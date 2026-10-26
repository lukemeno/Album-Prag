import XCTest
@testable import Album

@MainActor
final class TripLibraryTests: XCTestCase {
    @MainActor
    private final class LifecycleService: AlbumSyncService {
        var stopped = false
        func createTrip(store: AlbumStore) async throws -> CollaborationState { throw AlbumSyncError.missingConfiguration }
        func joinTrip(token: String) async throws -> CollaborationState { throw AlbumSyncError.missingConfiguration }
        func sync(store: AlbumStore) async throws { throw AlbumSyncError.missingConfiguration }
        func startRealtime(onChange: @escaping @MainActor @Sendable () async -> Void) {}
        func authenticatedUserID() async throws -> String { "test-user" }
        func stopRealtime() async { stopped = true }
    }

    private func temporaryRoot(_ name: String = #function) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TripLibrary-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    private func write(_ data: AlbumData, to legacy: URL, extraFile: String? = nil) throws {
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try JSONEncoder().encode(data).write(to: legacy.appendingPathComponent("album.json"), options: .atomic)
        if let extraFile {
            let url = legacy.appendingPathComponent(extraFile)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("preserve-me", using: .utf8).write(to: url)
        }
    }

    func testBlankTripIsTrulyEmptyAndIndependent() throws {
        let root = try temporaryRoot()
        let inboxRoot = root.appendingPathComponent("share")
        let library = TripLibrary(root: root.appendingPathComponent("AlbumLibrary"),
                                  legacyRoot: root.appendingPathComponent("Album"),
                                  shareInbox: ShareInbox(root: inboxRoot))
        let first = try XCTUnwrap(library.createBlankTrip(title: "Paris", destination: "Frankreich",
                                                          startDate: TripDay(rawValue: "2027-04-01"),
                                                          endDate: TripDay(rawValue: "2027-04-03")))
        let second = try XCTUnwrap(library.createBlankTrip(title: "Rom", destination: "Italien"))
        XCTAssertEqual(library.entries.count, 2)
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(library.open(first))
        XCTAssertTrue(library.activeStore?.data.places.isEmpty == true)
        XCTAssertEqual(library.activeStore?.data.trip.hotel, "")
        XCTAssertEqual(library.activeStore?.data.trip.startDate?.rawValue, "2027-04-01")
        XCTAssertFalse(library.activeStore?.data.places.contains(where: { $0.id.hasPrefix("prague-") }) == true)
        XCTAssertTrue(library.showLibrary())
        XCTAssertTrue(library.open(second))
        XCTAssertTrue(library.activeStore?.data.places.isEmpty == true)
    }

