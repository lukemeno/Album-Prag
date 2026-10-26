import Foundation
import CoreLocation
import MapKit
import NaturalLanguage

struct CollectionPlaceCandidate: Identifiable, Equatable {
    let id: String
    let query: String
    let context: String
}

struct CollectionPlaceSuggestion: Identifiable, Equatable {
    let id: String
    let candidate: CollectionPlaceCandidate
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: CollectionPlaceSuggestion, rhs: CollectionPlaceSuggestion) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.address == rhs.address
    }
}

enum CollectionPlaceExtractor {
    private static let broadPlaceNames: Set<String> = [
        "prag", "prague", "praha", "tschechien", "czech republic", "europe", "europa",
        "city", "stadt", "urlaub", "reise", "travel", "trip", "weekend", "vacation",
        "mein", "ausführliches", "fazit", "eintritt", "social", "media", "totally"
    ]

    static func candidates(title: String?, caption: String?, comments: [String]) -> [CollectionPlaceCandidate] {
        let sources = [caption, title].compactMap { $0 } + comments
        var values: [(String, String)] = []
        for text in sources {
            let cleaned = clean(text)
            guard !cleaned.isEmpty else { continue }
            values.append(contentsOf: labelledCandidates(in: cleaned))
            values.append(contentsOf: addressCandidates(in: cleaned))
            values.append(contentsOf: namedCandidates(in: cleaned))
        }
        var seen = Set<String>()
        let unique: [CollectionPlaceCandidate] = values.compactMap { raw, context in
            let query = normalize(raw)
            guard isPlausible(query), seen.insert(query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)).inserted else { return nil }
            return CollectionPlaceCandidate(id: query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current), query: query, context: context)
        }
        return Array(unique.prefix(12))
    }

    private static func clean(_ value: String) -> String {
        value.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"https?://\S+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"#[\p{L}\p{N}_-]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[\p{So}\uFE0F•]"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\u{00a0}", with: " ")
    }

    private static func labelledCandidates(in text: String) -> [(String, String)] {
        let pieces = text.components(separatedBy: CharacterSet(charactersIn: "\n;|"))
        return pieces.flatMap { piece -> [(String, String)] in
            let segments = piece.components(separatedBy: ":")
            guard segments.count > 1 else { return [] }
            let candidate = segments[0].replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"^[\-–—•\d.) ]+"#, with: "", options: .regularExpression)
            return isPlausible(candidate) ? [(candidate, piece.trimmingCharacters(in: .whitespacesAndNewlines))] : []
        }
    }

    private static func addressCandidates(in text: String) -> [(String, String)] {
        guard let expression = try? NSRegularExpression(pattern: #"(?iu)\b([\p{L}][\p{L}.'’ -]{2,55}\s+\d{1,4}[a-z]?)\b"#) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard let valueRange = Range(match.range(at: 1), in: text) else { return nil }
            let value = String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return isPlausible(value) ? (value, value) : nil
        }
    }

    private static func namedCandidates(in text: String) -> [(String, String)] {
        var result: [(String, String)] = []
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let full = text.startIndex..<text.endIndex
        tagger.enumerateTags(in: full, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, tokenRange in
            guard tag == .placeName || tag == .organizationName else { return true }
            let value = String(text[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if isPlausible(value) { result.append((value, value)) }
            return true
        }
        // Name tagging is intentionally only one token wide on some locales. Pair
        // adjacent title-case words to retain landmarks such as “Dancing House”.
        let words = text.split(whereSeparator: { $0.isWhitespace || ".,;!?()[]{}".contains($0) }).map(String.init)
        for index in 0..<(max(0, words.count - 1)) {
            let pair = "\(words[index]) \(words[index + 1])"
            if isTitleCase(words[index]), isTitleCase(words[index + 1]), isPlausible(pair) { result.append((pair, pair)) }
        }
        return result
    }

    private static func isTitleCase(_ word: String) -> Bool {
        guard let first = word.first else { return false }
        return first.isUppercase && word.dropFirst().contains(where: { $0.isLetter })
    }

    private static func normalize(_ value: String) -> String {
        value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private static func isPlausible(_ value: String) -> Bool {
        let normalized = normalize(value)
        guard normalized.count >= 3, normalized.count <= 80 else { return false }
        let lower = normalized.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard !broadPlaceNames.contains(lower), !lower.hasPrefix("http") else { return false }
        guard normalized.rangeOfCharacter(from: .letters) != nil else { return false }
        let words = normalized.split(separator: " ")
        if let first = lower.split(separator: " ").first, broadPlaceNames.contains(String(first)) { return false }
        if ["meine unterkunft", "offis fahren", "baumstriezel probieren", "typisch tschechische", "touri bootsfahrt", "aber", "definitiv", "trotzdem"].contains(where: { lower.hasPrefix($0) }) { return false }
        return words.count >= 2 || normalized.contains("-") || words.first?.first?.isUppercase == true
    }
}

enum CollectionPlaceResolver {
    static func resolve(_ candidates: [CollectionPlaceCandidate], context: TripRegionContext, limit: Int = 3) async -> [CollectionPlaceSuggestion] {
        guard context.source != .none, context.region != nil || !(context.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard environment["XCTestConfigurationFilePath"] == nil && environment["ALBUM_TEST_STORE"] == nil else { return [] }
        #endif
        return await resolve(candidates, region: context.region, name: context.name, limit: limit)
    }

    static func resolve(_ candidates: [CollectionPlaceCandidate], around center: CLLocationCoordinate2D, limit: Int = 3) async -> [CollectionPlaceSuggestion] {
        let region = MKCoordinateRegion(center: center, span: .init(latitudeDelta: 0.2, longitudeDelta: 0.2))
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard environment["XCTestConfigurationFilePath"] == nil && environment["ALBUM_TEST_STORE"] == nil else { return [] }
        #endif
        return await resolve(candidates, region: region, name: nil, limit: limit)
    }

    private static func resolve(_ candidates: [CollectionPlaceCandidate], region: MKCoordinateRegion?, name: String?, limit: Int) async -> [CollectionPlaceSuggestion] {
        let destinationTokens = name.map(normalizedTokens) ?? []
        var resolved: [CollectionPlaceSuggestion] = []
        for candidate in candidates.prefix(limit) {
            guard !Task.isCancelled else { return resolved }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = [candidate.query, name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            if let region { request.region = region }
            guard let response = try? await MKLocalSearch(request: request).start(), !Task.isCancelled else { continue }
            guard let item = response.mapItems.first(where: { item in
                let coordinate = item.placemark.location?.coordinate ?? item.placemark.coordinate
                if let region {
                    let center = region.center
                    let distance = CLLocation(latitude: center.latitude, longitude: center.longitude).distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                    guard distance < 60_000 else { return false }
                }
                let title = item.name?.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) ?? ""
                guard CollectionPlaceResolver.namesMatch(name: title, query: candidate.query) else { return false }
                guard region == nil, !destinationTokens.isEmpty else { return true }
                let address = item.placemark.title ?? ""
                let addressTokens = Set(normalizedTokens(address))
                return destinationTokens.allSatisfy(addressTokens.contains)
            }), let name = item.name, !name.isEmpty else { continue }
            let coordinate = item.placemark.location?.coordinate ?? item.placemark.coordinate
            let address = item.placemark.title ?? item.placemark.thoroughfare.map { "\($0) \(item.placemark.subThoroughfare ?? "")" } ?? ""
            resolved.append(CollectionPlaceSuggestion(id: candidate.id + ":" + name, candidate: candidate, name: name, address: address, coordinate: coordinate))
        }
        return resolved
    }

    private static func normalizedTokens(_ value: String) -> [String] {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^\p{L}\p{N}]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    static func namesMatch(name: String, query: String) -> Bool {
        let normalize: (String) -> String = {
            $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .replacingOccurrences(of: #"[^\p{L}\p{N}]"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let left = normalize(name), right = normalize(query)
        guard !left.isEmpty, !right.isEmpty else { return false }
        if left == right { return true }
        let leftWords = Set(left.split(separator: " ").map(String.init))
        let rightWords = Set(right.split(separator: " ").map(String.init))
        let overlap = leftWords.intersection(rightWords)
        let generic: Set<String> = ["cafe", "café", "restaurant", "hotel", "church", "kirche", "castle", "burg", "bridge", "brücke", "house", "haus", "the", "of", "our", "st", "saint"]
        let discriminative = overlap.filter { $0.count >= 4 && !generic.contains($0) }
        if rightWords.count > 1 { return !discriminative.isEmpty }
        return !overlap.isEmpty && !generic.contains(right)
    }
}

enum PlaceResolver {
    private struct RankedCandidate {
        let candidate: PlaceResolutionCandidate
        let score: Double
        let strongNameMatch: Bool
        let trustedAddressMatch: Bool
    }

    private static let genericTokens: Set<String> = [
        "a", "an", "the", "of", "and", "at", "in", "de", "la", "le", "el", "der", "die", "das",
        "cafe", "coffee", "restaurant", "ramen", "sushi", "food", "bar", "shop", "store", "market",
        "museum", "church", "kirche", "temple", "hotel", "park", "bridge", "bruecke", "platz", "square",
        "restaurant", "gericht", "essen", "trinken", "location", "place", "spot", "cuisine"
    ]

    static func rank(
        place: Place,
        context: TripRegionContext,
        candidates: [PlaceResolutionCandidate]
    ) -> PlaceResolutionOutcome {
        let candidates = Array(candidates.prefix(5))
        guard context.source != .none else { return .needsReview(candidates, .missingContext) }
        guard !candidates.isEmpty else { return .notFound }

        let requestedTitle = normalized(place.title)
        let requestedTokens = tokens(place.title)
        let strongTokens = requestedTokens.filter { !genericTokens.contains($0) && $0.count > 1 }

        let ranked = candidates.compactMap { candidate -> RankedCandidate? in
            let title = normalized(candidate.title)
            let candidateTokens = Set(tokens(candidate.title))
            let exactTitle = title == requestedTitle
            let trustedAddressMatch = addressesMatch(place.address, candidate.address)
            let tokenNameMatch = !requestedTokens.isEmpty && requestedTokens.allSatisfy(candidateTokens.contains)
            let strongNameMatch = (exactTitle && !strongTokens.isEmpty)
                || (strongTokens.count >= 2 && strongTokens.allSatisfy(candidateTokens.contains))
                || (trustedAddressMatch && tokenNameMatch)
            guard strongNameMatch else { return nil }
            guard matchesContext(candidate, context: context) else { return nil }
            let score = (exactTitle ? 1.0 : 0.8) + (trustedAddressMatch ? 0.8 : 0) + contextScore(candidate, context: context)
            return RankedCandidate(candidate: candidate, score: score, strongNameMatch: strongNameMatch, trustedAddressMatch: trustedAddressMatch)
        }.sorted { $0.score > $1.score }

        guard let best = ranked.first else {
            return .needsReview(candidates, strongTokens.isEmpty ? .genericConcept : .weakMatch)
        }
        let hasClearMargin = ranked.count == 1 || best.score - ranked[1].score >= 0.25
        if best.trustedAddressMatch && best.strongNameMatch {
            return hasClearMargin ? .resolved(best.candidate) : .needsReview(candidates, .ambiguous)
        }
        guard !strongTokens.isEmpty,
              strongTokens.count >= 2 || normalized(best.candidate.title) == requestedTitle else {
            return .needsReview(candidates, .genericConcept)
        }
        guard best.strongNameMatch, hasClearMargin else { return .needsReview(candidates, .ambiguous) }
        return .resolved(best.candidate)
    }

    static func resolve(place: Place, context: TripRegionContext) async -> PlaceResolutionOutcome {
        guard context.source != .none else { return .needsReview([], .missingContext) }
        guard !place.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .notFound }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = [place.title, place.address, context.name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        // A named venue must resolve to a POI. Without this filter MapKit can
        // return the city itself for queries such as “Knedlín, Prag”.
        request.resultTypes = .pointOfInterest
        if let region = context.region { request.region = region }
        do {
            let response = try await MKLocalSearch(request: request).start()
            let candidates = response.mapItems.compactMap { item -> PlaceResolutionCandidate? in
                let coordinate = item.placemark.location?.coordinate ?? item.placemark.coordinate
                guard coordinate.latitude.isFinite, coordinate.longitude.isFinite,
                      (-90...90).contains(coordinate.latitude), (-180...180).contains(coordinate.longitude),
                      let title = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
                let address = item.placemark.title ?? ""
                let id = String(format: "%.6f,%.6f:%@", coordinate.latitude, coordinate.longitude, title)
                return PlaceResolutionCandidate(id: id, title: title, address: address,
                                                latitude: coordinate.latitude, longitude: coordinate.longitude,
                                                category: item.pointOfInterestCategory?.rawValue)
            }
            return rank(place: place, context: context, candidates: Array(candidates.prefix(5)))
        } catch {
            return Task.isCancelled ? .failed(retryable: false) : .failed(retryable: true)
        }
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    private static func tokens(_ value: String) -> [String] {
        normalized(value).split(separator: " ").map(String.init)
    }

    private static func addressesMatch(_ requested: String, _ candidate: String) -> Bool {
        let requested = normalized(requested)
        let candidate = normalized(candidate)
        guard !requested.isEmpty, !candidate.isEmpty else { return false }
        if requested == candidate { return true }
        let requestedTokens = Set(tokens(requested))
        let candidateTokens = Set(tokens(candidate))
        let numbers = requestedTokens.filter { $0.contains(where: \.isNumber) }
        guard !numbers.isEmpty, numbers.allSatisfy(candidateTokens.contains) else { return false }
        let streetTokens = requestedTokens.filter { !genericTokens.contains($0) && !$0.contains(where: \.isNumber) }
        return streetTokens.count >= 1 && streetTokens.allSatisfy(candidateTokens.contains)
    }

    private static func matchesContext(_ candidate: PlaceResolutionCandidate, context: TripRegionContext) -> Bool {
        let candidateText = normalized(candidate.title + " " + candidate.address)
        if let name = context.name, !name.isEmpty {
            let nameTokens = tokens(name).filter { !genericTokens.contains($0) }
            let candidateTokens = Set(tokens(candidateText))
            if !nameTokens.isEmpty && nameTokens.allSatisfy(candidateTokens.contains) { return true }
        }
        guard let region = context.region else { return false }
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let point = CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
        let latitudeRadius = max(region.span.latitudeDelta * 111_000 / 2, 30_000)
        let longitudeRadius = max(region.span.longitudeDelta * 111_000 * max(cos(region.center.latitude * .pi / 180), 0.1) / 2, 30_000)
        let radius = min(max(latitudeRadius, longitudeRadius), 150_000)
        return center.distance(from: point) <= radius
    }

    private static func contextScore(_ candidate: PlaceResolutionCandidate, context: TripRegionContext) -> Double {
        guard let region = context.region else { return 0.1 }
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let point = CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
        return max(0, 0.4 - center.distance(from: point) / 500_000)
    }
}
