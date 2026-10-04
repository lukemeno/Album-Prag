import SwiftUI
#if DEBUG && targetEnvironment(simulator)
import UIKit
#endif

enum AlbumTab: String, CaseIterable { case reise = "Reise", ideen = "Ideen", karte = "Karte" }

extension View {
    /// Einheitliche Toolbar: genau eine Aktion, „Idee einwerfen“. Alles andere hat einen festen Platz in den Ansichten.
    func albumToolbar(add: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Idee einwerfen", systemImage: "plus", action: add)
            }
        }
    }
}

struct AlbumRoot: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var tab: AlbumTab = .reise
    @State private var adding: Place?
    @State private var sharing = false
    @State private var documents = false
    @State private var clipboardOffer = false
    @State private var askName = false
    @State private var assistantPresented = false
    @State private var assistantSession: AssistantSession?
#if DEBUG && targetEnvironment(simulator)
    @State private var nativeShareSheet = false
#endif
    @AppStorage("album.offeredPasteboard") private var offeredChangeCount = -1

    init() {
        #if DEBUG
        if let start = ProcessInfo.processInfo.environment["ALBUM_START_TAB"], let startTab = AlbumTab(rawValue: start) {
            _tab = State(initialValue: startTab)
        }
        #endif
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                ReiseView(openIdeas: { tab = .ideen }, openMap: { tab = .karte },
                          openDocuments: { documents = true }, openSharing: { sharing = true }, openAdd: add)
                    .toolbar(.hidden, for: .navigationBar)
#if DEBUG && targetEnvironment(simulator)
                    .toolbar {
                        if ProcessInfo.processInfo.environment["ALBUM_QA_NATIVE_SHARE"] == "1" {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("QA Share", systemImage: "square.and.arrow.up") {
                                    nativeShareSheet = true
                                }
                                .accessibilityIdentifier("qa-native-share")
                            }
                        }
                    }
#endif
            }
            .tabItem { Label("Reise", systemImage: "suitcase") }.tag(AlbumTab.reise)
            NavigationStack { InboxView(add: add) }
                .tabItem { Label("Ideen", systemImage: "tray") }.tag(AlbumTab.ideen)
                .badge(store.inbox.count)
            NavigationStack { TripMapView().albumToolbar(add: add) }
                .tabItem { Label("Karte", systemImage: "map") }.tag(AlbumTab.karte)
        }
        .tint(Stitch.ink)
        #if DEBUG
        .accessibilityIdentifier(qaReduceMotionObserved ? "qa-reduce-motion-root" : "album-root")
        #endif
        .overlay(alignment: .top) {
            if clipboardOffer {
                ClipboardNote(onPaste: { url in
                    clipboardOffer = false
                    adding = Place(title: "", sourceURL: url.absoluteString, author: store.me)
                }, onDismiss: { withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) { clipboardOffer = false } })
                // Unter der Toolbar (44) mit 8 Luft, damit „+“ erreichbar bleibt.
                .padding(.top, Stitch.Size.touch + Stitch.Space.xs)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !assistantPresented && !addingPresented {
                Button {
                    if assistantSession == nil { assistantSession = AssistantSession(store: store) }
                    assistantPresented = true
                } label: {
                    // Immer der kleine dunkle Kreis: `Stitch.ink` wird im Dunkelmodus hell, das weiße Symbol wäre dann unsichtbar.
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Stitch.onAccent)
                        .frame(width: 48, height: 48)
                        .background(Stitch.actionFill, in: Circle())
                        .overlay(Circle().strokeBorder(Stitch.rule, lineWidth: colorScheme == .dark ? 1 : 0))
                        .stitchElevation(.floating)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reise-Assistent")
                .accessibilityIdentifier("assistant-launch")
                .padding(.trailing, Stitch.Space.page)
                // Knapp über der Tab-Leiste: So bleibt der Ja-Knopf der Ideen frei.
                .padding(.bottom, 56)
            }
        }
        .sheet(isPresented: $assistantPresented) {
            if let assistantSession { AssistantView(session: assistantSession).environment(store) }
        }
        .sheet(item: $adding) { PlaceEditor(place: $0) }
        .sheet(isPresented: $sharing) { AlbumSettings() }
        .sheet(isPresented: $documents) { TripDocumentsView() }
        .sheet(isPresented: $askName) { NamePrompt() }
        .sheet(item: Binding(get: { store.pendingExtraction }, set: { store.pendingExtraction = $0 })) { ExtractedTripSheet(extracted: $0) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { checkPasteboard() } }
        .onAppear {
            if store.myName.isEmpty { askName = true } else { checkPasteboard() }
        }
        .onChange(of: askName) { _, open in if !open { checkPasteboard() } }
#if DEBUG && targetEnvironment(simulator)
        .sheet(isPresented: $nativeShareSheet) {
            QANativeShareSheet(item: URL(string: "https://example.com/album-qa-share")!, onComplete: {
                store.drainShareQueue()
                nativeShareSheet = false
            })
        }
#endif
    }

    private func add() { adding = Place(title: "", author: store.me) }

    private var addingPresented: Bool {
        adding != nil || sharing || documents || askName || store.pendingExtraction != nil
    }

    #if DEBUG
    private var qaReduceMotionObserved: Bool {
        ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] != nil
            && ProcessInfo.processInfo.environment["ALBUM_QA_REDUCE_MOTION"] == "1"
            && reduceMotion
    }
    #endif

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

