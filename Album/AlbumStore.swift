import SwiftUI
import PDFKit

@MainActor @Observable final class AlbumStore {
    var data: AlbumData
    var error: String?
    var syncStatus = "Auf diesem iPhone gespeichert"
    var syncing = false
    let root: URL
    var syncService: AlbumSyncService?
    private var loadFailed = false
    private var pendingSync: Task<Void, Never>?
    var places: [Place] { data.places.filter { !$0.deleted } }
    var inbox: [Place] { places.filter { !$0.franked && !$0.deferred } }
    var deferred: [Place] { places.filter { !$0.franked && $0.deferred } }
    var franked: [Place] { places.filter(\.franked) }

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Album", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
            let file = self.root.appendingPathComponent("album.json")
            data = FileManager.default.fileExists(atPath: file.path) ? try JSONDecoder().decode(AlbumData.self, from: Data(contentsOf: file)) : AlbumData()
        } catch {
            data = AlbumData()
            loadFailed = true
            self.error = "Gespeicherte Daten konnten nicht geladen werden: \(error.localizedDescription). Bitte die App nicht löschen."
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
    func restoreDeferred() { for var p in deferred { p.deferred = false; upsert(p) } }
    func updateTrip(_ trip: TripInfo) {
        data.trip = trip; data.trip.updatedAt = Date(); data.dirty.insert("trip"); persist(); scheduleSync()
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
        do {
            let service = try service()
            try await service.sync(store: self)
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
