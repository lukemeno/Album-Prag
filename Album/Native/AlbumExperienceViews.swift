import SwiftUI
import MapKit

struct NativeHomeView: View {
    @Environment(AlbumStore.self) private var store
    let namespace: Namespace.ID
    let openTrip: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                    HStack {
                        Text("Album").font(.system(size: 30, weight: .medium, design: .serif)).foregroundStyle(Stitch.red)
                        Spacer()
                        Button { openTrip() } label: { Image(systemName: "person.2") }
                            .buttonStyle(HeaderIconButton())
                            .accessibilityLabel("Reisegruppe")
                            .accessibilityHint("Öffnet die Reise")
                    }
                    .padding(.top, Stitch.Space.s)

                    VStack(alignment: .leading, spacing: Stitch.Space.s) {
                        Text("Deine Reise").font(.caption.weight(.semibold)).foregroundStyle(Stitch.inkSoft).textCase(.uppercase)
                        Button(action: openTrip) {
                            VStack(alignment: .leading, spacing: Stitch.Space.m) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                                        Text("Prag").font(.system(size: 38, weight: .semibold, design: .serif)).foregroundStyle(Stitch.ink)
                                            .matchedGeometryEffect(id: "trip-title", in: namespace)
                                        Text("4.–9. Oktober 2026").font(.subheadline).foregroundStyle(Stitch.inkSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right").font(.headline.weight(.semibold)).foregroundStyle(Stitch.red)
                                }
                                HStack(spacing: Stitch.Space.xs) {
                                    Label(store.data.trip.hotel, systemImage: "bed.double")
                                    Spacer(minLength: 0)
                                    Text("Reise öffnen").font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.red)
                                }
                                .font(.footnote)
                                .foregroundStyle(Stitch.inkSoft)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Stitch.Space.l)
                            .background(Stitch.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Stitch.rule))
                        }
                        .buttonStyle(.plain)
                        .matchedGeometryEffect(id: "trip-card", in: namespace)
                        .accessibilityIdentifier("native-trip-prag")
                        .accessibilityLabel("Prag, 4. bis 9. Oktober 2026")
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

struct NativeTripExperience: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var section: NativeTripSection
    @Binding var sheet: NativeSheet?
    let namespace: Namespace.ID
    let onHome: () -> Void
    let onAssistant: (String?) -> Void

    var body: some View {
        ZStack {
            switch section {
            case .plan: NativePlanView(sheet: $sheet)
            case .ideas: NativeIdeasView(sheet: $sheet)
            case .map: TripMapView().ignoresSafeArea(edges: .bottom)
            case .group: NativeGroupView(sheet: $sheet, onAssistant: onAssistant)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: Stitch.Space.s) {
                Button(action: onHome) {
                    Image(systemName: "chevron.left").frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Album-Übersicht")
                Text(section == .map ? "Karte" : "Prag")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Stitch.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { onAssistant(nil) } label: {
                    Image(systemName: "sparkles").frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Stitch.red)
                .accessibilityLabel("Reise-Assistent")
                .accessibilityIdentifier("assistant-launch")
                Menu {
                    Button("Neue Idee", systemImage: "plus") { sheet = .add(Place(title: "", author: store.me)) }
                    Button("Assistent", systemImage: "sparkles") { onAssistant(nil) }
                    Button("Teilen & Personen", systemImage: "person.2") { sheet = .sharing }
                    Button("Unterlagen", systemImage: "doc.text") { sheet = .documents }
                } label: {
                    Image(systemName: "ellipsis").frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                }
                .accessibilityLabel("Mehr")
                .accessibilityIdentifier("trip-more-menu")
            }
            .padding(.horizontal, Stitch.Space.s)
            .background(Stitch.card.opacity(0.96))
        }
        .background(Stitch.paper.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) {
            NativeArcFAB { action in
                switch action {
                case .newIdea: sheet = .add(Place(title: "", author: store.me))
                case .assistant(let prompt): onAssistant(prompt)
                case .inbox: section = .ideas
                case .documents: sheet = .documents
                }
            }
            .padding(.trailing, Stitch.Space.m)
            .padding(.bottom, 92)
        }
    }
}

