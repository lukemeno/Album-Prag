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
    /// 0…1: das Kreuz, das sich bei „Dafür“ auf das Foto stickt.
    @State private var crossProgress: CGFloat = 0
    @State private var stitchTick = 0
    /// Magnet-Klick: zwei Herzhälften schnappen zusammen, wenn beide dafür sind.
    @State private var magnet: CGFloat = 0
    @State private var magnetTick = 0

    private let decisionThreshold: CGFloat = 96
    private var progress: CGFloat { min(abs(offset) / decisionThreshold, 1) }

    var body: some View {
        VStack(spacing: Stitch.Space.m) {
            if let place = store.inbox.first {
                GeometryReader { geo in
                    ZStack {
                        ForEach(Array(store.inbox.dropFirst().prefix(2).enumerated()), id: \.element.id) { index, next in
                            IdeaPolaroid(place: next, root: store.root, tackColor: Stitch.cobalt)
                                .rotationEffect(.degrees(index == 0 ? -4 : 5))
                                .offset(x: index == 0 ? -14 : 16, y: 10)
                                .scaleEffect(reduceMotion ? 0.94 : 0.94 + 0.04 * progress)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }

                        IdeaPolaroid(place: place, root: store.root, tackColor: Stitch.red, crossProgress: crossProgress)
                            .overlay(alignment: .topTrailing) {
                                Button { shouldFrank = false; editing = place } label: {
                                    Image(systemName: "pencil").font(.body.weight(.semibold))
                                }
                                .buttonStyle(HeaderIconButton())
                                .padding(Stitch.Space.l)
                                .accessibilityLabel("Idee bearbeiten")
                            }
                            .overlay { DecisionHint(direction: offset == 0 ? nil : offset > 0 ? .frank : .shelve, progress: progress) }
                            .overlay { if magnet > 0 { MagnetHearts(progress: magnet) } }
                            .offset(x: offset, y: reduceMotion ? 0 : -4 * progress)
                            .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset / 42).clamped(to: -6...6) + place.id.stableTilt))
                            .shadow(color: .black.opacity(0.12 + 0.1 * progress), radius: 10 + 8 * progress, y: 6 + 5 * progress)
                            .gesture(dragGesture(for: place))
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("Inbox-Ticket")
                            .accessibilityAction(named: "Dafür") { act(place, frank: true) }
                            .accessibilityAction(named: "Später") { act(place, frank: false) }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }

                if let line = authorLine(place) {
                    Text(line).font(.footnote.weight(.medium)).foregroundStyle(Stitch.inkSoft)
                }

                HStack(spacing: Stitch.Space.s) {
                    Button("Später") { act(place, frank: false) }.buttonStyle(StitchButton())
                    Button("Dafür") { act(place, frank: true) }.buttonStyle(StitchButton(primary: true))
                }
            } else {
                Spacer()
                StitchedSymbol(name: "heart.fill", rows: 16, cell: 5, color: Stitch.red)
                Text("Alles entschieden").font(.title2.weight(.bold)).foregroundStyle(Stitch.ink).padding(.top, Stitch.Space.xs)
                Text("Neue Links landen hier.\nBeschlossene Orte findest du auf der Karte.")
                    .font(.body).multilineTextAlignment(.center).foregroundStyle(Stitch.inkSoft)
                if !store.deferred.isEmpty {
                    Button("\(store.deferred.count) für später ansehen") { store.restoreDeferred() }
                        .buttonStyle(StitchButton()).padding(.top, Stitch.Space.xs).padding(.horizontal, Stitch.Space.xl)
                }
                Spacer()
            }
            if let lastAction {
                Button("Rückgängig", systemImage: "arrow.uturn.backward") { store.upsert(lastAction); self.lastAction = nil }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.red).frame(minHeight: Stitch.Size.touch)
                    .accessibilityLabel("Letzte Entscheidung rückgängig")
            }
        }
        .allowsHitTesting(!committing)
        .padding(.horizontal, Stitch.Space.page).padding(.bottom, Stitch.Space.s)
        .background(LinenBackground())
        .navigationTitle("Ideen")
        .sheet(item: $editing) { PlaceEditor(place: $0, frankOnSave: shouldFrank) }
        .sensoryFeedback(.impact(weight: .medium), trigger: feedback)
        .sensoryFeedback(.selection, trigger: thresholdFeedback)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: stitchTick)
        .sensoryFeedback(.success, trigger: magnetTick)
    }

    /// Nur was du nicht schon weißt: wer außer dir die Idee gesammelt hat und wer schon dafür ist.
    private func authorLine(_ place: Place) -> String? {
        let fromPartner = place.author != store.me && place.author.localizedCaseInsensitiveCompare("Wir") != .orderedSame
        let others = place.approvals.filter { $0 != store.me }
        var parts: [String] = []
        if fromPartner { parts.append("Von \(place.author)") }
        if !others.isEmpty { parts.append(ListFormatter.localizedString(byJoining: others) + (others.count == 1 ? " ist dafür" : " sind dafür")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func dragGesture(for place: Place) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                offset = rubberBanded(value.translation.width)
                let armed = abs(offset) >= decisionThreshold
                if armed && !thresholdArmed { thresholdFeedback += 1 }
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
        let changed = store.decided(place, approve: frank)
        let bothAgree = frank && store.isShared(changed)
        if reduceMotion { feedback += 1; if bothAgree { magnetTick += 1 }; store.upsert(changed); offset = 0; return }
        committing = true
        if frank {
            // Das Kreuz stickt sich in zwei Stichen auf das Foto, jeder Stich mit eigener Haptik.
            withAnimation(.easeOut(duration: 0.22)) { offset = 0; crossProgress = 0.5 } completion: {
                stitchTick += 1
                withAnimation(.easeOut(duration: 0.22)) { crossProgress = 1 } completion: {
                    stitchTick += 1
                    guard bothAgree else { fly(changed, to: 560); return }
                    // Ihr seid beide dafür: Die Herzhälften schnappen zusammen, dann fliegt die Karte.
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { magnet = 1 } completion: {
                        magnetTick += 1
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(450))
                            fly(changed, to: 560)
                        }
                    }
                }
            }
        } else {
            feedback += 1
            fly(changed, to: -560)
        }
    }

    private func fly(_ changed: Place, to target: CGFloat) {
        withAnimation(.easeIn(duration: 0.26)) { offset = target } completion: {
            store.upsert(changed)
            offset = 0
            crossProgress = 0
            magnet = 0
            committing = false
        }
    }
}

