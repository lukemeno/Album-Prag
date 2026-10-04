import SwiftUI

/// Reisezeitraum und „heute“. In Debug-Builds lässt sich heute per `ALBUM_TODAY=2026-10-05` festlegen.
enum TripPhase: Equatable {
    case before
    case during
    case after
}

enum TripDates {
    static let calendar = Calendar(identifier: .gregorian)
    static let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4))!
    static let end = calendar.date(from: DateComponents(year: 2026, month: 10, day: 9))!

    static var today: Date {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["ALBUM_TODAY"], let date = key.date(from: raw) { return date }
        #endif
        return calendar.startOfDay(for: Date())
    }

    /// Tage bis zur Abreise; 0 am Abreisetag, negativ danach.
    static func daysUntilStart(from date: Date = today) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: start).day ?? 0
    }

    /// Tag im Oktober (4…9), wenn das Datum in die Reise fällt.
    static func tripDay(on date: Date = today) -> Int? {
        let day = calendar.startOfDay(for: date)
        guard day >= start, day <= end else { return nil }
        return calendar.component(.day, from: day)
    }

    /// Dieselbe Reise hat drei Zustände: planen, unterwegs sein und erinnern.
    static func phase(on date: Date = today) -> TripPhase {
        let day = calendar.startOfDay(for: date)
        if day < start { return .before }
        if day > end { return .after }
        return .during
    }

    /// „Sonntag, 4. Oktober“ – Überschrift eines Reisetags.
    static func dayTitle(_ day: Int) -> String {
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: day))!
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_DE")))
    }

    static let key: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
