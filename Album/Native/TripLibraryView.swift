import SwiftUI

/// The trip switcher is deliberately independent from an opened trip store.
/// It only renders the library index; opening a card is the point at which a
/// store is created and injected into the native experience.
/// Startet den Beitritt mit einem Einladungslink; `false`, wenn der Link keiner ist.
extension EnvironmentValues {
    @Entry var openInvitation: (URL) -> Bool = { _ in false }
}

struct TripLibraryView: View {
    @Environment(TripLibrary.self) private var library
    @Environment(\.openInvitation) private var openInvitation
    @State private var invitationError: String?
    @State private var showingCreate = false
    @State private var removalRequest: TripLibraryEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.l) {
                    HStack(alignment: .center, spacing: Stitch.Space.s) {
                        Text("Album").font(Stitch.Face.wordmark()).foregroundStyle(Stitch.ink)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        // Ohne Reise reicht der große Knopf darunter; das + kommt erst dazu, wenn es Reisen gibt.
                        if !library.entries.isEmpty {
                            Button { showingCreate = true } label: { Image(systemName: "plus") }
                                .buttonStyle(HeaderIconButton())
                                .accessibilityLabel("Neue Reise")
                                .accessibilityIdentifier("library-create-trip")
                        }
                    }
                    .padding(.top, Stitch.Space.xs)

                    VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                        Text("Deine Reisen")
                            .font(Stitch.Face.display())
                            .foregroundStyle(Stitch.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text(library.entries.isEmpty ? "Jede Reise bleibt ihr eigenes Album." : countLine)
                            .font(Stitch.Face.subheadline)
                            .foregroundStyle(Stitch.inkSoft)
                            .monospacedDigit()
                    }

                    if let error = library.error {
                        HStack(alignment: .top, spacing: Stitch.Space.s) {
                            Image(systemName: "exclamationmark.circle").foregroundStyle(Stitch.action)
                            Text(error)
                                .font(Stitch.Face.footnote)
                                .foregroundStyle(Stitch.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .stitchCard(.pinned, padding: Stitch.Space.s)
                    }

                    if library.entries.isEmpty {
                        VStack(alignment: .leading, spacing: Stitch.Space.m) {
                            EmptyStateCard(symbol: "book.closed", title: "Noch keine Reise",
                                           message: "Erstelle deine erste Reise oder öffne eine Einladung.")
                            Button("Reise erstellen", systemImage: "plus") { showingCreate = true }
                                .buttonStyle(StitchButton(primary: true))
                                .accessibilityIdentifier("library-create-trip-empty")
                            invitationPaste
                        }
                    } else {
                        LazyVStack(spacing: Stitch.Space.s) {
                            ForEach(library.entries) { entry in
                                tripCard(entry)
                            }
                        }
                    }
                }
                .padding(.horizontal, Stitch.Space.page)
                .padding(.top, Stitch.Space.xs)
                .padding(.bottom, Stitch.Space.xxl)
            }
            .scrollIndicators(.hidden)
            .background(Stitch.paper.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCreate) {
            TripCreateView { title, destination, startDate, endDate in
                guard let id = library.createBlankTrip(title: title, destination: destination,
                                                       startDate: startDate, endDate: endDate) else { return false }
                return library.open(id)
            }
            .environment(library)
        }
        .tripRemoval(request: $removalRequest)
        // TripLibrary loads its index during initialization and refreshes it
        // after every create/open/background transition; avoid constructing a
        // second store merely to redraw this cache view.
    }

    /// Einladung aus der Zwischenablage: Apples Einfügen-Knopf liest sie ohne Nachfrage, weil man selbst tippt.
    private var invitationPaste: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            Text("Einladung bekommen? Link kopieren und hier einfügen.")
                .font(Stitch.Face.footnote).foregroundStyle(Stitch.inkSoft)
            PasteButton(payloadType: String.self) { strings in
                let text = strings.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                Task { @MainActor in
                    if let url = URL(string: text), openInvitation(url) { invitationError = nil }
                    else { invitationError = "Das ist kein Einladungslink. Kopiere den Link aus der Einladung und versuch es noch einmal." }
                }
            }
            .labelStyle(.titleAndIcon)
            .buttonBorderShape(.capsule)
            .tint(Stitch.ink)
            .accessibilityIdentifier("library-paste-invitation")
            if let invitationError {
                Text(invitationError).font(Stitch.Face.footnote).foregroundStyle(Stitch.action)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("library-invitation-error")
            }
        }
        .padding(.top, Stitch.Space.xs)
    }

    private var countLine: String {
        library.entries.count == 1 ? "1 Reise" : "\(library.entries.count) Reisen"
    }

    /// Pastellrand der Marke je Reise: stabil aus der Kennung, damit eine Reise ihre Farbe behält.
    private func mat(for entry: TripLibraryEntry) -> Color {
        let colors = [Stitch.Stamp.sky, Stitch.Stamp.rose, Stitch.Stamp.butter, Stitch.Stamp.mint, Stitch.Stamp.lilac]
        let sum = entry.id.uuidString.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) % 997 }
        return colors[sum % colors.count]
    }

    private func tripCard(_ entry: TripLibraryEntry) -> some View {
        Button {
            _ = library.open(entry.id)
        } label: {
            HStack(spacing: Stitch.Space.m) {
                StampFrame(mat: mat(for: entry), inset: 5, matWidth: 3, elevation: .flat) {
                    Image(systemName: "map")
                        .font(.title2.weight(.regular))
                        .foregroundStyle(Stitch.ink)
                        .frame(width: 52, height: 64)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text(entry.destination?.nilIfEmpty ?? entry.title)
                        .font(Stitch.Face.place(22, relativeTo: .title2))
                        .foregroundStyle(Stitch.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let destination = entry.destination?.nilIfEmpty,
                       destination.localizedCaseInsensitiveCompare(entry.title) != .orderedSame {
                        Text(entry.title).font(Stitch.Face.subheadline).foregroundStyle(Stitch.inkSoft).lineLimit(2)
                    }
                    Text(period(entry)).font(Stitch.Face.footnote).foregroundStyle(Stitch.inkSoft).monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.ink)
            }
            .frame(minHeight: Stitch.Size.touch)
            .stitchCard(.pinned, padding: Stitch.Space.s)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Reise löschen", systemImage: "trash", role: .destructive) { removalRequest = entry }
                .accessibilityIdentifier("library-trip-delete")
        }
        .accessibilityIdentifier("library-trip-\(entry.id.uuidString)")
        .accessibilityLabel("\(entry.destination ?? entry.title), \(period(entry)), öffnen")
    }

    private func period(_ entry: TripLibraryEntry) -> String {
        guard let start = entry.startDate, let end = entry.endDate else { return "Zeitraum offen" }
        var trip = TripInfo()
        trip.startDate = start
        trip.endDate = end
        return TripCalendar(trip: trip).rangeLabel(wideMonth: true, includeYear: true) ?? "Zeitraum prüfen"
    }
}

