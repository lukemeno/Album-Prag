import SwiftUI

enum AlbumTab: String, CaseIterable { case reise = "Reise", ideen = "Ideen", karte = "Karte" }

struct AlbumRoot: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AlbumTab = .reise
    @State private var adding: Place?
    @State private var settings = false
    @State private var clipboardOffer = false
    @AppStorage("album.offeredPasteboard") private var offeredChangeCount = -1

    init() {
        #if DEBUG
        if let start = ProcessInfo.processInfo.environment["ALBUM_START_TAB"], let startTab = AlbumTab(rawValue: start) {
            _tab = State(initialValue: startTab)
        }
        #endif
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Stitch.card)
        appearance.shadowColor = UIColor(Stitch.ink.opacity(0.12))
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $tab) {
            ReiseView(openIdeas: { tab = .ideen }, onAdd: add, onShare: { settings = true })
                .tabItem { Label("Reise", systemImage: "suitcase") }.tag(AlbumTab.reise)
            InboxView(onAdd: add, onShare: { settings = true })
                .tabItem { Label("Ideen", systemImage: "lightbulb") }.tag(AlbumTab.ideen)
                .badge(store.inbox.count)
            TripMapView(onAdd: add, onShare: { settings = true })
                .tabItem { Label("Karte", systemImage: "map") }.tag(AlbumTab.karte)
        }
        .tint(Stitch.red)
        .overlay(alignment: .top) {
            if clipboardOffer {
                ClipboardNote(onPaste: { url in
                    clipboardOffer = false
                    adding = Place(title: "", sourceURL: url.absoluteString)
                }, onDismiss: { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { clipboardOffer = false } })
                .padding(.top, 64) // unter der Kopfzeile, damit „+“ und „Teilen“ erreichbar bleiben
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $adding) { PlaceEditor(place: $0) }
        .sheet(isPresented: $settings) { AlbumSettings() }
        .sensoryFeedback(.selection, trigger: tab)
        .onChange(of: scenePhase) { _, phase in if phase == .active { checkPasteboard() } }
        .onAppear(perform: checkPasteboard)
    }

    private func add() { adding = Place(title: "") }

    /// Prüft nur, ob ein Link in der Zwischenablage liegt. Gelesen wird erst, wenn ihr „Einfügen“ tippt.
    private func checkPasteboard() {
        let board = UIPasteboard.general
        guard board.changeCount != offeredChangeCount, board.hasURLs || board.hasStrings else { return }
        let changeCount = board.changeCount
        board.detectPatterns(for: [.probableWebURL]) { result in
            guard case .success(let patterns) = result, patterns.contains(.probableWebURL) else { return }
            Task { @MainActor in
                offeredChangeCount = changeCount
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { clipboardOffer = true }
            }
        }
    }
}

/// Ein Zettel, der aus der Tasche lugt: Link in der Zwischenablage erkannt.
/// Einfügen übernimmt ihn als neue Idee, nach oben wischen legt ihn weg, nach 6 Sekunden geht er von selbst.
struct ClipboardNote: View {
    var onPaste: (URL) -> Void
    var onDismiss: () -> Void
    @State private var drag: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            StitchedSymbol(name: "link", rows: 10, cell: 2.4, color: Stitch.red)
            VStack(alignment: .leading, spacing: 2) {
                Text("Link kopiert").font(.subheadline.weight(.bold)).foregroundStyle(Stitch.ink)
                Text("Als Idee sichern?").font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
            Spacer(minLength: 8)
            PasteButton(payloadType: URL.self) { urls in
                guard let url = urls.first else { return }
                Task { @MainActor in onPaste(url) }
            }
            .buttonBorderShape(.capsule)
            .labelStyle(.titleOnly)
            .tint(Stitch.red)
        }
        .padding(.leading, 16).padding(.trailing, 12).padding(.vertical, 12)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 14, style: .continuous)
                .fill(Stitch.card)
                .overlay(alignment: .bottom) { TornEdge().fill(Stitch.card).frame(height: 6).rotationEffect(.degrees(180)).offset(y: 5) }
                .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
        }
        .overlay(alignment: .topLeading) { TackStitch(color: Stitch.cobalt, size: 13).offset(x: 10, y: -4) }
        .rotationEffect(.degrees(appeared ? 1.5 : 6), anchor: .topLeading)
        .padding(.horizontal, 16)
        .offset(y: min(0, drag))
        .gesture(DragGesture()
            .onChanged { drag = $0.translation.height }
            .onEnded { value in
                if value.translation.height < -40 || value.predictedEndTranslation.height < -110 { onDismiss() }
                else { withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { drag = 0 } }
            })
        .sensoryFeedback(.impact(flexibility: .soft), trigger: appeared)
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
            try? await Task.sleep(for: .seconds(6))
            onDismiss()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Link in der Zwischenablage")
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

struct BoardingPassView: View {
    let trip: TripInfo
    var hasFlight: Bool { !trip.outbound.isEmpty || !trip.arrival.isEmpty }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(hasFlight ? "Anreise · 4. Okt" : "Reise · 4.–9. Okt").font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.muted)
                if hasFlight {
                    HStack { Text(trip.outbound); Spacer(); Text("→").font(AlbumStyle.serif()).foregroundStyle(AlbumStyle.gold); Spacer(); Text(trip.arrival) }.font(AlbumStyle.display(42)).minimumScaleFactor(0.6).lineLimit(1)
                    Text(trip.route).font(AlbumStyle.serif())
                } else {
                    Text("Noch keine Anreise eingetragen").font(AlbumStyle.serif(28))
                    Text("Tickets & Reisedaten hinzufügen").font(AlbumStyle.body(13)).foregroundStyle(AlbumStyle.muted)
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            Text(trip.flightNumber.isEmpty ? "PRAG 2026" : trip.flightNumber).font(AlbumStyle.ticket).rotationEffect(.degrees(90)).fixedSize().frame(width: 36, height: 130).background(AlbumStyle.deep)
        }.foregroundStyle(AlbumStyle.ink).background(AlbumStyle.white, in: RoundedRectangle(cornerRadius: 20))
            .clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AlbumStyle.gold, lineWidth: 0.8))
    }
}