struct NativeTripPillBar: View {
    @Binding var selection: NativeTripSection
    var body: some View {
        HStack(spacing: 3) {
            ForEach(NativeTripSection.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.28)) { selection = item }
                } label: {
                    Label(item.rawValue, systemImage: item.icon)
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selection == item ? Stitch.red : Stitch.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(selection == item ? Stitch.paperDeep : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("native-tab-\(item.rawValue.lowercased())")
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Stitch.rule))
        .stitchElevation(.floating)
    }
}

struct NativePlanView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var sheet: NativeSheet?
    @State private var day = TripDates.tripDay() ?? 4

    private var stops: [PlanStop] {
        let window = DayPlanGenerator.windows(flights: store.data.trip.flights ?? [])[day] ?? .init(start: 10 * 60, end: 22 * 60)
        return DayPlanGenerator.timeline(store.plan(for: day), day: day, window: window, hotel: store.hotelCoordinate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                    Text("Dein Plan").font(.system(size: 32, weight: .semibold, design: .serif)).foregroundStyle(Stitch.ink)
                    Text("Orte, die ihr gemeinsam beschlossen habt.").font(.subheadline).foregroundStyle(Stitch.inkSoft)
                }
                dayStrip
                if let next = stops.first(where: { !$0.place.visited }) {
                    NativeNextStopCard(stop: next, root: store.root) { sheet = .detail(next.place.id) }
                }
                VStack(alignment: .leading, spacing: Stitch.Space.s) {
                    Text(TripDates.dayTitle(day)).font(.headline).foregroundStyle(Stitch.ink)
                    if stops.isEmpty {
                        VStack(alignment: .leading, spacing: Stitch.Space.s) {
                            Image(systemName: "calendar.badge.plus").font(.title2).foregroundStyle(Stitch.red)
                            Text("Noch nichts geplant").font(.headline)
                            Text("Stimmt eine Idee ab oder fügt einen Ort hinzu.").font(.subheadline).foregroundStyle(Stitch.inkSoft)
                            Button("Idee einwerfen", systemImage: "plus") { sheet = .add(Place(title: "", author: store.me)) }.buttonStyle(StitchButton(primary: true))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .stitchCard()
                    } else {
                        ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                            let previous = index == 0 ? store.hotelCoordinate : (stops[index - 1].place.coordinate ?? store.hotelCoordinate)
                            let walkingMinutes = stop.place.coordinate.map { DayPlanGenerator.walkingMinutes(DayPlanGenerator.distance(previous, $0)) }
                            NativeTimelineRow(number: index + 1, stop: stop, root: store.root, walkingMinutes: walkingMinutes) { sheet = .detail(stop.place.id) }
                        }
                    }
                }
            }
            .padding(.horizontal, Stitch.Space.page)
            .padding(.top, Stitch.Space.m)
            .padding(.bottom, 128)
        }
        .scrollIndicators(.hidden)
        .background(Stitch.paper.ignoresSafeArea())
    }

    private var dayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Stitch.Space.xs) {
                ForEach(DayPlanGenerator.days, id: \.self) { value in
                    Button { day = value } label: {
                        VStack(spacing: 2) {
                            Text("Okt").font(.caption2.weight(.medium))
                            Text(String(value)).font(.headline.weight(.semibold))
                        }
                        .foregroundStyle(day == value ? Stitch.onAccent : Stitch.ink)
                        .frame(width: 52, height: 54)
                        .background(day == value ? Stitch.redFill : Stitch.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Stitch.rule))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TripDates.dayTitle(value))
                    .accessibilityAddTraits(day == value ? .isSelected : [])
                }
            }
        }
    }
}

