import SwiftUI
import MapKit

struct NativeHomeView: View {
    @Environment(AlbumStore.self) private var store
    let namespace: Namespace.ID
    let openTrip: () -> Void
    let openLibrary: () -> Void

    private var heroAsset: PlaceImageAsset? {
        store.franked.first(where: { $0.displayImage != nil })?.displayImage
            ?? store.places.first(where: { $0.displayImage != nil })?.displayImage
    }

    private var tripCardID: String {
        #if DEBUG
        if ProcessInfo.processInfo.environment["ALBUM_LEGACY_HOME_QA"] == "1" {
            return "native-trip-prag"
        }
        #endif
        let raw = store.tripName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let slug = raw.unicodeScalars.filter { $0.isASCII && CharacterSet.alphanumerics.contains($0) }
            .map(String.init).joined().lowercased()
        return "native-trip-\(slug.isEmpty ? "trip" : slug)"
    }

    private var tripDateLabel: String {
        let calendar = store.tripCalendar
        if let range = calendar.rangeLabel(wideMonth: true, includeYear: true) { return range }
        return calendar.trip.startDate == nil && calendar.trip.endDate == nil
            ? "Reisedaten noch offen"
            : "Reisezeitraum prüfen"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                    HStack {
                        Text("Album").font(Stitch.Face.wordmark()).foregroundStyle(Stitch.action)
                        Spacer()
                        Button(action: openLibrary) { Image(systemName: "square.grid.2x2") }
                            .buttonStyle(HeaderIconButton())
                            .accessibilityLabel("Alle Reisen")
                            .accessibilityIdentifier("library-open")
                    }
                    .padding(.top, Stitch.Space.s)

                    VStack(alignment: .leading, spacing: Stitch.Space.s) {
                        Text("Deine Reise").font(.caption.weight(.semibold)).foregroundStyle(Stitch.inkSoft).textCase(.uppercase)
                        Button(action: openTrip) {
                            ZStack(alignment: .bottomLeading) {
                                AlbumPhoto(asset: heroAsset, root: store.root)
                                LinearGradient(colors: [.clear, Stitch.ink.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                                VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(store.tripName).font(Stitch.Face.display(38, relativeTo: .largeTitle)).foregroundStyle(.white)
                                                .matchedGeometryEffect(id: "trip-title", in: namespace)
                                            Text(tripDateLabel).font(.subheadline).foregroundStyle(.white.opacity(0.9))
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right").font(.headline.weight(.semibold)).foregroundStyle(.white)
                                    }
                                    if !store.data.trip.hotel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Label(store.data.trip.hotel, systemImage: "bed.double")
                                            .font(.footnote).foregroundStyle(.white.opacity(0.9))
                                    }
                                }
                                .padding(Stitch.Space.l)
                            }
                            .frame(height: 236)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .background(Stitch.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Stitch.line))
                        }
                        .buttonStyle(.plain)
                        .matchedGeometryEffect(id: "trip-card", in: namespace)
                        .accessibilityIdentifier(tripCardID)
                        .accessibilityLabel("\(store.tripName), \(tripDateLabel)")
                    }

                    Text("Ein Album, das euch durch die Reise begleitet.")
                        .font(.body).foregroundStyle(Stitch.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Stitch.Space.page)
                .padding(.bottom, Stitch.Space.xxl)
            }
            .scrollIndicators(.hidden)
            .background(Stitch.paper.ignoresSafeArea())
        }
    }
}

/// Merkt sich in dieser Sitzung neu gespeicherte Ideen: Reihenfolge (neueste zuerst), „Neu“-Marke und die kurze Bestätigung.
@Observable
final class NewIdeaTracker {
    private(set) var order: [String] = []
    var toastVisible = false
    private var hideTask: Task<Void, Never>?

    func added(_ id: String) {
        order.removeAll { $0 == id }
        order.insert(id, at: 0)
        toastVisible = true
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.toastVisible = false
        }
    }
}

struct NativeTripExperience: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var section: NativeTripSection
    @Binding var sheet: NativeSheet?
    let namespace: Namespace.ID
    let onHome: () -> Void
    let onAssistant: (String?) -> Void
    let onNativeShare: () -> Void
    let onFanOpenChanged: (Bool) -> Void
    @State private var fanOpen = false

    /// Kontext des KI-Untermenüs: Reise, heutiger Reisetag und Anzahl der geplanten Orte.
    private var fanContext: String {
        let calendar = store.tripCalendar
        guard let day = calendar.todayInTrip else { return [store.tripName, calendar.rangeLabel()].compactMap { $0 }.joined(separator: " · ") }
        let count = store.plan(for: day).count
        return "\(store.tripName) · \(calendar.weekday(day)), \(calendar.shortDate(day)) · \(count == 1 ? "1 Ort" : "\(count) Orte")"
    }

    private func tabHeader(_ tab: NativeTripSection) -> some View {
        TabHeader(title: tab == .plan ? "Album" : tab.rawValue,
                  onBack: onHome,
                  onAdd: { sheet = .add(Place(title: "", author: store.me)) }) {
            if tab == .ideas {
                Menu {
                    Button("Entscheiden", systemImage: "hand.tap") { sheet = .inbox }
                    Button("Sammlung", systemImage: "tray.full") { sheet = .collection }
                } label: { HeaderIconLabel(symbol: "ellipsis") }
                    .accessibilityLabel("Ideenbereiche")
            }
        }
    }

    var body: some View {
        // TabView hält jeden Tab nach dem ersten Besuch am Leben (Scrollstand, Filter, Kartenausschnitt) und nimmt
        // die versteckten Tabs aus der Bedienhilfe-Hierarchie. Die eigene Leiste (NativeTripPillBar) ersetzt die System-Leiste.
        // Der Kopf hängt an jedem Tab selbst, weil TabView die Kopf-Einrückung nicht an die Tabs weitergibt.
        // Der Kopf hängt an jedem Tab selbst: TabView gibt die Kopf-Einrückung nicht an seine Tabs weiter.
        TabView(selection: $section) {
            NativeTripView(sheet: $sheet, onAssistant: onAssistant, onNativeShare: onNativeShare)
                .safeAreaInset(edge: .top, spacing: 0) { tabHeader(.plan) }
                .tag(NativeTripSection.plan)
            NativeIdeasView(sheet: $sheet, header: { tabHeader(.ideas) })
                .tag(NativeTripSection.ideas)
            TripMapView().ignoresSafeArea(edges: .bottom)
                .safeAreaInset(edge: .top, spacing: 0) { tabHeader(.map) }
                .tag(NativeTripSection.map)
        }
        .toolbar(.hidden, for: .tabBar)
        .accessibilityHidden(fanOpen)
        .background(Stitch.paper.ignoresSafeArea())
        .overlay {
            ZStack {
                if fanOpen {
                    Stitch.paper.opacity(0.78)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { fanOpen = false }
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : Stitch.Motion.press, value: fanOpen)
        }
        .overlay(alignment: .bottomTrailing) {
            NativeArcFAB(isOpen: $fanOpen, contextLabel: fanContext, onAction: { action in
                switch action {
                case .memories: sheet = .memories
                case .camera: sheet = .cameraMemories
                case .expenses: sheet = .expenses
                case .documents: sheet = .documents
                case .assistant(let prompt): onAssistant(prompt)
                }
            }, onOpenStateChanged: onFanOpenChanged)
            .padding(.trailing, Stitch.Space.m)
            .padding(.bottom, 92)
        }
        .onChange(of: fanOpen) { _, isOpen in onFanOpenChanged(isOpen) }
    }
}

