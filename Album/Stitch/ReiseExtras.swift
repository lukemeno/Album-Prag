import SwiftUI

/// Reisezeitraum und „heute“. In Debug-Builds lässt sich heute per `ALBUM_TODAY=2026-10-05` festlegen.
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

    /// „Sonntag, 4. Oktober“ – Überschrift eines Reisetags.
    static func dayTitle(_ day: Int) -> String {
        date(day).formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_DE")))
    }

    /// „So“ – Wochentag in zwei Zeichen für die Tagesleiste.
    static func weekdayShort(_ day: Int) -> String {
        date(day).formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "de_DE")))
    }

    static func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day))!
    }

    static let key: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

/// Die sechs Reisetage als Leiste: Wochentag, Datum und ein Punkt, wenn für den Tag etwas geplant ist.
/// Der gewählte Tag ist gefüllt, „heute“ trägt zusätzlich einen Rahmen.
struct DayStrip: View {
    let selected: Int
    let today: Int?
    /// Anzahl geplanter Orte je Tag.
    var counts: [Int: Int] = [:]
    var onSelect: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .headline) private var dayHeight = Stitch.Size.touch + Stitch.Space.xs

    var body: some View {
        HStack(spacing: Stitch.Space.xs) {
            ForEach(DayPlanGenerator.days, id: \.self) { day in
                let isSelected = day == selected
                Button {
                    withAnimation(Stitch.Motion.maybe(reduceMotion, .easeOut(duration: Stitch.Motion.quick))) { onSelect(day) }
                } label: {
                    VStack(spacing: Stitch.Space.xxs) {
                        Text(TripDates.weekdayShort(day))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? Stitch.onAccent.opacity(0.85) : Stitch.inkSoft)
                        Text("\(day).")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(isSelected ? Stitch.onAccent : Stitch.ink)
                        Circle()
                            .fill(isSelected ? Stitch.onAccent.opacity(0.9) : Stitch.red)
                            .frame(width: 4, height: 4)
                            .opacity((counts[day] ?? 0) > 0 ? 1 : 0)
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .frame(height: dayHeight)
                    .background(isSelected ? Stitch.redFill : Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous)
                            .strokeBorder(day == today && !isSelected ? Stitch.red : (isSelected ? Color.clear : Stitch.rule),
                                          lineWidth: day == today && !isSelected ? 1.5 : 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(TripDates.dayTitle(day) + (day == today ? ", heute" : ""))
                .accessibilityValue(planLabel(counts[day] ?? 0))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func planLabel(_ count: Int) -> String {
        switch count {
        case 0: "nichts geplant"
        case 1: "1 Ort geplant"
        default: "\(count) Orte geplant"
        }
    }
}

/// Was an einem Tag ansteht: Flüge als Ticketkarte, danach die Orte in geplanter Reihenfolge.
/// Jede Zeile führt zum Ort, daneben steht der Fußweg.
struct DayPlanRows: View {
    let day: Int
    let places: [Place]
    let root: URL
    var flights: [FlightLeg] = []
    var onSelect: (Place) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            ForEach(flights) { FlightCard(flight: $0) }
            if places.isEmpty && flights.isEmpty {
                Text("Für diesen Tag ist noch nichts geplant. In der Karte kannst du Orten einen Tag geben.")
                    .font(.subheadline).foregroundStyle(Stitch.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .stitchCard()
            }
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                HStack(spacing: Stitch.Space.s) {
                    AlbumPlaceRow(title: place.title, meta: place.category, asset: place.image, root: root,
                                  index: index + 1, visited: place.visited) { onSelect(place) }
                    if place.coordinate != nil {
                        Button { openWalkingRoute(to: place) } label: { Image(systemName: "figure.walk") }
                            .buttonStyle(HeaderIconButton())
                            .accessibilityLabel("Route zu \(place.title)")
                    }
                }
                .stitchCard()
            }
        }
    }
}
