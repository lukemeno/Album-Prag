import SwiftUI

/// Was ein Abgleich von der anderen Person gebracht hat: neue Ideen und neue Ja-Stimmen.
struct SyncChange: Equatable, Identifiable {
    let id = UUID()
    var who: String?
    var ideas: Int
    var votes: Int

    /// Vergleicht den Stand vor und nach dem Abgleich. Eigene Ideen und Stimmen zählen nicht;
    /// Stimmen auf neuen Ideen auch nicht, die gehören schon zur Idee.
    static func between(before: [Place], after: [Place], me: String) -> SyncChange? {
        let known = Dictionary(before.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        func isOther(_ name: String) -> Bool {
            !name.isEmpty && name.localizedCaseInsensitiveCompare(me) != .orderedSame && name.localizedCaseInsensitiveCompare("Wir") != .orderedSame
        }
        var ideas = 0, votes = 0
        var names = Set<String>()
        for place in after where !place.deleted {
            if let old = known[place.id], !old.deleted {
                let added = Set(place.approvals).subtracting(old.approvals).filter(isOther)
                votes += added.count; names.formUnion(added)
            } else if isOther(place.author) {
                ideas += 1; names.insert(place.author)
            }
        }
        guard ideas + votes > 0 else { return nil }
        return SyncChange(who: names.count == 1 ? names.first : nil, ideas: ideas, votes: votes)
    }

    var message: String {
        let name = who ?? "Die anderen"
        let idea = ideas == 1 ? "1 Idee" : "\(ideas) Ideen"
        switch (ideas > 0, votes > 0) {
        case (true, true): return "\(name) hat \(idea) eingeworfen · \(votes)× Ja"
        case (true, false): return "\(name) hat \(idea) eingeworfen"
        default: return "\(name) hat \(votes)× Ja gesagt"
        }
    }
}

/// Kleine Kapsel oben auf der Reise-Seite: pulsiert dezent, solange abgeglichen wird; bringt der Abgleich etwas von
/// der anderen Person, wächst sie auf und zeigt es (Inhalt blendet nach der Hülle ein), klappt nach einigen Sekunden
/// oder per Tipp wieder zu. Ohne Neuigkeit bleibt sie klein und verschwindet.
struct SyncIsland: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Beim Herunterziehen zum Abgleichen ist die Klingel die Rückmeldung; die Insel wartet.
    var suppressed = false
    @State private var showsPulse = false
    @State private var expanded = false
    @State private var contentVisible = false
    @State private var message = ""
    @State private var pending: SyncChange?
    @State private var collapse: Task<Void, Never>?

    private let small = CGSize(width: 96, height: 32)
    private let wide: CGFloat = 244

    private var visible: Bool { showsPulse || expanded }
    private var pulseWanted: Bool { store.syncing && !suppressed }

    var body: some View {
        Button(action: close) {
            ZStack {
                if !expanded {
                    pulse
                }
                Text(message)
                    .font(.footnote.weight(.semibold)).foregroundStyle(Stitch.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.horizontal, Stitch.Space.m)
                    .opacity(contentVisible ? 1 : 0)
            }
            .frame(width: expanded ? wide : small.width, height: expanded ? Stitch.Size.touch : small.height)
            .background(Stitch.card, in: Capsule())
            .overlay(Capsule().strokeBorder(Stitch.ink.opacity(expanded ? 0 : 0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .stitchElevation(expanded ? .floating : .pinned)
        }
        .buttonStyle(.plain)
        .disabled(!expanded)
        .frame(width: wide, alignment: .leading)
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.85, anchor: .leading)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: visible)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(!expanded)
        .accessibilityLabel(message)
        .accessibilityHint("Zum Schließen tippen")
        .accessibilityIdentifier("Abgleich-Insel")
        .task(id: pulseWanted) {
            guard pulseWanted else { showsPulse = false; return }
            // Kurze Abgleiche bleiben unsichtbar, sonst flackert die Kapsel bei jedem Start.
            try? await Task.sleep(for: .seconds(0.5))
            if !Task.isCancelled { showsPulse = true }
        }
        .onChange(of: store.syncChange) { _, change in
            guard let change else { return }
            if suppressed { pending = change } else { open(change) }
        }
        .onChange(of: suppressed) { _, now in
            if !now, let change = pending { pending = nil; open(change) }
        }
        .onDisappear { collapse?.cancel() }
    }

    /// Ein dunkles Garn pulsiert in der kleinen Kapsel; bei „Bewegung reduzieren“ steht es still.
    private var pulse: some View {
        TimelineView(.animation(paused: reduceMotion || !showsPulse)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: Stitch.Space.xs) {
                TackStitch(color: Stitch.red)
                Text("Abgleich").font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
            .opacity(reduceMotion ? 1 : 0.65 + 0.35 * sin(t * 2.6))
        }
        .accessibilityHidden(true)
    }

    private func open(_ change: SyncChange) {
        collapse?.cancel()
        message = change.message
        let shell: Animation = .spring(response: 0.5, dampingFraction: 0.78)
        // Erst wächst die Hülle, dann blendet der Text ein.
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : shell) { expanded = true }
        withAnimation(.easeOut(duration: 0.2).delay(reduceMotion ? 0 : 0.15)) { contentVisible = true }
        AccessibilityNotification.Announcement(change.message).post()
        collapse = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { close() }
        }
    }

    /// Zuklappen: erst verschwindet der Text, dann schrumpft die Hülle; jederzeit unterbrechbar.
    private func close() {
        collapse?.cancel()
        guard expanded else { return }
        withAnimation(.easeIn(duration: 0.12)) { contentVisible = false }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.85).delay(0.06)) { expanded = false }
    }
}
