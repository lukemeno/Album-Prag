import SwiftUI

struct InboxView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var add: () -> Void = {}
    @State private var offset: CGSize = .zero
    @State private var editing: Place?
    @State private var shouldFrank = false
    @State private var lastAction: Place?
    @State private var lastActionWasLater = false
    @State private var laterIDs: Set<String> = []
    @State private var feedback = 0
    @State private var thresholdFeedback = 0
    @State private var thresholdArmed = false
    @State private var committing = false
    /// 0…1: Der Poststempel landet auf dem Foto („frankiert“).
    @State private var stamp: CGFloat = 0
    @State private var stampTick = 0
    /// Wenn beide Ja sagen: zwei Herzhälften schnappen zusammen.
    @State private var magnet: CGFloat = 0
    @State private var magnetTick = 0
    /// 1 = hintere Marken weit aufgefächert, 0 = ruhige Lage; federt beim Erscheinen des Stapels.
    @State private var fan: CGFloat = 1
    /// Oberste Marke in der Hand: 0…1 für Anheben (Größe, Schatten).
    @State private var lift: CGFloat = 0
    /// Neigung um die senkrechte Achse in Grad, aus der geglätteten Ziehgeschwindigkeit.
    @State private var tilt: Double = 0
    @State private var lastSample: (x: CGFloat, time: Date)?
    @State private var tiltDecay: Task<Void, Never>?
    @State private var viewer: PhotoViewerItem?

    private let decisionThreshold: CGFloat = 96
    private var progress: CGFloat { min(abs(offset.width) / decisionThreshold, 1) }
    private var laterProgress: CGFloat { min(max(-offset.height, 0) / decisionThreshold, 1) }

    private var undecided: [Place] { store.inbox.filter { !laterIDs.contains($0.id) } }

    var body: some View {
        VStack(spacing: Stitch.Space.m) {
            if let place = undecided.first {
                GeometryReader { geo in
                    ZStack {
                        ForEach(Array(undecided.dropFirst().prefix(2).enumerated()), id: \.element.id) { index, next in
                            let spread = reduceMotion ? 0 : fan
                            IdeaStamp(place: next, root: store.root)
                                .rotationEffect(.degrees((index == 0 ? -2.5 : 3) + (index == 0 ? -5 : 5) * spread))
                                .offset(x: (index == 0 ? -10 : 12) + (index == 0 ? -16 : 18) * spread, y: 8 - 4 * spread)
                                .scaleEffect(reduceMotion ? 0.95 : 0.95 + 0.03 * progress)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }

                        IdeaStamp(place: place, root: store.root, stamp: stamp, onPhotoTap: { openPhoto(place, from: $0) })
                            .overlay(alignment: .topTrailing) {
                                Button { shouldFrank = false; editing = place } label: { Image(systemName: "pencil") }
                                    .buttonStyle(HeaderIconButton())
                                    .padding(Stitch.Space.l)
                                    .accessibilityLabel("Idee bearbeiten")
                            }
                            .overlay { DecisionHint(direction: hintDirection, progress: max(progress, laterProgress)) }
                            .overlay { if magnet > 0 { MagnetHearts(progress: magnet) } }
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : tilt), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                            .scaleEffect(reduceMotion ? 1 : 1 + 0.05 * lift)
                            .offset(x: offset.width, y: min(offset.height, 0) + (reduceMotion ? 0 : -4 * progress))
                            .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset.width / 42).clamped(to: -6...6)))
                            .shadow(color: Stitch.shadow.opacity(0.06 * lift + 0.08 * progress), radius: 10 + 8 * lift, y: 6 + 6 * lift)
                            .gesture(dragGesture(for: place))
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("Inbox-Ticket")
                            .accessibilityAction(named: "Ja") { act(place, frank: true) }
                            .accessibilityAction(named: "Nein") { act(place, frank: false) }
                            .accessibilityAction(named: "Später entscheiden") { later(place) }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }

                if let line = authorLine(place) {
                    Text(line).font(.footnote.weight(.medium)).foregroundStyle(Stitch.inkSoft)
                }

                HStack(spacing: Stitch.Space.s) {
                    Button { act(place, frank: false) } label: { Label("Nein", systemImage: "xmark") }
                        .buttonStyle(StitchButton())
                    Button { act(place, frank: true) } label: { Label("Ja", systemImage: "checkmark") }
                        .buttonStyle(StitchButton(primary: true))
                }
                HStack {
                    if let lastAction { undoButton(lastAction) }
                    Spacer()
                    Button("Später entscheiden") { later(place) }.buttonStyle(TextActionButton(tint: Stitch.inkSoft))
                }
            } else {
                empty
            }
        }
        .allowsHitTesting(!committing)
        .padding(.horizontal, Stitch.Space.page).padding(.bottom, Stitch.Space.xs)
        .background(PaperBackground())
        .navigationTitle("Ideen")
        .sheet(item: $editing) { PlaceEditor(place: $0, frankOnSave: shouldFrank) }
        .sensoryFeedback(.impact(weight: .medium), trigger: feedback)
        .sensoryFeedback(.selection, trigger: thresholdFeedback)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: stampTick)
        .sensoryFeedback(.success, trigger: magnetTick)
        .onAppear { spread() }
        .onChange(of: undecided.first?.id) { spread() }
        .fullScreenCover(item: $viewer) { PhotoViewer(place: $0.place, root: store.root, source: $0.source) }
    }

    private var hintDirection: InboxDecision? {
        if laterProgress > progress, laterProgress > 0 { return .later }
        if offset.width == 0 { return nil }
        return offset.width > 0 ? .frank : .shelve
    }

    private var empty: some View {
        VStack(spacing: Stitch.Space.s) {
            Spacer()
            Postmark(top: "IDEEN", bottom: laterIDs.isEmpty ? "LEER" : "SPÄTER", color: Stitch.inkSoft, size: 96)
                .padding(.bottom, Stitch.Space.s)
            Text(laterIDs.isEmpty ? "Alles entschieden" : "Ein paar warten noch")
                .font(Stitch.Face.title(28, relativeTo: .title)).foregroundStyle(Stitch.ink)
            Text(laterIDs.isEmpty ? "Neue Links landen hier. Was ihr wollt, steht danach im Plan." : "Du hast sie für später zurückgelegt.")
                .font(.body).multilineTextAlignment(.center).foregroundStyle(Stitch.inkSoft)
            VStack(spacing: Stitch.Space.xs) {
                if !laterIDs.isEmpty {
                    Button("Jetzt entscheiden") { laterIDs.removeAll(); lastAction = nil }
                        .buttonStyle(StitchButton(primary: true))
                } else {
                    Button(action: add) { Label("Idee einwerfen", systemImage: "plus") }
                        .buttonStyle(StitchButton(primary: true))
                }
                if !store.deferred.isEmpty {
                    Button(store.deferred.count == 1 ? "1 abgelehnte Idee zurückholen" : "\(store.deferred.count) abgelehnte Ideen zurückholen") {
                        store.restoreDeferred()
                    }
                    .buttonStyle(TextActionButton())
                }
            }
            .padding(.top, Stitch.Space.m).padding(.horizontal, Stitch.Space.l)
            if let lastAction { undoButton(lastAction) }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func undoButton(_ place: Place) -> some View {
        Button {
            if lastActionWasLater { laterIDs.remove(place.id) } else { store.upsert(place) }
            lastAction = nil
        } label: { Label("Rückgängig", systemImage: "arrow.uturn.backward") }
        .buttonStyle(TextActionButton())
        .accessibilityLabel("Letzte Entscheidung rückgängig")
    }

    /// Die hinteren Marken fächern kurz weiter auf und legen sich per Feder auf ihre Lage;
    /// nur beim Erscheinen und wenn eine neue Marke oben liegt.
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
                guard !committing else { return }
                let t = value.translation
                if abs(t.width) >= abs(t.height) {
                    offset = CGSize(width: rubberBanded(t.width), height: 0)
                    if !reduceMotion { hold(value) }
                } else if t.height < 0 {
                    offset = CGSize(width: 0, height: rubberBanded(t.height))
                }
                let armed = progress >= 1 || laterProgress >= 1
                if armed && !thresholdArmed { thresholdFeedback += 1 }
                thresholdArmed = armed
            }
            .onEnded { value in
                release()
                thresholdArmed = false
                let projected = value.predictedEndTranslation
                if offset.height < 0 {
                    if min(projected.height, value.translation.height) < -decisionThreshold { later(place) }
                } else {
                    let decision = abs(projected.width) > abs(value.translation.width) ? projected.width : value.translation.width
                    if decision > decisionThreshold { act(place, frank: true) }
                    else if decision < -decisionThreshold { act(place, frank: false) }
                }
                if !committing {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.78)) { offset = .zero }
                }
            }
    }

    /// Marke in der Hand: hebt sich an und neigt sich mit der Ziehgeschwindigkeit (geglättet, höchstens ±12°).
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
        // Hält der Finger inne, richtet sich die Marke wieder auf.
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

    /// Später entscheiden: Die Marke geht nur für diesen Durchgang aus dem Weg, ohne Stimme und ohne Abgleich.
    private func later(_ place: Place) {
        guard !committing else { return }
        lastAction = place
        lastActionWasLater = true
        feedback += 1
        if reduceMotion { laterIDs.insert(place.id); offset = .zero; return }
        committing = true
        withAnimation(.easeIn(duration: 0.24)) { offset = CGSize(width: 0, height: -700) } completion: {
            laterIDs.insert(place.id)
            offset = .zero
            committing = false
        }
    }

    private func act(_ place: Place, frank: Bool) {
        if frank && place.coordinate == nil { shouldFrank = true; editing = place; return }
        guard !committing else { return }
        lastAction = place
        lastActionWasLater = false
        let changed = store.decided(place, approve: frank)
        let bothAgree = frank && store.isShared(changed)
        if reduceMotion { feedback += 1; if bothAgree { magnetTick += 1 }; store.upsert(changed); offset = .zero; return }
        committing = true
        if frank {
            // Frankieren: Der Poststempel wird mit Nachdruck aufs Foto gesetzt.
            withAnimation(.easeOut(duration: 0.2)) { offset = .zero }
            withAnimation(.spring(response: 0.26, dampingFraction: 0.55)) { stamp = 1 } completion: {
                stampTick += 1
                guard bothAgree else { fly(changed, to: 640); return }
                // Ihr seid beide dafür: Die Herzhälften schnappen zusammen, dann fliegt die Marke.
                withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { magnet = 1 } completion: {
                    magnetTick += 1
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(450))
                        fly(changed, to: 640)
                    }
                }
            }
        } else {
            feedback += 1
            fly(changed, to: -640)
        }
    }

    private func fly(_ changed: Place, to target: CGFloat) {
        Task { @MainActor in
            if target > 0 { try? await Task.sleep(for: .milliseconds(260)) }
            withAnimation(.easeIn(duration: 0.26)) { offset = CGSize(width: target, height: 0) } completion: {
                store.upsert(changed)
                offset = .zero
                stamp = 0
                magnet = 0
                committing = false
            }
        }
    }
}

