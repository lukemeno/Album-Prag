import SwiftUI

/// Beschriftungen und Kennungen einer Schlitz-Szene.
struct SlotLabels {
    var flap: String
    var cardLabel: String
    var cardHint: String
    var action: String
    var cardID: String
    var buttonID: String
    var idle: String
    var working: String
    var done: String
    var announcement: String
}

/// Gemeinsame Mechanik von Briefkasten und Einladung: Eine Karte wird per Finger nach oben in den Schlitz
/// gezogen (nur Y, halbe Geste = halber Zustand, Maske an der Schlitzkante), ab 40 % Weg oder vorhergesagtem Ende
/// wirft sie von selbst ein, die Klappe schlägt zu, die Naht schließt sich, und ein Zettel wird nach unten nachgedruckt.
/// `commit` läuft ab der Schwelle; liefert es einen Text, ist es gescheitert: Die Karte federt zurück,
/// der Text steht ruhig über dem Knopf, und es lässt sich erneut versuchen.
struct SlotScene<Card: View, Receipt: View>: View {
    var labels: SlotLabels
    var commit: @MainActor () async -> String? = { nil }
    /// Sekunden bis `onFinished` von selbst; nil: erst, wenn der Knopf im erledigten Zustand getippt wird.
    var autoFinish: Double?
    /// Bei „Bewegung reduzieren“ bleibt die Karte stehen (ohne Geste) und wird überblendet, statt gleich zu verschwinden.
    var keepsCardWhenReduced = false
    var onFinished: () -> Void
    private let card: Card
    private let receipt: Receipt

