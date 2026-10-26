import Foundation
import CryptoKit
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
    var status: String?
    var retryAfterSeconds: Int?

    init(image: PlaceImage?, candidates: [PlaceImage]?, selectionVersion: Int?, status: String? = nil,
         retryAfterSeconds: Int? = nil) {
        self.image = image
        self.candidates = candidates
        self.selectionVersion = selectionVersion
        self.status = status
        self.retryAfterSeconds = retryAfterSeconds
    }

    enum CodingKeys: String, CodingKey {
        case image, candidates
        case selectionVersion = "selection_version"
        case status
        case retryAfterSeconds = "retry_after_seconds"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        image = try values.decodeIfPresent(PlaceImage.self, forKey: .image)
        candidates = try values.decodeIfPresent([PlaceImage].self, forKey: .candidates)
        selectionVersion = try values.decodeIfPresent(Int.self, forKey: .selectionVersion)
        status = try values.decodeIfPresent(String.self, forKey: .status)
        retryAfterSeconds = try values.decodeIfPresent(Int.self, forKey: .retryAfterSeconds)
    }

    var isCurrent: Bool { (selectionVersion ?? 0) >= PlaceImageService.ranking }
    var deferredRetryAfter: TimeInterval? {
        guard status?.lowercased() == "deferred" else { return nil }
        return TimeInterval(max(retryAfterSeconds ?? 60, 1))
    }
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
    static let ranking = 4

    enum RequestMode: String { case manual, automatic = "automatic_photo_v1" }
    enum RequestError: Error, Equatable { case retryable(retryAfter: TimeInterval?) }

    struct Request: Encodable {
        let selection_version = PlaceImageService.ranking
        let mode: String?
        let tripID: String?
        let placeID: String?
        let revision: String?
        let manual: Bool
        let title: String
        let latitude: Double
        let longitude: Double
        let category: String
        let address: String
        let region: String?
        let languageCode: String?

        enum CodingKeys: String, CodingKey {
            case selection_version, mode, title, latitude, longitude, category, address, region, manual
            case tripID = "trip_id"
            case placeID = "place_id"
            case revision
            case languageCode = "language_code"
        }
    }

    static func image(for place: Place, bundle: Bundle = .main, region: String? = nil, languageCode: String? = nil) async throws -> PlaceImage? {
        try await images(for: place, bundle: bundle, region: region, languageCode: languageCode).first
    }

    /// Das Hauptfoto und weitere Fotos für den Foto-Streifen, bestes zuerst.
    static func images(for place: Place, bundle: Bundle = .main, region: String? = nil, languageCode: String? = nil) async throws -> [PlaceImage] {
        try await search(for: place, bundle: bundle, region: region, languageCode: languageCode).automaticImages
    }

    static func search(for place: Place, bundle: Bundle = .main, region: String? = nil, languageCode: String? = nil,
                       mode: RequestMode = .manual, tripID: String? = nil, placeID: String? = nil,
                       revision: String? = nil) async throws -> PlaceImageSearchResult {
        guard let coordinate = place.coordinate,
              !place.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .init(image: nil, candidates: [], selectionVersion: ranking) }
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if let fixture = try testStoreResponse(environment: environment) {
            if let rawDelay = environment["ALBUM_IMAGE_RESPONSE_DELAY_MS"].flatMap(Int.init) {
                let delay = min(max(rawDelay, 0), 15_000)
                if delay > 0 {
                    // QA-only late-result simulation: deliberately detached from caller cancellation.
                    try await Task.detached {
                        try await Task.sleep(for: .milliseconds(delay))
                    }.value
                }
            }
            return fixture
        }
        #endif
        let client = try SupabaseConfiguration.client(bundle: bundle)
        if (try? await client.auth.session) == nil { _ = try await client.auth.signInAnonymously() }
        do {
            return try await client.functions.invoke(
                "place-photo",
                options: FunctionInvokeOptions(body: Request(
                    mode: mode == .automatic ? mode.rawValue : nil,
                    tripID: tripID,
                    placeID: placeID ?? place.id,
                    revision: revision ?? requestRevision(for: place, region: region),
                    manual: mode == .manual,
                    title: place.title,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    category: place.category,
                    address: place.address,
                    region: region,
                    languageCode: languageCode
                ))
            )
        } catch let error as FunctionsError {
            if case .httpError(let status, let data) = error, status == 429 || status == 503 {
                let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                let retry = payload?["retry_after_seconds"] as? Int
                throw RequestError.retryable(retryAfter: retry.map(TimeInterval.init))
            }
            throw error
        }
    }

    /// Encodes the exact function body for deterministic request-contract tests.
    static func requestPayload(for place: Place, mode: RequestMode = .manual, tripID: String? = nil,
                               placeID: String? = nil, revision: String? = nil, region: String? = nil,
                               languageCode: String? = nil) throws -> Data {
        guard place.coordinate != nil else { throw CocoaError(.validationMissingMandatoryProperty) }
        let coordinate = place.coordinate!
        return try JSONEncoder().encode(Request(mode: mode == .automatic ? mode.rawValue : nil, tripID: tripID, placeID: placeID ?? place.id,
                                                revision: revision ?? requestRevision(for: place, region: region), manual: mode == .manual,
                                                title: place.title, latitude: coordinate.latitude,
                                                longitude: coordinate.longitude, category: place.category,
                                                address: place.address, region: region, languageCode: languageCode))
    }

    private static func requestRevision(for place: Place, region: String?) -> String {
        let coordinate = place.coordinate.map { "\($0.latitude),\($0.longitude)" } ?? "none"
        let raw = [place.id, place.title, place.address, place.category, coordinate, region ?? ""].joined(separator: "\u{1F}")
        return SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func testStoreResponse(environment: [String: String]) throws -> PlaceImageSearchResult? {
        guard let store = environment["ALBUM_TEST_STORE"] else { return nil }
        if let encoded = environment["ALBUM_IMAGE_RESPONSE_BASE64"] {
            guard let data = Data(base64Encoded: encoded) else { throw CocoaError(.fileReadCorruptFile) }
            return try JSONDecoder().decode(PlaceImageSearchResult.self, from: data)
        }
        if let filename = environment["ALBUM_IMAGE_RESPONSE"] {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(store).appendingPathComponent(filename)
            return try JSONDecoder().decode(PlaceImageSearchResult.self, from: Data(contentsOf: file))
        }
        if environment["ALBUM_LIVE_IMAGE_QA"] == "1" { return nil }
        return .init(image: nil, candidates: [], selectionVersion: ranking)
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
            if image.provider == .sourcePreview { return image.userSelected != true }
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

    /// Returns a bounded website thumbnail after MapKit has confirmed one exact venue.
    /// The optional transports keep the validation path deterministic in tests without
    /// changing the production search or network policy.
    static func sourcePreview(
        for place: Place,
        search: ((Place) async throws -> [MKMapItem])? = nil,
        preview: ((URL) async throws -> OEmbedService.Preview)? = nil,
        imageData: ((URL) async throws -> Data)? = nil,
        htmlData: ((URL) async throws -> (data: Data, url: URL))? = nil,
        allowNetworkFallback: Bool = false
    ) async -> PlaceImage? {
        guard canUseSourcePreview(for: place), place.coordinate != nil, !Task.isCancelled else { return nil }

        do {
            let items: [MKMapItem]
            if let search {
                items = try await search(place)
            } else {
                items = try await mapItems(for: place)
            }
            guard !Task.isCancelled, let website = sourcePreviewWebsite(for: place, mapItems: items) else { return nil }
            sourcePreviewTrace("website host=\(website.host ?? "")")
            let fetchedPreview: OEmbedService.Preview?
            if let preview {
                fetchedPreview = try? await preview(website)
            } else {
                fetchedPreview = try? await OEmbedService.preview(website)
            }
            guard !Task.isCancelled else { return nil }

            var selectedThumbnail: URL?
            if let fetchedPreview {
                let evidence = hasVenueEvidence(fetchedPreview, for: place, website: website)
                sourcePreviewTrace("metadata evidence=\(evidence) title=\(fetchedPreview.conciseTitle)")
                if evidence,
                   let rawThumbnail = fetchedPreview.thumbnail_url,
                   let thumbnail = sourcePreviewImageURL(rawThumbnail),
                   isUsableSourcePreviewThumbnailURL(thumbnail),
                   await isUsableSourcePreviewImageAt(thumbnail, imageData: imageData) {
                    selectedThumbnail = thumbnail
                }
            }

            if selectedThumbnail == nil {
                let html: (data: Data, url: URL)?
                if let htmlData {
                    html = try? await htmlData(website)
                } else if allowNetworkFallback || (search == nil && preview == nil && imageData == nil) {
                    // A fully injected transport set is a deterministic unit-test
                    // harness; never fall back to an unexpected network request.
                    html = try? await fetchHTMLData(website)
                } else {
                    html = nil
                }
                if let html {
                    let allowedHTML = isAllowedSourcePreviewHTMLURL(html.url, website: website)
                    sourcePreviewTrace("html response allowed=\(allowedHTML)")
                    if allowedHTML {
                        let candidates = sourcePreviewHTMLCandidates(data: html.data, baseURL: html.url, for: place)
                        sourcePreviewTrace("html candidates=\(candidates.count)")
                        for candidate in candidates {
                            if await isUsableSourcePreviewImageAt(candidate, imageData: imageData) {
                                selectedThumbnail = candidate
                                break
                            }
                        }
                    }
                }
            }
            guard !Task.isCancelled, let thumbnail = selectedThumbnail else { return nil }
            let host = (website.host ?? "").lowercased().replacingOccurrences(of: "www.", with: "")
            return PlaceImage(
                imageURL: thumbnail,
                sourceURL: website,
                credit: "Website-Vorschau · \(host)",
                provider: .sourcePreview,
                licenseName: nil,
                licenseURL: nil,
                providerPlaceID: nil,
                confidence: .suggested,
                caption: fetchedPreview?.conciseTitle ?? place.title
            )
        } catch {
            return nil
        }
    }

    private static func isUsableSourcePreviewImageAt(_ url: URL, imageData: ((URL) async throws -> Data)?) async -> Bool {
        do {
            let bytes: Data
            if let imageData {
                bytes = try await imageData(url)
            } else {
                bytes = try await fetchImageData(url)
            }
            return !Task.isCancelled && isUsableSourcePreviewImage(bytes)
        } catch {
            return false
        }
    }

    /// Whether a place may be upgraded by the website-preview pass.
    static func canUseSourcePreview(for place: Place) -> Bool {
        switch place.image {
        case nil:
            let rawSourceURL = place.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawSourceURL.isEmpty else { return true }
            guard let url = URL(string: rawSourceURL) else { return false }
            if PlaceLinkMetadata.isMapProviderURL(url) { return true }
            guard let website = normalizedSourcePreviewURL(url) else { return false }
            return hasVenueWebsiteEvidence(website, for: place)
        case .bundled:
            return true
        case .external(let image):
            return image.provider == .sourcePreview && image.userSelected != true
        case .uploaded(let image):
            return image.generatedSource != nil
        case .linkPreview(let pageURL, let thumbnailURL, _):
            guard let page = URL(string: pageURL) else { return false }
            if PlaceLinkMetadata.isMapProviderURL(page) { return true }
            guard normalizedSourcePreviewURL(page) != nil else { return false }
            guard let thumbnailURL, let thumbnail = URL(string: thumbnailURL) else { return true }
            return !isUsableSourcePreviewThumbnailURL(thumbnail)
        }
    }

    /// Pure MapKit candidate validation used by sourcePreview and its deterministic tests.
    static func sourcePreviewWebsite(for place: Place, mapItems: [MKMapItem]) -> URL? {
        guard let coordinate = place.coordinate else { return nil }
        let expectedName = normalizedSourcePreviewName(place.title)
        guard !expectedName.isEmpty else { return nil }
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let matches = mapItems.filter { item in
            guard normalizedSourcePreviewName(item.name ?? "") == expectedName,
                  let itemCoordinate = item.placemark.location?.coordinate else { return false }
            return origin.distance(from: CLLocation(latitude: itemCoordinate.latitude, longitude: itemCoordinate.longitude)) <= 250
        }
        guard matches.count == 1 else { return nil }
        let item = matches[0]
        if let rawURL = item.url {
            return normalizedSourcePreviewURL(rawURL)
        }
        guard let fallback = URL(string: place.sourceURL),
              let website = normalizedSourcePreviewURL(fallback),
              hasVenueWebsiteEvidence(website, for: place) else { return nil }
        return website
    }

    static func normalizedSourcePreviewURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw) else { return nil }
        return normalizedSourcePreviewURL(url)
    }

    static func normalizedSourcePreviewURL(_ url: URL) -> URL? {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host?.lowercased(), !host.isEmpty,
              url.user == nil, url.password == nil,
              !PlaceLinkMetadata.isMapProviderURL(url),
              !isBlockedSourcePreviewHost(host),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.scheme = "https"
        return components.url
    }

    /// Keeps the bounded image fetch small for Sanity's image CDN without
    /// rewriting arbitrary official-site URLs.
    static func sourcePreviewImageURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw) else { return nil }
        return sourcePreviewImageURL(url)
    }

    static func sourcePreviewImageURL(_ url: URL) -> URL? {
        guard let normalized = normalizedSourcePreviewURL(url) else { return nil }
        guard normalized.host?.lowercased() == "cdn.sanity.io",
              normalized.path.hasPrefix("/images/") else {
            sourcePreviewTrace("image url host=\(normalized.host ?? "") optimized=false")
            return normalized
        }
        guard var components = URLComponents(url: normalized, resolvingAgainstBaseURL: false) else { return normalized }
        var queryItems = components.queryItems ?? []
        func setQueryValue(_ name: String, _ value: String) {
            queryItems.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            queryItems.append(URLQueryItem(name: name, value: value))
        }
        setQueryValue("w", "1200")
        setQueryValue("fit", "max")
        setQueryValue("fm", "jpg")
        components.queryItems = queryItems
        let optimized = components.url ?? normalized
        sourcePreviewTrace("image url host=\(optimized.host ?? "") optimized=true")
        return optimized
    }

    static func isUsableSourcePreviewThumbnailURL(_ url: URL) -> Bool {
        guard normalizedSourcePreviewURL(url) != nil else { return false }
        let path = url.path.lowercased()
        guard !path.hasSuffix(".svg") else { return false }
        let value = "\(path)\(url.query.map { "?\($0)" } ?? "")".lowercased()
        let blockedTerms = ["logo", "icon", "favicon", "apple-touch", "staticmap", "static-map", "maptile", "menu", "sprite", "avatar"]
        return !blockedTerms.contains(where: value.contains)
    }

    static func isUsableSourcePreviewImage(_ data: Data) -> Bool {
        guard data.count <= 2_000_000, let image = UIImage(data: data) else { return false }
        let width = image.cgImage.map { $0.width } ?? Int(image.size.width * image.scale)
        let height = image.cgImage.map { $0.height } ?? Int(image.size.height * image.scale)
        return width >= 300 && height >= 180 && width > 0 && height > 0 && width <= 10_000 && height <= 10_000 && width * height <= 40_000_000
    }

    /// Returns at most three venue-specific HTML image candidates. Generic first images
    /// are intentionally ignored unless their alt/title contains the complete venue name.
    static func sourcePreviewHTMLCandidates(data: Data, baseURL: URL, for place: Place) -> [URL] {
        guard data.count <= 2_000_000, let html = String(data: data, encoding: .utf8) else { return [] }
        let venue = normalizedSourcePreviewName(place.title)
        guard !venue.isEmpty,
              let expression = try? NSRegularExpression(pattern: #"(?is)<img\b[^>]*>"#) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var seen = Set<URL>()
        var candidates: [URL] = []
        for match in expression.matches(in: html, range: range) {
            guard let tagRange = Range(match.range, in: html) else { continue }
            let tag = String(html[tagRange])
            let attributes = htmlImageAttributes(in: tag)
            let evidence = [attributes["alt"], attributes["title"]].compactMap { $0 }
                .map(normalizedSourcePreviewName)
                .contains { $0.contains(venue) }
            guard evidence else { continue }
            let rawURL = attributes["src"] ?? attributes["data-src"] ?? attributes["data-lazy-src"]
            guard let rawURL,
                  let resolved = URL(string: rawURL, relativeTo: baseURL)?.absoluteURL,
                  let normalized = sourcePreviewImageURL(resolved),
                  isUsableSourcePreviewThumbnailURL(normalized),
                  seen.insert(normalized).inserted else { continue }
            candidates.append(normalized)
            if candidates.count == 3 { break }
        }
        return candidates
    }

    private static func isAllowedSourcePreviewHTMLURL(_ url: URL, website: URL) -> Bool {
        guard let normalized = normalizedSourcePreviewURL(url),
              let normalizedWebsite = normalizedSourcePreviewURL(website),
              let host = normalized.host?.lowercased(),
              let websiteHost = normalizedWebsite.host?.lowercased() else { return false }
        let trimmedHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let trimmedWebsiteHost = websiteHost.hasPrefix("www.") ? String(websiteHost.dropFirst(4)) : websiteHost
        return trimmedHost == trimmedWebsiteHost
    }

    private static func htmlImageAttributes(in tag: String) -> [String: String] {
        guard let expression = try? NSRegularExpression(pattern: #"(?is)([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))"#) else { return [:] }
        let range = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        var attributes: [String: String] = [:]
        for match in expression.matches(in: tag, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: tag) else { continue }
            let valueRange = (2...4).compactMap { Range(match.range(at: $0), in: tag) }.first
            guard let valueRange else { continue }
            attributes[String(tag[keyRange]).lowercased()] = decodeHTMLAttribute(String(tag[valueRange]))
        }
        return attributes
    }

    private static func decodeHTMLAttribute(_ raw: String) -> String {
        raw.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#38;", with: "&")
            .replacingOccurrences(of: "&#x26;", with: "&")
            .replacingOccurrences(of: "&#X26;", with: "&")
    }

    private static func mapItems(for place: Place) async throws -> [MKMapItem] {
        guard let coordinate = place.coordinate else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = place.title.trimmingCharacters(in: .whitespacesAndNewlines)
        request.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.02)
        )
        return try await MKLocalSearch(request: request).start().mapItems
    }

    private static func hasVenueEvidence(_ preview: OEmbedService.Preview, for place: Place, website: URL) -> Bool {
        let venue = normalizedSourcePreviewName(place.title)
        let placeWords = Set(venue.split(separator: " ").map(String.init).filter { $0.count >= 3 })
        guard !placeWords.isEmpty else { return false }
        let genericWords = Set(["bar", "cafe", "café", "hotel", "restaurant", "bistro", "pub", "museum", "gallery", "park"])
        let discriminativeWords = placeWords.filter { !genericWords.contains($0) }
        guard !discriminativeWords.isEmpty else { return false }

        let metadata = [preview.conciseTitle, preview.description ?? ""].map(normalizedSourcePreviewName).joined(separator: " ")
        if metadata == venue || metadata.contains(venue) { return true }

        return hasVenueWebsiteEvidence(website, for: place)
    }

    private static func hasVenueWebsiteEvidence(_ website: URL, for place: Place) -> Bool {
        let venue = normalizedSourcePreviewName(place.title)
        let placeWords = Set(venue.split(separator: " ").map(String.init).filter { $0.count >= 3 })
        let genericWords = Set(["bar", "cafe", "café", "hotel", "restaurant", "bistro", "pub", "museum", "gallery", "park"])
        let discriminativeWords = placeWords.filter { !genericWords.contains($0) }
        guard !discriminativeWords.isEmpty else { return false }
        let siteText = normalizedSourcePreviewName("\(website.host ?? "") \(website.path)")
        let compactVenue = venue.replacingOccurrences(of: " ", with: "")
        let compactSite = siteText.replacingOccurrences(of: " ", with: "")
        if compactSite.contains(compactVenue) { return true }
        let siteWords = Set(siteText.split(separator: " ").map(String.init))
        return discriminativeWords.allSatisfy { word in
            siteWords.contains(word) || compactSite.contains(word)
        }
    }

    private static func sourcePreviewTrace(_ message: String) {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard environment["ALBUM_LIVE_SOURCE_PREVIEW_QA"] == "1"
                || environment["TEST_RUNNER_ALBUM_LIVE_SOURCE_PREVIEW_QA"] == "1" else { return }
        print("[SourcePreview] \(message)")
        #endif
    }

    private static func normalizedSourcePreviewName(_ raw: String) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics
        let separated = folded.unicodeScalars.map { allowed.contains($0) ? String($0) : " " }.joined()
        return separated.split(whereSeparator: { $0 == " " }).joined(separator: " ")
    }

    private static func isBlockedSourcePreviewHost(_ host: String) -> Bool {
        let clean = host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        guard clean != "localhost", !clean.hasSuffix(".local"), !clean.hasSuffix(".localhost"), !clean.contains(":"), !isPrivateIPv4(clean) else { return true }
        if let url = URL(string: "https://\(clean)"), PlaceLinkMetadata.isMapProviderURL(url) { return true }
        let blocked = ["google.com", "facebook.com", "instagram.com", "tiktok.com", "youtube.com", "youtu.be", "twitter.com", "x.com", "linkedin.com", "pinterest.com", "yelp.com", "goo.gl", "waze.com", "mapquest.com", "openstreetmap.org"]
        return blocked.contains { clean == $0 || clean.hasSuffix(".\($0)") }
    }

    private static func isPrivateIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, host.split(separator: ".").count == 4, parts.allSatisfy({ (0...255).contains($0) }) else { return false }
        return parts[0] == 0 || parts[0] == 10 || parts[0] == 127 || parts[0] == 169 && parts[1] == 254
            || parts[0] == 172 && (16...31).contains(parts[1]) || parts[0] == 192 && parts[1] == 168
    }

    private static func fetchHTMLData(_ url: URL) async throws -> (data: Data, url: URL) {
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("Album/1.0", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode), let finalURL = response.url else {
            throw URLError(.badServerResponse)
        }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            data.append(byte)
            if data.count > 2_000_000 { throw URLError(.dataLengthExceedsMaximum)
            }
        }
        return (data, finalURL)
    }

    private static func fetchImageData(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        request.setValue("Album/1.0", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<400).contains(http.statusCode),
              let finalURL = response.url,
              normalizedSourcePreviewURL(finalURL) != nil else { throw URLError(.badServerResponse) }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            data.append(byte)
            if data.count > 2_000_000 { throw URLError(.dataLengthExceedsMaximum)
            }
        }
        return data
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
