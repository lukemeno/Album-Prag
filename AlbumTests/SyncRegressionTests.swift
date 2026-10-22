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
        sync.seedRevisionCacheForTesting(V2SyncRevision(tripUpdatedAt: "2026-10-16T12:00:00.123456+00:00", placeUpdatedAt: [:]),
                                         tripID: tripID, store: store)
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
        let tripID = UUID()
        sync.seedRevisionCacheForTesting(V2SyncRevision(tripUpdatedAt: "2023-11-14T22:13:20.123456+00:00", placeUpdatedAt: [:]),
                                         tripID: tripID, store: store)

        try await sync.pushDirtyForTesting(store: store, tripID: tripID)
        XCTAssertFalse(store.data.dirty.contains("trip"))
        store.data.dirty.insert("trip")
        try await sync.pushDirtyForTesting(store: store, tripID: tripID)
        XCTAssertFalse(store.data.dirty.contains("trip"))
        XCTAssertEqual(transport.tripWriteCount, 2)
        XCTAssertEqual(transport.v2ExpectedTripUpdatedAt, "2027-01-15T08:00:00.123456+00:00", "Die zweite Schreibung nutzt die vom Server bestätigte Revision")
    }

    func testV2CASRevisionPreservesPostgresMicrosecondsAsOpaqueStrings() throws {
        let stamp = "2026-10-16T12:34:56.123456+00:00"
        let place = Place(id: "p", title: "Museum", planningSchemaVersion: 2)
        let payload = V2PlaceSyncPayload(id: "p", payload: place, updatedAt: Date(), deleted: false, expectedUpdatedAt: stamp)
        let encodedPlace = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any]
        XCTAssertEqual(encodedPlace?["expected_updated_at"] as? String, stamp)

        let params = V2SyncParameters(tripID: UUID(), tripPayload: nil, expectedTripUpdatedAt: stamp, places: [payload])
        let encodedParams = try JSONSerialization.jsonObject(with: JSONEncoder().encode(params)) as? [String: Any]
        XCTAssertEqual(encodedParams?["p_expected_trip_updated_at"] as? String, stamp)
        XCTAssertTrue(encodedParams?.keys.contains("p_trip_payload") == true, "Explizites null trifft die RPC-Signatur eindeutig")
    }

    func testV2TripAndPlaceAssignmentsUseOneAtomicTransportCall() async throws {
        let store = AlbumStore(root: root)
        store.data.trip.startDate = TripDay(rawValue: "2027-04-30")
        store.data.trip.endDate = TripDay(rawValue: "2027-05-03")
        store.data.trip.updatedAt = Date()
        var place = Place(id: "v2-place", title: "Museum", plannedDate: TripDay(rawValue: "2027-05-01"), planningSchemaVersion: 2)
        place.selectedGooglePlace = .object(["placeID": .string("ChIJmuseum")])
        store.data.places = [place]
        store.data.dirty = ["trip", place.id]
        let tripID = UUID()
        store.data.collaboration = CollaborationState(tripID: tripID, inviteToken: "test-invite-token")
        XCTAssertTrue(store.persist())
        let transport = PausingSyncWriteTransport()
        let sync = SupabaseSync(writeTransport: transport)
        sync.seedRevisionCacheForTesting(
            V2SyncRevision(tripUpdatedAt: "2027-04-29T10:00:00.123456+00:00",
                           placeUpdatedAt: [place.id: "2027-04-29T10:00:00.654321+00:00"]),
            tripID: tripID, store: store
        )

        try await sync.pushDirtyForTesting(store: store, tripID: tripID)

        XCTAssertEqual(transport.v2WriteCount, 1)
        XCTAssertEqual(transport.v2TripPayload?.planningSchemaVersion, 2)
        XCTAssertEqual(transport.v2TripPayload?.startDate?.rawValue, "2027-04-30")
        XCTAssertEqual(transport.v2ExpectedTripUpdatedAt, "2027-04-29T10:00:00.123456+00:00")
        XCTAssertEqual(transport.v2PlacePayloads.map(\.id), [place.id])
        XCTAssertEqual(transport.v2PlacePayloads.first?.expectedUpdatedAt, "2027-04-29T10:00:00.654321+00:00")
        XCTAssertEqual(transport.v2PlacePayloads.first?.payload.plannedDate?.rawValue, "2027-05-01")
        XCTAssertNotNil(transport.v2PlacePayloads.first?.payload.selectedGooglePlace, "Felder neuerer Clients gehen beim Schreiben nicht verloren")
        XCTAssertEqual(transport.legacyTripWriteCount, 0)
        XCTAssertEqual(transport.legacyPlaceWriteCount, 0)
        XCTAssertFalse(store.data.dirty.contains("trip"))
        XCTAssertFalse(store.data.dirty.contains(place.id))
    }

    func testV2TransitionStagesRemotePlacesAndMapsPulledLegacyPragueDays() async throws {
        let store = AlbumStore(root: root)
        let tripID = UUID()
        store.data.collaboration = CollaborationState(tripID: tripID, inviteToken: "test-invite-token")
        // Vom Server gezogen: v1-Reise ohne Daten, Partner-Ort mit alter Tageszahl und ein ungelöster Wert.
        store.data.trip = TripInfo()
        let pulledPragueDay = Place(id: "partner-day", title: "Museum", franked: true, day: 6, dayOrder: 2)
        let pulledAmbiguous = Place(id: "partner-ambiguous", title: "Café", day: 31, dayOrder: 0)
        let localOnly = Place(id: "local-only", title: "Nur hier")
        store.data.places = [pulledPragueDay, pulledAmbiguous, localOnly]
        store.data.dirty = []
        XCTAssertTrue(store.persist())

        let transport = PausingSyncWriteTransport()
        let sync = SupabaseSync(writeTransport: transport)
        sync.recordRevisionsForTesting(tripRevision: "2026-10-01T10:00:00.123456+00:00",
                                       placeRevisions: [pulledPragueDay.id: "2026-10-01T10:00:00.111111+00:00",
                                                        pulledAmbiguous.id: "2026-10-01T10:00:00.222222+00:00"],
                                       tripID: tripID, store: store)
        sync.stageV2TransitionForTesting(store: store, remoteTripVersion: nil,
                                         remotePlaceIDs: [pulledPragueDay.id, pulledAmbiguous.id])
        try await sync.pushDirtyForTesting(store: store, tripID: tripID)

        XCTAssertEqual(transport.v2WriteCount, 1)
        XCTAssertEqual(transport.v2TripPayload?.planningSchemaVersion, 2)
        XCTAssertEqual(transport.v2TripPayload?.startDate?.rawValue, "2026-10-04")
        XCTAssertEqual(transport.v2TripPayload?.endDate?.rawValue, "2026-10-09")
        XCTAssertEqual(transport.v2ExpectedTripUpdatedAt, "2026-10-01T10:00:00.123456+00:00")
        XCTAssertEqual(Set(transport.v2PlacePayloads.map(\.id)), [pulledPragueDay.id, pulledAmbiguous.id],
                       "Nur Orte vom Server werden für den Übergang gestaged, lokale unveränderte Orte nicht")
        let mapped = try XCTUnwrap(transport.v2PlacePayloads.first { $0.id == pulledPragueDay.id })
        XCTAssertEqual(mapped.expectedUpdatedAt, "2026-10-01T10:00:00.111111+00:00")
        XCTAssertEqual(mapped.payload.plannedDate?.rawValue, "2026-10-06")
        XCTAssertNil(mapped.payload.day)
        XCTAssertEqual(mapped.payload.dayOrder, 2)
        let ambiguous = try XCTUnwrap(transport.v2PlacePayloads.first { $0.id == pulledAmbiguous.id })
        XCTAssertEqual(ambiguous.payload.planningSchemaVersion, 2)
        XCTAssertEqual(ambiguous.payload.day, 31, "Uneindeutige alte Werte bleiben erhalten")
        XCTAssertNil(ambiguous.payload.plannedDate)
        XCTAssertTrue(store.data.dirty.isEmpty)
    }

    func testV2ConflictKeepsLocalChangesDirty() async throws {
        let store = AlbumStore(root: root)
        store.data.trip.notes = "lokale Änderung"
        store.data.dirty = ["trip"]
        XCTAssertTrue(store.persist())
        let transport = PausingSyncWriteTransport()
        transport.v2NextError = NSError(domain: "Postgrest", code: 1, userInfo: [NSLocalizedDescriptionKey: "ALBUM_SYNC_CONFLICT"])
        let sync = SupabaseSync(writeTransport: transport)
        let tripID = UUID()
        sync.seedRevisionCacheForTesting(V2SyncRevision(tripUpdatedAt: "2026-10-16T12:00:00.123456+00:00", placeUpdatedAt: [:]),
                                         tripID: tripID, store: store)

        do {
            try await sync.pushDirtyForTesting(store: store, tripID: tripID)
            XCTFail("Ein veralteter CAS-Stand muss abgelehnt werden")
        } catch AlbumSyncError.syncConflict {
        }
        XCTAssertEqual(store.data.trip.notes, "lokale Änderung")
        XCTAssertTrue(store.data.dirty.contains("trip"))

        // Der nächste Abgleich liest die aktuelle Revision und überträgt die lokale Änderung damit.
        sync.recordRevisionsForTesting(tripRevision: "2026-10-16T12:05:00.654321+00:00", placeRevisions: [:], tripID: tripID, store: store)
        try await sync.pushDirtyForTesting(store: store, tripID: tripID)
        XCTAssertEqual(transport.v2ExpectedTripUpdatedAt, "2026-10-16T12:05:00.654321+00:00")
        XCTAssertFalse(store.data.dirty.contains("trip"))
    }

    func testV2WriteWithoutBaselineForKnownRowIsRefused() async throws {
        let store = AlbumStore(root: root)
        let place = Place(id: "known", title: "Bekannt", planningSchemaVersion: 2)
        store.data.places = [place]
        store.data.dirty = [place.id]
        XCTAssertTrue(store.persist())
        let transport = PausingSyncWriteTransport()
        let sync = SupabaseSync(writeTransport: transport)
        let tripID = UUID()
        // Zeile ist vom Server bekannt, aber ohne lesbare Revision.
        sync.recordRevisionsForTesting(tripRevision: "2026-10-16T12:00:00.123456+00:00", placeRevisions: ["known": ""], tripID: tripID, store: store)

        do {
            try await sync.pushDirtyForTesting(store: store, tripID: tripID)
            XCTFail("Ohne Basis für eine bestehende Zeile darf nicht überschrieben werden")
        } catch AlbumSyncError.syncConflict {
        }
        XCTAssertEqual(transport.v2WriteCount, 0)
        XCTAssertTrue(store.data.dirty.contains(place.id))
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
    var legacyTripWriteCount = 0
    var legacyPlaceWriteCount = 0
    var v2WriteCount = 0
    var v2TripPayload: TripInfo?
    var v2PlacePayloads: [V2PlaceSyncPayload] = []
    var v2ExpectedTripUpdatedAt: String?
    var v2NextError: Error?
    var placePayload: Place?
    var documentUploadPath: String?
    var documentPayload: String?
    var documentWriteCount = 0
    private var continuation: CheckedContinuation<Void, Never>?

    init(pause: Operation? = nil) { self.pause = pause }

    func updateTrip(tripID: UUID, payload: TripInfo) async throws {
        tripWriteCount += 1
        legacyTripWriteCount += 1
        tripPayload = payload
        await waitIfNeeded(.trip)
    }

    func syncTripV2(tripID: UUID, tripPayload: TripInfo?, expectedTripUpdatedAt: String?, places: [V2PlaceSyncPayload]) async throws -> V2SyncRevision {
        v2WriteCount += 1
        v2TripPayload = tripPayload
        v2ExpectedTripUpdatedAt = expectedTripUpdatedAt
        v2PlacePayloads = places
        if let tripPayload {
            tripWriteCount += 1
            self.tripPayload = tripPayload
            await waitIfNeeded(.trip)
        }
        if let first = places.first {
            placePayload = first.payload
            await waitIfNeeded(.place)
        }
        if let error = v2NextError { v2NextError = nil; throw error }
        return V2SyncRevision(
            tripUpdatedAt: "2027-01-15T08:00:00.123456+00:00",
            placeUpdatedAt: Dictionary(uniqueKeysWithValues: places.map { ($0.id, "2027-01-15T08:00:00.123456+00:00") })
        )
    }

    func uploadImage(path: String, data: Data) async throws {
        await waitIfNeeded(.image)
    }

    func upsertPlace(id: String, tripID: UUID, payload: Place, updatedAt: Date, deleted: Bool) async throws {
        legacyPlaceWriteCount += 1
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