    init(labels: SlotLabels, commit: @escaping @MainActor () async -> String? = { nil }, autoFinish: Double? = nil,
         keepsCardWhenReduced: Bool = false, onFinished: @escaping () -> Void,
         @ViewBuilder card: () -> Card, @ViewBuilder receipt: () -> Receipt) {
        self.labels = labels; self.commit = commit; self.autoFinish = autoFinish
        self.keepsCardWhenReduced = keepsCardWhenReduced; self.onFinished = onFinished
        self.card = card(); self.receipt = receipt()
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 = Karte liegt unten, 1 = ganz im Schlitz. Der Finger setzt den Wert direkt.
    @State private var progress: CGFloat = 0
    @State private var stage = Stage.idle
    @State private var flapClosed = false
    @State private var seam: CGFloat = 0
    @State private var receiptOut = false
    @State private var cardGone = false
    @State private var failure: String?
    @State private var armed = false
    @State private var armTick = 0
    @State private var clack = 0
    @State private var flow: Task<Void, Never>?

    enum Stage { case idle, swallowing, done }

    private let slotY: CGFloat = 150
    /// Ab hier gilt die Geste als Einwurf (Weg oder vorhergesagtes Ende).
    private let armAt: CGFloat = 0.4
    private var showsCard: Bool { !reduceMotion || keepsCardWhenReduced }

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                let rest = geo.size.height * 0.34
                let travel = rest - (slotY - 150)
                let shrink = min(progress / 0.5, 1)
                ZStack(alignment: .top) {
                    PaperBackground()

                    VStack(spacing: Stitch.Space.xs) {
                        ZStack(alignment: .top) {
                            Capsule().fill(Stitch.ink.opacity(0.78)).frame(width: 220, height: 14)
                                .overlay(Capsule().strokeBorder(Stitch.paperDeep, lineWidth: 3))
                                .overlay(SeamRing(closed: seam).fill(Stitch.red).padding(-6))
                            // Klappe
                            RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous).fill(Stitch.redFill)
                                .frame(width: 236, height: 30)
                                .overlay(Text(labels.flap).font(.footnote.weight(.bold)).foregroundStyle(Stitch.onAccent))
                                .rotation3DEffect(.degrees(flapClosed ? 0 : -70 * min(progress / 0.3, 1)), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.6)
                                .offset(y: -10)
                        }
                    }
                    .padding(.top, slotY - 10)
                    .zIndex(2)

                    ZStack(alignment: .top) {
                        if showsCard {
                            card
                                .scaleEffect(1 - 0.58 * shrink, anchor: .top)
                                .offset(y: rest - progress * travel)
                                .rotation3DEffect(.degrees(18 * shrink), axis: (x: 1, y: 0, z: 0))
                                .opacity(cardGone ? 0 : 1)
                                .gesture(reduceMotion ? nil : pull(travel: travel))
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(labels.cardLabel)
                                .accessibilityHint(labels.cardHint)
                                .accessibilityAction(named: labels.action) { throwIn() }
                                .accessibilityIdentifier(labels.cardID)
                        }
                        receipt
                            .accessibilityHidden(!receiptOut)
                            .offset(y: receiptOut || reduceMotion ? slotY + 36 : slotY - 100)
                            .opacity(reduceMotion && !receiptOut ? 0 : 1)
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    // Was über den Schlitz hinausgeht, ist im Briefkasten verschwunden;
                    // der Zettel kommt hinter derselben Kante wieder heraus.
                    .mask(alignment: .top) { Rectangle().padding(.top, slotY + 4) }
                    .zIndex(1)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()

            VStack(spacing: Stitch.Space.s) {
                if let failure {
                    Label(failure, systemImage: "exclamationmark.circle")
                        .font(.footnote).foregroundStyle(Stitch.red).multilineTextAlignment(.center)
                        .transition(.opacity)
                        .accessibilityIdentifier("Einlass-Fehler")
                }
                Button { stage == .done ? onFinished() : throwIn() } label: {
                    // Erledigt zeigt sich mit Häkchen; der gesperrte Knopf bleibt sonst unverändert.
                    HStack(spacing: Stitch.Space.xs) {
                        if stage == .done { Image(systemName: "checkmark").accessibilityHidden(true) }
                        Text(ctaTitle)
                    }
                    .contentTransition(.opacity)
                }
                .buttonStyle(StitchButton(primary: true))
                .disabled(stage == .swallowing || (stage == .done && autoFinish != nil))
                .animation(.easeInOut(duration: 0.28), value: stage)
                .accessibilityIdentifier(labels.buttonID)
            }
            .animation(.easeInOut(duration: 0.28), value: failure)
            .padding(.horizontal, Stitch.Space.page)
            .padding(.bottom, Stitch.Space.m)
        }
        .sensoryFeedback(.selection, trigger: armTick)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: clack)
        .task {
            // Die Tastatur des Editors darf Karte und Knopf nicht verdecken.
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            if reduceMotion && !keepsCardWhenReduced { await settleWithoutMotion() }
        }
        .onDisappear { flow?.cancel() }
    }

    private var ctaTitle: String {
        switch stage {
        case .idle: labels.idle
        case .swallowing: labels.working
        case .done: labels.done
        }
    }

    private func pull(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard stage == .idle else { return }
                progress = min(max(-value.translation.height / travel, 0), 1)
                let nowArmed = progress >= armAt
                if nowArmed && !armed { armTick += 1 }
                armed = nowArmed
            }
            .onEnded { value in
                guard stage == .idle else { return }
                armed = false
                let projected = -value.predictedEndTranslation.height / travel
                if max(progress, projected) >= armAt {
                    throwIn()
                } else {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) { progress = 0 }
                }
            }
    }

    /// Wirft die Karte von der aktuellen Stelle an ganz ein; Geste, Knopf und VoiceOver landen hier.
    private func throwIn() {
        guard stage == .idle else { return }
        stage = .swallowing
        failure = nil
        flow = Task { await run() }
    }

    private func run() async {
        // Der Beitritt o. Ä. läuft ab der Schwelle und wird auch nicht abgebrochen, wenn die Ansicht verschwindet.
        let committing = Task { await commit() }
        if reduceMotion { await finishWithoutMotion(committing); return }
        let rise = 0.16 + 0.24 * (1 - progress)
        withAnimation(.easeIn(duration: rise)) { progress = 1 }
        guard await pause(rise) else { return }
        clack += 1
        withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { flapClosed = true }
        if let message = await committing.value {
            guard !Task.isCancelled else { return }
            bounceBack(message)
            return
        }
        withAnimation(.easeInOut(duration: 0.4)) { seam = 1 }
        guard await pause(0.32) else { return }
        stage = .done
        // Federt mit rund 4 % Überschwingen des Wegs auf.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { receiptOut = true }
        announce()
        guard let autoFinish else { return }
        guard await pause(autoFinish) else { return }
        onFinished()
    }

    /// Gescheitert: Die Klappe öffnet sich, die Karte federt wieder heraus, der Text bleibt ruhig stehen.
    private func bounceBack(_ message: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { flapClosed = false }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) { progress = 0 }
        failure = message
        stage = .idle
        AccessibilityNotification.Announcement(message).post()
    }

    /// Bewegung reduzieren, Karte bleibt stehen: kein Weg, nur Überblenden.
    private func finishWithoutMotion(_ committing: Task<String?, Never>) async {
        if let message = await committing.value {
            failure = message; stage = .idle
            AccessibilityNotification.Announcement(message).post()
            return
        }
        flapClosed = true; seam = 1; stage = .done
        withAnimation(.easeInOut(duration: 0.3)) { cardGone = true; receiptOut = true }
        announce()
        guard let autoFinish else { return }
        guard await pause(autoFinish) else { return }
        onFinished()
    }

    /// Bewegung reduzieren: keine Karte zum Ziehen, der Zettel wird nur eingeblendet.
    private func settleWithoutMotion() async {
        flapClosed = true; seam = 1; stage = .done
        withAnimation(.easeInOut(duration: 0.3)) { receiptOut = true }
        announce()
        guard let autoFinish else { return }
        guard await pause(min(autoFinish, 0.9)) else { return }
        onFinished()
    }

    private func announce() {
        AccessibilityNotification.Announcement(labels.announcement).post()
    }

    private func pause(_ seconds: Double) async -> Bool {
        (try? await Task.sleep(for: .seconds(seconds))) != nil && !Task.isCancelled
    }
}

