import SwiftUI
import PDFKit
import CoreLocation
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
    var sourcePreviewResolver: (@MainActor (URL) async -> OEmbedService.Preview?)?
    var placeImageSearchResolver: (@MainActor (Place) async throws -> PlaceImageSearchResult)?
    var places: [Place] { data.places.filter { !$0.deleted } }
    /// Was auf diesem iPhone noch zu entscheiden ist, auch Vorschläge, für die nur die andere Person schon ist.
    var inbox: [Place] { places.filter(isOpenForMe) }
    var deferred: [Place] { places.filter { ($0.deferred && !$0.franked) || $0.passedBy.contains(me) } }
    var franked: [Place] { places.filter(\.franked) }
    /// Offene Ideen, die jemand anderes gesammelt hat – für das Zeichen am Tab.
    var newFromOthers: Int { inbox.filter { $0.author != me && $0.author.localizedCaseInsensitiveCompare("Wir") != .orderedSame }.count }

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
            changed.franked = true; changed.deferred = false
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
        do {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
            let file = self.root.appendingPathComponent("album.json")
            var loadedData: AlbumData
            if FileManager.default.fileExists(atPath: file.path) {
                let bytes = try Data(contentsOf: file)
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
                              image: .bundled(name: "imgPhotoLetna"), franked: true, visited: true, day: 4, dayOrder: 0)
            letna.gallery = [ExternalPlaceImage(
                imageURL: "https://example.invalid/memory.jpg", sourceURL: "https://example.invalid/memory",
                credit: "Demo", provider: .sourcePreview
            )]
            let oldTown = Place(id: "memory-oldtown", title: "Altstädter Ring", category: "Sehenswert", author: "Luke",
                                image: .bundled(name: "imgPhotoOldTown"), franked: true, visited: true, day: 4, dayOrder: 1)
            let noPhoto = Place(id: "memory-cafe", title: "Café Savoy", category: "Essen & Trinken", author: "Luke",
                                franked: true, visited: true, day: 5, dayOrder: 0)
            data.places = [letna, oldTown, noPhoto]
        }
        if ProcessInfo.processInfo.environment["ALBUM_DEMO_MOTION"] == "1" {
            var savoy = Place(id: "motion-savoy", title: "Café Savoy", category: "Essen & Trinken", author: "Luke",
                              image: .bundled(name: "imgThumbCafe"), franked: true, day: 4, dayOrder: 0, approvals: ["Luke"])
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
            if ProcessInfo.processInfo.environment["ALBUM_DEMO_INBOX_UNLOCATED"] == "1" {
                for index in data.places.indices {
                    data.places[index].lat = nil
                    data.places[index].lng = nil
                }
                data.places[0].approvals = ["Mia"]
                data.places[0].franked = true
            }
        }
        if ProcessInfo.processInfo.environment["ALBUM_DEMO_IMAGE_CHOICE"] == "1",
           !data.places.contains(where: { $0.id == "image-choice-cafe" }) {
            data.places = [
                Place(id: "image-choice-cafe", title: "Café Louvre", category: "Essen & Trinken", author: "Luke",
                      address: "Národní 22, Praha 1", lat: 50.0819, lng: 14.4185, franked: true, day: 4, dayOrder: 0, approvals: ["Luke"])
            ]
        }
        if ProcessInfo.processInfo.environment["ALBUM_DEMO_PHOTO_FALLBACK"] == "1" {
            data.places = [
                Place(id: "photo-fallback-speculum", title: "Speculum Alchemiae",
                      sourceURL: "https://example.invalid/speculum-alchemiae",
                      category: "Sehenswert", address: "Haštalská 795/1, 110 00 Praha 1",
                      lat: 50.0907544, lng: 14.4224672)
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
            _ = backfillSeedLocations()
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
            if !place.deleted, case .uploaded(let oldImage) = data.places[index].image,
               case .uploaded(let newImage) = place.image, oldImage.id == newImage.id {
            } else if case .uploaded(let oldImage) = data.places[index].image {
                oldImageToRemove = oldImage
                if let path = oldImage.storagePath { data.dirty.insert("image-delete:" + path) }
                if place.deleted { place.image = nil }
            }
            data.places[index] = place
        } else { data.places.append(place) }
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
        var restored = place
        restored.deferred = false
        restored.passedBy.removeAll { $0 == me }
        upsert(restored)
    }
    func restoreDeferred() {
        for place in deferred { restoreDeferred(place) }
    }

    /// Setzt einen Ort ans Ende eines Tages (oder nimmt ihn aus der Tagesplanung).
    func assign(_ place: Place, to day: Int?) {
        var p = place
        p.day = day
        p.dayOrder = day.map { d in (franked.filter { $0.day == d && $0.id != place.id }.compactMap(\.dayOrder).max() ?? -1) + 1 }
        upsert(p)
    }

    /// Neue Reihenfolge eines Tages nach dem Verschieben in der Liste.
    func reorder(day: Int, ids: [String]) {
        for (index, id) in ids.enumerated() {
            guard var p = places.first(where: { $0.id == id }), p.dayOrder != index else { continue }
            p.dayOrder = index; upsert(p)
        }
    }

    /// Orte eines Tages in geplanter Reihenfolge.
    /// Hotel als Start jeder Tagesrunde; ohne Hotel die Altstadt.
    var hotelCoordinate: CLLocationCoordinate2D {
        franked.first { $0.category == "Unterkunft" && $0.coordinate != nil }?.coordinate
            ?? CLLocationCoordinate2D(latitude: 50.0875, longitude: 14.4213)
    }

    /// Holt fehlende Öffnungszeiten (einmal pro Ort) und rechnet einen Tagesplan-Vorschlag.
    func proposeDayPlan(keepAssigned: Bool) async -> DayPlanProposal {
        let candidates = franked.filter { $0.openingHours == nil && $0.coordinate != nil && $0.category != "Unterkunft" }
        let resolver = openingHoursResolver
        var results: [OpeningHoursFetchResult] = []

        // Drei gleichzeitige Abfragen begrenzen die Netzlast; fehlende Ergebnisse bleiben offen.
        for batchStart in stride(from: 0, to: candidates.count, by: 3) {
            guard !Task.isCancelled else {
                return DayPlanGenerator.plan(places: franked, hotel: hotelCoordinate, flights: data.trip.flights ?? [], keepAssigned: keepAssigned)
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
                return DayPlanGenerator.plan(places: franked, hotel: hotelCoordinate, flights: data.trip.flights ?? [], keepAssigned: keepAssigned)
            }
            results.append(contentsOf: batchResults)
        }

        guard !Task.isCancelled else {
            return DayPlanGenerator.plan(places: franked, hotel: hotelCoordinate, flights: data.trip.flights ?? [], keepAssigned: keepAssigned)
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
        return DayPlanGenerator.plan(places: franked, hotel: hotelCoordinate, flights: data.trip.flights ?? [], keepAssigned: keepAssigned)
    }

    /// Übernimmt den Vorschlag als einen atomaren Persistenzschritt.
    @discardableResult func apply(_ proposal: DayPlanProposal) -> Bool {
        let previous = data
        let commitDate = Date()
        var changed = false
        for (day, stops) in proposal.days {
            for (index, stop) in stops.enumerated() {
                // Vorschläge dürfen keine veralteten, gelöschten oder nicht mehr beschlossenen Orte schreiben.
                guard var place = franked.first(where: { $0.id == stop.id }) else { continue }
                guard place.day != day || place.dayOrder != index else { continue }
                place.day = day
                place.dayOrder = index
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
              assignments.allSatisfy({ assignment in data.places.contains(where: { place in place.id == assignment.placeID }) }) else {
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
            guard data.places[index].day != assignment.day || data.places[index].dayOrder != assignment.dayOrder else {
                continue
            }
            data.places[index].day = assignment.day
            data.places[index].dayOrder = assignment.dayOrder
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

    func plan(for day: Int) -> [Place] {
        franked.filter { $0.day == day }.sorted { ($0.dayOrder ?? .max, $0.title) < ($1.dayOrder ?? .max, $1.title) }
    }
    @discardableResult func updateTrip(_ trip: TripInfo) -> Bool {
        let previous = data
        data.trip = trip; data.trip.updatedAt = Date(); data.dirty.insert("trip")
        if persist() {
            scheduleSync()
            return true
        } else {
            data = previous
            return false
        }
    }

    /// Orte, für die in diesem App-Lauf schon ein Bild gesucht wurde (Titel und Koordinate), damit nichts in Schleife läuft.
    private var imageLookupsTried: Set<String> = []

    /// Repairs only untouched copies of bundled seed places whose coordinates
    /// were added after the copy was originally saved. User edits are identified
    /// by either a changed title or source URL and are left entirely untouched.
    @discardableResult
    func backfillSeedLocations() -> Bool {
        guard !loadFailed else { return false }
        let seeds = Dictionary(uniqueKeysWithValues: Place.examples.map { ($0.id, $0) })
        var succeeded = true
        for current in data.places {
            guard let seed = seeds[current.id], current.title == seed.title else { continue }
            let legacyAlchemiaeSource = current.id == "prague-alchemiae"
                && ["http://alchemiae.cz/cs", "https://alchemiae.cz/cs"].contains(current.sourceURL)
                && (current.address.isEmpty || current.address == seed.address)
            guard current.sourceURL == seed.sourceURL || legacyAlchemiaeSource else { continue }
            var repaired = current
            if legacyAlchemiaeSource { repaired.sourceURL = seed.sourceURL }
            if current.coordinate == nil {
                guard current.address.isEmpty || current.address == seed.address else { continue }
                guard let coordinate = seed.coordinate else { continue }
                repaired.lat = coordinate.latitude
                repaired.lng = coordinate.longitude
                if repaired.address.isEmpty { repaired.address = seed.address }
            }
            guard repaired != current else { continue }
            if !upsert(repaired) { succeeded = false }
        }
        return succeeded
    }

    /// Sucht für alle Orte mit Koordinaten, aber ohne echtes Ortsfoto, ein Bild vom tatsächlichen Ort.
    func refreshPlaceImages(placeID: String? = nil) async {
        _ = backfillSeedLocations()
        if let placeID {
            await refreshSourcePreviewIfNeeded(placeID: placeID)
        }
        let candidates = if let placeID {
            places.filter { $0.id == placeID }
        } else {
            places
        }
        for place in candidates where place.coordinate != nil && (PlaceImageService.shouldSearch(for: place, force: false) || PlaceImageService.needsGallery(place)) {
            let key = "\(place.id)|\(place.title)|\(place.lat ?? 0)|\(place.lng ?? 0)|\(place.category)|\(place.address)"
            guard imageLookupsTried.insert(key).inserted else { continue }
            let needsImage = PlaceImageService.shouldSearch(for: place, force: false)
            let result: PlaceImageSearchResult?
            do {
                if let placeImageSearchResolver {
                    result = try await placeImageSearchResolver(place)
                } else {
                    result = try await PlaceImageService.search(for: place)
                }
            } catch {
                result = nil
            }
            guard !Task.isCancelled else {
                imageLookupsTried.remove(key)
                return
            }

            // Eine reine Galerie-Nachlieferung ersetzt niemals das vorhandene Hauptbild.
            if !needsImage {
                guard let result, result.isCurrent else { imageLookupsTried.remove(key); continue }
                let found = result.automaticImages
                guard var current = places.first(where: { $0.id == place.id }),
                      PlaceImageService.matchesRequest(place, current), current.image == place.image else {
                    imageLookupsTried.remove(key)
                    continue
                }
                let gallery = PlaceImageService.gallery(from: found, for: current)
                if current.gallery != gallery { current.gallery = gallery; upsert(current) }
                continue
            }

            let found = result?.automaticImages ?? []
            let hasCurrentGeneratedFallback: Bool = if case .uploaded(let image) = place.image {
                image.generatedSource != nil && image.resolvedFor?.matches(place) == true
            } else {
                false
            }
            let local: LocalPlaceImage? = if found.isEmpty, !hasCurrentGeneratedFallback,
                                             !isSourcePreview(place.image),
                                             let coordinate = place.coordinate {
                await PlaceImageResolver.localSnapshot(at: coordinate)
            } else {
                nil
            }
            guard !Task.isCancelled else {
                imageLookupsTried.remove(key)
                return
            }

            guard var current = places.first(where: { $0.id == place.id }),
                  PlaceImageService.matchesRequest(place, current), current.image == place.image else {
                imageLookupsTried.remove(key)
                continue
            }
            guard !Task.isCancelled else {
                imageLookupsTried.remove(key)
                return
            }
            do {
                if let best = found.first {
                    current.image = best.asset(for: current)
                    current.gallery = PlaceImageService.gallery(from: found, for: current)
                } else if let local, let coordinate = current.coordinate, !isSourcePreview(current.image) {
                    var uploaded = try PlaceImageStorage.save(local.data, root: root)
                    uploaded.resolvedFor = ResolvedPlaceIdentity(
                        title: current.title,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        category: current.category,
                        address: current.address
                    )
                    uploaded.generatedSource = local.source
                    current.image = .uploaded(uploaded)
                    current.gallery = []
                } else if !PlaceImageService.canRetain(current.image, for: current) {
                    current.image = nil
                    current.gallery = []
                    imageLookupsTried.remove(key)
                } else if !hasCurrentGeneratedFallback {
                    // Ein späterer Aufruf darf einen vollständigen Ausfall erneut versuchen.
                    imageLookupsTried.remove(key)
                }
                if current != place { upsert(current) }
            } catch {
                imageLookupsTried.remove(key)
            }
        }
    }

    private func refreshSourcePreviewIfNeeded(placeID: String) async {
        guard let place = places.first(where: { $0.id == placeID }),
              !place.deleted,
              (place.image == nil || isGeneratedFallback(place.image)),
              let pageURL = LinkValidation.url(place.sourceURL),
              var components = URLComponents(url: pageURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return }
        if scheme == "http" { components.scheme = "https" }
        guard let requestURL = components.url else { return }

        let preview: OEmbedService.Preview?
        do {
            if let sourcePreviewResolver {
                preview = await sourcePreviewResolver(requestURL)
            } else {
                preview = try await OEmbedService.preview(requestURL)
            }
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        guard let thumbnail = preview?.thumbnail_url,
              let thumbnailURL = LinkValidation.url(thumbnail),
              ["http", "https"].contains(thumbnailURL.scheme?.lowercased() ?? "") else { return }
        guard var current = places.first(where: { $0.id == placeID }),
              !current.deleted,
              PlaceImageService.matchesRequest(place, current),
              current.title == place.title,
              current.sourceURL == place.sourceURL,
              current.image == place.image,
              (current.image == nil || isGeneratedFallback(current.image)) else { return }
        guard !Task.isCancelled else { return }
        current.image = .linkPreview(
            pageURL: pageURL.absoluteString,
            thumbnailURL: thumbnailURL.absoluteString,
            credit: current.sourceLabel
        )
        _ = upsert(current)
    }

    private func isGeneratedFallback(_ image: PlaceImageAsset?) -> Bool {
        guard case .uploaded(let uploaded) = image else { return false }
        return uploaded.generatedSource != nil
    }

    private func isSourcePreview(_ image: PlaceImageAsset?) -> Bool {
        if case .linkPreview = image { return true }
        return false
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
        do {
            let service = try service()
            try await service.sync(store: self)
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
        let service = try service()
        data.dirty.formUnion(data.places.map(\.id))
        data.dirty.formUnion(data.documents.map { "doc-" + $0.id })
        data.dirty.insert("trip")
        guard persist() else { throw CocoaError(.fileWriteUnknown) }
        data.collaboration = try await service.createTrip(store: self)
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
        data.collaboration = try await service.joinTrip(token: token)
        publishShareContext()
        guard persist() else { throw CocoaError(.fileWriteUnknown) }
        try await service.sync(store: self)
        service.startRealtime { [weak self] in await self?.sync() }
        syncStatus = "Album verbunden"
    }

    private func service() throws -> AlbumSyncService {
        if let syncService { return syncService }
        let service = try SupabaseSync.configured()
        syncService = service
        return service
    }
}
