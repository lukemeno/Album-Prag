import SwiftUI

struct InboxView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var editing: Place?
    @State private var shouldFrank = false
    @State private var lastAction: Place?
    @State private var lastActionWasOpen = false
    @State private var openIDs: Set<String> = []
    @State private var feedback = 0
    @State private var thresholdFeedback = 0
    @State private var thresholdArmed = false
    @State private var committing = false
    @State private var crossProgress: CGFloat = 0
    @State private var stitchTick = 0
    /// Magnet-Klick: zwei Herzhälften schnappen zusammen, wenn beide dafür sind.
    @State private var magnet: CGFloat = 0
    @State private var magnetTick = 0
    /// 1 = hintere Karten weit aufgefächert, 0 = ruhige Lage; federt beim Erscheinen des Stapels.
    @State private var fan: CGFloat = 1
    /// Oberste Karte in der Hand: 0…1 für Anheben (Größe, Schatten).
    @State private var lift: CGFloat = 0
    /// Neigung um die senkrechte Achse in Grad, aus der geglätteten Ziehgeschwindigkeit.
    @State private var tilt: Double = 0
    @State private var lastSample: (x: CGFloat, time: Date)?
    @State private var tiltDecay: Task<Void, Never>?
    @State private var viewer: PhotoViewerItem?

    private let decisionThreshold: CGFloat = 96
    private var progress: CGFloat { min(abs(offset) / decisionThreshold, 1) }

    private var undecided: [Place] { store.inbox.filter { !openIDs.contains($0.id) } }

    var body: some View {
        VStack(spacing: Stitch.Space.m) {
            if let place = undecided.first {
                GeometryReader { geo in
                    ZStack {
                        ForEach(Array(undecided.dropFirst().prefix(2).enumerated()), id: \.element.id) { index, next in
                            let spread = reduceMotion ? 0 : fan
                            IdeaPolaroid(place: next, root: store.root, tackColor: Stitch.cobalt)
                                .rotationEffect(.degrees((index == 0 ? -4 : 5) + (index == 0 ? -6 : 6) * spread))
                                .offset(x: (index == 0 ? -14 : 16) + (index == 0 ? -18 : 20) * spread, y: 10 - 4 * spread)
                                .scaleEffect(reduceMotion ? 0.94 : 0.94 + 0.04 * progress)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }

                        IdeaPolaroid(place: place, root: store.root, tackColor: Stitch.red, crossProgress: crossProgress,
                                     onPhotoTap: { openPhoto(place, from: $0) })
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
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : tilt), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                            .scaleEffect(reduceMotion ? 1 : 1 + 0.05 * lift)
                            .offset(x: offset, y: reduceMotion ? 0 : -4 * progress)
                            .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset / 42).clamped(to: -6...6) + place.id.stableTilt))
                            .shadow(color: .black.opacity(0.12 + 0.1 * progress + 0.04 * lift), radius: 10 + 8 * progress + 6 * lift, y: 6 + 5 * progress + 4 * lift)
                            .gesture(dragGesture(for: place))
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("Inbox-Ticket")
                            .accessibilityAction(named: "Ja") { act(place, frank: true) }
                            .accessibilityAction(named: "Nein") { act(place, frank: false) }
                            .accessibilityAction(named: "Offen") { leaveOpen(place) }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }

                if let line = authorLine(place) {
                    Text(line).font(.footnote.weight(.medium)).foregroundStyle(Stitch.inkSoft)
                }

                HStack(spacing: Stitch.Space.s) {
                    Button("Nein") { act(place, frank: false) }.buttonStyle(StitchButton())
                    Button("Offen") { leaveOpen(place) }.buttonStyle(StitchButton())
                    Button("Ja") { act(place, frank: true) }.buttonStyle(StitchButton(primary: true))
                }
            } else {
                Spacer()
                StitchedSymbol(name: "heart.fill", rows: 16, cell: 5, color: Stitch.red)
                Text(openIDs.isEmpty ? "Alles entschieden" : "Noch offen").font(.title2.weight(.bold)).foregroundStyle(Stitch.ink).padding(.top, Stitch.Space.xs)
                Text("Neue Links landen hier.\nBeschlossene Orte findest du auf der Karte.")
                    .font(.body).multilineTextAlignment(.center).foregroundStyle(Stitch.inkSoft)
                if !openIDs.isEmpty {
                    Button("Offene Ideen ansehen") { openIDs.removeAll(); lastAction = nil }
                        .buttonStyle(StitchButton()).padding(.top, Stitch.Space.xs).padding(.horizontal, Stitch.Space.xl)
                }
                if !store.deferred.isEmpty {
                    Button("\(store.deferred.count) abgelehnte Ideen ansehen") { store.restoreDeferred() }
                        .buttonStyle(StitchButton()).padding(.top, Stitch.Space.xs).padding(.horizontal, Stitch.Space.xl)
                }
                Spacer()
            }
            if let lastAction {
                Button("Rückgängig", systemImage: "arrow.uturn.backward") {
                    if lastActionWasOpen {
                        openIDs.remove(lastAction.id)
                    } else {
                        store.upsert(lastAction)
                    }
                    self.lastAction = nil
                }
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
        .onAppear { spread() }
        .onChange(of: undecided.first?.id) { spread() }
        .fullScreenCover(item: $viewer) { PhotoViewer(place: $0.place, root: store.root, source: $0.source) }
    }

    /// Die hinteren Karten fächern kurz weiter auf und legen sich per Feder auf ihre Lage;
    /// nur beim Erscheinen und wenn eine neue Karte oben liegt.
    private func spread() {
        guard !reduceMotion else { return }
        var instant = Transaction(animation: nil); instant.disablesAnimations = true
        withTransaction(instant) { fan = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { fan = 0 }
        }
    }

    private func openPhoto(_ place: Place, from source: CGRect) {
        guard !committing else { return }
        var instant = Transaction(animation: nil); instant.disablesAnimations = true
        withTransaction(instant) { viewer = PhotoViewerItem(place: place, source: source) }
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
                guard !committing, abs(value.translation.width) > abs(value.translation.height) else { return }
                offset = rubberBanded(value.translation.width)
                if !reduceMotion { hold(value) }
                let armed = abs(offset) >= decisionThreshold
                if armed && !thresholdArmed { thresholdFeedback += 1 }
                thresholdArmed = armed
            }
            .onEnded { value in
                release()
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

    /// Karte in der Hand: hebt sich an und neigt sich mit der Ziehgeschwindigkeit (geglättet, höchstens ±12°).
    private func hold(_ value: DragGesture.Value) {
        if lift == 0 { withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { lift = 1 } }
        if let last = lastSample {
            let dt = value.time.timeIntervalSince(last.time)
            if dt > 0.008 {
                let velocity = Double(value.translation.width - last.x) / dt
                tilt = tilt * 0.7 + (velocity / 1000 * 12).clamped(to: -12...12) * 0.3
                lastSample = (value.translation.width, value.time)
            }
        } else {
            lastSample = (value.translation.width, value.time)
        }
        // Hält der Finger inne, richtet sich die Karte wieder auf.
        tiltDecay?.cancel()
        tiltDecay = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { tilt = 0 }
        }
    }

    private func release() {
        tiltDecay?.cancel(); lastSample = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { tilt = 0; lift = 0 }
    }

    private func rubberBanded(_ value: CGFloat) -> CGFloat {
        let limit: CGFloat = 190
        guard abs(value) > limit else { return value }
        return value.sign == .minus ? -limit - sqrt(abs(value) - limit) * 4 : limit + sqrt(value - limit) * 4
    }

    private func leaveOpen(_ place: Place) {
        lastAction = place
        lastActionWasOpen = true
        openIDs.insert(place.id)
        offset = 0
        feedback += 1
    }

    private func act(_ place: Place, frank: Bool) {
        if frank && place.coordinate == nil { shouldFrank = true; editing = place; return }
        guard !committing else { return }
        lastAction = place
        lastActionWasOpen = false
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

private struct DecisionHint: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let direction: InboxDecision?
    let progress: CGFloat
    var body: some View {
        if let direction {
            let frank = direction == .frank
            let armed = progress >= 1
            let thread = frank ? Stitch.red : Stitch.cobalt
            Text((frank ? "Ja" : "Nein") + (armed ? "" : "?"))
                .font(.title2.weight(.heavy))
                .contentTransition(.interpolate)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: armed)
                .foregroundStyle(armed && frank ? Stitch.onAccent : Stitch.ink)
                .padding(.horizontal, Stitch.Space.m).padding(.vertical, Stitch.Space.xs)
                .background {
                    ZStack {
                        Stitch.card
                        ThreadFill(color: thread, progress: progress, fromTrailing: !frank)
                        if frank { Stitch.redFill.opacity(armed ? 1 : 0) }
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: armed)
                }
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(thread, lineWidth: armed && !frank ? 3 : 2))
                .phaseAnimator([1.0, reduceMotion ? 1.0 : 1.06, 1.0], trigger: armed) { content, scale in
                    content.scaleEffect(scale)
                } animation: { _ in .spring(response: 0.22, dampingFraction: 0.5) }
                .rotationEffect(.degrees(frank ? -8 : 8))
                .opacity(Double(min(progress * 4, 1)))
                .scaleEffect(0.85 + 0.15 * progress)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frank ? .topLeading : .topTrailing)
                .padding(Stitch.Space.xl)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// Laufstiche in Garnfarbe, die das Schild von einer Seite aus füllen.
