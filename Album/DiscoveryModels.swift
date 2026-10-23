import Foundation

enum DiscoveryInterest: String, Codable, CaseIterable, Hashable, Identifiable {
    case cultureMuseums = "culture_museums", history, architecture, natureParks = "nature_parks", viewpoints, art
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cultureMuseums: "Kultur & Museen"
        case .history: "Geschichte"
        case .architecture: "Architektur"
        case .natureParks: "Natur & Parks"
        case .viewpoints: "Aussicht"
        case .art: "Kunst"
        }
    }
}

struct DiscoveryCity: Codable, Equatable, Identifiable {
    let qid, name, country: String
    let latitude, longitude: Double
    let sourceURL: URL
    var id: String { qid }
    enum CodingKeys: String, CodingKey { case qid, name, country, latitude, longitude; case sourceURL = "source_url" }
}
struct DiscoveryCoverage: Codable, Equatable {
    enum Kind: String, Codable { case radius }
    let kind: Kind; let radiusMeters: Int; let label: String
    enum CodingKeys: String, CodingKey { case kind, label; case radiusMeters = "radius_meters" }
}
enum DiscoveryImageConfidence: String, Codable { case verified }
struct DiscoveryImage: Codable, Equatable {
    let imageURL, sourceURL: URL; let credit: String; let provider: PlaceImageProvider
    let licenseName: String; let licenseURL: URL; let providerPlaceID: String
    let confidence: DiscoveryImageConfidence; let caption: String?
    enum CodingKeys: String, CodingKey { case credit, provider, caption; case imageURL = "image_url"; case sourceURL = "source_url"; case licenseName = "license_name"; case licenseURL = "license_url"; case providerPlaceID = "provider_place_id"; case confidence }
}
struct DiscoveryItem: Codable, Equatable, Identifiable {
    let qid, name: String; let description: String?; let latitude, longitude: Double
    let interests: [DiscoveryInterest]; let wikipediaLanguageCount: Int; let sourceURL: URL
    let distanceMeters: Int; let image: DiscoveryImage?
    var id: String { qid }
    enum CodingKeys: String, CodingKey { case qid, name, description, latitude, longitude, interests, image; case wikipediaLanguageCount = "wikipedia_language_count"; case sourceURL = "source_url"; case distanceMeters = "distance_meters" }
}
enum DiscoveryCacheStatus: String, Codable { case fresh, stale }
struct DiscoveryCatalog: Codable, Equatable {
    let protocolVersion, catalogVersion, rankingVersion: Int; let city: DiscoveryCity
    let languageCode: String; let coverage: DiscoveryCoverage; let items: [DiscoveryItem]
    let fetchedAt, expiresAt, staleUntil: Date; let cacheStatus: DiscoveryCacheStatus
    enum CodingKeys: String, CodingKey { case city, items; case protocolVersion = "protocol_version"; case catalogVersion = "catalog_version"; case rankingVersion = "ranking_version"; case languageCode = "language_code"; case coverage; case fetchedAt = "fetched_at"; case expiresAt = "expires_at"; case staleUntil = "stale_until"; case cacheStatus = "cache_status" }
}
enum DiscoveryServiceError: Error, Equatable { case invalidRequest, unauthorized, rateLimited(retryAfter: Int?), sourceUnavailable(retryAfter: Int?), disabled, offline, invalidResponse }
enum DiscoveryPhase: Equatable { case needsInterests, needsCity, searchingCities, cityChoices, loadingCatalog, ready, empty, failed(DiscoveryServiceError) }
enum DiscoveryAdoptionResult: Equatable { case added(placeID: String), alreadyPresent(placeID: String, planned: Bool), removed(placeID: String), failed }
