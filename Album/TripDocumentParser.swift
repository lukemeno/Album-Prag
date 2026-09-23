import Foundation

/// Liest Flüge, Hotel und Buchungsdaten aus dem Text von Reiseunterlagen.
/// Läuft komplett auf dem Gerät. Geburtsdaten und Ausweisnummern werden bewusst nicht übernommen.
struct ExtractedTrip: Equatable, Identifiable {
    let id = UUID()
    var flights: [FlightLeg] = []
    var hotel = HotelDetails()
    var bookingNumber: String?
    var travelers: [String] = []
    var notes: [String] = []

    var isEmpty: Bool {
        flights.isEmpty && hotel.name == nil && hotel.address == nil && bookingNumber == nil && travelers.isEmpty
    }

    /// Überträgt das Gelesene in die Reisedaten. Frei eingetragene Notizen bleiben erhalten.
    func applied(to trip: TripInfo) -> TripInfo {
        var trip = trip
        if !flights.isEmpty { trip.flights = flights }
        if let outbound = flights.first(where: { $0.direction == .outbound }) ?? flights.first {
            trip.flightNumber = outbound.number
            trip.outbound = outbound.departure
            trip.arrival = outbound.arrival
            trip.route = outbound.route
        }
        if hotel != HotelDetails() {
            trip.hotelDetails = hotel
            if let name = hotel.name { trip.hotel = name }
        }
        if let bookingNumber { trip.bookingNumber = bookingNumber }
        if !travelers.isEmpty { trip.travelers = travelers }
        for note in notes where !trip.notes.contains(note) {
            trip.notes = trip.notes.isEmpty ? note : trip.notes + "\n" + note
        }
        return trip
    }
}

