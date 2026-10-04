import Foundation
import Supabase
import MapKit
import UIKit

struct PlaceImage: Decodable, Equatable {
    let imageURL: URL
    let sourceURL: URL
    let credit: String
    let provider: PlaceImageProvider?
    let licenseName: String?
    let licenseURL: URL?
    let providerPlaceID: String?
    var confidence: Confidence?
    var caption: String?

    enum Confidence: String, Decodable { case verified, suggested }

    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case sourceURL = "source_url"
        case credit
        case provider
        case licenseName = "license_name"
        case licenseURL = "license_url"
        case providerPlaceID = "provider_place_id"
        case confidence, caption
    }

    func asset(for place: Place, userSelected: Bool = false) -> PlaceImageAsset {
        let coordinate = place.coordinate
        return .external(ExternalPlaceImage(
            imageURL: imageURL.absoluteString,
            sourceURL: sourceURL.absoluteString,
            credit: credit,
            provider: provider ?? .legacy,
            licenseName: licenseName,
            licenseURL: licenseURL?.absoluteString,
            providerPlaceID: providerPlaceID,
            resolvedFor: coordinate.map { ResolvedPlaceIdentity(title: place.title, latitude: $0.latitude, longitude: $0.longitude, category: place.category, address: place.address) },
            ranking: PlaceImageService.ranking,
            userSelected: userSelected
        ))
    }
}

struct PlaceImageSearchResult: Decodable {
    let image: PlaceImage?
    let candidates: [PlaceImage]?
    let selectionVersion: Int?

    enum CodingKeys: String, CodingKey {
        case image, candidates
        case selectionVersion = "selection_version"
    }

    var isCurrent: Bool { (selectionVersion ?? 0) >= PlaceImageService.ranking }
    var choices: [PlaceImage] {
        var seen: Set<URL> = []
        return ((image.map { [$0] } ?? []) + (candidates ?? [])).filter { seen.insert($0.imageURL).inserted }
    }
    var automaticImages: [PlaceImage] {
        guard isCurrent, image?.confidence == .verified else { return [] }
        return choices.filter { $0.confidence == .verified }
    }
}

enum PlaceImageService {
    static let ranking = 3

    private struct Request: Encodable {
        let selection_version = PlaceImageService.ranking
        let title: String
        let latitude: Double
        let longitude: Double
        let category: String
        let address: String
    }

    static func image(for place: Place, bundle: Bundle = .main) async throws -> PlaceImage? {
        try await images(for: place, bundle: bundle).first
    }

    /// Das Hauptfoto und weitere Fotos für den Foto-Streifen, bestes zuerst.
    static func images(for place: Place, bundle: Bundle = .main) async throws -> [PlaceImage] {
        try await search(for: place, bundle: bundle).automaticImages
    }