struct NativeNextStopCard: View {
    let stop: PlanStop
    let root: URL
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Stitch.Space.m) {
                AlbumPhoto(asset: stop.place.displayImage, root: root, thumbnailWidth: 180)
                    .frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                    Text("Als Nächstes").font(.caption.weight(.semibold)).foregroundStyle(Stitch.red)
                    Text(stop.place.title).font(.headline).foregroundStyle(Stitch.ink).lineLimit(2)
                    Text(stop.slot.capitalized + (stop.note.map { " · \($0)" } ?? ""))
                        .font(.footnote).foregroundStyle(Stitch.inkSoft).lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Stitch.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .stitchCard(.pinned)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Nächster Halt: \(stop.place.title)")
    }
}

struct NativeTimelineRow: View {
    let number: Int
    let stop: PlanStop
    let root: URL
    let walkingMinutes: Int?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Stitch.Space.s) {
                VStack(spacing: Stitch.Space.xs) {
                    Text("\(number)").font(.caption.weight(.bold)).foregroundStyle(Stitch.red)
                    Rectangle().fill(Stitch.rule).frame(width: 1, height: 48)
                }
                AlbumPhoto(asset: stop.place.displayImage, root: root, thumbnailWidth: 120)
                    .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(stop.place.title).font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
                    Text(stop.slot.capitalized + (walkingMinutes.map { " · ca. \($0) Min. zu Fuß · Schätzung" } ?? ""))
                        .font(.footnote).foregroundStyle(Stitch.inkSoft)
                    if let note = stop.note { Text(note).font(.caption).foregroundStyle(Stitch.red) }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, Stitch.Space.xs)
        .accessibilityLabel("\(stop.place.title), \(stop.slot)")
    }
}

struct NativeIdeasView: View {
    @Environment(AlbumStore.self) private var store
    @Binding var sheet: NativeSheet?
    @State private var category = "Alle"
    private let categories = ["Alle", "Essen & Trinken", "Sehenswert", "Aussicht", "Shopping", "Idee"]

    private var ideas: [Place] {
        var seen = Set<String>()
        return (store.inbox + store.franked.filter { $0.day == nil })
            .filter { category == "Alle" || $0.category == category }
            .filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Stitch.Space.l) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                        Text("Ideen").font(.system(size: 32, weight: .semibold, design: .serif)).foregroundStyle(Stitch.ink)
                        Text("Vorschläge mit Quelle und Foto.").font(.subheadline).foregroundStyle(Stitch.inkSoft)
                    }
                    Spacer()
                    Button { sheet = .add(Place(title: "", author: store.me)) } label: { Image(systemName: "plus") }
                        .buttonStyle(HeaderIconButton())
                        .accessibilityLabel("Neue Idee")
                        .accessibilityIdentifier("native-new-place")
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Stitch.Space.xs) {
                        ForEach(categories, id: \.self) { item in
                            Button(item) { category = item }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(category == item ? Stitch.onAccent : Stitch.ink)
                                .padding(.horizontal, Stitch.Space.s).frame(minHeight: 36)
                                .background(category == item ? Stitch.redFill : Stitch.card, in: Capsule())
                                .overlay(Capsule().strokeBorder(Stitch.rule))
                                .buttonStyle(.plain)
                        }
                    }
                }
                if ideas.isEmpty {
                    VStack(alignment: .leading, spacing: Stitch.Space.s) {
                        Image(systemName: "lightbulb").font(.title2).foregroundStyle(Stitch.red)
                        Text("Noch keine Ideen in dieser Kategorie.").font(.headline)
                        Button("Idee hinzufügen", systemImage: "plus") { sheet = .add(Place(title: "", author: store.me)) }.buttonStyle(StitchButton(primary: true))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .stitchCard()
                } else {
                    LazyVStack(spacing: Stitch.Space.s) {
                        ForEach(ideas) { place in NativeIdeaRow(place: place, root: store.root, store: store, sheet: $sheet) }
                    }
                }
            }
            .padding(.horizontal, Stitch.Space.page)
            .padding(.top, Stitch.Space.m)
            .padding(.bottom, 128)
        }
        .scrollIndicators(.hidden)
        .background(Stitch.paper.ignoresSafeArea())
    }
}