struct TripCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var destination = ""
    @State private var saveError: String?
    @State private var confirmDiscard = false
    let onSave: (String, String?, TripDay?, TripDay?) -> Bool
    /// „Neue Reise“ oder „Reise bearbeiten“; beim Bearbeiten startet das Formular mit den Werten der Reise.
    var heading = "Neue Reise"
    @State private var includeDates = false
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date()
    private let initialTitle: String
    private let initialDestination: String
    private let initialIncludesDates: Bool
    /// Beim Anlegen reicht das Ziel; ein eigener Name ist erst beim Bearbeiten nötig.
    private let editing: Bool

    init(heading: String = "Neue Reise", initial: TripInfo? = nil, focusDates: Bool = false,
         onSave: @escaping (String, String?, TripDay?, TripDay?) -> Bool) {
        self.heading = heading
        self.onSave = onSave
        let calendar = initial.map { TripCalendar(trip: $0) }
        let start = initial?.startDate.flatMap { calendar?.date(for: $0) }
        let end = initial?.endDate.flatMap { calendar?.date(for: $0) }
        initialTitle = initial?.title ?? ""
        initialDestination = initial?.destination ?? ""
        initialIncludesDates = start != nil && end != nil
        editing = initial != nil
        _title = State(initialValue: initialTitle)
        _destination = State(initialValue: initialDestination)
        // Neue Reisen fragen den Zeitraum gleich ab; „Weiß ich noch nicht“ ist eine bewusste Wahl.
        _includeDates = State(initialValue: initial == nil || initialIncludesDates || focusDates)
        if let start { _startDate = State(initialValue: start) }
        if let end { _endDate = State(initialValue: end) }
    }

    private var hasChanges: Bool {
        title != initialTitle || destination != initialDestination || (editing && includeDates != initialIncludesDates)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if editing {
                        TextField("Name der Reise", text: $title)
                            .accessibilityIdentifier("trip-create-title")
                    }
                    TextField(editing ? "Ziel" : "Wohin geht's?", text: $destination)
                        .textContentType(.addressCity)
                        .accessibilityIdentifier("trip-create-destination")
                }
                .listRowBackground(Stitch.card)
                Section("Zeitraum") {
                    Picker("Zeitraum", selection: $includeDates) {
                        Text("Mit Daten").tag(true)
                        Text("Weiß ich noch nicht").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("trip-create-dates-toggle")
                    if includeDates {
                        DatePicker("Von", selection: $startDate, displayedComponents: .date)
                        DatePicker("Bis", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }
                .listRowBackground(Stitch.card)
                if let saveError { Text(saveError).foregroundStyle(Stitch.action).listRowBackground(Stitch.card) }
            }
            .scrollContentBackground(.hidden)
            .background(PaperBackground())
            .navigationTitle(heading)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { if hasChanges { confirmDiscard = true } else { dismiss() } }.accessibilityIdentifier("trip-create-cancel") }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let cleanDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
                        // Beim Anlegen wird das Ziel zum Namen; umbenennen geht über „Reise bearbeiten“.
                        let cleanTitle = editing ? title.trimmingCharacters(in: .whitespacesAndNewlines) : cleanDestination
                        guard !cleanTitle.isEmpty else { saveError = editing ? "Gib der Reise einen Namen." : "Wohin geht's?"; return }
                        let start: TripDay?
                        let end: TripDay?
                        if includeDates {
                            guard startDate <= endDate, let parsedStart = tripDay(startDate), let parsedEnd = tripDay(endDate) else {
                                saveError = "Prüfe den Reisezeitraum."
                                return
                            }
                            start = parsedStart
                            end = parsedEnd
                        } else {
                            start = nil
                            end = nil
                        }
                        guard onSave(cleanTitle, cleanDestination.isEmpty ? nil : cleanDestination, start, end) else {
                            saveError = "Die Reise konnte nicht gespeichert werden."
                            return
                        }
                        dismiss()
                    }
                    .disabled((editing ? title : destination).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("trip-create-save")
                }
            }
            .discardGuard(hasChanges: hasChanges, isPresented: $confirmDiscard) { dismiss() }
        }
    }

    private func tripDay(_ date: Date) -> TripDay? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return TripDay(rawValue: formatter.string(from: date))
    }
}

