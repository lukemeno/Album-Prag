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
                    HStack {
                        Text("Album").font(Stitch.Face.wordmark()).foregroundStyle(Stitch.red)
                        Spacer()
                        Button("Neue Reise", systemImage: "plus") { showingCreate = true }
                            .labelStyle(.iconOnly)
                            .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                            .accessibilityIdentifier("library-create-trip")
                    }
                    .padding(.top, Stitch.Space.s)
                    Text("Deine Reisen")
                        .font(Stitch.Face.display(36, relativeTo: .largeTitle))
                        .foregroundStyle(Stitch.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Jede Reise bleibt ihr eigenes Album.")
                        .font(.body)
                        .foregroundStyle(Stitch.inkSoft)

                    if let error = library.error {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(Stitch.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(Stitch.Space.s)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Stitch.redFill, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb))
                    }

                    if library.entries.isEmpty {
                        ContentUnavailableView {
                            Label("Noch keine Reise", systemImage: "book.closed")
                        } description: {
                            Text("Erstelle deine erste Reise oder öffne eine Einladung.")
                        } actions: {
                            Button("Reise erstellen", systemImage: "plus") { showingCreate = true }
                                .buttonStyle(StitchButton(primary: true))
                                .accessibilityIdentifier("library-create-trip-empty")
                        }
                        .padding(.vertical, Stitch.Space.l)
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
                guard let id = library.createBlankTrip(title: title, destination: destination), library.open(id), let store = library.activeStore else { return false }
                if startDate != nil || endDate != nil {
                    var trip = store.data.trip
                    trip.startDate = startDate
                    trip.endDate = endDate
                    _ = store.updateTrip(trip)
                    library.refreshActiveEntry()
                }
                return true
            }
            .environment(library)
        }
        // TripLibrary loads its index during initialization and refreshes it
        // after every create/open/background transition; avoid constructing a
        // second store merely to redraw this cache view.
    }

    private func tripCard(_ entry: TripLibraryEntry) -> some View {
        Button {
            _ = library.open(entry.id)
        } label: {
            HStack(spacing: Stitch.Space.m) {
                RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous)
                    .fill(Stitch.paperDeep.gradient)
                    .overlay(Image(systemName: "map").font(.system(size: 28, weight: .light)).foregroundStyle(Stitch.inkSoft.opacity(0.65)))
                    .frame(width: 84, height: 92)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text(entry.destination?.nilIfEmpty ?? entry.title)
                        .font(Stitch.Face.place(24, relativeTo: .title2))
                        .foregroundStyle(Stitch.ink)
                        .lineLimit(2)
                    if let destination = entry.destination?.nilIfEmpty,
                       destination.localizedCaseInsensitiveCompare(entry.title) != .orderedSame {
                        Text(entry.title).font(.subheadline.weight(.medium)).foregroundStyle(Stitch.inkSoft).lineLimit(2)
                    }
                    Text(period(entry)).font(.footnote).foregroundStyle(Stitch.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
            }
            .padding(Stitch.Space.s)
            .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.card).strokeBorder(Stitch.rule))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("library-trip-\(entry.id.uuidString)")
        .accessibilityLabel("\(entry.destination ?? entry.title), \(period(entry)), öffnen")
    }

    private func period(_ entry: TripLibraryEntry) -> String {
        guard let start = entry.startDate, let end = entry.endDate else { return "Zeitraum offen" }
        return "\(start.rawValue) – \(end.rawValue)"
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
                if let saveError { Text(saveError).foregroundStyle(Stitch.red) }
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
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return TripDay(rawValue: formatter.string(from: date))
    }
}
