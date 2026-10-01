import XCTest
import PDFKit
@testable import Album

final class AlbumTests: XCTestCase {
    func testTripCountdownAndTodayPlan() {
        let date = { (day: Int, hour: Int) in TripDates.calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))! }
        let september = TripDates.calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 23, minute: 59))!
        XCTAssertEqual(TripDates.daysUntilStart(from: september), 11)
        XCTAssertEqual(TripDates.daysUntilStart(from: date(3, 22)), 1)
        XCTAssertEqual(TripDates.daysUntilStart(from: date(4, 6)), 0)
        XCTAssertNil(TripDates.tripDay(on: date(3, 23)))
        XCTAssertEqual(TripDates.tripDay(on: date(4, 0)), 4)
        XCTAssertEqual(TripDates.tripDay(on: date(9, 23)), 9)
        XCTAssertNil(TripDates.tripDay(on: date(10, 0)))
    }

    /// Anonymisiertes Muster im Aufbau einer Voyage-Privé-Reisebestätigung, inklusive zerstückeltem PDF-Text.
    private static let bookingSample = """
    I H R E  R E I S E D O K U M E N T E
    Prag - Tschechien
    Hotel Beispielhaus 4*
    Von Sonntag 04 Oktober 2026 bis Freitag 09 Oktober 2026
    BUCHUNGSNUMMER VOYAGE PRIVÉ
    123456789VPDEHin Flüge
    ONLINE CHECK -IN ERFORDERLICH
    Sie können zwischen 72 Stunden und 3 Stunden vor Abﬂug online einchecken.
    3 Geben Sie im Feld « Buchungscode » Ihre Buchungsref erenz ein: ABC12X
    Erwachsener 1 Herr MUSTER-MANN Max Geboren am 01/02/ 1990
    Erwachsener 2 Frau BEISPIEL Erika Geboren am 03/04/199 1
    Details
    KÖLN
    Cologne/Bonn
    PRAG
    Prague-Václav Havel
    BUCHUNGSNUMMER FLUGGESELLSCHAFT FLUGNR. KLASSE TERMINAL
    ABC12X EUROWINGS
     EW4241 Economy Class
    EINFINDUNGSZEIT ABFLUG ANKUNFT GEPÄCK
    04/10/2026 12:45 04/10/2026 - 14:45 04/10/2026 - 15:5 5 2 Handgepäck
    BUCHUNGSNUMMER VOYAGE PRIVÉ
    123456789VPDERück Flüge
    Details
    PRAG
    Prague-Václav Havel
    KÖLN
    Cologne/Bonn
    BUCHUNGSNUMMER FLUGGESELLSCHAFT FLUGNR. KLASSE TERMINAL
    ABC12X EUROWINGS
     EW773 Economy Class
    EINFINDUNGSZEIT ABFLUG ANKUNFT GEPÄCK
    09/10/2026 10:20 09/10/2026 - 12:20 09/10/2026 - 13:3 5 2 Handgepäck
    Hotel
    123456789VPDE
    BEISPIELHAUS
    04/10/2026 - 09/10/2026
    Musterstraße 12, Prague, Czech Republic 110 00
    Beinhaltet :
    Superior Zimmer
    Frühstück
    Beinhaltet nicht :
    - Persönliche Ausgaben
    Check-in: 14:00
    Check-out: 12:00
    Die T ourismusabgabe in Höhe von 2,20 € pro Person pro Nacht ist vor Ort zu zahlen.
    """

    func testBookingPDFTextIsRead() {
        let trip = TripDocumentParser.parse(Self.bookingSample)
        XCTAssertEqual(trip.flights.map(\.number), ["EW4241", "EW773"])
        let out = trip.flights[0], back = trip.flights[1]
        XCTAssertEqual(out.direction, .outbound); XCTAssertEqual(back.direction, .inbound)
        XCTAssertEqual(out.route, "Köln → Prag"); XCTAssertEqual(back.route, "Prag → Köln")
        XCTAssertEqual([out.date, out.departure, out.arrival, out.arriveBy], ["04.10.2026", "14:45", "15:55", "12:45"])
        XCTAssertEqual([back.date, back.departure, back.arrival, back.arriveBy], ["09.10.2026", "12:20", "13:35", "10:20"])
        XCTAssertEqual(out.bookingCode, "ABC12X"); XCTAssertEqual(out.airline, "Eurowings")
        XCTAssertEqual(trip.hotel.name, "Hotel Beispielhaus")
        XCTAssertEqual(trip.hotel.address, "Musterstraße 12, Prague, Czech Republic 110 00")
        XCTAssertEqual(trip.hotel.checkIn, "14:00"); XCTAssertEqual(trip.hotel.checkOut, "12:00")
        XCTAssertEqual(trip.hotel.included, ["Superior Zimmer", "Frühstück"])
        XCTAssertEqual(trip.bookingNumber, "123456789VPDE")
        XCTAssertEqual(trip.travelers, ["Max Muster-Mann", "Erika Beispiel"])
        XCTAssertTrue(trip.notes.contains { $0.contains("Tourismusabgabe") })
        XCTAssertTrue(trip.notes.contains { $0.contains("zwischen 72 und 3 Stunden") })
        // Geburtsdaten werden nirgends übernommen.
        let applied = trip.applied(to: TripInfo())
        XCTAssertFalse(String(describing: applied).contains("1990"))
        XCTAssertEqual(applied.flightNumber, "EW4241"); XCTAssertEqual(applied.route, "Köln → Prag")
        XCTAssertEqual(applied.hotel, "Hotel Beispielhaus")
    }

    func testRealBookingPDFIfAvailable() throws {
        // Nur lokal: TEST_RUNNER_ALBUM_SAMPLE_PDF=/pfad/zum.pdf xcodebuild test …
        guard let path = ProcessInfo.processInfo.environment["ALBUM_SAMPLE_PDF"],
              let text = PDFDocument(url: URL(fileURLWithPath: path))?.string else { throw XCTSkip("Kein echtes PDF angegeben") }
        let trip = TripDocumentParser.parse(text)
        XCTAssertEqual(trip.flights.count, 2)
        XCTAssertTrue(trip.flights.allSatisfy { !$0.departure.isEmpty && !$0.arrival.isEmpty && $0.bookingCode != nil })
        XCTAssertNotNil(trip.hotel.address); XCTAssertNotNil(trip.hotel.checkIn); XCTAssertNotNil(trip.bookingNumber)
    }

    func testOnlyWebLinksAccepted() {
        XCTAssertNil(LinkValidation.url("javascript:alert(1)"))
        XCTAssertNil(LinkValidation.url("file:///private/test"))
        XCTAssertNil(LinkValidation.url("https://"))
        XCTAssertNotNil(LinkValidation.url("https://www.instagram.com/reel/example/"))
        XCTAssertEqual(LinkValidation.firstURL(in: "Schau mal https://www.tiktok.com/@user/video/123")?.host, "www.tiktok.com")
    }
    func testCoordinatesMustBeValid() {
        var place = Place(title: "Prag")
        XCTAssertNil(place.coordinate)
        place.lat = 50.087; place.lng = 14.423
        XCTAssertNotNil(place.coordinate)
        place.lat = 100
        XCTAssertNil(place.coordinate)
    }
    func testSourceHostCannotSpoofTikTok() {
        let place = Place(title: "Test", sourceURL: "https://tiktok.com.evil.example/video")
        XCTAssertNotEqual(place.sourceLabel, "TikTok")
    }
    func testRealPlacePhotoBeatsLinkPreviewOnceConfirmed() {
        var place = Place(title: "Letná", image: .linkPreview(
            pageURL: "https://example.com/letna",
            thumbnailURL: "https://example.com/letna.jpg",
            credit: "example.com"
        ))
        XCTAssertFalse(PlaceImageService.shouldSearch(for: place, force: false), "Ohne bestätigten Ort bleibt die Vorschau")
        place.lat = 50.0966; place.lng = 14.4165
        XCTAssertTrue(PlaceImageService.shouldSearch(for: place, force: false), "Bestätigter Ort bekommt ein echtes Foto")
        let own = Place(title: "Letná", image: .uploaded(.init(id: "x", storagePath: nil, pixelWidth: 1, pixelHeight: 1)), lat: 50.0966, lng: 14.4165)
        XCTAssertFalse(PlaceImageService.shouldSearch(for: own, force: false), "Eigene Fotos werden nie ersetzt")
        XCTAssertTrue(PlaceImageService.shouldSearch(for: place, force: true))
        XCTAssertTrue(PlaceImageService.shouldSearch(for: Place(title: "Letná"), force: false))
    }

    func testLegacyImageFieldsMigrateToTypedAsset() throws {
        let json = #"{"id":"legacy","title":"Letná","remoteImage":"https://example.com/letna.jpg","imageSourceURL":"https://example.com/source","imageCredit":"Archiv"}"#.data(using: .utf8)!
        let place = try JSONDecoder().decode(Place.self, from: json)

        guard case .external(let image) = place.image else {
            return XCTFail("Legacy remoteImage was not migrated")
        }
        XCTAssertEqual(image.provider, .legacy)
        XCTAssertEqual(image.credit, "Archiv")

        let encoded = try JSONEncoder().encode(place)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNotNil(object["image"])
        XCTAssertNil(object["remoteImage"])
    }

    func testChangedResolvedPlaceRequestsAFreshImage() {
        let resolved = ResolvedPlaceIdentity(title: "Letná", latitude: 50.0957, longitude: 14.4165)
        let asset = PlaceImageAsset.external(.init(
            imageURL: "https://example.com/letna.jpg",
            sourceURL: "https://example.com/source",
            credit: "Archiv",
            provider: .wikimedia,
            resolvedFor: resolved,
            ranking: PlaceImageService.ranking
        ))
        let samePlace = Place(title: "Letná", image: asset, lat: 50.0957, lng: 14.4165)
        let movedPlace = Place(title: "Letná", image: asset, lat: 50.0755, lng: 14.4378)
        XCTAssertFalse(PlaceImageService.shouldSearch(for: samePlace, force: false))
        XCTAssertTrue(PlaceImageService.shouldSearch(for: movedPlace, force: false))
    }

    func testOwnPhotoIsNormalizedAndBounded() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 3200, height: 1600))
        let source = renderer.jpegData(withCompressionQuality: 1) { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3200, height: 1600))
        }

        let uploaded = try PlaceImageStorage.save(source, root: directory, id: "bounded")
        let storedURL = PlaceImageStorage.localURL(for: uploaded, root: directory)
        let storedData = try Data(contentsOf: storedURL)
        let image = try XCTUnwrap(UIImage(data: storedData))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 2048)
        XCTAssertLessThanOrEqual(storedData.count, 5 * 1024 * 1024)
        XCTAssertEqual(uploaded.pixelWidth, 2048)
        XCTAssertEqual(uploaded.pixelHeight, 1024)
    }
    @MainActor func testVotesArePerPersonAndBothAgree() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumStore(root: directory)
        store.myName = "Luke"
        var place = try XCTUnwrap(store.inbox.first); place.lat = 50.087; place.lng = 14.423
        store.upsert(store.decided(place, approve: true))
        XCTAssertTrue(store.franked.contains { $0.id == place.id })
        XCTAssertFalse(store.inbox.contains { $0.id == place.id }, "Eigene Stimme ist abgegeben")

        store.myName = "Mia" // dasselbe Album auf dem zweiten iPhone
        let open = try XCTUnwrap(store.inbox.first { $0.id == place.id }, "Lukes Vorschlag wartet auf Mias Stimme")
        XCTAssertFalse(store.isShared(open))
        let both = store.decided(open, approve: true)
        XCTAssertTrue(store.isShared(both))
        store.upsert(both)
        XCTAssertFalse(store.inbox.contains { $0.id == place.id })

        // „Später“ auf einen Vorschlag der anderen Person nimmt ihn nicht von der Karte.
        store.myName = "Luke"
        var other = try XCTUnwrap(store.inbox.first { $0.id != place.id }); other.lat = 50.08; other.lng = 14.42
        store.myName = "Mia"; store.upsert(store.decided(other, approve: true))
        store.myName = "Luke"
        let passed = store.decided(try XCTUnwrap(store.places.first { $0.id == other.id }), approve: false)
        store.upsert(passed)
        XCTAssertTrue(store.franked.contains { $0.id == other.id })
        XCTAssertFalse(store.inbox.contains { $0.id == other.id })
        XCTAssertTrue(store.deferred.contains { $0.id == other.id })
    }

    @MainActor func testNoVoteLeavesIdeaOpenForOtherPerson() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumStore(root: directory)
        store.myName = "Luke"
        let place = try XCTUnwrap(store.inbox.first)
        store.upsert(store.decided(place, approve: false))
        XCTAssertFalse(store.inbox.contains { $0.id == place.id })
        XCTAssertTrue(store.deferred.contains { $0.id == place.id })
        store.myName = "Mia"
        XCTAssertTrue(store.inbox.contains { $0.id == place.id })
        let saved = try XCTUnwrap(store.places.first { $0.id == place.id })
        XCTAssertEqual(saved.passedBy, ["Luke"])
        XCTAssertFalse(saved.deferred)
    }

    func testMergeKeepsVotesFromBothPhones() {
        var local = Place(id: "p", title: "Letná", approvals: ["Luke"], updatedAt: Date(timeIntervalSince1970: 10))
        local.franked = true
        let remote = Place(id: "p", title: "Letná", franked: true, approvals: ["Mia"], updatedAt: Date(timeIntervalSince1970: 20))
        let merged = AlbumMerge.place(local: local, remote: remote)
        XCTAssertEqual(Set(merged.approvals), ["Luke", "Mia"])
        XCTAssertTrue(merged.franked)
    }

    @MainActor func testDayPlanOrder() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumStore(root: directory)
        for var place in store.places { place.franked = true; store.upsert(place) }
        let ids = store.franked.map(\.id)
        for id in ids { store.assign(try XCTUnwrap(store.places.first { $0.id == id }), to: 5) }
        XCTAssertEqual(store.plan(for: 5).map(\.id), ids)
        store.reorder(day: 5, ids: ids.reversed())
        XCTAssertEqual(AlbumStore(root: directory).plan(for: 5).map(\.id), ids.reversed(), "Reihenfolge bleibt gespeichert")
    }

    @MainActor func testPersistenceAndInboxDecisions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumStore(root: directory)
        let example = try XCTUnwrap(store.inbox.first)
        store.deferPlace(example)
        XCTAssertFalse(store.inbox.contains { $0.id == example.id })
        XCTAssertEqual(store.deferred.count, 1)
        store.restoreDeferred()
        XCTAssertEqual(store.inbox.count, 3)
        var place = example; place.franked = true; place.lat = 50.087; place.lng = 14.423
        store.upsert(place)
        let reopened = AlbumStore(root: directory)
        XCTAssertEqual(reopened.franked.count, 1)
        XCTAssertEqual(reopened.inbox.count, 2)
        XCTAssertTrue(reopened.data.dirty.contains(example.id))
        var deleted = place; deleted.deleted = true; reopened.upsert(deleted)
        XCTAssertFalse(reopened.places.contains { $0.id == place.id })
        XCTAssertTrue(reopened.data.places.contains { $0.id == place.id && $0.deleted })
    }
    @MainActor func testPDFImportPersistsOriginalAndText() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumStore(root: directory)
        let source = directory.appendingPathComponent("booking.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 400))
        try renderer.writePDF(to: source) { ctx in
            ctx.beginPage()
            ("Prague 4 October 2026" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
        }
        try store.importPDF(source, id: "test-document")
        XCTAssertEqual(store.data.documents.count, 1)
        XCTAssertTrue(store.data.documents[0].extractedText.contains("Prague"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("test-document.pdf").path))
        try store.importPDF(source, id: "test-document")
        XCTAssertEqual(store.data.documents.count, 1)
        XCTAssertEqual(AlbumStore(root: directory).data.documents.count, 1)
    }
    @MainActor func testCorruptStoreIsNotOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("album.json")
        let corrupt = Data("broken-data".utf8)
        try corrupt.write(to: file)
        let store = AlbumStore(root: directory)
        XCTAssertNotNil(store.error)
        XCTAssertFalse(store.persist())
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }
    @MainActor func testTripChangesPersist() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumStore(root: directory)
        var trip = store.data.trip; trip.outbound = "14:45"; trip.route = "CGN → PRG"
        store.updateTrip(trip)
        XCTAssertEqual(AlbumStore(root: directory).data.trip.outbound, "14:45")
        XCTAssertTrue(store.data.dirty.contains("trip"))
    }

    func testInvitationLinksRejectWrongSchemeAndShortTokens() throws {
        let token = String(repeating: "a", count: 43)
        let url = try XCTUnwrap(InvitationLink.make(token: token))
        XCTAssertEqual(InvitationLink.token(from: url), token)
        XCTAssertNil(InvitationLink.token(from: URL(string: "https://join/\(token)")!))
        XCTAssertNil(InvitationLink.token(from: URL(string: "album://join/short")!))
    }

    func testNewestRecordWinsConflict() {
        let older = Place(id: "same", title: "Alt", updatedAt: Date(timeIntervalSince1970: 10))
        let newer = Place(id: "same", title: "Neu", updatedAt: Date(timeIntervalSince1970: 20))
        XCTAssertEqual(AlbumMerge.place(local: older, remote: newer).title, "Neu")
        XCTAssertEqual(AlbumMerge.place(local: newer, remote: older).title, "Neu")
    }

    @MainActor func testLocalAlbumBecomesSharedIdempotently() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumStore(root: directory)
        let service = MockSyncService()
        store.syncService = service

        let link = try await store.createSharedTrip()

        XCTAssertEqual(store.data.collaboration?.tripID, service.tripID)
        XCTAssertEqual(InvitationLink.token(from: link), service.token)
        XCTAssertEqual(service.syncCount, 1)
        XCTAssertTrue(service.lastDirty.contains("trip"))
        XCTAssertEqual(AlbumStore(root: directory).data.collaboration?.tripID, service.tripID)
    }

    func testExistingAlbumWithoutCollaborationStillDecodes() throws {
        let oldJSON = #"{"places":[],"trip":{"hotel":"Urban Crème","outbound":"","arrival":"","route":"","flightNumber":"","notes":"","updatedAt":0},"documents":[],"dirty":[]}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AlbumData.self, from: oldJSON)
        XCTAssertNil(decoded.collaboration)
    }
}

