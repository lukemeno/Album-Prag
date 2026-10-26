import Foundation
import Observation

/// The origin is metadata for the library UI only. It is deliberately not
/// inferred from the contents of a trip folder after a migration.
enum TripLibraryOrigin: String, Codable {
    case migrated
    case starter
    case blank
}

struct TripLibraryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let albumID: String
    var origin: TripLibraryOrigin
    var title: String
    var destination: String?
    var startDate: TripDay?
    var endDate: TripDay?
    var remoteTripID: UUID?
    var travelers: [String]
    var createdAt: Date
    var lastOpenedAt: Date?
    var unavailableReason: String?

    init(id: UUID = UUID(), albumID: String, origin: TripLibraryOrigin,
         title: String, destination: String? = nil, startDate: TripDay? = nil,
         endDate: TripDay? = nil, remoteTripID: UUID? = nil,
         travelers: [String] = [], createdAt: Date = Date(),
         lastOpenedAt: Date? = nil, unavailableReason: String? = nil) {
        self.id = id; self.albumID = albumID; self.origin = origin; self.title = title
        self.destination = destination; self.startDate = startDate; self.endDate = endDate
        self.remoteTripID = remoteTripID; self.travelers = travelers; self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt; self.unavailableReason = unavailableReason
    }
}

struct TripLibraryIndex: Codable, Equatable {
    let version: Int
    var entries: [TripLibraryEntry]
    var lastOpenedID: UUID?

    init(version: Int = 1, entries: [TripLibraryEntry] = [], lastOpenedID: UUID? = nil) {
        self.version = version; self.entries = entries; self.lastOpenedID = lastOpenedID
    }

    private enum CodingKeys: String, CodingKey { case version, entries, lastOpenedID }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        entries = try values.decodeIfPresent([TripLibraryEntry].self, forKey: .entries) ?? []
        lastOpenedID = try values.decodeIfPresent(UUID.self, forKey: .lastOpenedID)
    }
}

struct LegacyMigrationReceipt: Codable, Equatable {
    enum State: String, Codable { case copying, committed }
    let id: UUID
    let state: State
    let sourceFiles: Int
    let sourceBytes: Int64
    let places: Int
    let documents: Int
    let memories: Int
    let albumID: String
    let committedAt: Date?
}

/// Owns the index and lifecycle of one or more AlbumStore folders. The index
/// is only a cache; each trip folder remains the source of truth.
@MainActor @Observable final class TripLibrary {
    let root: URL
    let legacyRoot: URL
    let shareInbox: ShareInbox
    private(set) var entries: [TripLibraryEntry] = []
    private(set) var activeID: UUID?
    private(set) var activeStore: AlbumStore?
    var error: String?

    @ObservationIgnored private let availableCapacity: () -> Int64?
    @ObservationIgnored private let copier: (URL, URL) throws -> Void
    @ObservationIgnored private let storeFactory: (URL, ShareInbox, Bool) -> AlbumStore
    @ObservationIgnored private let indexWriter: ((Data, URL) throws -> Void)?
    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private var readOnlyIndex = false
    @ObservationIgnored private var indexLastOpenedID: UUID?

    private var indexURL: URL { root.appendingPathComponent("library.json") }
    private var receiptURL: URL { root.appendingPathComponent("legacy-migration.json") }
    private var tripsURL: URL { root.appendingPathComponent("Trips", isDirectory: true) }
    private static let pristineCleanupMarker = "legacy-pristine-cleanup-v1"