enum TripDocumentParser {
    static func parse(_ raw: String) -> ExtractedTrip {
        let text = normalize(raw)
        var result = ExtractedTrip()
        result.flights = flights(in: text)
        result.hotel = hotel(in: text)
        result.bookingNumber = firstMatch(#"(?m)^\s*(\d{6,}[A-Z]{2,6})\s*$"#, in: text)
        result.travelers = travelers(in: text)
        if let tax = firstLine(containing: ["Tourismusabgabe", "Kurtaxe", "City Tax"], in: text) {
            result.notes.append(tax)
        }
        let compact = text.replacingOccurrences(of: " ", with: "").lowercased()
        if compact.contains("check-inerforderlich") || compact.contains("obligatorischercheck-in") {
            let window = groups(#"zwischen\s+(\d+)\s*Stunden\s+und\s+(\d+)\s*Stunden\s+vor"#, in: text)
            let hint = window.map { " – zwischen \($0[0]) und \($0[1]) Stunden vor Abflug" } ?? ""
            result.notes.append("Online-Check-in ist Pflicht\(hint).")
        }
        return result
    }

    // MARK: - Text säubern

    /// PDF-Text ist oft zerstückelt: „15:5 5“, „200 1“, „Buchungsref erenz“.
    static func normalize(_ text: String) -> String {
        var s = text.replacingOccurrences(of: "\u{00A0}", with: " ")
        s = s.replacingOccurrences(of: "ﬂ", with: "fl").replacingOccurrences(of: "ﬁ", with: "fi")
        s = replace(#"(\d{1,2}):(\d) (\d)\b"#, in: s, with: "$1:$2$3")          // 15:5 5 → 15:55
        s = replace(#"(\d{2}/\d{2}/)(\d{2,3}) (\d{1,2})\b"#, in: s, with: "$1$2$3") // 22/06/200 1 → 22/06/2001
        s = replace(#"(\d{2}/\d{2}/) (\d{4})"#, in: s, with: "$1$2")             // 11/08/ 1998
        s = replace(#"[ \t]+"#, in: s, with: " ")
        return s
    }

    // MARK: - Flüge

    private static let airports: [String: String] = [
        "KÖLN": "Köln", "COLOGNE": "Köln", "PRAG": "Prag", "PRAGUE": "Prag", "BERLIN": "Berlin", "MÜNCHEN": "München",
        "MUNICH": "München", "FRANKFURT": "Frankfurt", "HAMBURG": "Hamburg", "DÜSSELDORF": "Düsseldorf", "STUTTGART": "Stuttgart"
    ]

    static func flights(in text: String) -> [FlightLeg] {
        // Jede Flugnummer, auf die Datum und Uhrzeiten folgen, ist ein Flug.
        let pattern = #"\b([A-Z]{2}|[A-Z]\d|\d[A-Z]) ?(\d{2,4})\b(?=[^\n]*\b(?:Class|Klasse|Economy|Business)\b|[\s\S]{0,400}?\d{2}/\d{2}/\d{4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        var legs: [FlightLeg] = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let number = ns.substring(with: match.range(at: 1)) + ns.substring(with: match.range(at: 2))
            guard !legs.contains(where: { $0.number == number }) else { continue }
            let before = ns.substring(to: match.range.location)
            let after = ns.substring(from: match.range.location + match.range.length)
            guard let times = flightTimes(in: String(after.prefix(400))) else { continue }
            let (from, to) = route(in: String(before.suffix(500)))
            let section = String(before.suffix(1500))
            let isReturn = section.range(of: "Rück", options: [.caseInsensitive, .backwards]).map { r in
                section.range(of: "Hin", options: [.caseInsensitive, .backwards]).map { r.lowerBound > $0.lowerBound } ?? true
            } ?? false
            let airline = firstMatch(#"\b([A-Z][A-Z ]{3,})\s*$"#, in: String(before.suffix(60)).trimmingCharacters(in: .whitespacesAndNewlines))
            legs.append(FlightLeg(
                direction: isReturn ? .inbound : (legs.isEmpty ? .outbound : .inbound),
                number: number,
                airline: airline.map(prettyName),
                from: from ?? "Abflug", to: to ?? "Ziel",
                date: times.date, departure: times.departure, arrival: times.arrival,
                arriveBy: times.arriveBy,
                bookingCode: bookingCode(in: section)
            ))
        }
        return legs
    }

    private static func flightTimes(in text: String) -> (date: String, departure: String, arrival: String, arriveBy: String?)? {
        let date = #"(\d{2})/(\d{2})/(\d{4})"#
        // Einfindungszeit · Abflug · Ankunft, wie in „04/10/2026 12:45 04/10/2026 - 14:45 04/10/2026 - 15:55“
        let full = date + #"\s+(\d{1,2}:\d{2})\s+"# + date + #"\s*-\s*(\d{1,2}:\d{2})\s+"# + date + #"\s*-\s*(\d{1,2}:\d{2})"#
        if let m = groups(full, in: text), m.count == 12 {
            return ("\(m[4]).\(m[5]).\(m[6])", m[7], m[11], m[3])
        }
        // Nur Abflug und Ankunft
        let short = date + #"\s*-?\s*(\d{1,2}:\d{2})[\s\S]{0,40}?"# + date + #"\s*-?\s*(\d{1,2}:\d{2})"#
        if let m = groups(short, in: text), m.count == 8 {
            return ("\(m[0]).\(m[1]).\(m[2])", m[3], m[7], nil)
        }
        return nil
    }

    private static func route(in text: String) -> (String?, String?) {
        // Nach „Details“ stehen Abflug- und Zielort in Großbuchstaben untereinander.
        let block = text.components(separatedBy: "Details").last ?? text
        let cities = block.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { line -> String? in
                let key = line.uppercased()
                return airports[key] ?? (line == key && line.count >= 3 && line.count <= 20 && !line.contains(where: \.isNumber) && !line.contains("BUCHUNG") ? prettyName(line) : nil)
            }
        return (cities.first, cities.dropFirst().first)
    }

    private static func bookingCode(in text: String) -> String? {
        firstMatch(#"Buchungs\s*(?:ref\s*erenz|code|nummer)[^:\n]{0,20}:\s*([A-Z0-9]{5,8})\b"#, in: text)
            ?? firstMatch(#"\b([A-Z0-9]{6})\s+(?:EUROWINGS|LUFTHANSA|RYANAIR|EASYJET|CONDOR)\b"#, in: text)
    }

    // MARK: - Hotel, Reisende

    static func hotel(in text: String) -> HotelDetails {
        var hotel = HotelDetails()
        if let line = firstMatch(#"(?m)^\s*(Hotel [^\n]{3,60}?)\s*(?:\d\*)?\s*$"#, in: text) {
            hotel.name = line.replacingOccurrences(of: "Créme", with: "Crème").trimmingCharacters(in: .whitespaces)
        }
        // Adresse: erste Zeile mit Hausnummer und Postleitzahl nach dem Aufenthaltszeitraum im Hotelabschnitt.
        let hotelSection = text.range(of: "\nHotel\n").map { String(text[$0.upperBound...]) } ?? text
        hotel.address = firstMatch(#"(?m)^\s*([^\n\d]{3,40}\s\d{1,4}[a-z]?,[^\n]{3,80}\d{3}\s?\d{2})\s*$"#, in: hotelSection)
        hotel.checkIn = firstMatch(#"Check-in:\s*(\d{1,2}:\d{2})"#, in: text)
        hotel.checkOut = firstMatch(#"Check-out:\s*(\d{1,2}:\d{2})"#, in: text)
        if let block = firstMatch(#"Beinhaltet\s*:\s*\n([\s\S]*?)\n\s*Beinhaltet nicht"#, in: text) {
            hotel.included = block.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " -•")) }
                .filter { !$0.isEmpty }
        }
        return hotel
    }

    static func travelers(in text: String) -> [String] {
        let pattern = #"\b(?:Herr|Frau)\s+([A-ZÄÖÜ][A-ZÄÖÜ\-]+)\s+([A-ZÄÖÜ][a-zäöüß\-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        var names: [String] = []
        for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let name = ns.substring(with: m.range(at: 2)) + " " + prettyName(ns.substring(with: m.range(at: 1)))
            if !names.contains(name) { names.append(name) }
        }
        return names
    }

    // MARK: - Hilfen

    /// „MEYER-NOACK“ → „Meyer-Noack“, „EUROWINGS“ → „Eurowings“
    static func prettyName(_ s: String) -> String {
        s.lowercased().split(separator: "-", omittingEmptySubsequences: false)
            .map { $0.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ") }
            .joined(separator: "-")
    }

    /// Erste Zeile mit einem der Wörter; Leerzeichen mitten im Wort („T ourismusabgabe“) stören nicht.
    private static func firstLine(containing words: [String], in text: String) -> String? {
        let compactWords = words.map { $0.replacingOccurrences(of: " ", with: "").lowercased() }
        guard let line = text.components(separatedBy: .newlines).first(where: { line in
            let compact = line.replacingOccurrences(of: " ", with: "").lowercased()
            return compactWords.contains { compact.contains($0) }
        }) else { return nil }
        return replace(#"\b([A-ZÄÖÜ]) ([a-zäöüß]{3,})"#, in: line.trimmingCharacters(in: .whitespaces), with: "$1$2")
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        groups(pattern, in: text)?.first
    }

    private static func groups(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<m.numberOfRanges).compactMap { Range(m.range(at: $0), in: text).map { String(text[$0]) } }
    }

    private static func replace(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }
}
