import SwiftUI
import PDFKit
import CoreLocation
import MapKit
import Observation

private struct OpeningHoursRequest: Sendable {
    let id: String
    let title: String
    let address: String
    let category: String
    let latitude: Double
    let longitude: Double
}

private struct OpeningHoursFetchResult: Sendable {
    let id: String
    let hours: String?
}

private struct PlaceResolutionSnapshot: Equatable {
    let title: String
    let address: String
    let category: String
    let context: TripRegionContext
    let albumID: String
    let trip: TripInfo
}

@MainActor @Observable final class AlbumStore {
    var data: AlbumData
    var error: String?
    var syncStatus = "Auf diesem iPhone gespeichert"
    var syncing = false
    /// Was der letzte Abgleich von anderen gebracht hat; die Abgleich-Insel zeigt es kurz.
    var syncChange: SyncChange?
    var shareQueueRevision = 0
    var shareQueueError: String?
    let root: URL
    let shareInbox: ShareInbox
    var syncService: AlbumSyncService?
    private(set) var authenticatedUserID: String?
    /// Nur fokussierte Tests setzen diese Identität; produktiv bleibt sie die Installations-UUID.
    var collectionParticipantIDOverride: String? = nil
    /// In-flight/backfill guards keep repeated view updates from starting duplicate previews.
    @ObservationIgnored var collectionMetadataRefreshIDs = Set<String>()
    @ObservationIgnored var collectionMetadataBackfilledIDs = Set<String>()
    private var loadFailed = false
    private var pendingSync: Task<Void, Never>?
    private var syncRequestedWhileRunning = false
    /// Test hooks keep the production services as the default while allowing paused, deterministic regressions.
    var openingHoursResolver: (@MainActor (Place) async -> String?)?
    var geocodeAddressResolver: (@MainActor (String) async -> CLLocationCoordinate2D?)?
    var placeResolutionResolver: (@MainActor (Place, TripRegionContext) async -> PlaceResolutionOutcome)?
    var placeImageSearchResolver: (@MainActor (Place, TripRegionContext) async throws -> PlaceImageSearchResult)?
    var placeSourcePreviewResolver: (@MainActor (Place, TripRegionContext) async -> PlaceImage?)?
    @ObservationIgnored var discoveryServiceOverride: (any DiscoveryServiceProtocol)?
    @ObservationIgnored private var storedDiscoverySession: DiscoverySession?
    var discoverySession: DiscoverySession {
        if let storedDiscoverySession { return storedDiscoverySession }
        let session = DiscoverySession(store: self)
        storedDiscoverySession = session
        return session
    }
    private(set) var placeImageStatuses: [String: PlaceImageStatus] = [:]
    @ObservationIgnored private var placeResolutionSnapshots: [String: PlaceResolutionSnapshot] = [:]
    @ObservationIgnored private var placeResolutionAttempts = Set<String>()
    @ObservationIgnored private var placeImageAttempts = Set<String>()
    @ObservationIgnored private var placeImageInFlight = Set<String>()
    var places: [Place] { data.places.filter { !$0.deleted } }
    /// Was auf diesem iPhone noch zu entscheiden ist, auch Vorschläge, für die nur die andere Person schon ist.
    var inbox: [Place] { places.filter(isOpenForMe) }
    var deferred: [Place] { places.filter { ($0.deferred && !$0.franked) || $0.passedBy.contains(me) } }
    var franked: [Place] { places.filter(\.franked) }
    var tripCalendar: TripCalendar { TripCalendar(trip: data.trip) }
    var tripRegionContext: TripRegionContext { tripRegionContext(for: nil) }
    /// Alte Tageszahlen, die sich keinem Datum sicher zuordnen ließen; bleiben sichtbar, bis jemand neu plant.
    var unresolvedLegacyPlaces: [Place] { places.filter { $0.day != nil && $0.plannedDate == nil } }
    var outOfRangePlannedPlaces: [Place] { placesOutsideRange(of: data.trip) }
    /// Offene Ideen, die jemand anderes gesammelt hat – für das Zeichen am Tab.
    var newFromOthers: Int { inbox.filter { $0.author != me && $0.author.localizedCaseInsensitiveCompare("Wir") != .orderedSame }.count }

    func tripRegionContext(for place: Place?) -> TripRegionContext {
        let destination = [data.trip.destination, data.trip.title]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        let language = Locale.current.language.languageCode?.identifier
        let accommodations = places.filter { $0.franked && $0.category.localizedCaseInsensitiveCompare("Unterkunft") == .orderedSame && $0.coordinate != nil }
        if let place, let date = place.plannedDate,
           let sameDay = accommodations.first(where: { $0.plannedDate == date }), let coordinate = sameDay.coordinate {
            return TripRegionContext(name: destination ?? sameDay.title, region: Self.region(center: coordinate, span: 0.2), preferredLanguageCode: language, source: .sameDayAccommodation)
        }
        if let accommodation = accommodations.first, let coordinate = accommodation.coordinate {
            return TripRegionContext(name: destination ?? accommodation.title, region: Self.region(center: coordinate, span: 0.2), preferredLanguageCode: language, source: .accommodation)
        }
        let confirmed = places.filter { $0.franked && $0.coordinate != nil }
        if let region = Self.region(covering: confirmed.compactMap(\.coordinate)) {
            return TripRegionContext(name: destination, region: region, preferredLanguageCode: language, source: .confirmedPlaces)
        }
        if let destination {
            return TripRegionContext(name: destination, region: nil, preferredLanguageCode: language, source: .destinationOnly)
        }
        return TripRegionContext(name: nil, region: nil, preferredLanguageCode: language, source: .none)
    }

    var tripAnchorCoordinate: CLLocationCoordinate2D? { tripRegionContext.region?.center }

    private static func region(center: CLLocationCoordinate2D, span: CLLocationDegrees) -> MKCoordinateRegion {
        MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
    }

