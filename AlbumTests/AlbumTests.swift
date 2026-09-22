import XCTest
import PDFKit
@testable import Album

final class AlbumTests: XCTestCase {
    func testOnlyWebLinksAccepted() {
        XCTAssertNil(LinkValidation.url("javascript:alert(1)"))
        XCTAssertNil(LinkValidation.url("file:///private/test"))
        XCTAssertNil(LinkValidation.url("https://"))
        XCTAssertNotNil(LinkValidation.url("https://www.instagram.com/reel/example/"))
        XCTAssertEqual(LinkValidation.firstURL(in: "Schau mal https://www.tiktok.com/@user/video/123")?.host, "www.tiktok.com")
    }
    func testCoordinatesMustBeValid() {
        var place = Place(title: "Prag")
        XCTAssertNil(place.coordinate)
        place.lat = 50.087; place.lng = 14.423
        XCTAssertNotNil(place.coordinate)
        place.lat = 100
        XCTAssertNil(place.coordinate)
    }
    func testSourceHostCannotSpoofTikTok() {
        let place = Place(title: "Test", sourceURL: "https://tiktok.com.evil.example/video")
        XCTAssertNotEqual(place.sourceLabel, "TikTok")
    }
    func testSourcePreviewWinsAutomaticImageSearch() {
        let place = Place(title: "Letná", image: .linkPreview(
            pageURL: "https://example.com/letna",
            thumbnailURL: "https://example.com/letna.jpg",
            credit: "example.com"
        ))
        XCTAssertFalse(PlaceImageService.shouldSearch(for: place, force: false))
        XCTAssertTrue(PlaceImageService.shouldSearch(for: place, force: true))
        XCTAssertTrue(PlaceImageService.shouldSearch(for: Place(title: "Letná"), force: false))
    }

    func testLegacyImageFieldsMigrateToTypedAsset() throws {
        let json = #"{"id":"legacy","title":"Letná","remoteImage":"https://example.com/letna.jpg","imageSourceURL":"https://example.com/source","imageCredit":"Archiv"}"#.data(using: .utf8)!
        let place = try JSONDecoder().decode(Place.self, from: json)

        guard case .external(let image) = place.image else {
            return XCTFail("Legacy remoteImage was not migrated")
        }
        XCTAssertEqual(image.provider, .legacy)
        XCTAssertEqual(image.credit, "Archiv")

        let encoded = try JSONEncoder().encode(place)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNotNil(object["image"])
        XCTAssertNil(object["remoteImage"])
    }

    func testChangedResolvedPlaceRequestsAFreshImage() {
        let resolved = ResolvedPlaceIdentity(title: "Letná", latitude: 50.0957, longitude: 14.4165)
        let asset = PlaceImageAsset.external(.init(
            imageURL: "https://example.com/letna.jpg",
            sourceURL: "https://example.com/source",
            credit: "Archiv",
            provider: .wikimedia,
            resolvedFor: resolved
        ))
        let samePlace = Place(title: "Letná", image: asset, lat: 50.0957, lng: 14.4165)
        let movedPlace = Place(title: "Letná", image: asset, lat: 50.0755, lng: 14.4378)
        XCTAssertFalse(PlaceImageService.shouldSearch(for: samePlace, force: false))
        XCTAssertTrue(PlaceImageService.shouldSearch(for: movedPlace, force: false))
    }

