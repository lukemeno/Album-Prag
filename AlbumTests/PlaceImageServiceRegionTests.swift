import XCTest
import MapKit
import UIKit
@testable import Album

final class PlaceImageServiceRegionTests: XCTestCase {
    func testTestStoreWithoutImageFixtureReturnsDeterministicEmptyResult() throws {
        let result = try XCTUnwrap(PlaceImageService.testStoreResponse(environment: [
            "ALBUM_TEST_STORE": "ui-region-test",
        ]))

        XCTAssertNil(result.image)
        XCTAssertEqual(result.candidates?.count, 0)
        XCTAssertEqual(result.selectionVersion, PlaceImageService.ranking)
    }

    func testNormalRunDoesNotUseTestStoreFallback() throws {
        XCTAssertNil(try PlaceImageService.testStoreResponse(environment: [:]))
    }

    func testLiveImagePreviewRequiresExplicitOptIn() throws {
        XCTAssertNil(try PlaceImageService.testStoreResponse(environment: [
            "ALBUM_TEST_STORE": "live-preview", "ALBUM_LIVE_IMAGE_QA": "1"
        ]))
        XCTAssertNotNil(try PlaceImageService.testStoreResponse(environment: [
            "ALBUM_TEST_STORE": "live-preview", "ALBUM_LIVE_IMAGE_QA": "0"
        ]))
    }

