import Foundation
import PDFKit
import Supabase
import UIKit
import XCTest
@testable import Album

/// Opt-in only: this test talks to the configured Supabase project and owns no cleanup.
@MainActor
final class SupabaseSwiftIntegrationTests: XCTestCase {
    private static let storagePDFText = "Album QA storage roundtrip"
    private struct Receipt: Codable {
        var runID: String
        var role: String
        var userIDs: [String] = []
        var tripID: String?
        var memberIDs: [String] = []
        var bucketPaths: [[String]] = []
        var timeline: [TimingEvent] = []
        var testRevision = "no-background-v3"
        var startedAt: Date
        var status = "started"
    }

    private struct TimingEvent: Codable {
        let phase: String
        let timestamp: TimeInterval
        let detail: String
    }

    private struct RealtimeMemberRow: Decodable {
        let userID: UUID
        enum CodingKeys: String, CodingKey { case userID = "user_id" }
    }

    private final class IsolatedAuthStorage: AuthLocalStorage, @unchecked Sendable {
        private var values: [String: Data] = [:]
        private let lock = NSLock()

        func store(key: String, value: Data) throws { lock.lock(); defer { lock.unlock() }; values[key] = value }
        func retrieve(key: String) throws -> Data? { lock.lock(); defer { lock.unlock() }; return values[key] }
        func remove(key: String) throws { lock.lock(); defer { lock.unlock() }; values.removeValue(forKey: key) }
    }

    func testTwoIndependentSwiftClientsRoundTripTripAndCollectionCAS() async throws {
        guard ProcessInfo.processInfo.environment["ALBUM_LIVE_SUPABASE"] == "1" else {
            throw XCTSkip("Live-Supabase-Gate: ALBUM_LIVE_SUPABASE=1 fehlt")
        }
        let environment = ProcessInfo.processInfo.environment
        guard let receiptPath = environment["QA_RUN_RECEIPT_PATH"], receiptPath.hasPrefix("/") else {
            XCTFail("QA_RUN_RECEIPT_PATH muss ein absoluter Pfad sein; kein Auth-Request wurde gesendet")
            return
        }
        let receiptURL = URL(fileURLWithPath: receiptPath)
        let runID = "swift-client-qa-\(UUID().uuidString)"
        var receipt = Receipt(runID: runID, role: "swift-supabase", startedAt: Date())
        try writeReceipt(receipt, to: receiptURL)

        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: rawURL), !rawURL.contains("YOUR_PROJECT"),
              let anonKey = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !anonKey.isEmpty, !anonKey.contains("YOUR_PUBLISHABLE_KEY") else {
            XCTFail("Öffentliche Supabase-Konfiguration fehlt im Test-Bundle; kein Auth-Request wurde gesendet")
            return
        }

        let fileManager = FileManager.default
        let rootBase = fileManager.temporaryDirectory.appendingPathComponent("album-swift-client-\(runID)", isDirectory: true)
        let rootA = rootBase.appendingPathComponent("store-a", isDirectory: true)
        let rootB = rootBase.appendingPathComponent("store-b", isDirectory: true)
        let inboxA = rootBase.appendingPathComponent("inbox-a", isDirectory: true)
        let inboxB = rootBase.appendingPathComponent("inbox-b", isDirectory: true)
        defer { try? fileManager.removeItem(at: rootBase) }
        let storeA = AlbumStore(root: rootA, shareInbox: ShareInbox(root: inboxA))
        let storeB = AlbumStore(root: rootB, shareInbox: ShareInbox(root: inboxB))
        storeA.syncService = NoBackgroundSyncService()
        storeB.syncService = NoBackgroundSyncService()
        XCTAssertTrue(storeA.syncService is NoBackgroundSyncService)
        XCTAssertTrue(storeB.syncService is NoBackgroundSyncService)
        let revisionAttachment = XCTAttachment(string: "no-background-v3")
        revisionAttachment.name = "no-background-v3"
        revisionAttachment.lifetime = .keepAlways
        add(revisionAttachment)
        storeA.collectionParticipantIDOverride = "swift-a-\(runID)"
        storeB.collectionParticipantIDOverride = "swift-b-\(runID)"
        let qaPlace = Place(id: "qa-place-\(runID)", title: "QA Prague Place \(runID)", lat: 50.0875, lng: 14.4213)
        storeA.data.places = [qaPlace]
        storeA.data.documents = []
        storeA.data.dirty = [qaPlace.id]
        storeB.data.places = []
        storeB.data.documents = []
        storeB.data.dirty = []

        let clientA = makeClient(url: url, key: anonKey, storage: IsolatedAuthStorage(), role: "A", runID: runID)
        let clientB = makeClient(url: url, key: anonKey, storage: IsolatedAuthStorage(), role: "B", runID: runID)
        let sessionA = try await clientA.auth.signInAnonymously(data: [
            "qa_run": .string(runID), "qa_role": .string("swift-client-A")
        ])
        receipt.userIDs.append(sessionA.user.id.uuidString); try writeReceipt(receipt, to: receiptURL); attach(receipt)
        try assertStableSession(clientA, expected: sessionA.user.id, receipt: &receipt, receiptURL: receiptURL)
        // Re-probe the protected receipt immediately before the second auth request.
        try writeReceipt(receipt, to: receiptURL)
        let sessionB = try await clientB.auth.signInAnonymously(data: [
            "qa_run": .string(runID), "qa_role": .string("swift-client-B")
        ])
        receipt.userIDs.append(sessionB.user.id.uuidString); try writeReceipt(receipt, to: receiptURL); attach(receipt)
        try assertStableSession(clientB, expected: sessionB.user.id, receipt: &receipt, receiptURL: receiptURL)