/// Tab-Leiste: eine weiße Kapsel mit drei Tabs. Der gewählte Tab ist eine Tintenfläche mit Kartenschrift.
struct NativeTripPillBar: View {
    @Binding var selection: NativeTripSection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: Stitch.Space.xxs) {
            ForEach(NativeTripSection.allCases) { item in
                Button {
                    withAnimation(reduceMotion ? nil : Stitch.Motion.press) { selection = item }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: item.icon).font(.system(size: 17, weight: .semibold))
                        Text(item.rawValue).font(Stitch.Face.caption)
                    }
                    .foregroundStyle(selection == item ? Stitch.card : Stitch.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(selection == item ? Stitch.ink : .clear, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(item.accessibilityID)
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(Stitch.Space.xxs)
        .background(Stitch.card, in: Capsule())
        .stitchElevation(.floating)
    }
}

// MARK: Reise

/// Tab „Reise“ (Figma 01): Reisekarte mit Mehr-Menü, Mitreisende und „Einladen“, Reiseplan mit Tagesstreifen,
/// Heute, Unterlagen und die früheren Gruppen-Bereiche als Aktionszeilen.
struct NativeTripView: View {
    @Environment(AlbumStore.self) private var store
    @Binding var sheet: NativeSheet?
    let onAssistant: (String?) -> Void
    let onNativeShare: () -> Void
    @State private var chosenDay: TripDay?

    private var calendar: TripCalendar { store.tripCalendar }
    private var today: TripDay? { calendar.todayInTrip }
    private var day: TripDay? {
        if let chosenDay, calendar.contains(chosenDay) { return chosenDay }
        return today ?? calendar.days.first
    }
    private var stops: [PlanStop] {
        guard let day else { return [] }
        return store.stops(for: day)
    }
    private var heroAsset: PlaceImageAsset? {
        store.franked.first(where: { $0.displayImage != nil })?.displayImage
            ?? store.places.first(where: { $0.displayImage != nil })?.displayImage
    }
    private var heroSubtitle: String {
        var parts = [calendar.rangeLabel(wideMonth: true)].compactMap { $0 }
        let count = calendar.days.count
        if count > 0 { parts.append(count == 1 ? "1 Tag" : "\(count) Tage") }
        if parts.isEmpty { return "Reisedaten noch offen" }
        return parts.joined(separator: " · ")
    }
    private var travelers: [String] {
        var names = store.data.trip.travelers ?? []
        names.append(store.me)
        return Array(Set(names.filter { !$0.isEmpty && $0.caseInsensitiveCompare("Wir") != .orderedSame })).sorted {
            if $0 == store.me { return true }
            if $1 == store.me { return false }
            return $0 < $1
        }
    }
    private var flights: [FlightLeg] { store.data.trip.flights ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                VStack(alignment: .leading, spacing: Stitch.Space.m) {
                    hero
                    crewRow
                    planCard
                }
                todaySection
                documentsSection
                moreCard
                syncLine
            }
            .padding(.horizontal, Stitch.Space.page)
            .padding(.top, Stitch.Space.xs)
            .padding(.bottom, 128)
        }
        .scrollIndicators(.hidden)
        .background(Stitch.paper.ignoresSafeArea())
    }

    // MARK: Kopf der Reise

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            AlbumPhoto(asset: heroAsset, root: store.root, thumbnailWidth: 900)
            LinearGradient(colors: [.clear, Stitch.scrim.opacity(0.62)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                Text(store.tripName).font(Stitch.Face.display()).foregroundStyle(Stitch.onAction)
                    .lineLimit(2).minimumScaleFactor(0.7)
                Text(heroSubtitle).font(Stitch.Face.subheadline).foregroundStyle(Stitch.onAction.opacity(0.92))
                    .monospacedDigit()
            }
            .padding(Stitch.Space.m)
        }
        .frame(height: 284)
        .background(Stitch.Stamp.sky)
        .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Neue Idee", systemImage: "plus") { sheet = .add(Place(title: "", author: store.me)) }
                Button("Assistent", systemImage: "sparkles") { onAssistant(nil) }
                Button("Teilen & Personen", systemImage: "person.2") { sheet = .sharing }
                Button("Unterlagen", systemImage: "doc.text") { sheet = .documents }
                Button("Ausgaben", systemImage: "eurosign.circle") { sheet = .expenses }
                Button("Erinnerungen", systemImage: "photo.stack") { sheet = .memories }
                Button("Sammlung", systemImage: "tray.full") { sheet = .collection }
#if DEBUG && targetEnvironment(simulator)
                if ProcessInfo.processInfo.environment["ALBUM_QA_NATIVE_SHARE"] == "1" {
                    Button("QA Share", systemImage: "square.and.arrow.up", action: onNativeShare)
                        .accessibilityIdentifier("qa-native-share")
                }