@MainActor private final class MockSyncService: AlbumSyncService {
    let tripID = UUID()
    let token = String(repeating: "t", count: 43)
    var syncCount = 0
    var lastDirty: Set<String> = []

    func createTrip(store: AlbumStore) async throws -> CollaborationState {
        try await sync(store: store)
        return CollaborationState(tripID: tripID, inviteToken: token)
    }
    func joinTrip(token: String) async throws -> CollaborationState {
        CollaborationState(tripID: tripID, inviteToken: nil)
    }
    func sync(store: AlbumStore) async throws {
        syncCount += 1
        lastDirty = store.data.dirty
    }
    func startRealtime(onChange: @escaping @MainActor @Sendable () async -> Void) {}
}

extension AlbumTests {
    func testImageSuggestionsNeverBecomeAutomaticByArrayPosition() throws {
        let json = #"{"selection_version":3,"image":null,"candidates":[{"image_url":"https://example.com/nearby.jpg","source_url":"https://example.com/source","credit":"A","provider":"wikimedia","confidence":"suggested"}]}"#.data(using: .utf8)!
        let result = try JSONDecoder().decode(PlaceImageSearchResult.self, from: json)
        XCTAssertEqual(result.choices.count, 1)
        XCTAssertTrue(result.automaticImages.isEmpty)
    }