private struct NativeIdeaRow: View {
    let place: Place
    let root: URL
    let store: AlbumStore
    @Binding var sheet: NativeSheet?
    @State private var addingDay = false
    var body: some View {
        Button { sheet = .detail(place.id) } label: {
            HStack(spacing: Stitch.Space.s) {
                AlbumPhoto(asset: place.displayImage, root: root, thumbnailWidth: 160)
                    .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(place.title).font(.body.weight(.semibold)).foregroundStyle(Stitch.ink).lineLimit(2)
                    Text(place.category).font(.caption.weight(.medium)).foregroundStyle(Stitch.red)
                    if !place.sourceURL.isEmpty { Text(place.sourceLabel).font(.caption).foregroundStyle(Stitch.inkSoft) }
                }
                Spacer(minLength: 0)
                Menu {
                    Button("Für mich", systemImage: "checkmark") { approve() }
                    Button("Auf Tag legen", systemImage: "calendar") { addingDay = true }
                    Button("Bearbeiten", systemImage: "pencil") { sheet = .add(place) }
                    Button("Ausblenden", systemImage: "eye.slash") { store.deferPlace(place) }
                    Button("Löschen", systemImage: "trash", role: .destructive) { var copy = place; copy.deleted = true; _ = store.upsert(copy) }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(Stitch.inkSoft).frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                }
                .accessibilityLabel("Mehr für \(place.title)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Stitch.Space.s)
            .background(Stitch.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Stitch.rule))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Für mich", systemImage: "checkmark", action: approve)
            Button("Ausblenden", systemImage: "eye.slash") { store.deferPlace(place) }
        }
        .sheet(isPresented: $addingDay) {
            NativeDayPicker(place: place, store: store) { addingDay = false }
                .presentationDetents([.medium])
        }
        .accessibilityLabel("\(place.title), \(place.category)")
    }

    private func approve() {
        var decided = store.decided(place, approve: true)
        if decided.day == nil { decided.day = TripDates.tripDay() ?? 4 }
        _ = store.upsert(decided)
    }
}

private struct NativeDayPicker: View {
    let place: Place
    let store: AlbumStore
    let close: () -> Void
    var body: some View {
        NavigationStack {
            List(DayPlanGenerator.days, id: \.self) { day in
                Button(TripDates.dayTitle(day)) { store.assign(place, to: day); close() }
            }
            .navigationTitle("Tag wählen")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen", action: close) } }
        }
    }
}

