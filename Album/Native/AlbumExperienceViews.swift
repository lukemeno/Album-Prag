import SwiftUI
import MapKit

struct NativeHomeView: View {
    @Environment(AlbumStore.self) private var store
    let namespace: Namespace.ID
    let openTrip: () -> Void

    private var heroAsset: PlaceImageAsset {
        store.franked.first(where: { $0.displayImage != nil })?.displayImage
            ?? store.places.first(where: { $0.displayImage != nil })?.displayImage
            ?? .bundled(name: "imgPhotoCharlesBridge")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                    HStack {
                        Text("Album").font(Stitch.Face.wordmark()).foregroundStyle(Stitch.red)
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
                            ZStack(alignment: .bottomLeading) {
                                AlbumPhoto(asset: heroAsset, root: store.root)
                                LinearGradient(colors: [.clear, Stitch.ink.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                                VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Prag").font(Stitch.Face.display(38, relativeTo: .largeTitle)).foregroundStyle(.white)
                                                .matchedGeometryEffect(id: "trip-title", in: namespace)
                                            Text("4.–9. Oktober 2026").font(.subheadline).foregroundStyle(.white.opacity(0.9))
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right").font(.headline.weight(.semibold)).foregroundStyle(.white)
                                    }
                                    Label(store.data.trip.hotel, systemImage: "bed.double")
                                        .font(.footnote).foregroundStyle(.white.opacity(0.9))
                                }
                                .padding(Stitch.Space.l)
                            }
                            .frame(height: 236)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
    let onNativeShare: () -> Void
    let onFanOpenChanged: (Bool) -> Void
    @State private var fanOpen = false

    var body: some View {
        ZStack {
            Group {
                switch section {
                case .plan: NativePlanView(sheet: $sheet)
                case .ideas: NativeIdeasView(sheet: $sheet)
                case .map: TripMapView().ignoresSafeArea(edges: .bottom)
                case .group: NativeGroupView(sheet: $sheet, onAssistant: onAssistant)
                }
            }
            .accessibilityHidden(fanOpen)
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
                    .matchedGeometryEffect(id: "trip-title", in: namespace)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
#if DEBUG && targetEnvironment(simulator)
                if ProcessInfo.processInfo.environment["ALBUM_QA_NATIVE_SHARE"] == "1" {
                    Button("QA Share", systemImage: "square.and.arrow.up", action: onNativeShare)
                        .labelStyle(.iconOnly)
                        .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                        .accessibilityIdentifier("qa-native-share")
                }
#endif
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
#if DEBUG && targetEnvironment(simulator)
                    if ProcessInfo.processInfo.environment["ALBUM_QA_NATIVE_SHARE"] == "1" {
                        Button("QA Share", systemImage: "square.and.arrow.up", action: onNativeShare)
                            .accessibilityIdentifier("qa-native-share")
                    }
#endif
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
        .overlay {
            if fanOpen {
                Color.black.opacity(0.10)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { fanOpen = false }
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            NativeArcFAB(isOpen: $fanOpen, onAction: { action in
                switch action {
                case .memories: sheet = .memories
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
                .accessibilityIdentifier(item.accessibilityID)
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
                    Text("Dein Plan").font(Stitch.Face.display(32, relativeTo: .largeTitle)).foregroundStyle(Stitch.ink)
                    Text("Orte, die ihr gemeinsam beschlossen habt.").font(.subheadline).foregroundStyle(Stitch.inkSoft)
                }
                dayStrip
                if let next = stops.first(where: { !$0.place.visited }) {
                    NativeNextStopCard(stop: next, root: store.root,
                                       onOpen: { sheet = .detail(next.place.id) },
                                       onVisited: { var copy = next.place; copy.visited = true; _ = store.upsert(copy) },
                                       onRoute: { openWalkingRoute(to: next.place) })
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
                            NativeTimelineRow(number: index + 1, stop: stop, root: store.root, walkingMinutes: walkingMinutes,
                                              onOpen: { sheet = .detail(stop.place.id) },
                                              onVisited: { var copy = stop.place; copy.visited = true; _ = store.upsert(copy) },
                                              onRoute: { openWalkingRoute(to: stop.place) })
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
    let onOpen: () -> Void
    let onVisited: () -> Void
    let onRoute: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Button(action: onOpen) {
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
            }
            .buttonStyle(.plain)
            HStack(spacing: Stitch.Space.s) {
                if stop.place.coordinate != nil {
                    Button("Route", systemImage: "figure.walk", action: onRoute).buttonStyle(StitchButton(primary: true))
                        .accessibilityIdentifier("native-next-route")
                }
                if stop.place.franked && !stop.place.visited {
                    Button("Besucht", systemImage: "checkmark", action: onVisited).buttonStyle(StitchButton())
                        .accessibilityIdentifier("native-next-visited")
                }
            }
        }
        .padding(Stitch.Space.s)
        .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous).strokeBorder(Stitch.rule))
        .stitchElevation(.pinned)
        .accessibilityLabel("Nächster Halt: \(stop.place.title)")
    }
}

struct NativeTimelineRow: View {
    let number: Int
    let stop: PlanStop
    let root: URL
    let walkingMinutes: Int?
    let onOpen: () -> Void
    let onVisited: () -> Void
    let onRoute: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            Button(action: onOpen) {
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
        }
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
                    Text("Ideen").font(Stitch.Face.display(32, relativeTo: .largeTitle)).foregroundStyle(Stitch.ink)
                        Text("Vorschläge mit Quelle und Foto.").font(.subheadline).foregroundStyle(Stitch.inkSoft)
                    }
                    Spacer()
                    Menu {
                        Button("Entscheiden", systemImage: "hand.tap") { sheet = .inbox }
                        Button("Sammlung", systemImage: "tray.full") { sheet = .collection }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                    }
                    .accessibilityLabel("Ideenbereiche")
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
        return Array(Set(names.filter { !$0.isEmpty && $0.caseInsensitiveCompare("Wir") != .orderedSame })).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                    Text("Gruppe").font(Stitch.Face.display(32, relativeTo: .largeTitle)).foregroundStyle(Stitch.ink)
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
                    NativeGroupLink(title: "Sammlung", subtitle: "Links und Nachrichten der Gruppe", icon: "tray.full") { sheet = .collection }
                        .accessibilityIdentifier("native-group-collection")
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
    case memories
    case expenses
    case documents
    case assistant(String?)
}

struct NativeArcFAB: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isOpen: Bool
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
    private let positions: [(CGFloat, CGFloat)] = [(-41, -165), (-130, -110), (-161, -55), (-170, 0)]

    init(
        isOpen: Binding<Bool>,
        onAction: @escaping (NativeFABAction) -> Void,
        onOpenStateChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _isOpen = isOpen
        self.onAction = onAction
        self.onOpenStateChanged = onOpenStateChanged
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ForEach(0..<4, id: \.self) { index in
                fanNode(index: index)
                    .id("native-fan-node-\(index)")
            }
            Button(action: buttonTap) {
                Image(systemName: mode == .closed ? "plus" : "xmark")
                    .font(.title3.weight(.bold))
                    .frame(width: 56, height: 56)
                    .foregroundStyle(Stitch.onAccent)
                    .background(Stitch.redFill, in: Circle())
                    .shadow(color: Stitch.ink.opacity(0.24), radius: 14, y: 8)
                    .rotationEffect(.degrees(mode == .closed ? 0 : 90))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .highPriorityGesture(dragGesture)
            .accessibilityLabel(mode == .closed ? "Aktionen öffnen" : "Aktionen schließen")
            .accessibilityHint("Öffnet Assistent, Erinnerungen, Ausgaben und Unterlagen")
            .accessibilityIdentifier("native-fab")
            .accessibilityAddTraits(.isButton)
        }
        .frame(width: 220, height: 220, alignment: .bottomTrailing)
        .sensoryFeedback(.impact(weight: .light), trigger: mode != .closed)
        .onDisappear { cancelGestures() }
        .onChange(of: isOpen) { _, open in
            if !open, mode != .closed { closeMenu() }
        }
    }

    @ViewBuilder private func fanNode(index: Int) -> some View {
        let isSubmenu = mode == .sub
        let spec = fanNodeSpec(index: index, submenu: isSubmenu)
        let node = Button(action: { commitFanNode(index) }) {
            Image(systemName: spec.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(spec.green ? Stitch.onAccent : Stitch.red)
                .frame(width: 52, height: 52)
                .background(spec.green ? Stitch.redFill : Stitch.card, in: Circle())
                .overlay(Circle().strokeBorder(candidate == index ? Stitch.red : Stitch.rule, lineWidth: candidate == index ? 2 : 1))
                .shadow(color: Stitch.ink.opacity(0.18), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            Text(spec.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Stitch.ink)
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .background(Stitch.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Stitch.rule))
                .offset(x: -62)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .position(x: 192 + positions[index].0, y: 192 + positions[index].1)
        .opacity(mode == .closed ? 0 : 1)
        .scaleEffect(mode == .closed ? 0.84 : 1)
        .allowsHitTesting(mode != .closed)
        .accessibilityHidden(mode == .closed)
        .accessibilityLabel(spec.title)
        .accessibilityIdentifier(spec.id)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: mode)

        if !isSubmenu && index == 0 {
            node
                .accessibilityHint("Öffnet Plan heute, Essen und Regen")
                .accessibilityAction(named: Text("Plan heute")) {
                    commit(.assistant("Plane den heutigen Tag für uns."))
                }
                .accessibilityAction(named: Text("Essen")) {
                    commit(.assistant("Welche Essenstipps aus unseren Ideen passen heute?"))
                }
                .accessibilityAction(named: Text("Regen")) {
                    commit(.assistant("Was können wir heute bei Regen in Prag unternehmen?"))
                }
                .accessibilityIdentifier(spec.id)
                .accessibilityAddTraits(.isButton)
        } else {
            node
        }
    }

    private func fanNodeSpec(index: Int, submenu: Bool) -> (icon: String, title: String, id: String, green: Bool) {
        if submenu {
            switch index {
            case 0: return ("sparkles", "Assistent", "native-fan-sub-ai", true)
            case 1: return ("calendar", "Plan heute", "native-fan-sub-plan", false)
            case 2: return ("fork.knife", "Essen", "native-fan-sub-food", false)
            default: return ("cloud.rain", "Regen", "native-fan-sub-rain", false)
            }
        }
        switch index {
        case 0: return ("sparkles", "Assistent", "native-fan-ai", true)
        case 1: return ("photo.stack", "Erinnerungen", "native-fan-mem", false)
        case 2: return ("eurosign.circle", "Ausgaben", "native-fan-exp", false)
        default: return ("doc.text", "Unterlagen", "native-fan-doc", false)
        }
    }

    private func commitFanNode(_ index: Int) {
        switch mode {
        case .main:
            switch index {
            case 0: switchToSub()
            case 1: commit(.memories)
            case 2: commit(.expenses)
            case 3: commit(.documents)
            default: break
            }
        case .sub:
            switch index {
            case 0: commit(.assistant(nil))
            case 1: commit(.assistant("Plane den heutigen Tag für uns."))
            case 2: commit(.assistant("Welche Essenstipps aus unseren Ideen passen heute?"))
            case 3: commit(.assistant("Was können wir heute bei Regen in Prag unternehmen?"))
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
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { mode = .main }
        isOpen = true
        onOpenStateChanged(true)
    }

    private func switchToSub() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { mode = .sub }
        isOpen = true
        onOpenStateChanged(true)
        candidate = nil
    }

    private func closeMenu() {
        holdTask?.cancel(); dwellTask?.cancel()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { mode = .closed }
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
            switch index { case 0: switchToSub(); case 1: commit(.memories); case 2: commit(.expenses); case 3: commit(.documents); default: break }
        case .sub:
            switch index {
            case 0: commit(.assistant(nil))
            case 1: commit(.assistant("Plane den heutigen Tag für uns."))
            case 2: commit(.assistant("Welche Essenstipps aus unseren Ideen passen heute?"))
            case 3: commit(.assistant("Was können wir heute bei Regen in Prag unternehmen?"))
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
