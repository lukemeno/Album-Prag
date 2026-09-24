import SwiftUI
import MapKit
import RiveRuntime

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

    static let key: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

/// Abreißkalender bis Prag: pro Tag darf ein Blatt abgerissen werden.
struct TearCalendar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("album.tornDay") private var tornDay = ""
    @State private var drag: CGSize = .zero
    @State private var falling = false
    @State private var torn = 0

    private var todayKey: String { TripDates.key.string(from: TripDates.today) }
    private var days: Int { max(0, TripDates.daysUntilStart()) }
    private var tornToday: Bool { tornDay == todayKey }
    /// Vor dem Abreißen zeigt das oberste Blatt noch den gestrigen Stand.
    private var topNumber: Int { tornToday ? days : days + 1 }
    private var pull: CGFloat { min(max(drag.height, 0) / 90, 1) }

    var body: some View {
        ZStack(alignment: .top) {
            page(number: days, caption: caption(for: days))
            if !tornToday {
                page(number: topNumber, caption: caption(for: topNumber))
                    .rotationEffect(.degrees(falling ? 28 : Double(pull) * 16 + Double(drag.width) / 12), anchor: .topLeading)
                    .offset(x: falling ? 70 : drag.width * 0.3, y: falling ? 520 : max(0, drag.height) * 0.45)
                    .opacity(falling ? 0 : 1)
                    .gesture(DragGesture()
                        .onChanged { drag = $0.translation }
                        .onEnded { value in
                            if value.translation.height > 70 || value.predictedEndTranslation.height > 180 { tear() }
                            else { withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { drag = .zero } }
                        })
                    .accessibilityAction(named: "Blatt abreißen") { tear() }
            }
            binding
        }
        .frame(width: 128, height: 142)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9), trigger: torn)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Noch \(days) Tage bis Prag")
    }

    private func tear() {
        guard !tornToday else { return }
        torn += 1
        if reduceMotion { tornDay = todayKey; drag = .zero; return }
        withAnimation(.easeIn(duration: 0.55)) { falling = true } completion: {
            tornDay = todayKey
            falling = false
            drag = .zero
        }
    }

    private func caption(for number: Int) -> String {
        switch number {
        case 0: "Heute geht’s los"
        case 1: "Tag bis Prag"
        default: "Tage bis Prag"
        }
    }

    private func page(number: Int, caption: String) -> some View {
        VStack(spacing: 2) {
            Text("\(number)")
                .font(.system(size: 56, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Stitch.ink)
                .contentTransition(.numericText())
            Text(caption).font(.footnote.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
            if !tornToday && number == topNumber {
                Label("abreißen", systemImage: "arrow.down").font(.caption2.weight(.bold)).foregroundStyle(Stitch.red)
                    .padding(.top, 2)
            }
        }
        .frame(width: 128, height: 128)
        .padding(.top, 14)
        .background(Stitch.card)
        .overlay(alignment: .top) {
            Line().stroke(Stitch.ink.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2, 3])).frame(height: 1).offset(y: 16)
        }
        .shadow(color: .black.opacity(0.14), radius: 4, x: 1, y: 3)
    }

    /// Gestickte Bindung am oberen Rand.
    private var binding: some View {
        HStack(spacing: 0) {
            ForEach(0..<9, id: \.self) { _ in TackStitch(color: Stitch.red, size: 11).frame(maxWidth: .infinity) }
        }
        .frame(width: 128, height: 16)
        .background(Stitch.card)
        .allowsHitTesting(false)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path { Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: rect.width, y: 0)) } }
    }
}

/// Unterwegs: was heute ansteht, groß und mit einem Tipp zur Route.
struct TodayPlan: View {
    let day: Int
    let places: [Place]
    let root: URL
    var flights: [FlightLeg] = []
    var onSelect: (Place) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Heute").font(.title.weight(.bold)).foregroundStyle(Stitch.ink)
                Text("\(day). Oktober").font(.title3.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
            }
            ForEach(flights) { FlightCard(flight: $0) }
            if places.isEmpty && flights.isEmpty {
                Text("Für heute ist noch nichts geplant. In der Karte könnt ihr Orten einen Tag geben.")
                    .font(.body).foregroundStyle(Stitch.inkSoft)
            }
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                HStack(spacing: 14) {
                    Text("\(index + 1)").font(.headline.monospacedDigit()).foregroundStyle(Stitch.onAccent)
                        .frame(width: 30, height: 30).background(Stitch.red, in: Circle())
                    Button { onSelect(place) } label: {
                        HStack(spacing: 12) {
                            AlbumPhoto(asset: place.image, root: root).frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.title).font(.headline).foregroundStyle(Stitch.ink)
                                Text(place.category).font(.subheadline).foregroundStyle(Stitch.inkSoft)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    if let coordinate = place.coordinate {
                        Button {
                            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                            item.name = place.title
                            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                        } label: { Image(systemName: "figure.walk") }
                        .buttonStyle(HeaderIconButton())
                        .accessibilityLabel("Route zu \(place.title)")
                    }
                }
                .padding(12)
                .background(Stitch.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

/// Tram-Klingel: in Blender modelliert, in Rive mit Knochen animiert (Design/rive/tram-bell).
/// Schwingt beim Abgleichen und beim Antippen und macht „Ding“.
struct TramBell: View {
    let rings: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var rive = RiveViewModel(fileName: "tram-bell", stateMachineName: "Klingel")
    @State private var taps = 0

    var body: some View {
        rive.view()
            .frame(width: 60, height: 60)
            .contentShape(Rectangle())
            .onTapGesture { taps += 1 }
            .onChange(of: rings) { _, _ in ring() }
            .onChange(of: taps) { _, _ in ring() }
            .sensoryFeedback(.impact(weight: .light, intensity: 1), trigger: rings + taps)
            .accessibilityHidden(true)
    }

    private func ring() {
        guard !reduceMotion else { return }
        rive.triggerInput("ring")
    }
}
