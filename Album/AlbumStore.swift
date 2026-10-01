import SwiftUI
import PDFKit
import CoreLocation

@MainActor @Observable final class AlbumStore {
    var data: AlbumData
    var error: String?
    var syncStatus = "Auf diesem iPhone gespeichert"
    var syncing = false
    /// Was der letzte Abgleich von anderen gebracht hat; die Abgleich-Insel zeigt es kurz.
    var syncChange: SyncChange?
    let root: URL
    var syncService: AlbumSyncService?
    private var loadFailed = false
    private var pendingSync: Task<Void, Never>?
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

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Album", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
            let file = self.root.appendingPathComponent("album.json")
            data = FileManager.default.fileExists(atPath: file.path) ? try JSONDecoder().decode(AlbumData.self, from: Data(contentsOf: file)) : AlbumData()
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

    func upsert(_ input: Place) {
        var place = input; place.updatedAt = Date()
        if let index = data.places.firstIndex(where: { $0.id == place.id }) {
            if !place.deleted, case .uploaded(let oldImage) = data.places[index].image,
               case .uploaded(let newImage) = place.image, oldImage.id == newImage.id {
            } else if case .uploaded(let oldImage) = data.places[index].image {
                PlaceImageStorage.remove(oldImage, root: root)
                if let path = oldImage.storagePath { data.dirty.insert("image-delete:" + path) }
                if place.deleted { place.image = nil }
            }
            data.places[index] = place
        } else { data.places.append(place) }
        data.dirty.insert(place.id)
        persist(); scheduleSync()
    }

