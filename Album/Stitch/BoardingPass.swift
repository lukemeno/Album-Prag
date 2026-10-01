import SwiftUI

/// Die angeheftete Anreise. Tippen lässt sie an Ort und Stelle zur Bordkarte aufwachsen (Hülle zuerst, nach 150 ms der Inhalt,
/// weiches Überschwingen); Schließen kehrt um, jederzeit unterbrechbar. Ohne Flugdaten führt das Tippen direkt zu den Unterlagen.
struct FlightTicket: View {
    let trip: TripInfo
    var openDocuments: () -> Void
    var onOpen: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var closedSide: CGFloat = 152
    @ScaledMetric(relativeTo: .footnote) private var openWidth: CGFloat = 300
    @ScaledMetric(relativeTo: .footnote) private var openHeight: CGFloat = 300
    @State private var open = false
    @State private var showsPass = false
    @State private var toggles = 0

    private var legs: [FlightLeg] { trip.flights ?? [] }
    private var hasFlight: Bool { !legs.isEmpty }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PinnedTicket(trip: trip, chrome: false).opacity(showsPass ? 0 : 1)
            if showsPass { pass.transition(.opacity) }
        }
        .padding(Stitch.Space.s)
        .frame(width: open ? openWidth : closedSide, height: open ? openHeight : nil, alignment: .topLeading)
        .frame(minHeight: open ? nil : closedSide, alignment: .topLeading)
        .background(Stitch.card)
        .stitchElevation(.pinned)
        .overlay(alignment: .top) { TackStitch(color: Stitch.cobalt).offset(y: -Stitch.Space.xxs) }
        .rotationEffect(.degrees(open ? 0 : 2))
        .contentShape(Rectangle())
        .onTapGesture { hasFlight ? toggle() : openDocuments() }
        .sensoryFeedback(.impact(weight: .light), trigger: toggles)
        .accessibilityElement(children: showsPass ? .contain : .ignore)
        .accessibilityLabel(showsPass ? "Bordkarte" : (legs.first { $0.direction == .outbound }.map { "Anreise \($0.number), \($0.from) nach \($0.to)" } ?? "Reiseunterlagen öffnen"))
        .accessibilityHint(hasFlight && !showsPass ? "Öffnet die Bordkarte" : "")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("Flug-Ticket")
    }

    private func toggle() {
        toggles += 1
        let opening = !open
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { open = opening; showsPass = opening }
            if opening { onOpen() }
            return
        }
        if opening {
            // Erst wächst die Hülle mit einem weichen Überschwingen, dann blendet der Inhalt ein.
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { open = true }
            withAnimation(.easeOut(duration: 0.2).delay(0.15)) { showsPass = true }
            onOpen()
        } else {
            withAnimation(.easeIn(duration: 0.12)) { showsPass = false }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85).delay(0.05)) { open = false }
        }
    }

    private var pass: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            if let leg = legs.first(where: { $0.direction == .outbound }) ?? legs.first {
                HStack {
                    Text(leg.direction == .outbound ? "Hinflug" : "Rückflug").font(.footnote.weight(.bold)).foregroundStyle(Stitch.red)
                    Spacer()
                    Text(leg.date).font(.footnote.weight(.semibold).monospacedDigit()).foregroundStyle(Stitch.inkSoft)
                }
                HStack(alignment: .firstTextBaseline) {
                    time(leg.departure, leg.from, .leading)
                    Spacer()
                    Image(systemName: "airplane").font(.title3).foregroundStyle(Stitch.red)
                    Spacer()
                    time(leg.arrival, leg.to, .trailing)
                }
                PerforationLine()
                HStack(spacing: Stitch.Space.l) {
                    fact("Flug", [leg.airline, leg.number].compactMap { $0 }.joined(separator: " "))
                    if let arriveBy = leg.arriveBy { fact("Am Flughafen", "ab \(arriveBy)") }
                }
                if let back = legs.first(where: { $0.direction == .inbound && $0.id != leg.id }) {
                    Text("Rückflug \(back.date.prefix(6)) · \(back.departure) \(back.from) → \(back.to)")
                        .font(.footnote.monospacedDigit()).foregroundStyle(Stitch.inkSoft)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button("Reiseunterlagen", action: openDocuments)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.red).frame(minHeight: Stitch.Size.touch)
                Spacer()
                Button { toggle() } label: { Image(systemName: "xmark") }
                    .buttonStyle(HeaderIconButton()).accessibilityLabel("Bordkarte schließen")
            }
        }
    }

    private func time(_ value: String, _ place: String, _ alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Stitch.Space.xxs) {
            Text(value).font(.title.weight(.bold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(Stitch.ink)
            Text(place).font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.ink)
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
            Text(value).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(Stitch.ink)
        }
    }
}
