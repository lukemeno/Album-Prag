import SwiftUI

/// Briefkasten-Schlitz: Die Karte wird per Finger nach oben eingeworfen, die Klappe schlägt zu,
/// die Naht schließt sich, und ein kleiner Zettel wird nachgedruckt.
/// Gespeichert ist die Idee schon vor dieser Ansicht; das Ziehen ist nur das Ritual.
struct LetterSlotDrop: View {
    let place: Place
    let root: URL
    var onDone: () -> Void
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 = Karte liegt unten, 1 = ganz im Schlitz. Der Finger setzt den Wert direkt.
    @State private var progress: CGFloat = 0
    @State private var stage = Stage.idle
    @State private var flapClosed = false
    @State private var seam: CGFloat = 0
    @State private var receiptOut = false
    @State private var armed = false
    @State private var armTick = 0
    @State private var clack = 0
    @State private var flow: Task<Void, Never>?

    enum Stage { case idle, swallowing, done }

    private let slotY: CGFloat = 150
    /// Ab hier gilt die Geste als Einwurf (Weg oder vorhergesagtes Ende).
    private let armAt: CGFloat = 0.4

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                let rest = geo.size.height * 0.34
                let travel = rest - (slotY - 150)
                let shrink = min(progress / 0.5, 1)
                ZStack(alignment: .top) {
                    LinenBackground()

                    VStack(spacing: Stitch.Space.xs) {
                        ZStack(alignment: .top) {
                            Capsule().fill(Color.black.opacity(0.85)).frame(width: 220, height: 20)
                                .overlay(SeamRing(closed: seam).fill(Stitch.red).padding(-6))
                            // Klappe
                            RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous).fill(Stitch.redFill)
                                .frame(width: 236, height: 30)
                                .overlay(Text("Ideen").font(.footnote.weight(.bold)).foregroundStyle(Stitch.onAccent))
                                .rotation3DEffect(.degrees(flapClosed ? 0 : -70 * min(progress / 0.3, 1)), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.6)
                                .offset(y: -10)
                        }
                    }
                    .padding(.top, slotY - 10)
                    .zIndex(2)

                    ZStack(alignment: .top) {
                        if !reduceMotion {
                            card
                                .scaleEffect(1 - 0.58 * shrink, anchor: .top)
                                .offset(y: rest - progress * travel)
                                .rotation3DEffect(.degrees(18 * shrink), axis: (x: 1, y: 0, z: 0))
                                .gesture(pull(travel: travel))
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(place.title), Idee")
                                .accessibilityHint("Nach oben ziehen zum Einwerfen")
                                .accessibilityAction(named: "Einwerfen") { throwIn() }
                                .accessibilityIdentifier("Einwurf-Karte")
                        }
                        receipt
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

            Button { throwIn() } label: {
                // Erledigt zeigt sich mit Häkchen; der gesperrte Knopf bleibt sonst unverändert.
                HStack(spacing: Stitch.Space.xs) {
                    if stage == .done { Image(systemName: "checkmark").accessibilityHidden(true) }
                    Text(ctaTitle)
                }
                .contentTransition(.opacity)
            }
                .buttonStyle(StitchButton(primary: true))
                .disabled(stage != .idle)
                .animation(.easeInOut(duration: 0.28), value: stage)
                .padding(.horizontal, Stitch.Space.page)
                .padding(.bottom, Stitch.Space.m)
                .accessibilityIdentifier("Einwurf-Knopf")
        }
        .sensoryFeedback(.selection, trigger: armTick)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: clack)
        .task {
            // Die Tastatur des Editors darf Karte und Knopf nicht verdecken.
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            if reduceMotion { await settleWithoutMotion() }
        }
        .onDisappear { flow?.cancel() }
    }

    private var ctaTitle: String {
        switch stage {
        case .idle: "Nach oben einwerfen"
        case .swallowing: "Wird eingeworfen …"
        case .done: "Eingeworfen"
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            AlbumPhoto(asset: place.image, root: root).frame(width: 236, height: 200)
            Text(place.title).font(.title3.weight(.bold)).foregroundStyle(Stitch.ink).lineLimit(2)
                .frame(width: 236, alignment: .leading)
        }
        .padding(Stitch.Space.s)
        .background(Stitch.card)
        .overlay(alignment: .topLeading) { TackStitch().offset(x: Stitch.Space.xs, y: Stitch.Space.xs) }
        .overlay(alignment: .topTrailing) { TackStitch().offset(x: -Stitch.Space.xs, y: Stitch.Space.xs) }
        .stitchElevation(.floating)
    }

    /// Kleiner Zettel, der nach dem Einwurf aus dem Schlitz kommt.
    private var receipt: some View {
        VStack(spacing: Stitch.Space.xxs) {
            Text("Liegt bei Ideen").font(.headline).foregroundStyle(Stitch.ink)
            if let partner {
                Text("\(partner) sieht sie beim nächsten Abgleich")
                    .font(.footnote).foregroundStyle(Stitch.inkSoft).multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Stitch.Space.l).padding(.vertical, Stitch.Space.m)
        .frame(width: 212)
        .background(Stitch.card)
        .overlay(alignment: .topLeading) { TackStitch().offset(x: Stitch.Space.xs, y: Stitch.Space.xs) }
        .overlay(alignment: .topTrailing) { TackStitch().offset(x: -Stitch.Space.xs, y: Stitch.Space.xs) }
        .stitchElevation(.pinned)
        .rotationEffect(.degrees(-1.5))
        .accessibilityElement(children: .combine)
        .accessibilityHidden(!receiptOut)
    }

    /// Der Album hat keine Mitgliederliste; die andere Person kennen wir nur, wenn genau ein
    /// weiterer Name auf Ideen oder Stimmen vorkommt.
    private var partner: String? {
        let names = Set(store.places.flatMap { [$0.author] + $0.approvals + $0.passedBy }
            .filter { !$0.isEmpty && $0 != store.me && $0.localizedCaseInsensitiveCompare("Wir") != .orderedSame })
        return names.count == 1 ? names.first : nil
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
        flow = Task { await run() }
    }

    private func run() async {
        let rise = 0.16 + 0.24 * (1 - progress)
        withAnimation(.easeIn(duration: rise)) { progress = 1 }
        guard await pause(rise) else { return }
        clack += 1
        withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { flapClosed = true }
        withAnimation(.easeInOut(duration: 0.4)) { seam = 1 }
        guard await pause(0.32) else { return }
        stage = .done
        // Federt mit rund 4 % Überschwingen des Wegs auf.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { receiptOut = true }
        announce()
        guard await pause(1.35) else { return }
        onDone()
    }

    /// Bewegung reduzieren: keine Karte zum Ziehen, der Zettel wird nur eingeblendet.
    private func settleWithoutMotion() async {
        flapClosed = true; seam = 1; stage = .done
        withAnimation(.easeInOut(duration: 0.3)) { receiptOut = true }
        announce()
        guard await pause(0.9) else { return }
        onDone()
    }

    private func announce() {
        AccessibilityNotification.Announcement("Idee eingeworfen. Liegt bei Ideen.").post()
    }

    private func pause(_ seconds: Double) async -> Bool {
        (try? await Task.sleep(for: .seconds(seconds))) != nil && !Task.isCancelled
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
