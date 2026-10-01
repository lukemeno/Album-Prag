import SwiftUI

enum AlbumTab: String, CaseIterable { case reise = "Reise", ideen = "Ideen", karte = "Karte" }

/// Aktionen, die jede Tab-Toolbar gleich anbietet.
struct AlbumActions {
    var add: () -> Void
    var documents: () -> Void
    var planner: () -> Void
    var share: () -> Void
}

extension View {
    /// Einheitliche Toolbar: genau eine Hauptaktion („+“), alles Seltene beschriftet im „Mehr“-Menü.
    func albumToolbar(_ actions: AlbumActions) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Reiseunterlagen", systemImage: "doc.text", action: actions.documents)
                    Button("Tagesplan", systemImage: "calendar", action: actions.planner)
                    Button("Album teilen", systemImage: "person.2", action: actions.share)
                } label: {
                    Label("Mehr", systemImage: "ellipsis")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Idee hinzufügen", systemImage: "plus", action: actions.add)
            }
        }
    }
}

struct AlbumRoot: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab: AlbumTab = .reise
    @State private var adding: Place?
    @State private var settings = false
    @State private var documents = false
    /// „Tagesplan“ öffnet die Karte mit ganz ausgeklappter Liste; jede Wahl zählt hoch.
    @State private var plannerRequest = 0
    @State private var clipboardOffer = false
    @State private var askName = false
    @AppStorage("album.offeredPasteboard") private var offeredChangeCount = -1

    init() {
        #if DEBUG
        if let start = ProcessInfo.processInfo.environment["ALBUM_START_TAB"], let startTab = AlbumTab(rawValue: start) {
            _tab = State(initialValue: startTab)
        }
        #endif
    }

    private var actions: AlbumActions {
        AlbumActions(add: add, documents: { documents = true }, planner: { tab = .karte; plannerRequest += 1 }, share: { settings = true })
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { ReiseView(openIdeas: { tab = .ideen }, openDocuments: { documents = true }).albumToolbar(actions) }
                .tabItem { Label("Reise", systemImage: "suitcase") }.tag(AlbumTab.reise)
            NavigationStack { InboxView().albumToolbar(actions) }
                .tabItem { Label("Ideen", systemImage: "lightbulb") }.tag(AlbumTab.ideen)
                .badge(store.newFromOthers)
            NavigationStack { TripMapView(expandRequest: plannerRequest).albumToolbar(actions) }
                .tabItem { Label("Karte", systemImage: "map") }.tag(AlbumTab.karte)
        }
        .tint(Stitch.red)
        .overlay(alignment: .top) {
            if clipboardOffer {
                ClipboardNote(onPaste: { url in
                    clipboardOffer = false
                    adding = Place(title: "", sourceURL: url.absoluteString, author: store.me)
                }, onDismiss: { withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) { clipboardOffer = false } })
                // Unter der Toolbar (44) mit 8 Luft, damit „+“ und „Mehr“ erreichbar bleiben.
                .padding(.top, Stitch.Size.touch + Stitch.Space.xs)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $adding) { PlaceEditor(place: $0) }
        .sheet(isPresented: $settings) { AlbumSettings() }
        .sheet(isPresented: $documents) { TripDocumentsView() }
        .sheet(isPresented: $askName) { NamePrompt() }
        .sheet(item: Binding(get: { store.pendingExtraction }, set: { store.pendingExtraction = $0 })) { ExtractedTripSheet(extracted: $0) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { checkPasteboard() } }
        .onAppear {
            if store.myName.isEmpty { askName = true } else { checkPasteboard() }
        }
        .onChange(of: askName) { _, open in if !open { checkPasteboard() } }
    }

    private func add() { adding = Place(title: "", author: store.me) }

    /// Prüft nur, ob ein Link in der Zwischenablage liegt. Gelesen wird erst, wenn ihr „Einfügen“ tippt.
    private func checkPasteboard() {
        let board = UIPasteboard.general
        guard board.changeCount != offeredChangeCount, board.hasURLs || board.hasStrings else { return }
        let changeCount = board.changeCount
        Task {
            guard let patterns = try? await board.detectedPatterns(for: [\.probableWebURL]),
                  patterns.contains(\.probableWebURL) else { return }
            offeredChangeCount = changeCount
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8)) { clipboardOffer = true }
        }
    }
}

/// Einmal beim ersten Start: Wie heißt du? Der Name steht an den eigenen Ideen.
struct NamePrompt: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var waveTick = 0
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.m) {
            StitchedSymbol(name: "hand.wave.fill", rows: 18, cell: 3.6, color: Stitch.red)
                // Beim ersten Buchstaben ploppt die Hand einmal auf.
                .phaseAnimator([1.0, reduceMotion ? 1.0 : 1.07, 1.0], trigger: waveTick) { content, scale in
                    content.scaleEffect(scale, anchor: .bottomLeading)
                } animation: { _ in .spring(response: 0.22, dampingFraction: 0.75) }
            Text("Wie heißt du?").font(.largeTitle.weight(.bold)).foregroundStyle(Stitch.ink)
            Text("Dein Name steht an den Ideen, die du sammelst.")
                .font(.body).foregroundStyle(Stitch.inkSoft)
            StitchTextField(placeholder: "Vorname", text: $name, focused: $focused, onSubmit: save)
                .textContentType(.givenName)
                .onChange(of: name) { old, new in if old.isEmpty && !new.isEmpty { waveTick += 1 } }
            Button("Los geht’s", action: save).buttonStyle(StitchButton(primary: true))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            Spacer()
        }
        .padding(Stitch.Space.page).padding(.top, Stitch.Space.xl)
        .background(LinenBackground())
        .interactiveDismissDisabled()
        .presentationDragIndicator(.hidden)
        .task {
            // Erst fokussieren, wenn das Blatt fertig hereingefahren ist; vorher ignoriert iOS den Fokus.
            try? await Task.sleep(for: .milliseconds(600))
            focused = true
        }
        .presentationDetents([.large])
    }
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.myName = trimmed
        dismiss()
    }
}

