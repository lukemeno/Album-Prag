import Foundation
import XCTest
@testable import Album

@MainActor
final class SyncRegressionTests: XCTestCase {
    private var root: URL!

    func testRealtimeReadinessRequiresBothServerConfirmationsInEitherOrder() throws {
        for names in [["postgres_changes", "system"], ["system", "postgres_changes"]] {
            var readiness = SupabaseRealtimeReadiness()
            XCTAssertFalse(try readiness.receive(extensionName: names[0], status: "ok"))
            XCTAssertFalse(try readiness.receive(extensionName: names[0], status: "ok"))
            XCTAssertTrue(try readiness.receive(extensionName: names[1], status: "ok"))
        }
    }

    func testRealtimeReadinessRejectsErrorsBeforeCatchup() throws {
        for name in ["postgres_changes", "system"] {
            for status in ["error", "timeout"] {
                var readiness = SupabaseRealtimeReadiness()
                XCTAssertThrowsError(try readiness.receive(extensionName: name, status: status))
            }
        }
    }

    func testUnrelatedSystemMessagesCannotEstablishRealtimeReadiness() throws {
        var readiness = SupabaseRealtimeReadiness()
        XCTAssertFalse(try readiness.receive(extensionName: "presence", status: "ok"))
        XCTAssertFalse(try readiness.receive(extensionName: nil, status: "ok"))
        XCTAssertFalse(try readiness.receive(extensionName: "system", status: nil))
        XCTAssertFalse(try readiness.receive(extensionName: "postgres_changes", status: "ok"))
        XCTAssertTrue(try readiness.receive(extensionName: "system", status: "ok"))
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async throws {
        for _ in 0..<400 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Realtime-Testbed condition timed out after 2 seconds")
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("sync-regression-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        try super.tearDownWithError()
    }

    func testTripMutationDuringWriteKeepsDirtyMarkerAndPayload() async throws {
        let store = AlbumStore(root: root)
        store.data.trip.notes = "vorher"
        store.data.dirty = ["trip"]
        XCTAssertTrue(store.persist())

        let transport = PausingSyncWriteTransport(pause: .trip)
        let sync = SupabaseSync(writeTransport: transport)
        let tripID = UUID()
        let task = Task { try await sync.pushDirtyForTesting(store: store, tripID: tripID) }
        while !transport.entered.contains(.trip) { try await Task.sleep(for: .milliseconds(5)) }

        store.data.trip.notes = "neu während Upload"
        store.data.trip.updatedAt = Date()
        store.data.dirty.insert("trip")
        transport.resume()
        try await task.value

        XCTAssertEqual(transport.tripPayload?.notes, "vorher")
        XCTAssertEqual(store.data.trip.notes, "neu während Upload")
        XCTAssertTrue(store.data.dirty.contains("trip"))
    }

    func testUnchangedTripWriteAcknowledgesDirtyMarkerRepeatedly() async throws {
        let store = AlbumStore(root: root)
        store.data.trip.notes = "stabil"
        store.data.dirty = ["trip"]
        XCTAssertTrue(store.persist())
        let transport = PausingSyncWriteTransport()
        let sync = SupabaseSync(writeTransport: transport)

        try await sync.pushDirtyForTesting(store: store, tripID: UUID())
        XCTAssertFalse(store.data.dirty.contains("trip"))
        store.data.dirty.insert("trip")
        try await sync.pushDirtyForTesting(store: store, tripID: UUID())
        XCTAssertFalse(store.data.dirty.contains("trip"))
        XCTAssertEqual(transport.tripWriteCount, 2)
    }

    func testPlaceMutationDuringWriteKeepsDirtyMarkerAndPayload() async throws {
        let store = AlbumStore(root: root)
        let original = Place(id: "place-1", title: "Vorher")
        store.data.places = [original]
        store.data.dirty = [original.id]
        XCTAssertTrue(store.persist())

        let transport = PausingSyncWriteTransport(pause: .place)
        let sync = SupabaseSync(writeTransport: transport)
        let task = Task { try await sync.pushDirtyForTesting(store: store, tripID: UUID()) }
        while !transport.entered.contains(.place) { try await Task.sleep(for: .milliseconds(5)) }

        var current = original
        current.title = "Neu während Upload"
        current.updatedAt = Date()
        store.data.places[0] = current
        store.data.dirty.insert(original.id)
        transport.resume()
        try await task.value

        XCTAssertEqual(transport.placePayload?.title, "Vorher")
        XCTAssertEqual(store.data.places.first?.title, "Neu während Upload")
        XCTAssertTrue(store.data.dirty.contains(original.id))
    }

    func testDocumentMutationDuringUploadDoesNotUpsertOldMetadata() async throws {
        let store = AlbumStore(root: root)
        let document = TravelDocument(id: "doc-1", name: "Vorher", filename: "doc-1.pdf", extractedText: "alt")
        store.data.documents = [document]
        store.data.dirty = ["doc-\(document.id)"]
        try Data("pdf".utf8).write(to: root.appendingPathComponent(document.filename))
        XCTAssertTrue(store.persist())

        let transport = PausingSyncWriteTransport(pause: .documentUpload)
        let sync = SupabaseSync(writeTransport: transport)
        let task = Task { try await sync.pushDirtyForTesting(store: store, tripID: UUID()) }
        while !transport.entered.contains(.documentUpload) { try await Task.sleep(for: .milliseconds(5)) }

        var current = document
        current.name = "Neu während Upload"
        current.updatedAt = Date()
        store.data.documents[0] = current
        store.data.dirty.insert("doc-\(document.id)")
        transport.resume()
        try await task.value

        XCTAssertEqual(transport.documentUploadPath?.hasSuffix("/doc-1.pdf"), true)
        XCTAssertNil(transport.documentPayload)
        XCTAssertEqual(store.data.documents.first?.name, "Neu während Upload")
        XCTAssertTrue(store.data.dirty.contains("doc-\(document.id)"))
    }

    func testUnchangedDocumentWriteAcknowledgesDirtyMarkerRepeatedly() async throws {
        let store = AlbumStore(root: root)
        let document = TravelDocument(id: "doc-stable", name: "Stabil", filename: "doc-stable.pdf", extractedText: "text")
        store.data.documents = [document]
        store.data.dirty = ["doc-\(document.id)"]
        try Data("pdf".utf8).write(to: root.appendingPathComponent(document.filename))
        XCTAssertTrue(store.persist())
        let transport = PausingSyncWriteTransport()
        let sync = SupabaseSync(writeTransport: transport)

        try await sync.pushDirtyForTesting(store: store, tripID: UUID())
        XCTAssertFalse(store.data.dirty.contains("doc-\(document.id)"))
        store.data.dirty.insert("doc-\(document.id)")
        try await sync.pushDirtyForTesting(store: store, tripID: UUID())
        XCTAssertFalse(store.data.dirty.contains("doc-\(document.id)"))
        XCTAssertEqual(transport.documentWriteCount, 2)
    }

    func testImageUploadPreservesNewerPlacePayloadAndAttachesOnlySameImagePath() async throws {
        let store = AlbumStore(root: root)
        let image = UploadedPlaceImage(id: "image-1", storagePath: nil, pixelWidth: 1, pixelHeight: 1)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("images"), withIntermediateDirectories: true)
        try Data("jpeg".utf8).write(to: PlaceImageStorage.localURL(for: image, root: root))
        let original = Place(id: "place-image", title: "Vorher", image: .uploaded(image))
        store.data.places = [original]
        store.data.dirty = [original.id]
        XCTAssertTrue(store.persist())

        let transport = PausingSyncWriteTransport(pause: .image)
        let sync = SupabaseSync(writeTransport: transport)
        let tripID = UUID()
        let task = Task { try await sync.pushDirtyForTesting(store: store, tripID: tripID) }
        while !transport.entered.contains(.image) { try await Task.sleep(for: .milliseconds(5)) }

        var current = original
        current.title = "Neu während Bildupload"
        current.updatedAt = Date()
        store.data.places[0] = current
        store.data.dirty.insert(original.id)
        transport.resume()
        try await task.value

        XCTAssertEqual(transport.placePayload?.title, "Neu während Bildupload")
        guard case .uploaded(let uploaded)? = transport.placePayload?.image else { return XCTFail("Bild fehlt im Payload") }
        XCTAssertEqual(uploaded.id, image.id)
        XCTAssertEqual(uploaded.storagePath, "\(tripID.uuidString)/place-image/image-1.jpg")
        XCTAssertEqual(store.data.places.first?.title, "Neu während Bildupload")
        XCTAssertFalse(store.data.dirty.contains(original.id))
    }

    func testImageUploadDoesNotAttachOldPathToNewerImage() async throws {
        let store = AlbumStore(root: root)
        let oldImage = UploadedPlaceImage(id: "image-old", storagePath: nil, pixelWidth: 1, pixelHeight: 1)
        let newImage = UploadedPlaceImage(id: "image-new", storagePath: nil, pixelWidth: 1, pixelHeight: 1)
        let imageRoot = root.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imageRoot, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: PlaceImageStorage.localURL(for: oldImage, root: root))
        try Data("new".utf8).write(to: PlaceImageStorage.localURL(for: newImage, root: root))
        let original = Place(id: "place-image-switch", title: "Vorher", image: .uploaded(oldImage))
        store.data.places = [original]
        store.data.dirty = [original.id]
        XCTAssertTrue(store.persist())

        let transport = PausingSyncWriteTransport(pause: .image)
        let sync = SupabaseSync(writeTransport: transport)
        let task = Task { try await sync.pushDirtyForTesting(store: store, tripID: UUID()) }
        while !transport.entered.contains(.image) { try await Task.sleep(for: .milliseconds(5)) }

        var current = original
        current.title = "Neues Bild"
        current.image = .uploaded(newImage)
        current.updatedAt = Date()
        store.data.places[0] = current
        store.data.dirty.insert(original.id)
        transport.resume()
        try await task.value

        XCTAssertNil(transport.placePayload)
        XCTAssertEqual(store.data.places.first?.title, "Neues Bild")
        guard case .uploaded(let uploaded)? = store.data.places.first?.image else { return XCTFail("Neues Bild fehlt") }
        XCTAssertEqual(uploaded.id, newImage.id)
        XCTAssertNil(uploaded.storagePath)
        XCTAssertTrue(store.data.dirty.contains(original.id))
    }