#endif
            } label: { HeaderIconLabel(symbol: "ellipsis") }
                .padding(Stitch.Space.s)
                .accessibilityLabel("Mehr")
                .accessibilityIdentifier("trip-more-menu")
        }
        .accessibilityElement(children: .contain)
    }

    private var crewRow: some View {
        HStack(spacing: Stitch.Space.s) {
            HStack(spacing: -Stitch.Space.xs) {
                ForEach(Array(travelers.prefix(3)), id: \.self) { name in
                    Text(String(name.prefix(2)).uppercased())
                        .font(Stitch.Face.footnote.weight(.semibold)).foregroundStyle(Stitch.Stamp.ink)
                        .frame(width: Stitch.Size.button - Stitch.Space.xs, height: Stitch.Size.button - Stitch.Space.xs)
                        .background(Stitch.Stamp.sky, in: Circle())
                        .overlay(Circle().strokeBorder(Stitch.paper, lineWidth: 2))
                        .accessibilityLabel(name == store.me ? "\(name), du" : name)
                }
            }
            Button { sheet = .sharing } label: {
                Text(store.isShared ? "Einladung teilen" : "Einladen")
                    .font(Stitch.Face.headline).foregroundStyle(Stitch.ink)
                    .frame(maxWidth: .infinity, minHeight: Stitch.Size.button)
                    .background(Stitch.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(Stitch.line))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.isShared ? "Einladung teilen" : "Einladung erstellen")
            .accessibilityIdentifier("native-group-sharing")
        }
    }

    // MARK: Reiseplan

    private var planCard: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Button { sheet = .dayPlan } label: {
                HStack {
                    Text("Reiseplan").font(Stitch.Face.section).foregroundStyle(Stitch.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: Stitch.Space.s)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                }
                .frame(minHeight: Stitch.Size.touch)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reiseplan, Tagesplan öffnen")
            .accessibilityIdentifier("native-open-dayplan")
            if calendar.days.isEmpty {
                Text("Noch kein Reisezeitraum").font(Stitch.Face.subheadline).foregroundStyle(Stitch.inkSoft)
            } else {
                NativeDayTiles(selection: Binding(get: { day }, set: { chosenDay = $0 }))
            }
        }
        .stitchCard()
    }

    // MARK: Heute

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            SectionTitle(title: heading) {
                if !stops.isEmpty {
                    Text(stops.count == 1 ? "1 Ort" : "\(stops.count) Orte").font(Stitch.Face.footnote).foregroundStyle(Stitch.inkSoft)
                        .monospacedDigit()
                }
            }
            if stops.isEmpty {
                EmptyStateCard(symbol: "calendar.badge.plus", title: "Noch nichts geplant",
                               message: "Stimmt eine Idee ab oder fügt einen Ort hinzu.")
                Button("Idee einwerfen", systemImage: "plus") { sheet = .add(Place(title: "", author: store.me)) }
                    .buttonStyle(StitchButton(primary: true))
            } else {
                if let next = stops.first(where: { !$0.place.visited }) {
                    NativeNextStopCard(stop: next, root: store.root,
                                       onOpen: { sheet = .detail(next.place.id) },
                                       onVisited: { var copy = next.place; copy.visited = true; _ = store.upsert(copy) },
                                       onRoute: { openWalkingRoute(to: next.place) })
                    if !next.place.note.isEmpty {
                        NoteSlip(text: next.place.note).padding(.leading, Stitch.Space.l)
                    }
                }
                Button { sheet = .dayPlan } label: {
                    Label("Tagesplan öffnen", systemImage: "list.bullet")
                }
                .buttonStyle(StitchButton())
                .accessibilityIdentifier("native-open-dayplan-list")
            }
        }
    }

    private var heading: String {
        guard let day else { return "Dein Plan" }
        return day == today ? "Heute · \(calendar.dayTitle(day))" : calendar.dayTitle(day)
    }

    // MARK: Unterlagen

    @ViewBuilder private var documentsSection: some View {
        let hotel = store.data.trip.hotel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !flights.isEmpty || !hotel.isEmpty {
            VStack(alignment: .leading, spacing: Stitch.Space.s) {
                SectionTitle(title: "Unterlagen") {
                    Button("Alle") { sheet = .documents }.buttonStyle(TextActionButton())
                        .accessibilityLabel("Alle Reiseunterlagen")
                }
                ForEach(flights) { FlightTicket(leg: $0, legs: flights) { sheet = .documents } }
                if !hotel.isEmpty {
                    Button { sheet = .documents } label: {
                        let details = store.data.trip.hotelDetails
                        TicketRow(symbol: "bed.double", title: details?.name ?? hotel,
                                  detail: [details?.checkIn.map { "Check-in ab \($0)" }, details?.checkOut.map { "Check-out bis \($0)" }]
                                    .compactMap { $0 }.joined(separator: " · ").nilIfEmpty ?? "Unterkunft",
                                  stub: store.data.trip.bookingNumber, mat: Stitch.Stamp.lilac)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Weitere Bereiche (früher „Gruppe“)

    private var moreCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ActionRow(title: "Unterlagen", subtitle: "Flüge, Hotel und PDFs", symbol: "doc.text", mat: Stitch.Stamp.sky) { sheet = .documents }
                .accessibilityIdentifier("native-group-documents")
            rule
            ActionRow(title: "Ausgaben", subtitle: "Gemeinsame Reisekosten", symbol: "eurosign.circle", mat: Stitch.Stamp.butter) { sheet = .expenses }
                .accessibilityIdentifier("native-group-expenses")
            rule
            ActionRow(title: "Erinnerungen", subtitle: "Besuchte Orte und Fotos", symbol: "photo.stack", mat: Stitch.Stamp.rose) { sheet = .memories }
                .accessibilityIdentifier("native-group-memories")
            rule
            ActionRow(title: "Sammlung", subtitle: "Links und Nachrichten der Gruppe", symbol: "tray.full", mat: Stitch.Stamp.mint) { sheet = .collection }
                .accessibilityIdentifier("native-group-collection")
            rule
            ActionRow(title: "Reise-Assistent", subtitle: "Fragen und echte Vorschläge", symbol: "sparkles", mat: Stitch.Stamp.lilac) { onAssistant(nil) }
                .accessibilityIdentifier("assistant-launch")
        }
        .stitchCard()
    }

    private var rule: some View { Rectangle().fill(Stitch.line).frame(height: 1) }

    private var syncLine: some View {
        HStack(spacing: Stitch.Space.xs) {
            Circle().fill(store.syncing ? Stitch.action : Stitch.inkSoft).frame(width: 8, height: 8)
            Text(store.syncStatus).font(Stitch.Face.footnote).foregroundStyle(Stitch.inkSoft)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Synchronisierung: \(store.syncStatus)")
    }
}

/// Tageskacheln im Reiseplan: Datum, Foto des Tages, erster Ort. Gewählt ist die Kachel in Himmelblau.
struct NativeDayTiles: View {
    @Environment(AlbumStore.self) private var store
    @Binding var selection: TripDay?
    private var calendar: TripCalendar { store.tripCalendar }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: Stitch.Space.xs) {
                ForEach(calendar.days) { value in tile(value) }
            }
        }
        .accessibilityLabel("Reisetage")
    }

    /// „4. OKT“: Tag und Monat kurz, wie auf der Kachel in Figma.
    private func shortLabel(_ value: TripDay) -> String {
        calendar.shortDate(value).uppercased()
    }

    private func tile(_ value: TripDay) -> some View {
        let places = store.plan(for: value)
        let selected = selection == value
        let cover = places.first { $0.displayImage != nil }
        return Button { selection = value } label: {
            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                Text(shortLabel(value))
                    .font(Stitch.Face.caption).foregroundStyle(Stitch.inkSoft).monospacedDigit()
                    .lineLimit(1)
                AlbumPhoto(asset: cover?.displayImage, root: store.root, thumbnailWidth: 240)
                    .frame(width: 80, height: 72)
                    .background(Stitch.Stamp.sky.opacity(0.5))
                    .overlay {
                        if cover == nil {
                            Image(systemName: places.first?.symbol ?? "calendar").foregroundStyle(Stitch.inkSoft)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Stitch.Space.s, style: .continuous))
                Text(places.first?.title ?? "Frei")
                    .font(Stitch.Face.subheadline).foregroundStyle(Stitch.ink)
                    .lineLimit(1)
            }
            .padding(Stitch.Space.xs)
            .frame(width: 96, alignment: .leading)
            .background(selected ? Stitch.selection : Stitch.paper, in: RoundedRectangle(cornerRadius: Stitch.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(calendar.dayTitle(value))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: Tagesplan (Figma 02)

struct NativeDayPlanView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var chosenDay: TripDay?
    @State private var detailID: String?
    @State private var proposing = false
    @State private var adding = false

    private var calendar: TripCalendar { store.tripCalendar }
    private var today: TripDay? { calendar.todayInTrip }
    private var day: TripDay? {
        if let chosenDay, calendar.contains(chosenDay) { return chosenDay }
        return today ?? calendar.days.first
    }
    private var stops: [PlanStop] {
        guard let day else { return [] }
        return store.stops(for: day)
    }
    private var subtitle: String {
        guard let day else { return "Noch kein Reisezeitraum" }
        var text = calendar.dayTitle(day)
        if let index = calendar.days.firstIndex(of: day) { text += " · Tag \(index + 1) von \(calendar.days.count)" }
        return text
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.l) {
                    VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                        Text(subtitle).font(Stitch.Face.subheadline).foregroundStyle(Stitch.inkSoft).monospacedDigit()
                    }
                    if !calendar.days.isEmpty {
                        NativeDayTiles(selection: Binding(get: { day }, set: { chosenDay = $0 })).stitchCard()
                    }
                    Text(day == today ? "Heute in \(store.tripName)" : (day.map(calendar.dayTitle) ?? "Noch kein Reisezeitraum"))
                        .font(Stitch.Face.section).foregroundStyle(Stitch.ink)
                        .accessibilityAddTraits(.isHeader)
                    if stops.isEmpty {
                        EmptyStateCard(symbol: "calendar.badge.plus", title: "Noch nichts geplant",
                                       message: "Stimmt eine Idee ab oder lasst einen Tag vorschlagen.")
                    } else {
                        let next = stops.first(where: { !$0.place.visited })
                        VStack(spacing: Stitch.Space.s) {
                            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                                let tripAnchor = store.tripAnchorCoordinate
                                let previous = index == 0 ? tripAnchor : (stops[index - 1].place.coordinate ?? tripAnchor)
                                let walkingMinutes = previous.flatMap { origin in
                                    stop.place.coordinate.map { DayPlanGenerator.walkingMinutes(DayPlanGenerator.distance(origin, $0)) }
                                }
                                NativeTimelineRow(number: index + 1, stop: stop, root: store.root, walkingMinutes: walkingMinutes,
                                                  isNext: stop.id == next?.id,
                                                  onOpen: { detailID = stop.place.id },
                                                  onVisited: { var copy = stop.place; copy.visited = true; _ = store.upsert(copy) },
                                                  onRoute: { openWalkingRoute(to: stop.place) })
                            }
                        }
                    }
                    Button("Automatischen Plan vorschlagen", systemImage: "wand.and.stars") { proposing = true }
                        .buttonStyle(StitchButton(primary: true))
                        .accessibilityIdentifier("native-dayplan-propose")
                }
                .padding(.horizontal, Stitch.Space.page)
                .padding(.top, Stitch.Space.xs)
                .padding(.bottom, Stitch.Space.xl)
            }
            .scrollIndicators(.hidden)
            .background(Stitch.paper.ignoresSafeArea())
            .navigationTitle("Tagesplan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Neue Idee", systemImage: "plus") { adding = true }
                }
            }
            .sheet(isPresented: $proposing) { DayPlanPreview() }
            .sheet(isPresented: $adding) { PlaceEditor(place: Place(title: "", author: store.me)) }
            .sheet(item: Binding(get: { detailID.map(PlanDetailID.init) }, set: { detailID = $0?.id })) { PlaceDetail(placeID: $0.id) }
        }
        .tint(Stitch.ink)
    }

    private struct PlanDetailID: Identifiable { let id: String }
}