struct NativeGroupView: View {
    @Environment(AlbumStore.self) private var store
    @Binding var sheet: NativeSheet?
    let onAssistant: (String?) -> Void
    private var travelers: [String] {
        var names = store.data.trip.travelers ?? []
        names.append(store.me)
        names += store.places.flatMap { [$0.author] + $0.approvals }
        return Array(Set(names.filter { !$0.isEmpty && $0.caseInsensitiveCompare("Wir") != .orderedSame })).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                    Text("Gruppe").font(.system(size: 32, weight: .semibold, design: .serif)).foregroundStyle(Stitch.ink)
                    Text(store.isShared ? "Gemeinsam planen und sammeln." : "Lade eure Reisegruppe ein.").font(.subheadline).foregroundStyle(Stitch.inkSoft)
                }
                VStack(alignment: .leading, spacing: Stitch.Space.s) {
                    HStack {
                        Text("Reisende").font(.headline)
                        Spacer()
                        Image(systemName: store.isShared ? "checkmark.icloud" : "iphone").foregroundStyle(Stitch.red)
                    }
                    ForEach(travelers, id: \.self) { name in
                        Label(name == store.me ? "\(name) · du" : name, systemImage: "person.fill")
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2)
                    }
                    Button(store.isShared ? "Einladung teilen" : "Einladung erstellen", systemImage: "person.badge.plus") { sheet = .sharing }
                        .buttonStyle(StitchButton(primary: true))
                        .accessibilityIdentifier("native-group-sharing")
                }
                .stitchCard()

                VStack(alignment: .leading, spacing: Stitch.Space.s) {
                    Text("Verknüpfte Bereiche").font(.headline)
                    NativeGroupLink(title: "Unterlagen", subtitle: "Flüge, Hotel und PDFs", icon: "doc.text") { sheet = .documents }
                        .accessibilityIdentifier("native-group-documents")
                    NativeGroupLink(title: "Ausgaben", subtitle: "Gemeinsame Reisekosten", icon: "eurosign.circle") { sheet = .expenses }
                        .accessibilityIdentifier("native-group-expenses")
                    NativeGroupLink(title: "Erinnerungen", subtitle: "Besuchte Orte und Fotos", icon: "photo.stack") { sheet = .memories }
                        .accessibilityIdentifier("native-group-memories")
                    NativeGroupLink(title: "Reise-Assistent", subtitle: "Fragen und echte Vorschläge", icon: "sparkles") { onAssistant(nil) }
                }
                .stitchCard()

                HStack(spacing: Stitch.Space.s) {
                    Circle().fill(store.syncing ? Stitch.red : Stitch.teal).frame(width: 10, height: 10)
                    Text(store.syncStatus).font(.footnote).foregroundStyle(Stitch.inkSoft)
                }
                .accessibilityLabel("Synchronisierung: \(store.syncStatus)")
            }
            .padding(.horizontal, Stitch.Space.page)
            .padding(.top, Stitch.Space.m)
            .padding(.bottom, 128)
        }
        .scrollIndicators(.hidden)
        .background(Stitch.paper.ignoresSafeArea())
    }
}

private struct NativeGroupLink: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Stitch.Space.s) {
                Image(systemName: icon).foregroundStyle(Stitch.red).frame(width: 40, height: 40).background(Stitch.paperDeep, in: Circle())
                VStack(alignment: .leading, spacing: 2) { Text(title).font(.body.weight(.semibold)); Text(subtitle).font(.caption).foregroundStyle(Stitch.inkSoft) }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
            }
            .foregroundStyle(Stitch.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: Stitch.Size.touch)
    }
}

enum NativeFABAction {
    case newIdea
    case inbox
    case documents
    case assistant(String?)
}