    func testRealtimeSubscribeFailureAllowsLaterStart() async throws {
        let realtime = PausingRealtimeTransport(failures: 1)
        let sync = SupabaseSync(writeTransport: PausingSyncWriteTransport(), realtimeTransport: realtime)
        let tripID = UUID()
        sync.activateTripForTesting(tripID)
        sync.startRealtime(onChange: {})
        while realtime.attempts < 1 { try await Task.sleep(for: .milliseconds(5)) }
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(realtime.attempts, 1)
        sync.startRealtime(onChange: {})
        while realtime.attempts < 2 { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(realtime.attempts, 2)
        realtime.resume(tripID)
    }

    func testRealtimeReadyFollowsInitialCatchupAndResetsOnStop() async throws {
        let realtime = CatchupRealtimeTransport()
        let sync = SupabaseSync(writeTransport: PausingSyncWriteTransport(), realtimeTransport: realtime)
        let tripID = UUID()
        var callbacks = 0
        sync.activateTripForTesting(tripID)
        sync.startRealtime {
            await realtime.blockCatchupCallback()
            callbacks += 1
        }

        try await waitUntil { realtime.started }
        XCTAssertFalse(sync.isRealtimeReady)
        realtime.releaseInitialCatchup()
        try await waitUntil { realtime.callbackEntered }
        XCTAssertFalse(sync.isRealtimeReady)
        realtime.releaseCatchupCallback()
        try await waitUntil { sync.isRealtimeReady }
        XCTAssertEqual(callbacks, 1)

        await sync.stopRealtime()
        XCTAssertFalse(sync.isRealtimeReady)
    }

    func testObsoleteRealtimeTaskCannotClearNewerTripState() async throws {
        let realtime = PausingRealtimeTransport()
        let sync = SupabaseSync(writeTransport: PausingSyncWriteTransport(), realtimeTransport: realtime)
        let firstTrip = UUID()
        let secondTrip = UUID()
        sync.activateTripForTesting(firstTrip)
        sync.startRealtime(onChange: {})
        while realtime.tripIDs.count < 1 { try await Task.sleep(for: .milliseconds(5)) }

        sync.activateTripForTesting(secondTrip)
        sync.startRealtime(onChange: {})
        while realtime.tripIDs.count < 2 { try await Task.sleep(for: .milliseconds(5)) }
        realtime.resume(firstTrip)
        try await Task.sleep(for: .milliseconds(20))

        sync.startRealtime(onChange: {})
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(realtime.tripIDs, [firstTrip, secondTrip])
        realtime.resume(secondTrip)
    }

    func testStopRealtimeCancelsAndAllowsSameTripRestart() async throws {
        let realtime = CancellingRealtimeTransport()
        let sync = SupabaseSync(writeTransport: PausingSyncWriteTransport(), realtimeTransport: realtime)
        let tripID = UUID()
        sync.activateTripForTesting(tripID)
        sync.startRealtime(onChange: {})
        try await waitUntil { realtime.started }

        await sync.stopRealtime()
        XCTAssertTrue(realtime.cancelled)

        sync.startRealtime(onChange: {})
        try await waitUntil { realtime.starts >= 2 }
        XCTAssertEqual(realtime.starts, 2)
        sync.startRealtime(onChange: {})
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(realtime.starts, 2, "Ein laufender Same-Trip-Channel darf nicht dupliziert werden")
        await sync.stopRealtime()
    }

    func testRealtimeTaskCancelsWhenSyncIsReleased() async throws {
        let realtime = CancellingRealtimeTransport()
        var sync: SupabaseSync? = SupabaseSync(writeTransport: PausingSyncWriteTransport(), realtimeTransport: realtime)
        let tripID = UUID()
        sync?.activateTripForTesting(tripID)
        sync?.startRealtime(onChange: {})
        try await waitUntil { realtime.started }

        sync = nil
        try await waitUntil { realtime.cancelled }
        XCTAssertTrue(realtime.cancelled)
    }

    func testCancelledTaskCannotStartRealtime() async throws {
        let realtime = PausingRealtimeTransport()
        let sync = SupabaseSync(writeTransport: PausingSyncWriteTransport(), realtimeTransport: realtime)
        sync.activateTripForTesting(UUID())
        let task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            sync.startRealtime(onChange: {})
        }
        task.cancel()
        await task.value
        try await Task.sleep(for: .milliseconds(20))

        XCTAssertEqual(realtime.attempts, 0)
    }