/// Einzeiliges Eingabefeld im Stil der Karten. Die ganze Fläche ist antippbar.
/// Unter dem Text wächst ein Vorstich; eine Nadel am Ende folgt jedem Anschlag mit kleiner Verzögerung.
struct StitchTextField: View {
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var onSubmit: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    /// Bis hierhin ist schon gestickt; die Nadel steckt am Ende.
    @State private var sewn: CGFloat = 0
    @State private var follow: Task<Void, Never>?
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.body).submitLabel(.done)
            .focused(focused).onSubmit(onSubmit)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            // Unsichtbarer Text in gleicher Schrift misst die Breite; das Feld selbst bleibt unberührt.
            .background(alignment: .leading) {
                Text(text).font(.body).fixedSize().hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { moveNeedle(to: $0) }
            }
            .overlay(alignment: .bottomLeading) {
                GeometryReader { box in
                    let x = min(reduceMotion ? textWidth : sewn, box.size.width)
                    ZStack(alignment: .leading) {
                        Path { path in path.move(to: CGPoint(x: 0, y: 0)); path.addLine(to: CGPoint(x: x, y: 0)) }
                            .stroke(Stitch.red, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        if !reduceMotion && x > 0 {
                            Capsule().fill(Stitch.inkSoft).frame(width: 2, height: 12)
                                .rotationEffect(.degrees(25)).offset(x: x - 1, y: -4)
                        }
                    }
                    .frame(height: 1.5).offset(y: 6)
                    .allowsHitTesting(false).accessibilityHidden(true)
                }
                .frame(height: 1.5).offset(y: 6)
            }
            .stitchCard()
            .contentShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
            .onTapGesture { focused.wrappedValue = true }
    }

    /// Der Text steht sofort; nur die Nadel kommt mit 40–90 ms Verzögerung nach (aus der Textlänge, kein Zufall).
    private func moveNeedle(to width: CGFloat) {
        textWidth = width
        guard !reduceMotion else { return }
        let delay = 40 + (text.count * 37) % 51
        follow?.cancel()
        follow = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { sewn = width }
        }
    }
}

/// Ein Zettel, der aus der Tasche lugt: Link in der Zwischenablage erkannt.
/// Einfügen übernimmt ihn als neue Idee, nach oben wischen legt ihn weg, nach 6 Sekunden geht er von selbst.
struct ClipboardNote: View {
    var onPaste: (URL) -> Void
    var onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        HStack(spacing: Stitch.Space.s) {
            StitchedSymbol(name: "link", rows: 10, cell: 2.4, color: Stitch.red)
            VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                Text("Link kopiert").font(.subheadline.weight(.bold)).foregroundStyle(Stitch.ink)
                Text("Als Idee sichern?").font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
            Spacer(minLength: Stitch.Space.xs)
            PasteButton(payloadType: URL.self) { urls in
                guard let url = urls.first else { return }
                Task { @MainActor in onPaste(url) }
            }
            .buttonBorderShape(.capsule)
            .labelStyle(.titleOnly)
            .tint(Stitch.redFill)
        }
        .padding(.leading, Stitch.Space.m).padding(.trailing, Stitch.Space.s).padding(.vertical, Stitch.Space.s)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: Stitch.Radius.card, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: Stitch.Radius.card, style: .continuous)
                .fill(Stitch.card)
                .overlay(alignment: .bottom) { TornEdge().fill(Stitch.card).frame(height: 6).rotationEffect(.degrees(180)).offset(y: 5) }
                .stitchElevation(.floating)
        }
        .overlay(alignment: .top) { TackStitch(color: Stitch.cobalt).offset(y: -4) }
        .rotationEffect(.degrees(reduceMotion ? 0 : (appeared ? 1.5 : 6)), anchor: .topLeading)
        .padding(.horizontal, Stitch.Space.page)
        .offset(y: min(0, drag))
        .gesture(DragGesture()
            .onChanged { drag = $0.translation.height }
            .onEnded { value in
                if value.translation.height < -40 || value.predictedEndTranslation.height < -110 { onDismiss() }
                else { withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7)) { drag = 0 } }
            })
        .sensoryFeedback(.impact(flexibility: .soft), trigger: appeared)
        .task {
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
            try? await Task.sleep(for: .seconds(6))
            onDismiss()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Link in der Zwischenablage")
        .accessibilityAction(named: "Schließen", onDismiss)
    }
}

/// Abgerissene Papierkante.
struct TornEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        var x: CGFloat = 0
        var random = SeededRandom(seed: 11)
        while x < rect.width {
            path.addLine(to: CGPoint(x: x, y: random.next(in: 0...Double(rect.height))))
            x += CGFloat(random.next(in: 5...11))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
