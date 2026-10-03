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
    static func resolve(_ candidates: [CollectionPlaceCandidate], around center: CLLocationCoordinate2D, limit: Int = 3) async -> [CollectionPlaceSuggestion] {
        let region = MKCoordinateRegion(center: center, span: .init(latitudeDelta: 0.2, longitudeDelta: 0.2))
        var resolved: [CollectionPlaceSuggestion] = []
        for candidate in candidates.prefix(limit) {
            guard !Task.isCancelled else { return resolved }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = candidate.query
            request.region = region
            guard let response = try? await MKLocalSearch(request: request).start(), !Task.isCancelled else { continue }
            guard let item = response.mapItems.first(where: { item in
                let coordinate = item.placemark.location?.coordinate ?? item.placemark.coordinate
                let distance = CLLocation(latitude: center.latitude, longitude: center.longitude).distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                guard distance < 60_000 else { return false }
                let name = item.name?.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) ?? ""
                return CollectionPlaceResolver.namesMatch(name: name, query: candidate.query)
            }), let name = item.name, !name.isEmpty else { continue }
            let coordinate = item.placemark.location?.coordinate ?? item.placemark.coordinate
            let address = item.placemark.title ?? item.placemark.thoroughfare.map { "\($0) \(item.placemark.subThoroughfare ?? "")" } ?? ""
            resolved.append(CollectionPlaceSuggestion(id: candidate.id + ":" + name, candidate: candidate, name: name, address: address, coordinate: coordinate))
        }
        return resolved
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