struct NativeNextStopCard: View {
    let stop: PlanStop
    let root: URL
    let onOpen: () -> Void
    let onVisited: () -> Void
    let onRoute: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Button(action: onOpen) {
                HStack(spacing: Stitch.Space.m) {
                    StampFrame(mat: stop.place.mat, inset: 4, matWidth: 2, elevation: .flat) {
                        AlbumPhoto(asset: stop.place.displayImage, root: root, thumbnailWidth: 180)
                            .frame(width: 56, height: 64)
                    }
                    VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                        Text("Als Nächstes").font(Stitch.Face.caption).foregroundStyle(Stitch.action)
                        Text(stop.place.title).font(Stitch.Face.headline).foregroundStyle(Stitch.ink).lineLimit(2)
                        Text(stop.slot.capitalized + (stop.note.map { " · \($0)" } ?? ""))
                            .font(Stitch.Face.footnote).foregroundStyle(Stitch.inkSoft).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack(spacing: Stitch.Space.s) {
                if stop.place.coordinate != nil {
                    Button("Route starten", systemImage: "location.fill", action: onRoute).buttonStyle(StitchButton(primary: true))
                        .accessibilityLabel("Route")
                        .accessibilityIdentifier("native-next-route")
                }
                if stop.place.franked && !stop.place.visited {
                    Button("Besucht", systemImage: "checkmark", action: onVisited).buttonStyle(StitchButton())
                        .accessibilityIdentifier("native-next-visited")
                }
            }
        }
        .stitchCard()
        .accessibilityLabel("Nächster Halt: \(stop.place.title)")
    }
}

/// Ein Ort im Tagesplan (Figma 02): Foto, Name, „Zeit · Art“, Pfeil. Der nächste Ort liegt auf Himmelblau.
struct NativeTimelineRow: View {
    let number: Int
    let stop: PlanStop
    let root: URL
    let walkingMinutes: Int?
    var isNext = false
    let onOpen: () -> Void
    let onVisited: () -> Void
    let onRoute: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            Button(action: onOpen) {
                HStack(spacing: Stitch.Space.s) {
                    AlbumPhoto(asset: stop.place.displayImage, root: root, thumbnailWidth: 160)
                        .frame(width: 66, height: 66)
                        .background(stop.place.mat)
                        .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.small, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stop.place.title).font(Stitch.Face.headline).foregroundStyle(Stitch.ink).lineLimit(2)
                        Text([stop.slot.capitalized, stop.place.category].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(Stitch.Face.footnote).foregroundStyle(Stitch.inkSoft).monospacedDigit()
                        if let walkingMinutes {
                            Text("ca. \(walkingMinutes) Min. zu Fuß · Schätzung").font(Stitch.Face.caption).foregroundStyle(Stitch.inkSoft)
                        }
                        if let note = stop.note { Text(note).font(Stitch.Face.caption).foregroundStyle(Stitch.action) }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if stop.place.coordinate != nil || (stop.place.franked && !stop.place.visited) {
                HStack(spacing: Stitch.Space.l) {
                    if stop.place.coordinate != nil {
                        Button("Route", systemImage: "figure.walk", action: onRoute).buttonStyle(TextActionButton())
                            .accessibilityIdentifier("native-stop-route")
                    }
                    if stop.place.franked && !stop.place.visited {
                        Button("Besucht", systemImage: "checkmark", action: onVisited).buttonStyle(TextActionButton())
                            .accessibilityIdentifier("native-stop-visited")
                    }
                }
                .padding(.leading, 66 + Stitch.Space.s)
            }
        }
        .padding(Stitch.Space.s)
        .background(isNext ? Stitch.selection : Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
        .stitchElevation(isNext ? .flat : .pinned)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(number). \(stop.place.title), \(stop.slot)")
    }
}

// MARK: Ideen

private enum IdeasMode: Int { case stack, list }

struct NativeIdeasView<Header: View>: View {
    /// Tab-Kopf; er und der Umschalter sind die feste Einrückung über der Liste.
    @ViewBuilder var header: Header
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var sheet: NativeSheet?
    @State private var mode = IdeasMode.stack
    @State private var category = "Alle"
    @State private var skipped = Set<String>()
    @State private var imageRefreshTask: Task<Void, Never>?
    @State private var discoveryPresented = false
    @Environment(NewIdeaTracker.self) private var newIdeas: NewIdeaTracker?
    private let categories = ["Alle", "Essen & Trinken", "Sehenswert", "Aussicht", "Shopping", "Idee"]

    private var ideas: [Place] {
        // Ungelöste alte Tageszahlen bleiben hier sichtbar, bis jemand ein Datum wählt.
        let approvedButUnplanned = store.places.filter {
            $0.plannedDate == nil && $0.approvals.contains(store.me)
                && !$0.deferred && !$0.passedBy.contains(store.me)
        }
        let visibleIDs = Set((store.inbox + store.franked.filter { $0.plannedDate == nil } + approvedButUnplanned).map(\.id))
        return store.places
            .filter { visibleIDs.contains($0.id) }
            .filter { category == "Alle" || $0.category == category }
    }