/// Briefkasten-Schlitz: Die Karte wird per Finger nach oben eingeworfen, die Klappe schlägt zu,
/// die Naht schließt sich, und ein kleiner Zettel wird nachgedruckt.
/// Gespeichert ist die Idee schon vor dieser Ansicht; das Ziehen ist nur das Ritual.
struct LetterSlotDrop: View {
    let place: Place
    let root: URL
    var onDone: () -> Void
    @Environment(AlbumStore.self) private var store

    var body: some View {
        SlotScene(labels: SlotLabels(flap: "Ideen", cardLabel: "\(place.title), Idee", cardHint: "Nach oben ziehen zum Einwerfen",
                                     action: "Einwerfen", cardID: "Einwurf-Karte", buttonID: "Einwurf-Knopf",
                                     idle: "Nach oben einwerfen", working: "Wird eingeworfen …", done: "Eingeworfen",
                                     announcement: "Idee eingeworfen. Liegt bei Ideen."),
                  autoFinish: 1.35, onFinished: onDone) {
            card
        } receipt: {
            receipt
        }
    }

    private var card: some View {
        StampFrame(mat: place.mat, inset: 9, matWidth: 5, elevation: .floating) {
            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                AlbumPhoto(asset: place.image, root: root).frame(width: 220, height: 190)
                Text(place.title.isEmpty ? "Neue Idee" : place.title).font(Stitch.Face.place(24, relativeTo: .title3))
                    .foregroundStyle(Stitch.ink).lineLimit(2)
                    .frame(width: 220, alignment: .leading)
                    .padding(.horizontal, Stitch.Space.xxs).padding(.bottom, Stitch.Space.xxs)
            }
            .background(Stitch.card)
        }
    }

    /// Kleiner Zettel, der nach dem Einwurf aus dem Schlitz kommt.
    private var receipt: some View {
        VStack(spacing: Stitch.Space.xxs) {
            Text("Liegt bei Ideen").font(Stitch.Face.place(22, relativeTo: .headline)).foregroundStyle(Stitch.ink)
            if let partner {
                Text("\(partner) sieht sie beim nächsten Abgleich")
                    .font(.footnote).foregroundStyle(Stitch.inkSoft).multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Stitch.Space.l).padding(.vertical, Stitch.Space.m)
        .frame(width: 228)
        .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
        .overlay(alignment: .topTrailing) { Postmark(bottom: "IDEEN", size: 48).offset(x: 14, y: -18) }
        .stitchElevation(.pinned)
        .accessibilityElement(children: .combine)
    }

    /// Der Album hat keine Mitgliederliste; die andere Person kennen wir nur, wenn genau ein
    /// weiterer Name auf Ideen oder Stimmen vorkommt.
    private var partner: String? {
        let names = Set(store.places.flatMap { [$0.author] + $0.approvals + $0.passedBy }
            .filter { !$0.isEmpty && $0 != store.me && $0.localizedCaseInsensitiveCompare("Wir") != .orderedSame })
        return names.count == 1 ? names.first : nil
    }
}

/// Gestrichelte Naht um den Schlitz; `closed` schließt die Lücken zu einer durchgehenden Linie.
private struct SeamRing: Shape {
    var closed: CGFloat
    var animatableData: CGFloat {
        get { closed }
        set { closed = newValue }
    }
    func path(in rect: CGRect) -> Path {
        Capsule().path(in: rect.insetBy(dx: 1, dy: 1))
            .strokedPath(StrokeStyle(lineWidth: 2, dash: [5, max(4 * (1 - closed), 0.01)]))
    }
}