        let syncA = SupabaseSync(client: clientA)
        let syncB = SupabaseSync(client: clientB)
        try await probeSession(clientA, expected: sessionA.user.id, receipt: &receipt, receiptURL: receiptURL)
        try await probeSession(clientB, expected: sessionB.user.id, receipt: &receipt, receiptURL: receiptURL)
        let created = try await syncA.createTrip(store: storeA)
        receipt.tripID = created.tripID.uuidString; try writeReceipt(receipt, to: receiptURL); attach(receipt)
        try assertStableSession(clientA, expected: sessionA.user.id, receipt: &receipt, receiptURL: receiptURL)
        storeA.data.collaboration = created; XCTAssertTrue(storeA.persist())
        try await probeSession(clientB, expected: sessionB.user.id, receipt: &receipt, receiptURL: receiptURL)
        let joined = try await syncB.joinTrip(token: try XCTUnwrap(created.inviteToken))
        try assertStableSession(clientB, expected: sessionB.user.id, receipt: &receipt, receiptURL: receiptURL)
        XCTAssertEqual(joined.tripID, created.tripID)
        storeB.data.collaboration = joined; XCTAssertTrue(storeB.persist())

        storeA.data.trip.notes = "Swift client A round-trip \(runID)"
        storeA.data.trip.updatedAt = Date()
        storeA.data.dirty.insert("trip")
        XCTAssertTrue(storeA.persist())
        try await syncAndAssert(syncA, client: clientA, expected: sessionA.user.id, store: storeA, receipt: &receipt, receiptURL: receiptURL)
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        XCTAssertEqual(storeB.data.trip.notes, storeA.data.trip.notes)
        XCTAssertEqual(storeB.places.map(\.title), [qaPlace.title])
        XCTAssertEqual(storeB.places.first?.lat, qaPlace.lat)
        XCTAssertEqual(storeB.places.first?.lng, qaPlace.lng)

        let post = try storeA.addCollectionPost(text: "Swift client post \(runID)", deterministicID: runID)
        try await syncAndAssert(syncA, client: clientA, expected: sessionA.user.id, store: storeA, receipt: &receipt, receiptURL: receiptURL)
        let postMarker = "collection:\(post.id)"
        XCTAssertFalse(storeA.data.dirty.contains(postMarker), "A muss den Post nach bestätigtem Server-Ack als sauber markieren")
        XCTAssertNotNil(storeA.data.collectionSync[post.id]?.serverVersion)
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        XCTAssertTrue(storeB.data.collectionEntries.contains(where: { $0.id == post.id }))
        XCTAssertNotNil(storeB.data.collectionSync[post.id]?.serverVersion)
        XCTAssertFalse(storeB.data.dirty.contains(postMarker), "B muss den Roundtrip-Post als sauber markieren")
        _ = try storeB.addCollectionComment(postID: post.id, text: "Kommentar von B", deterministicID: "comment-\(runID)")
        _ = try storeB.setCollectionHeart(postID: post.id, active: true)
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        try await syncAndAssert(syncA, client: clientA, expected: sessionA.user.id, store: storeA, receipt: &receipt, receiptURL: receiptURL)
        XCTAssertEqual(storeA.collectionComments(for: post.id).count, 1)
        XCTAssertEqual(storeA.collectionHeartCount(for: post.id), 1)

        let qaPlaceID = try XCTUnwrap(storeA.places.first?.id)
        _ = try storeA.linkCollectionPlace(postID: post.id, placeID: qaPlaceID)
        try await syncAndAssert(syncA, client: clientA, expected: sessionA.user.id, store: storeA, receipt: &receipt, receiptURL: receiptURL)
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        XCTAssertEqual(storeB.collectionPlaces(for: post.id).count, 1)
        let linkID = CollectionEntry.placeLinkID(postID: post.id, placeID: qaPlaceID)
        let linkMarker = "collection:\(linkID)"
        let initialLinkVersion = try XCTUnwrap(storeA.data.collectionSync[linkID]?.serverVersion)
        XCTAssertEqual(storeB.data.collectionSync[linkID]?.serverVersion, initialLinkVersion)
        XCTAssertFalse(storeA.data.dirty.contains(linkMarker))
        XCTAssertFalse(storeB.data.dirty.contains(linkMarker))