private struct ThreadFill: View {
    let color: Color
    let progress: CGFloat
    let fromTrailing: Bool
    var body: some View {
        Canvas { context, size in
            let width = size.width * progress
            context.clip(to: Path(CGRect(x: fromTrailing ? size.width - width : 0, y: 0, width: width, height: size.height)))
            var y: CGFloat = 3
            while y < size.height {
                var row = Path(); row.move(to: CGPoint(x: 0, y: y)); row.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(row, with: .color(color.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                y += 5
            }
        }
    }
}

/// Eine Idee als Polaroid, an zwei Ecken angeheftet.
struct IdeaPolaroid: View {
    let place: Place
    let root: URL
    var tackColor = Stitch.red
    var crossProgress: CGFloat = 0
    /// Tippen auf das Foto; liefert dessen Rahmen auf dem Bildschirm.
    var onPhotoTap: ((CGRect) -> Void)?

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                AlbumPhoto(asset: place.image, root: root)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(160, geo.size.height - 118))
                    .overlay {
                        if let onPhotoTap {
                            GeometryReader { photo in
                                Color.clear.contentShape(Rectangle())
                                    .onTapGesture { onPhotoTap(photo.frame(in: .global)) }
                            }
                            .accessibilityElement().accessibilityLabel("Foto vergrößern").accessibilityAddTraits(.isButton)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Canvas { context, size in
                            Stitch.drawCross(&context, in: CGRect(origin: .zero, size: size), color: Stitch.red, progress: crossProgress)
                        }
                        .frame(width: 64, height: 64)
                        .padding(Stitch.Space.s)
                        .opacity(crossProgress > 0 ? 1 : 0)
                        .allowsHitTesting(false)
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

private struct PhotoViewerItem: Identifiable {
    let id = UUID()
    let place: Place
    let source: CGRect
}

/// Foto im Vollbild. Wächst aus dem Polaroid, nach unten ziehen schrumpft es zurück (halbe Geste = halbe Verkleinerung).
private struct PhotoViewer: View {
    let place: Place
    let root: URL
    let source: CGRect
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 = an der Stelle des Polaroids, 1 = groß.
    @State private var open: CGFloat = 0
    @State private var pull: CGSize = .zero
    @State private var closing = false
    /// 0…1 nach unten gezogen; 300 pt ziehen halbieren den Weg zurück zum Polaroid.
    private var shrink: CGFloat { min(max(pull.height / 300, 0), 1) }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let full = CGRect(x: 0, y: 0, width: geo.size.width, height: min(geo.size.height * 0.72, geo.size.width * 1.3))
                    .offsetBy(dx: 0, dy: geo.size.height * 0.46 - min(geo.size.height * 0.72, geo.size.width * 1.3) / 2)
                let t = reduceMotion ? 1 : open * (1 - 0.5 * shrink)
                let mix = { (a: CGFloat, b: CGFloat) in a + (b - a) * t }
                ZStack {
                    Stitch.opening.opacity(reduceMotion ? open : t)
                    AlbumPhoto(asset: place.image, root: root)
                        .frame(width: mix(source.width, full.width), height: mix(source.height, full.height))
                        .position(x: mix(source.midX, full.midX) + pull.width * open, y: mix(source.midY, full.midY) + pull.height * open)
                        .opacity(reduceMotion ? open : 1)
                        .gesture(reduceMotion ? nil : drag)
                        .accessibilityLabel("Foto von \(place.title)").accessibilityAddTraits(.isImage)
                }
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button { close() } label: { Image(systemName: "xmark") }
                        .buttonStyle(HeaderIconButton())
                        .accessibilityLabel("Foto schließen")
                }
                Spacer()
                if case .external(let image) = place.image {
                    Text("Foto: \(image.credit)\(image.licenseName.map { " · \($0)" } ?? "")")
                        .font(.caption).foregroundStyle(Stitch.onAccent.opacity(0.85)).multilineTextAlignment(.center)
                }
            }
            .padding(Stitch.Space.page)
            .opacity(Double(open * (1 - shrink)))
        }
        .presentationBackground(.clear)
        .onAppear { withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.86)) { open = 1 } }
        .accessibilityAction(.escape) { close() }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !closing else { return }
                pull = CGSize(width: value.translation.width, height: value.translation.height > 0 ? value.translation.height : value.translation.height / 4)
            }
            .onEnded { value in
                guard !closing else { return }
                if pull.height > 110 || value.predictedEndTranslation.height > 320 { close() }
                else { withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) { pull = .zero } }
            }
    }

    private func close() {
        guard !closing else { return }
        closing = true
        withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.32)) { open = 0; pull = .zero } completion: {
            var instant = Transaction(animation: nil); instant.disablesAnimations = true
            withTransaction(instant) { dismiss() }
        }
    }
}
