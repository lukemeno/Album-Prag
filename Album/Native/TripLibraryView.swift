import SwiftUI

/// The trip switcher is deliberately independent from an opened trip store.
/// It only renders the library index; opening a card is the point at which a
/// store is created and injected into the native experience.
struct TripLibraryView: View {
    @Environment(TripLibrary.self) private var library
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.l) {
                    HStack(alignment: .center, spacing: Stitch.Space.s) {
                        Text("Album").font(Stitch.Face.wordmark()).foregroundStyle(Stitch.ink)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button { showingCreate = true } label: { Image(systemName: "plus") }
                            .buttonStyle(HeaderIconButton())
                            .accessibilityLabel("Neue Reise")
                            .accessibilityIdentifier("library-create-trip")
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
        // TripLibrary loads its index during initialization and refreshes it
        // after every create/open/background transition; avoid constructing a
        // second store merely to redraw this cache view.
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
    let onSave: (String, String?, TripDay?, TripDay?) -> Bool
    @State private var includeDates = false
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Neue Reise") {
                    TextField("Name der Reise", text: $title)
                        .accessibilityIdentifier("trip-create-title")
                    TextField("Ziel (optional)", text: $destination)
                        .accessibilityIdentifier("trip-create-destination")
                    Toggle("Zeitraum festlegen", isOn: $includeDates)
                        .accessibilityIdentifier("trip-create-dates-toggle")
                    if includeDates {
                        DatePicker("Von", selection: $startDate, displayedComponents: .date)
                        DatePicker("Bis", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }
                if let saveError { Text(saveError).foregroundStyle(Stitch.action) }
            }
            .navigationTitle("Neue Reise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() }.accessibilityIdentifier("trip-create-cancel") }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanTitle.isEmpty else { saveError = "Gib der Reise einen Namen."; return }
                        let cleanDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("trip-create-save")
                }
            }
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
