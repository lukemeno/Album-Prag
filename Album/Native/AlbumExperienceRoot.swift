import SwiftUI
import UIKit

/// The native Album shell. It keeps the existing store and support screens behind a small,
/// predictable router so only one sheet can be active at a time.
struct AlbumExperienceRoot: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var tripCardNamespace
    @State private var showingTrip = false
    @State private var section: NativeTripSection = .plan
    @State private var sheet: NativeSheet?
    @State private var assistantSession: AssistantSession?
    @State private var assistantPrompt: String?
    @State private var fanOpen = false
#if DEBUG && targetEnvironment(simulator)
    @State private var nativeShareSheet = false
#endif
    @State private var clipboardOffer = false
    @State private var offeredChangeCount = -1
    @State private var fanRequest = 0

    init() {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["ALBUM_START_TAB"] {
            switch raw {
            case "Reise", "Plan": _showingTrip = State(initialValue: true)
            case "Ideen": _showingTrip = State(initialValue: true); _section = State(initialValue: .ideas)
            case "Karte": _showingTrip = State(initialValue: true); _section = State(initialValue: .map)
            case "Gruppe": _showingTrip = State(initialValue: true); _section = State(initialValue: .group)
            default: break
            }
        }
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if showingTrip {
                NativeTripExperience(section: $section, sheet: $sheet,
                                     namespace: tripCardNamespace,
                                     onHome: { closeTrip() },
                                     onAssistant: { prompt in openAssistant(prompt) },
                                     onNativeShare: {
#if DEBUG && targetEnvironment(simulator)
                                         nativeShareSheet = true
#endif
                                     },
                                     onFanOpenChanged: { fanOpen = $0 })
                    .environment(store)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                NativeHomeView(namespace: tripCardNamespace) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) { showingTrip = true }
                }
                .environment(store)
                .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
            }

            if showingTrip {
                NativeTripPillBar(selection: $section)
                    .padding(.horizontal, Stitch.Space.m)
                    .padding(.bottom, 10)
                    .accessibilityHidden(fanOpen)
                    .allowsHitTesting(!fanOpen)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Stitch.paper.ignoresSafeArea())
        .sheet(item: $sheet) { route in
            switch route {
            case .add(let place): PlaceEditor(place: place)
            case .detail(let id): PlaceDetail(placeID: id)
            case .documents: TripDocumentsView()
            case .inbox:
                NavigationStack { InboxView(add: { sheet = .add(Place(title: "", author: store.me)) }) }
            case .collection:
                NavigationStack { CollectionHomeView(add: { sheet = .add(Place(title: "", author: store.me)) }) }
            case .sharing: AlbumSettings()
            case .name: NamePrompt()
            case .extraction(let extraction): ExtractedTripSheet(extracted: extraction)
            case .assistant:
                if let assistantSession {
                    AssistantView(session: assistantSession).environment(store).task {
                        guard let prompt = assistantPrompt else { return }
                        assistantPrompt = nil
                        assistantSession.send(prompt)
                    }
                } else {
                    ProgressView().task { self.assistantSession = AssistantSession(store: store) }
                }
            case .expenses: NativeExpensesView().environment(store)
            case .memories: NativeMemoriesView().environment(store)
            }
        }
        .onAppear {
            if store.myName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { sheet = .name }
            if let extraction = store.pendingExtraction { sheet = .extraction(extraction) }
            checkPasteboard()
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { checkPasteboard() } }
        .onChange(of: store.pendingExtraction) { _, extraction in
            if let extraction { sheet = .extraction(extraction) }
        }
        .onChange(of: sheet?.id) { oldID, newID in
            if oldID == "extraction", newID == nil { store.pendingExtraction = nil }
        }
#if DEBUG && targetEnvironment(simulator)
        .sheet(isPresented: $nativeShareSheet) {
            NativeQAShareSheet(item: URL(string: "https://example.com/album-qa-share")!, onComplete: {
                store.drainShareQueue()
                nativeShareSheet = false
            })
        }
#endif
        .overlay(alignment: .top) {
            if clipboardOffer {
                NativeClipboardNote(onPaste: pasteClipboard, onDismiss: { clipboardOffer = false })
                    .padding(.top, Stitch.Space.s)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .accessibilityIdentifier("album-native-root")
    }

    private func closeTrip() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { showingTrip = false }
    }

    private func openAssistant(_ prompt: String? = nil) {
        if assistantSession == nil { assistantSession = AssistantSession(store: store) }
        assistantPrompt = prompt
        sheet = .assistant
    }

    private func pasteClipboard() {
        let board = UIPasteboard.general
        let raw = board.url?.absoluteString ?? board.string
        clipboardOffer = false
        guard let raw else { return }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: value), ["http", "https"].contains(parsed.scheme?.lowercased()) else { return }
        sheet = .add(Place(title: "", sourceURL: value, author: store.me))
    }

    /// Looking at pasteboard metadata is permission safe. Contents are read only after the user taps Einfügen.
    private func checkPasteboard() {
        let board = UIPasteboard.general
        guard board.changeCount != offeredChangeCount, board.hasURLs || board.hasStrings else { return }
        let count = board.changeCount
        Task { @MainActor in
            guard let patterns = try? await board.detectedPatterns(for: [\.probableWebURL]), patterns.contains(\.probableWebURL) else { return }
            offeredChangeCount = count
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { clipboardOffer = true }
        }
    }
}

enum NativeTripSection: String, CaseIterable, Identifiable {
    case plan = "Plan", ideas = "Ideen", map = "Karte", group = "Gruppe"
    var id: String { rawValue }
    var accessibilityID: String {
        switch self { case .plan: "native-tab-plan"; case .ideas: "native-tab-ideas"; case .map: "native-tab-map"; case .group: "native-tab-group" }
    }
    var icon: String {
        switch self { case .plan: "calendar"; case .ideas: "lightbulb"; case .map: "map"; case .group: "person.2" }
    }
}

enum NativeSheet: Identifiable {
    case add(Place), detail(String), documents, inbox, collection, sharing, name, extraction(ExtractedTrip), assistant, expenses, memories
    var id: String {
        switch self {
        case .add(let place): "add-\(place.id)"
        case .detail(let id): "detail-\(id)"
        case .documents: "documents"
        case .inbox: "inbox"
        case .collection: "collection"
        case .sharing: "sharing"
        case .name: "name"
        case .extraction: "extraction"
        case .assistant: "assistant"
        case .expenses: "expenses"
        case .memories: "memories"
        }
    }
}

private struct NativeClipboardNote: View {
    let onPaste: () -> Void
    let onDismiss: () -> Void
    var body: some View {
        HStack(spacing: Stitch.Space.s) {
            Image(systemName: "link").foregroundStyle(Stitch.red).frame(width: 36, height: 36).background(Stitch.paperDeep, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Link kopiert").font(.subheadline.weight(.semibold))
                Text("Als Idee einwerfen?").font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
            Spacer(minLength: 0)
            Button("Einfügen", action: onPaste).buttonStyle(.borderedProminent).tint(Stitch.redFill)
            Button("Schließen", systemImage: "xmark", action: onDismiss).labelStyle(.iconOnly).buttonStyle(.plain)
                .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                .accessibilityLabel("Link-Hinweis schließen")
        }
        .padding(Stitch.Space.s)
        .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous).strokeBorder(Stitch.rule))
        .stitchElevation(.floating)
        .padding(.horizontal, Stitch.Space.page)
    }
}

#if DEBUG && targetEnvironment(simulator)
private struct NativeQAShareSheet: UIViewControllerRepresentable {
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
