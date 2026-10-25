import XCTest
import CoreLocation
import MapKit
@testable import Album

@MainActor
final class PlaceResolutionTests: XCTestCase {
    private var roots: [URL] = []

    override func tearDownWithError() throws {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots.removeAll()
        try super.tearDownWithError()
    }

    private func makeStore() -> AlbumStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("place-resolution-\(UUID().uuidString)", isDirectory: true)
        roots.append(root)
        let store = AlbumStore(root: root, shareInbox: ShareInbox(root: root.appendingPathComponent("share", isDirectory: true)))
        store.data.places = []
        return store
    }

    private func context(_ name: String, latitude: Double, longitude: Double) -> TripRegionContext {
        TripRegionContext(name: name,
                          region: MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                                     span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)),
                          preferredLanguageCode: "en", source: .confirmedPlaces)
    }

    private func candidate(_ id: String, _ title: String, _ address: String, _ latitude: Double, _ longitude: Double) -> PlaceResolutionCandidate {
        PlaceResolutionCandidate(id: id, title: title, address: address, latitude: latitude, longitude: longitude, category: nil)
    }

    func testNamesResolveAcrossTokyoParisSaoPauloAndArabic() {
        let cases: [(String, String, String, Double, Double)] = [
            ("Sensoji Temple", "Sensoji Temple", "Asakusa, Tokyo", 35.7148, 139.7967),
            ("Café des Amis", "Café des Amis", "Paris, France", 48.8566, 2.3522),
            ("Museu de Arte Moderna", "Museu de Arte Moderna", "São Paulo", -23.5614, -46.6559),
            ("متحف الفن الإسلامي", "متحف الفن الإسلامي", "الدوحة", 25.2950, 51.5310)
        ]
        for (title, resultTitle, address, latitude, longitude) in cases {
            let place = Place(title: title, category: "Sehenswert")
            let tripContext = context(address.components(separatedBy: ",").last ?? address, latitude: latitude, longitude: longitude)
            let result = PlaceResolver.rank(place: place, context: tripContext,
                                            candidates: [candidate("match", resultTitle, address, latitude, longitude)])
            guard case .resolved(let resolved) = result else {
                XCTFail("Erwartete sichere Zuordnung für \(title), erhielt \(result)")
                continue
            }
            XCTAssertEqual(resolved.id, "match")
        }
    }

    func testGenericRamenNeedsReviewWithoutTrustedAddress() {
        let place = Place(title: "Ramen", category: "Essen & Trinken")
        let result = PlaceResolver.rank(place: place, context: context("Tokyo", latitude: 35.68, longitude: 139.76), candidates: [
            candidate("one", "Ramen House", "Tokyo", 35.68, 139.76),
            candidate("two", "Ramen Corner", "Tokyo", 35.68, 139.76)
        ])
        guard case .needsReview(_, .genericConcept) = result else { return XCTFail("Generische Idee muss geprüft werden: \(result)") }
    }

    func testTrustedAddressCanResolveEvenWhenTitleIsGeneric() {
        let place = Place(title: "Ramen", category: "Essen", address: "1 Chome-1-1 Asakusa")
        let result = PlaceResolver.rank(place: place, context: context("Tokyo", latitude: 35.71, longitude: 139.79), candidates: [
            candidate("exact", "Ramen", "1 Chome-1-1 Asakusa, Tokyo", 35.714, 139.796)
        ])
        guard case .resolved(let resolved) = result else { return XCTFail("Vertrauenswürdige Adresse sollte auflösen: \(result)") }
        XCTAssertEqual(resolved.id, "exact")
    }

    func testEqualCandidatesStayAmbiguous() {
        let place = Place(title: "Café Savoy", category: "Essen & Trinken")
        let tripContext = context("Prague", latitude: 50.08, longitude: 14.42)
        let result = PlaceResolver.rank(place: place, context: tripContext, candidates: [
            candidate("first", "Café Savoy", "Prague 1", 50.081, 14.421),
            candidate("second", "Café Savoy", "Prague 2", 50.081, 14.421)
        ])
        guard case .needsReview(_, .ambiguous) = result else { return XCTFail("Gleich starke Treffer müssen mehrdeutig bleiben: \(result)") }
    }

    func testMissingContextNeverChoosesCandidate() {
        let place = Place(title: "Café Louvre", category: "Essen")
        let noContext = TripRegionContext(name: nil, region: nil, preferredLanguageCode: "en", source: .none)
        let result = PlaceResolver.rank(place: place, context: noContext, candidates: [candidate("x", "Café Louvre", "Paris", 48.8, 2.3)])
        guard case .needsReview(_, .missingContext) = result else { return XCTFail("Ohne Kontext darf nicht automatisch gewählt werden") }
    }

    func testConfirmedPlaceCentroidHandlesDateLine() {
        let store = makeStore()
        store.data.trip.destination = "Fiji"
        store.data.places = [
            Place(id: "west", title: "West", category: "Idee", lat: 10, lng: 179.5, franked: true),
            Place(id: "east", title: "East", category: "Idee", lat: 10, lng: -179.5, franked: true)
        ]
        let result = store.tripRegionContext
        XCTAssertEqual(result.source, .confirmedPlaces)
        let longitude = try! XCTUnwrap(result.region?.center.longitude)
        XCTAssertGreaterThan(abs(longitude), 179)
    }

    func testStaleResolutionAfterTripChangeIsIgnored() async {
        let store = makeStore()
        store.data.trip.destination = "Tokyo"
        let place = Place(id: "stale", title: "Sensoji Temple", category: "Sehenswert")
        store.data.places = [place]
        store.placeResolutionResolver = { _, _ in
            store.data.trip.destination = "Osaka"
            return .resolved(self.candidate("temple", "Sensoji Temple", "Tokyo", 35.71, 139.79))
        }
        await store.refreshPlaceImage(id: place.id)
        XCTAssertNil(store.places.first?.coordinate)
        XCTAssertEqual(store.placeImageStatus(for: place.id), .idle)
    }

    func testCancelledResolutionClearsAttemptAndStatus() async {
        let store = makeStore()
        store.data.trip.destination = "Tokyo"
        let place = Place(id: "cancelled", title: "Sensoji Asakusa Temple", category: "Sehenswert")
        store.data.places = [place]
        var continuation: CheckedContinuation<PlaceResolutionOutcome, Never>?
        store.placeResolutionResolver = { _, _ in
            await withCheckedContinuation { continuation = $0 }
        }
        let task = Task { await store.refreshPlaceImage(id: place.id) }
        while continuation == nil { await Task.yield() }
        task.cancel()
        continuation?.resume(returning: .resolved(self.candidate("temple", "Sensoji Asakusa Temple", "Tokyo", 35.71, 139.79)))
        await task.value
        XCTAssertNil(store.places.first?.coordinate)
        XCTAssertEqual(store.placeImageStatus(for: place.id), .idle)

        store.placeResolutionResolver = { _, _ in .failed(retryable: true) }
        await store.refreshPlaceImage(id: place.id)
        XCTAssertEqual(store.placeImageStatus(for: place.id), .failed(retryable: true))
    }

    func testCancelledPhotoSearchCanBeRetried() async {
        let store = makeStore()
        store.data.trip.destination = "Tokyo"
        let place = Place(id: "photo-cancel", title: "Sensoji Asakusa Temple", category: "Sehenswert", lat: 35.71, lng: 139.79)
        store.data.places = [place]
        var continuation: CheckedContinuation<PlaceImageSearchResult, Error>?
        var calls = 0
        store.placeImageSearchResolver = { _, _ in
            calls += 1
            if calls == 1 {
                return try await withCheckedThrowingContinuation { continuation = $0 }
            }
            return PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking)
        }
        let task = Task { await store.refreshPlaceImage(id: place.id) }
        while continuation == nil { await Task.yield() }
        task.cancel()
        continuation?.resume(returning: PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking))
        await task.value
        XCTAssertEqual(store.placeImageStatus(for: place.id), .idle)
        await store.refreshPlaceImage(id: place.id)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(store.placeImageStatus(for: place.id), .notFound)
    }

    func testDeletedPlaceCannotReceiveLateResolution() async {
        let store = makeStore()
        store.data.trip.destination = "Tokyo"
        let place = Place(id: "deleted", title: "Sensoji Temple", category: "Sehenswert")
        store.data.places = [place]
        store.placeResolutionResolver = { _, _ in
            var deleted = place
            deleted.deleted = true
            _ = store.upsert(deleted)
            return .resolved(self.candidate("temple", "Sensoji Temple", "Tokyo", 35.71, 139.79))
        }
        await store.refreshPlaceImage(id: place.id)
        XCTAssertTrue(store.places.isEmpty)
        XCTAssertNil(store.data.places.first?.coordinate)
    }

    private func staleWikimediaAsset(for place: Place) -> PlaceImageAsset {
        .external(ExternalPlaceImage(
            imageURL: "https://example.test/old.jpg",
            sourceURL: "https://example.test/old-source",
            credit: "Wikimedia",
            provider: .wikimedia,
            resolvedFor: ResolvedPlaceIdentity(title: place.title, latitude: place.lat!, longitude: place.lng!, category: place.category, address: place.address),
            ranking: PlaceImageService.ranking - 1,
            userSelected: false
        ))
    }

    private func imageResult(confidence: PlaceImage.Confidence?, title: String) -> PlaceImageSearchResult {
        let image = confidence.map {
            PlaceImage(imageURL: URL(string: "https://example.test/\(title).jpg")!,
                       sourceURL: URL(string: "https://example.test/\(title)")!,
                       credit: "Test", provider: .wikimedia, licenseName: nil, licenseURL: nil,
                       providerPlaceID: nil, confidence: $0, caption: title)
        }
        return PlaceImageSearchResult(image: image, candidates: [], selectionVersion: PlaceImageService.ranking)
    }

    private func sourcePreview(title: String = "source-preview") -> PlaceImage {
        PlaceImage(imageURL: URL(string: "https://example.test/\(title).jpg")!,
                   sourceURL: URL(string: "https://example.test/\(title)")!,
                   credit: "Website", provider: .sourcePreview, licenseName: nil, licenseURL: nil,
                   providerPlaceID: nil, confidence: .suggested, caption: title)
    }

    private func mapSnapshotAsset(for place: Place) -> PlaceImageAsset {
        var photo = UploadedPlaceImage(id: "map-\(place.id)", storagePath: nil, pixelWidth: 1200, pixelHeight: 900)
        photo.resolvedFor = ResolvedPlaceIdentity(title: place.title, latitude: place.lat!, longitude: place.lng!, category: place.category, address: place.address)
        photo.generatedSource = .mapSnapshot
        return .uploaded(photo)
    }

    func testCurrentEmptyRankingRemovesStaleAutomaticWikimediaImage() async {
        let store = makeStore()
        let base = Place(id: "stale-image", title: "Sensoji Temple", category: "Sehenswert", lat: 35.71, lng: 139.79)
        var place = base
        place.image = staleWikimediaAsset(for: base)
        store.data.places = [place]
        store.placeImageSearchResolver = { _, _ in self.imageResult(confidence: nil, title: "empty") }
        await store.refreshPlaceImage(id: place.id)
        XCTAssertNil(store.places.first?.image)
        XCTAssertEqual(store.placeImageStatus(for: place.id), .notFound)
    }

    func testNetworkFailureKeepsStaleWikimediaImageForRetry() async {
        let store = makeStore()
        let base = Place(id: "stale-network", title: "Sensoji Temple", category: "Sehenswert", lat: 35.71, lng: 139.79)
        var place = base
        place.image = staleWikimediaAsset(for: base)
        store.data.places = [place]
        store.placeImageSearchResolver = { _, _ in throw NSError(domain: "PlaceResolutionTests", code: 1) }
        await store.refreshPlaceImage(id: place.id)
        XCTAssertEqual(store.places.first?.image, place.image)
        XCTAssertEqual(store.placeImageStatus(for: place.id), .failed(retryable: true))
    }

    func testVerifiedCurrentRankingReplacesStaleWikimediaImage() async {
        let store = makeStore()
        let base = Place(id: "stale-verified", title: "Sensoji Temple", category: "Sehenswert", lat: 35.71, lng: 139.79)
        var place = base
        place.image = staleWikimediaAsset(for: base)
        store.data.places = [place]
        store.placeImageSearchResolver = { _, _ in self.imageResult(confidence: .verified, title: "verified") }
        await store.refreshPlaceImage(id: place.id)
        guard case .external(let image)? = store.places.first?.image else { return XCTFail("Verifizierter Treffer sollte gespeichert sein") }
        XCTAssertEqual(image.provider, .wikimedia)
        XCTAssertEqual(image.ranking, PlaceImageService.ranking)
        XCTAssertNotEqual(image.imageURL, "https://example.test/old.jpg")
    }

    func testSourcePreviewReplacesGeneratedMapAfterNoVerifiedResult() async {
        let base = Place(id: "map-source", title: "Café Savoy",
                         sourceURL: "https://www.google.com/maps/search/?api=1&query=Cafe+Savoy", category: "Essen & Trinken", lat: 50.0755, lng: 14.4072)
        var place = base
        place.image = mapSnapshotAsset(for: base)
        let store = makeStore()
        store.data.places = [place]
        var previewCalls = 0
        store.placeImageSearchResolver = { _, _ in
            PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking)
        }
        store.placeSourcePreviewResolver = { _, _ in
            previewCalls += 1
            return self.sourcePreview()
        }

        await store.refreshPlaceImage(id: place.id)

        guard case .external(let image)? = store.places.first?.image else { return XCTFail("Website-Preview fehlt") }
        XCTAssertEqual(image.provider, .sourcePreview)
        XCTAssertEqual(image.resolvedFor?.title, place.title)
        XCTAssertEqual(previewCalls, 1)
        XCTAssertEqual(store.placeImageStatus(for: place.id), .ready)
    }

    func testHiddenGeneratedMapRemainsStoredButReportsNotFound() async {
        let base = Place(id: "hidden-map", title: "Café Savoy", category: "Essen & Trinken", lat: 50.0755, lng: 14.4072)
        var place = base
        place.image = mapSnapshotAsset(for: base)
        let store = makeStore()
        store.data.places = [place]
        store.placeImageSearchResolver = { _, _ in
            PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking)
        }

        await store.refreshPlaceImage(id: place.id)

        XCTAssertEqual(store.places.first?.image, place.image)
        XCTAssertEqual(store.placeImageStatus(for: place.id), .notFound)
    }

    func testVerifiedCommonsWinsWithoutCallingSourcePreview() async {
        let base = Place(id: "commons-wins", title: "Café Savoy",
                         sourceURL: "https://www.google.com/maps/search/?api=1&query=Cafe+Savoy", category: "Essen & Trinken", lat: 50.0755, lng: 14.4072)
        var place = base
        place.image = mapSnapshotAsset(for: base)
        let store = makeStore()
        store.data.places = [place]
        var previewCalls = 0
        store.placeImageSearchResolver = { _, _ in self.imageResult(confidence: .verified, title: "commons") }
        store.placeSourcePreviewResolver = { _, _ in
            previewCalls += 1
            return self.sourcePreview()
        }

        await store.refreshPlaceImage(id: place.id)

        guard case .external(let image)? = store.places.first?.image else { return XCTFail("Commons-Treffer fehlt") }
        XCTAssertEqual(image.provider, .wikimedia)
        XCTAssertEqual(previewCalls, 0)
    }

    func testOwnAndManualImagesAreProtected() async {
        let own = Place(id: "own-photo", title: "Own",
                        image: .uploaded(.init(id: "own", storagePath: nil, pixelWidth: 800, pixelHeight: 600)), lat: 50.0, lng: 14.0)
        let manual = Place(id: "manual-photo", title: "Manual",
                           image: .external(ExternalPlaceImage(imageURL: "https://example.test/manual.jpg",
                                                               sourceURL: "https://example.test/manual", credit: "Me",
                                                               provider: .wikimedia, userSelected: true)), lat: 50.0, lng: 14.0)

        for original in [own, manual] {
            let store = makeStore()
            store.data.places = [original]
            var searchCalls = 0
            var previewCalls = 0
            store.placeImageSearchResolver = { _, _ in
                searchCalls += 1
                return self.imageResult(confidence: .verified, title: "replacement")
            }
            store.placeSourcePreviewResolver = { _, _ in
                previewCalls += 1
                return self.sourcePreview()
            }
            await store.refreshPlaceImage(id: original.id, force: true)
            XCTAssertEqual(store.places.first?.image, original.image, "(original.id) wurde ersetzt")
            XCTAssertEqual(searchCalls, 0)
            XCTAssertEqual(previewCalls, 0)
        }
    }

    func testGenuineLinkPreviewIsProtectedFromSourcePreviewFallback() async {
        let link = Place(id: "link-preview", title: "Link", sourceURL: "https://example.test/post",
                         image: .linkPreview(pageURL: "https://example.test/post", thumbnailURL: "https://example.test/thumb.jpg", credit: "example.test"), lat: 50.0, lng: 14.0)
        let store = makeStore()
        store.data.places = [link]
        var previewCalls = 0
        store.placeImageSearchResolver = { _, _ in
            PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking)
        }
        store.placeSourcePreviewResolver = { _, _ in
            previewCalls += 1
            return self.sourcePreview()
        }

        await store.refreshPlaceImage(id: link.id, force: true)

        XCTAssertEqual(store.places.first?.image, link.image)
        XCTAssertEqual(previewCalls, 0)
    }

    func testVerifiedCommonsCanUpgradeExistingLinkPreview() async {
        let link = Place(id: "commons-link-preview", title: "Café Savoy", sourceURL: "https://www.tiktok.com/@trip/video/1",
                         image: .linkPreview(pageURL: "https://www.tiktok.com/@trip/video/1", thumbnailURL: "https://example.test/thumb.jpg", credit: "TikTok"), lat: 50.0, lng: 14.0)
        let store = makeStore()
        store.data.places = [link]
        store.placeImageSearchResolver = { _, _ in self.imageResult(confidence: .verified, title: "commons-link") }

        await store.refreshPlaceImage(id: link.id, force: true)

        guard case .external(let image)? = store.places.first?.image else { return XCTFail("Commons-Treffer fehlt") }
        XCTAssertEqual(image.provider, .wikimedia)
    }

    func testMapLinkPreviewCanUseSourcePreviewWhenServiceAllowsIt() async {
        let link = Place(id: "map-link-preview", title: "Café Savoy",
                         sourceURL: "https://www.google.com/maps/search/?api=1&query=Cafe+Savoy",
                         image: .linkPreview(pageURL: "https://www.google.com/maps/search/?api=1&query=Cafe+Savoy",
                                              thumbnailURL: nil, credit: "Google Maps"), lat: 50.0, lng: 14.0)
        let store = makeStore()
        store.data.places = [link]
        store.placeImageSearchResolver = { _, _ in
            PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking)
        }
        var previewCalls = 0
        store.placeSourcePreviewResolver = { _, _ in
            previewCalls += 1
            return self.sourcePreview(title: "map-source")
        }

        await store.refreshPlaceImage(id: link.id)

        XCTAssertEqual(previewCalls, 1)
        guard case .external(let image)? = store.places.first?.image else { return XCTFail("Map-Website-Preview fehlt") }
        XCTAssertEqual(image.provider, .sourcePreview)
    }

    func testCancelledSourcePreviewPreservesImageAndCanRetry() async {
        let base = Place(id: "cancel-source", title: "Café Savoy",
                         sourceURL: "https://www.google.com/maps/search/?api=1&query=Cafe+Savoy", category: "Essen & Trinken", lat: 50.0755, lng: 14.4072)
        var place = base
        place.image = mapSnapshotAsset(for: base)
        let store = makeStore()
        store.data.places = [place]
        store.placeImageSearchResolver = { _, _ in PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking) }
        var continuation: CheckedContinuation<PlaceImage?, Never>?
        var calls = 0
        store.placeSourcePreviewResolver = { _, _ in
            calls += 1
            if calls == 1 { return await withCheckedContinuation { continuation = $0 } }
            return self.sourcePreview(title: "retry")
        }
        let task = Task { await store.refreshPlaceImage(id: place.id) }
        while continuation == nil { await Task.yield() }
        task.cancel()
        continuation?.resume(returning: self.sourcePreview(title: "cancelled"))
        await task.value

        XCTAssertEqual(store.places.first?.image, place.image)
        XCTAssertEqual(store.placeImageStatus(for: place.id), .idle)
        await store.refreshPlaceImage(id: place.id)
        XCTAssertEqual(calls, 2)
        guard case .external(let image)? = store.places.first?.image else { return XCTFail("Retry-Preview fehlt") }
        XCTAssertEqual(image.provider, .sourcePreview)
    }

    func testStaleSourcePreviewResultIsIgnoredAfterPlaceChange() async {
        let base = Place(id: "stale-source", title: "Café Savoy",
                         sourceURL: "https://www.google.com/maps/search/?api=1&query=Cafe+Savoy", category: "Essen & Trinken", lat: 50.0755, lng: 14.4072)
        var place = base
        place.image = mapSnapshotAsset(for: base)
        let store = makeStore()
        store.data.places = [place]
        store.placeImageSearchResolver = { _, _ in PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking) }
        store.placeSourcePreviewResolver = { _, _ in
            var changed = base
            changed.title = "Changed"
            changed.image = place.image
            _ = store.upsert(changed)
            return self.sourcePreview(title: "stale")
        }

        await store.refreshPlaceImage(id: place.id)

        XCTAssertEqual(store.places.first?.title, "Changed")
        XCTAssertEqual(store.places.first?.image, place.image)
        XCTAssertEqual(store.placeImageStatus(for: place.id), .idle)
    }

    func testSourcePreviewResultIsIgnoredAfterSourceURLChange() async {
        let base = Place(id: "stale-source-url", title: "Café Savoy",
                         sourceURL: "https://www.google.com/maps/search/?api=1&query=Cafe+Savoy", category: "Essen & Trinken", lat: 50.0755, lng: 14.4072)
        var place = base
        place.image = mapSnapshotAsset(for: base)
        let store = makeStore()
        store.data.places = [place]
        store.placeImageSearchResolver = { _, _ in PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking) }
        store.placeSourcePreviewResolver = { _, _ in
            var changed = base
            changed.sourceURL = "https://example.test/post"
            changed.image = place.image
            _ = store.upsert(changed)
            return self.sourcePreview(title: "stale-source-url")
        }

        await store.refreshPlaceImage(id: place.id)

        XCTAssertEqual(store.places.first?.sourceURL, "https://example.test/post")
        XCTAssertEqual(store.places.first?.image, place.image)
        XCTAssertEqual(store.placeImageStatus(for: place.id), .idle)
    }

    func testRefreshPlaceImagesPrioritizesMapSeedAndCapsBatch() async {
        let store = makeStore()
        let ordinary = (0..<5).map { index in
            Place(id: "ordinary-\(index)", title: "Ordinary \(index)", lat: 50.0 + Double(index) / 100, lng: 14.0)
        }
        let mapSeed = Place(id: "map-seed", title: "Café Seed", sourceURL: "https://www.google.com/maps/search/?api=1&query=Cafe", lat: 50.2, lng: 14.0)
        store.data.places = ordinary + [mapSeed]
        var calls: [String] = []
        store.placeImageSearchResolver = { place, _ in
            calls.append(place.id)
            return PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking)
        }
        store.placeSourcePreviewResolver = { _, _ in nil }

        await store.refreshPlaceImages()

        XCTAssertEqual(calls.count, 5)
        XCTAssertEqual(calls.first, mapSeed.id)
        XCTAssertFalse(calls.contains(ordinary.last!.id))
    }

    func testManuallyChosenImageIsNeverReplacedByRefresh() async {
        let store = makeStore()
        let place = Place(id: "manual-image", title: "Sensoji Temple", category: "Sehenswert",
                          image: .external(ExternalPlaceImage(imageURL: "https://example.test/mine.jpg",
                                                              sourceURL: "https://example.test/mine",
                                                              credit: "Eigenes Bild", provider: .wikimedia,
                                                              ranking: 1, userSelected: true)), lat: 35.71, lng: 139.79)
        store.data.places = [place]
        var calls = 0
        store.placeImageSearchResolver = { _, _ in
            calls += 1
            return self.imageResult(confidence: .verified, title: "automatic")
        }
        await store.refreshPlaceImage(id: place.id, force: true)
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(store.places.first?.image, place.image)
    }

    func testRetryAndExplicitCandidateSelection() async {
        let store = makeStore()
        store.data.trip.destination = "Tokyo"
        let place = Place(id: "manual", title: "Sensoji Temple", category: "Sehenswert")
        store.data.places = [place]
        let selected = candidate("temple", "Sensoji Temple", "Asakusa, Tokyo", 35.714, 139.796)
        var attempts = 0
        store.placeResolutionResolver = { _, _ in
            attempts += 1
            return attempts == 1 ? .failed(retryable: true) : .needsReview([selected], .ambiguous)
        }
        store.placeImageSearchResolver = { _, _ in PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking) }

        await store.refreshPlaceImage(id: place.id)
        XCTAssertEqual(store.placeImageStatus(for: place.id), .failed(retryable: true))
        await store.refreshPlaceImage(id: place.id, force: true)
        guard case .needsReview([selected], .ambiguous) = store.placeImageStatus(for: place.id) else {
            return XCTFail("Erneuter Versuch soll die Auswahl anbieten")
        }
        await store.acceptPlaceResolution(placeID: place.id, candidate: selected)
        XCTAssertEqual(store.places.first?.coordinate?.latitude, selected.latitude)
        XCTAssertEqual(store.places.first?.address, selected.address)
        XCTAssertEqual(store.placeImageStatus(for: place.id), .notFound)
    }
}