#if DEBUG && targetEnvironment(simulator)
private struct QANativeShareSheet: UIViewControllerRepresentable {
    let item: URL
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onComplete() }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

/// Einmal beim ersten Start: Wie heißt du? Der Name steht an den eigenen Ideen.
struct NamePrompt: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var stampTick = 0
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.m) {
            Postmark(bottom: "4.–9.10.", size: 84)
                // Beim ersten Buchstaben drückt der Stempel einmal nach.
                .phaseAnimator([1.0, reduceMotion ? 1.0 : 1.08, 1.0], trigger: stampTick) { content, scale in
                    content.scaleEffect(scale)
                } animation: { _ in .spring(response: 0.22, dampingFraction: 0.6) }
                .padding(.bottom, Stitch.Space.xs)
            Text("Wie heißt du?").font(Stitch.Face.display()).foregroundStyle(Stitch.ink)
            Text("Dein Name steht an den Ideen, die du einwirfst.")
                .font(.body).foregroundStyle(Stitch.inkSoft)
            StitchTextField(placeholder: "Vorname", text: $name, focused: $focused, onSubmit: save)
                .textContentType(.givenName)
                .onChange(of: name) { old, new in if old.isEmpty && !new.isEmpty { stampTick += 1 } }
            Button("Los geht’s", action: save).buttonStyle(StitchButton(primary: true))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            Spacer()
        }
        .padding(Stitch.Space.page).padding(.top, Stitch.Space.xl)
        .background(PaperBackground())
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

/// Einzeiliges Eingabefeld als Schreibmaschine: eine feine Schiene unter dem Text, darauf ein kleiner Schlitten,
/// der dem Text mit leicht unregelmäßigem Anschlag folgt. Der Text selbst steht sofort.
struct StitchTextField: View {
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var onSubmit: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    /// Wo der Schlitten gerade steht.
    @State private var carriage: CGFloat = 0
    @State private var follow: Task<Void, Never>?
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.body).submitLabel(.done)
            .focused(focused).onSubmit(onSubmit)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            // Unsichtbarer Text in gleicher Schrift misst die Breite; das Feld selbst bleibt unberührt.
            .background(alignment: .leading) {
                Text(text).font(.body).fixedSize().hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { moveCarriage(to: $0) }
            }
            .padding(.bottom, Stitch.Space.s)
            .overlay(alignment: .bottomLeading) {
                GeometryReader { box in
                    let x = min(reduceMotion ? textWidth : carriage, box.size.width)
                    ZStack(alignment: .leading) {
                        Rectangle().fill(focused.wrappedValue ? Stitch.ink.opacity(0.35) : Stitch.rule).frame(height: 1)
                        if !reduceMotion && focused.wrappedValue {
                            Capsule().fill(Stitch.red).frame(width: 14, height: 5)
                                .offset(x: max(0, x - 2))
                        }
                    }
                    .frame(height: 5)
                    .allowsHitTesting(false).accessibilityHidden(true)
                }
                .frame(height: 5)
            }
            .stitchCard()
            .contentShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
            .onTapGesture { focused.wrappedValue = true }
    }

    /// Der Schlitten folgt mit 40–90 ms Verzögerung, abgeleitet aus der Textlänge (kein Zufall, aber ungleichmäßig).
    private func moveCarriage(to width: CGFloat) {
        textWidth = width
        guard !reduceMotion else { return }
        let delay = 40 + (text.count * 37) % 51
        follow?.cancel()
        follow = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) { carriage = width }
        }
    }
}

/// Ein Zettel unter der Toolbar: Link in der Zwischenablage erkannt.
/// Einfügen übernimmt ihn als neue Idee, nach oben wischen legt ihn weg, nach 6 Sekunden geht er von selbst.
struct ClipboardNote: View {
    var onPaste: (URL) -> Void
    var onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        HStack(spacing: Stitch.Space.s) {
            Image(systemName: "link").font(.body.weight(.semibold)).foregroundStyle(Stitch.red)
                .frame(width: 36, height: 36).background(Stitch.paperDeep, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Link kopiert").font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.ink)
                Text("Als Idee einwerfen?").font(.footnote).foregroundStyle(Stitch.inkSoft)
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
        .padding(.leading, Stitch.Space.s).padding(.trailing, Stitch.Space.s).padding(.vertical, Stitch.Space.s)
        .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous).strokeBorder(Stitch.rule, lineWidth: 1))
        .stitchElevation(.floating)
        .padding(.horizontal, Stitch.Space.page)
        .scaleEffect(reduceMotion || appeared ? 1 : 0.96, anchor: .top)
        .offset(y: min(0, drag))
        .gesture(DragGesture()
            .onChanged { drag = $0.translation.height }
            .onEnded { value in
                if value.translation.height < -40 || value.predictedEndTranslation.height < -110 { onDismiss() }
                else { withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7)) { drag = 0 } }
            })
        .sensoryFeedback(.impact(flexibility: .soft), trigger: appeared)
        .task {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
            try? await Task.sleep(for: .seconds(6))
            onDismiss()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Link in der Zwischenablage")
        .accessibilityAction(named: "Schließen", onDismiss)
    }
}