    func testOwnPhotoIsNormalizedAndBounded() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 3200, height: 1600))
        let source = renderer.jpegData(withCompressionQuality: 1) { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3200, height: 1600))
        }

        let uploaded = try PlaceImageStorage.save(source, root: directory, id: "bounded")
        let storedURL = PlaceImageStorage.localURL(for: uploaded, root: directory)
        let storedData = try Data(contentsOf: storedURL)
        let image = try XCTUnwrap(UIImage(data: storedData))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 2048)
        XCTAssertLessThanOrEqual(storedData.count, 5 * 1024 * 1024)
        XCTAssertEqual(uploaded.pixelWidth, 2048)
        XCTAssertEqual(uploaded.pixelHeight, 1024)
    }
    @MainActor func testPersistenceAndInboxDecisions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumStore(root: directory)
        let example = try XCTUnwrap(store.inbox.first)
        store.deferPlace(example)
        XCTAssertFalse(store.inbox.contains { $0.id == example.id })
        XCTAssertEqual(store.deferred.count, 1)
        store.restoreDeferred()
        XCTAssertEqual(store.inbox.count, 3)
        var place = example; place.franked = true; place.lat = 50.087; place.lng = 14.423
        store.upsert(place)
        let reopened = AlbumStore(root: directory)
        XCTAssertEqual(reopened.franked.count, 1)
        XCTAssertEqual(reopened.inbox.count, 2)
        XCTAssertTrue(reopened.data.dirty.contains(example.id))
        var deleted = place; deleted.deleted = true; reopened.upsert(deleted)
        XCTAssertFalse(reopened.places.contains { $0.id == place.id })
        XCTAssertTrue(reopened.data.places.contains { $0.id == place.id && $0.deleted })
    }
    @MainActor func testPDFImportPersistsOriginalAndText() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumStore(root: directory)
        let source = directory.appendingPathComponent("booking.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 400))
        try renderer.writePDF(to: source) { ctx in
            ctx.beginPage()
            ("Prague 4 October 2026" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
        }
        try store.importPDF(source, id: "test-document")
        XCTAssertEqual(store.data.documents.count, 1)
        XCTAssertTrue(store.data.documents[0].extractedText.contains("Prague"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("test-document.pdf").path))
        try store.importPDF(source, id: "test-document")
        XCTAssertEqual(store.data.documents.count, 1)
        XCTAssertEqual(AlbumStore(root: directory).data.documents.count, 1)
    }
    @MainActor func testCorruptStoreIsNotOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("album.json")
        let corrupt = Data("broken-data".utf8)
        try corrupt.write(to: file)
        let store = AlbumStore(root: directory)
        XCTAssertNotNil(store.error)
        XCTAssertFalse(store.persist())
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }
    @MainActor func testTripChangesPersist() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumStore(root: directory)
        var trip = store.data.trip; trip.outbound = "14:45"; trip.route = "CGN → PRG"
        store.updateTrip(trip)
        XCTAssertEqual(AlbumStore(root: directory).data.trip.outbound, "14:45")
        XCTAssertTrue(store.data.dirty.contains("trip"))
    }

    func testInvitationLinksRejectWrongSchemeAndShortTokens() throws {
        let token = String(repeating: "a", count: 43)
        let url = try XCTUnwrap(InvitationLink.make(token: token))
        XCTAssertEqual(InvitationLink.token(from: url), token)
        XCTAssertNil(InvitationLink.token(from: URL(string: "https://join/\(token)")!))
        XCTAssertNil(InvitationLink.token(from: URL(string: "album://join/short")!))
    }

    func testNewestRecordWinsConflict() {
        let older = Place(id: "same", title: "Alt", updatedAt: Date(timeIntervalSince1970: 10))
        let newer = Place(id: "same", title: "Neu", updatedAt: Date(timeIntervalSince1970: 20))
        XCTAssertEqual(AlbumMerge.place(local: older, remote: newer).title, "Neu")
        XCTAssertEqual(AlbumMerge.place(local: newer, remote: older).title, "Neu")
    }

    @MainActor func testLocalAlbumBecomesSharedIdempotently() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumStore(root: directory)
        let service = MockSyncService()
        store.syncService = service

        let link = try await store.createSharedTrip()

        XCTAssertEqual(store.data.collaboration?.tripID, service.tripID)
        XCTAssertEqual(InvitationLink.token(from: link), service.token)
        XCTAssertEqual(service.syncCount, 1)
        XCTAssertTrue(service.lastDirty.contains("trip"))
        XCTAssertEqual(AlbumStore(root: directory).data.collaboration?.tripID, service.tripID)
    }

    func testExistingAlbumWithoutCollaborationStillDecodes() throws {
        let oldJSON = #"{"places":[],"trip":{"hotel":"Urban Crème","outbound":"","arrival":"","route":"","flightNumber":"","notes":"","updatedAt":0},"documents":[],"dirty":[]}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AlbumData.self, from: oldJSON)
        XCTAssertNil(decoded.collaboration)
    }
}

@MainActor private final class MockSyncService: AlbumSyncService {
    let tripID = UUID()
    let token = String(repeating: "t", count: 43)
    var syncCount = 0
    var lastDirty: Set<String> = []

    func createTrip(store: AlbumStore) async throws -> CollaborationState {
        try await sync(store: store)
        return CollaborationState(tripID: tripID, inviteToken: token)
    }
    func joinTrip(token: String) async throws -> CollaborationState {
        CollaborationState(tripID: tripID, inviteToken: nil)
    }
    func sync(store: AlbumStore) async throws {
        syncCount += 1
        lastDirty = store.data.dirty
    }
    func startRealtime(onChange: @escaping @MainActor @Sendable () async -> Void) {}
}