    private static func region(covering coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        let latitudes = coordinates.map(\.latitude)
        let centerLatitude = (latitudes.min()! + latitudes.max()!) / 2
        let radians = coordinates.map { $0.longitude * .pi / 180 }
        let x = radians.reduce(0) { $0 + cos($1) }
        let y = radians.reduce(0) { $0 + sin($1) }
        let centerLongitude = atan2(y, x) * 180 / .pi
        let center = CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
        let maxDistance = coordinates.map { CLLocation(latitude: centerLatitude, longitude: centerLongitude).distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) }.max() ?? 0
        let delta = min(max(maxDistance / 55_000, 0.08), 80)
        return region(center: center, span: delta)
    }

    private var isAutomatedTestStore: Bool {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil || environment["ALBUM_TEST_STORE"] != nil
        #else
        return false
        #endif
    }

    var myName: String { didSet { UserDefaults.standard.set(myName, forKey: "album.myName") } }
    var me: String {
        let name = myName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Ich" : name
    }

    func isOpenForMe(_ place: Place) -> Bool {
        if place.approvals.contains(me) || place.passedBy.contains(me) { return false }
        if place.franked {
            return !place.approvals.isEmpty
        }
        return !place.deferred
    }

    /// Beide (oder alle) sind dafür.
    func isShared(_ place: Place) -> Bool { Set(place.approvals).count >= 2 }

    /// Die Stimme dieser Person. Gibt den geänderten Ort zurück, gespeichert wird mit `upsert`.
    func decided(_ place: Place, approve: Bool) -> Place {
        var changed = place
        if approve {
            if !changed.approvals.contains(me) { changed.approvals.append(me) }
            changed.passedBy.removeAll { $0 == me }
            changed.deferred = false
        } else {
            changed.approvals.removeAll { $0 == me }
            if !changed.passedBy.contains(me) { changed.passedBy.append(me) }
        }
        return changed
    }

    init(root: URL? = nil, shareInbox: ShareInbox? = nil) {
        self.shareInbox = shareInbox ?? ShareInbox()
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Album", isDirectory: true)
        var legacyAlbumID = false
        var needsInitialPersist = false
        var shouldPublishShareContext = true
        var storedBytes: Data?
        do {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
            let file = self.root.appendingPathComponent("album.json")
            var loadedData: AlbumData
            if FileManager.default.fileExists(atPath: file.path) {
                let bytes = try Data(contentsOf: file)
                storedBytes = bytes
                if let object = try? JSONSerialization.jsonObject(with: bytes), let dictionary = object as? [String: Any] { legacyAlbumID = dictionary["albumID"] == nil }
                loadedData = try JSONDecoder().decode(AlbumData.self, from: bytes)
            } else {
                loadedData = AlbumData()
                needsInitialPersist = true
                #if DEBUG
                if ProcessInfo.processInfo.environment["ALBUM_EMPTY_TEST_STORE"] == "1" { loadedData.places = [] }
                #endif
            }
            data = loadedData
            myName = UserDefaults.standard.string(forKey: "album.myName") ?? ""
        } catch {
            myName = UserDefaults.standard.string(forKey: "album.myName") ?? ""
            data = AlbumData()
            loadFailed = true
            self.error = "Gespeicherte Daten konnten nicht geladen werden: \(error.localizedDescription). Bitte die App nicht löschen."
        }
        #if DEBUG
        if let name = ProcessInfo.processInfo.environment["ALBUM_MY_NAME"] { myName = name }
        #endif
        // Beispielorte bekommen ihre echte Lage, damit sie echte Fotos erhalten.
        for (id, lat, lng) in [("example-letna", 50.0966, 14.4165), ("example-oldtown", 50.0875, 14.4213)] {
            if let index = data.places.firstIndex(where: { $0.id == id && $0.coordinate == nil }) {
                data.places[index].lat = lat; data.places[index].lng = lng
            }
        }
        #if DEBUG
        if ProcessInfo.processInfo.environment["ALBUM_DEMO_MEMORIES"] == "1" {
            var letna = Place(id: "memory-letna", title: "Letná", category: "Aussicht", author: "Luke",
                              image: .bundled(name: "imgPhotoLetna"), franked: true, visited: true, plannedDate: TripInfo.legacyPragueStart, dayOrder: 0)
            letna.gallery = [ExternalPlaceImage(
                imageURL: "https://example.invalid/memory.jpg", sourceURL: "https://example.invalid/memory",
                credit: "Demo", provider: .sourcePreview
            )]
            let oldTown = Place(id: "memory-oldtown", title: "Altstädter Ring", category: "Sehenswert", author: "Luke",
                                image: .bundled(name: "imgPhotoOldTown"), franked: true, visited: true, plannedDate: TripInfo.legacyPragueStart, dayOrder: 1)
            let noPhoto = Place(id: "memory-cafe", title: "Café Savoy", category: "Essen & Trinken", author: "Luke",
                                franked: true, visited: true, plannedDate: TripDay(rawValue: "2026-10-05"), dayOrder: 0)
            data.places = [letna, oldTown, noPhoto]
        }
        if ProcessInfo.processInfo.environment["ALBUM_DEMO_MOTION"] == "1" {
            var savoy = Place(id: "motion-savoy", title: "Café Savoy", category: "Essen & Trinken", author: "Luke",
                              image: .bundled(name: "imgThumbCafe"), franked: true, plannedDate: TripInfo.legacyPragueStart, dayOrder: 0, approvals: ["Luke"])
            savoy.gallery = [
                ExternalPlaceImage(imageURL: "https://example.invalid/motion-photo-2.jpg", sourceURL: "https://example.invalid/motion-photo-2",
                                   credit: "Demo", provider: .sourcePreview),
                ExternalPlaceImage(imageURL: "https://example.invalid/motion-photo-3.jpg", sourceURL: "https://example.invalid/motion-photo-3",
                                   credit: "Demo", provider: .sourcePreview)
            ]
            data.places = [savoy]
            data.trip.flights = [
                FlightLeg(direction: .outbound, number: "EW4241", airline: "Eurowings", from: "Berlin", to: "Prag",
                          date: "04.10.2026", departure: "08:10", arrival: "09:20", arriveBy: "06:30", bookingCode: "MOTION"),
                FlightLeg(direction: .inbound, number: "EW4242", airline: "Eurowings", from: "Prag", to: "Berlin",
                          date: "09.10.2026", departure: "18:05", arrival: "19:15", arriveBy: "16:20", bookingCode: "MOTION")
            ]
        }
        if ProcessInfo.processInfo.environment["ALBUM_DEMO_INBOX"] == "1" {
            data.places = [
                Place(id: "motion-inbox-bridge", title: "Karlsbrücke", category: "Sehenswert", author: "Mia",
                      image: .bundled(name: "imgPhotoCharlesBridge"), lat: 50.0865, lng: 14.4114),
                Place(id: "motion-inbox-cafe", title: "Café Slavia", category: "Essen & Trinken", author: "Mia",
                      image: .bundled(name: "imgThumbCafe"), lat: 50.0817, lng: 14.4125),
                Place(id: "motion-inbox-petrin", title: "Petřín", category: "Aussicht", author: "Mia",
                      image: .bundled(name: "imgPhotoLetna"), lat: 50.0831, lng: 14.3951)
            ]
        }
        if ProcessInfo.processInfo.environment["ALBUM_DEMO_IMAGE_CHOICE"] == "1",
           !data.places.contains(where: { $0.id == "image-choice-cafe" }) {
            data.places = [
                Place(id: "image-choice-cafe", title: "Café Louvre", category: "Essen & Trinken", author: "Luke",
                      address: "Národní 22, Praha 1", lat: 50.0819, lng: 14.4185, franked: true, plannedDate: TripInfo.legacyPragueStart, dayOrder: 0, approvals: ["Luke"])
            ]
        }
        #endif
        #if DEBUG
        let isAutomatedTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] != nil
        #else
        let isAutomatedTest = false
        #endif
        if !isAutomatedTest {
            let existingIDs = Set(data.places.map(\.id))
            let missingPragueIdeas = Place.examples.filter { $0.id.hasPrefix("prague-") && !existingIDs.contains($0.id) }
            if !missingPragueIdeas.isEmpty {
                data.places.append(contentsOf: missingPragueIdeas)
                data.dirty.formUnion(missingPragueIdeas.map(\.id))
                needsInitialPersist = true
            }

            // Refresh these untouched built-in ideas with their current official links and addresses.
            // Places edited or voted on by a traveler have a newer timestamp and remain untouched.
            let refreshedSeedIDs = ["prague-planetum-program", "prague-ghost-legends-tour"]
            for id in refreshedSeedIDs where existingIDs.contains(id) {
                guard let template = Place.examples.first(where: { $0.id == id }),
                      let index = data.places.firstIndex(where: { $0.id == id }),
                      data.places[index].updatedAt == .distantPast else { continue }
                var refreshed = template
                refreshed.updatedAt = Date()
                data.places[index] = refreshed
                data.dirty.insert(id)
                needsInitialPersist = true
            }
        }
        if !loadFailed, data.schemaVersion != 2, migrateLegacyPlanning(originalBytes: storedBytes) {
            needsInitialPersist = false
        }
        if legacyAlbumID, !persist() { shouldPublishShareContext = false }
        // The share extension may enqueue before the first in-app mutation. Persist
        // the generated installation identity before publishing its share context.
        if needsInitialPersist, !persist() { shouldPublishShareContext = false }
        guard shouldPublishShareContext else { return }
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil && ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] == nil { publishShareContext() }
        #else
        publishShareContext()
        #endif
    }

    static let legacyPlanningBackupName = "album.legacy-planning-backup.json"

    /// Einmalige Umstellung alter Tageszahlen auf Kalendertage. Vor dem Schreiben wird die
    /// Original-JSON gesichert; schlägt die Sicherung fehl, bleibt alles unverändert.
    private func migrateLegacyPlanning(originalBytes: Data?) -> Bool {
        let previous = data
        guard normalizeLegacyPlanning() else { return false }
        if let originalBytes {
            let backup = root.appendingPathComponent(Self.legacyPlanningBackupName)
            do {
                if !FileManager.default.fileExists(atPath: backup.path) {
                    try originalBytes.write(to: backup, options: .atomic)
                }
            } catch {
                data = previous
                self.error = "Die Reisedaten konnten nicht sicher umgestellt werden: \(error.localizedDescription)"
                return false
            }
        }
        guard persist() else { data = previous; return false }
        return true
    }

    /// Bringt Reise und Orte auf Planungsschema 2. Nur eine nachweislich alte Prag-Reise erhält
    /// 4.–9. Oktober 2026; andere alte Tageszahlen bleiben ungelöst und sichtbar.
    /// IDs, Stimmen, Fotos und Zeitstempel bleiben unverändert.
    @discardableResult func normalizeLegacyPlanning() -> Bool {
        var trip = data.trip
        let isPrague = Self.hasPragueIdentity(trip: trip, places: data.places)
        if isPrague, trip.planningSchemaVersion != 2, trip.startDate == nil, trip.endDate == nil {
            let known = TripInfo.legacyPrague()
            trip.title = trip.title ?? known.title
            trip.destination = trip.destination ?? known.destination
            trip.startDate = known.startDate
            trip.endDate = known.endDate
            trip.timeZoneIdentifier = trip.timeZoneIdentifier ?? known.timeZoneIdentifier
        }
        trip.planningSchemaVersion = 2
        let legacyRange = isPrague && trip.startDate == TripInfo.legacyPragueStart && trip.endDate == TripInfo.legacyPragueEnd
        var places = data.places
        for index in places.indices {
            if legacyRange, places[index].plannedDate == nil, let legacyDay = places[index].day, (4...9).contains(legacyDay) {
                places[index].plannedDate = TripDay(year: 2026, month: 10, day: legacyDay)
                places[index].day = nil
            }
            places[index].planningSchemaVersion = 2
        }
        let changed = trip != data.trip || places != data.places || data.schemaVersion != 2
        data.trip = trip
        data.places = places
        data.schemaVersion = 2
        return changed
    }

    private static func hasPragueIdentity(trip: TripInfo, places: [Place]) -> Bool {
        let destination = (trip.destination ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !destination.isEmpty { return containsPragueCityToken(destination) }
        let legacyHotel = trip.hotel.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines) == "hotel urban creme"
        return containsPragueCityToken(trip.title ?? "") || containsPragueCityToken(trip.route) || legacyHotel
            || places.contains { $0.id.hasPrefix("prague-") || $0.id == "example-letna" || $0.id == "example-oldtown" }
    }

    private static func containsPragueCityToken(_ value: String) -> Bool {
        let normalized = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let tokens = normalized.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
        return tokens.contains { ["prag", "prague", "praha"].contains($0) }
    }

    func tripDateValidationError(_ trip: TripInfo) -> String? {
        if (trip.startDate == nil) != (trip.endDate == nil) { return "Bitte wähle beide Reisedaten oder lasse den Zeitraum offen." }
        if let start = trip.startDate, let end = trip.endDate, end < start { return "Das Ende der Reise muss am oder nach dem Beginn liegen." }
        if trip.startDate != nil, !TripCalendar(trip: trip).isValidRange { return "Der Reisezeitraum darf höchstens 3.660 Kalendertage umfassen." }
        if let identifier = trip.timeZoneIdentifier, TimeZone(identifier: identifier) == nil { return "Bitte wähle eine gültige Zeitzone." }
        return nil
    }

    func placesOutsideRange(of trip: TripInfo) -> [Place] {
        let calendar = TripCalendar(trip: trip)
        return places.filter { place in
            guard let date = place.plannedDate else { return false }
            return !calendar.contains(date)
        }
    }

    func publishShareContext() {
        guard !loadFailed, persist() else { return }
        let key = data.collaboration.map { "trip:\($0.tripID.uuidString)" } ?? "local:\(data.albumID)"
        try? shareInbox.saveContext(ShareContext(tripKey: key, albumID: data.albumID))
    }

    func drainShareQueue() {
        let inbox = shareInbox
        let queued = inbox.items()
        shareQueueError = nil
        guard let context = inbox.loadContext() else {
            if !queued.isEmpty { shareQueueError = ShareInboxError.missingContext.localizedDescription; error = shareQueueError }
            shareQueueRevision += 1
            return
        }
        for var item in queued where item.state != .cancelled {
            if item.lastErrorCode == "queue-decode-failed" {
                shareQueueError = "Ein geteilter Beitrag ist beschädigt. Erneut versuchen oder verwerfen."
                continue
            }
            guard item.tripKey == context.tripKey else {
                item.state = .failed; item.lastErrorCode = "trip-mismatch"
                do { try inbox.update(item); shareQueueError = "Geteilter Beitrag gehört zu einer anderen Reise." } catch { shareQueueError = error.localizedDescription }
                continue
            }
            do {
                if let url = item.url {
                    _ = try addCollectionPost(text: "", url: url, caption: item.payload, deterministicID: item.id)
                } else {
                    _ = try addCollectionPost(text: item.payload, deterministicID: item.id)
                }
                try inbox.remove(item)
            } catch {
                item.attemptCount += 1
                item.state = .failed
                item.lastErrorCode = String(describing: error)
                do { try inbox.update(item); shareQueueError = "Ein geteilter Beitrag wartet auf einen erneuten Versuch." } catch { shareQueueError = error.localizedDescription }
            }
        }
        shareQueueRevision += 1
    }

    var isShared: Bool { data.collaboration != nil }
    var inviteURL: URL? {
        guard let token = data.collaboration?.inviteToken else { return nil }
        return InvitationLink.make(token: token)
    }

    @discardableResult func persist() -> Bool {
        guard !loadFailed else { return false }
        do { try JSONEncoder().encode(data).write(to: root.appendingPathComponent("album.json"), options: .atomic); return true }
        catch { self.error = "Speichern fehlgeschlagen: \(error.localizedDescription)"; return false }
    }

    @discardableResult func upsert(_ input: Place) -> Bool {
        var place = input; place.updatedAt = Date()
        let previous = data
        var oldImageToRemove: UploadedPlaceImage?
        if let index = data.places.firstIndex(where: { $0.id == place.id }) {
            let existing = data.places[index]
            if place.franked != existing.franked || place.plannedDate != existing.plannedDate
                || place.day != existing.day || place.dayOrder != existing.dayOrder
                || place.planningSchemaVersion != existing.planningSchemaVersion {
                place.planningUpdatedAt = Date()
            }
            if !place.deleted, case .uploaded(let oldImage) = data.places[index].image,
               case .uploaded(let newImage) = place.image, oldImage.id == newImage.id {
            } else if case .uploaded(let oldImage) = data.places[index].image {
                oldImageToRemove = oldImage
                if let path = oldImage.storagePath { data.dirty.insert("image-delete:" + path) }
                if place.deleted { place.image = nil }
            }
            data.places[index] = place
        } else {
            if place.franked || place.plannedDate != nil || place.day != nil || place.dayOrder != nil {
                place.planningUpdatedAt = place.planningUpdatedAt ?? Date()
            }
            data.places.append(place)
        }
        data.dirty.insert(place.id)
        let saved = persist()
        if saved {
            if let oldImageToRemove { PlaceImageStorage.remove(oldImageToRemove, root: root) }
            scheduleSync()
        } else {
            data = previous
        }
        return saved
    }

    var tripMemories: [TripMemoryPhoto] { data.tripMemories.filter { !$0.deleted }.sorted { $0.createdAt > $1.createdAt } }

    func tripMemoryURL(for photo: TripMemoryPhoto, thumbnail: Bool = false) -> URL {
        TripMemoryStorage.localURL(for: photo, thumbnail: thumbnail, root: root)
    }

    @discardableResult func addTripMemory(data source: Data, caption: String = "", placeID: String? = nil) -> TripMemoryPhoto? {
        guard !loadFailed else { return nil }
        let previous = data
        do {
            let photo = try TripMemoryStorage.save(source, root: root, placeID: placeID, caption: caption, authorName: me)
            data.tripMemories.append(photo)
            data.tripMemorySync[photo.id] = TripMemorySyncMetadata(serverVersion: nil, mutationToken: UUID().uuidString)
            data.dirty.insert("photo-" + photo.id)
            guard persist() else { data = previous; TripMemoryStorage.remove(photo, root: root); return nil }
            scheduleSync()
            return photo
        } catch {
            self.error = "Foto konnte nicht gespeichert werden: \(error.localizedDescription)"
            return nil
        }
    }

    @discardableResult func updateTripMemory(_ input: TripMemoryPhoto) -> Bool {
        guard !loadFailed, let index = data.tripMemories.firstIndex(where: { $0.id == input.id && !$0.deleted }) else { return false }
        let previous = data
        data.tripMemories[index] = input
        data.tripMemorySync[input.id] = TripMemorySyncMetadata(serverVersion: data.tripMemorySync[input.id]?.serverVersion,
                                                               mutationToken: UUID().uuidString)
        data.dirty.insert("photo-" + input.id)
        guard persist() else { data = previous; return false }
        scheduleSync()
        return true
    }

    @discardableResult func deleteTripMemory(id: String) -> Bool {
        guard !loadFailed, let index = data.tripMemories.firstIndex(where: { $0.id == id && !$0.deleted }) else { return false }
        let previous = data
        data.tripMemories[index].deleted = true
        data.tripMemorySync[id] = TripMemorySyncMetadata(serverVersion: data.tripMemorySync[id]?.serverVersion,
                                                         mutationToken: UUID().uuidString)
        data.dirty.insert("photo-" + id)
        guard persist() else { data = previous; return false }
        scheduleSync()
        return true
    }

    /// Saves assistant place recommendations into the shared Ideas inbox in one local commit.
    /// Existing suggestions are reused by title or source URL, so retrying is idempotent.
    func saveAssistantIdeas(_ suggestions: [AssistantPlace]) -> (added: Int, restored: Int, existing: Int) {
        guard !loadFailed, !suggestions.isEmpty else { return (0, 0, 0) }
        let previous = data
        var added = 0
        var restored = 0
        var existingCount = 0

        for suggestion in suggestions {
            let title = suggestion.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            let normalizedTitle = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            let matchIndex = data.places.firstIndex { place in
                let sameTitle = place.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX")) == normalizedTitle
                let suggestedURL = suggestion.sourceURL ?? ""
                let sameSource = !suggestedURL.isEmpty && place.sourceURL == suggestedURL
                return sameTitle || sameSource
            }

            if let matchIndex {
                var place = data.places[matchIndex]
                if place.deleted { place.deleted = false }
                let wasHidden = place.deferred || place.passedBy.contains(me)
                place.deferred = false
                place.passedBy.removeAll { $0 == me }
                place.updatedAt = Date()
                data.places[matchIndex] = place
                if wasHidden { restored += 1 } else { existingCount += 1 }
                if !place.deleted { data.dirty.insert(place.id) }
            } else {
                let place = Place(
                    title: title,
                    note: "Vom Reise-Assistenten vorgeschlagen.",
                    sourceURL: suggestion.sourceURL ?? "",
                    category: "Idee",
                    author: me,
                    address: suggestion.address
                )
                data.places.append(place)
                data.dirty.insert(place.id)
                added += 1
            }
        }

        guard added + restored > 0 else { return (added, restored, existingCount) }
        guard persist() else {
            data = previous
            return (0, 0, 0)
        }
        scheduleSync()
        return (added, restored, existingCount)
    }

    func scheduleCollectionSync() { scheduleSync() }

    private func scheduleSync() {
        guard isShared else { return }
        pendingSync?.cancel()
        pendingSync = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            await self?.sync()
        }
    }

    func deferPlace(_ place: Place) { var p = place; p.deferred = true; upsert(p) }
    func restoreDeferred(_ place: Place) {
        guard deferred.contains(where: { $0.id == place.id }),
              var current = places.first(where: { $0.id == place.id }) else { return }
        current.deferred = false
        current.passedBy.removeAll { $0 == me }
        upsert(current)
    }
    func restoreDeferred() {
        for place in deferred { restoreDeferred(place) }
    }

    /// Setzt einen Ort ans Ende eines Reisetags (oder nimmt ihn aus der Tagesplanung).
    func assign(_ place: Place, toDate date: TripDay?) {
        if let date, !tripCalendar.contains(date) { return }
        var p = place
        p.plannedDate = date
        p.franked = true
        p.planningSchemaVersion = 2
        p.planningUpdatedAt = Date()
        p.day = nil
        p.dayOrder = date.map { day in
            (franked.filter { $0.plannedDate == day && $0.id != place.id }.compactMap(\.dayOrder).max() ?? -1) + 1
        }
        upsert(p)
    }

    /// Neue Reihenfolge eines Reisetags nach dem Verschieben in der Liste.
    func reorder(date: TripDay, ids: [String]) {
        for (index, id) in ids.enumerated() {
            guard var p = places.first(where: { $0.id == id }), p.plannedDate == date, p.dayOrder != index else { continue }
            p.dayOrder = index; p.planningSchemaVersion = 2; upsert(p)
        }
    }

    /// Optionale Startkoordinate aus dem tatsächlichen Reiseziel, ohne Prag-Fallback.
    var hotelCoordinate: CLLocationCoordinate2D? { tripAnchorCoordinate }

    private func currentDayPlan(keepAssigned: Bool) -> DayPlanProposal {
        var proposal = DayPlanGenerator.plan(places: franked, hotel: hotelCoordinate, flights: data.trip.flights ?? [],
                                             calendar: tripCalendar, keepAssigned: keepAssigned)
        proposal.sourceAlbumID = data.albumID
        return proposal
    }

    /// Holt fehlende Öffnungszeiten (einmal pro Ort) und rechnet einen Tagesplan-Vorschlag.
    func proposeDayPlan(keepAssigned: Bool) async -> DayPlanProposal {
        let candidates = franked.filter { $0.openingHours == nil && $0.coordinate != nil && $0.category != "Unterkunft" }
        let resolver = openingHoursResolver
        var results: [OpeningHoursFetchResult] = []

        // Drei gleichzeitige Abfragen begrenzen die Netzlast; fehlende Ergebnisse bleiben offen.
        for batchStart in stride(from: 0, to: candidates.count, by: 3) {
            guard !Task.isCancelled else {
                return currentDayPlan(keepAssigned: keepAssigned)
            }
            let batch = Array(candidates[batchStart..<min(batchStart + 3, candidates.count)])
            let batchResults = await withTaskGroup(of: OpeningHoursFetchResult.self) { group in
                for place in batch {
                    let request = OpeningHoursRequest(
                        id: place.id,
                        title: place.title,
                        address: place.address,
                        category: place.category,
                        latitude: place.lat!,
                        longitude: place.lng!
                    )
                    group.addTask { @MainActor in
                        guard !Task.isCancelled else { return OpeningHoursFetchResult(id: request.id, hours: nil) }
                        let requestPlace = Place(id: request.id, title: request.title, category: request.category,
                                                  address: request.address, lat: request.latitude, lng: request.longitude,
                                                  franked: true)
                        let hours = if let resolver {
                            await resolver(requestPlace)
                        } else {
                            await OpeningHoursService.fetch(for: requestPlace)
                        }
                        return OpeningHoursFetchResult(id: request.id, hours: hours)
                    }
                }
                var collected: [OpeningHoursFetchResult] = []
                while let result = await group.next() {
                    if Task.isCancelled {
                        group.cancelAll()
                    } else {
                        collected.append(result)
                    }
                }
                return collected
            }
            guard !Task.isCancelled else {
                return currentDayPlan(keepAssigned: keepAssigned)
            }
            results.append(contentsOf: batchResults)
        }

        guard !Task.isCancelled else {
            return currentDayPlan(keepAssigned: keepAssigned)
        }

        for result in results {
            guard let hours = result.hours,
                  let place = candidates.first(where: { $0.id == result.id }),
                  var current = data.places.first(where: { $0.id == place.id }),
                  current.title == place.title,
                  current.address == place.address,
                  current.lat == place.lat,
                  current.lng == place.lng,
                  current.category == place.category,
                  current.openingHours == place.openingHours else { continue }
            current.openingHours = hours
            _ = upsert(current)
        }
        return currentDayPlan(keepAssigned: keepAssigned)
    }

    /// Übernimmt den Vorschlag als einen atomaren Persistenzschritt.
    /// Ein Vorschlag gilt nur für das Album und den Reisezeitraum, aus dem er berechnet wurde.
    @discardableResult func apply(_ proposal: DayPlanProposal) -> Bool {
        guard proposal.sourceAlbumID == nil || proposal.sourceAlbumID == data.albumID,
              proposal.calendarSnapshot == tripCalendar.snapshot,
              proposal.days.keys.allSatisfy({ tripCalendar.contains($0) }) else { return false }
        let previous = data
        let commitDate = Date()
        var changed = false
        for (day, stops) in proposal.days {
            for (index, stop) in stops.enumerated() {
                // Vorschläge dürfen keine veralteten, gelöschten oder nicht mehr beschlossenen Orte schreiben.
                guard var place = franked.first(where: { $0.id == stop.id }) else { continue }
                guard place.plannedDate != day || place.dayOrder != index else { continue }
                place.plannedDate = day
                place.planningSchemaVersion = 2
                place.day = nil
                place.dayOrder = index
                place.planningUpdatedAt = commitDate
                place.updatedAt = commitDate
                if let placeIndex = data.places.firstIndex(where: { $0.id == place.id }) {
                    data.places[placeIndex] = place
                    data.dirty.insert(place.id)
                    changed = true
                }
            }
        }
        guard changed else { return true }
        guard persist() else {
            data = previous
            return false
        }
        scheduleSync()
        return true
    }

    /// Atomically restores only the day fields recorded by AssistantActions.
    /// All other fields, including edits made to unrelated places, are retained.
    /// This is a local optimistic commit; the existing sync layer does not expose
    /// a server-side CAS for place rows yet.
    @discardableResult func applyAssistantDayAssignments(_ assignments: [AssistantActions.DayAssignment]) -> Bool {
        let ids = assignments.map(\.placeID)
        guard Set(ids).count == ids.count,
              assignments.allSatisfy({ assignment in
                  data.places.contains(where: { $0.id == assignment.placeID })
                      && (assignment.date.map { tripCalendar.contains($0) } ?? true)
              }) else {
            return false
        }

        let previous = data
        let commitDate = Date()
        var changed = false
        for assignment in assignments {
            guard let index = data.places.firstIndex(where: { $0.id == assignment.placeID }) else {
                data = previous
                return false
            }
            let current = data.places[index]
            guard current.plannedDate != assignment.date || current.dayOrder != assignment.dayOrder
                    || current.day != assignment.legacyDay else {
                continue
            }
            data.places[index].plannedDate = assignment.date
            data.places[index].planningSchemaVersion = 2
            data.places[index].day = assignment.legacyDay
            data.places[index].dayOrder = assignment.dayOrder
            data.places[index].planningUpdatedAt = commitDate
            data.places[index].updatedAt = commitDate
            data.dirty.insert(assignment.placeID)
            changed = true
        }
        guard changed else { return true }
        guard persist() else {
            data = previous
            return false
        }
        scheduleSync()
        return true
    }

    /// Orte eines Reisetags in geplanter Reihenfolge.
    func plan(for date: TripDay) -> [Place] {
        franked.filter { $0.plannedDate == date }.sorted { ($0.dayOrder ?? .max, $0.title) < ($1.dayOrder ?? .max, $1.title) }
    }

    func stops(for date: TripDay) -> [PlanStop] {
        let calendar = tripCalendar
        let window = DayPlanGenerator.windows(flights: data.trip.flights ?? [], calendar: calendar)[date]
            ?? DayPlanGenerator.Window(start: 10 * 60, end: 22 * 60)
        return DayPlanGenerator.timeline(plan(for: date), day: date, window: window, start: hotelCoordinate, calendar: calendar)
    }

    @discardableResult func saveExpense(_ expense: TravelExpense) -> Bool {
        var trip = data.trip
        var entries = trip.expenses ?? []
        var saved = expense
        if let index = entries.firstIndex(where: { $0.id == expense.id }) {
            let existing = entries[index]
            guard existing.deletedAt == nil else { return false }
            saved.createdAt = existing.createdAt
            saved.deletedAt = nil
            saved.updatedAt = max(Date(), existing.updatedAt.addingTimeInterval(0.001))
            entries[index] = saved
        } else {
            saved.updatedAt = Date()
            entries.append(saved)
        }
        trip.expenses = entries
        return updateTrip(trip)
    }

    @discardableResult func deleteExpense(id: String, now: Date = Date()) -> Bool {
        var trip = data.trip
        guard var entries = trip.expenses,
              let index = entries.firstIndex(where: { $0.id == id }), entries[index].deletedAt == nil else { return false }
        let timestamp = max(now, entries[index].updatedAt.addingTimeInterval(0.001))
        entries[index].deletedAt = timestamp
        entries[index].updatedAt = timestamp
        trip.expenses = entries
        return updateTrip(trip)
    }

    @discardableResult func updateTrip(_ trip: TripInfo) -> Bool {
        guard tripDateValidationError(trip) == nil else { return false }
        let previous = data
        let oldDestination = data.trip.destination ?? tripName
        data.trip = trip; data.trip.updatedAt = Date(); data.trip.planningSchemaVersion = 2
        data.schemaVersion = 2; data.dirty.insert("trip")
        if persist() {
            if oldDestination != (trip.destination ?? tripName) { storedDiscoverySession?.destinationDidChange() }
            scheduleSync()
            return true
        } else {
            data = previous
            return false
        }
    }

    func discoveryAdoptionStatus(_ item: DiscoveryItem) -> DiscoveryAdoptionResult? {
        let placeID = "discovery-\(item.qid.lowercased())"
        let canonical = "https://www.wikidata.org/wiki/\(item.qid)"
        let normalized = Self.normalizedDiscoveryTitle(item.name)
        guard let existing = data.places.first(where: { place in
            if place.id == placeID || Self.isDiscoverySource(place.sourceURL, qid: item.qid) { return true }
            guard let coordinate = place.coordinate, Self.normalizedDiscoveryTitle(place.title) == normalized else { return false }
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                .distance(from: CLLocation(latitude: item.latitude, longitude: item.longitude)) <= 100
        }) else { return nil }
        return existing.deleted ? .removed(placeID: existing.id)
            : .alreadyPresent(placeID: existing.id, planned: existing.plannedDate != nil || existing.day != nil)
    }

    private static func normalizedDiscoveryTitle(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let scalars = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(scalars).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func isDiscoverySource(_ value: String, qid: String) -> Bool {
        guard let url = URLComponents(string: value), url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "www.wikidata.org" else { return false }
        return url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "wiki/\(qid)"
    }

    @discardableResult func restoreDiscoveryPlace(id: String) -> Bool {
        guard let index = data.places.firstIndex(where: { $0.id == id && $0.deleted }) else { return false }
        var place = data.places[index]; place.deleted = false
        return upsert(place)
    }

    @discardableResult func adoptDiscoveryItem(_ item: DiscoveryItem) -> DiscoveryAdoptionResult {
        let placeID = "discovery-\(item.qid.lowercased())"
        let canonical = "https://www.wikidata.org/wiki/\(item.qid)"
        if let status = discoveryAdoptionStatus(item) { return status }
        var place = Place(id: placeID, title: item.name, sourceURL: canonical,
                          category: item.interests.contains(.viewpoints) ? "Aussicht" : "Sehenswert",
                          author: me, lat: item.latitude, lng: item.longitude)
        if let image = item.image, image.confidence == .verified {
            place.image = .external(ExternalPlaceImage(
                imageURL: image.imageURL.absoluteString, sourceURL: image.sourceURL.absoluteString,
                credit: image.credit, provider: .wikimedia, licenseName: image.licenseName,
                licenseURL: image.licenseURL.absoluteString, providerPlaceID: item.qid,
                resolvedFor: ResolvedPlaceIdentity(title: item.name, latitude: item.latitude,
                                                   longitude: item.longitude, category: place.category, address: ""),
                ranking: PlaceImageService.ranking, userSelected: false))
        }
        guard upsert(place) else { return .failed }
        return .added(placeID: placeID)
    }

    func placeImageStatus(for placeID: String) -> PlaceImageStatus {
        if let status = placeImageStatuses[placeID] { return status }
        guard let place = places.first(where: { $0.id == placeID }) else { return .idle }
        return place.image == nil ? .idle : .ready
    }

    func refreshPlaceImages(force: Bool = false) async {
        var attempted = 0
        let orderedPlaces = places.enumerated().sorted { left, right in
            let leftPriority = left.element.image == nil && Self.isMapProviderSource(left.element.sourceURL)
            let rightPriority = right.element.image == nil && Self.isMapProviderSource(right.element.sourceURL)
            if leftPriority != rightPriority { return leftPriority }
            return left.offset < right.offset
        }.map(\.element)
        for place in orderedPlaces {
            guard !Task.isCancelled, attempted < 5 else { return }
            let context = tripRegionContext(for: place)
            if place.coordinate == nil {
                let snapshot = PlaceResolutionSnapshot(title: place.title, address: place.address,
                                                       category: place.category, context: context,
                                                       albumID: data.albumID, trip: data.trip)
                if !force, placeResolutionAttempts.contains(place.id), placeResolutionSnapshots[place.id] == snapshot { continue }
            } else {
                if PlaceImageService.isUserChosen(place.image) { continue }
                let imageKey = "\(place.id)|\(place.title)|\(place.lat ?? 0)|\(place.lng ?? 0)|\(place.category)|\(place.address)|\(contextAttemptKey(context))"
                if !force, placeImageAttempts.contains(imageKey) { continue }
                if !force, !PlaceImageService.shouldSearch(for: place, force: false), !PlaceImageService.needsGallery(place) { continue }
            }
            attempted += 1
            await refreshPlaceImage(id: place.id, force: force)
        }
    }

    func refreshPlaceImage(id: String, force: Bool = false) async {
        guard !placeImageInFlight.contains(id), let requested = places.first(where: { $0.id == id }) else { return }
        var context = tripRegionContext(for: requested)
        var snapshot = PlaceResolutionSnapshot(title: requested.title, address: requested.address,
                                               category: requested.category, context: context,
                                               albumID: data.albumID, trip: data.trip)
        if requested.coordinate == nil {
            if !force, placeResolutionAttempts.contains(id), placeResolutionSnapshots[id] == snapshot { return }
            placeResolutionAttempts.insert(id)
            placeResolutionSnapshots[id] = snapshot
            placeImageInFlight.insert(id)
            placeImageStatuses[id] = .resolvingPlace
            defer { placeImageInFlight.remove(id) }

            let outcome: PlaceResolutionOutcome
            if let resolver = placeResolutionResolver {
                outcome = await resolver(requested, context)
            } else if isAutomatedTestStore {
                outcome = context.source == .none ? .needsReview([], .missingContext) : .failed(retryable: false)
            } else {
                outcome = await PlaceResolver.resolve(place: requested, context: context)
            }
            guard !Task.isCancelled else {
                placeImageStatuses[id] = .idle
                placeResolutionAttempts.remove(id)
                placeResolutionSnapshots[id] = nil
                return
            }
            guard isCurrentResolutionRequest(requested, snapshot: snapshot) else {
                placeImageStatuses[id] = .idle
                placeResolutionAttempts.remove(id)
                placeResolutionSnapshots[id] = nil
                return
            }
            switch outcome {
            case .resolved(let candidate):
                guard Self.valid(candidate) else { placeImageStatuses[id] = .failed(retryable: false); return }
                guard apply(candidate, to: requested), let updated = places.first(where: { $0.id == id }) else {
                    placeImageStatuses[id] = .failed(retryable: true); return
                }
                context = tripRegionContext(for: updated)
                snapshot = PlaceResolutionSnapshot(title: updated.title, address: updated.address,
                                                   category: updated.category, context: context,
                                                   albumID: data.albumID, trip: data.trip)
                placeResolutionSnapshots[id] = nil
                placeResolutionAttempts.remove(id)
            case .needsReview(let candidates, let reason):
                placeImageStatuses[id] = .needsReview(Array(candidates.prefix(5)), reason)
                return
            case .notFound:
                placeImageStatuses[id] = .notFound
                return
            case .failed(let retryable):
                placeImageStatuses[id] = .failed(retryable: retryable)
                return
            }
        }

        guard let current = places.first(where: { $0.id == id }), current.coordinate != nil else { return }
        if PlaceImageService.isUserChosen(current.image) {
            placeImageStatuses[id] = .ready
            return
        }
        let imageKey = "\(id)|\(current.title)|\(current.lat ?? 0)|\(current.lng ?? 0)|\(current.category)|\(current.address)|\(contextAttemptKey(context))"
        if !force, placeImageAttempts.contains(imageKey) { return }
        if !force, !PlaceImageService.shouldSearch(for: current, force: false), !PlaceImageService.needsGallery(current) {
            placeImageStatuses[id] = .ready
            return
        }
        placeImageAttempts.insert(imageKey)
        placeImageInFlight.insert(id)
        placeImageStatuses[id] = .loadingPhoto
        defer { placeImageInFlight.remove(id) }

        do {
            var result: PlaceImageSearchResult?
            var searchFailed = false
            do {
                if let resolver = placeImageSearchResolver {
                    result = try await resolver(current, context)
                } else if isAutomatedTestStore {
                    result = .init(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking)
                } else {
                    result = try await PlaceImageService.search(for: current, region: context.name,
                                                                languageCode: context.preferredLanguageCode)
                }
            } catch {
                searchFailed = true
            }
            guard !Task.isCancelled else {
                placeImageStatuses[id] = .idle
                placeImageAttempts.remove(imageKey)
                return
            }
            guard let latest = places.first(where: { $0.id == id }),
                  PlaceImageService.matchesRequest(current, latest), latest.image == current.image,
                  data.albumID == snapshot.albumID, data.trip == snapshot.trip,
                  tripRegionContext(for: latest) == context else {
                placeImageStatuses[id] = .idle
                placeImageAttempts.remove(imageKey)
                return
            }
            let found = result?.automaticImages ?? []
            let needsImage = PlaceImageService.shouldSearch(for: current, force: force)
            var updated = latest
            var resolvedImage = false
            if needsImage, let best = found.first {
                updated.image = best.asset(for: updated)
                updated.gallery = PlaceImageService.gallery(from: found, for: updated)
                resolvedImage = true
            } else if needsImage, PlaceImageService.canUseSourcePreview(for: latest) {
                let preview: PlaceImage?
                if let resolver = placeSourcePreviewResolver {
                    preview = await resolver(latest, context)
                } else if isAutomatedTestStore {
                    preview = nil
                } else {
                    preview = await PlaceImageService.sourcePreview(for: latest)
                }
                guard !Task.isCancelled else {
                    placeImageStatuses[id] = .idle
                    placeImageAttempts.remove(imageKey)
                    return
                }
                guard let latestAfterPreview = places.first(where: { $0.id == id }),
                      PlaceImageService.matchesRequest(current, latestAfterPreview),
                      latestAfterPreview.sourceURL == current.sourceURL,
                      PlaceImageService.canUseSourcePreview(for: latestAfterPreview), latestAfterPreview.image == latest.image,
                      data.albumID == snapshot.albumID, data.trip == snapshot.trip,
                      tripRegionContext(for: latestAfterPreview) == context else {
                    placeImageStatuses[id] = .idle
                    placeImageAttempts.remove(imageKey)
                    return
                }
                if let preview, preview.provider == .sourcePreview, preview.confidence == .suggested {
                    updated = latestAfterPreview
                    updated.image = preview.asset(for: updated)
                    updated.gallery = []
                    resolvedImage = true
                }
            }
            if !resolvedImage, needsImage, result?.isCurrent == true, found.isEmpty,
                      Self.isStaleAutomaticWikimedia(updated.image) {
                // A current ranking response supersedes old automatic Wikimedia assets; failures do not.
                updated.image = nil
                updated.gallery = []
                resolvedImage = true
            } else if !resolvedImage, !needsImage, result?.isCurrent == true {
                let gallery = PlaceImageService.gallery(from: found, for: updated)
                if !gallery.isEmpty { updated.gallery = gallery }
            } else if !resolvedImage, needsImage, !isAutomatedTestStore,
                      !PlaceImageService.canRetain(updated.image, for: updated),
                      let coordinate = updated.coordinate {
                let local = await PlaceImageResolver.localSnapshot(at: coordinate)
                guard !Task.isCancelled else {
                    placeImageStatuses[id] = .idle
                    placeImageAttempts.remove(imageKey)
                    return
                }
                guard data.albumID == snapshot.albumID, data.trip == snapshot.trip,
                      tripRegionContext(for: updated) == context,
                      let latestAfterSnapshot = places.first(where: { $0.id == id }),
                      PlaceImageService.matchesRequest(current, latestAfterSnapshot),
                      latestAfterSnapshot.image == latest.image else {
                    placeImageStatuses[id] = .idle
                    placeImageAttempts.remove(imageKey)
                    return
                }
                if let local {
                    updated = latestAfterSnapshot
                    var uploaded = try PlaceImageStorage.save(local.data, root: root)
                    uploaded.resolvedFor = ResolvedPlaceIdentity(title: updated.title, latitude: coordinate.latitude,
                                                                  longitude: coordinate.longitude, category: updated.category,
                                                                  address: updated.address)
                    uploaded.generatedSource = local.source
                    updated.image = .uploaded(uploaded)
                    updated.gallery = []
                    resolvedImage = true
                }
            }
            if updated != latest, !upsert(updated) { placeImageStatuses[id] = .failed(retryable: true); return }
            if searchFailed, updated == latest {
                placeImageStatuses[id] = .failed(retryable: true)
            } else {
                placeImageStatuses[id] = (updated.displayImage == nil && needsImage) ? .notFound : .ready
            }
        } catch {
            if Task.isCancelled {
                placeImageStatuses[id] = .idle
                placeImageAttempts.remove(imageKey)
            } else {
                placeImageStatuses[id] = .failed(retryable: true)
            }
        }
    }

    func acceptPlaceResolution(placeID: String, candidate: PlaceResolutionCandidate) async {
        guard case .needsReview(let candidates, _) = placeImageStatus(for: placeID),
              candidates.contains(candidate), Self.valid(candidate),
              let place = places.first(where: { $0.id == placeID }), place.coordinate == nil,
              let snapshot = placeResolutionSnapshots[placeID], isCurrentResolutionRequest(place, snapshot: snapshot),
              apply(candidate, to: place) else { return }
        placeResolutionSnapshots[placeID] = nil
        placeResolutionAttempts.remove(placeID)
        await refreshPlaceImage(id: placeID, force: true)
    }

    private func contextAttemptKey(_ context: TripRegionContext) -> String {
        let region = context.region.map {
            "\($0.center.latitude),\($0.center.longitude),\($0.span.latitudeDelta),\($0.span.longitudeDelta)"
        } ?? "none"
        return "\(context.source)|\(context.name ?? "")|\(region)|\(context.preferredLanguageCode ?? "")"
    }

    private static func isMapProviderSource(_ value: String) -> Bool {
        guard let url = URL(string: value) else { return false }
        return PlaceLinkMetadata.isMapProviderURL(url)
    }

    private func isCurrentResolutionRequest(_ requested: Place, snapshot: PlaceResolutionSnapshot) -> Bool {
        guard let current = places.first(where: { $0.id == requested.id }) else { return false }
        return current.coordinate == nil && current.title == snapshot.title && current.address == snapshot.address
            && current.category == snapshot.category && data.albumID == snapshot.albumID
            && data.trip == snapshot.trip && tripRegionContext(for: current) == snapshot.context
    }

    private func apply(_ candidate: PlaceResolutionCandidate, to requested: Place) -> Bool {
        guard var current = places.first(where: { $0.id == requested.id }), current.coordinate == nil,
              current.title == requested.title, current.address == requested.address,
              Self.valid(candidate) else { return false }
        current.lat = candidate.latitude
        current.lng = candidate.longitude
        if !candidate.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { current.address = candidate.address }
        if !PlaceImageService.isUserChosen(current.image), PlaceImageService.shouldDiscardImageAfterLocationMove(current.image) {
            current.image = nil
            current.gallery = nil
        }
        return upsert(current)
    }

    private static func isStaleAutomaticWikimedia(_ asset: PlaceImageAsset?) -> Bool {
        guard case .external(let image) = asset else { return false }
        return image.provider == .wikimedia && image.userSelected != true
            && (image.ranking ?? 1) < PlaceImageService.ranking
    }

    private static func valid(_ candidate: PlaceResolutionCandidate) -> Bool {
        candidate.latitude.isFinite && candidate.longitude.isFinite
            && (-90...90).contains(candidate.latitude) && (-180...180).contains(candidate.longitude)
    }

    /// Beim Öffnen eines PDFs von außen gelesen; die Startansicht bietet es zum Übernehmen an.
    var pendingExtraction: ExtractedTrip?

    /// Liest Flüge, Hotel und Buchungsdaten aus einem gespeicherten PDF.
    func extraction(from document: TravelDocument) -> ExtractedTrip {
        TripDocumentParser.parse(document.extractedText)
    }

    /// Übernimmt Gelesenes in die Reisedaten und legt das Hotel als Unterkunft auf die Karte.
    func applyExtraction(_ extracted: ExtractedTrip) async {
        guard updateTrip(extracted.applied(to: data.trip)) else { return }
        guard let name = extracted.hotel.name, let address = extracted.hotel.address else { return }
        let id = "hotel-" + (extracted.bookingNumber ?? name).lowercased().filter { $0.isLetter || $0.isNumber }
        var place = places.first { $0.id == id } ?? Place(id: id, title: name, note: "", category: "Unterkunft", author: "Wir")
        place.title = name; place.address = address; place.franked = true; place.deferred = false
        if extracted.hotel.checkIn != nil || extracted.hotel.checkOut != nil {
            place.note = ["Check-in \(extracted.hotel.checkIn ?? "–")", "Check-out \(extracted.hotel.checkOut ?? "–")"].joined(separator: " · ")
        }
        guard upsert(place) else { return }
        if place.coordinate == nil, let coordinate = await geocodeAddress(address) {
            guard var current = data.places.first(where: { $0.id == place.id }),
                  current.title == place.title,
                  current.address == place.address,
                  current.coordinate == nil else {
                await refreshPlaceImages()
                return
            }
            current.lat = coordinate.latitude; current.lng = coordinate.longitude
            _ = upsert(current)
        }
        await refreshPlaceImages()
    }

    private func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
        if let geocodeAddressResolver { return await geocodeAddressResolver(address) }
        if isAutomatedTestStore { return nil }
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(address)
            return placemarks.first?.location?.coordinate
        } catch {
            return nil
        }
    }

    func importPDF(_ url: URL, id: String = UUID().uuidString) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let document = PDFDocument(url: url) else { throw CocoaError(.fileReadCorruptFile) }
        guard !document.isLocked else { throw CocoaError(.fileReadNoPermission) }
        let size = (try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
        guard size <= 25_000_000 else { throw NSError(domain: "Album", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bitte ein PDF unter 25 MB verwenden."]) }
        let name = id + ".pdf"
        let destination = root.appendingPathComponent(name)
        let copiedDestination = !FileManager.default.fileExists(atPath: destination.path)
        if copiedDestination { try FileManager.default.copyItem(at: url, to: destination) }
        let previous = data
        if !data.documents.contains(where: { $0.id == id }) {
            data.documents.append(TravelDocument(id: id, name: url.deletingPathExtension().lastPathComponent, filename: name, extractedText: String((document.string ?? "").prefix(100_000))))
        }
        data.dirty.insert("doc-" + id)
        if !persist() {
            data = previous
            if copiedDestination { try? FileManager.default.removeItem(at: destination) }
            throw CocoaError(.fileWriteUnknown)
        }
        scheduleSync()
    }

    /// Refreshes the local view before a user-confirmed assistant mutation.
    /// A successful return means the current sync pass completed; it is still a
    /// best-effort freshness check because place writes have no server CAS yet.
    @discardableResult func refreshForAssistantApply() async -> Bool {
        guard !loadFailed else { return false }
        guard isShared else { return true }
        return await sync()
    }

    @discardableResult func sync() async -> Bool {
        guard isShared, !loadFailed else { return !loadFailed }
        if syncing {
            syncRequestedWhileRunning = true
            return false
        }
        syncing = true; syncStatus = "Album wird abgeglichen …"
        var succeeded = false
        defer {
            syncing = false
            if succeeded && syncRequestedWhileRunning {
                syncRequestedWhileRunning = false
                scheduleSync()
            } else if !succeeded {
                syncRequestedWhileRunning = false
            }
        }
        let before = data.places
        let oldDestination = data.trip.destination ?? tripName
        do {
            let service = try service()
            try await service.sync(store: self)
            if oldDestination != (data.trip.destination ?? tripName) { storedDiscoverySession?.destinationDidChange() }
            // Beim ersten Abgleich ist alles neu; das ist keine Neuigkeit der anderen Person.
            if !before.isEmpty { syncChange = SyncChange.between(before: before, after: data.places, me: me) ?? syncChange }
            service.startRealtime { [weak self] in await self?.sync() }
            syncStatus = "Synchronisiert"
            succeeded = true
        } catch {
            syncStatus = "Lokal gespeichert · Synchronisierung nicht erreichbar"
            for id in data.dirty.compactMap({ $0.hasPrefix("collection:") ? String($0.dropFirst("collection:".count)) : nil }) {
                if var metadata = data.collectionSync[id] { metadata.lastErrorCode = String(describing: error); data.collectionSync[id] = metadata }
            }
            _ = persist()
            self.error = error.localizedDescription
        }
        return succeeded
    }

    func createSharedTrip() async throws -> URL {
        guard !loadFailed else { throw CocoaError(.fileReadCorruptFile) }
        let discovery = discoverySession
        let service = try service()
        data.dirty.formUnion(data.places.map(\.id))
        data.dirty.formUnion(data.documents.map { "doc-" + $0.id })
        data.dirty.insert("trip")
        guard persist() else { throw CocoaError(.fileWriteUnknown) }
        data.collaboration = try await service.createTrip(store: self)
        discovery.switchToCurrentScope(copyLocal: true)
        publishShareContext()
        guard persist() else { throw CocoaError(.fileWriteUnknown) }
        service.startRealtime { [weak self] in await self?.sync() }
        guard let url = inviteURL else { throw AlbumSyncError.invalidInvitation }
        syncStatus = "Album kann geteilt werden"
        return url
    }

    func joinSharedTrip(url: URL) async throws {
        guard let token = InvitationLink.token(from: url) else { throw AlbumSyncError.invalidInvitation }
        let service = try service()
        let discovery = discoverySession
        data.collaboration = try await service.joinTrip(token: token)
        publishShareContext()
        guard persist() else { throw CocoaError(.fileWriteUnknown) }
        try await service.sync(store: self)
        discovery.switchToCurrentScope(copyLocal: false)
        service.startRealtime { [weak self] in await self?.sync() }
        syncStatus = "Album verbunden"
    }

    private func service() throws -> AlbumSyncService {
        if let syncService { return syncService }
        let service = try SupabaseSync.configured()
        syncService = service
        return service
    }

    func refreshAuthenticatedUserID() async {
        guard isShared else { authenticatedUserID = nil; return }
        do { authenticatedUserID = try await service().authenticatedUserID().lowercased() }
        catch { authenticatedUserID = nil }
    }
}
