import Foundation
import CoreLocation

/// Öffnungszeiten im OpenStreetMap-Format („Mo-Fr 08:00-22:00; Sa,Su 09:00-20:00“).
/// Gelesen wird nur die übliche Form. Alles Exotische (Monate, Feiertagsregeln, „sunrise“) gilt als unbekannt,
/// damit nie falsch „geschlossen“ geraten wird.
struct OpeningHours: Equatable {
    /// Minuten seit Mitternacht; Ende kann über 24:00 hinausgehen („18:00-02:00“ → 1080…1560).
    typealias Range = ClosedRange<Int>
    /// Index 0 = Montag … 6 = Sonntag.
    let week: [[Range]]

    init?(_ raw: String) {
        // „Sa, Su 10:00-19:00“ kommt in OSM oft mit Leerzeichen vor; gemeint ist „Sa,Su“.
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"(Mo|Tu|We|Th|Fr|Sa|Su),\s+(?=Mo|Tu|We|Th|Fr|Sa|Su)"#, with: "$1,", options: .regularExpression)
        guard !text.isEmpty else { return nil }
        if text == "24/7" { week = Array(repeating: [0...1440], count: 7); return }
        var week = Array(repeating: [Range](), count: 7)
        for rule in text.split(separator: ";").map({ $0.trimmingCharacters(in: .whitespaces) }) where !rule.isEmpty {
            // Feiertage kommen in der Reisewoche nicht vor.
            if rule.hasPrefix("PH") || rule.hasPrefix("SH") { continue }
            let parts = rule.split(separator: " ", maxSplits: 1).map(String.init)
            let days: [Int]
            let times: String
            if let parsed = Self.days(parts[0]) {
                days = parsed
                times = parts.count > 1 ? parts[1] : "00:00-24:00"
            } else {
                days = Array(0..<7)
                times = rule
            }
            let ranges: [Range]
            if times == "off" || times == "closed" {
                ranges = []
            } else {
                guard let parsed = Self.times(times) else { return nil }
                ranges = parsed
            }
            // Spätere Regeln überschreiben frühere für dieselben Tage.
            for day in days { week[day] = ranges }
        }
        self.week = week
    }

    func ranges(weekday: Int) -> [Range] { week[weekday] }
    func isOpen(weekday: Int) -> Bool { !week[weekday].isEmpty }
    func isOpen(weekday: Int, at minute: Int) -> Bool { week[weekday].contains { $0.contains(minute) } }

    /// „10:00–18:00“ für die Anzeige.
    func summary(weekday: Int) -> String {
        let ranges = week[weekday]
        guard !ranges.isEmpty else { return "geschlossen" }
        return ranges.map { "\(Self.clock($0.lowerBound))–\(Self.clock($0.upperBound))" }.joined(separator: ", ")
    }

    static func clock(_ minute: Int) -> String { String(format: "%02d:%02d", (minute / 60) % 24, minute % 60) }

    private static let names = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    private static func days(_ spec: String) -> [Int]? {
        var result: [Int] = []
        for piece in spec.split(separator: ",") {
            let bounds = piece.split(separator: "-").map(String.init)
            guard let first = names.firstIndex(of: bounds[0]) else { return nil }
            if bounds.count == 1 { result.append(first); continue }
            guard bounds.count == 2, let last = names.firstIndex(of: bounds[1]) else { return nil }
            var day = first
            while true { result.append(day); if day == last { break }; day = (day + 1) % 7 }
        }
        return result
    }

    private static func times(_ spec: String) -> [Range]? {
        var result: [Range] = []
        for piece in spec.split(separator: ",") {
            let bounds = piece.trimmingCharacters(in: .whitespaces).split(separator: "-").map(String.init)
            guard bounds.count == 2, let start = minute(bounds[0]), var end = minute(bounds[1]) else { return nil }
            if end <= start { end += 1440 }
            result.append(start...end)
        }
        return result
    }

    private static func minute(_ clock: String) -> Int? {
        let parts = clock.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]), (0...24).contains(hour), (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }
}

/// Holt Öffnungszeiten aus OpenStreetMap (Overpass, ohne Schlüssel).
/// Nur ein Treffer mit passendem Namen in unmittelbarer Nähe zählt; sonst bleibt es unbekannt.
enum OpeningHoursService {
    /// Ergebnis der Abfrage. `nil` heißt: Abfrage gescheitert, später noch einmal versuchen.
    /// `""` heißt: nachgesehen, aber für diesen Ort sind keine Öffnungszeiten eingetragen.
    static func fetch(for place: Place) async -> String? {
        guard let coordinate = place.coordinate else { return "" }
        let query = "[out:json][timeout:15];nwr(around:80,\(coordinate.latitude),\(coordinate.longitude))[\"opening_hours\"][\"name\"];out tags;"
        var request = URLRequest(url: URL(string: "https://overpass-api.de/api/interpreter")!, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")".data(using: .utf8)
        request.setValue("Album-Prague/1.0 (private travel app)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONDecoder().decode(Overpass.self, from: data) else { return nil }
        return bestMatch(payload.elements.map(\.tags), title: place.title) ?? ""
    }

    /// Das Element, dessen Name am besten zum Ortstitel passt.
    static func bestMatch(_ elements: [[String: String]], title: String) -> String? {
        let wanted = words(title)
        guard !wanted.isEmpty else { return nil }
        return elements
            .compactMap { tags -> (String, Double)? in
                guard let name = tags["name"], let hours = tags["opening_hours"] else { return nil }
                let found = words(name)
                let shared = Double(wanted.intersection(found).count) / Double(wanted.union(found).count)
                return shared >= 0.5 ? (hours, shared) : nil
            }
            .max { $0.1 < $1.1 }?.0
    }

    private static func words(_ value: String) -> Set<String> {
        Set(value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 2 })
    }

    private struct Overpass: Decodable {
        struct Element: Decodable { var tags: [String: String] }
        var elements: [Element]
    }
}