    init(root: URL? = nil, legacyRoot: URL? = nil, shareInbox: ShareInbox = ShareInbox(),
         fileManager: FileManager = .default, availableCapacity: @escaping () -> Int64? = {
             guard let url = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                          appropriateFor: nil, create: true) else { return nil }
             return try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                 .volumeAvailableCapacityForImportantUsage
         }, copier: @escaping (URL, URL) throws -> Void = { source, destination in
             try FileManager.default.copyItem(at: source, to: destination)
         }, storeFactory: ((URL, ShareInbox, Bool) -> AlbumStore)? = nil,
         indexWriter: ((Data, URL) throws -> Void)? = nil) {
        self.fileManager = fileManager
        self.shareInbox = shareInbox
        self.availableCapacity = availableCapacity
        self.copier = copier
        self.indexWriter = indexWriter
        self.storeFactory = storeFactory ?? { path, inbox, publishesContext in
            AlbumStore(root: path, shareInbox: inbox, publishesShareContext: publishesContext)
        }

        #if DEBUG
        if root == nil, let slot = ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"], !slot.isEmpty {
            let safe = String(slot.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.root = (root ?? support.appendingPathComponent("AlbumUITestLibraries", isDirectory: true))
                .appendingPathComponent(safe, isDirectory: true)
            self.legacyRoot = legacyRoot ?? support.appendingPathComponent("AlbumUITests", isDirectory: true)
                .appendingPathComponent(safe, isDirectory: true)
        } else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.root = root ?? support.appendingPathComponent("AlbumLibrary", isDirectory: true)
            self.legacyRoot = legacyRoot ?? support.appendingPathComponent("Album", isDirectory: true)
        }
        #else
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.root = root ?? support.appendingPathComponent("AlbumLibrary", isDirectory: true)
        self.legacyRoot = legacyRoot ?? support.appendingPathComponent("Album", isDirectory: true)
        #endif

        do {
            try fileManager.createDirectory(at: tripsURL, withIntermediateDirectories: true)
            loadIndex()
            if !readOnlyIndex { migrateLegacyIfNeeded() }
            rebuildIfNeeded()
            persistIndex()
        } catch {
            self.error = "Die Reisebibliothek konnte nicht geöffnet werden: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func restoreLastOpenedTrip() -> Bool {
        let id = indexLastOpenedID.flatMap { candidate in
            entries.contains(where: { $0.id == candidate && $0.unavailableReason == nil }) ? candidate : nil
        } ?? entries.first(where: { $0.unavailableReason == nil && folderExists($0.id) })?.id
        guard let id else { return false }
        return open(id)
    }

    @discardableResult
    func open(_ id: UUID) -> Bool {
        guard let entry = entries.first(where: { $0.id == id }), entry.unavailableReason == nil else { return false }
        if activeID == id, activeStore != nil {
            refreshActiveEntry()
            return true
        }
        guard folderExists(id) else {
            markUnavailable(id, reason: "Der Reiseordner fehlt.")
            return false
        }
        // Build and validate the candidate first. A corrupt target must not
        // deactivate the currently usable trip.
        let store = storeFactory(tripURL(id), shareInbox, false)
        guard !store.loadFailed else {
            markUnavailable(id, reason: store.error ?? "Die Reise konnte nicht geladen werden.")
            return false
        }
        if let current = activeStore {
            current.stopOwnedCallbacks()
            Task { await current.shutdown() }
        }
        activeID = id
        activeStore = store
        indexLastOpenedID = id
        refreshActiveEntry()
        store.activateShareContext()
        store.publishShareContext()
        store.drainShareQueue()
        persistIndex()
        return true
    }

    @discardableResult
    func showLibrary() -> Bool {
        refreshActiveEntry()
        if let store = activeStore { store.stopOwnedCallbacks(); Task { await store.shutdown() } }
        activeStore = nil; activeID = nil
        return persistIndex()
    }

    @discardableResult
    func createBlankTrip(title: String = "Neue Reise", destination: String? = nil,
                         startDate: TripDay? = nil, endDate: TripDay? = nil) -> UUID? {
        createTrip(origin: .blank, title: title, destination: destination,
                   startDate: startDate, endDate: endDate, includeExamples: false)
    }

    /// Kept for callers that offer an explicit “starter” choice. Starter data is
    /// intentionally blank in the current product; no Prague examples are
    /// inserted into new trips.
    @discardableResult
    func createStarterTrip(title: String = "Neue Reise", destination: String? = nil) -> UUID? {
        createTrip(origin: .starter, title: title, destination: destination,
                   startDate: nil, endDate: nil, includeExamples: false)
    }

    /// Re-reads folder metadata without constructing AlbumStores for every
    /// trip. This is used after a background import or a scene transition.
    func refreshEntries() {
        rebuildIfNeeded()
        persistIndex()
    }

    func refreshActiveEntry() {
        guard let id = activeID, let store = activeStore,
              let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let trip = store.data.trip
        var entry = entries[index]
        entry.title = trip.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? trip.title! : (trip.destination ?? entry.title)
        entry.destination = trip.destination
        entry.startDate = trip.startDate; entry.endDate = trip.endDate
        entry.remoteTripID = store.data.collaboration?.tripID
        entry.travelers = trip.travelers ?? []
        entry.lastOpenedAt = Date()
        entry.unavailableReason = nil
        entries[index] = entry
        persistIndex()
    }

    /// Joins into a new folder first. A duplicate remote trip is discarded
    /// before it can replace the active trip or alter the index.
    func joinInvitation(_ url: URL) async throws -> UUID {
        let previousLastOpenedID = indexLastOpenedID
        let id = UUID()
        let staging = root.appendingPathComponent(".staging-\(id.uuidString)", isDirectory: true)
        var destination: URL?
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        try writeBlankAlbum(to: staging)
        let stagedStore = storeFactory(staging, shareInbox, false)
        do {
            try await stagedStore.joinSharedTrip(url: url)
            guard let remoteID = stagedStore.data.collaboration?.tripID else { throw AlbumSyncError.missingTrip }
            guard stagedStore.persist() else { throw CocoaError(.fileWriteUnknown) }
            if let existing = entries.first(where: { $0.remoteTripID == remoteID && $0.unavailableReason == nil }) {
                await stagedStore.shutdown(); try? fileManager.removeItem(at: staging)
                _ = open(existing.id)
                return existing.id
            }
            destination = tripURL(id)
            try fileManager.moveItem(at: staging, to: destination!)
            let entry = makeEntry(id: id, origin: .migrated, data: stagedStore.data)
            entries.append(entry)
            guard persistIndex() else { throw CocoaError(.fileWriteUnknown) }
            await stagedStore.shutdown()
            _ = open(id)
            return id
        } catch {
            await stagedStore.shutdown()
            try? fileManager.removeItem(at: staging)
            if let destination { try? fileManager.removeItem(at: destination) }
            entries.removeAll { $0.id == id }
            if indexLastOpenedID == id { indexLastOpenedID = previousLastOpenedID }
            throw error
        }
    }

    // MARK: - Index and migration

    private func loadIndex() {
        guard fileManager.fileExists(atPath: indexURL.path) else { return }
        do {
            let index = try JSONDecoder().decode(TripLibraryIndex.self, from: Data(contentsOf: indexURL))
            entries = index.entries; indexLastOpenedID = index.lastOpenedID
            if index.version > 1 {
                readOnlyIndex = true
                error = "Diese Reisebibliothek stammt aus einer neueren App-Version und wird nur gelesen."
            }
        } catch {
            let backup = root.appendingPathComponent("library.corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? fileManager.moveItem(at: indexURL, to: backup)
            self.error = "Der Bibliotheksindex war beschädigt und wurde neu aufgebaut."
        }
    }

    private func rebuildIfNeeded() {
        let scanned = scanFolders()
        var byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for entry in scanned {
            if let old = byID[entry.id], old.unavailableReason != nil { continue }
            if let old = byID[entry.id] {
                var refreshed = entry
                refreshed.origin = old.origin
                refreshed.createdAt = old.createdAt
                refreshed.lastOpenedAt = old.lastOpenedAt
                byID[entry.id] = refreshed
            } else {
                byID[entry.id] = entry
            }
        }
        entries = byID.values.sorted { $0.createdAt < $1.createdAt }
        if let last = indexLastOpenedID, !entries.contains(where: { $0.id == last }) { indexLastOpenedID = nil }
    }

    private func migrateLegacyIfNeeded() {
        let sourceAlbum = legacyRoot.appendingPathComponent("album.json")
        guard fileManager.fileExists(atPath: sourceAlbum.path) else { return }
        let sourceData: AlbumData
        let sourceBytes: Data
        do {
            sourceBytes = try Data(contentsOf: sourceAlbum)
            sourceData = try JSONDecoder().decode(AlbumData.self, from: sourceBytes)
        } catch {
            self.error = "Der bisherige Reisebestand konnte nicht gelesen werden; er bleibt unverändert."
            return
        }

        let previous = try? JSONDecoder().decode(LegacyMigrationReceipt.self, from: Data(contentsOf: receiptURL))
        if let previous, previous.state == .committed {
            if folderExists(previous.id), loadAlbum(at: tripURL(previous.id)) != nil {
                ensureEntry(id: previous.id, origin: .migrated, data: loadAlbum(at: tripURL(previous.id))!)
            } else {
                ensureUnavailableEntry(id: previous.id, albumID: previous.albumID, reason: "Die migrierte Reise fehlt.")
            }
            return
        }

        let id = previous?.id ?? UUID()
        let target = tripURL(id)
        // A crash can occur after the folder rename but before the receipt is
        // committed. If that UUID is already indexed and the folder decodes,
        // the indexed copy is authoritative: preserve user edits and only
        // finish the receipt commit. Never compare it with the old legacy
        // folder in this case.
        if previous?.state == .copying, let index = entries.firstIndex(where: { $0.id == id }) {
            guard let targetData = loadAlbum(at: target),
                  targetData.albumID == previous?.albumID,
                  entries[index].albumID == targetData.albumID else {
                entries[index].unavailableReason = "Die angefangene Migration ist beschädigt oder nicht verfügbar."
                _ = persistIndex()
                return
            }
            entries[index].unavailableReason = nil
            guard persistIndex() else { return }
            let committed = LegacyMigrationReceipt(id: id, state: .committed,
                                                   sourceFiles: previous?.sourceFiles ?? treeFiles(legacyRoot),
                                                   sourceBytes: previous?.sourceBytes ?? treeBytes(legacyRoot),
                                                   places: targetData.places.count,
                                                   documents: targetData.documents.count,
                                                   memories: targetData.tripMemories.count,
                                                   albumID: targetData.albumID, committedAt: Date())
            _ = writeReceipt(committed)
            return
        }
        // Cleanup itself writes a marker after the verified copy. If the app
        // crashed before the index commit, that marker proves this is our
        // transformed orphan rather than an unrelated folder; keep its edits.
        if previous?.state == .copying,
           !entries.contains(where: { $0.id == id }),
           fileManager.fileExists(atPath: target.appendingPathComponent(Self.pristineCleanupMarker).path),
           let targetData = loadAlbum(at: target), targetData.albumID == previous?.albumID {
            ensureEntry(id: id, origin: .migrated, data: targetData)
            guard persistIndex() else { return }
            let committed = LegacyMigrationReceipt(id: id, state: .committed,
                                                   sourceFiles: previous?.sourceFiles ?? treeFiles(legacyRoot),
                                                   sourceBytes: previous?.sourceBytes ?? treeBytes(legacyRoot),
                                                   places: targetData.places.count,
                                                   documents: targetData.documents.count,
                                                   memories: targetData.tripMemories.count,
                                                   albumID: targetData.albumID, committedAt: Date())
            _ = writeReceipt(committed)
            return
        }
        let sourceSize = treeBytes(legacyRoot)
        if let capacity = availableCapacity(), capacity < Int64(Double(max(sourceSize, 0)) * 1.2) + 50_000_000 {
            error = "Nicht genügend Speicherplatz für die Reisekopie. Sie wird beim nächsten Start erneut versucht."
            return
        }
        let receipt = LegacyMigrationReceipt(id: id, state: .copying, sourceFiles: treeFiles(legacyRoot),
                                             sourceBytes: sourceSize, places: sourceData.places.count,
                                             documents: sourceData.documents.count, memories: sourceData.tripMemories.count,
                                             albumID: sourceData.albumID, committedAt: nil)
        guard writeReceipt(receipt) else { return }
        let staging = root.appendingPathComponent(".staging-\(id.uuidString)", isDirectory: true)
        try? fileManager.removeItem(at: staging)
        do {
            if fileManager.fileExists(atPath: target.path),
               (!treesEqual(legacyRoot, target) || loadAlbum(at: target) == nil) {
                // A stale copying receipt may leave a target folder that was
                // modified after a crash. Remove only that UUID and recopy it
                // in this same startup, retaining the receipt ID.
                try fileManager.removeItem(at: target)
                entries.removeAll { $0.id == id }
                if indexLastOpenedID == id { indexLastOpenedID = nil }
            }
            if !fileManager.fileExists(atPath: target.path) {
                try copier(legacyRoot, staging)
                guard treesEqual(legacyRoot, staging), loadAlbum(at: staging)?.albumID == sourceData.albumID else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                try fileManager.moveItem(at: staging, to: target)
            }
            let copied = try cleanupPristineTemplates(in: target)
            ensureEntry(id: id, origin: .migrated, data: copied)
            guard persistIndex() else { throw CocoaError(.fileWriteUnknown) }
            let committed = LegacyMigrationReceipt(id: id, state: .committed, sourceFiles: receipt.sourceFiles,
                                                   sourceBytes: receipt.sourceBytes, places: copied.places.count,
                                                   documents: copied.documents.count, memories: copied.tripMemories.count,
                                                   albumID: copied.albumID, committedAt: Date())
            _ = writeReceipt(committed)
        } catch {
            try? fileManager.removeItem(at: staging)
            // The target was unindexed at the start of this copy path. Do not
            // let a failed index commit expose it to the next folder scan.
            try? fileManager.removeItem(at: target)
            entries.removeAll { $0.id == id }
            if indexLastOpenedID == id { indexLastOpenedID = nil }
            self.error = "Die Reise konnte noch nicht übernommen werden: \(error.localizedDescription)"
        }
    }

    private func createTrip(origin: TripLibraryOrigin, title: String, destination: String?,
                            startDate: TripDay?, endDate: TripDay?, includeExamples: Bool) -> UUID? {
        guard (startDate == nil) == (endDate == nil), startDate == nil || endDate! >= startDate! else {
            error = "Bitte wähle einen gültigen Reisezeitraum."
            return nil
        }
        let id = UUID()
        let staging = root.appendingPathComponent(".staging-\(id.uuidString)", isDirectory: true)
        let target = tripURL(id)
        let previousEntries = entries
        let previousLastOpenedID = indexLastOpenedID
        do {
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            try writeBlankAlbum(to: staging, title: title, destination: destination,
                                startDate: startDate, endDate: endDate, includeExamples: includeExamples)
            try fileManager.moveItem(at: staging, to: target)
            let data = loadAlbum(at: target)!
            entries.append(makeEntry(id: id, origin: origin, data: data))
            guard persistIndex() else { throw CocoaError(.fileWriteUnknown) }
            return id
        } catch {
            try? fileManager.removeItem(at: staging)
            try? fileManager.removeItem(at: target)
            entries = previousEntries
            indexLastOpenedID = previousLastOpenedID
            self.error = "Die neue Reise konnte nicht angelegt werden: \(error.localizedDescription)"
            return nil
        }
    }

    private func writeBlankAlbum(to folder: URL, title: String? = nil, destination: String? = nil,
                                 startDate: TripDay? = nil, endDate: TripDay? = nil,
                                 includeExamples: Bool = false) throws {
        var data = AlbumData()
        if !includeExamples { data.places = [] }
        data.schemaVersion = 2
        data.trip = TripInfo()
        data.trip.hotel = ""
        data.trip.planningSchemaVersion = 2
        data.trip.title = title
        data.trip.destination = destination
        data.trip.startDate = startDate
        data.trip.endDate = endDate
        try JSONEncoder().encode(data).write(to: folder.appendingPathComponent("album.json"), options: .atomic)
    }

    /// Removes only exact untouched built-in templates from the migrated copy.
    /// The old folder is never changed. Shared trips retain a tombstone so
    /// other members receive the cleanup through normal place sync.
    private func cleanupPristineTemplates(in folder: URL) throws -> AlbumData {
        let marker = folder.appendingPathComponent(Self.pristineCleanupMarker)
        if fileManager.fileExists(atPath: marker.path) {
            guard let data = loadAlbum(at: folder) else { throw CocoaError(.fileReadCorruptFile) }
            return data
        }
        guard var data = loadAlbum(at: folder) else { throw CocoaError(.fileReadCorruptFile) }
        let templates = Place.examples
        if data.collaboration != nil {
            for index in data.places.indices where templates.contains(data.places[index]) {
                data.places[index].deleted = true
                data.places[index].updatedAt = Date()
                data.dirty.insert(data.places[index].id)
            }
        } else {
            data.places.removeAll { templates.contains($0) }
        }
        try JSONEncoder().encode(data).write(to: folder.appendingPathComponent("album.json"), options: .atomic)
        try Data(Self.pristineCleanupMarker.utf8).write(to: marker, options: .atomic)
        return data
    }

    private func makeEntry(id: UUID, origin: TripLibraryOrigin, data: AlbumData) -> TripLibraryEntry {
        TripLibraryEntry(id: id, albumID: data.albumID, origin: origin,
                         title: data.trip.title?.isEmpty == false ? data.trip.title! : (data.trip.destination ?? "Neue Reise"),
                         destination: data.trip.destination, startDate: data.trip.startDate, endDate: data.trip.endDate,
                         remoteTripID: data.collaboration?.tripID, travelers: data.trip.travelers ?? [])
    }

    private func ensureEntry(id: UUID, origin: TripLibraryOrigin, data: AlbumData) {
        let entry = makeEntry(id: id, origin: origin, data: data)
        if let index = entries.firstIndex(where: { $0.id == id }) {
            var refreshed = entry
            refreshed.origin = entries[index].origin
            refreshed.createdAt = entries[index].createdAt
            refreshed.lastOpenedAt = entries[index].lastOpenedAt
            entries[index] = refreshed
        } else {
            entries.append(entry)
        }
    }

    private func ensureUnavailableEntry(id: UUID, albumID: String, reason: String) {
        if let index = entries.firstIndex(where: { $0.id == id }) { entries[index].unavailableReason = reason; return }
        entries.append(TripLibraryEntry(id: id, albumID: albumID, origin: .migrated, title: "Nicht verfügbar", unavailableReason: reason))
    }

    private func markUnavailable(_ id: UUID, reason: String) {
        if let index = entries.firstIndex(where: { $0.id == id }) { entries[index].unavailableReason = reason; persistIndex() }
    }

    @discardableResult private func persistIndex() -> Bool {
        guard !readOnlyIndex else { return false }
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            let index = TripLibraryIndex(entries: entries.sorted { $0.createdAt < $1.createdAt }, lastOpenedID: indexLastOpenedID)
            let bytes = try JSONEncoder().encode(index)
            if let indexWriter { try indexWriter(bytes, indexURL) }
            else { try bytes.write(to: indexURL, options: .atomic) }
            return true
        } catch { self.error = "Der Bibliotheksindex konnte nicht gespeichert werden: \(error.localizedDescription)"; return false }
    }

    private func writeReceipt(_ receipt: LegacyMigrationReceipt) -> Bool {
        do { try JSONEncoder().encode(receipt).write(to: receiptURL, options: .atomic); return true }
        catch { self.error = "Der Migrationsbeleg konnte nicht gespeichert werden: \(error.localizedDescription)"; return false }
    }

    private func scanFolders() -> [TripLibraryEntry] {
        guard let urls = try? fileManager.contentsOfDirectory(at: tripsURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else { return [] }
        return urls.compactMap { url in
            guard let id = UUID(uuidString: url.lastPathComponent), let data = loadAlbum(at: url) else { return nil }
            return makeEntry(id: id, origin: .migrated, data: data)
        }
    }

    private func folderExists(_ id: UUID) -> Bool { fileManager.fileExists(atPath: tripURL(id).path) }
    private func tripURL(_ id: UUID) -> URL { tripsURL.appendingPathComponent(id.uuidString, isDirectory: true) }
    private func loadAlbum(at folder: URL) -> AlbumData? {
        guard let bytes = try? Data(contentsOf: folder.appendingPathComponent("album.json")) else { return nil }
        return try? JSONDecoder().decode(AlbumData.self, from: bytes)
    }

    private func treeFiles(_ folder: URL) -> Int {
        guard let enumerator = fileManager.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: []) else { return 0 }
        return enumerator.compactMap { ($0 as? URL).flatMap { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true ? nil : $0 } }.count
    }

    private func treeBytes(_ folder: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: []) else { return 0 }
        return enumerator.reduce(Int64(0)) { total, item in
            guard let url = item as? URL, let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]), values.isDirectory != true else { return total }
            return total + Int64(values.fileSize ?? 0)
        }
    }

    private func treesEqual(_ lhs: URL, _ rhs: URL) -> Bool {
        func files(_ root: URL) -> Set<String>? {
            guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: []) else { return nil }
            var result = Set<String>()
            for item in enumerator {
                guard let url = item as? URL,
                      let values = try? url.resourceValues(forKeys: [.isDirectoryKey]), values.isDirectory != true,
                      let relative = relativePath(url, root: root) else { return nil }
                result.insert(relative)
            }
            return result
        }
        guard let left = files(lhs), let right = files(rhs), left == right else { return false }
        return left.allSatisfy { relative in
            fileManager.contentsEqual(atPath: lhs.appendingPathComponent(relative).path,
                                      andPath: rhs.appendingPathComponent(relative).path)
        }
    }

    private func relativePath(_ file: URL, root: URL) -> String? {
        let prefix = root.standardizedFileURL.path.hasSuffix("/") ? root.standardizedFileURL.path : root.standardizedFileURL.path + "/"
        let path = file.standardizedFileURL.path
        guard path.hasPrefix(prefix) else { return nil }
        return String(path.dropFirst(prefix.count))
    }
}
