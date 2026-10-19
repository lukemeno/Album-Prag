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
                                     onAssistant: { prompt in openAssistant(prompt) })
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Stitch.paper.ignoresSafeArea())
        .sheet(item: $sheet) { route in
            switch route {
            case .add(let place): PlaceEditor(place: place)
            case .detail(let id): PlaceDetail(placeID: id)
            case .documents: TripDocumentsView()
            case .sharing: AlbumSettings()
            case .name: NamePrompt()
            case .extraction(let extraction): ExtractedTripSheet(extracted: extraction)
            case .assistant:
                if let assistantSession {
                    AssistantView(session: assistantSession).environment(store)
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
        sheet = .assistant
        guard let prompt else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            assistantSession?.send(prompt)
        }
    }

    private func pasteClipboard() {
        guard let url = UIPasteboard.general.url else { return }
        clipboardOffer = false
        sheet = .add(Place(title: "", sourceURL: url.absoluteString, author: store.me))
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
    var icon: String {
        switch self { case .plan: "calendar"; case .ideas: "lightbulb"; case .map: "map"; case .group: "person.2" }
    }
}

enum NativeSheet: Identifiable {
    case add(Place), detail(String), documents, sharing, name, extraction(ExtractedTrip), assistant, expenses, memories
    var id: String {
        switch self {
        case .add(let place): "add-\(place.id)"
        case .detail(let id): "detail-\(id)"
        case .documents: "documents"
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