private enum InboxDecision { case shelve, frank, later }

/// Zwei Herzhälften (Rot und Teal), die von links und rechts zusammenschnappen.
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
        Image(systemName: "heart.fill").font(.system(size: 96)).foregroundStyle(leading ? Stitch.red : Stitch.teal)
            .mask(alignment: leading ? .leading : .trailing) {
                Rectangle().frame(width: 53)
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
            let armed = progress >= 1
            let ink = direction == .frank ? Stitch.redFill : direction == .shelve ? Stitch.ink : Stitch.teal
            let word = direction == .frank ? "Ja" : direction == .shelve ? "Nein" : "Später"
            Text(word + (armed ? "" : "?"))
                .font(Stitch.Face.title(24, relativeTo: .title2))
                .contentTransition(.interpolate)
                .foregroundStyle(armed ? Stitch.onAccent : ink)
                .padding(.horizontal, Stitch.Space.m).padding(.vertical, Stitch.Space.xs)
                .background {
                    // Stempelfarbe füllt die Pille mit dem Weg; an der Schwelle ist sie voll.
                    GeometryReader { box in
                        ZStack(alignment: direction == .shelve ? .trailing : .leading) {
                            Stitch.card
                            ink.frame(width: box.size.width * progress)
                        }
                    }
                }
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(ink, lineWidth: 2))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: armed)
                .phaseAnimator([1.0, reduceMotion ? 1.0 : 1.08, 1.0], trigger: armed) { content, scale in
                    content.scaleEffect(scale)
                } animation: { _ in .spring(response: 0.22, dampingFraction: 0.5) }
                .rotationEffect(.degrees(direction == .frank ? -8 : direction == .shelve ? 8 : 0))
                .opacity(Double(min(progress * 4, 1)))
                .scaleEffect(0.85 + 0.15 * progress)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: direction == .frank ? .topLeading : direction == .shelve ? .topTrailing : .bottom)
                .padding(Stitch.Space.xl)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// Eine Idee als große Briefmarke: Foto im Pastellrand ihrer Kategorie, Name in Serif, Quelle darunter.