    static func search(for place: Place, bundle: Bundle = .main) async throws -> PlaceImageSearchResult {
        guard let coordinate = place.coordinate,
              !place.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .init(image: nil, candidates: [], selectionVersion: ranking) }
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if let store = environment["ALBUM_TEST_STORE"], store.hasPrefix("slot-"),
           let encoded = environment["ALBUM_IMAGE_RESPONSE_BASE64"] {
            if let rawDelay = environment["ALBUM_IMAGE_RESPONSE_DELAY_MS"].flatMap(Int.init) {
                let delay = min(max(rawDelay, 0), 15_000)
                if delay > 0 {
                    // QA-only late-result simulation: deliberately detached from caller cancellation.
                    try await Task.detached {
                        try await Task.sleep(for: .milliseconds(delay))
                    }.value
                }
            }
            guard let data = Data(base64Encoded: encoded) else { throw CocoaError(.fileReadCorruptFile) }
            return try JSONDecoder().decode(PlaceImageSearchResult.self, from: data)
        }
        if let store = environment["ALBUM_TEST_STORE"], store.hasPrefix("slot-"), let filename = environment["ALBUM_IMAGE_RESPONSE"] {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(store).appendingPathComponent(filename)
            return try JSONDecoder().decode(PlaceImageSearchResult.self, from: Data(contentsOf: file))
        }
        #endif
        let client = try SupabaseConfiguration.client(bundle: bundle)
        if (try? await client.auth.session) == nil { _ = try await client.auth.signInAnonymously() }
        let response: PlaceImageSearchResult = try await client.functions.invoke(
            "place-photo",
            options: FunctionInvokeOptions(body: Request(
                title: place.title,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                category: place.category,
                address: place.address
            ))
        )
        return response
    }

    /// Weitere Fotos neben dem Hauptfoto: höchstens zwei, ohne Doppelte.
    static func gallery(from images: [PlaceImage], for place: Place) -> [ExternalPlaceImage] {
        images.dropFirst().filter { $0.confidence == .verified }.prefix(2).compactMap {
            if case .external(let image) = $0.asset(for: place) { return image }
            return nil
        }
    }

    /// Ein Wikimedia-Ort ohne Foto-Streifen bekommt ihn einmal nachgeliefert.
    static func needsGallery(_ place: Place) -> Bool {
        guard place.gallery == nil, case .external(let image) = place.image else { return false }
        return image.provider == .wikimedia && image.userSelected != true
    }

    static func shouldSearch(for place: Place, force: Bool) -> Bool {
        if force { return true }
        switch place.image {
        case nil, .bundled: return true
        case .external(let image):
            if image.resolvedFor.map({ !$0.matches(place) }) == true { return true }
            if image.userSelected == true { return false }
            if image.provider == .wikimedia && (image.ranking ?? 1) < ranking { return true }
            return image.provider == .legacy || image.resolvedFor == nil
        // Ein TikTok-Standbild zeigt meist Menschen, nicht den Ort: Sobald der Ort bestätigt ist, gewinnt ein echtes Ortsfoto.
        case .linkPreview: return place.coordinate != nil
        case .uploaded(let image):
            if image.resolvedFor.map({ !$0.matches(place) }) == true { return true }
            // Lokale Ersatzansichten dürfen in einem späteren App-Lauf durch ein verifiziertes Ortsfoto verbessert werden.
            return image.generatedSource != nil
        }
    }

    static func matchesRequest(_ original: Place, _ current: Place) -> Bool {
        original.title == current.title && original.lat == current.lat && original.lng == current.lng
            && original.category == current.category && original.address == current.address
    }

    static func locationMoved(from old: CLLocationCoordinate2D?, to new: CLLocationCoordinate2D) -> Bool {
        guard let old else { return false }
        return abs(old.latitude - new.latitude) > 0.0001 || abs(old.longitude - new.longitude) > 0.0001
    }

    /// External results and Look Around snapshots belong to their resolved location. A user photo and a link preview do not.
    static func shouldDiscardImageAfterLocationMove(_ asset: PlaceImageAsset?) -> Bool {
        switch asset {
        case .external: true
        case .uploaded(let image): image.resolvedFor != nil
        case .bundled, .linkPreview, .none: false
        }
    }

    /// Ein fehlgeschlagener Suchlauf darf nur ein Bild behalten, dessen Herkunft weiterhin zum Ort passt.
    static func canRetain(_ asset: PlaceImageAsset?, for place: Place) -> Bool {
        switch asset {
        case .bundled, .linkPreview: return true
        case .external(let image):
            if let resolvedFor = image.resolvedFor { return resolvedFor.matches(place) }
            return image.userSelected == true
        case .uploaded(let image):
            return image.resolvedFor?.matches(place) ?? true
        case nil: return false
        }
    }

    static func isUserChosen(_ asset: PlaceImageAsset?) -> Bool {
        switch asset {
        case .external(let image): image.userSelected == true
        case .uploaded(let image): image.generatedSource == nil && image.resolvedFor == nil
        case .bundled, .linkPreview, nil: false
        }
    }
}

struct LocalPlaceImage {
    let data: Data
    let source: GeneratedPlaceImageSource
}

/// Ortsgebundener Ersatz, wenn kein verifiziertes Foto verfügbar ist.
enum PlaceImageResolver {
    /// Apple Look Around zuerst; ohne Abdeckung folgt eine markierte Karte derselben Koordinate.
    static func localSnapshot(at coordinate: CLLocationCoordinate2D) async -> LocalPlaceImage? {
        if let data = await lookAroundSnapshot(at: coordinate) {
            return LocalPlaceImage(data: data, source: .lookAround)
        }
        if let data = await mapSnapshot(at: coordinate) {
            return LocalPlaceImage(data: data, source: .mapSnapshot)
        }
        return nil
    }

    /// Straßenansicht von Apple Karten; läuft auf dem Gerät, ohne Schlüssel. Nil, wo es keine Aufnahmen gibt.
    static func lookAroundSnapshot(at coordinate: CLLocationCoordinate2D) async -> Data? {
        #if DEBUG
        if ProcessInfo.processInfo.environment["ALBUM_DISABLE_LOOK_AROUND"] == "1" { return nil }
        #endif
        guard let scene = try? await MKLookAroundSceneRequest(coordinate: coordinate).scene else { return nil }
        let options = MKLookAroundSnapshotter.Options()
        options.size = CGSize(width: 1200, height: 900)
        guard let snapshot = try? await MKLookAroundSnapshotter(scene: scene, options: options).snapshot else { return nil }
        return snapshot.image.jpegData(compressionQuality: 0.85)
    }

    /// Letzte sichere Stufe: eine Kartenansicht mit einer sichtbaren Marke exakt an der Ortskoordinate.
    static func mapSnapshot(at coordinate: CLLocationCoordinate2D) async -> Data? {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
        )
        options.size = CGSize(width: 1200, height: 900)
        options.scale = 1
        options.mapType = .standard
        options.pointOfInterestFilter = .excludingAll
        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }

        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: options.size, format: format).image { _ in
            snapshot.image.draw(at: .zero)
            let point = snapshot.point(for: coordinate)
            let configuration = UIImage.SymbolConfiguration(pointSize: 78, weight: .bold)
            let marker = UIImage(systemName: "mappin.circle.fill", withConfiguration: configuration)?
                .withTintColor(.systemRed, renderingMode: .alwaysOriginal)
            marker?.draw(in: CGRect(x: point.x - 45, y: point.y - 86, width: 90, height: 90))
        }
        return image.jpegData(compressionQuality: 0.85)
    }
}
