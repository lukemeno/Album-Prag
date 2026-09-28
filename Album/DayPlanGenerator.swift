import Foundation
import CoreLocation

/// Ein Ort im Vorschlag, mit ungefährer Tageszeit und ggf. einem Hinweis („hat dann zu“).
struct PlanStop: Identifiable, Equatable {
    var place: Place
    var slot: String
    var note: String?
    var id: String { place.id }
}

/// Vorschlag für die ganze Reise: Orte pro Tag in Reihenfolge, dazu was nicht mehr hineinpasst.
struct DayPlanProposal: Equatable {
    var days: [Int: [PlanStop]]
    var leftOver: [Place]
}

/// Verteilt beschlossene Orte auf die Reisetage: nahe Orte an denselben Tag, jeder Tag als kurze Runde ab dem Hotel,
/// nur an Tagen, an denen der Ort offen hat. Reine Rechnung ohne Netz, damit sie testbar und sofort ist.
enum DayPlanGenerator {
    struct Window: Equatable {
        /// Minuten seit Mitternacht.
        var start: Int
        var end: Int
        var minutes: Int { max(0, end - start) }
    }

    static let days = Array(4...9)
    /// Ein neuer Stadtteil „kostet“ so viel wie 1,5 km Umweg: Weiter entfernte Orte eröffnen lieber einen eigenen Tag.
    static let newAreaCost: Double = 1_500
    /// Gehen: 75 m pro Minute, Straßen sind etwa 30 % länger als die Luftlinie.
    static func walkingMinutes(_ meters: Double) -> Int { Int((meters * 1.3 / 75).rounded()) }

    static func visitMinutes(_ place: Place) -> Int {
        switch place.category {
        case "Essen & Trinken": 75
        case "Sehenswert": 60
        case "Aussicht": 30
        case "Shopping": 45
        default: 45
        }
    }

    /// Zeitfenster je Tag: Am Anreisetag erst nach der Landung, am Abreisetag nur bis zur Fahrt zum Flughafen.
    static func windows(flights: [FlightLeg]) -> [Int: Window] {
        var result = Dictionary(uniqueKeysWithValues: days.map { ($0, Window(start: 10 * 60, end: 22 * 60)) })
        let arrival = flights.first { $0.direction == .outbound }.flatMap { minute($0.arrival) }
        result[4] = Window(start: (arrival ?? 16 * 60) + 90, end: 22 * 60)
        let departure = flights.first { $0.direction == .inbound }.flatMap { minute($0.departure) }
        // Zwei Stunden vor Abflug am Flughafen, 45 Minuten Fahrt dorthin.
        result[9] = Window(start: 8 * 60 + 30, end: (departure ?? 12 * 60 + 30) - 120 - 45)
        return result
    }

    /// Wochentag (0 = Montag) eines Oktobertags 2026.
    static func weekday(_ day: Int) -> Int {
        let date = TripDates.calendar.date(from: DateComponents(year: 2026, month: 10, day: day))!
        return (TripDates.calendar.component(.weekday, from: date) + 5) % 7
    }

    static func slot(_ minute: Int) -> String {
        switch minute {
        case ..<(12 * 60): "vormittags"
        case ..<(14 * 60 + 30): "mittags"
        case ..<(18 * 60): "nachmittags"
        default: "abends"
        }
    }