    func testStaleRealtimeCallbackCannotReachNewerTrip() async throws {
        let realtime = CallbackRealtimeTransport()
        let sync = SupabaseSync(writeTransport: PausingSyncWriteTransport(), realtimeTransport: realtime)
        let firstTrip = UUID()
        let secondTrip = UUID()
        var callbackCount = 0

        sync.activateTripForTesting(firstTrip)
        sync.startRealtime { callbackCount += 1 }
        try await waitUntil { realtime.callbacks[firstTrip] != nil }
        sync.activateTripForTesting(secondTrip)
        sync.startRealtime { callbackCount += 1 }
        try await waitUntil { realtime.callbacks[secondTrip] != nil }

        await realtime.emit(firstTrip)
        XCTAssertEqual(callbackCount, 0)
        await realtime.emit(secondTrip)
        XCTAssertEqual(callbackCount, 1)
        await sync.stopRealtime()
    }
}

@MainActor
private final class PausingSyncWriteTransport: SupabaseSyncWriteTransport {
    enum Operation: Hashable { case trip, place, image, documentUpload, documentUpsert }
    var pause: Operation?
    var entered: Set<Operation> = []
    var tripPayload: TripInfo?
    var tripWriteCount = 0
    var placePayload: Place?
    var documentUploadPath: String?
    var documentPayload: String?
    var documentWriteCount = 0
    private var continuation: CheckedContinuation<Void, Never>?