    func testMigrationCopiesAlbumFilesAndPreservesLegacy() throws {
        let root = try temporaryRoot()
        let libraryRoot = root.appendingPathComponent("AlbumLibrary")
        let legacy = root.appendingPathComponent("Album")
        var data = AlbumData()
        data.places = [Place(id: "real-place", title: "Museum", category: "Sehenswert")]
        data.trip.hotel = "A real hotel"
        try write(data, to: legacy, extraFile: "images/original.jpg")
        let original = try Data(contentsOf: legacy.appendingPathComponent("album.json"))

        let library = TripLibrary(root: libraryRoot, legacyRoot: legacy,
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")))
        let entry = try XCTUnwrap(library.entries.first)
        XCTAssertEqual(entry.origin, .migrated)
        XCTAssertTrue(FileManager.default.fileExists(atPath: libraryRoot.appendingPathComponent("legacy-migration.json").path))
        XCTAssertTrue(library.open(entry.id))
        XCTAssertEqual(library.activeStore?.data.albumID, data.albumID)
        XCTAssertEqual(library.activeStore?.data.places.map(\.id), ["real-place"])
        XCTAssertEqual(try Data(contentsOf: legacy.appendingPathComponent("album.json")), original)
        XCTAssertTrue(FileManager.default.fileExists(atPath: libraryRoot.appendingPathComponent("Trips", isDirectory: true).appendingPathComponent(entry.id.uuidString).appendingPathComponent("images/original.jpg").path))
    }

    func testInterruptedCopyReusesReceiptIDOnRetry() throws {
        let root = try temporaryRoot()
        let libraryRoot = root.appendingPathComponent("AlbumLibrary")
        let legacy = root.appendingPathComponent("Album")
        try write(AlbumData(), to: legacy)
        var shouldFail = true
        let failing = TripLibrary(root: libraryRoot, legacyRoot: legacy,
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")),
                                  copier: { source, destination in
                                      if shouldFail { shouldFail = false; throw CocoaError(.fileWriteNoSpace) }
                                      try FileManager.default.copyItem(at: source, to: destination)
                                  })
        XCTAssertTrue(failing.entries.isEmpty)
        let receiptData = try Data(contentsOf: libraryRoot.appendingPathComponent("legacy-migration.json"))
        let receipt = try JSONDecoder().decode(LegacyMigrationReceipt.self, from: receiptData)
        XCTAssertEqual(receipt.state, .copying)
        let retry = TripLibrary(root: libraryRoot, legacyRoot: legacy,
                                shareInbox: ShareInbox(root: root.appendingPathComponent("share")))
        XCTAssertEqual(retry.entries.map(\.id), [receipt.id])
    }

    func testCorruptIndexIsBackedUpAndRebuiltFromFolders() throws {
        let root = try temporaryRoot()
        let libraryRoot = root.appendingPathComponent("AlbumLibrary")
        let library = TripLibrary(root: libraryRoot, legacyRoot: root.appendingPathComponent("legacy"),
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")))
        let id = try XCTUnwrap(library.createBlankTrip(title: "Test"))
        try Data("not json".utf8).write(to: libraryRoot.appendingPathComponent("library.json"), options: .atomic)
        let rebuilt = TripLibrary(root: libraryRoot, legacyRoot: root.appendingPathComponent("legacy"),
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")))
        XCTAssertTrue(rebuilt.entries.contains(where: { $0.id == id }))
        let backups = try FileManager.default.contentsOfDirectory(at: libraryRoot, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("library.corrupt-") }
        XCTAssertEqual(backups.count, 1)
    }

    func testStaleCopyingReceiptReplacesModifiedTargetAndPreservesIndexMetadata() throws {
        let root = try temporaryRoot()
        let libraryRoot = root.appendingPathComponent("AlbumLibrary")
        let legacy = root.appendingPathComponent("Album")
        var data = AlbumData(); data.places = [Place(id: "source", title: "Source", category: "Sehenswert")]
        try write(data, to: legacy)
        let id = UUID()
        let target = libraryRoot.appendingPathComponent("Trips", isDirectory: true).appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: legacy, to: target)
        var modified = data; modified.places = [Place(id: "stale", title: "Stale", category: "Sehenswert")]
        try JSONEncoder().encode(modified).write(to: target.appendingPathComponent("album.json"), options: .atomic)
        let created = Date(timeIntervalSince1970: 123)
        let indexed = TripLibraryEntry(id: id, albumID: data.albumID, origin: .blank,
                                       title: "Curated title", createdAt: created)
        try FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
        try JSONEncoder().encode(TripLibraryIndex(entries: [indexed])).write(to: libraryRoot.appendingPathComponent("library.json"), options: .atomic)
        let receipt = LegacyMigrationReceipt(id: id, state: .copying, sourceFiles: 1, sourceBytes: 1,
                                             places: 1, documents: 0, memories: 0, albumID: data.albumID, committedAt: nil)
        try JSONEncoder().encode(receipt).write(to: libraryRoot.appendingPathComponent("legacy-migration.json"), options: .atomic)

        let library = TripLibrary(root: libraryRoot, legacyRoot: legacy,
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")))
        let entry = try XCTUnwrap(library.entries.first(where: { $0.id == id }))
        XCTAssertEqual(entry.origin, .blank)
        XCTAssertEqual(entry.createdAt, created)
        XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("album.json")),
                       try Data(contentsOf: legacy.appendingPathComponent("album.json")))
        let committed = try JSONDecoder().decode(LegacyMigrationReceipt.self,
                                                  from: Data(contentsOf: libraryRoot.appendingPathComponent("legacy-migration.json")))
        XCTAssertEqual(committed.state, .committed)
    }

    func testInsufficientCapacityLeavesLegacyUntouched() throws {
        let root = try temporaryRoot()
        let legacy = root.appendingPathComponent("Album")
        try write(AlbumData(), to: legacy)
        let libraryRoot = root.appendingPathComponent("AlbumLibrary")
        let library = TripLibrary(root: libraryRoot, legacyRoot: legacy,
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")),
                                  availableCapacity: { 1 })
        XCTAssertTrue(library.entries.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("album.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: libraryRoot.appendingPathComponent("legacy-migration.json").path))
    }

    func testForeignShareQueueItemsRemainForTheirTrip() throws {
        let root = try temporaryRoot()
        let inbox = ShareInbox(root: root.appendingPathComponent("share"))
        let storeRoot = root.appendingPathComponent("trip-a")
        var data = AlbumData(); data.places = []; data.albumID = "album-a"
        try FileManager.default.createDirectory(at: storeRoot, withIntermediateDirectories: true)
        try JSONEncoder().encode(data).write(to: storeRoot.appendingPathComponent("album.json"), options: .atomic)
        let store = AlbumStore(root: storeRoot, shareInbox: inbox, publishesShareContext: false)
        store.activateShareContext(); store.publishShareContext()
        let foreign = ShareQueueItem(payload: "other trip", url: nil, tripKey: "local:album-b")
        try inbox.save(foreign)
        store.drainShareQueue()
        XCTAssertEqual(inbox.items().first?.id, foreign.id)
        XCTAssertEqual(inbox.items().first?.state, .pending)
    }

    func testShutdownStopsRealtimeAndLocalCallbacks() async throws {
        let root = try temporaryRoot()
        let store = AlbumStore(root: root.appendingPathComponent("trip"),
                               shareInbox: ShareInbox(root: root.appendingPathComponent("share")),
                               publishesShareContext: false)
        let service = LifecycleService()
        store.syncService = service
        await store.shutdown()
        XCTAssertTrue(service.stopped)
        let didSync = await store.sync()
        XCTAssertFalse(didSync)
    }
}
