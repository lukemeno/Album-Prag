import Foundation

/// Reiner Kalendertag `yyyy-MM-dd` ohne Uhrzeit; einzige Planungseinheit für Orte.
struct TripDay: RawRepresentable, Hashable, Comparable, Codable, Identifiable, Sendable {
    let rawValue: String

    var id: String { rawValue }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ part in part.utf8.allSatisfy { (48...57).contains($0) } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              Self.isValid(year: year, month: month, day: day) else { return nil }
        self.rawValue = rawValue
    }

    init?(year: Int, month: Int, day: Int) {
        guard Self.isValid(year: year, month: month, day: day) else { return nil }
        self.rawValue = String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func isValid(year: Int, month: Int, day: Int) -> Bool {
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              let timeZone = TimeZone(secondsFromGMT: 0) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return false }
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        return resolved.year == year && resolved.month == month && resolved.day == day
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = TripDay(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO local calendar date")
        }
        self = value
    }

    fileprivate init(unchecked rawValue: String) { self.rawValue = rawValue }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var dayOfMonth: Int { Int(rawValue.suffix(2)) ?? 0 }

    static func < (lhs: TripDay, rhs: TripDay) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Reisezeitraum, „heute“ und Tagestitel aus den Reisedaten. In Debug-Builds lässt sich heute
/// per `ALBUM_TODAY=2026-10-05` festlegen.
struct TripCalendar {
    struct Snapshot: Equatable, Sendable {
        let startDate: TripDay?
        let endDate: TripDay?
        let timeZoneIdentifier: String
        let tripUpdatedAt: Date
    }

    let trip: TripInfo
    private let calendar: Calendar
    private let now: () -> Date

    init(trip: TripInfo, now: (() -> Date)? = nil) {
        self.trip = trip
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.timeZone = TimeZone(identifier: trip.timeZoneIdentifier ?? "") ?? .autoupdatingCurrent
        self.calendar = calendar
        if let now {
            self.now = now
        } else {
            #if DEBUG
            let testNow = Self.debugDate(calendar: calendar)
            self.now = { testNow ?? Date() }
            #else
            self.now = Date.init
            #endif
        }
    }

    var isValidRange: Bool {
        guard let startDate = trip.startDate, let endDate = trip.endDate else { return false }
        guard startDate <= endDate,
              let start = dateWithoutRange(for: startDate), let end = dateWithoutRange(for: endDate),
              let span = calendar.dateComponents([.day], from: start, to: end).day else { return false }
        return span < 3660
    }

    var snapshot: Snapshot {
        Snapshot(startDate: trip.startDate, endDate: trip.endDate,
                 timeZoneIdentifier: calendar.timeZone.identifier, tripUpdatedAt: trip.updatedAt)
    }

    /// Alle Tage eines gültigen Zeitraums von höchstens 3.660 Kalendertagen.
    var days: [TripDay] {
        guard isValidRange, let start = trip.startDate, let end = trip.endDate else { return [] }
        var result = [start]
        var current = start
        while current < end {
            guard let date = date(for: current),
                  let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { return [] }
            let next = day(from: nextDate)
            guard next > current else { return [] }
            current = next
            result.append(current)
        }
        return result
    }

    func contains(_ day: TripDay) -> Bool {
        guard isValidRange, let start = trip.startDate, let end = trip.endDate else { return false }
        return (start...end).contains(day)
    }

    var today: TripDay { day(from: now()) }

    /// Heute, falls es in den Reisezeitraum fällt.
    var todayInTrip: TripDay? { contains(today) ? today : nil }

    var phase: TripPhase? {
        guard isValidRange, let start = trip.startDate, let end = trip.endDate else { return nil }
        if today < start { return .before }
        if today > end { return .after }
        return .during
    }

    func date(for day: TripDay) -> Date? {
        dateWithoutRange(for: day)
    }

    func day(from date: Date) -> TripDay {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return TripDay(year: year, month: month, day: day) ?? TripDay(unchecked: "1970-01-01")
    }

    /// „Sonntag, 4. Oktober“ – Überschrift eines Reisetags.
    func dayTitle(_ day: TripDay) -> String {
        guard let date = date(for: day) else { return day.rawValue }
        return date.formatted(style.weekday(.wide).day().month(.wide))
    }

    /// „So“ bzw. „Sonntag“ – Wochentag für Datumsstreifen.
    func weekday(_ day: TripDay, style weekdayStyle: Date.FormatStyle.Symbol.Weekday = .abbreviated) -> String {
        guard let date = date(for: day) else { return "" }
        return date.formatted(style.weekday(weekdayStyle)).replacingOccurrences(of: ".", with: "")
    }

    /// „4. Okt“ – kurzes Datum ohne Wochentag.
    func shortDate(_ day: TripDay) -> String {
        guard let date = date(for: day) else { return day.rawValue }
        let month = date.formatted(style.month(.abbreviated)).replacingOccurrences(of: ".", with: "")
        return "\(day.dayOfMonth). \(month)"
    }

    /// „4. Oktober“ – Datum mit ausgeschriebenem Monat.
    func dayMonth(_ day: TripDay) -> String {
        guard let date = date(for: day) else { return day.rawValue }
        return "\(day.dayOfMonth). \(date.formatted(style.month(.wide)))"
    }

    /// „4.–9. Okt“ (oder ausgeschrieben „4.–9. Oktober“) für den ganzen Zeitraum; nil ohne gültige Reisedaten.
    func rangeLabel(wideMonth: Bool = false) -> String? {
        guard isValidRange, let start = trip.startDate, let end = trip.endDate,
              let startDate = date(for: start), let endDate = date(for: end) else { return nil }
        let format: (TripDay) -> String = wideMonth ? dayMonth : shortDate
        if start == end { return format(start) }
        let sameMonth = calendar.isDate(startDate, equalTo: endDate, toGranularity: .month)
        return sameMonth ? "\(start.dayOfMonth).–\(format(end))" : "\(format(start)) – \(format(end))"
    }

    var daysUntilStart: Int? {
        guard isValidRange, let start = trip.startDate, let startDate = date(for: start) else { return nil }
        let from = calendar.startOfDay(for: now())
        let to = calendar.startOfDay(for: startDate)
        return calendar.dateComponents([.day], from: from, to: to).day
    }

    private var style: Date.FormatStyle {
        Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: calendar, timeZone: calendar.timeZone)
    }

    private func dateWithoutRange(for day: TripDay) -> Date? {
        guard let year = Int(day.rawValue.prefix(4)),
              let month = Int(day.rawValue.dropFirst(5).prefix(2)),
              let dayOfMonth = Int(day.rawValue.suffix(2)),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth)) else { return nil }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
    }

    #if DEBUG
    private static func debugDate(calendar: Calendar) -> Date? {
        guard let rawDate = ProcessInfo.processInfo.environment["ALBUM_TODAY"], let day = TripDay(rawValue: rawDate),
              let year = Int(day.rawValue.prefix(4)), let month = Int(day.rawValue.dropFirst(5).prefix(2)),
              let dayOfMonth = Int(day.rawValue.suffix(2)),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth)) else { return nil }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
    }
    #endif
}
