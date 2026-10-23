import Foundation
import Supabase

protocol DiscoveryServiceProtocol {
    func searchCities(query: String, languageCode: String) async throws -> [DiscoveryCity]
    func catalog(cityQID: String, languageCode: String) async throws -> DiscoveryCatalog
}

struct DiscoveryService: DiscoveryServiceProtocol {
    private struct Request: Encodable { let protocol_version = 1; let action: String; let query: String?; let city_qid: String?; let language_code: String }
    private struct CityResponse: Decodable { let protocolVersion: Int; let cities: [DiscoveryCity]; enum CodingKeys: String, CodingKey { case cities; case protocolVersion = "protocol_version" } }
    private let bundle: Bundle
    init(bundle: Bundle = .main) { self.bundle = bundle }

    func searchCities(query: String, languageCode: String) async throws -> [DiscoveryCity] {
        let response: CityResponse = try await request(Request(action: "search_cities", query: query, city_qid: nil, language_code: languageCode))
        guard response.protocolVersion == 1 else { throw DiscoveryServiceError.invalidResponse }
        return Array(response.cities.filter(valid).prefix(5))
    }
    func catalog(cityQID: String, languageCode: String) async throws -> DiscoveryCatalog {
        let catalog: DiscoveryCatalog = try await request(Request(action: "catalog", query: nil, city_qid: cityQID, language_code: languageCode))
        guard catalog.protocolVersion == 1, catalog.catalogVersion == 1, catalog.rankingVersion == 1,
              catalog.city.qid == cityQID, valid(catalog.city), catalog.items.count <= 60,
              catalog.coverage.kind == .radius, catalog.coverage.radiusMeters == 25_000,
              !catalog.languageCode.isEmpty, catalog.fetchedAt <= catalog.expiresAt, catalog.expiresAt <= catalog.staleUntil,
              catalog.staleUntil >= Date(),
              Set(catalog.items.map(\.qid)).count == catalog.items.count,
              catalog.items.allSatisfy({ item in
                  item.qid.range(of: #"^Q[1-9][0-9]*$"#, options: .regularExpression) != nil
                      && item.latitude.isFinite && item.longitude.isFinite && (-90...90).contains(item.latitude) && (-180...180).contains(item.longitude)
                      && item.sourceURL.absoluteString == "https://www.wikidata.org/wiki/\(item.qid)"
                      && !item.interests.isEmpty && item.wikipediaLanguageCount >= 0 && (0...catalog.coverage.radiusMeters).contains(item.distanceMeters)
                      && distance(item.latitude, item.longitude, catalog.city.latitude, catalog.city.longitude) <= Double(catalog.coverage.radiusMeters)
                      && (item.image == nil || (item.image?.provider == .wikimedia && item.image?.confidence == .verified && item.image?.providerPlaceID == item.qid && !(item.image?.credit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) && !(item.image?.licenseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) && item.image?.imageURL.scheme == "https" && item.image?.licenseURL.scheme == "https" && item.image?.sourceURL.scheme == "https"))
              }) else {
            throw DiscoveryServiceError.invalidResponse
        }
        return catalog
    }
    private func request<T: Decodable, B: Encodable>(_ body: B) async throws -> T {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["ALBUM_TEST_STORE"] != nil {
            if env["ALBUM_DISCOVERY_LIVE_QA"] != "1" { throw DiscoveryServiceError.disabled }
            guard let raw = env["ALBUM_DISCOVERY_LOCAL_URL"], let base = URL(string: raw),
                  ["http", "https"].contains(base.scheme?.lowercased() ?? ""),
                  ["localhost", "127.0.0.1", "::1"].contains(base.host?.lowercased() ?? ""), base.port != nil else {
                throw DiscoveryServiceError.invalidRequest
            }
            return try await send(body, to: base.appendingPathComponent("functions/v1/discover-places"), client: nil)
        }
        #endif
        let client = try SupabaseConfiguration.client(bundle: bundle)
        if (try? await client.auth.session) == nil { _ = try await client.auth.signInAnonymously() }
        do {
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            return try await client.functions.invoke("discover-places", options: FunctionInvokeOptions(body: body), decoder: decoder)
        } catch let error as FunctionsError {
            if case .httpError(let code, let data) = error {
                let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
                let errorCode = (payload["code"] as? String ?? payload["error"] as? String ?? "").lowercased()
                let retry = payload["retry_after_seconds"] as? Int
                throw Self.classifyHTTP(status: code, code: errorCode, retryAfter: retry)
            }
            throw DiscoveryServiceError.offline
        } catch is DecodingError {
            throw DiscoveryServiceError.invalidResponse
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("429") || message.contains("rate limit") { throw DiscoveryServiceError.rateLimited(retryAfter: nil) }
            if message.contains("401") || message.contains("403") || message.contains("unauthorized") { throw DiscoveryServiceError.unauthorized }
            if message.contains("disabled") { throw DiscoveryServiceError.disabled }
            if message.contains("503") || message.contains("unavailable") { throw DiscoveryServiceError.sourceUnavailable(retryAfter: nil) }
            throw DiscoveryServiceError.offline
        }
    }
    private func valid(_ city: DiscoveryCity) -> Bool {
        city.qid.range(of: #"^Q[1-9][0-9]*$"#, options: .regularExpression) != nil
            && city.latitude.isFinite && city.longitude.isFinite
            && (-90...90).contains(city.latitude) && (-180...180).contains(city.longitude)
            && city.sourceURL.absoluteString == "https://www.wikidata.org/wiki/\(city.qid)"
    }
    private func distance(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = Double.pi / 180
        let dLat = (lat2 - lat1) * r, dLon = (lon2 - lon1) * r
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * r) * cos(lat2 * r) * sin(dLon / 2) * sin(dLon / 2)
        return 6_371_000 * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
    private func send<T: Decodable, B: Encodable>(_ body: B, to url: URL, client: URLSession?) async throws -> T {
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        do {
            let (data, response) = try await (client ?? .shared).data(for: request)
            guard let http = response as? HTTPURLResponse else { throw DiscoveryServiceError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else {
                let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
                let code = (payload["code"] as? String ?? payload["error"] as? String ?? "").lowercased()
                let retry = payload["retry_after_seconds"] as? Int ?? http.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
                throw Self.classifyHTTP(status: http.statusCode, code: code, retryAfter: retry)
            }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch let error as DiscoveryServiceError { throw error }
        catch is DecodingError { throw DiscoveryServiceError.invalidResponse }
        catch { throw DiscoveryServiceError.offline }
    }

    static func classifyHTTP(status: Int, code: String = "", retryAfter: Int? = nil) -> DiscoveryServiceError {
        if code.contains("disabled") { return .disabled }
        if code.contains("unauthorized") { return .unauthorized }
        if code.contains("rate_limited") || status == 429 { return .rateLimited(retryAfter: retryAfter) }
        if status == 401 || status == 403 { return .unauthorized }
        if status == 400 || status == 422 { return .invalidRequest }
        return .sourceUnavailable(retryAfter: retryAfter)
    }
}
