import SwiftUI

struct InboxView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var editing: Place?
    @State private var shouldFrank = false
    @State private var lastAction: Place?
    @State private var feedback = 0
    @State private var thresholdFeedback = 0
    @State private var thresholdArmed = false
    @State private var committing = false

    private let decisionThreshold: CGFloat = 96
    private var progress: CGFloat { min(abs(offset) / decisionThreshold, 1) }

    var body: some View {
        VStack(spacing: 12) {
            if let place = store.inbox.first {
                GeometryReader { geo in
                    ZStack {
                        InboxDecisionStage(direction: offset == 0 ? nil : offset > 0 ? .frank : .shelve, progress: progress)

                        if let next = store.inbox.dropFirst().first {
                            InboxTicketCard(place: next, root: store.root, subtitle: "Als Nächstes")
                                .padding(.horizontal, 10)
                                .scaleEffect(reduceMotion ? 1 : 0.965 + 0.035 * progress)
                                .offset(y: reduceMotion ? 12 : 12 - 8 * progress)
                        }

                        InboxTicketCard(place: place, root: store.root, subtitle: "Ziehen, um zu entscheiden")
                            .overlay(alignment: .topTrailing) {
                                Button { shouldFrank = false; editing = place } label: {
                                    Image(systemName: "pencil")
                                        .padding(14)
                                        .background(AlbumStyle.paper, in: Circle())
                                }
                                .padding(16)
                                .accessibilityLabel("Idee bearbeiten")
                            }
                            .offset(x: offset, y: reduceMotion ? 0 : -4 * progress)
                            .scaleEffect(reduceMotion ? 1 : 1 - 0.018 * progress)
                            .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset / 42).clamped(to: -5...5)))
                            .shadow(color: .black.opacity(0.10 + 0.12 * progress), radius: 10 + 8 * progress, y: 5 + 5 * progress)
                            .gesture(dragGesture(for: place))
                            .accessibilityIdentifier("Inbox-Ticket")
                            .accessibilityAction(named: "Frankieren") { act(place, frank: true) }
                            .accessibilityAction(named: "Zurücklegen") { act(place, frank: false) }
                    }
                    .frame(height: max(220, geo.size.height - 14))
                }

                HStack(spacing: 8) {
                    Button("ZURÜCKLEGEN") { act(place, frank: false) }.buttonStyle(AlbumButton())
                    Button("FRANKIEREN") { act(place, frank: true) }.buttonStyle(AlbumButton(primary: true))
                }
            } else {
                Spacer()
                Image("imgSculpture").resizable().scaledToFit().frame(width: 140, height: 140)
                Text("Inbox ist leer").font(AlbumStyle.display(28))
                Text("Neue Ideen erscheinen hier.\nFrankierte Orte findet ihr auf der Karte.")
                    .font(AlbumStyle.body()).multilineTextAlignment(.center).foregroundStyle(AlbumStyle.muted)
                if !store.deferred.isEmpty {
                    Button("\(store.deferred.count) zurückgelegte Ideen ansehen") { store.restoreDeferred() }.buttonStyle(AlbumButton())
                }
                Spacer()
            }
            if let lastAction {
                Button("Letzte Entscheidung rückgängig") { store.upsert(lastAction); self.lastAction = nil }
                    .font(AlbumStyle.body(12)).padding(.bottom, 4)
            }
        }
        .allowsHitTesting(!committing)
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 8)
        .sheet(item: $editing) { PlaceEditor(place: $0, frankOnSave: shouldFrank) }
        .sensoryFeedback(.impact(weight: .medium), trigger: feedback)
        .sensoryFeedback(.selection, trigger: thresholdFeedback)
    }

    private func dragGesture(for place: Place) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                offset = rubberBanded(value.translation.width)
                let armed = abs(offset) >= decisionThreshold
                if armed && !thresholdArmed {
                    thresholdFeedback += 1
                }
                thresholdArmed = armed
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.width
                let decision = abs(projected) > abs(value.translation.width) ? projected : value.translation.width
                thresholdArmed = false
                if decision > decisionThreshold { act(place, frank: true) }
                else if decision < -decisionThreshold { act(place, frank: false) }
                if !committing {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.78)) { offset = 0 }
                }
            }
    }

    private func rubberBanded(_ value: CGFloat) -> CGFloat {
        let limit: CGFloat = 190
        guard abs(value) > limit else { return value }
        return value.sign == .minus ? -limit - sqrt(abs(value) - limit) * 4 : limit + sqrt(value - limit) * 4
    }

    private func act(_ place: Place, frank: Bool) {
        if frank && place.coordinate == nil { shouldFrank = true; editing = place; return }
        guard !committing else { return }
        lastAction = place
        var changed = place
        if frank { changed.franked = true; changed.deferred = false } else { changed.deferred = true }
        feedback += 1
        if reduceMotion { store.upsert(changed); offset = 0; return }
        committing = true
        withAnimation(.easeIn(duration: 0.24)) { offset = frank ? 520 : -520 } completion: {
            store.upsert(changed)
            offset = 0
            committing = false
        }
    }
}

private enum InboxDecision {
    case shelve, frank
}

private struct InboxDecisionStage: View {
    let direction: InboxDecision?
    let progress: CGFloat

    var body: some View {
        HStack {
            decision(.frank, title: "FRANKIEREN", icon: "checkmark.seal.fill")
            Spacer()
            decision(.shelve, title: "ZURÜCKLEGEN", icon: "arrow.uturn.backward.circle.fill")
        }
        .padding(.horizontal, 22)
    }

    private func decision(_ value: InboxDecision, title: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 27))
            Text(title).font(AlbumStyle.ticket)
        }
        .foregroundStyle(AlbumStyle.red)
        .opacity(direction == value ? 0.25 + 0.75 * progress : 0)
        .scaleEffect(0.9 + 0.1 * progress)
    }
}

private struct InboxTicketCard: View {
    let place: Place
    let root: URL
    let subtitle: String

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                PhotoCard(asset: place.image, root: root, title: place.title, subtitle: subtitle)
                    .frame(height: max(150, geo.size.height - 68))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                ticketStub
            }
            .background(AlbumStyle.paper)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AlbumStyle.gold.opacity(0.42), lineWidth: 0.75))
        }
    }

    private var ticketStub: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(place.category.uppercased()).font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.red)
                Text(originLabel).font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.muted)
            }
            Spacer()
            TicketBarcode(seed: place.id)
        }
        .padding(.horizontal, 18)
        .frame(height: 68)
        .background(alignment: .top) {
            PerforationLine().stroke(AlbumStyle.gold.opacity(0.7), style: .init(lineWidth: 1, dash: [4, 5]))
        }
    }

    private var originLabel: String {
        if !place.sourceURL.isEmpty { return place.sourceLabel.uppercased() }
        return place.author.localizedCaseInsensitiveCompare("Wir") == .orderedSame
            ? "VON UNS"
            : "VON \(place.author.uppercased())"
    }
}

private struct PerforationLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0.5))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0.5))
        return path
    }
}

private struct TicketBarcode: View {
    let seed: String
    private var bars: [CGFloat] {
        Array(seed.utf8.prefix(18)).enumerated().map { index, byte in CGFloat(1 + (Int(byte) + index) % 3) }
    }

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, width in
                Rectangle().fill(AlbumStyle.ink.opacity(0.78)).frame(width: width, height: 30)
            }
        }
        .accessibilityHidden(true)
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