    /// Anzeige: in dieser Sitzung neu gespeicherte Ideen zuerst (neueste oben), danach die Reihenfolge des Stores.
    private var listIdeas: [Place] {
        let fresh = newIdeas?.order ?? []
        guard !fresh.isEmpty else { return ideas }
        let head = fresh.compactMap { id in ideas.first { $0.id == id } }
        return head + ideas.filter { !fresh.contains($0.id) }
    }

    /// Noch nicht entschieden und in dieser Runde nicht auf „Offen“ gelegt.
    private var stack: [Place] { store.inbox.filter { !skipped.contains($0.id) } }

    private var subtitle: String {
        switch mode {
        case .stack:
            return stack.count == 1 ? "Noch 1 Idee · gemeinsam entscheiden" : "Noch \(stack.count) Ideen · gemeinsam entscheiden"
        case .list:
            return "\(ideas.count == 1 ? "1 Idee" : "\(ideas.count) Ideen") · \(category == "Alle" ? "alle Kategorien" : category)"
        }
    }

    private var showsSwitcher: Bool { !(ideas.isEmpty && store.inbox.isEmpty && category == "Alle") }

    init(sheet: Binding<NativeSheet?>, @ViewBuilder header: () -> Header) {
        _sheet = sheet
        self.header = header()
    }

    var body: some View {
        ScrollView {
            // Der Kopf scrollt mit der Liste weg; Untertitel und Umschalter bleiben oben stehen. So wechselt Stapel/Liste
            // ohne Scrollen, und die Liste behält ihre Position (Beta-Test 4).
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                header
                if showsSwitcher {
                    Section {
                        VStack(alignment: .leading, spacing: Stitch.Space.m) {
                            switch mode {
                            case .stack: stackContent
                            case .list: listContent
                            }
                            actionRows
                        }
                        .padding(.horizontal, Stitch.Space.page)
                        .padding(.bottom, 128)
                    } header: {
                        VStack(alignment: .leading, spacing: Stitch.Space.m) {
                            Text(subtitle).font(Stitch.Face.subheadline).foregroundStyle(Stitch.inkSoft).monospacedDigit()
                            SegmentPair(titles: ["Stapel", "Liste"],
                                        identifiers: ["native-ideas-stack", "native-ideas-list"],
                                        selection: Binding(get: { mode.rawValue }, set: { mode = IdeasMode(rawValue: $0) ?? .stack }))
                        }
                        .padding(.horizontal, Stitch.Space.page)
                        .padding(.top, Stitch.Space.xs)
                        .padding(.bottom, Stitch.Space.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Stitch.paper)
                    }
                } else {
                    emptyState
                        .padding(.horizontal, Stitch.Space.page)
                        .padding(.top, Stitch.Space.xs)
                        .padding(.bottom, 128)
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(Stitch.paper.ignoresSafeArea())
        .onDisappear { imageRefreshTask?.cancel() }
        .sheet(isPresented: $discoveryPresented) { NativeDiscoveryView() }
    }

    // MARK: Leer (Figma 32)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.m) {
            EmptyStateCard(symbol: "tray", title: "Noch keine Ideen",
                           message: "Kopiere einen Link oder füge einen Ort hinzu. Eure Ideen sammeln sich hier.")
            Button("Erste Idee einwerfen") { sheet = .add(Place(title: "", author: store.me)) }
                .buttonStyle(StitchButton(primary: true))
            actionRows
        }
    }

    // MARK: Stapel (Figma 03)

    @ViewBuilder private var stackContent: some View {
        if let top = stack.first {
            NativeIdeaStackCard(place: top, root: store.root, store: store, sheet: $sheet)
                .id(top.id)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
            HStack(spacing: Stitch.Space.s) {
                decision("Nein", primary: false, id: "native-decide-no") { decide(top, approve: false) }
                decision("Offen", primary: false, id: "native-decide-open") { withAnimation(reduceMotion ? nil : Stitch.Motion.panel) { _ = skipped.insert(top.id) } }
                decision("Ja", primary: true, id: "native-decide-yes") { decide(top, approve: true) }
            }
            Text("Tippe auf das Foto, um den Ort anzusehen.")
                .font(Stitch.Face.footnote).foregroundStyle(Stitch.inkSoft)
        } else {
            EmptyStateCard(symbol: "checkmark.circle", title: "Alles entschieden",
                           message: "Neue Ideen erscheinen hier. In der Liste siehst du alle Orte.")
        }
    }

    private func decision(_ title: String, primary: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Stitch.Face.headline)
                .foregroundStyle(primary ? Stitch.card : Stitch.ink)
                .frame(maxWidth: .infinity, minHeight: Stitch.Size.button)
                .background(primary ? Stitch.ink : Stitch.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Stitch.line, lineWidth: primary ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func decide(_ place: Place, approve: Bool) {
        withAnimation(reduceMotion ? nil : Stitch.Motion.panel) {
            _ = store.upsert(store.decided(place, approve: approve))
        }
    }

    // MARK: Liste (Figma 04)

    @ViewBuilder private var listContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Stitch.Space.xs) {
                ForEach(categories, id: \.self) { item in
                    FilterChip(title: item, selected: category == item) { category = item }
                }
            }
        }
        if ideas.isEmpty {
            EmptyStateCard(symbol: "lightbulb", title: "Noch keine Ideen in dieser Kategorie",
                           message: "Wähle eine andere Kategorie oder wirf eine neue Idee ein.")
        } else {
            LazyVStack(spacing: Stitch.Space.s) {
                ForEach(listIdeas) { place in NativeIdeaRow(place: place, root: store.root, store: store, sheet: $sheet) }
            }
        }
    }

    // MARK: Aktionszeilen unter der Liste

    private var actionRows: some View {
        VStack(spacing: Stitch.Space.s) {
            Button { sheet = .collection } label: { Label("Sammlung öffnen", systemImage: "tray.full") }
                .buttonStyle(StitchButton())
                .accessibilityIdentifier("native-ideas-collection")
            Button { discoveryPresented = true } label: { Label("Entdecken", systemImage: "sparkle.magnifyingglass") }
                .buttonStyle(StitchButton())
                .accessibilityIdentifier("native-discover")
            Button {
                imageRefreshTask?.cancel()
                imageRefreshTask = Task { await store.refreshPlaceImages(force: false) }
            } label: { Label("Bilder ergänzen", systemImage: "arrow.clockwise") }
                .buttonStyle(StitchButton())
                .accessibilityIdentifier("native-refresh-images")
        }
        .padding(.top, Stitch.Space.xs)
    }
}

/// Oberste Karte des Stapels (Figma 03): großes Foto, Name, „Art · von Name“, Mehr-Menü oben rechts.
private struct NativeIdeaStackCard: View {
    let place: Place
    let root: URL
    let store: AlbumStore
    @Binding var sheet: NativeSheet?
    @State private var addingDay = false
    @State private var confirmDelete = false