/// `stamp` 0…1 setzt den Poststempel aufs Foto (frankiert).
struct IdeaStamp: View {
    let place: Place
    let root: URL
    var stamp: CGFloat = 0
    /// Tippen auf das Foto; liefert dessen Rahmen auf dem Bildschirm.
    var onPhotoTap: ((CGRect) -> Void)?

    var body: some View {
        GeometryReader { geo in
            StampFrame(mat: place.mat, inset: 10, matWidth: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    AlbumPhoto(asset: place.image, root: root)
                        .frame(maxWidth: .infinity)
                        .frame(height: max(160, geo.size.height - 132))
                        .clipped()
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
                            Postmark(bottom: "FRANKIERT", size: 92)
                                .scaleEffect(1.8 - 0.8 * stamp)
                                .opacity(Double(stamp))
                                .padding(Stitch.Space.s)
                                .allowsHitTesting(false)
                        }
                    VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                        Text(place.title.isEmpty ? "Neue Idee" : place.title)
                            .font(Stitch.Face.place(30, relativeTo: .title)).foregroundStyle(Stitch.ink).lineLimit(2)
                            .minimumScaleFactor(0.8)
                        HStack(spacing: Stitch.Space.xs) {
                            Image(systemName: sourceIcon).font(.footnote.weight(.semibold))
                            Text(place.sourceURL.isEmpty ? place.category : "\(place.sourceLabel) · \(place.category)")
                                .font(.subheadline)
                        }
                        .foregroundStyle(Stitch.inkSoft)
                    }
                    .padding(.horizontal, Stitch.Space.s).padding(.vertical, Stitch.Space.s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Stitch.card)
                }
            }
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