    func testLegacyServerResultsRequireManualSelection() throws {
        let json = #"{"image":{"image_url":"https://example.com/old.jpg","source_url":"https://example.com/source","credit":"A","provider":"wikimedia"}}"#.data(using: .utf8)!
        let result = try JSONDecoder().decode(PlaceImageSearchResult.self, from: json)
        XCTAssertFalse(result.isCurrent)
        XCTAssertEqual(result.choices.count, 1)
        XCTAssertTrue(result.automaticImages.isEmpty)
    }

    func testAutomaticGalleryExcludesSuggestionsAndDuplicates() throws {
        let json = #"{"selection_version":3,"image":{"image_url":"https://example.com/verified.jpg","source_url":"https://example.com/source","credit":"A","provider":"wikimedia","confidence":"verified"},"candidates":[{"image_url":"https://example.com/verified.jpg","source_url":"https://example.com/source","credit":"A","provider":"wikimedia","confidence":"verified"},{"image_url":"https://example.com/nearby.jpg","source_url":"https://example.com/source","credit":"B","provider":"wikimedia","confidence":"suggested"}]}"#.data(using: .utf8)!
        let result = try JSONDecoder().decode(PlaceImageSearchResult.self, from: json)
        XCTAssertEqual(result.choices.count, 2)
        XCTAssertEqual(result.automaticImages.count, 1)
        XCTAssertTrue(PlaceImageService.gallery(from: result.automaticImages, for: Place(title: "Ort")).isEmpty)
    }

