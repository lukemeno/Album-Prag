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
    }

    static func image(for place: Place, bundle: Bundle = .main) async throws -> PlaceImage? {
        guard let coordinate = place.coordinate,
              !place.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
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
        return response.image
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

/// Echtes Bild vom Ort: erst Wikimedia (über die Edge Function), sonst Apple Look Around an genau dieser Koordinate.
enum PlaceImageResolver {
    static func resolve(for place: Place, root: URL) async -> PlaceImageAsset? {
        guard let coordinate = place.coordinate else { return nil }
        if let image = try? await PlaceImageService.image(for: place) { return image.asset(for: place) }
        guard let data = await lookAroundSnapshot(at: coordinate),
              let uploaded = try? PlaceImageStorage.save(data, root: root) else { return nil }
        return .uploaded(uploaded)
    }

    /// Straßenansicht von Apple Karten; läuft auf dem Gerät, ohne Schlüssel. Nil, wo es keine Aufnahmen gibt.
    static func lookAroundSnapshot(at coordinate: CLLocationCoordinate2D) async -> Data? {
        guard let scene = try? await MKLookAroundSceneRequest(coordinate: coordinate).scene else { return nil }
        let options = MKLookAroundSnapshotter.Options()
        options.size = CGSize(width: 1200, height: 900)
        guard let snapshot = try? await MKLookAroundSnapshotter(scene: scene, options: options).snapshot else { return nil }
        return snapshot.image.jpegData(compressionQuality: 0.85)
    }
}
