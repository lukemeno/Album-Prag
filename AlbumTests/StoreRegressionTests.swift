import XCTest
import PDFKit
import CoreLocation
@testable import Album

@MainActor
final class StoreRegressionTests: XCTestCase {
    private var roots: [URL] = []

    override func tearDownWithError() throws {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots.removeAll()
        try super.tearDownWithError()
    }

    private func makeRoot() -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("store-regression-\(UUID().uuidString)", isDirectory: true)
        roots.append(root)
        return root
    }

    private func makeStore(at root: URL) -> AlbumStore {
        AlbumStore(root: root, shareInbox: ShareInbox(root: makeRoot()))
    }

    private func makePersistenceBlocker(for root: URL) throws {
        let albumFile = root.appendingPathComponent("album.json")
        try FileManager.default.removeItem(at: albumFile)
        try FileManager.default.createDirectory(at: albumFile, withIntermediateDirectories: false)
    }

    func testUpsertRollsBackWithoutDeletingCallerOwnedImageWhenPersistenceFails() throws {
        let root = makeRoot()
        let store = makeStore(at: root)
        let oldImage = UploadedPlaceImage(id: "old", storagePath: nil, pixelWidth: 1, pixelHeight: 1)
        let newImage = UploadedPlaceImage(id: "new", storagePath: nil, pixelWidth: 1, pixelHeight: 1)
        let images = root.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: PlaceImageStorage.localURL(for: oldImage, root: root))
        try Data("new".utf8).write(to: PlaceImageStorage.localURL(for: newImage, root: root))

        let original = Place(id: "photo-place", title: "Vorher", image: .uploaded(oldImage))
        store.data.places = [original]
        XCTAssertTrue(store.persist())
        try makePersistenceBlocker(for: root)

        var replacement = original
        replacement.title = "Nachher"
        replacement.image = .uploaded(newImage)
        XCTAssertFalse(store.upsert(replacement))
        XCTAssertEqual(store.data.places.first, original)
        XCTAssertTrue(FileManager.default.fileExists(atPath: PlaceImageStorage.localURL(for: oldImage, root: root).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: PlaceImageStorage.localURL(for: newImage, root: root).path))
    }

    func testSuccessfulImageReplacementRemovesOldFileAfterCommit() throws {
        let root = makeRoot()
        let store = makeStore(at: root)
        let oldImage = UploadedPlaceImage(id: "old", storagePath: nil, pixelWidth: 1, pixelHeight: 1)
        let newImage = UploadedPlaceImage(id: "new", storagePath: nil, pixelWidth: 1, pixelHeight: 1)
        let images = root.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: PlaceImageStorage.localURL(for: oldImage, root: root))
        try Data("new".utf8).write(to: PlaceImageStorage.localURL(for: newImage, root: root))
        let original = Place(id: "photo-place", title: "Vorher", image: .uploaded(oldImage))
        store.data.places = [original]
        XCTAssertTrue(store.persist())

        var replacement = original
        replacement.title = "Nachher"
        replacement.image = .uploaded(newImage)
        XCTAssertTrue(store.upsert(replacement))
        XCTAssertFalse(FileManager.default.fileExists(atPath: PlaceImageStorage.localURL(for: oldImage, root: root).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: PlaceImageStorage.localURL(for: newImage, root: root).path))
    }

    func testTripAndPDFMutationsRollBackTogetherWithCopiedPDF() throws {
        let root = makeRoot()
        let store = makeStore(at: root)
        store.data.trip.notes = "Vorher"
        XCTAssertTrue(store.persist())

        let pdf = PDFDocument()
        pdf.insert(PDFPage(), at: 0)
        let sourceRoot = makeRoot()
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        let source = sourceRoot.appendingPathComponent("booking.pdf")
        let sourceData = try XCTUnwrap(pdf.dataRepresentation())
        try sourceData.write(to: source)
        try makePersistenceBlocker(for: root)

        var changedTrip = store.data.trip
        changedTrip.notes = "Nachher"
        XCTAssertFalse(store.updateTrip(changedTrip))
        XCTAssertEqual(store.data.trip.notes, "Vorher")

        XCTAssertThrowsError(try store.importPDF(source, id: "booking"))
        XCTAssertTrue(store.data.documents.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("booking.pdf").path))
    }

    func testUpdateTripReturnsTrueAndPersistsCommittedTrip() throws {
        let root = makeRoot()
        let store = makeStore(at: root)
        var changedTrip = store.data.trip
        changedTrip.notes = "Gespeichert"

        XCTAssertTrue(store.updateTrip(changedTrip))
        XCTAssertEqual(AlbumStore(root: root).data.trip.notes, "Gespeichert")
    }

    func testBackfillSeedLocationsRepairsOnlyUntouchedMissingCoordinatesAndPersists() throws {
        let seed = try XCTUnwrap(Place.examples.first(where: { $0.id == "prague-alchemiae" }))
        XCTAssertNotNil(seed.coordinate)

        let missingRoot = makeRoot()
        let missingStore = makeStore(at: missingRoot)
        var missing = seed
        missing.lat = nil
        missing.lng = nil
        missing.address = ""
        missingStore.data.places = [missing]
        XCTAssertTrue(missingStore.persist())
        XCTAssertTrue(missingStore.backfillSeedLocations())

        let repaired = try XCTUnwrap(missingStore.data.places.first)
        XCTAssertEqual(repaired.coordinate?.latitude, seed.coordinate?.latitude)
        XCTAssertEqual(repaired.coordinate?.longitude, seed.coordinate?.longitude)
        XCTAssertEqual(repaired.address, seed.address)

        let editedRoot = makeRoot()
        let editedStore = makeStore(at: editedRoot)
        var edited = seed
        edited.title = "Eigene Bezeichnung"
        edited.lat = nil
        edited.lng = nil
        edited.address = "Eigene Adresse"
        editedStore.data.places = [edited]
        XCTAssertTrue(editedStore.persist())
        XCTAssertTrue(editedStore.backfillSeedLocations())

        let unchangedEdited = try XCTUnwrap(editedStore.data.places.first)
        XCTAssertNil(unchangedEdited.coordinate)
        XCTAssertEqual(unchangedEdited.title, edited.title)
        XCTAssertEqual(unchangedEdited.address, edited.address)

        var movedAddress = seed
        movedAddress.lat = nil
        movedAddress.lng = nil
        movedAddress.address = "Vom Nutzer geänderter Ort"
        editedStore.data.places = [movedAddress]
        XCTAssertTrue(editedStore.persist())
        XCTAssertTrue(editedStore.backfillSeedLocations())
        XCTAssertNil(editedStore.data.places.first?.coordinate)
        XCTAssertEqual(editedStore.data.places.first?.address, movedAddress.address)

        let locatedRoot = makeRoot()
        let locatedStore = makeStore(at: locatedRoot)
        var alreadyLocated = seed
        alreadyLocated.lat = 50.1
        alreadyLocated.lng = 14.5
        alreadyLocated.address = "Eigene Adresse"
        locatedStore.data.places = [alreadyLocated]
        XCTAssertTrue(locatedStore.persist())
        XCTAssertTrue(locatedStore.backfillSeedLocations())

        let unchangedLocated = try XCTUnwrap(locatedStore.data.places.first)
        XCTAssertEqual(unchangedLocated.coordinate?.latitude, alreadyLocated.coordinate?.latitude)
        XCTAssertEqual(unchangedLocated.coordinate?.longitude, alreadyLocated.coordinate?.longitude)
        XCTAssertEqual(unchangedLocated.address, alreadyLocated.address)

        let reloaded = AlbumStore(root: missingRoot)
        let persisted = try XCTUnwrap(reloaded.data.places.first)
        XCTAssertEqual(persisted.coordinate?.latitude, seed.coordinate?.latitude)
        XCTAssertEqual(persisted.coordinate?.longitude, seed.coordinate?.longitude)
        XCTAssertEqual(persisted.address, seed.address)
    }

    func testBackfillMigratesLegacyAlchemiaeSourceWithoutChangingSavedCoordinate() throws {
        let root = makeRoot()
        let store = makeStore(at: root)
        let seed = try XCTUnwrap(Place.examples.first(where: { $0.id == "prague-alchemiae" }))
        var legacy = seed
        legacy.sourceURL = "http://alchemiae.cz/cs"
        legacy.lat = 50.091
        legacy.lng = 14.423
        store.data.places = [legacy]
        XCTAssertTrue(store.persist())

        XCTAssertTrue(store.backfillSeedLocations())
        let migrated = try XCTUnwrap(store.data.places.first)
        XCTAssertEqual(migrated.sourceURL, seed.sourceURL)
        XCTAssertEqual(migrated.coordinate?.latitude, legacy.coordinate?.latitude)
        XCTAssertEqual(migrated.coordinate?.longitude, legacy.coordinate?.longitude)

        let reloaded = AlbumStore(root: root)
        XCTAssertEqual(reloaded.data.places.first?.sourceURL, seed.sourceURL)
        XCTAssertEqual(reloaded.data.places.first?.coordinate?.latitude, legacy.coordinate?.latitude)
        XCTAssertEqual(reloaded.data.places.first?.coordinate?.longitude, legacy.coordinate?.longitude)
    }

    func testSinglePlaceSourcePreviewStoresThumbnailAndHonorsStaleGuards() async throws {
        let root = makeRoot()
        let store = makeStore(at: root)
        let source = Place(id: "source-preview", title: "Quelle", sourceURL: "http://example.com/place")
        store.data.places = [source]
        XCTAssertTrue(store.persist())
        var requestedURL: URL?
        store.sourcePreviewResolver = { url in
            requestedURL = url
            return OEmbedService.Preview(title: "Quelle", thumbnail_url: "https://example.com/thumb.jpg")
        }

        await store.refreshPlaceImages(placeID: source.id)

        XCTAssertEqual(requestedURL?.scheme, "https")
        guard case .linkPreview(let pageURL, let thumbnailURL, _) = store.data.places.first?.image else {
            return XCTFail("Eine gültige Thumbnail-Quelle muss als Linkpreview gespeichert werden")
        }
        XCTAssertEqual(pageURL, source.sourceURL)
        XCTAssertEqual(thumbnailURL, "https://example.com/thumb.jpg")

        let noThumbnailRoot = makeRoot()
        let noThumbnailStore = makeStore(at: noThumbnailRoot)
        var noThumbnail = source
        noThumbnail.id = "source-preview-empty"
        noThumbnailStore.data.places = [noThumbnail]
        XCTAssertTrue(noThumbnailStore.persist())
        noThumbnailStore.sourcePreviewResolver = { _ in OEmbedService.Preview(title: "Quelle") }
        await noThumbnailStore.refreshPlaceImages(placeID: noThumbnail.id)
        XCTAssertNil(noThumbnailStore.data.places.first?.image)

        let staleRoot = makeRoot()
        let staleStore = makeStore(at: staleRoot)
        var stale = source
        stale.id = "source-preview-stale"
        staleStore.data.places = [stale]
        XCTAssertTrue(staleStore.persist())
        let gate = AsyncValueGate<OEmbedService.Preview?>()
        staleStore.sourcePreviewResolver = { _ in await gate.wait() }
        let task = Task { await staleStore.refreshPlaceImages(placeID: stale.id) }
        while !gate.requested { await Task.yield() }
        var edited = stale
        edited.title = "Vom Nutzer geändert"
        XCTAssertTrue(staleStore.upsert(edited))
        gate.resume(OEmbedService.Preview(title: "Quelle", thumbnail_url: "https://example.com/stale.jpg"))
        await task.value
        XCTAssertNil(staleStore.data.places.first?.image)
        XCTAssertEqual(staleStore.data.places.first?.title, edited.title)
    }

    func testConfirmedLocationUsesSourcePhotoWithoutReplacingPersonalPhoto() async throws {
        let store = makeStore(at: makeRoot())
        let place = Place(id: "confirmed-source", title: "Museum", sourceURL: "https://example.com/museum", lat: 50.09, lng: 14.42)
        store.data.places = [place]
        store.sourcePreviewResolver = { _ in OEmbedService.Preview(title: "Museum", thumbnail_url: "https://example.com/museum.jpg") }
        await store.refreshPlaceImages(placeID: place.id)
        guard case .linkPreview = store.data.places.first?.image else { return XCTFail("Quelle muss trotz bekannter Lage erhalten bleiben") }
        XCTAssertEqual(store.data.places.first?.lat, place.lat)
        XCTAssertEqual(store.data.places.first?.lng, place.lng)
        let reloaded = AlbumStore(root: store.root)
        XCTAssertEqual(reloaded.data.places.first?.image, store.data.places.first?.image)

        var personal = place
        personal.id = "personal-source"
        personal.image = .uploaded(UploadedPlaceImage(id: "user-photo", storagePath: nil, pixelWidth: 10, pixelHeight: 10))
        store.data.places = [personal]
        var requested = false
        store.sourcePreviewResolver = { _ in requested = true; return OEmbedService.Preview(title: "Museum", thumbnail_url: "https://example.com/replacement.jpg") }
        await store.refreshPlaceImages(placeID: personal.id)
        XCTAssertFalse(requested)
        XCTAssertEqual(store.data.places.first?.image, personal.image)
    }

    func testStaleImageResultReleasesLookupKeyForRetry() async throws {
        let store = makeStore(at: makeRoot())
        let fallback = UploadedPlaceImage(id: "generated", storagePath: nil, pixelWidth: 1, pixelHeight: 1,
                                          resolvedFor: ResolvedPlaceIdentity(title: "Museum", latitude: 50.09, longitude: 14.42,
                                                                             category: "Idee", address: ""),
                                          generatedSource: .mapSnapshot)
        let place = Place(id: "image-race", title: "Museum", image: .uploaded(fallback), lat: 50.09, lng: 14.42)
        store.data.places = [place]
        XCTAssertTrue(store.persist())

        let gate = AsyncValueGate<PlaceImageSearchResult>()
        var calls = 0
        store.placeImageSearchResolver = { _ in
            calls += 1
            if calls == 1 { return await gate.wait() }
            return PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking)
        }

        let task = Task { await store.refreshPlaceImages(placeID: place.id) }
        while calls < 1 { await Task.yield() }

        var edited = place
        edited.image = .uploaded(UploadedPlaceImage(id: "user-photo", storagePath: nil, pixelWidth: 1, pixelHeight: 1))
        XCTAssertTrue(store.upsert(edited))
        gate.resume(PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking))
        await task.value

        XCTAssertTrue(store.upsert(place), "Fixture must restore the original generated fallback")
        await store.refreshPlaceImages(placeID: place.id)
        XCTAssertEqual(calls, 2, "Ein veraltetes Ergebnis darf den nächsten sichtbaren Versuch nicht sperren")
    }

    func testCancelledSourcePreviewResultIsIgnored() async throws {
        let store = makeStore(at: makeRoot())
        let place = Place(id: "cancelled-source", title: "Quelle", sourceURL: "http://example.com/place")
        store.data.places = [place]
        XCTAssertTrue(store.persist())

        let gate = AsyncValueGate<OEmbedService.Preview?>()
        store.sourcePreviewResolver = { _ in await gate.wait() }
        let task = Task { await store.refreshPlaceImages(placeID: place.id) }
        while !gate.requested { await Task.yield() }
        task.cancel()
        gate.resume(OEmbedService.Preview(title: "Quelle", thumbnail_url: "https://example.com/late.jpg"))
        await task.value

        XCTAssertNil(store.data.places.first?.image, "Ein verspätetes Preview-Ergebnis darf nach Cancellation nicht gespeichert werden")
    }

    func testOpeningHoursResolverUsesBoundedConcurrency() async throws {
        let store = makeStore(at: makeRoot())
        store.data.places = (0..<6).map { index in
            Place(id: "hours-\(index)", title: "Ort \(index)", category: "Essen & Trinken",
                  lat: 50.08 + Double(index) * 0.001, lng: 14.42, franked: true)
        }
        var active = 0
        var maxActive = 0
        var calls = 0
        store.openingHoursResolver = { _ in
            calls += 1
            active += 1
            maxActive = max(maxActive, active)
            try? await Task.sleep(for: .milliseconds(100))
            active -= 1
            return "09:00–18:00"
        }

        _ = await store.proposeDayPlan(keepAssigned: true)

        XCTAssertEqual(calls, 6)
        XCTAssertGreaterThanOrEqual(maxActive, 2, "Der Fake muss echte Überlappung zeigen")
        XCTAssertLessThanOrEqual(maxActive, 3, "Die Öffnungszeiten-Abfragen müssen begrenzt bleiben")
        XCTAssertEqual(active, 0)
    }

    func testOpeningHoursCancellationPropagatesToCooperativeResolvers() async throws {
        let store = makeStore(at: makeRoot())
        store.data.places = (0..<6).map { index in
            Place(id: "cooperative-hours-\(index)", title: "Ort \(index)", category: "Essen & Trinken",
                  lat: 50.08 + Double(index) * 0.001, lng: 14.42, franked: true)
        }
        var starts = 0
        var cancellations = 0
        store.openingHoursResolver = { _ in
            starts += 1
            do {
                try await Task.sleep(for: .seconds(30))
                return "09:00–18:00"
            } catch {
                cancellations += 1
                return nil
            }
        }

        let task = Task { await store.proposeDayPlan(keepAssigned: true) }
        while starts < 3 { await Task.yield() }
        task.cancel()
        _ = await task.value

        XCTAssertEqual(starts, 3)
        XCTAssertEqual(cancellations, 3, "Structured Cancellation muss alle aktiven Resolver erreichen")
        XCTAssertTrue(store.data.places.allSatisfy { $0.openingHours == nil })
    }

    func testOpeningHoursCancellationStopsAfterCurrentBoundedBatchWithoutWrites() async throws {
        let store = makeStore(at: makeRoot())
        store.data.places = (0..<6).map { index in
            Place(id: "cancel-hours-\(index)", title: "Ort \(index)", category: "Essen & Trinken",
                  lat: 50.08 + Double(index) * 0.001, lng: 14.42, franked: true)
        }
        let gate = OpeningHoursBatchGate()
        store.openingHoursResolver = { _ in await gate.wait() }

        let task = Task { await store.proposeDayPlan(keepAssigned: true) }
        while gate.requestedCount < 3 { await Task.yield() }
        task.cancel()
        // Der Fake ignoriert Cancellation absichtlich; freigeben, damit die aktuelle Batch sauber ausläuft.
        gate.resumeAll("09:00–18:00")
        _ = await task.value

        XCTAssertEqual(gate.requestedCount, 3, "Nach Cancellation darf keine zweite Batch gestartet werden")
        XCTAssertTrue(store.data.places.allSatisfy { $0.openingHours == nil }, "Cancellation darf keine verspäteten Ergebnisse schreiben")
    }

    func testOpeningHoursResultIsDroppedWhenPlaceChangedWhileRequestWasInFlight() async throws {
        let root = makeRoot()
        let store = makeStore(at: root)
        let place = Place(id: "cafe", title: "Café", category: "Essen & Trinken", lat: 50.08, lng: 14.42, franked: true)
        XCTAssertTrue(store.upsert(place))
        let gate = AsyncValueGate<String?>()
        store.openingHoursResolver = { _ in await gate.wait() }

        let task = Task { await store.proposeDayPlan(keepAssigned: true) }
        while !gate.requested { await Task.yield() }
        var edited = place
        edited.title = "Neues Café"
        XCTAssertTrue(store.upsert(edited))
        gate.resume("09:00–18:00")
        _ = await task.value

        let current = try XCTUnwrap(store.data.places.first(where: { $0.id == place.id }))
        XCTAssertEqual(current.title, "Neues Café")
        XCTAssertNil(current.openingHours)
    }

    func testGeocodeResultIsDroppedWhenHotelAddressChangedWhileRequestWasInFlight() async throws {
        let root = makeRoot()
        let store = makeStore(at: root)
        let gate = AsyncValueGate<CLLocationCoordinate2D?>()
        store.geocodeAddressResolver = { _ in await gate.wait() }
        var extracted = ExtractedTrip()
        extracted.hotel.name = "Hotel A"
        extracted.hotel.address = "Alte Straße"

        let task = Task { await store.applyExtraction(extracted) }
        while !gate.requested { await Task.yield() }
        let hotelID = "hotel-" + "Hotel A".lowercased().filter { $0.isLetter || $0.isNumber }
        var edited = try XCTUnwrap(store.data.places.first(where: { $0.id == hotelID }))
        edited.address = "Neue Straße"
        XCTAssertTrue(store.upsert(edited))
        gate.resume(CLLocationCoordinate2D(latitude: 50.08, longitude: 14.42))
        await task.value

        let current = try XCTUnwrap(store.data.places.first(where: { $0.id == hotelID }))
        XCTAssertEqual(current.address, "Neue Straße")
        XCTAssertNil(current.coordinate)
    }

    func testCreateJoinStartRealtimeAndOverlappingSyncRunsOneFollowUp() async throws {
        let createStore = makeStore(at: makeRoot())
        let createService = StoreSyncProbe()
        createStore.syncService = createService
        let invitation = try await createStore.createSharedTrip()
        XCTAssertEqual(createService.realtimeStarts, 1)

        let joinStore = makeStore(at: makeRoot())
        let joinService = StoreSyncProbe()
        joinStore.syncService = joinService
        try await joinStore.joinSharedTrip(url: invitation)
        XCTAssertEqual(joinService.realtimeStarts, 1)
        XCTAssertEqual(joinService.syncCount, 1)

        let store = makeStore(at: makeRoot())
        let service = StoreSyncProbe()
        service.pauseFirstSync = true
        store.syncService = service
        store.data.collaboration = CollaborationState(tripID: UUID(), inviteToken: nil)
        XCTAssertTrue(store.persist())
        let first = Task { await store.sync() }
        while !service.firstSyncEntered { await Task.yield() }

        var changed = store.places[0]
        changed.note = "Während des Abgleichs geändert"
        XCTAssertTrue(store.upsert(changed))
        await store.sync()
        service.resumeFirstSync()
        await first.value
        for _ in 0..<100 where service.syncCount < 2 { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(service.syncCount, 2)
    }

    func testFailedSyncDoesNotCreateAutomaticRetryLoop() async throws {
        let store = makeStore(at: makeRoot())
        let service = StoreSyncProbe()
        service.failNextSync = true
        store.syncService = service
        store.data.collaboration = CollaborationState(tripID: UUID(), inviteToken: nil)
        XCTAssertTrue(store.persist())
        await store.sync()
        try await Task.sleep(for: .milliseconds(1_100))
        XCTAssertEqual(service.syncCount, 1)
    }
}