    /// - Parameters:
    ///   - places: beschlossene Orte (ohne Unterkunft).
    ///   - hotel: Startpunkt jeder Runde.
    ///   - keepAssigned: Orte, die schon einem Tag zugeordnet sind, bleiben dort.
    static func plan(places: [Place], hotel: CLLocationCoordinate2D, flights: [FlightLeg] = [], keepAssigned: Bool = true) -> DayPlanProposal {
        let windows = windows(flights: flights)
        let located = places.filter { $0.coordinate != nil && $0.category != "Unterkunft" }
        var buckets: [Int: [Place]] = Dictionary(uniqueKeysWithValues: days.map { ($0, []) })
        var free: [Place] = []
        for place in located {
            if keepAssigned, let day = place.day, days.contains(day) { buckets[day]!.append(place) } else { free.append(place) }
        }

        // Wer an weniger Tagen offen hat, wird zuerst verteilt; danach die weit entfernten, weil sie Stadtteile eröffnen.
        func openDays(_ place: Place) -> [Int] {
            guard let hours = place.openingHours.flatMap(OpeningHours.init) else { return days }
            return days.filter { hours.isOpen(weekday: weekday($0)) }
        }
        free.sort {
            let (a, b) = (openDays($0).count, openDays($1).count)
            if a != b { return a < b }
            return distance($0.coordinate!, hotel) > distance($1.coordinate!, hotel)
        }

        var leftOver: [Place] = []
        for place in free {
            let options = openDays(place).compactMap { day -> (day: Int, cost: Double)? in
                let load = estimatedMinutes(buckets[day]!, hotel: hotel)
                let extra = visitMinutes(place) + walkingMinutes(nearest(place.coordinate!, in: buckets[day]!, hotel: hotel))
                guard load + extra <= Int(Double(windows[day]!.minutes) * 0.85) else { return nil }
                // Höchstens zwei Mal Essen & Trinken am Tag, und lieber verteilt als drei Cafés hintereinander.
                let meals = buckets[day]!.filter { $0.category == "Essen & Trinken" }.count
                if place.category == "Essen & Trinken" && meals >= 2 { return nil }
                let mealCost = place.category == "Essen & Trinken" ? Double(meals) * 700 : 0
                // Neue Viertel lieber an lange Tage, damit das ganze Viertel hineinpasst.
                // Ausnahme: Orte nahe am Hotel passen gut an kurze Tage (erstes Abendessen am Anreisetag).
                let longest = Double(windows.values.map(\.minutes).max() ?? 1)
                let nearHotel = distance(place.coordinate!, hotel) < 1_000
                let area = buckets[day]!.isEmpty
                    ? newAreaCost + (nearHotel ? 0 : (1 - Double(windows[day]!.minutes) / longest) * 1_000)
                    : nearest(place.coordinate!, in: buckets[day]!, hotel: nil)
                // Gleichmäßig füllen: Ein voller Tag wird etwas teurer.
                let fullness = Double(load) / Double(max(windows[day]!.minutes, 1))
                return (day, area + mealCost + fullness * 800)
            }
            if let best = options.min(by: { $0.cost < $1.cost }) { buckets[best.day]!.append(place) } else { leftOver.append(place) }
        }

        var result: [Int: [PlanStop]] = [:]
        for day in days {
            let ordered = route(buckets[day]!, from: hotel)
            var clock = windows[day]!.start
            var position = hotel
            result[day] = ordered.map { place in
                clock += walkingMinutes(distance(position, place.coordinate!))
                position = place.coordinate!
                let hours = place.openingHours.flatMap(OpeningHours.init)
                var note: String?
                if let hours {
                    let weekday = weekday(day)
                    if !hours.isOpen(weekday: weekday) {
                        note = "an diesem Tag geschlossen"
                    } else if !hours.isOpen(weekday: weekday, at: clock) {
                        // Später am Tag geöffnet? Dann dorthin warten, statt vor verschlossener Tür zu stehen.
                        if let opens = hours.ranges(weekday: weekday).map(\.lowerBound).filter({ $0 > clock }).min(), opens - clock <= 90 {
                            clock = opens
                        } else {
                            note = "offen \(hours.summary(weekday: weekday))"
                        }
                    }
                }
                defer { clock += visitMinutes(place) }
                return PlanStop(place: place, slot: slot(clock), note: note)
            }
        }
        return DayPlanProposal(days: result, leftOver: leftOver)
    }

    /// Kürzeste Runde ab dem Hotel: nächster Nachbar, danach 2-opt (Teilstrecken umdrehen, solange es kürzer wird).
    static func route(_ places: [Place], from start: CLLocationCoordinate2D) -> [Place] {
        var remaining = places
        var order: [Place] = []
        var position = start
        while !remaining.isEmpty {
            let index = remaining.indices.min { distance(position, remaining[$0].coordinate!) < distance(position, remaining[$1].coordinate!) }!
            let next = remaining.remove(at: index)
            order.append(next)
            position = next.coordinate!
        }
        guard order.count > 2 else { return separateMeals(order) }
        var improved = true
        while improved {
            improved = false
            for i in 0..<(order.count - 1) {
                for j in (i + 1)..<order.count {
                    var candidate = order
                    candidate[i...j].reverse()
                    if length(candidate, from: start) + 1 < length(order, from: start) { order = candidate; improved = true }
                }
            }
        }
        return separateMeals(order)
    }

    /// Zwei Cafés oder Restaurants direkt hintereinander: den nächsten anderen Ort dazwischenziehen.
    static func separateMeals(_ places: [Place]) -> [Place] {
        var order = places
        let isMeal = { (place: Place) in place.category == "Essen & Trinken" }
        for index in order.indices.dropFirst() where isMeal(order[index]) && isMeal(order[index - 1]) {
            guard let other = order[index...].firstIndex(where: { !isMeal($0) }) else { break }
            order.insert(order.remove(at: other), at: index)
        }
        return order
    }

    /// Weg ab dem Hotel durch alle Orte und zurück.
    static func length(_ places: [Place], from start: CLLocationCoordinate2D) -> Double {
        var total = 0.0
        var position = start
        for place in places { total += distance(position, place.coordinate!); position = place.coordinate! }
        return total + distance(position, start)
    }

    private static func estimatedMinutes(_ places: [Place], hotel: CLLocationCoordinate2D) -> Int {
        places.reduce(0) { $0 + visitMinutes($1) } + walkingMinutes(length(route(places, from: hotel), from: hotel))
    }

    private static func nearest(_ point: CLLocationCoordinate2D, in places: [Place], hotel: CLLocationCoordinate2D?) -> Double {
        let points = places.compactMap(\.coordinate) + (hotel.map { [$0] } ?? [])
        return points.map { distance(point, $0) }.min() ?? 0
    }

    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private static func minute(_ clock: String) -> Int? {
        let parts = clock.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        return hour * 60 + minute
    }
}
