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

    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case sourceURL = "source_url"
        case credit
        case provider
        case licenseName = "license_name"
        case licenseURL = "license_url"
        case providerPlaceID = "provider_place_id"
    }

    func asset(for place: Place) -> PlaceImageAsset {
        let coordinate = place.coordinate
        return .external(ExternalPlaceImage(
            imageURL: imageURL.absoluteString,
            sourceURL: sourceURL.absoluteString,
            credit: credit,
            provider: provider ?? .legacy,
            licenseName: licenseName,
            licenseURL: licenseURL?.absoluteString,
            providerPlaceID: providerPlaceID,
            resolvedFor: coordinate.map { ResolvedPlaceIdentity(title: place.title, latitude: $0.latitude, longitude: $0.longitude) },
            ranking: PlaceImageService.ranking
        ))
    }
}

enum PlaceImageService {
    /// 2: typischstes Foto aus Hauptbild, Commons-Kategorie und Umgebung (statt nur Wikidata-Hauptbild).
    static let ranking = 2

    private struct Request: Encodable {
        let title: String
        let latitude: Double
        let longitude: Double
        let category: String
        let address: String
    }

    private struct Response: Decodable {
        let image: PlaceImage?
        /// Bis zu acht Fotos, das beste zuerst (seit Foto-Auswahl 2).
        let candidates: [PlaceImage]?
    }

    static func image(for place: Place, bundle: Bundle = .main) async throws -> PlaceImage? {
        try await images(for: place, bundle: bundle).first
    }

    /// Das Hauptfoto und weitere Fotos für den Foto-Streifen, bestes zuerst.
    static func images(for place: Place, bundle: Bundle = .main) async throws -> [PlaceImage] {
        guard let coordinate = place.coordinate,
              !place.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let client = try SupabaseConfiguration.client(bundle: bundle)
        if (try? await client.auth.session) == nil { _ = try await client.auth.signInAnonymously() }
        let response: Response = try await client.functions.invoke(
            "place-photo",
            options: FunctionInvokeOptions(body: Request(
                title: place.title,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                category: place.category,
                address: place.address
            ))
        )
        return response.candidates ?? response.image.map { [$0] } ?? []
    }

    /// Weitere Fotos neben dem Hauptfoto: höchstens zwei, ohne Doppelte.
    static func gallery(from images: [PlaceImage], for place: Place) -> [ExternalPlaceImage] {
        images.dropFirst().prefix(2).compactMap {
            if case .external(let image) = $0.asset(for: place) { return image }
            return nil
        }
    }

    /// Ein Wikimedia-Ort ohne Foto-Streifen bekommt ihn einmal nachgeliefert.
    static func needsGallery(_ place: Place) -> Bool {
        guard place.gallery == nil, case .external(let image) = place.image else { return false }
        return image.provider == .wikimedia
    }

    static func shouldSearch(for place: Place, force: Bool) -> Bool {
        if force { return true }
        switch place.image {
        case nil, .bundled: return true
        case .external(let image):
            if image.provider == .wikimedia && (image.ranking ?? 1) < ranking { return true }
            return image.resolvedFor.map { !$0.matches(place) } ?? false
        // Ein TikTok-Standbild zeigt meist Menschen, nicht den Ort: Sobald der Ort bestätigt ist, gewinnt ein echtes Ortsfoto.
        case .linkPreview: return place.coordinate != nil
        case .uploaded: return false
        }
    }
}

/// Ersatz, wenn Wikimedia nichts hat: Apple Look Around an genau dieser Koordinate.
enum PlaceImageResolver {
    /// Straßenansicht von Apple Karten; läuft auf dem Gerät, ohne Schlüssel. Nil, wo es keine Aufnahmen gibt.
    static func lookAroundSnapshot(at coordinate: CLLocationCoordinate2D) async -> Data? {
        guard let scene = try? await MKLookAroundSceneRequest(coordinate: coordinate).scene else { return nil }
        let options = MKLookAroundSnapshotter.Options()
        options.size = CGSize(width: 1200, height: 900)
        guard let snapshot = try? await MKLookAroundSnapshotter(scene: scene, options: options).snapshot else { return nil }
        return snapshot.image.jpegData(compressionQuality: 0.85)
    }
}