    private var byline: String {
        let from = place.author.localizedCaseInsensitiveCompare("Wir") == .orderedSame ? nil : "von \(place.author)"
        return [place.category, from].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        Button { sheet = .detail(place.id) } label: {
            ZStack(alignment: .bottomLeading) {
                AlbumPhoto(asset: place.displayImage, root: root, thumbnailWidth: 900)
                    .background(place.mat)
                    .overlay {
                        if place.displayImage == nil { Image(systemName: place.symbol).font(.largeTitle).foregroundStyle(Stitch.ink) }
                    }
                LinearGradient(colors: [.clear, Stitch.scrim.opacity(0.62)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text(place.title).font(Stitch.Face.display()).foregroundStyle(Stitch.onAction)
                        .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.leading)
                    Text(byline).font(Stitch.Face.subheadline).foregroundStyle(Stitch.onAction.opacity(0.92))
                }
                .padding(Stitch.Space.m)
            }
            .frame(height: 380)
            .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(place.title), \(place.category)")
        .accessibilityHint("Öffnet die Ortsdetails")
        .accessibilityIdentifier("native-idea-\(place.id)")
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Für mich", systemImage: "checkmark") {
                    _ = store.upsert(store.decided(place, approve: true))
                }
                Button("Auf Tag legen", systemImage: "calendar") { addingDay = true }
                Button("Bearbeiten", systemImage: "pencil") { sheet = .add(place) }
                Button("Ausblenden", systemImage: "eye.slash") { store.deferPlace(place) }
                Button("Löschen", systemImage: "trash", role: .destructive) { confirmDelete = true }
            } label: { HeaderIconLabel(symbol: "ellipsis") }
                .padding(Stitch.Space.s)
                .accessibilityLabel("Mehr für \(place.title)")
        }
        .stitchElevation(.pinned)
        .sheet(isPresented: $addingDay) {
            DayChoiceSheet(place: place, store: store) { addingDay = false }
        }
        .modifier(IdeaDeleteConfirmation(place: place, store: store, isPresented: $confirmDelete))
    }
}

/// „Löschen“ im Ideen-Menü fragt nach (Figma 36). „Behalten“ lässt die Idee unverändert.
private struct IdeaDeleteConfirmation: ViewModifier {
    let place: Place
    let store: AlbumStore
    @Binding var isPresented: Bool
    func body(content: Content) -> some View {
        content.deleteConfirmation(
            isPresented: $isPresented, name: place.title,
            message: "Die Idee verschwindet auch auf dem anderen iPhone.",
            onDelete: { var copy = place; copy.deleted = true; _ = store.upsert(copy) },
            preview: {
                AlbumPhoto(asset: place.displayImage, root: store.root, thumbnailWidth: 800)
                    .frame(height: 220).frame(maxWidth: .infinity).background(place.mat)
                    .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
            })
    }
}


private struct NativeIdeaRow: View {
    let place: Place
    let root: URL
    let store: AlbumStore
    @Binding var sheet: NativeSheet?
    @State private var addingDay = false
    @State private var resolutionCandidates: [PlaceResolutionCandidate]?
    @State private var imageTask: Task<Void, Never>?
    @State private var confirmDelete = false
    @Environment(NewIdeaTracker.self) private var newIdeas: NewIdeaTracker?
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            Button { sheet = .detail(place.id) } label: {
                HStack(spacing: Stitch.Space.s) {
                    AlbumPhoto(asset: place.displayImage, root: root, thumbnailWidth: 160)
                        .frame(width: 66, height: 66)
                        .background(place.mat)
                        .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.small, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(place.title).font(Stitch.Face.headline).foregroundStyle(Stitch.ink).lineLimit(2)
                        Text([place.category, status].joined(separator: " · ")).font(Stitch.Face.footnote).foregroundStyle(Stitch.inkSoft)
                        if !place.sourceURL.isEmpty { Text(place.sourceLabel).font(Stitch.Face.caption).foregroundStyle(Stitch.inkSoft) }
                    }
                    Spacer(minLength: 0)
                    Menu {
                        Button("Für mich", systemImage: "checkmark") { approve() }
                        Button("Auf Tag legen", systemImage: "calendar") { addingDay = true }
                        Button("Bearbeiten", systemImage: "pencil") { sheet = .add(place) }
                        Button("Ausblenden", systemImage: "eye.slash") { store.deferPlace(place) }
                        Button("Löschen", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    } label: {
                        Image(systemName: "ellipsis").font(.body.weight(.semibold)).foregroundStyle(Stitch.ink).frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                    }
                    .accessibilityLabel("Mehr für \(place.title)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Stitch.Space.s)
                .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
                .stitchElevation(.pinned)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(place.title), \(place.category)")
            .accessibilityIdentifier("native-idea-\(place.id)")
            .contextMenu {
                Button("Für mich", systemImage: "checkmark", action: approve)
                Button("Ausblenden", systemImage: "eye.slash") { store.deferPlace(place) }
            }
            imageStatusControl
                .sheet(isPresented: Binding(
                    get: { resolutionCandidates != nil },
                    set: { if !$0 { resolutionCandidates = nil } }
                )) {
                    resolutionSheet
                }
        }
        .sheet(isPresented: $addingDay) {
            DayChoiceSheet(place: place, store: store) { addingDay = false }
        }
        .overlay(alignment: .topLeading) {
            if newIdeas?.order.contains(place.id) == true {
                NewBadge().padding(Stitch.Space.xs)
            }
        }
        .modifier(IdeaDeleteConfirmation(place: place, store: store, isPresented: $confirmDelete))
        .onDisappear { imageTask?.cancel() }
    }

    private var status: String {
        if let day = place.plannedDate { return store.tripCalendar.shortDate(day) }
        return place.approvals.isEmpty ? "noch offen" : "beschlossen"
    }

    @ViewBuilder private var imageStatusControl: some View {
        switch store.placeImageStatus(for: place.id) {
        case .idle, .ready:
            EmptyView()
        case .resolvingPlace:
            imageStatus("Ort wird gesucht …")
        case .loadingPhoto:
            imageStatus("Bild wird gesucht …")
        case .deferred(let retryAfter):
            imageStatus("Bildsuche wartet \(Int(retryAfter.rounded())) s …")
        case .notFound:
            HStack {
                imageStatus("Kein passender Treffer")
                Spacer()
                editPlaceButton
            }
        case .needsReview(let candidates, _):
            if candidates.isEmpty {
                HStack {
                    imageStatus("Ort bitte ergänzen")
                    Spacer()
                    editPlaceButton
                }
            } else {
                HStack {
                    imageStatus("Ort bitte auswählen")
                    Spacer()
                    Button("Ort auswählen") { resolutionCandidates = candidates }
                        .font(.caption.weight(.semibold))
                        .accessibilityIdentifier("native-resolve-\(place.id)")
                }
            }
        case .failed(let retryable):
            if retryable {
                HStack {
                    imageStatus("Suche fehlgeschlagen")
                    Spacer()
                    Button("Erneut versuchen") { retryImage() }
                        .font(.caption.weight(.semibold))
                        .accessibilityIdentifier("native-retry-image-\(place.id)")
                }
            } else {
                HStack {
                    imageStatus("Kein passender Treffer")
                    Spacer()
                    editPlaceButton
                }
            }
        }
    }

    private func imageStatus(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Stitch.inkSoft)
            .accessibilityIdentifier("native-image-status-\(place.id)")
    }

    private var editPlaceButton: some View {
        Button("Ort bearbeiten") { sheet = .add(place) }
            .font(.caption.weight(.semibold))
            .accessibilityIdentifier("native-resolve-\(place.id)")
    }