private enum InboxDecision { case shelve, frank }

/// Zwei gestickte Herzhälften, die von links und rechts zusammenschnappen.
private struct MagnetHearts: View {
    let progress: CGFloat
    var body: some View {
        ZStack {
            half(leading: true).offset(x: -90 * (1 - progress))
            half(leading: false).offset(x: 90 * (1 - progress))
        }
        .scaleEffect(0.9 + 0.1 * progress)
        .padding(.bottom, 60)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    private func half(leading: Bool) -> some View {
        StitchedSymbol(name: "heart.fill", rows: 22, cell: 4.4, color: leading ? Stitch.red : Stitch.cobalt)
            .mask(alignment: leading ? .leading : .trailing) {
                Rectangle().frame(width: 22 * 4.4 / 2 * 1.1)
            }
            .stitchElevation(.pinned)
    }
}

/// Während des Ziehens: „Dafür“ oder „Später“ erscheint auf dem Foto.
private struct DecisionHint: View {
    let direction: InboxDecision?
    let progress: CGFloat
    var body: some View {
        if let direction {
            Text(direction == .frank ? "Dafür" : "Später")
                .font(.title2.weight(.heavy))
                .foregroundStyle(direction == .frank ? Stitch.onAccent : Stitch.red)
                .padding(.horizontal, Stitch.Space.m).padding(.vertical, Stitch.Space.xs)
                .background(direction == .frank ? Stitch.redFill : Stitch.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Stitch.redFill, lineWidth: 2))
                .rotationEffect(.degrees(direction == .frank ? -8 : 8))
                .opacity(Double(progress))
                .scaleEffect(0.85 + 0.15 * progress)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: direction == .frank ? .topLeading : .topTrailing)
                .padding(Stitch.Space.xl)
                .allowsHitTesting(false)
        }
    }
}

/// Eine Idee als Polaroid, an zwei Ecken angeheftet.
struct IdeaPolaroid: View {
    let place: Place
    let root: URL
    var tackColor = Stitch.red
    var crossProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                AlbumPhoto(asset: place.image, root: root)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(160, geo.size.height - 118))
                    .overlay(alignment: .bottomTrailing) {
                        Canvas { context, size in
                            Stitch.drawCross(&context, in: CGRect(origin: .zero, size: size), color: Stitch.red, progress: crossProgress)
                        }
                        .frame(width: 64, height: 64)
                        .padding(Stitch.Space.s)
                        .opacity(crossProgress > 0 ? 1 : 0)
                        .accessibilityHidden(true)
                    }
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text(place.title.isEmpty ? "Neue Idee" : place.title)
                        .font(.title2.weight(.bold)).foregroundStyle(Stitch.ink).lineLimit(2)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: Stitch.Space.xs) {
                        Image(systemName: sourceIcon).font(.footnote.weight(.semibold))
                        Text(place.sourceURL.isEmpty ? place.category : "\(place.sourceLabel) · \(place.category)")
                            .font(.subheadline)
                    }
                    .foregroundStyle(Stitch.inkSoft)
                }
                .padding(.top, Stitch.Space.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(Stitch.Space.s)
            .background(Stitch.card)
            .overlay(alignment: .topLeading) { TackStitch(color: tackColor).offset(x: Stitch.Space.xs, y: Stitch.Space.xs) }
            .overlay(alignment: .topTrailing) { TackStitch(color: tackColor).offset(x: -Stitch.Space.xs, y: Stitch.Space.xs) }
        }
    }

    private var sourceIcon: String {
        switch place.sourceLabel {
        case "TikTok": "music.note"
        case "Instagram": "camera"
        case "Gesammelt": "square.and.pencil"
        default: "link"
        }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
