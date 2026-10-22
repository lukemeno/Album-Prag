import XCTest
@testable import Album

@MainActor
final class TripMigrationTests: XCTestCase {
    private var roots: [URL] = []

    override func tearDownWithError() throws {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots.removeAll()
        try super.tearDownWithError()
    }

    /// Album im Format von main vor B1: Reise ohne Daten, Orte mit Tageszahlen 4…9.
    private func legacyAlbumJSON(places: [Place], trip: TripInfo = TripInfo(), collaboration: CollaborationState? = nil,
                                 placeExtras: [String: [String: Any]] = [:]) throws -> Data {
        var album = AlbumData()
        album.places = places
        album.trip = trip
        album.collaboration = collaboration
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(album)) as? [String: Any])
        XCTAssertNil(object["schemaVersion"])
        var rawPlaces = try XCTUnwrap(object["places"] as? [[String: Any]])
        for index in rawPlaces.indices {
            guard let id = rawPlaces[index]["id"] as? String, let extras = placeExtras[id] else { continue }
            rawPlaces[index].merge(extras) { _, new in new }
        }
        object["places"] = rawPlaces
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    func testLegacyPragueMigrationBacksUpAndPreservesIdentityVotesAndPhotos() throws {
        let root = try temporaryRoot()
        let image = UploadedPlaceImage(id: "photo-1", storagePath: "trip/existing-idea/photo-1.jpg", pixelWidth: 4, pixelHeight: 3)
        var museum = Place(id: "existing-idea", title: "Museum", sourceURL: "https://example.com", category: "Sehenswert",
                           image: .uploaded(image), address: "Address", lat: 50.1, lng: 14.4,
                           franked: true, visited: true, day: 4, dayOrder: 3, approvals: ["A", "B"], passedBy: ["C"],
                           updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        museum.gallery = [ExternalPlaceImage(imageURL: "https://example.invalid/g.jpg", sourceURL: "https://example.invalid", credit: "Wiki", provider: .wikimedia)]
        let lastDay = Place(id: "prague-castle-day", title: "Burg", franked: true, day: 9, dayOrder: 0)
        let unknownDay = Place(id: "odd-day", title: "Seltsam", franked: true, day: 12, dayOrder: 1)
        let open = Place(id: "prague-open", title: "Offen")
        let original = try legacyAlbumJSON(places: [museum, lastDay, unknownDay, open],
                                           placeExtras: ["existing-idea": ["selectedGooglePlace": ["placeID": "ChIJ-test", "title": "Museum"]]])
        try original.write(to: root.appendingPathComponent("album.json"))

        let store = AlbumStore(root: root)

        XCTAssertEqual(store.data.schemaVersion, 2)
        XCTAssertEqual(store.data.trip.startDate?.rawValue, "2026-10-04")
        XCTAssertEqual(store.data.trip.endDate?.rawValue, "2026-10-09")
        XCTAssertEqual(store.data.trip.timeZoneIdentifier, "Europe/Prague")
        XCTAssertEqual(store.data.trip.planningSchemaVersion, 2)
        XCTAssertEqual(store.data.trip.hotel, "Hotel Urban Crème", "Hotel bleibt unverändert")
        XCTAssertEqual(store.data.places.map(\.id), ["existing-idea", "prague-castle-day", "odd-day", "prague-open"])
        let migrated = try XCTUnwrap(store.data.places.first)
        XCTAssertEqual(migrated.plannedDate?.rawValue, "2026-10-04")
        XCTAssertNil(migrated.day)
        XCTAssertEqual(migrated.dayOrder, 3)
        XCTAssertEqual(migrated.approvals, ["A", "B"])
        XCTAssertEqual(migrated.passedBy, ["C"])
        XCTAssertEqual(migrated.image, museum.image)
        XCTAssertEqual(migrated.gallery, museum.gallery)
        XCTAssertEqual(migrated.updatedAt, museum.updatedAt, "Migration erzeugt keine neue Revision")
        XCTAssertEqual(migrated.selectedGooglePlace, .object(["placeID": .string("ChIJ-test"), "title": .string("Museum")]))
        XCTAssertEqual(store.data.places[1].plannedDate?.rawValue, "2026-10-09")
        XCTAssertNil(store.data.places[2].plannedDate, "Nichts wird erfunden")
        XCTAssertEqual(store.data.places[2].day, 12)
        XCTAssertEqual(store.unresolvedLegacyPlaces.map(\.id), ["odd-day"])
        XCTAssertNil(store.data.places[3].plannedDate)
        XCTAssertTrue(store.data.dirty.isEmpty)
        XCTAssertEqual(store.plan(for: try XCTUnwrap(TripDay(rawValue: "2026-10-04"))).map(\.id), ["existing-idea"])

        let backup = root.appendingPathComponent(AlbumStore.legacyPlanningBackupName)
        XCTAssertEqual(try Data(contentsOf: backup), original, "Backup ist die unveränderte Original-JSON")

        let migratedBytes = try Data(contentsOf: root.appendingPathComponent("album.json"))
        let reopened = AlbumStore(root: root)
        XCTAssertEqual(reopened.data.places.first?.plannedDate, migrated.plannedDate)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("album.json")), migratedBytes, "Kein zweiter Migrationslauf")
        XCTAssertEqual(try Data(contentsOf: backup), original, "Backup wird nie überschrieben")
    }

    func testAmbiguousLegacyDayRemainsVisibleAndUnassigned() throws {
        let root = try temporaryRoot()
        var trip = TripInfo()
        trip.destination = "Tokyo"
        trip.hotel = ""
        let original = try legacyAlbumJSON(places: [Place(id: "old-local-place", title: "Uncertain", franked: true, day: 4, dayOrder: 2)], trip: trip)
        try original.write(to: root.appendingPathComponent("album.json"))

        let store = AlbumStore(root: root)
        XCTAssertNil(store.data.trip.startDate)
        XCTAssertNil(store.data.places[0].plannedDate)
        XCTAssertEqual(store.data.places[0].day, 4)
        XCTAssertEqual(store.unresolvedLegacyPlaces.map(\.id), ["old-local-place"])
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(AlbumStore.legacyPlanningBackupName)), original)
    }

    func testSharedLegacyAlbumMigratesLocallyWithoutMarkingDirty() throws {
        let root = try temporaryRoot()
        let collaboration = CollaborationState(tripID: UUID(), inviteToken: String(repeating: "a", count: 40))
        let original = try legacyAlbumJSON(places: [Place(id: "shared-place", title: "Café", franked: true, day: 5, dayOrder: 0)],
                                           collaboration: collaboration)
        try original.write(to: root.appendingPathComponent("album.json"))

        let store = AlbumStore(root: root)
        XCTAssertEqual(store.data.places.first?.plannedDate?.rawValue, "2026-10-05")
        XCTAssertEqual(store.data.collaboration, collaboration)
        XCTAssertTrue(store.data.dirty.isEmpty, "Der Übergang auf dem Server passiert erst im Abgleich")
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(AlbumStore.legacyPlanningBackupName)), original)
    }

    func testCorruptAlbumIsNeitherMigratedNorBackedUp() throws {
        let root = try temporaryRoot()
        let corrupt = Data("{ kaputt".utf8)
        try corrupt.write(to: root.appendingPathComponent("album.json"))

        let store = AlbumStore(root: root)
        XCTAssertNotNil(store.error)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(AlbumStore.legacyPlanningBackupName).path))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("album.json")), corrupt)
    }

    func testFreshAlbumGetsLegacyPragueRangeWithoutBackup() throws {
        let root = try temporaryRoot()
        let store = AlbumStore(root: root)
        XCTAssertEqual(store.tripCalendar.days.count, 6)
        XCTAssertEqual(store.data.schemaVersion, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(AlbumStore.legacyPlanningBackupName).path))
    }

    func testRangeChangeRetainsOutOfRangeDatesAndRejectsInvalidRange() throws {
        let root = try temporaryRoot()
        let store = AlbumStore(root: root)
        var trip = store.data.trip
        let place = Place(id: "dated", title: "Idea", franked: true, plannedDate: TripDay(rawValue: "2026-10-09"), planningSchemaVersion: 2)
        XCTAssertTrue(store.upsert(place))

        trip.endDate = TripDay(rawValue: "2026-10-08")
        XCTAssertEqual(store.placesOutsideRange(of: trip).map(\.id), ["dated"])
        XCTAssertTrue(store.updateTrip(trip))
        XCTAssertEqual(store.data.places.first { $0.id == "dated" }?.plannedDate?.rawValue, "2026-10-09")
        XCTAssertEqual(store.outOfRangePlannedPlaces.map(\.id), ["dated"])
        XCTAssertFalse(store.tripCalendar.contains(try XCTUnwrap(TripDay(rawValue: "2026-10-09"))))

        var reversed = trip
        reversed.endDate = TripDay(rawValue: "2026-10-01")
        XCTAssertFalse(store.updateTrip(reversed))
        XCTAssertEqual(store.data.trip.endDate?.rawValue, "2026-10-08")

        store.assign(try XCTUnwrap(store.places.first { $0.id == "dated" }), toDate: TripDay(rawValue: "2026-10-20"))
        XCTAssertEqual(store.data.places.first { $0.id == "dated" }?.plannedDate?.rawValue, "2026-10-09", "Daten außerhalb des Zeitraums werden nicht neu vergeben")
    }

    func testTripInfoRoundTripsAllCalendarFieldsAndLedger() throws {
        let json = """
        {"title":"Prag","destination":"Prag","startDate":"2026-10-04","endDate":"2026-10-09",
         "timeZoneIdentifier":"Europe/Prague","planningSchemaVersion":2,"hotel":"Hotel Urban Crème",
         "outbound":"","arrival":"","route":"","flightNumber":"","notes":"","updatedAt":0,
         "expenses":[]}
        """
        let trip = try JSONDecoder().decode(TripInfo.self, from: Data(json.utf8))
        XCTAssertEqual(trip.startDate?.rawValue, "2026-10-04")
        XCTAssertEqual(trip.planningSchemaVersion, 2)
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(trip)) as? [String: Any])
        for key in ["title", "destination", "startDate", "endDate", "timeZoneIdentifier", "planningSchemaVersion"] {
            XCTAssertNotNil(encoded[key], "\(key) muss zurückgeschrieben werden")
        }
        XCTAssertEqual(encoded["endDate"] as? String, "2026-10-09")
        XCTAssertNotNil(encoded["expenses"])

        // Alte Nutzlast ohne v2-Felder bleibt lesbar.
        let legacy = try JSONDecoder().decode(TripInfo.self, from: Data(#"{"hotel":"H","updatedAt":0}"#.utf8))
        XCTAssertNil(legacy.startDate)
        XCTAssertEqual(legacy.hotel, "H")
    }

    func testPlaceRejectsInvalidPlannedDate() {
        let json = #"{"id":"p","title":"P","plannedDate":"2026-02-30"}"#
        XCTAssertThrowsError(try JSONDecoder().decode(Place.self, from: Data(json.utf8)))
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("trip-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        roots.append(root)
        return root
    }
}
