import Foundation
import CoreLocation

/// Ein Ort im Vorschlag, mit ungefährer Tageszeit und ggf. einem Öffnungshinweis.
struct PlanStop: Identifiable, Equatable {
    var place: Place
    var slot: String
    var note: String?
    var id: String { place.id }
}

/// Vorschlag für die Reise: konkrete Kalendertage und nicht eingeplante Orte.
struct DayPlanProposal: Equatable {
    var days: [TripDay: [PlanStop]]
    var leftOver: [Place]
    var calendarSnapshot: TripCalendar.Snapshot
    var sourceAlbumID: String? = nil
}

/// Verteilt beschlossene Orte auf die gültigen Reisetage. Reine Rechnung ohne Netz.
enum DayPlanGenerator {
    struct Window: Equatable {
        /// Minuten seit Mitternacht.
        var start: Int
        var end: Int
        var minutes: Int { max(0, end - start) }
    }

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

    /// Normale Zeitfenster gelten für jeden Tag. Nur datierte Flüge am jeweiligen
    /// Reisebeginn oder -ende schränken den passenden Tag ein.
    static func windows(flights: [FlightLeg], calendar: TripCalendar) -> [TripDay: Window] {
        var result = Dictionary(uniqueKeysWithValues: calendar.days.map { ($0, Window(start: 10 * 60, end: 22 * 60)) })
        guard let first = calendar.days.first, let last = calendar.days.last else { return result }

        if let outbound = flights.first(where: { $0.direction == .outbound && flightDay($0) == first }),
           let arrival = minute(outbound.arrival) {
            result[first]?.start = min(22 * 60, arrival + 90)
        }
        if let inbound = flights.first(where: { $0.direction == .inbound && flightDay($0) == last }),
           let departure = minute(inbound.departure) {
            result[last]?.end = max(0, departure - 120 - 45)
        }
        return result
    }