    func testExplicitImageFixtureTakesPriorityOverLivePreview() throws {
        let fixture = Data(#"{"selection_version":4,"image":null,"candidates":[]}"#.utf8)
        XCTAssertNotNil(try PlaceImageService.testStoreResponse(environment: [
            "ALBUM_TEST_STORE": "live-preview", "ALBUM_LIVE_IMAGE_QA": "1",
            "ALBUM_IMAGE_RESPONSE_BASE64": fixture.base64EncodedString()
        ]))
    }

    func testDisplayImageSuppressesMapArtifactsButPreservesGenuineWebPreview() {
        let mapURL = "https://www.google.com/maps/search/?api=1&query=Hotel+Urban+Creme"
        let mapPlace = Place(title: "Hotel Urban Crème", sourceURL: mapURL, image: .linkPreview(pageURL: mapURL, thumbnailURL: nil, credit: "Google Maps"), lat: 50.08, lng: 14.42)
        XCTAssertNil(mapPlace.displayImage)

        var snapshot = UploadedPlaceImage(id: "generated-map", storagePath: nil, pixelWidth: 1200, pixelHeight: 900, resolvedFor: nil)
        snapshot.generatedSource = .mapSnapshot
        let snapshotPlace = Place(title: "Hotel Urban Crème", image: .uploaded(snapshot), lat: 50.08, lng: 14.42)
        XCTAssertNil(snapshotPlace.displayImage)

        let web = PlaceImageAsset.linkPreview(pageURL: "https://hotel.example/", thumbnailURL: "https://hotel.example/hero.jpg", credit: "hotel.example")
        let webPlace = Place(title: "Hotel Urban Crème", sourceURL: "https://hotel.example/", image: web, lat: 50.08, lng: 14.42)
        XCTAssertEqual(webPlace.displayImage, web)
    }

    func testSourcePreviewRequiresExactNearbyVenueAndRejectsAmbiguousResults() async {
        let place = sourcePlace()
        let near = mapItem(name: place.title, latitude: 50.0801, longitude: 14.4201, url: "https://hotel.example/")
        let far = mapItem(name: place.title, latitude: 50.0815, longitude: 14.4200, url: "https://other.example/")

        let valid = await PlaceImageService.sourcePreview(
            for: place,
            search: { _ in [near] },
            preview: { _ in .init(title: "Hotel Urban Crème", thumbnail_url: "https://hotel.example/hero.jpg") },
            imageData: { _ in self.imageData(width: 640, height: 400) }
        )
        XCTAssertEqual(valid?.provider, .sourcePreview)
        XCTAssertEqual(valid?.confidence, .suggested)
        XCTAssertEqual(valid?.credit, "Website-Vorschau · hotel.example")
        XCTAssertEqual(valid?.caption, "Hotel Urban Crème")

        let ambiguous = await PlaceImageService.sourcePreview(
            for: place,
            search: { _ in [near, far] },
            preview: { _ in .init(title: "Hotel Urban Crème", thumbnail_url: "https://hotel.example/hero.jpg") },
            imageData: { _ in self.imageData(width: 640, height: 400) }
        )
        XCTAssertNil(ambiguous)
    }

    func testSourcePreviewRejectsMapLogoAndTinyThumbnails() async {
        let place = sourcePlace()
        let mapURL = "https://www.google.com/maps/search/?api=1&query=Hotel"
        let map = mapItem(name: place.title, latitude: 50.0801, longitude: 14.4201, url: mapURL)
        XCTAssertNil(PlaceImageService.normalizedSourcePreviewURL(mapURL))
        XCTAssertNil(PlaceImageService.sourcePreviewWebsite(for: place, mapItems: [map]))
        let mapResult = await PlaceImageService.sourcePreview(for: place, search: { _ in [map] })
        XCTAssertNil(mapResult)

        let website = mapItem(name: place.title, latitude: 50.0801, longitude: 14.4201, url: "https://hotel.example/")
        let logo = await PlaceImageService.sourcePreview(
            for: place,
            search: { _ in [website] },
            preview: { _ in .init(title: "Hotel Urban Crème", thumbnail_url: "https://hotel.example/assets/logo.png") },
            imageData: { _ in self.imageData(width: 640, height: 400) }
        )
        XCTAssertNil(logo)

        let tiny = await PlaceImageService.sourcePreview(
            for: place,
            search: { _ in [website] },
            preview: { _ in .init(title: "Hotel Urban Crème", thumbnail_url: "https://hotel.example/assets/hero.jpg") },
            imageData: { _ in self.imageData(width: 120, height: 100) }
        )
        XCTAssertNil(tiny)
    }

    func testSourcePreviewImageURLBoundsSanityCDNWithoutRewritingOtherHosts() throws {
        let sanity = try XCTUnwrap(URL(string: "https://cdn.sanity.io/images/project/production/photo-6562x4375.jpg?rect=0,0,6562,4375&w=6562&fit=crop&fm=png"))
        let optimized = try XCTUnwrap(PlaceImageService.sourcePreviewImageURL(sanity))
        let query = try XCTUnwrap(URLComponents(url: optimized, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(optimized.host, "cdn.sanity.io")
        XCTAssertEqual(query.first(where: { $0.name == "rect" })?.value, "0,0,6562,4375")
        XCTAssertEqual(query.first(where: { $0.name == "w" })?.value, "1200")
        XCTAssertEqual(query.first(where: { $0.name == "fit" })?.value, "max")
        XCTAssertEqual(query.first(where: { $0.name == "fm" })?.value, "jpg")

        let officialSite = try XCTUnwrap(URL(string: "https://hotel.example/hero.jpg?width=640"))
        XCTAssertEqual(PlaceImageService.sourcePreviewImageURL(officialSite), officialSite)
    }

    func testSourcePreviewRequiresDiscriminativeVenueEvidence() async {
        let pasta = Place(title: "Pasta Fresca", category: "Essen & Trinken", lat: 50.087, lng: 14.421)
        let genericWebsite = mapItem(name: pasta.title, latitude: 50.0871, longitude: 14.4211, url: "https://restaurant.example/")
        let genericResult = await PlaceImageService.sourcePreview(
            for: pasta,
            search: { _ in [genericWebsite] },
            preview: { _ in .init(title: "Pasta recipes", thumbnail_url: "https://restaurant.example/hero.jpg") },
            imageData: { _ in self.imageData(width: 640, height: 400) }
        )
        XCTAssertNil(genericResult)

        let cafe = Place(title: "Cafe", category: "Essen & Trinken", lat: 50.087, lng: 14.421)
        let cafeWebsite = mapItem(name: cafe.title, latitude: 50.0871, longitude: 14.4211, url: "https://cafe.example/")
        let cafeResult = await PlaceImageService.sourcePreview(
            for: cafe,
            search: { _ in [cafeWebsite] },
            preview: { _ in .init(title: "Cafe", thumbnail_url: "https://cafe.example/hero.jpg") },
            imageData: { _ in self.imageData(width: 640, height: 400) }
        )
        XCTAssertNil(cafeResult)

        let realWebsite = mapItem(name: pasta.title, latitude: 50.0871, longitude: 14.4211, url: "https://pastafresca.ambi.cz/")
        let realResult = await PlaceImageService.sourcePreview(
            for: pasta,
            search: { _ in [realWebsite] },
            preview: { _ in .init(title: "Pasta Fresca", thumbnail_url: "https://pastafresca.ambi.cz/hero.jpg") },
            imageData: { _ in self.imageData(width: 640, height: 400) }
        )
        XCTAssertEqual(realResult?.provider, .sourcePreview)
    }

    func testSourcePreviewFallsBackFromOGLogoToVenueSpecificHTMLPhoto() async {
        let place = Place(title: "Pasta Fresca", category: "Essen & Trinken", lat: 50.087, lng: 14.421)
        let website = mapItem(name: place.title, latitude: 50.0871, longitude: 14.4211, url: "https://pastafresca.example/")
        let html = Data(#"""
        <html><head><meta property="og:title" content="Pasta Fresca"><meta property="og:image" content="https://pastafresca.example/assets/logo.svg"></head>
        <body><img src="/cf-image?url=https%3A%2F%2Fcdn.example%2Fpasta.jpeg&amp;width=1920&amp;quality=75" alt="Interiér restaurace Pasta Fresca s prostřenými stoly"></body></html>
        """#.utf8)

        let result = await PlaceImageService.sourcePreview(
            for: place,
            search: { _ in [website] },
            preview: { _ in .init(title: "Pasta Fresca", thumbnail_url: "https://pastafresca.example/assets/logo.svg") },
            imageData: { url in
                XCTAssertTrue(url.absoluteString.contains("cf-image"))
                XCTAssertTrue(url.absoluteString.contains("width=1920&quality=75"))
                return self.imageData(width: 1920, height: 1080)
            },
            htmlData: { _ in (html, URL(string: "https://pastafresca.example/")!) }
        )

        XCTAssertEqual(result?.provider, .sourcePreview)
        XCTAssertTrue(result?.imageURL.absoluteString.contains("cf-image") == true)
        XCTAssertFalse(result?.imageURL.pathExtension.lowercased() == "svg")
    }

    func testSourcePreviewRetryIsEligibleForGeneratedAndExistingSourcePreviewAssets() {
        var generated = UploadedPlaceImage(id: "generated", storagePath: nil, pixelWidth: 1200, pixelHeight: 900, resolvedFor: nil)
        generated.generatedSource = .mapSnapshot
        let generatedPlace = Place(title: "Hotel Urban Crème", image: .uploaded(generated), lat: 50.08, lng: 14.42)
        XCTAssertTrue(PlaceImageService.canUseSourcePreview(for: generatedPlace))

        let source = ExternalPlaceImage(imageURL: "https://hotel.example/hero.jpg", sourceURL: "https://hotel.example/", credit: "Website-Vorschau · hotel.example", provider: .sourcePreview, licenseName: nil, licenseURL: nil, providerPlaceID: nil, resolvedFor: nil, ranking: PlaceImageService.ranking, userSelected: false)
        let sourcePlace = Place(title: "Hotel Urban Crème", image: .external(source), lat: 50.08, lng: 14.42)
        XCTAssertTrue(PlaceImageService.canUseSourcePreview(for: sourcePlace))
        XCTAssertTrue(PlaceImageService.shouldSearch(for: sourcePlace, force: false))

        let social = Place(title: "Hotel Urban Crème", image: .linkPreview(pageURL: "https://www.instagram.com/p/abc", thumbnailURL: nil, credit: "Instagram"), lat: 50.08, lng: 14.42)
        XCTAssertFalse(PlaceImageService.canUseSourcePreview(for: social))
        XCTAssertTrue(PlaceImageService.shouldSearch(for: social, force: false))

        let socialURLOnly = Place(title: "Hotel Urban Crème", sourceURL: "https://www.instagram.com/p/abc", lat: 50.08, lng: 14.42)
        XCTAssertFalse(PlaceImageService.canUseSourcePreview(for: socialURLOnly))

        let mapsURLOnly = Place(title: "Hotel Urban Crème", sourceURL: "https://www.google.com/maps/search/?api=1&query=Hotel", lat: 50.08, lng: 14.42)
        XCTAssertTrue(PlaceImageService.canUseSourcePreview(for: mapsURLOnly))
        let mapsLink = Place(title: "Hotel Urban Crème", image: .linkPreview(pageURL: "https://www.google.com/maps/search/?api=1&query=Hotel", thumbnailURL: nil, credit: "Google Maps"), lat: 50.08, lng: 14.42)
        XCTAssertTrue(PlaceImageService.canUseSourcePreview(for: mapsLink))

        let genuine = Place(title: "Hotel Urban Crème", image: .linkPreview(pageURL: "https://hotel.example/", thumbnailURL: "https://hotel.example/hero.jpg", credit: "hotel.example"), lat: 50.08, lng: 14.42)
        XCTAssertFalse(PlaceImageService.canUseSourcePreview(for: genuine))
        let unusable = Place(title: "Hotel Urban Crème", image: .linkPreview(pageURL: "https://hotel.example/", thumbnailURL: "https://hotel.example/logo.svg", credit: "hotel.example"), lat: 50.08, lng: 14.42)
        XCTAssertTrue(PlaceImageService.canUseSourcePreview(for: unusable))
    }

    func testSourcePreviewUsesOnlyVenueMatchedUserWebsiteWhenMapKitOmitsURL() async {
        let place = Place(title: "Pasta Fresca", sourceURL: "https://pastafresca.ambi.cz/", category: "Essen & Trinken", lat: 50.087, lng: 14.421)
        let mapItemWithoutWebsite = mapItem(name: place.title, latitude: 50.0871, longitude: 14.4211, url: nil)
        let result = await PlaceImageService.sourcePreview(
            for: place,
            search: { _ in [mapItemWithoutWebsite] },
            preview: { _ in .init(title: "Pasta Fresca", thumbnail_url: "https://pastafresca.ambi.cz/hero.jpg") },
            imageData: { _ in self.imageData(width: 640, height: 400) }
        )
        XCTAssertEqual(result?.provider, .sourcePreview)
        XCTAssertTrue(PlaceImageService.canUseSourcePreview(for: place))

        let mapsPlace = Place(title: "Pasta Fresca", sourceURL: "https://www.google.com/maps/search/?api=1&query=Pasta+Fresca", category: "Essen & Trinken", lat: 50.087, lng: 14.421)
        XCTAssertTrue(PlaceImageService.canUseSourcePreview(for: mapsPlace))
        let mapsResult = await PlaceImageService.sourcePreview(for: mapsPlace, search: { _ in [mapItemWithoutWebsite] })
        XCTAssertNil(mapsResult)
    }

    func testLiveSourcePreviewRealWebsitesWhenOptedIn() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["ALBUM_LIVE_SOURCE_PREVIEW_QA"] == "1"
                || environment["TEST_RUNNER_ALBUM_LIVE_SOURCE_PREVIEW_QA"] == "1" else {
            throw XCTSkip("Set ALBUM_LIVE_SOURCE_PREVIEW_QA=1 for the opt-in MapKit/network proof")
        }

        let probes = [("Knedlín Prague", "Knedlín", Optional<String>.none), ("Pasta Fresca Prague", "Pasta Fresca", Optional("https://pastafresca.ambi.cz/"))]
        var receipt: [[String: String]] = []
        for (query, expectedName, suppliedWebsite) in probes {
            let item = try await liveMapItem(query: query, expectedName: expectedName)
            let coordinate = item.placemark.coordinate
            print("SOURCE_PREVIEW_LIVE_MAP name=\(item.name ?? expectedName) website=\(item.url?.absoluteString ?? "-") source=\(suppliedWebsite == nil ? "mapkit" : "suppliedWebsite") lat=\(coordinate.latitude) lng=\(coordinate.longitude)")
            let place = Place(
                title: item.name ?? expectedName,
                sourceURL: suppliedWebsite ?? "",
                category: "Essen & Trinken",
                address: item.placemark.title ?? "",
                lat: coordinate.latitude,
                lng: coordinate.longitude
            )
            let result = await PlaceImageService.sourcePreview(for: place, search: { _ in
                let candidates = try await self.liveMapItems(query: query)
                for candidate in candidates {
                    let candidateCoordinate = candidate.placemark.coordinate
                    print("SOURCE_PREVIEW_LIVE_CANDIDATE name=\(candidate.name ?? "-") website=\(candidate.url?.absoluteString ?? "-") lat=\(candidateCoordinate.latitude) lng=\(candidateCoordinate.longitude)")
                }
                return candidates
            }, allowNetworkFallback: true)
            let image = try XCTUnwrap(result, "Keine Source-Preview für \(place.title)")
            XCTAssertEqual(image.provider, .sourcePreview)
            XCTAssertEqual(image.confidence, .suggested)
            XCTAssertFalse(image.imageURL.pathExtension.caseInsensitiveCompare("svg") == .orderedSame)
            print("SOURCE_PREVIEW_LIVE name=\(place.title) website=\(image.sourceURL.absoluteString) image=\(image.imageURL.absoluteString)")
            receipt.append([
                "name": place.title,
                "website": image.sourceURL.absoluteString,
                "website_source": suppliedWebsite == nil ? "mapkit" : "suppliedWebsite",
                "image": image.imageURL.absoluteString,
            ])
        }

        let data = try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: "/tmp/album-source-preview-live.json"), options: .atomic)
    }

    private func sourcePlace() -> Place {
        Place(title: "Hotel Urban Crème", category: "Hotel", lat: 50.08, lng: 14.42)
    }

    private func mapItem(name: String, latitude: Double, longitude: Double, url: String?) -> MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
        item.name = name
        item.url = url.flatMap(URL.init(string:))
        return item
    }

    private func imageData(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 0.85)!
    }

    private func liveMapItem(query: String, expectedName: String) async throws -> MKMapItem {
        let items = try await liveMapItems(query: query)
        let expected = normalizedLiveName(expectedName)
        let candidates = items.filter {
            normalizedLiveName($0.name ?? "") == expected
        }
        guard let item = candidates.first else {
            throw NSError(domain: "PlaceImageServiceRegionTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "No exact MapKit result for \(expectedName)"])
        }
        return item
    }

    private func liveMapItems(query: String) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.087, longitude: 14.421),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        return try await MKLocalSearch(request: request).start().mapItems
    }

    private func normalizedLiveName(_ raw: String) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics
        return folded.unicodeScalars.map { allowed.contains($0) ? String($0) : " " }
            .joined().split(whereSeparator: { $0 == " " }).joined(separator: " ")
    }
}