@MainActor
private final class AsyncValueGate<Value> {
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

@MainActor
private final class OpeningHoursBatchGate {
    private(set) var requestedCount = 0
    private var continuations: [CheckedContinuation<String?, Never>] = []

    func wait() async -> String? {
        requestedCount += 1
        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resumeAll(_ value: String?) {
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume(returning: value) }
    }
}

@MainActor
private final class StoreSyncProbe: AlbumSyncService {
    let tripID = UUID()
    var syncCount = 0
    var realtimeStarts = 0
    var pauseFirstSync = false
    var firstSyncEntered = false
    var failNextSync = false
    private var continuation: CheckedContinuation<Void, Never>?

    func createTrip(store: AlbumStore) async throws -> CollaborationState {
        CollaborationState(tripID: tripID, inviteToken: String(repeating: "t", count: 43))
    }

    func joinTrip(token: String) async throws -> CollaborationState {
        CollaborationState(tripID: tripID, inviteToken: nil)
    }

    func sync(store: AlbumStore) async throws {
        syncCount += 1
        if failNextSync {
            failNextSync = false
            throw NSError(domain: "StoreSyncProbe", code: 1)
        }
        if pauseFirstSync && syncCount == 1 {
            firstSyncEntered = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in self.continuation = continuation }
        }
    }

    func startRealtime(onChange: @escaping @MainActor @Sendable () async -> Void) {
        realtimeStarts += 1
    }

    func resumeFirstSync() {
        continuation?.resume()
        continuation = nil
    }
}