private struct PhotoViewerItem: Identifiable {
    let id = UUID()
    let place: Place
    let source: CGRect
}

/// Foto im Vollbild. Wächst aus der Marke, nach unten ziehen schrumpft es zurück (halbe Geste = halbe Verkleinerung).
/// Mit `photo` zeigt es ein bestimmtes Foto des Ortes (Foto-Stapel), sonst das Hauptfoto.
struct PhotoViewer: View {
    let place: Place
    let root: URL
    let source: CGRect
    var photo: PlaceImageAsset?
    private var asset: PlaceImageAsset? { photo ?? place.image }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 = an der Stelle der Marke, 1 = groß.
    @State private var open: CGFloat = 0
    @State private var pull: CGSize = .zero
    @State private var closing = false
    /// 0…1 nach unten gezogen; 300 pt ziehen halbieren den Weg zurück zur Marke.
    private var shrink: CGFloat { min(max(pull.height / 300, 0), 1) }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let full = CGRect(x: 0, y: 0, width: geo.size.width, height: min(geo.size.height * 0.72, geo.size.width * 1.3))
                    .offsetBy(dx: 0, dy: geo.size.height * 0.46 - min(geo.size.height * 0.72, geo.size.width * 1.3) / 2)
                let t = reduceMotion ? 1 : open * (1 - 0.5 * shrink)
                let mix = { (a: CGFloat, b: CGFloat) in a + (b - a) * t }
                ZStack {
                    Stitch.scrim.opacity(reduceMotion ? open : t)
                    AlbumPhoto(asset: asset, root: root)
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
                if case .external(let image) = asset {
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