    init(pause: Operation? = nil) { self.pause = pause }

    func updateTrip(tripID: UUID, payload: TripInfo) async throws {
        tripWriteCount += 1
        tripPayload = payload
        await waitIfNeeded(.trip)
    }

    func uploadImage(path: String, data: Data) async throws {
        await waitIfNeeded(.image)
    }

    func upsertPlace(id: String, tripID: UUID, payload: Place, updatedAt: Date, deleted: Bool) async throws {
        placePayload = payload
        await waitIfNeeded(.place)
    }

    func uploadDocument(path: String, data: Data) async throws {
        documentWriteCount += 1
        documentUploadPath = path
        await waitIfNeeded(.documentUpload)
    }

    func upsertDocument(id: String, tripID: UUID, name: String, filename: String, extractedText: String, storagePath: String, updatedAt: Date) async throws {
        documentPayload = name
        await waitIfNeeded(.documentUpsert)
    }

    func removeImage(path: String) async throws {}

    func resume() {
        continuation?.resume()
        continuation = nil
        pause = nil
    }

    private func waitIfNeeded(_ operation: Operation) async {
        guard pause == operation else { return }
        entered.insert(operation)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in self.continuation = continuation }
    }
}

@MainActor
private final class PausingRealtimeTransport: SupabaseRealtimeTransport {
    var failures: Int
    var attempts = 0
    var tripIDs: [UUID] = []
    private var continuations: [UUID: CheckedContinuation<Void, Never>] = [:]