    private func scheduleSync() {
        guard isShared else { return }
        pendingSync?.cancel()
        pendingSync = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            await self?.sync()
        }
    }

    func deferPlace(_ place: Place) { var p = place; p.deferred = true; upsert(p) }
    func restoreDeferred() {
        for var p in deferred { p.deferred = false; p.passedBy.removeAll { $0 == me }; upsert(p) }
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
        for place in franked where place.openingHours == nil && place.coordinate != nil && place.category != "Unterkunft" {
            // Gescheiterte Abfragen bleiben offen und werden beim nächsten Planen wiederholt.
            guard let hours = await OpeningHoursService.fetch(for: place) else { continue }
            var checked = place
            checked.openingHours = hours
            upsert(checked)
        }
        return DayPlanGenerator.plan(places: franked, hotel: hotelCoordinate, flights: data.trip.flights ?? [], keepAssigned: keepAssigned)
    }

    /// Übernimmt den Vorschlag: Tag und Reihenfolge je Ort.
    func apply(_ proposal: DayPlanProposal) {
        for (day, stops) in proposal.days {
            for (index, stop) in stops.enumerated() {
                guard var place = places.first(where: { $0.id == stop.id }), place.day != day || place.dayOrder != index else { continue }
                place.day = day; place.dayOrder = index
                upsert(place)
            }
        }
    }

    func plan(for day: Int) -> [Place] {
        franked.filter { $0.day == day }.sorted { ($0.dayOrder ?? .max, $0.title) < ($1.dayOrder ?? .max, $1.title) }
    }
    func updateTrip(_ trip: TripInfo) {
        data.trip = trip; data.trip.updatedAt = Date(); data.dirty.insert("trip"); persist(); scheduleSync()
    }

    /// Orte, für die in diesem App-Lauf schon ein Bild gesucht wurde (Titel und Koordinate), damit nichts in Schleife läuft.
    private var imageLookupsTried: Set<String> = []

    /// Sucht für alle Orte mit Koordinaten, aber ohne echtes Ortsfoto, ein Bild vom tatsächlichen Ort.
    func refreshPlaceImages() async {
        for place in places where place.coordinate != nil && (PlaceImageService.shouldSearch(for: place, force: false) || PlaceImageService.needsGallery(place)) {
            let key = "\(place.id)|\(place.title)|\(place.lat ?? 0)|\(place.lng ?? 0)|\(place.category)|\(place.address)"
            guard imageLookupsTried.insert(key).inserted else { continue }
            do {
                let result = try await PlaceImageService.search(for: place)
                guard result.isCurrent else { imageLookupsTried.remove(key); continue }
                let found = result.automaticImages
                var lookAround: UploadedPlaceImage?
                if found.isEmpty, let coordinate = place.coordinate, let data = await PlaceImageResolver.lookAroundSnapshot(at: coordinate) {
                    lookAround = try PlaceImageStorage.save(data, root: root)
                    lookAround?.resolvedFor = ResolvedPlaceIdentity(title: place.title, latitude: coordinate.latitude, longitude: coordinate.longitude, category: place.category, address: place.address)
                }
                guard var current = places.first(where: { $0.id == place.id }),
                      PlaceImageService.matchesRequest(place, current), current.image == place.image else {
                    if let lookAround { PlaceImageStorage.remove(lookAround, root: root) }
                    continue
                }
                if let best = found.first {
                    current.image = best.asset(for: current)
                    current.gallery = PlaceImageService.gallery(from: found, for: current)
                } else {
                    current.image = lookAround.map { .uploaded($0) }
                    current.gallery = []
                }
                if current != place { upsert(current) }
            } catch {
                imageLookupsTried.remove(key)
            }
        }
    }

    /// Beim Öffnen eines PDFs von außen gelesen; die Startansicht bietet es zum Übernehmen an.
    var pendingExtraction: ExtractedTrip?

    /// Liest Flüge, Hotel und Buchungsdaten aus einem gespeicherten PDF.
    func extraction(from document: TravelDocument) -> ExtractedTrip {
        TripDocumentParser.parse(document.extractedText)
    }

    /// Übernimmt Gelesenes in die Reisedaten und legt das Hotel als Unterkunft auf die Karte.
    func applyExtraction(_ extracted: ExtractedTrip) async {
        updateTrip(extracted.applied(to: data.trip))
        guard let name = extracted.hotel.name, let address = extracted.hotel.address else { return }
        let id = "hotel-" + (extracted.bookingNumber ?? name).lowercased().filter { $0.isLetter || $0.isNumber }
        var place = places.first { $0.id == id } ?? Place(id: id, title: name, note: "", category: "Unterkunft", author: "Wir")
        place.title = name; place.address = address; place.franked = true; place.deferred = false
        if extracted.hotel.checkIn != nil || extracted.hotel.checkOut != nil {
            place.note = ["Check-in \(extracted.hotel.checkIn ?? "–")", "Check-out \(extracted.hotel.checkOut ?? "–")"].joined(separator: " · ")
        }
        if place.coordinate == nil, let location = try? await CLGeocoder().geocodeAddressString(address).first?.location {
            place.lat = location.coordinate.latitude; place.lng = location.coordinate.longitude
        }
        upsert(place)
        await refreshPlaceImages()
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
        if !FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.copyItem(at: url, to: destination) }
        if !data.documents.contains(where: { $0.id == id }) {
            data.documents.append(TravelDocument(id: id, name: url.deletingPathExtension().lastPathComponent, filename: name, extractedText: String((document.string ?? "").prefix(100_000))))
        }
        data.dirty.insert("doc-" + id)
        if !persist() { throw CocoaError(.fileWriteUnknown) }
        scheduleSync()
    }

    func sync() async {
        guard isShared, !syncing, !loadFailed else { return }
        syncing = true; syncStatus = "Album wird abgeglichen …"
        defer { syncing = false }
        let before = data.places
        do {
            let service = try service()
            try await service.sync(store: self)
            // Beim ersten Abgleich ist alles neu; das ist keine Neuigkeit der anderen Person.
            if !before.isEmpty { syncChange = SyncChange.between(before: before, after: data.places, me: me) ?? syncChange }
            service.startRealtime { [weak self] in await self?.sync() }
            syncStatus = "Synchronisiert"
        } catch { syncStatus = "Lokal gespeichert · Synchronisierung nicht erreichbar"; self.error = error.localizedDescription }
    }

    func createSharedTrip() async throws -> URL {
        guard !loadFailed else { throw CocoaError(.fileReadCorruptFile) }
        let service = try service()
        data.dirty.formUnion(data.places.map(\.id))
        data.dirty.formUnion(data.documents.map { "doc-" + $0.id })
        data.dirty.insert("trip")
        guard persist() else { throw CocoaError(.fileWriteUnknown) }
        data.collaboration = try await service.createTrip(store: self)
        guard persist() else { throw CocoaError(.fileWriteUnknown) }
        guard let url = inviteURL else { throw AlbumSyncError.invalidInvitation }
        syncStatus = "Album kann geteilt werden"
        return url
    }

    func joinSharedTrip(url: URL) async throws {
        guard let token = InvitationLink.token(from: url) else { throw AlbumSyncError.invalidInvitation }
        let service = try service()
        data.collaboration = try await service.joinTrip(token: token)
        guard persist() else { throw CocoaError(.fileWriteUnknown) }
        try await service.sync(store: self)
        syncStatus = "Album verbunden"
    }

    private func service() throws -> AlbumSyncService {
        if let syncService { return syncService }
        let service = try SupabaseSync.configured()
        syncService = service
        return service
    }
}