/// Löschen oder Verlassen einer Reise – derselbe Ablauf aus der Übersicht und aus der geöffneten Reise:
/// Art klären (nur Gerät, für alle, verlassen), nachfragen, dann erst Server, danach Gerät.
private struct TripRemovalFlow: ViewModifier {
    @Environment(TripLibrary.self) private var library
    @Binding var request: TripLibraryEntry?
    @State private var pendingRemoval: PendingRemoval?

    private struct PendingRemoval { let entry: TripLibraryEntry; let kind: TripLibrary.Removal }

    func body(content: Content) -> some View {
        content
            .onChange(of: request?.id) { _, id in
                guard id != nil, let entry = request else { return }
                request = nil
                prepareRemoval(entry)
            }
            .alert(pendingRemoval.map(title) ?? "",
                   isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
                   presenting: pendingRemoval) { pending in
                Button(confirmLabel(pending.kind), role: .destructive) { remove(pending) }
                Button("Abbrechen", role: .cancel) {}
            } message: { pending in
                Text(message(pending.kind))
            }
    }

    private func name(of entry: TripLibraryEntry) -> String { entry.destination?.nilIfEmpty ?? entry.title }

    private func prepareRemoval(_ entry: TripLibraryEntry) {
        Task {
            do { pendingRemoval = PendingRemoval(entry: entry, kind: try await library.removal(for: entry.id)) }
            catch { library.error = "Für eine geteilte Reise braucht das Löschen eine Internetverbindung. Bitte versuch es gleich noch einmal." }
        }
    }

    private func remove(_ pending: PendingRemoval) {
        Task {
            do { try await library.remove(pending.entry.id, as: pending.kind) }
            catch { library.error = "„\(name(of: pending.entry))“ wurde nicht gelöscht. Prüfe deine Internetverbindung und versuch es noch einmal." }
        }
    }

    private func title(_ pending: PendingRemoval) -> String {
        switch pending.kind {
        case .deviceOnly: "„\(name(of: pending.entry))“ löschen?"
        case .deleteForEveryone: "„\(name(of: pending.entry))“ für alle löschen?"
        case .leave: "„\(name(of: pending.entry))“ verlassen?"
        }
    }

    private func confirmLabel(_ kind: TripLibrary.Removal) -> String {
        switch kind {
        case .deviceOnly: "Löschen"
        case .deleteForEveryone: "Für alle löschen"
        case .leave: "Verlassen"
        }
    }

    private func message(_ kind: TripLibrary.Removal) -> String {
        switch kind {
        case .deviceOnly: "Pläne, Ideen, Unterlagen und Erinnerungen dieser Reise verschwinden von diesem iPhone."
        case .deleteForEveryone: "Die Reise verschwindet für alle Mitreisenden, mit allen Fotos und Unterlagen. Das lässt sich nicht rückgängig machen."
        case .leave: "Die Reise verschwindet von diesem iPhone. Die anderen behalten sie."
        }
    }

}

extension View {
    func tripRemoval(request: Binding<TripLibraryEntry?>) -> some View { modifier(TripRemovalFlow(request: request)) }
}
