import XCTest
import Foundation
import UIKit
import MapKit
@testable import Album

@MainActor
final class PhotoResolutionCoordinatorTests: XCTestCase {
    private final class Counter { var value = 0 }
    private var roots: [URL] = []

    override func tearDownWithError() throws {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots.removeAll()
        try super.tearDownWithError()
    }

    private func makeStore() -> AlbumStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("auto-photo-\(UUID().uuidString)", isDirectory: true)
        roots.append(root)
        let store = AlbumStore(root: root, shareInbox: ShareInbox(root: root.appendingPathComponent("share", isDirectory: true)))
        store.data.places = []
        store.data.trip.destination = "Tokyo"
        _ = store.persist()
        return store
    }

    private func installFixtureResolvers(on store: AlbumStore, counter: Counter) {
        store.placeResolutionResolver = { place, _ in
            .resolved(PlaceResolutionCandidate(id: "fixture-\(place.id)", title: place.title,
                                                address: "Tokyo, Japan", latitude: 35.6586, longitude: 139.7454,
                                                category: place.category))
        }
        store.placeImageSearchResolver = { place, _ in
            counter.value += 1
            let image = PlaceImage(imageURL: URL(fileURLWithPath: "/tmp/\(place.id).jpg"),
                                   sourceURL: URL(string: "https://commons.wikimedia.org/wiki/\(place.id)")!,
                                   credit: "Fixture Wikimedia", provider: .wikimedia,
                                   licenseName: "CC0", licenseURL: nil, providerPlaceID: place.id,
                                   confidence: .verified, caption: place.title)
            return PlaceImageSearchResult(image: image, candidates: [], selectionVersion: PlaceImageService.ranking)
        }
    }

    func testSavingAnIdeaAutomaticallyResolvesAndPersistsItsImage() async throws {
        let store = makeStore()
        let counter = Counter()
        installFixtureResolvers(on: store, counter: counter)
        let place = Place(id: "auto-one", title: "Sensoji Temple", category: "Sehenswert")
        XCTAssertTrue(store.upsert(place))
        await store.drainAutomaticPhotoResolutionForTesting()
        let saved = try XCTUnwrap(store.places.first { $0.id == place.id })
        guard case .external(let image) = saved.image else { return XCTFail("Automatic queue did not save an image") }
        XCTAssertEqual(image.provider, .wikimedia)
        XCTAssertEqual(counter.value, 1)
        XCTAssertEqual(store.automaticPhotoJob(for: place.id)?.state, .completed)
        let reopened = AlbumStore(root: store.root, shareInbox: ShareInbox(root: store.root.appendingPathComponent("share", isDirectory: true)))
        guard case .external(let persisted) = reopened.places.first(where: { $0.id == place.id })?.image else { return XCTFail("Automatic image was not persisted") }
        XCTAssertEqual(persisted.sourceURL, image.sourceURL)
    }

    func testAutomaticQueueProcessesMoreThanFivePlacesAndProtectsManualImage() async throws {
        let store = makeStore()
        let counter = Counter()
        installFixtureResolvers(on: store, counter: counter)
        for index in 0..<8 {
            XCTAssertTrue(store.upsert(Place(id: "auto-\(index)", title: "Place \(index)", category: "Sehenswert", lat: 35.0 + Double(index) / 100, lng: 139.0)))
        }
        let manual = Place(id: "manual", title: "Eigene Aufnahme", category: "Sehenswert", lat: 35.7, lng: 139.7,
                           image: .external(ExternalPlaceImage(imageURL: "https://example.test/mine.jpg", sourceURL: "https://example.test/mine", credit: "Eigenes Foto", provider: .wikimedia, userSelected: true)))
        XCTAssertTrue(store.upsert(manual))
        await store.drainAutomaticPhotoResolutionForTesting()
        XCTAssertEqual(counter.value, 8)
        XCTAssertEqual(store.places.filter { $0.image != nil }.count, 9)
        XCTAssertEqual(store.automaticPhotoJob(for: manual.id)?.state, .completed)
    }

    func testTravelContextChangeQueuesNewIdentityWithoutReplacingAutomaticImage() async throws {
        let store = makeStore()
        let counter = Counter()
        store.placeImageSearchResolver = { _, _ in
            counter.value += 1
            return PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking)
        }
        let place = Place(id: "context-place", title: "Museum", category: "Sehenswert", lat: 35.7, lng: 139.7)
        XCTAssertTrue(store.upsert(place))
        await store.drainAutomaticPhotoResolutionForTesting()
        XCTAssertEqual(counter.value, 1)
        var trip = store.data.trip
        trip.destination = "Paris"
        XCTAssertTrue(store.updateTrip(trip))
        await store.drainAutomaticPhotoResolutionForTesting()
        XCTAssertEqual(counter.value, 2)
        XCTAssertNil(store.places.first?.image)
    }

    func testExplicitRemovalPersistsAutomaticPhotoSuppression() async throws {
        let store = makeStore()
        let original = Place(id: "suppressed", title: "Museum", category: "Sehenswert", lat: 35.7, lng: 139.7,
                             image: .external(ExternalPlaceImage(imageURL: "https://example.test/auto.jpg", sourceURL: "https://example.test/auto", credit: "Auto", provider: .wikimedia)))
        XCTAssertTrue(store.upsert(original))
        var removed = original
        removed.image = nil
        XCTAssertTrue(store.upsert(removed, photoAutomation: .suppress))
        let reopened = AlbumStore(root: store.root, shareInbox: ShareInbox(root: store.root.appendingPathComponent("share", isDirectory: true)))
        XCTAssertTrue(reopened.places.first?.automaticPhotoSuppressed == true)
        var calls = 0
        reopened.placeImageSearchResolver = { _, _ in
            calls += 1
            return PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking)
        }
        await reopened.drainAutomaticPhotoResolutionForTesting()
        XCTAssertEqual(calls, 0)
    }

    func testLiveAutomaticSaveProofIsExplicitlyOptIn() async throws {
        guard ProcessInfo.processInfo.environment["ALBUM_LIVE_AUTO_PHOTO_QA"] == "1" else {
            throw XCTSkip("Set ALBUM_LIVE_AUTO_PHOTO_QA=1 for the real automatic-save proof")
        }
        let store = makeStore()
        var request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "Knedlín Prague"
        request.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 50.0822, longitude: 14.4190),
                                             span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))
        let response = try await MKLocalSearch(request: request).start()
        let item = try XCTUnwrap(response.mapItems.first { ($0.name ?? "").localizedCaseInsensitiveContains("Knedl") })
        let coordinate = item.placemark.coordinate
        store.data.trip.destination = "Prag"
        store.placeImageSearchResolver = { _, _ in
            PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking)
        }
        store.placeSourcePreviewResolver = { place, _ in
            await PlaceImageService.sourcePreview(for: place, allowNetworkFallback: true)
        }
        let place = Place(id: "live-knedlin", title: item.name ?? "Knedlín", sourceURL: "https://knedlin.cz/", category: "Essen & Trinken", lat: coordinate.latitude, lng: coordinate.longitude)
        XCTAssertTrue(store.upsert(place))
        await store.drainAutomaticPhotoResolutionForTesting()
        let saved = try XCTUnwrap(store.places.first { $0.id == place.id })
        guard case .external(let image) = saved.image else { return XCTFail("No live automatic image result") }
        XCTAssertEqual(image.provider, .sourcePreview)
        XCTAssertFalse(image.sourceURL.isEmpty)
        let request = URLRequest(url: try XCTUnwrap(URL(string: image.imageURL)))
        let (bytes, _) = try await URLSession.shared.data(for: request)
        XCTAssertNotNil(UIImage(data: bytes))
        print("AUTO_PHOTO_LIVE name=\(saved.title) source=\(image.sourceURL) image=\(image.imageURL)")
    }

    func testAutomaticRequestCarriesLeaseAndRevisionContext() throws {
        let place = Place(id: "request-place", title: "Knedlín", category: "Essen & Trinken", lat: 50.0822, lng: 14.4190)
        let payload = try PlaceImageService.requestPayload(for: place, mode: .automatic,
                                                            tripID: "trip-123", placeID: place.id,
                                                            revision: "sha256-revision", region: "Prag",
                                                            languageCode: "de")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        XCTAssertEqual(object["mode"] as? String, "automatic_photo_v1")
        XCTAssertEqual(object["manual"] as? Bool, false)
        XCTAssertEqual(object["trip_id"] as? String, "trip-123")
        XCTAssertEqual(object["place_id"] as? String, place.id)
        XCTAssertEqual(object["revision"] as? String, "sha256-revision")
        let manualPayload = try PlaceImageService.requestPayload(for: place)
        let manual = try XCTUnwrap(JSONSerialization.jsonObject(with: manualPayload) as? [String: Any])
        XCTAssertEqual(manual["mode"] as? String, "manual")
        XCTAssertEqual(manual["manual"] as? Bool, true)
    }

    func testDeferredResponsePreservesServerRetryAfter() throws {
        let data = #"{"status":"deferred","retry_after_seconds":173,"selection_version":4}"#.data(using: .utf8)!
        let response = try JSONDecoder().decode(PlaceImageSearchResult.self, from: data)
        XCTAssertEqual(response.deferredRetryAfter, 173)
        XCTAssertTrue(response.automaticImages.isEmpty)
    }

    func testDeferredPhotoResponseDoesNotBecomeNoMatch() async throws {
        let store = makeStore()
        store.placeImageSearchResolver = { _, _ in
            PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking,
                                   status: "deferred", retryAfterSeconds: 42)
        }
        let place = Place(id: "deferred-place", title: "Café", category: "Essen & Trinken", lat: 35.7, lng: 139.7)
        XCTAssertTrue(store.upsert(place))
        await store.drainAutomaticPhotoResolutionForTesting()
        let job = try XCTUnwrap(store.automaticPhotoJob(for: place.id))
        XCTAssertEqual(job.state, .retryAt)
        XCTAssertEqual(job.lastErrorCode, "deferred")
        XCTAssertGreaterThanOrEqual(job.nextAttemptAt ?? .distantPast, Date().addingTimeInterval(35))
    }
}