    private var resolutionSheet: some View {
        NavigationStack {
            List(resolutionCandidates ?? []) { candidate in
                Button {
                    Task {
                        await store.acceptPlaceResolution(placeID: place.id, candidate: candidate)
                        resolutionCandidates = nil
                    }
                } label: {
                    VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                        Text(candidate.title).font(.body.weight(.medium)).foregroundStyle(Stitch.ink)
                        if !candidate.address.isEmpty {
                            Text(candidate.address).font(.caption).foregroundStyle(Stitch.inkSoft)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("native-resolution-candidate-\(candidate.id)")
            }
            .navigationTitle("Ort auswählen")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { resolutionCandidates = nil } } }
        }
    }

    private func retryImage() {
        imageTask?.cancel()
        imageTask = Task { await store.refreshPlaceImage(id: place.id, force: true) }
    }

    private func approve() {
        let decided = store.decided(place, approve: true)
        _ = store.upsert(decided)
    }
}

/// Tag wählen (Figma 17): Name des Ortes, Frage, Karte mit den Reisetagen (Häkchen am gewählten), „Noch offen lassen“.
/// Ein Tipp auf einen Tag übernimmt ihn sofort und schließt das Blatt.
struct DayChoiceSheet: View {
    let place: Place
    let store: AlbumStore
    let close: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            PlaceSheetHeader(title: "Tag auswählen", onBack: close, onClose: close)
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.m) {
                    VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                        Text(place.title).font(Stitch.Face.title()).foregroundStyle(Stitch.ink)
                        Text("Wann möchtet ihr hier vorbeischauen?").font(Stitch.Face.subheadline).foregroundStyle(Stitch.inkSoft)
                    }
                    VStack(spacing: 0) {
                        ForEach(store.tripCalendar.days) { day in
                            Button {
                                store.assign(place, toDate: day)
                                close()
                            } label: {
                                HStack(spacing: Stitch.Space.s) {
                                    Image(systemName: place.plannedDate == day ? "checkmark" : "calendar")
                                        .font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
                                        .frame(width: 24)
                                    Text(store.tripCalendar.dayTitle(day)).font(Stitch.Face.body).foregroundStyle(Stitch.ink)
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, minHeight: Stitch.Size.touch, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(store.tripCalendar.dayTitle(day))
                            .accessibilityAddTraits(place.plannedDate == day ? .isSelected : [])
                            .accessibilityIdentifier("native-day-\(day.rawValue)")
                        }
                    }
                    .stitchCard(.pinned, padding: Stitch.Space.m)
                    Button("Noch offen lassen") {
                        if place.franked { store.assign(place, toDate: nil) }
                        close()
                    }
                    .buttonStyle(StitchButton())
                    .accessibilityIdentifier("native-day-open")
                }
                .padding(.horizontal, Stitch.Space.page).padding(.bottom, Stitch.Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background(PaperBackground())
        .presentationDetents([.medium, .large])
    }
}

enum NativeFABAction {
    case memories
    case camera
    case expenses
    case documents
    case assistant(String?)
}