    init(failures: Int = 0) { self.failures = failures }

    func subscribe(tripID: UUID, onChange: @escaping @MainActor @Sendable () async -> Void) async throws {
        attempts += 1
        tripIDs.append(tripID)
        if failures > 0 {
            failures -= 1
            throw NSError(domain: "SyncRegression", code: 1)
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in continuations[tripID] = continuation }
    }

    func resume(_ tripID: UUID) {
        continuations.removeValue(forKey: tripID)?.resume()
    }
}

@MainActor
private final class CatchupRealtimeTransport: SupabaseRealtimeTransport {
    var started = false
    var callbackEntered = false
    private var initialCatchup: CheckedContinuation<Void, Never>?
    private var callbackContinuation: CheckedContinuation<Void, Never>?

    func subscribe(tripID: UUID, onChange: @escaping @MainActor @Sendable () async -> Void) async throws {
        started = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            initialCatchup = continuation
        }
        guard !Task.isCancelled else { return }
        await onChange()
        do {
            try await Task.sleep(for: .seconds(3600))
        } catch is CancellationError {
            // Cooperative cancellation ends the fake subscription.
        }
    }

    func releaseInitialCatchup() {
        initialCatchup?.resume()
        initialCatchup = nil
    }

    func blockCatchupCallback() async {
        callbackEntered = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            callbackContinuation = continuation
        }
    }

    func releaseCatchupCallback() {
        callbackContinuation?.resume()
        callbackContinuation = nil
    }
}

@MainActor
private final class CancellingRealtimeTransport: SupabaseRealtimeTransport {
    var starts = 0
    var started = false
    var cancelled = false

    func subscribe(tripID: UUID, onChange: @escaping @MainActor @Sendable () async -> Void) async throws {
        starts += 1
        started = true
        do {
            try await Task.sleep(for: .seconds(3600))
        } catch is CancellationError {
            cancelled = true
        }
    }
}

@MainActor
private final class CallbackRealtimeTransport: SupabaseRealtimeTransport {
    var callbacks: [UUID: @MainActor @Sendable () async -> Void] = [:]

    func subscribe(tripID: UUID, onChange: @escaping @MainActor @Sendable () async -> Void) async throws {
        callbacks[tripID] = onChange
        do {
            try await Task.sleep(for: .seconds(3600))
        } catch is CancellationError {
            // Cooperative cancellation ends the fake subscription.
        }
    }

    func emit(_ tripID: UUID) async {
        await callbacks[tripID]?()
    }
}
