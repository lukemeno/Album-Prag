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

    @MainActor
    private final class JoinService: AlbumSyncService {
        final class Behavior {
            let remoteID: UUID
            var failNextJoin = false
            var pauseNextJoin = false
            var joinStarted = false
            var pausedJoinCount = 0
            var releasePausedJoin = false
            var failPausedJoin = false
            init(remoteID: UUID) { self.remoteID = remoteID }
        }
        let behavior: Behavior
        init(behavior: Behavior) { self.behavior = behavior }
        func createTrip(store: AlbumStore) async throws -> CollaborationState { throw AlbumSyncError.missingConfiguration }
        func joinTrip(token: String) async throws -> CollaborationState {
            if behavior.pauseNextJoin {
                behavior.pauseNextJoin = false
                behavior.joinStarted = true
                behavior.pausedJoinCount += 1
                let failAfterPause = behavior.failPausedJoin
                while !behavior.releasePausedJoin { await Task.yield() }
                behavior.pausedJoinCount -= 1
                if behavior.pausedJoinCount == 0 { behavior.releasePausedJoin = false }
                if failAfterPause { throw AlbumSyncError.invalidInvitation }
            }
            if behavior.failNextJoin {
                behavior.failNextJoin = false
                throw AlbumSyncError.invalidInvitation
            }
            return CollaborationState(tripID: behavior.remoteID, inviteToken: token)
        }
        func sync(store: AlbumStore) async throws {}
        func startRealtime(onChange: @escaping @MainActor @Sendable () async -> Void) {}
        func authenticatedUserID() async throws -> String { "test-user" }
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
            try Data("preserve-me".utf8).write(to: url)
        }
    }

    @MainActor
    private final class PausedCallbackService: AlbumSyncService {
        var syncEntered = false
        var releaseSync = false
        var realtimeStarts = 0

        func createTrip(store: AlbumStore) async throws -> CollaborationState { throw AlbumSyncError.missingConfiguration }
        func joinTrip(token: String) async throws -> CollaborationState { throw AlbumSyncError.missingConfiguration }
        func sync(store: AlbumStore) async throws {
            syncEntered = true
            while !releaseSync { await Task.yield() }
        }
        func startRealtime(onChange: @escaping @MainActor @Sendable () async -> Void) {
            realtimeStarts += 1
        }
        func authenticatedUserID() async throws -> String { "test-user" }
    }

    @MainActor
    private final class PausedResultGate<Value> {
        private(set) var requested = false
        private var continuation: CheckedContinuation<Value, Never>?

        func wait() async -> Value {
            requested = true
            return await withCheckedContinuation { continuation = $0 }
        }

        func resume(_ value: Value) {
            continuation?.resume(returning: value)
            continuation = nil
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
        let entry = try XCTUnwrap(library.entries.first, library.error ?? "no library entry; index=\(library.entries)")
        XCTAssertEqual(entry.origin, .migrated)
        XCTAssertTrue(FileManager.default.fileExists(atPath: libraryRoot.appendingPathComponent("legacy-migration.json").path))
        XCTAssertTrue(library.open(entry.id))
        XCTAssertEqual(library.activeStore?.data.albumID, data.albumID)
        XCTAssertEqual(library.activeStore?.data.places.map(\.id), ["real-place"])
        XCTAssertEqual(try Data(contentsOf: legacy.appendingPathComponent("album.json")), original)
        XCTAssertTrue(FileManager.default.fileExists(atPath: libraryRoot.appendingPathComponent("Trips", isDirectory: true).appendingPathComponent(entry.id.uuidString).appendingPathComponent("images/original.jpg").path))
    }

    func testLegacyCleanupRemovesOnlyExactUntouchedTemplates() throws {
        let root = try temporaryRoot()
        let libraryRoot = root.appendingPathComponent("AlbumLibrary")
        let legacy = root.appendingPathComponent("Album")
        let pristine = try XCTUnwrap(Place.examples.first)
        var edited = pristine; edited.note = "Meine Notiz"
        var ownPhoto = pristine; ownPhoto.image = .bundled(name: "my-photo")
        var voted = pristine; voted.approvals = ["Luke"]
        var data = AlbumData(); data.places = [pristine, edited, ownPhoto, voted]
        try write(data, to: legacy)
        let library = TripLibrary(root: libraryRoot, legacyRoot: legacy,
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")))
        let entry = try XCTUnwrap(library.entries.first)
        XCTAssertTrue(library.open(entry.id))
        let places = library.activeStore?.data.places ?? []
        XCTAssertFalse(places.contains(where: { $0 == pristine }))
        XCTAssertTrue(places.contains(where: { $0.note == "Meine Notiz" }))
        XCTAssertTrue(places.contains(where: { $0.image == .bundled(name: "my-photo") }))
        XCTAssertTrue(places.contains(where: { $0.approvals == ["Luke"] }))
        XCTAssertTrue(FileManager.default.fileExists(atPath: libraryRoot.appendingPathComponent("Trips", isDirectory: true)
            .appendingPathComponent(entry.id.uuidString).appendingPathComponent("legacy-pristine-cleanup-v1").path))
    }

    func testSharedLegacyCleanupUsesPlaceTombstones() throws {
        let root = try temporaryRoot()
        let libraryRoot = root.appendingPathComponent("AlbumLibrary")
        let legacy = root.appendingPathComponent("Album")
        let pristine = try XCTUnwrap(Place.examples.first)
        var data = AlbumData(); data.places = [pristine]
        data.collaboration = CollaborationState(tripID: UUID(), inviteToken: nil)
        try write(data, to: legacy)
        let library = TripLibrary(root: libraryRoot, legacyRoot: legacy,
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")))
        let entry = try XCTUnwrap(library.entries.first)
        XCTAssertTrue(library.open(entry.id))
        let tombstone = try XCTUnwrap(library.activeStore?.data.places.first)
        XCTAssertTrue(tombstone.deleted)
        XCTAssertTrue(library.activeStore?.data.dirty.contains(tombstone.id) == true)
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
                                      if shouldFail { shouldFail = false; throw CocoaError(.fileWriteOutOfSpace) }
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

    func testIndexedCopyingReceiptCommitsModifiedTargetAndPreservesIndexMetadata() throws {
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
        let editedBytes = try Data(contentsOf: target.appendingPathComponent("album.json"))
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
        XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("album.json")), editedBytes)
        let committed = try JSONDecoder().decode(LegacyMigrationReceipt.self,
                                                  from: Data(contentsOf: libraryRoot.appendingPathComponent("legacy-migration.json")))
        XCTAssertEqual(committed.state, .committed)
    }

    func testUnindexedCopyingReceiptPreservesUncleanTargetAndSidecars() throws {
        let root = try temporaryRoot()
        let libraryRoot = root.appendingPathComponent("AlbumLibrary")
        let legacy = root.appendingPathComponent("Album")
        var source = AlbumData()
        source.places = [Place(id: "source", title: "Source", category: "Sehenswert")]
        try write(source, to: legacy)
        let id = UUID()
        let target = libraryRoot.appendingPathComponent("Trips", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: target.appendingPathComponent("images"), withIntermediateDirectories: true)
        var edited = source
        edited.places[0].note = "Während der Migration ergänzt"
        try JSONEncoder().encode(edited).write(to: target.appendingPathComponent("album.json"), options: .atomic)
        let sidecar = target.appendingPathComponent("images/edited.jpg")
        let sidecarBytes = Data([0xFF, 0xD8, 0xEE, 0xD9])
        try sidecarBytes.write(to: sidecar)
        let receipt = LegacyMigrationReceipt(id: id, state: .copying, sourceFiles: 1, sourceBytes: 1,
                                             places: 1, documents: 0, memories: 0,
                                             albumID: source.albumID, committedAt: nil)
        try FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
        try JSONEncoder().encode(receipt).write(to: libraryRoot.appendingPathComponent("legacy-migration.json"), options: .atomic)

        let library = TripLibrary(root: libraryRoot, legacyRoot: legacy,
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")))
        let entry = try XCTUnwrap(library.entries.first(where: { $0.id == id }))
        XCTAssertNil(entry.unavailableReason)
        XCTAssertTrue(library.open(id))
        XCTAssertEqual(library.activeStore?.places.first?.note, "Während der Migration ergänzt")
        XCTAssertEqual(try Data(contentsOf: sidecar), sidecarBytes)
        let committed = try JSONDecoder().decode(LegacyMigrationReceipt.self,
                                                  from: Data(contentsOf: libraryRoot.appendingPathComponent("legacy-migration.json")))
        XCTAssertEqual(committed.state, .committed)
    }

    func testCommittedForeignAlbumIdentityIsUnavailableWithoutDeletingTarget() throws {
        let root = try temporaryRoot()
        let libraryRoot = root.appendingPathComponent("AlbumLibrary")
        let legacy = root.appendingPathComponent("Album")
        var source = AlbumData()
        source.places = [Place(id: "source", title: "Source", category: "Sehenswert")]
        try write(source, to: legacy)
        let id = UUID()
        let target = libraryRoot.appendingPathComponent("Trips", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: target.appendingPathComponent("documents"), withIntermediateDirectories: true)
        var foreign = AlbumData()
        foreign.albumID = "foreign-album"
        foreign.places = [Place(id: "foreign", title: "Andere Reise", category: "Sehenswert")]
        let foreignBytes = try JSONEncoder().encode(foreign)
        try foreignBytes.write(to: target.appendingPathComponent("album.json"), options: .atomic)
        let document = target.appendingPathComponent("documents/keep.pdf")
        let documentBytes = Data("foreign-document".utf8)
        try documentBytes.write(to: document)
        let receipt = LegacyMigrationReceipt(id: id, state: .committed, sourceFiles: 1, sourceBytes: 1,
                                             places: 1, documents: 0, memories: 0,
                                             albumID: source.albumID, committedAt: Date())
        try FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
        try JSONEncoder().encode(receipt).write(to: libraryRoot.appendingPathComponent("legacy-migration.json"), options: .atomic)

        let library = TripLibrary(root: libraryRoot, legacyRoot: legacy,
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")))
        let entry = try XCTUnwrap(library.entries.first(where: { $0.id == id }))
        XCTAssertNotNil(entry.unavailableReason)
        XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("album.json")), foreignBytes)
        XCTAssertEqual(try Data(contentsOf: document), documentBytes)
        let preservedReceipt = try JSONDecoder().decode(LegacyMigrationReceipt.self,
                                                        from: Data(contentsOf: libraryRoot.appendingPathComponent("legacy-migration.json")))
        XCTAssertEqual(preservedReceipt.state, .committed)
    }

    func testCorruptExistingTargetIsUnavailableWithoutDeletingSidecars() throws {
        let root = try temporaryRoot()
        let libraryRoot = root.appendingPathComponent("AlbumLibrary")
        let legacy = root.appendingPathComponent("Album")
        var source = AlbumData(); source.places = [Place(id: "source", title: "Source", category: "Sehenswert")]
        try write(source, to: legacy)
        let legacyBytes = try Data(contentsOf: legacy.appendingPathComponent("album.json"))
        let id = UUID()
        let target = libraryRoot.appendingPathComponent("Trips", isDirectory: true).appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: target.appendingPathComponent("images"), withIntermediateDirectories: true)
        try Data("corrupt-json".utf8).write(to: target.appendingPathComponent("album.json"))
        let sidecar = target.appendingPathComponent("images/keep.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: sidecar)
        try FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
        let receipt = LegacyMigrationReceipt(id: id, state: .copying, sourceFiles: 1, sourceBytes: 1,
                                             places: 1, documents: 0, memories: 0, albumID: source.albumID, committedAt: nil)
        try JSONEncoder().encode(receipt).write(to: libraryRoot.appendingPathComponent("legacy-migration.json"), options: .atomic)

        let library = TripLibrary(root: libraryRoot, legacyRoot: legacy,
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")))
        XCTAssertEqual(library.entries.first?.id, id)
        XCTAssertNotNil(library.entries.first?.unavailableReason)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sidecar.path))
        XCTAssertEqual(try Data(contentsOf: sidecar), Data([0xFF, 0xD8, 0xFF, 0xD9]))
        XCTAssertEqual(try Data(contentsOf: legacy.appendingPathComponent("album.json")), legacyBytes)
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

    func testLibraryOverviewClearsContextButRetainsTripQueue() throws {
        let root = try temporaryRoot()
        let inbox = ShareInbox(root: root.appendingPathComponent("share"))
        let library = TripLibrary(root: root.appendingPathComponent("library"),
                                  legacyRoot: root.appendingPathComponent("legacy"),
                                  shareInbox: inbox)
        let tripA = try XCTUnwrap(library.createBlankTrip(title: "A"))
        let tripB = try XCTUnwrap(library.createBlankTrip(title: "B"))
        XCTAssertTrue(library.open(tripA))
        let contextA = try XCTUnwrap(inbox.loadContext())
        try inbox.save(ShareQueueItem(payload: "A queue item", url: nil, tripKey: contextA.tripKey))
        XCTAssertTrue(library.showLibrary())
        XCTAssertNil(inbox.loadContext())
        XCTAssertEqual(inbox.items().count, 1)
        XCTAssertTrue(library.open(tripB))
        XCTAssertNotEqual(inbox.loadContext()?.tripKey, contextA.tripKey)
        XCTAssertEqual(inbox.items().count, 1)
        XCTAssertTrue(library.open(tripA))
        XCTAssertEqual(inbox.loadContext()?.tripKey, contextA.tripKey)
        XCTAssertTrue(inbox.items().isEmpty)
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

    func testStoppedStoreDropsPausedSyncCallbackAfterResume() async throws {
        let root = try temporaryRoot()
        let store = AlbumStore(root: root.appendingPathComponent("trip"),
                               shareInbox: ShareInbox(root: root.appendingPathComponent("share")),
                               publishesShareContext: false)
        let service = PausedCallbackService()
        store.syncService = service
        store.data.collaboration = CollaborationState(tripID: UUID(), inviteToken: nil)
        XCTAssertTrue(store.persist())
        store.activateShareContext()

        let task = Task { await store.sync() }
        while !service.syncEntered { await Task.yield() }
        store.stopOwnedCallbacks()
        service.releaseSync = true
        let syncResult = await task.value
        XCTAssertFalse(syncResult)
        XCTAssertEqual(service.realtimeStarts, 0)
    }

    func testStoppedStoreDropsPausedPhotoCallbackAfterResume() async throws {
        let root = try temporaryRoot()
        let store = AlbumStore(root: root.appendingPathComponent("trip"),
                               shareInbox: ShareInbox(root: root.appendingPathComponent("share")),
                               publishesShareContext: false)
        let place = Place(id: "paused-photo", title: "Museum", category: "Sehenswert", lat: 50.08, lng: 14.42)
        XCTAssertTrue(store.upsert(place))
        let gate = PausedResultGate<PlaceImageSearchResult>()
        store.placeImageSearchResolver = { _, _ in await gate.wait() }
        let task = Task { await store.refreshPlaceImage(id: place.id, force: true, automatic: true) }
        while !gate.requested { await Task.yield() }
        store.stopOwnedCallbacks()
        gate.resume(PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking))
        await task.value
        XCTAssertNil(store.places.first(where: { $0.id == place.id })?.image)
        if case .idle = store.placeImageStatus(for: place.id) {} else {
            XCTFail("A stopped store must not publish the paused photo result")
        }
    }

    func testJoinInvitationUsesStagingAndDeduplicatesRemoteTrip() async throws {
        let root = try temporaryRoot()
        let remoteID = UUID()
        let behavior = JoinService.Behavior(remoteID: remoteID)
        let library = TripLibrary(root: root.appendingPathComponent("library"),
                                  legacyRoot: root.appendingPathComponent("legacy"),
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")),
                                  storeFactory: { path, inbox, publishes in
                                      let store = AlbumStore(root: path, shareInbox: inbox, publishesShareContext: publishes)
                                      store.syncService = JoinService(behavior: behavior)
                                      return store
                                  })
        let invite = try XCTUnwrap(InvitationLink.make(token: String(repeating: "a", count: 32)))
        let first = try await library.joinInvitation(invite)
        XCTAssertEqual(library.entries.count, 1)
        XCTAssertEqual(library.entries.first?.remoteTripID, remoteID)
        XCTAssertEqual(library.activeID, first)
        let contextBefore = library.shareInbox.loadContext()
        behavior.failNextJoin = true
        do {
            _ = try await library.joinInvitation(invite)
            XCTFail("Expected failed staged join")
        } catch {}
        XCTAssertEqual(library.activeID, first)
        XCTAssertEqual(library.entries.count, 1)
        XCTAssertEqual(library.shareInbox.loadContext(), contextBefore)
        let second = try await library.joinInvitation(invite)
        XCTAssertEqual(second, first)
        XCTAssertEqual(library.entries.count, 1)
        XCTAssertEqual(library.activeID, first)
    }

    func testFailedPausedInvitationCannotEraseConcurrentSuccessfulJoin() async throws {
        let root = try temporaryRoot()
        let remoteID = UUID()
        let behavior = JoinService.Behavior(remoteID: remoteID)
        let library = TripLibrary(root: root.appendingPathComponent("library"),
                                  legacyRoot: root.appendingPathComponent("legacy"),
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")),
                                  storeFactory: { path, inbox, publishes in
                                      let store = AlbumStore(root: path, shareInbox: inbox, publishesShareContext: publishes)
                                      store.syncService = JoinService(behavior: behavior)
                                      return store
                                  })
        let invite = try XCTUnwrap(InvitationLink.make(token: String(repeating: "c", count: 32)))
        behavior.pauseNextJoin = true
        behavior.failPausedJoin = true
        let failedJoin = Task { try? await library.joinInvitation(invite) }
        while !behavior.joinStarted { await Task.yield() }

        let successfulID = try await library.joinInvitation(invite)
        XCTAssertEqual(library.entries.count, 1)
        XCTAssertEqual(library.activeID, successfulID)
        behavior.releasePausedJoin = true
        let failedResult = await failedJoin.value
        XCTAssertNil(failedResult)
        XCTAssertEqual(library.entries.count, 1)
        XCTAssertEqual(library.entries.first?.remoteTripID, remoteID)
        XCTAssertEqual(library.activeID, successfulID)
    }

    func testConcurrentSuccessfulInvitationsConvergeAfterStagedShutdown() async throws {
        let root = try temporaryRoot()
        let remoteID = UUID()
        let behavior = JoinService.Behavior(remoteID: remoteID)
        let library = TripLibrary(root: root.appendingPathComponent("library"),
                                  legacyRoot: root.appendingPathComponent("legacy"),
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("share")),
                                  storeFactory: { path, inbox, publishes in
                                      let store = AlbumStore(root: path, shareInbox: inbox, publishesShareContext: publishes)
                                      store.syncService = JoinService(behavior: behavior)
                                      return store
                                  })
        let invite = try XCTUnwrap(InvitationLink.make(token: String(repeating: "d", count: 32)))
        behavior.pauseNextJoin = true
        let first = Task { try? await library.joinInvitation(invite) }
        while behavior.pausedJoinCount < 1 { await Task.yield() }
        behavior.pauseNextJoin = true
        let second = Task { try? await library.joinInvitation(invite) }
        while behavior.pausedJoinCount < 2 { await Task.yield() }
        behavior.releasePausedJoin = true

        let firstResult = await first.value
        let secondResult = await second.value
        let firstID = try XCTUnwrap(firstResult)
        let secondID = try XCTUnwrap(secondResult)
        XCTAssertEqual(firstID, secondID)
        XCTAssertEqual(library.entries.count, 1)
        XCTAssertEqual(library.entries.first?.remoteTripID, remoteID)
    }

    func testIndexCommitFailureRollsBackCreatedTripAndJoinedFolder() async throws {
        let root = try temporaryRoot()
        let inbox = ShareInbox(root: root.appendingPathComponent("share"))
        let failingWriter: (Data, URL) throws -> Void = { _, _ in throw CocoaError(.fileWriteUnknown) }
        let blankLibrary = TripLibrary(root: root.appendingPathComponent("blank-library"),
                                       legacyRoot: root.appendingPathComponent("blank-legacy"),
                                       shareInbox: inbox, indexWriter: failingWriter)
        XCTAssertNil(blankLibrary.createBlankTrip(title: "Rollback"))
        XCTAssertTrue(blankLibrary.entries.isEmpty)
        let blankTrips = try FileManager.default.contentsOfDirectory(at: blankLibrary.root.appendingPathComponent("Trips"), includingPropertiesForKeys: nil)
        XCTAssertTrue(blankTrips.isEmpty)

        let behavior = JoinService.Behavior(remoteID: UUID())
        let joinedLibrary = TripLibrary(root: root.appendingPathComponent("join-library"),
                                        legacyRoot: root.appendingPathComponent("join-legacy"),
                                        shareInbox: inbox,
                                        storeFactory: { path, shareInbox, publishes in
                                            let store = AlbumStore(root: path, shareInbox: shareInbox, publishesShareContext: publishes)
                                            store.syncService = JoinService(behavior: behavior)
                                            return store
                                        },
                                        indexWriter: failingWriter)
        let invite = try XCTUnwrap(InvitationLink.make(token: String(repeating: "b", count: 32)))
        do {
            _ = try await joinedLibrary.joinInvitation(invite)
            XCTFail("Expected index commit failure")
        } catch {}
        XCTAssertTrue(joinedLibrary.entries.isEmpty)
        let joinTrips = try FileManager.default.contentsOfDirectory(at: joinedLibrary.root.appendingPathComponent("Trips"), includingPropertiesForKeys: nil)
        XCTAssertTrue(joinTrips.isEmpty)
    }
}
