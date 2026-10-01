import SwiftUI

/// Wisch-Spur „Als besucht markieren“: Der Daumen zieht nach rechts, Stempelfarbe füllt die Spur, an der Schwelle rastet das Label
/// ein („Loslassen“), danach steht dort „Besucht“ (gesperrt). Zu früh losgelassen federt zurück. Tippen füllt die Spur
/// von selbst (gleichwertige Schaltfläche), VoiceOver aktiviert sie ebenso. Rückgängig geht über „Schon besucht“ im Editor.
struct VisitedTrack: View {
    var visited: Bool
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dx: CGFloat = 0
    @State private var armed = false
    @State private var tick = 0
    @ScaledMetric(relativeTo: .subheadline) private var trackHeight = Stitch.Size.button

    private let knob = Stitch.Size.button - Stitch.Space.xs
    private let inset = Stitch.Space.xxs
    /// Ab diesem Anteil des Wegs gilt die Geste als „fertig“.
    private let armAt: CGFloat = 0.85

    var body: some View {
        GeometryReader { geo in
            let travel = max(geo.size.width - knob - inset * 2, 1)
            let p: CGFloat = visited ? 1 : min(max(dx / travel, 0), 1)
            let shape = Capsule()
            ZStack(alignment: .leading) {
                shape.fill(Stitch.card)
                // Stempelfarbe füllt die Spur bis unter den Knopf.
                shape.fill(Stitch.redFill).frame(width: inset + knob + travel * p).opacity(p > 0 ? 1 : 0)
                label(p: p)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, knob + Stitch.Space.m)
                Circle().fill(Stitch.card)
                    .frame(width: knob, height: knob)
                    .overlay(Image(systemName: visited ? "checkmark" : "chevron.right.2").font(.body.weight(.bold)).foregroundStyle(Stitch.red))
                    .stitchElevation(.pinned)
                    .offset(x: inset + travel * p)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Stitch.rule, lineWidth: 1))
            .contentShape(shape)
            .gesture(reduceMotion || visited ? nil : drag(travel: travel))
            .onTapGesture { fill(travel: travel) }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.78), value: visited)
        }
        .frame(height: trackHeight)
        .sensoryFeedback(.selection, trigger: tick)
        .onChange(of: visited) { _, now in if !now { dx = 0; armed = false } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(visited ? "Besucht" : "Als besucht markieren")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if !visited { onComplete() } }
        .accessibilityIdentifier("Besucht-Spur")
    }

    private func label(p: CGFloat) -> some View {
        HStack(spacing: Stitch.Space.xs) {
            if visited { Image(systemName: "checkmark").accessibilityHidden(true) }
            Text(visited ? "Besucht" : armed ? "Loslassen" : "Als besucht markieren")
        }
        .font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(p > 0.5 ? Stitch.onAccent : Stitch.red)
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.18), value: armed)
    }

    private func drag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                dx = min(max(value.translation.width, 0), travel)
                let now = dx / travel >= armAt
                if now && !armed { tick += 1 }
                armed = now
            }
            .onEnded { value in
                if armed || value.predictedEndTranslation.width >= travel {
                    fill(travel: travel)
                } else {
                    armed = false
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) { dx = 0 }
                }
            }
    }

    /// Füllt die Spur bis zum Ende und meldet den Ort als besucht; Geste, Tippen und VoiceOver landen hier.
    private func fill(travel: CGFloat) {
        guard !visited else { return }
        tick += 1
        armed = false
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.34, dampingFraction: 0.8)) { dx = travel }
        onComplete()
    }
}

/// Poststempel „BESUCHT“, der auf dem Foto landet, wenn der Ort besucht ist.
struct VisitedStamp: View {
    var body: some View {
        Postmark(top: "PRAHA", bottom: "BESUCHT", color: Stitch.onAccent, size: 84)
            .background(Stitch.redFill.opacity(0.88), in: Circle())
            .allowsHitTesting(false)
    }
}