        _ = try storeA.unlinkCollectionPlace(postID: post.id, placeID: qaPlaceID)
        _ = try storeB.unlinkCollectionPlace(postID: post.id, placeID: qaPlaceID)
        XCTAssertTrue(storeA.data.dirty.contains(linkMarker))
        XCTAssertTrue(storeB.data.dirty.contains(linkMarker))
        try await syncAndAssert(syncA, client: clientA, expected: sessionA.user.id, store: storeA, receipt: &receipt, receiptURL: receiptURL)
        let afterA = try XCTUnwrap(storeA.data.collectionSync[linkID]?.serverVersion)
        XCTAssertEqual(afterA, initialLinkVersion + 1)
        XCTAssertEqual(storeB.data.collectionSync[linkID]?.serverVersion, initialLinkVersion, "B bleibt bis zum CAS-Retry stale")
        XCTAssertTrue(storeB.data.dirty.contains(linkMarker))
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        let afterB = try XCTUnwrap(storeB.data.collectionSync[linkID]?.serverVersion)
        XCTAssertGreaterThanOrEqual(afterB, afterA + 1)
        XCTAssertFalse(storeB.data.dirty.contains(linkMarker))
        try await syncAndAssert(syncA, client: clientA, expected: sessionA.user.id, store: storeA, receipt: &receipt, receiptURL: receiptURL)
        XCTAssertEqual(storeA.data.collectionSync[linkID]?.serverVersion, afterB)
        XCTAssertEqual(storeA.collectionPlaces(for: post.id).count, storeB.collectionPlaces(for: post.id).count)
        XCTAssertEqual(storeA.data.collectionEntries.first(where: { $0.id == linkID })?.deleted, true)
        struct MemberRow: Decodable { let userID: UUID; enum CodingKeys: String, CodingKey { case userID = "user_id" } }
        let members: [MemberRow] = try await clientA.from("trip_members").select("user_id").eq("trip_id", value: created.tripID).execute().value
        XCTAssertEqual(members.count, 2)
        XCTAssertEqual(Set(members.map(\.userID)), Set([sessionA.user.id, sessionB.user.id]))
        receipt.memberIDs = members.map { $0.userID.uuidString }.sorted()
        try writeReceipt(receipt, to: receiptURL)
        attach(receipt)
        receipt.status = "completed"
        try writeReceipt(receipt, to: receiptURL)
    }

    func testTwoSwiftClientsUploadDownloadAndRepairStorage() async throws {
        guard ProcessInfo.processInfo.environment["ALBUM_LIVE_SUPABASE"] == "1" else {
            throw XCTSkip("Live-Supabase-Gate: ALBUM_LIVE_SUPABASE=1 fehlt")
        }
        let environment = ProcessInfo.processInfo.environment
        guard let receiptPath = environment["QA_RUN_RECEIPT_PATH"], receiptPath.hasPrefix("/") else {
            XCTFail("QA_RUN_RECEIPT_PATH muss ein absoluter Pfad sein; kein Auth-Request wurde gesendet")
            return
        }
        let receiptURL = URL(fileURLWithPath: receiptPath)
        let runID = "storage-roundtrip-\(UUID().uuidString)"
        var receipt = Receipt(runID: runID, role: "swift-storage", startedAt: Date())
        receipt.testRevision = "storage-roundtrip-v1"
        try writeReceipt(receipt, to: receiptURL)

        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: rawURL), !rawURL.contains("YOUR_PROJECT"),
              let anonKey = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !anonKey.isEmpty, !anonKey.contains("YOUR_PUBLISHABLE_KEY") else {
            XCTFail("Öffentliche Supabase-Konfiguration fehlt im Test-Bundle; kein Auth-Request wurde gesendet")
            return
        }
        let fileManager = FileManager.default
        let rootBase = fileManager.temporaryDirectory.appendingPathComponent("album-storage-\(runID)", isDirectory: true)
        let rootA = rootBase.appendingPathComponent("store-a", isDirectory: true)
        let rootB = rootBase.appendingPathComponent("store-b", isDirectory: true)
        let inboxA = rootBase.appendingPathComponent("inbox-a", isDirectory: true)
        let inboxB = rootBase.appendingPathComponent("inbox-b", isDirectory: true)
        defer { try? fileManager.removeItem(at: rootBase) }
        let storeA = AlbumStore(root: rootA, shareInbox: ShareInbox(root: inboxA))
        let storeB = AlbumStore(root: rootB, shareInbox: ShareInbox(root: inboxB))
        storeA.syncService = NoBackgroundSyncService()
        storeB.syncService = NoBackgroundSyncService()
        XCTAssertTrue(storeA.syncService is NoBackgroundSyncService)
        XCTAssertTrue(storeB.syncService is NoBackgroundSyncService)
        let revisionAttachment = XCTAttachment(string: "storage-roundtrip-v1")
        revisionAttachment.name = "storage-roundtrip-v1"
        revisionAttachment.lifetime = .keepAlways
        add(revisionAttachment)
        storeA.collectionParticipantIDOverride = "swift-storage-a-\(runID)"
        storeB.collectionParticipantIDOverride = "swift-storage-b-\(runID)"
        storeA.data.places = []; storeA.data.documents = []; storeA.data.dirty = []
        storeB.data.places = []; storeB.data.documents = []; storeB.data.dirty = []

        let clientA = makeClient(url: url, key: anonKey, storage: IsolatedAuthStorage(), role: "storage-A", runID: runID)
        let clientB = makeClient(url: url, key: anonKey, storage: IsolatedAuthStorage(), role: "storage-B", runID: runID)
        let sessionA = try await clientA.auth.signInAnonymously(data: ["qa_run": .string(runID), "qa_role": .string("swift-storage-A")])
        receipt.userIDs.append(sessionA.user.id.uuidString); try writeReceipt(receipt, to: receiptURL); attach(receipt)
        try await probeSession(clientA, expected: sessionA.user.id, receipt: &receipt, receiptURL: receiptURL)
        try writeReceipt(receipt, to: receiptURL)
        let sessionB = try await clientB.auth.signInAnonymously(data: ["qa_run": .string(runID), "qa_role": .string("swift-storage-B")])
        receipt.userIDs.append(sessionB.user.id.uuidString); try writeReceipt(receipt, to: receiptURL); attach(receipt)
        try await probeSession(clientB, expected: sessionB.user.id, receipt: &receipt, receiptURL: receiptURL)

        let syncA = SupabaseSync(client: clientA)
        let syncB = SupabaseSync(client: clientB)
        try await probeSession(clientA, expected: sessionA.user.id, receipt: &receipt, receiptURL: receiptURL)
        let created = try await syncA.createTrip(store: storeA)
        receipt.tripID = created.tripID.uuidString; try writeReceipt(receipt, to: receiptURL); attach(receipt)
        try assertStableSession(clientA, expected: sessionA.user.id, receipt: &receipt, receiptURL: receiptURL)
        storeA.data.collaboration = created; XCTAssertTrue(storeA.persist())
        try await probeSession(clientB, expected: sessionB.user.id, receipt: &receipt, receiptURL: receiptURL)
        let joined = try await syncB.joinTrip(token: try XCTUnwrap(created.inviteToken))
        try assertStableSession(clientB, expected: sessionB.user.id, receipt: &receipt, receiptURL: receiptURL)
        storeB.data.collaboration = joined; XCTAssertTrue(storeB.persist())

        let placeID = "qa-storage-place-\(runID)"
        let place = Place(id: placeID, title: "Storage QA Place \(runID)", lat: 50.0875, lng: 14.4213)
        let sourceImage = try makeSyntheticJPEG()
        let uploaded = try PlaceImageStorage.save(sourceImage, root: rootA, id: "image-\(runID)")
        let pdfID = "document-\(runID)"
        let pdfURL = rootBase.appendingPathComponent("source.pdf")
        try makeSyntheticPDF(at: pdfURL)
        let plannedImagePath = "\(created.tripID.uuidString)/\(placeID)/\(uploaded.id).jpg"
        let plannedDocumentPath = "\(created.tripID.uuidString)/\(pdfID).pdf"
        receipt.bucketPaths = [["trip-images", plannedImagePath], ["trip-files", plannedDocumentPath]]
        try writeReceipt(receipt, to: receiptURL)
        var imagePlace = place; imagePlace.image = .uploaded(uploaded)
        XCTAssertTrue(storeA.upsert(imagePlace))
        try storeA.importPDF(pdfURL, id: pdfID)

        try await syncAndAssert(syncA, client: clientA, expected: sessionA.user.id, store: storeA, receipt: &receipt, receiptURL: receiptURL)
        XCTAssertTrue(storeA.data.dirty.isEmpty)
        let storedImage = try XCTUnwrap(storeA.data.places.first?.image)
        guard case .uploaded(let storedAsset) = storedImage else { return XCTFail("Upload-Ort enthält kein Uploaded-Asset") }
        XCTAssertEqual(storedAsset.storagePath, plannedImagePath)
        let document = try XCTUnwrap(storeA.data.documents.first(where: { $0.id == pdfID }))
        let storedPDFData = try Data(contentsOf: rootA.appendingPathComponent(document.filename))
        let storedImageData = try Data(contentsOf: PlaceImageStorage.localURL(for: storedAsset, root: rootA))

        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        XCTAssertTrue(storeB.data.dirty.isEmpty)
        let bPlace = try XCTUnwrap(storeB.data.places.first(where: { $0.id == placeID }))
        guard case .uploaded(let bAsset) = bPlace.image else { return XCTFail("B-Download enthält kein Uploaded-Asset") }
        XCTAssertEqual(bAsset.storagePath, plannedImagePath)
        XCTAssertEqual(try Data(contentsOf: PlaceImageStorage.localURL(for: bAsset, root: rootB)), storedImageData)
        XCTAssertNotNil(UIImage(data: try Data(contentsOf: PlaceImageStorage.localURL(for: bAsset, root: rootB))))
        let bDocument = try XCTUnwrap(storeB.data.documents.first(where: { $0.id == pdfID }))
        let bPDFURL = rootB.appendingPathComponent(bDocument.filename)
        XCTAssertEqual(try Data(contentsOf: bPDFURL), storedPDFData)
        XCTAssertFalse(storeB.data.dirty.contains("doc-\(pdfID)"))
        XCTAssertNotNil(PDFDocument(url: bPDFURL)?.string)
        let reloadedB = AlbumStore(root: rootB, shareInbox: ShareInbox(root: inboxB)); reloadedB.syncService = NoBackgroundSyncService()
        let reloadedPlace = try XCTUnwrap(reloadedB.data.places.first(where: { $0.id == placeID }))
        guard case .uploaded(let reloadedAsset) = reloadedPlace.image else { return XCTFail("Reload-Ort enthält kein Uploaded-Asset") }
        XCTAssertEqual(reloadedAsset.id, bAsset.id)
        XCTAssertEqual(reloadedAsset.storagePath, plannedImagePath)
        let reloadedImageData = try Data(contentsOf: PlaceImageStorage.localURL(for: reloadedAsset, root: rootB))
        XCTAssertEqual(reloadedImageData, storedImageData)
        XCTAssertNotNil(UIImage(data: reloadedImageData))
        let reloadedDocument = try XCTUnwrap(reloadedB.data.documents.first(where: { $0.id == pdfID }))
        XCTAssertEqual(reloadedDocument.filename, document.filename)
        let reloadedPDFData = try Data(contentsOf: rootB.appendingPathComponent(reloadedDocument.filename))
        XCTAssertEqual(reloadedPDFData, storedPDFData)
        XCTAssertTrue(try XCTUnwrap(PDFDocument(data: reloadedPDFData)?.string).contains(Self.storagePDFText))

        try fileManager.removeItem(at: PlaceImageStorage.localURL(for: bAsset, root: rootB))
        try Data([4, 5, 6, 7]).write(to: bPDFURL, options: .atomic)
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        let repairedImageData = try Data(contentsOf: PlaceImageStorage.localURL(for: bAsset, root: rootB))
        XCTAssertEqual(repairedImageData, storedImageData)
        XCTAssertNotNil(UIImage(data: repairedImageData))
        let repairedPDFData = try Data(contentsOf: bPDFURL)
        XCTAssertEqual(repairedPDFData, storedPDFData)
        XCTAssertTrue(try XCTUnwrap(PDFDocument(data: repairedPDFData)?.string).contains(Self.storagePDFText))
        struct MemberRow: Decodable { let userID: UUID; enum CodingKeys: String, CodingKey { case userID = "user_id" } }
        let members: [MemberRow] = try await clientA.from("trip_members").select("user_id").eq("trip_id", value: created.tripID).execute().value
        XCTAssertEqual(members.count, 2)
        XCTAssertEqual(Set(members.map(\.userID)), Set([sessionA.user.id, sessionB.user.id]))
        receipt.memberIDs = members.map { $0.userID.uuidString }.sorted()
        try writeReceipt(receipt, to: receiptURL); attach(receipt)
        receipt.status = "completed"; try writeReceipt(receipt, to: receiptURL)
    }

    func testTwoSwiftClientsReceiveRealtimeChangesAndStop() async throws {
        guard ProcessInfo.processInfo.environment["ALBUM_LIVE_SUPABASE"] == "1" else {
            throw XCTSkip("Live-Supabase-Gate: ALBUM_LIVE_SUPABASE=1 fehlt")
        }
        let environment = ProcessInfo.processInfo.environment
        guard let receiptPath = environment["QA_RUN_RECEIPT_PATH"], receiptPath.hasPrefix("/") else {
            XCTFail("QA_RUN_RECEIPT_PATH muss ein absoluter Pfad sein; kein Auth-Request wurde gesendet")
            return
        }
        let receiptURL = URL(fileURLWithPath: receiptPath)
        let runID = "realtime-roundtrip-\(UUID().uuidString)"
        var receipt = Receipt(runID: runID, role: "swift-realtime", startedAt: Date())
        receipt.testRevision = "realtime-v8-readiness-documents-restart"
        try writeReceipt(receipt, to: receiptURL)
        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: rawURL), !rawURL.contains("YOUR_PROJECT"),
              let anonKey = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !anonKey.isEmpty, !anonKey.contains("YOUR_PUBLISHABLE_KEY") else {
            XCTFail("Öffentliche Supabase-Konfiguration fehlt im Test-Bundle; kein Auth-Request wurde gesendet")
            return
        }
        let fileManager = FileManager.default
        let rootBase = fileManager.temporaryDirectory.appendingPathComponent("album-realtime-\(runID)", isDirectory: true)
        let rootA = rootBase.appendingPathComponent("store-a", isDirectory: true)
        let rootB = rootBase.appendingPathComponent("store-b", isDirectory: true)
        let inboxA = rootBase.appendingPathComponent("inbox-a", isDirectory: true)
        let inboxB = rootBase.appendingPathComponent("inbox-b", isDirectory: true)
        defer { try? fileManager.removeItem(at: rootBase) }
        let storeA = AlbumStore(root: rootA, shareInbox: ShareInbox(root: inboxA))
        let storeB = AlbumStore(root: rootB, shareInbox: ShareInbox(root: inboxB))
        let noOpA = NoBackgroundSyncService(); let noOpB = NoBackgroundSyncService()
        storeA.syncService = noOpA; storeB.syncService = noOpB
        XCTAssertTrue(storeA.syncService is NoBackgroundSyncService)
        XCTAssertTrue(storeB.syncService is NoBackgroundSyncService)
        let revisionAttachment = XCTAttachment(string: "realtime-v5-startup-contract")
        revisionAttachment.name = "realtime-v5-startup-contract"; revisionAttachment.lifetime = .keepAlways; add(revisionAttachment)
        storeA.collectionParticipantIDOverride = "swift-realtime-a-\(runID)"
        storeB.collectionParticipantIDOverride = "swift-realtime-b-\(runID)"
        storeA.data.places = []; storeA.data.documents = []; storeA.data.dirty = []
        storeB.data.places = []; storeB.data.documents = []; storeB.data.dirty = []
        let clientA = makeClient(url: url, key: anonKey, storage: IsolatedAuthStorage(), role: "realtime-A", runID: runID)
        let clientB = makeClient(url: url, key: anonKey, storage: IsolatedAuthStorage(), role: "realtime-B", runID: runID)
        let sessionA = try await clientA.auth.signInAnonymously(data: ["qa_run": .string(runID), "qa_role": .string("swift-realtime-A")])
        receipt.userIDs.append(sessionA.user.id.uuidString); try writeReceipt(receipt, to: receiptURL); attach(receipt)
        let sessionB = try await clientB.auth.signInAnonymously(data: ["qa_run": .string(runID), "qa_role": .string("swift-realtime-B")])
        receipt.userIDs.append(sessionB.user.id.uuidString); try writeReceipt(receipt, to: receiptURL); attach(receipt)
        try await probeSession(clientA, expected: sessionA.user.id, receipt: &receipt, receiptURL: receiptURL)
        try await probeSession(clientB, expected: sessionB.user.id, receipt: &receipt, receiptURL: receiptURL)
        let syncA = SupabaseSync(client: clientA); let syncB = SupabaseSync(client: clientB)
        let created = try await syncA.createTrip(store: storeA)
        receipt.tripID = created.tripID.uuidString; try writeReceipt(receipt, to: receiptURL); attach(receipt)
        storeA.data.collaboration = created; XCTAssertTrue(storeA.persist())
        let joined = try await syncB.joinTrip(token: try XCTUnwrap(created.inviteToken))
        storeB.data.collaboration = joined; XCTAssertTrue(storeB.persist())
        let baseline = Place(id: "realtime-baseline-\(runID)", title: "Realtime Baseline", author: "Wir", lat: 50.0875, lng: 14.4213)
        storeA.data.places = [baseline]; storeA.data.dirty = [baseline.id]; XCTAssertTrue(storeA.persist())
        try await syncAndAssert(syncA, client: clientA, expected: sessionA.user.id, store: storeA, receipt: &receipt, receiptURL: receiptURL)
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        do {
        storeA.syncService = syncA
        let startupExpectation = expectation(description: "Realtime-Startup-Catchup ist bereit")
        let received = expectation(description: "Realtime-Callback synchronisiert den neuen B-Ort")
        var callbackCount = 0
        var startupFulfilled = false
        var phaseFulfilled = false
        var phaseExpectation: XCTestExpectation?
        var phasePredicate: (() -> Bool)?
        var phaseName = "startup"
        var callbackEvents: [TimingEvent] = []
        try record("subscription.start", detail: "channels=\(clientA.realtimeV2.channels.count)", receipt: &receipt, receiptURL: receiptURL)
        syncA.startRealtime {
            callbackCount += 1
            callbackEvents.append(TimingEvent(phase: "callback.start", timestamp: Date().timeIntervalSince1970, detail: "phase=\(phaseName),count=\(callbackCount)"))
            await storeA.sync()
            if !startupFulfilled, phaseName == "startup" {
                startupFulfilled = true; startupExpectation.fulfill()
            }
            if !phaseFulfilled, phasePredicate?() == true {
                phaseFulfilled = true; phaseExpectation?.fulfill()
            }
            callbackEvents.append(TimingEvent(phase: "callback.end", timestamp: Date().timeIntervalSince1970, detail: "phase=\(phaseName),count=\(callbackCount),places=\(storeA.places.count),fulfilled=\(phaseFulfilled)"))
        }
        syncA.startRealtime { callbackCount += 1; await storeA.sync() }
        try record("startup.wait.start", detail: "timeout=15s", receipt: &receipt, receiptURL: receiptURL)
        await fulfillment(of: [startupExpectation], timeout: 15)
        try record("startup.wait.end", detail: "fulfilled=\(startupFulfilled),ready=\(syncA.isRealtimeReady)", receipt: &receipt, receiptURL: receiptURL)
        let readinessDeadline = Date().addingTimeInterval(10)
        try record("subscription.readiness.start", detail: "deadline=10s", receipt: &receipt, receiptURL: receiptURL)
        while Date() < readinessDeadline {
            let channels = Array(clientA.realtimeV2.channels.values)
            if channels.count == 1, channels.allSatisfy({ $0.status == .subscribed }), syncA.isRealtimeReady { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        try record("subscription.readiness.end", detail: "channels=\(clientA.realtimeV2.channels.count),subscribed=\(clientA.realtimeV2.channels.values.allSatisfy { $0.status == .subscribed }),ready=\(syncA.isRealtimeReady)", receipt: &receipt, receiptURL: receiptURL)
        XCTAssertEqual(clientA.realtimeV2.channels.count, 1)
        XCTAssertTrue(clientA.realtimeV2.channels.values.allSatisfy { $0.status == .subscribed })
        XCTAssertTrue(syncA.isRealtimeReady)
        let callbackCountBeforePlace = callbackCount
        phaseName = "place"
        phaseExpectation = received
        phaseFulfilled = false
        var partner = Place(id: "realtime-partner-\(runID)", title: "Realtime Partner", author: "QA realtime partner", lat: 50.088, lng: 14.422)
        partner.note = "Live callback"
        phasePredicate = { storeA.places.contains(where: { $0.id == partner.id }) }
        try record("writer.start", detail: "place=\(partner.id)", receipt: &receipt, receiptURL: receiptURL)
        XCTAssertTrue(storeB.upsert(partner))
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        try record("writer.end", detail: "place=\(partner.id)", receipt: &receipt, receiptURL: receiptURL)
        try record("fulfillment.wait.start", detail: "timeout=15s", receipt: &receipt, receiptURL: receiptURL)
        await fulfillment(of: [received], timeout: 15)
        try record("fulfillment.wait.end.place", detail: "callbackCount=\(callbackCount),fulfilled=\(phaseFulfilled)", receipt: &receipt, receiptURL: receiptURL)
        let placeFulfilled = phaseFulfilled
        let placeCallbackDelta = callbackCount - callbackCountBeforePlace
        XCTAssertEqual(placeCallbackDelta, 1)
        XCTAssertNotNil(storeA.syncChange)
        XCTAssertEqual(storeA.syncChange?.ideas, 1)
        XCTAssertEqual(storeA.places.first(where: { $0.id == partner.id })?.title, partner.title)
        XCTAssertEqual(storeA.places.first(where: { $0.id == partner.id })?.lat, partner.lat)
        let placeValid = placeFulfilled && storeA.syncChange?.ideas == 1 && storeA.places.first(where: { $0.id == partner.id })?.title == partner.title && storeA.places.first(where: { $0.id == partner.id })?.lat == partner.lat

        let post = try storeB.addCollectionPost(text: "Realtime collection post \(runID)", deterministicID: runID)
        let postExpectation = expectation(description: "Realtime-Callback synchronisiert Collection-Post")
        phaseName = "post"; phaseExpectation = postExpectation; phasePredicate = { storeA.data.collectionEntries.contains(where: { $0.id == post.id }) }; phaseFulfilled = false
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        try record("fulfillment.wait.post.start", detail: "timeout=15s", receipt: &receipt, receiptURL: receiptURL)
        await fulfillment(of: [postExpectation], timeout: 15)
        let postFulfilled = phaseFulfilled
        try record("fulfillment.wait.post.end", detail: "callbackCount=\(callbackCount),fulfilled=\(postFulfilled)", receipt: &receipt, receiptURL: receiptURL)
        XCTAssertTrue(postFulfilled)

        let interactionExpectation = expectation(description: "Realtime-Callback synchronisiert Kommentar und Herz")
        phaseName = "interactions"; phaseExpectation = interactionExpectation
        phasePredicate = { storeA.collectionComments(for: post.id).count == 1 && storeA.collectionHeartCount(for: post.id) == 1 }
        phaseFulfilled = false
        _ = try storeB.addCollectionComment(postID: post.id, text: "Realtime comment", deterministicID: "comment-\(runID)")
        _ = try storeB.setCollectionHeart(postID: post.id, active: true)
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        try record("fulfillment.wait.interactions.start", detail: "timeout=15s", receipt: &receipt, receiptURL: receiptURL)
        await fulfillment(of: [interactionExpectation], timeout: 15)
        let interactionsFulfilled = phaseFulfilled
        try record("fulfillment.wait.interactions.end", detail: "callbackCount=\(callbackCount),fulfilled=\(interactionsFulfilled)", receipt: &receipt, receiptURL: receiptURL)
        XCTAssertTrue(interactionsFulfilled)

        let realtimeNotes = "Realtime trip update \(runID)"
        let tripExpectation = expectation(description: "Realtime-Callback synchronisiert Trip")
        phaseName = "trip"; phaseExpectation = tripExpectation; phasePredicate = { storeA.data.trip.notes == realtimeNotes }; phaseFulfilled = false
        storeB.data.trip.notes = realtimeNotes; storeB.data.trip.updatedAt = Date(); storeB.data.dirty.insert("trip"); XCTAssertTrue(storeB.persist())
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        try record("fulfillment.wait.trip.start", detail: "timeout=15s", receipt: &receipt, receiptURL: receiptURL)
        await fulfillment(of: [tripExpectation], timeout: 15)
        let tripFulfilled = phaseFulfilled
        try record("fulfillment.wait.trip.end", detail: "callbackCount=\(callbackCount),fulfilled=\(tripFulfilled)", receipt: &receipt, receiptURL: receiptURL)
        XCTAssertTrue(tripFulfilled)

        let documentID = "realtime-document-\(runID)"
        let documentStoragePath = "\(created.tripID.uuidString)/\(documentID).pdf"
        receipt.bucketPaths.append(["trip-files", documentStoragePath])
        try writeReceipt(receipt, to: receiptURL)
        let sourcePDF = rootBase.appendingPathComponent("document-source.pdf")
        try makeSyntheticPDF(at: sourcePDF)
        try storeB.importPDF(sourcePDF, id: documentID)
        let documentAdded = expectation(description: "Realtime-Callback synchronisiert neues Dokument")
        phaseName = "document-add"
        phaseExpectation = documentAdded
        phasePredicate = {
            storeA.data.documents.contains(where: {
                $0.id == documentID && $0.name == "document-source" && $0.extractedText.contains(Self.storagePDFText)
            })
        }
        phaseFulfilled = false
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        try record("fulfillment.wait.document-add.start", detail: "timeout=15s,id=\(documentID)", receipt: &receipt, receiptURL: receiptURL)
        await fulfillment(of: [documentAdded], timeout: 15)
        let documentAddFulfilled = phaseFulfilled
        try record("fulfillment.wait.document-add.end", detail: "fulfilled=\(documentAddFulfilled)", receipt: &receipt, receiptURL: receiptURL)
        XCTAssertTrue(documentAddFulfilled)
        let receivedDocumentURL = rootA.appendingPathComponent("\(documentID).pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: receivedDocumentURL.path))
        XCTAssertNotNil(PDFDocument(url: receivedDocumentURL))

        let revisedDocumentName = "Updated realtime document \(runID)"
        let documentUpdated = expectation(description: "Realtime-Callback synchronisiert geänderte Dokumentmetadaten")
        phaseName = "document-update"
        phaseExpectation = documentUpdated
        phasePredicate = {
            storeA.data.documents.contains(where: {
                $0.id == documentID && $0.name == revisedDocumentName && $0.extractedText == "Updated synthetic metadata \(runID)"
            })
        }
        phaseFulfilled = false
        guard let documentIndex = storeB.data.documents.firstIndex(where: { $0.id == documentID }) else {
            XCTFail("Partner-Store hat das synthetische Dokument nach dem ersten Sync nicht behalten")
            return
        }
        storeB.data.documents[documentIndex].name = revisedDocumentName
        storeB.data.documents[documentIndex].extractedText = "Updated synthetic metadata \(runID)"
        storeB.data.documents[documentIndex].updatedAt = Date().addingTimeInterval(1)
        storeB.data.dirty.insert("doc-\(documentID)")
        XCTAssertTrue(storeB.persist())
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        try record("fulfillment.wait.document-update.start", detail: "timeout=15s,id=\(documentID)", receipt: &receipt, receiptURL: receiptURL)
        await fulfillment(of: [documentUpdated], timeout: 15)
        let documentUpdateFulfilled = phaseFulfilled
        try record("fulfillment.wait.document-update.end", detail: "fulfilled=\(documentUpdateFulfilled)", receipt: &receipt, receiptURL: receiptURL)
        XCTAssertTrue(documentUpdateFulfilled)
        XCTAssertEqual(storeA.data.documents.first(where: { $0.id == documentID })?.filename, "\(documentID).pdf")
        XCTAssertTrue(try XCTUnwrap(PDFDocument(url: receivedDocumentURL)?.string).contains(Self.storagePDFText))

        let callbackCountAfterReceive = callbackCount
        await syncA.stopRealtime()
        storeA.syncService = noOpA
        XCTAssertTrue(clientA.realtimeV2.channels.isEmpty)
        var second = Place(id: "realtime-second-\(runID)", title: "Realtime Second", author: "QA realtime partner", lat: 50.089, lng: 14.423)
        second.note = "After stop"
        XCTAssertTrue(storeB.upsert(second))
        try await syncAndAssert(syncB, client: clientB, expected: sessionB.user.id, store: storeB, receipt: &receipt, receiptURL: receiptURL)
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(callbackCount, callbackCountAfterReceive)
        XCTAssertFalse(storeA.places.contains(where: { $0.id == second.id }))
        XCTAssertTrue(clientB.realtimeV2.channels.isEmpty)

        let restarted = expectation(description: "Realtime-Neustart holt während der Unterbrechung gespeicherte Daten nach")
        var restartFulfilled = false
        storeA.syncService = syncA
        syncA.startRealtime {
            await storeA.sync()
            if !restartFulfilled, storeA.places.contains(where: { $0.id == second.id }) {
                restartFulfilled = true
                restarted.fulfill()
            }
        }
        await fulfillment(of: [restarted], timeout: 15)
        XCTAssertTrue(restartFulfilled)
        XCTAssertEqual(clientA.realtimeV2.channels.count, 1)
        await syncA.stopRealtime()
        XCTAssertTrue(clientA.realtimeV2.channels.isEmpty)
        try record("subscription.restart.catchup", detail: "fulfilled=\(restartFulfilled)", receipt: &receipt, receiptURL: receiptURL)
        receipt.timeline.append(contentsOf: callbackEvents)
        try writeReceipt(receipt, to: receiptURL)
        let members: [RealtimeMemberRow] = try await clientA.from("trip_members").select("user_id").eq("trip_id", value: created.tripID).execute().value
        XCTAssertEqual(members.count, 2)
        XCTAssertEqual(Set(members.map(\.userID)), Set([sessionA.user.id, sessionB.user.id]))
        receipt.memberIDs = members.map { $0.userID.uuidString }.sorted(); try writeReceipt(receipt, to: receiptURL); attach(receipt)
        let anyPhaseTimeout = !(startupFulfilled && placeFulfilled && postFulfilled && interactionsFulfilled && tripFulfilled && documentAddFulfilled && documentUpdateFulfilled)
        let validResult = startupFulfilled && !anyPhaseTimeout && placeValid && placeCallbackDelta == 1 && members.count == 2 && documentAddFulfilled && documentUpdateFulfilled && restartFulfilled
        receipt.status = validResult ? "completed" : (anyPhaseTimeout ? "failed-timeout" : "failed-assertions")
        try writeReceipt(receipt, to: receiptURL)
        } catch {
            await syncA.stopRealtime()
            storeA.syncService = noOpA
            for path in receipt.bucketPaths where path.count == 2 && path[1].hasPrefix(created.tripID.uuidString + "/") {
                try? await clientB.storage.from(path[0]).remove(paths: [path[1]])
            }
            receipt.status = "failed-error"
            try? writeReceipt(receipt, to: receiptURL)
            throw error
        }
    }

    private func makeClient(url: URL, key: String, storage: any AuthLocalStorage, role: String, runID: String) -> SupabaseClient {
        SupabaseClient(supabaseURL: url, supabaseKey: key, options: SupabaseClientOptions(
            db: SupabaseConfiguration.databaseOptions(),
            auth: .init(storage: storage, storageKey: "album.qa.\(runID).\(role)", autoRefreshToken: false)
        ))
    }

    private func syncAndAssert(_ sync: SupabaseSync, client: SupabaseClient, expected: UUID, store: AlbumStore, receipt: inout Receipt, receiptURL: URL) async throws {
        try await probeSession(client, expected: expected, receipt: &receipt, receiptURL: receiptURL)
        do {
            try await sync.sync(store: store)
        } catch let syncError {
            do {
                try await probeSession(client, expected: expected, receipt: &receipt, receiptURL: receiptURL)
            } catch let probeError {
                throw NSError(domain: "Album.LiveSupabaseQA", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Sync-Fehler mit zusätzlichem Sessionproblem (\(String(describing: type(of: probeError)))): \(probeError.localizedDescription)",
                    NSUnderlyingErrorKey: syncError
                ])
            }
            throw syncError
        }
        try assertStableSession(client, expected: expected, receipt: &receipt, receiptURL: receiptURL)
    }

    private func probeSession(_ client: SupabaseClient, expected: UUID, receipt: inout Receipt, receiptURL: URL) async throws {
        do {
            let session = try await client.auth.session
            guard session.user.id == expected else {
                if !receipt.userIDs.contains(session.user.id.uuidString) { receipt.userIDs.append(session.user.id.uuidString) }
                try writeReceipt(receipt, to: receiptURL)
                throw NSError(domain: "Album.LiveSupabaseQA", code: 4, userInfo: [NSLocalizedDescriptionKey: "Supabase-Session-ID wechselte zu \(session.user.id.uuidString)"])
            }
            try assertStableSession(client, expected: expected, receipt: &receipt, receiptURL: receiptURL)
        } catch let error {
            throw NSError(domain: "Album.LiveSupabaseQA", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Session-Probe (\(String(describing: type(of: error)))): \(error.localizedDescription)",
                NSUnderlyingErrorKey: error
            ])
        }
    }

    private func assertStableSession(_ client: SupabaseClient, expected: UUID, receipt: inout Receipt, receiptURL: URL) throws {
        guard let actual = client.auth.currentUser?.id else {
            throw NSError(domain: "Album.LiveSupabaseQA", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase currentUser fehlt"])
        }
        guard actual == expected else {
            if !receipt.userIDs.contains(actual.uuidString) { receipt.userIDs.append(actual.uuidString) }
            try writeReceipt(receipt, to: receiptURL)
            throw NSError(domain: "Album.LiveSupabaseQA", code: 2, userInfo: [NSLocalizedDescriptionKey: "Supabase-Session wechselte von \(expected.uuidString) zu \(actual.uuidString)"])
        }
    }

    private func makeSyntheticJPEG() throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 24))
        let image = renderer.image { context in
            UIColor.systemRed.setFill(); context.fill(CGRect(x: 0, y: 0, width: 16, height: 24))
            UIColor.systemBlue.setFill(); context.fill(CGRect(x: 16, y: 0, width: 16, height: 24))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
    }

    private func makeSyntheticPDF(at url: URL) throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 180))
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            let text = Self.storagePDFText
            (text as NSString).draw(at: CGPoint(x: 24, y: 70), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
        }
    }

    private func writeReceipt(_ receipt: Receipt, to url: URL) throws {
        let data = try JSONEncoder().encode(receipt)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func record(_ phase: String, detail: String, receipt: inout Receipt, receiptURL: URL) throws {
        receipt.timeline.append(TimingEvent(phase: phase, timestamp: Date().timeIntervalSince1970, detail: detail))
        try writeReceipt(receipt, to: receiptURL)
    }

    private func attach(_ receipt: Receipt) {
        let attachment = XCTAttachment(string: "QA run \(receipt.runID); user IDs: \(receipt.userIDs.joined(separator: ",")); trip ID: \(receipt.tripID ?? "pending")")
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private final class NoBackgroundSyncService: AlbumSyncService {
    func createTrip(store: AlbumStore) async throws -> CollaborationState {
        throw NSError(domain: "Album.LiveSupabaseQA", code: 10, userInfo: [NSLocalizedDescriptionKey: "Automatischer Test-Sync ist deaktiviert"])
    }

    func joinTrip(token: String) async throws -> CollaborationState {
        throw NSError(domain: "Album.LiveSupabaseQA", code: 10, userInfo: [NSLocalizedDescriptionKey: "Automatischer Test-Sync ist deaktiviert"])
    }

    func sync(store: AlbumStore) async throws {}
    func startRealtime(onChange: @escaping @MainActor @Sendable () async -> Void) {}
}