struct NativeArcFAB: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onAction: (NativeFABAction) -> Void
    @State private var open = false
    @State private var began = Date.distantPast
    @State private var candidate: Int?
    @State private var dwellTask: Task<Void, Never>?
    @State private var aiMenu = false
    private let hold: TimeInterval = 0.35
    private let dwell: TimeInterval = 0.48

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if open {
                node("plus", title: "Neue Idee", index: 0, offset: (-41, -165)) { onAction(.newIdea) }
                node("tray.full", title: "Ideen prüfen", index: 1, offset: (-130, -110)) { onAction(.inbox) }
                node("doc.text", title: "Unterlagen", index: 2, offset: (-161, -55)) { onAction(.documents) }
                node("sparkles", title: "Assistent", index: 3, offset: (-170, 0)) { aiMenu = true }
                if aiMenu {
                    subNode("calendar", title: "Plan heute", id: "native-fan-sub-plan", offset: (-134, -188)) {
                        onAction(.assistant("Plane den heutigen Tag für uns.")); aiMenu = false; open = false
                    }
                    subNode("fork.knife", title: "Essen", id: "native-fan-sub-food", offset: (-83, -224)) {
                        onAction(.assistant("Welche Essenstipps aus unseren Ideen passen heute?")); aiMenu = false; open = false
                    }
                    subNode("cloud.rain", title: "Regen", id: "native-fan-sub-rain", offset: (-28, -245)) {
                        onAction(.assistant("Was können wir heute bei Regen in Prag unternehmen?")); aiMenu = false; open = false
                    }
                }
            }
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { open.toggle() }
            } label: {
                Image(systemName: open ? "xmark" : "plus")
                    .font(.title3.weight(.bold))
                    .frame(width: 56, height: 56)
                    .foregroundStyle(Stitch.onAccent)
                    .background(Stitch.redFill, in: Circle())
                    .shadow(color: Stitch.ink.opacity(0.24), radius: 14, y: 8)
                    .rotationEffect(.degrees(open ? 90 : 0))
            }
            .buttonStyle(.plain)
            .simultaneousGesture(dragGesture)
            .accessibilityLabel(open ? "Aktionen schließen" : "Aktionen öffnen")
            .accessibilityHint("Öffnet Neue Idee, Ideen prüfen, Unterlagen und den Assistenten")
            .accessibilityIdentifier("native-fab")
            .accessibilityAddTraits(.isButton)
        }
        .frame(width: 220, height: 220, alignment: .bottomTrailing)
        .sensoryFeedback(.impact(weight: .light), trigger: open)
        .onDisappear { dwellTask?.cancel() }
    }

    @ViewBuilder private func node(_ icon: String, title: String, index: Int, offset: (CGFloat, CGFloat), action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.body.weight(.semibold)).foregroundStyle(Stitch.red)
                .frame(width: 46, height: 46).background(Stitch.card, in: Circle())
                .overlay(Circle().strokeBorder(candidate == index ? Stitch.red : Stitch.rule, lineWidth: candidate == index ? 2 : 1))
                .shadow(color: Stitch.ink.opacity(0.18), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .offset(x: offset.0, y: offset.1)
        .accessibilityLabel(title)
        .accessibilityIdentifier(["native-fan-exp", "native-fan-mem", "native-fan-doc", "native-fan-ai"][index])
        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
    }

    @ViewBuilder private func subNode(_ icon: String, title: String, id: String, offset: (CGFloat, CGFloat), action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.caption.weight(.semibold)).foregroundStyle(Stitch.red)
                .frame(width: 42, height: 42).background(Stitch.card, in: Circle())
                .overlay(Circle().strokeBorder(Stitch.rule))
                .shadow(color: Stitch.ink.opacity(0.14), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .offset(x: offset.0, y: offset.1)
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if began == .distantPast { began = Date() }
                if Date().timeIntervalSince(began) >= hold && !open {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { open = true }
                }
                guard open else { return }
                let point = value.translation
                let options: [(Int, CGFloat, CGFloat)] = [(0, -41, -165), (1, -130, -110), (2, -161, -55), (3, -170, 0)]
                let nearest = options.min { lhs, rhs in
                    hypot(point.width - lhs.1, point.height - lhs.2) < hypot(point.width - rhs.1, point.height - rhs.2)
                }
                guard let nearest, hypot(point.width - nearest.1, point.height - nearest.2) < 58 else {
                    candidate = nil; dwellTask?.cancel(); return
                }
                if candidate != nearest.0 {
                    candidate = nearest.0
                    dwellTask?.cancel()
                    if nearest.0 == 3 {
                        dwellTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(Int(dwell * 1_000)))
                            guard !Task.isCancelled, candidate == 3 else { return }
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { aiMenu = true }
                            candidate = nil
                        }
                    }
                }
            }
            .onEnded { value in
                defer { began = .distantPast }
                dwellTask?.cancel(); dwellTask = nil
                guard open else { return }
                guard let candidate, abs(value.translation.width) > 12 || abs(value.translation.height) > 12 else { return }
                if candidate != 3 {
                    switch candidate { case 0: onAction(.newIdea); case 1: onAction(.inbox); case 2: onAction(.documents); default: break }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { open = false }
                }
                self.candidate = nil
            }
    }
}