    /// Wochentag für Öffnungszeiten (0 = Montag), aus dem konkreten Reisedatum.
    static func weekday(_ day: TripDay, calendar tripCalendar: TripCalendar) -> Int? {
        guard let date = tripCalendar.date(for: day) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        if let identifier = tripCalendar.trip.timeZoneIdentifier, let zone = TimeZone(identifier: identifier) {
            calendar.timeZone = zone
        }
        return (calendar.component(.weekday, from: date) + 5) % 7
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
    ///   - hotel: optionaler echter Startpunkt; ohne Hotel beginnt jede Runde am ersten Ort.
    ///   - calendar: einziger Ursprung der gültigen Planungstage.
    ///   - keepAssigned: konkrete Datumszuordnungen bleiben erhalten.
    static func plan(places: [Place], hotel: CLLocationCoordinate2D?, flights: [FlightLeg] = [], calendar: TripCalendar, keepAssigned: Bool = true) -> DayPlanProposal {
        let days = calendar.days
        guard !days.isEmpty else { return DayPlanProposal(days: [:], leftOver: places.filter { $0.coordinate != nil && $0.category != "Unterkunft" }, calendarSnapshot: calendar.snapshot) }
        let windows = windows(flights: flights, calendar: calendar)
        let located = places.filter { $0.coordinate != nil && $0.category != "Unterkunft" }
        var buckets: [TripDay: [Place]] = Dictionary(uniqueKeysWithValues: days.map { ($0, []) })
        var free: [Place] = []
        var leftOver: [Place] = []
        for place in located {
            if place.day != nil && place.plannedDate == nil {
                // Ambiguous legacy values need an explicit user assignment.
                leftOver.append(place)
            } else if let assignedDate = place.plannedDate, !calendar.contains(assignedDate) {
                // Out-of-range assignments stay visible; planning never silently moves them.
                leftOver.append(place)
            } else if keepAssigned, let assignedDate = place.plannedDate {
                buckets[assignedDate, default: []].append(place)
            } else {
                free.append(place)
            }
        }

        func startPoint(for bucket: [Place]) -> CLLocationCoordinate2D? { hotel ?? bucket.compactMap(\.coordinate).first }
        func openDays(_ place: Place) -> [TripDay] {
            guard let hours = place.openingHours.flatMap(OpeningHours.init) else { return days }
            return days.filter { day in
                guard let weekday = weekday(day, calendar: calendar) else { return false }
                return hours.isOpen(weekday: weekday)
            }
        }
        free.sort {
            let (a, b) = (openDays($0).count, openDays($1).count)
            if a != b { return a < b }
            guard let hotel else { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            guard let left = $0.coordinate, let right = $1.coordinate else { return $0.id < $1.id }
            return distance(left, hotel) > distance(right, hotel)
        }

        for place in free {
            let options = openDays(place).compactMap { day -> (day: TripDay, cost: Double)? in
                guard let coordinate = place.coordinate else { return nil }
                let bucket = buckets[day, default: []]
                let origin = startPoint(for: bucket) ?? coordinate
                let window = windows[day] ?? Window(start: 10 * 60, end: 22 * 60)
                let load = estimatedMinutes(bucket, start: origin)
                let extra = visitMinutes(place) + walkingMinutes(nearest(coordinate, in: bucket, start: hotel))
                guard load + extra <= Int(Double(window.minutes) * 0.85) else { return nil }
                let meals = bucket.filter { $0.category == "Essen & Trinken" }.count
                if place.category == "Essen & Trinken" && meals >= 2 { return nil }
                let mealCost = place.category == "Essen & Trinken" ? Double(meals) * 700 : 0
                let longest = Double(windows.values.map(\.minutes).max() ?? 1)
                let nearStart = hotel.map { distance(coordinate, $0) < 1_000 } ?? bucket.isEmpty
                let area = bucket.isEmpty
                    ? newAreaCost + (nearStart ? 0 : (1 - Double(window.minutes) / longest) * 1_000)
                    : nearest(coordinate, in: bucket, start: hotel)
                let fullness = Double(load) / Double(max(window.minutes, 1))
                return (day, area + mealCost + fullness * 800)
            }
            if let best = options.min(by: { $0.cost < $1.cost }) { buckets[best.day, default: []].append(place) }
            else { leftOver.append(place) }
        }

        var result: [TripDay: [PlanStop]] = [:]
        for day in days {
            let bucket = buckets[day, default: []]
            let start = startPoint(for: bucket)
            let route = start.map { route(bucket, from: $0) } ?? []
            result[day] = timeline(route, day: day, window: windows[day] ?? Window(start: 10 * 60, end: 22 * 60), start: hotel ?? route.first?.coordinate, calendar: calendar)
        }
        return DayPlanProposal(days: result, leftOver: leftOver, calendarSnapshot: calendar.snapshot)
    }

    /// Ungefähre Tageszeit und Öffnungshinweis je Ort.
    static func timeline(_ ordered: [Place], day: TripDay, window: Window, start: CLLocationCoordinate2D?, calendar: TripCalendar) -> [PlanStop] {
        var clock = window.start
        var position = start ?? ordered.first?.coordinate
        return ordered.map { place in
            if let coordinate = place.coordinate, let current = position {
                clock += walkingMinutes(distance(current, coordinate))
                position = coordinate
            } else if let coordinate = place.coordinate {
                position = coordinate
            }
            let hours = place.openingHours.flatMap(OpeningHours.init)
            var note: String?
            if let hours {
                if let weekday = weekday(day, calendar: calendar) {
                    if !hours.isOpen(weekday: weekday) {
                        note = "an diesem Tag geschlossen"
                    } else if !hours.isOpen(weekday: weekday, at: clock) {
                        if let opens = hours.ranges(weekday: weekday).map(\.lowerBound).filter({ $0 > clock }).min(), opens - clock <= 90 {
                            clock = opens
                        } else {
                            note = "offen \(hours.summary(weekday: weekday))"
                        }
                    }
                }
            }
            defer { clock += visitMinutes(place) }
            return PlanStop(place: place, slot: slot(clock), note: note)
        }
    }

    static func route(_ places: [Place], from start: CLLocationCoordinate2D) -> [Place] {
        var remaining = places.filter { $0.coordinate != nil }
        var order: [Place] = []
        var position = start
        while !remaining.isEmpty {
            guard let index = remaining.indices.min(by: { lhs, rhs in
                guard let left = remaining[lhs].coordinate, let right = remaining[rhs].coordinate else { return lhs < rhs }
                return distance(position, left) < distance(position, right)
            }) else { break }
            let next = remaining.remove(at: index)
            guard let coordinate = next.coordinate else { continue }
            order.append(next)
            position = coordinate
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

    static func separateMeals(_ places: [Place]) -> [Place] {
        var order = places
        let isMeal = { (place: Place) in place.category == "Essen & Trinken" }
        for index in order.indices.dropFirst() where isMeal(order[index]) && isMeal(order[index - 1]) {
            guard let other = order[index...].firstIndex(where: { !isMeal($0) }) else { break }
            order.insert(order.remove(at: other), at: index)
        }
        return order
    }

    static func length(_ places: [Place], from start: CLLocationCoordinate2D) -> Double {
        var total = 0.0
        var position = start
        for place in places {
            guard let coordinate = place.coordinate else { continue }
            total += distance(position, coordinate)
            position = coordinate
        }
        return total + distance(position, start)
    }

    private static func estimatedMinutes(_ places: [Place], start: CLLocationCoordinate2D) -> Int {
        places.reduce(0) { $0 + visitMinutes($1) } + walkingMinutes(length(route(places, from: start), from: start))
    }

    private static func nearest(_ point: CLLocationCoordinate2D, in places: [Place], start: CLLocationCoordinate2D?) -> Double {
        let points = places.compactMap(\.coordinate) + (start.map { [$0] } ?? [])
        return points.map { distance(point, $0) }.min() ?? 0
    }

    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    static func flightDay(_ flight: FlightLeg) -> TripDay? {
        let raw = flight.date.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = [("dd.MM.yyyy", 10), ("yyyy-MM-dd", 10)]
        for (format, expectedLength) in formats where raw.count == expectedLength {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.isLenient = false
            formatter.dateFormat = format
            guard let date = formatter.date(from: raw), formatter.string(from: date) == raw else { continue }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .gmt
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = parts.year, let month = parts.month, let day = parts.day else { continue }
            return TripDay(year: year, month: month, day: day)
        }
        return nil
    }

    private static func minute(_ clock: String) -> Int? {
        let parts = clock.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]), (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }
}
