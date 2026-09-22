import Foundation
import Supabase

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
            resolvedFor: coordinate.map { ResolvedPlaceIdentity(title: place.title, latitude: $0.latitude, longitude: $0.longitude) }
        ))
    }
}

enum PlaceImageService {
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
        case .external(let image): return image.resolvedFor.map { !$0.matches(place) } ?? false
        case .linkPreview, .uploaded: return false
        }
    }
}