    func testManualImageSelectionSurvivesRoundTripAndRankingUpdates() throws {
        let json = #"{"image_url":"https://example.com/manual.jpg","source_url":"https://example.com/source","credit":"A","provider":"wikimedia","confidence":"suggested"}"#.data(using: .utf8)!
        let image = try JSONDecoder().decode(PlaceImage.self, from: json)
        var place = Place(title: "Café Louvre", category: "Essen & Trinken", lat: 50.0819, lng: 14.4185)
        place.image = image.asset(for: place, userSelected: true)
        if case .external(var chosen) = place.image {
            chosen.ranking = 1
            place.image = .external(chosen)
        }
        let decoded = try JSONDecoder().decode(Place.self, from: JSONEncoder().encode(place))
        XCTAssertFalse(PlaceImageService.shouldSearch(for: decoded, force: false))
        XCTAssertFalse(PlaceImageService.needsGallery(decoded))
        var changed = decoded
        changed.category = "Sehenswert"
        XCTAssertTrue(PlaceImageService.shouldSearch(for: changed, force: false))
    }

    func testImageRequestRejectsStaleAddressAndCategory() {
        let place = Place(title: "Café Louvre", category: "Essen & Trinken", address: "Národní 22", lat: 50.0819, lng: 14.4185)
        var changed = place
        changed.address = "Národní 24"
        XCTAssertFalse(PlaceImageService.matchesRequest(place, changed))
        changed = place
        changed.category = "Unterkunft"
        XCTAssertFalse(PlaceImageService.matchesRequest(place, changed))
    }

    func testStreetViewIsResolvedForItsCoordinate() {
        var photo = UploadedPlaceImage(id: "street", storagePath: nil, pixelWidth: 1200, pixelHeight: 900)
        photo.resolvedFor = ResolvedPlaceIdentity(title: "Café Louvre", latitude: 50.0819, longitude: 14.4185)
        var place = Place(title: "Café Louvre", image: .uploaded(photo), lat: 50.0819, lng: 14.4185)
        XCTAssertFalse(PlaceImageService.shouldSearch(for: place, force: false))
        place.lat = 50.092
        XCTAssertTrue(PlaceImageService.shouldSearch(for: place, force: false))
    }
}
