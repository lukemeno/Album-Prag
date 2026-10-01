import SwiftUI

/// Ein Flug als Ticket. Tippen lässt es an Ort und Stelle zur Bordkarte aufwachsen: erst die Hülle mit weichem
/// Überschwingen, nach 150 ms der Inhalt. Schließen kehrt um und ist jederzeit unterbrechbar.
struct FlightTicket: View {
    let leg: FlightLeg
    /// Alle Flüge, damit die Bordkarte den Rückweg nennen kann.
    var legs: [FlightLeg] = []
    var openDocuments: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var stubWidth: CGFloat = 84
    @State private var open = false
    @State private var showsPass = false
    @State private var toggles = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsPass { pass.transition(.opacity) } else { closed.transition(.opacity) }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Stitch.card)
        .clipShape(TicketShape(stub: open ? 0 : stubWidth, notch: open ? 0 : 8, radius: open ? Stitch.Radius.card : Stitch.Radius.thumb))
        .stitchElevation(open ? .floating : .pinned)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .sensoryFeedback(.impact(weight: .light), trigger: toggles)
        .accessibilityElement(children: showsPass ? .contain : .ignore)
        .accessibilityLabel(showsPass ? "Bordkarte \(leg.number)" : "\(direction), \(leg.number), \(leg.from) nach \(leg.to), \(leg.date), \(leg.departure)")
        .accessibilityHint(showsPass ? "" : "Öffnet die Bordkarte")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("Flug-Ticket")
    }

    private var direction: String { leg.direction == .outbound ? "Hinflug" : "Rückflug" }

    private var closed: some View {
        HStack(spacing: 0) {
            HStack(spacing: Stitch.Space.s) {
                Image(systemName: "airplane").font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
                    .rotationEffect(.degrees(leg.direction == .outbound ? -30 : 30))
                    .frame(width: 36, height: 36).background(Stitch.Mat.sky, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(leg.from) → \(leg.to)").font(Stitch.Face.code(.headline)).foregroundStyle(Stitch.ink)
                    Text("\(direction) · \(shortDate) · \(leg.departure)").font(.footnote.monospacedDigit()).foregroundStyle(Stitch.inkSoft)
                }
                Spacer(minLength: 0)
            }
            .padding(Stitch.Space.s)
            Text(leg.number).font(Stitch.Face.ticket).foregroundStyle(Stitch.ink)
                .frame(width: stubWidth).frame(maxHeight: .infinity)
                .background(Stitch.paperDeep)
        }
        .frame(minHeight: 68)
    }

    private var shortDate: String {
        let parts = leg.date.split(separator: ".")
        guard parts.count >= 2, let day = Int(parts[0]) else { return leg.date }
        return "\(day). Okt"
    }

    private var pass: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.m) {
            HStack {
                Text(direction).font(.footnote.weight(.semibold)).foregroundStyle(Stitch.red)
                Spacer()
                Text(leg.date).font(Stitch.Face.ticket).foregroundStyle(Stitch.inkSoft)
            }
            HStack(alignment: .firstTextBaseline) {
                time(leg.departure, leg.from, .leading)
                Spacer()
                Image(systemName: "airplane").font(.title3).foregroundStyle(Stitch.red)
                Spacer()
                time(leg.arrival, leg.to, .trailing)
            }
            PerforationLine()
            HStack(alignment: .top, spacing: Stitch.Space.l) {
                fact("Flug", [leg.airline, leg.number].compactMap { $0 }.joined(separator: " "))
                if let arriveBy = leg.arriveBy { fact("Am Flughafen", "ab \(arriveBy)") }
                if let code = leg.bookingCode { fact("Buchung", code) }
            }
            if let back = legs.first(where: { $0.direction != leg.direction }) {
                Text("\(back.direction == .inbound ? "Rückflug" : "Hinflug") \(back.date.prefix(6)) · \(back.departure) \(back.from) → \(back.to)")
                    .font(.footnote.monospacedDigit()).foregroundStyle(Stitch.inkSoft)
            }
            HStack {
                Button("Unterlagen öffnen", action: openDocuments).buttonStyle(TextActionButton())
                Spacer()
                Button { toggle() } label: { Image(systemName: "chevron.up") }
                    .buttonStyle(HeaderIconButton()).accessibilityLabel("Bordkarte schließen")
            }
        }
        .padding(Stitch.Space.m)
    }

    private func toggle() {
        toggles += 1
        let opening = !open
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { open = opening; showsPass = opening }
            return
        }
        if opening {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { open = true }
            withAnimation(.easeOut(duration: 0.2).delay(0.15)) { showsPass = true }
        } else {
            withAnimation(.easeIn(duration: 0.12)) { showsPass = false }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85).delay(0.05)) { open = false }
        }
    }

    private func time(_ value: String, _ place: String, _ alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Stitch.Space.xxs) {
            Text(value).font(Stitch.Face.display(36, relativeTo: .largeTitle)).monospacedDigit().foregroundStyle(Stitch.ink)
            Text(place).font(Stitch.Face.code(.subheadline)).foregroundStyle(Stitch.ink)
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
            Text(value).font(Stitch.Face.code(.subheadline)).foregroundStyle(Stitch.ink).textSelection(.enabled)
        }
    }
}