struct NativeArcFAB: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isOpen: Bool
    let contextLabel: String
    let onAction: (NativeFABAction) -> Void
    let onOpenStateChanged: (Bool) -> Void
    @State private var mode: FanMode = .closed
    @State private var pointerStart: Date?
    @State private var holdTask: Task<Void, Never>?
    @State private var dwellTask: Task<Void, Never>?
    @State private var holdActivated = false
    @State private var cancelled = false
    @State private var candidate: Int?
    @State private var tapHandledByDrag = false
    @State private var tapWaitingForDragEnd = false
    private let hold: TimeInterval = 0.35
    private let dwell: TimeInterval = 0.48

    private enum FanMode: Equatable { case closed, main, sub }
    private let mainPositions: [(CGFloat, CGFloat)] = [(-34, -216), (-86, -162), (-128, -108), (-158, -54), (-170, 0)]
    private let submenuPositions: [(CGFloat, CGFloat)] = [(-41, -165), (-130, -110), (-161, -55), (-170, 0)]
    private var positions: [(CGFloat, CGFloat)] { mode == .sub ? submenuPositions : mainPositions }

    init(
        isOpen: Binding<Bool>,
        contextLabel: String,
        onAction: @escaping (NativeFABAction) -> Void,
        onOpenStateChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _isOpen = isOpen
        self.contextLabel = contextLabel
        self.onAction = onAction
        self.onOpenStateChanged = onOpenStateChanged
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if mode != .closed {
                ForEach(0..<(mode == .sub ? 4 : 5), id: \.self) { index in
                    fanNode(index: index)
                        .id("native-fan-node-\(index)")
                }
            }
            Button(action: buttonTap) {
                Image(systemName: mode == .closed ? "sparkles" : "xmark")
                    .font(.title3.weight(.semibold))
                    .frame(width: 56, height: 56)
                    .foregroundStyle(Stitch.card)
                    .background(Stitch.ink, in: Circle())
                    .stitchElevation(.floating)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .highPriorityGesture(dragGesture)
            .accessibilityLabel(mode == .closed ? "Aktionen öffnen" : "Aktionen schließen")
            .accessibilityHint("Öffnet Assistent, Kamera, Erinnerungen, Ausgaben und Unterlagen")
            .accessibilityIdentifier("native-fab")
            .accessibilityAddTraits(.isButton)
        }
        .frame(width: 220, height: 272, alignment: .bottomTrailing)
        .overlay(alignment: .topTrailing) {
            if mode == .sub {
                Label(contextLabel, systemImage: "map")
                    .font(Stitch.Face.caption)
                    .foregroundStyle(Stitch.ink)
                    .fixedSize()
                    .padding(.horizontal, Stitch.Space.s)
                    .frame(minHeight: Stitch.Space.xl)
                    .background(Stitch.card, in: Capsule())
                    .stitchElevation(.pinned)
                    .offset(y: 12)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        // Haptik wie im Prototyp: Öffnen und Wechsel ins KI-Untermenü mittel, Schließen leicht,
        // Überfahren eines Knotens als Auswahl.
        .sensoryFeedback(trigger: mode) { old, new in
            switch (old, new) {
            case (.closed, .main), (.main, .sub): .impact(weight: .medium)
            case (_, .closed): .impact(weight: .light)
            default: nil
            }
        }
        .sensoryFeedback(.selection, trigger: candidate) { _, new in new != nil }
        .onDisappear { cancelGestures() }
        .onChange(of: isOpen) { _, open in
            if !open, mode != .closed { closeMenu() }
        }
    }

    @ViewBuilder private func fanNode(index: Int) -> some View {
        let isSubmenu = mode == .sub
        let spec = fanNodeSpec(index: index, submenu: isSubmenu)
        let hint = !isSubmenu && index == 0 ? "Öffnet Plan heute, Essen und Regen" : ""
        let node = Button(action: { commitFanNode(index) }) {
            Image(systemName: spec.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(spec.green ? Stitch.card : Stitch.ink)
                .frame(width: 52, height: 52)
                .background(spec.green ? Stitch.ink : Stitch.card, in: Circle())
                .overlay(Circle().strokeBorder(candidate == index ? Stitch.action : Stitch.line, lineWidth: candidate == index ? 2 : 1))
                .stitchElevation(.object)
        }
        .buttonStyle(.plain)
        .frame(width: 52, height: 52)
        .contentShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spec.title)
        .accessibilityIdentifier(spec.id)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
        .overlay(alignment: .trailing) {
            // Im KI-Untermenü ist der KI-Knoten aktiv: Schildchen grün gefüllt, wie im Prototyp.
            let active = isSubmenu && spec.green
            HStack(spacing: Stitch.Space.xxs) {
                Text(spec.title)
                if spec.green {
                    Text("KI")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(active ? Stitch.ink : Stitch.card)
                        .padding(.horizontal, Stitch.Space.xs)
                        .frame(minHeight: 20)
                        .background(active ? Stitch.card : Stitch.ink, in: Capsule())
                }
            }
                .font(Stitch.Face.caption)
                .foregroundStyle(active ? Stitch.card : Stitch.ink)
                .fixedSize(horizontal: true, vertical: false)
                .lineLimit(1)
                .padding(.horizontal, Stitch.Space.s)
                .frame(minHeight: Stitch.Space.xl)
                .background(active ? Stitch.ink : Stitch.card, in: Capsule())
                .stitchElevation(.pinned)
                .offset(x: -62)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .position(x: 192 + positions[index].0, y: 244 + positions[index].1)
        .opacity(mode == .closed ? 0 : 1)
        .scaleEffect(mode == .closed ? 0.84 : 1)
        .allowsHitTesting(mode != .closed)
        .animation(reduceMotion ? nil : Stitch.Motion.press, value: mode)
        node
    }

    private func fanNodeSpec(index: Int, submenu: Bool) -> (icon: String, title: String, id: String, green: Bool) {
        if submenu {
            switch index {
            case 0: return ("sparkles", "Reise fragen", "native-fan-sub-ai", true)
            case 1: return ("calendar", "Plan für heute", "native-fan-sub-plan", false)
            case 2: return ("fork.knife", "Essen in der Nähe", "native-fan-sub-food", false)
            default: return ("cloud.rain", "Falls es regnet", "native-fan-sub-rain", false)
            }
        }
        switch index {
        case 0: return ("sparkles", "Reise fragen", "native-fan-ai", true)
        case 1: return ("camera", "Kamera", "native-fan-camera", false)
        case 2: return ("photo.stack", "Erinnerungen", "native-fan-mem", false)
        case 3: return ("eurosign.circle", "Ausgaben", "native-fan-exp", false)
        default: return ("doc.text", "Unterlagen", "native-fan-doc", false)
        }
    }

    private func commitFanNode(_ index: Int) {
        switch mode {
        case .main:
            switch index {
            case 0: switchToSub()
            case 1: commit(.camera)
            case 2: commit(.memories)
            case 3: commit(.expenses)
            case 4: commit(.documents)
            default: break
            }
        case .sub:
            switch index {
            case 0: commit(.assistant(nil))
            case 1: commit(.assistant("Plane den heutigen Tag für uns."))
            case 2: commit(.assistant("Welche Essenstipps aus unseren Ideen passen heute?"))
            case 3: commit(.assistant("Was können wir heute bei Regen unternehmen?"))
            default: break
            }
        case .closed: break
        }
    }

    private func toggleByAccessibility() {
        if mode == .closed { openMain() } else { closeMenu() }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pointerStart == nil {
                    pointerStart = Date()
                    holdActivated = false
                    cancelled = false
                    tapHandledByDrag = false
                    tapWaitingForDragEnd = false
                    holdTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(Int(hold * 1_000)))
                        guard !Task.isCancelled, pointerStart != nil, !cancelled else { return }
                        holdActivated = true
                        openMain()
                    }
                }
                if !holdActivated && hypot(value.translation.width, value.translation.height) > 10 {
                    cancelled = true
                    holdTask?.cancel()
                    return
                }
                guard mode != .closed else { return }
                updateHover(value.translation)
                if candidate == 0 && mode == .main && dwellTask == nil {
                    dwellTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(Int(dwell * 1_000)))
                        guard !Task.isCancelled, holdActivated, candidate == 0, mode == .main else { return }
                        switchToSub()
                        dwellTask = nil
                    }
                }
            }
            .onEnded { value in
                let wasHold = holdActivated
                let hovered = candidate
                let moved = hypot(value.translation.width, value.translation.height) > 10
                holdTask?.cancel(); holdTask = nil
                dwellTask?.cancel(); dwellTask = nil
                if wasHold, let hovered, moved { commitCandidate(hovered) }
                else if !wasHold && !cancelled && !moved {
                    if tapWaitingForDragEnd {
                        tapWaitingForDragEnd = false
                    } else {
                        tapHandledByDrag = true
                    }
                    toggleByAccessibility()
                }
                pointerStart = nil
                holdActivated = false
                cancelled = false
                candidate = nil
            }
    }

    private func buttonTap() {
        if tapHandledByDrag {
            tapHandledByDrag = false
        } else if pointerStart != nil {
            tapWaitingForDragEnd = true
        } else {
            toggleByAccessibility()
        }
    }

    private func openMain() {
        withAnimation(reduceMotion ? nil : Stitch.Motion.press) { mode = .main }
        isOpen = true
        onOpenStateChanged(true)
    }

    private func switchToSub() {
        withAnimation(reduceMotion ? nil : Stitch.Motion.press) { mode = .sub }
        isOpen = true
        onOpenStateChanged(true)
        candidate = nil
    }

    private func closeMenu() {
        holdTask?.cancel(); dwellTask?.cancel()
        withAnimation(reduceMotion ? nil : Stitch.Motion.press) { mode = .closed }
        candidate = nil
        isOpen = false
        onOpenStateChanged(false)
    }

    private func updateHover(_ translation: CGSize) {
        let nearest = positions.enumerated().min { lhs, rhs in
            hypot(translation.width - lhs.element.0, translation.height - lhs.element.1)
                < hypot(translation.width - rhs.element.0, translation.height - rhs.element.1)
        }
        guard let nearest, hypot(translation.width - nearest.element.0, translation.height - nearest.element.1) <= 58 else {
            candidate = nil
            dwellTask?.cancel(); dwellTask = nil
            return
        }
        let previous = candidate
        candidate = nearest.offset
        if previous != candidate {
            dwellTask?.cancel()
            dwellTask = nil
        }
    }

    private func commitCandidate(_ index: Int) {
        switch mode {
        case .main:
            switch index { case 0: switchToSub(); case 1: commit(.camera); case 2: commit(.memories); case 3: commit(.expenses); case 4: commit(.documents); default: break }
        case .sub:
            switch index {
            case 0: commit(.assistant(nil))
            case 1: commit(.assistant("Plane den heutigen Tag für uns."))
            case 2: commit(.assistant("Welche Essenstipps aus unseren Ideen passen heute?"))
            case 3: commit(.assistant("Was können wir heute bei Regen unternehmen?"))
            default: break
            }
        case .closed: break
        }
    }

    private func commit(_ action: NativeFABAction) {
        closeMenu()
        onAction(action)
    }

    private func cancelGestures() {
        holdTask?.cancel(); dwellTask?.cancel()
        pointerStart = nil; candidate = nil; holdActivated = false; cancelled = true
        tapHandledByDrag = false; tapWaitingForDragEnd = false
        mode = .closed
        isOpen = false
        onOpenStateChanged(false)
    }
}

extension AlbumStore {
    /// Reisename für Überschriften und Chips. Das Modell kennt noch keinen Namen; mit den flexiblen Reisen (B1)
    /// kommt er aus der Reise selbst. Bis dahin gibt es genau eine Reise.
    /// Name der Reise aus den Reisedaten. Blank trips must not inherit a
    /// destination from the historical Prague fixture.
    var tripName: String {
        let title = data.trip.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? (data.trip.destination?.nilIfEmpty ?? "Deine Reise") : title
    }
}
