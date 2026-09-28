import SwiftUI
import MapKit

struct TripMapView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera: MapCameraPosition = .region(.init(center: .init(latitude: 50.087, longitude: 14.423), span: .init(latitudeDelta: 0.035, longitudeDelta: 0.035)))
    @State private var selected: Place?
    @State private var detail: Place?
    @State private var filter = MapFilter.all
    /// Orte, die schon einmal auf der Karte gelandet sind. Nur neue fallen als Stecknadel.
    @AppStorage("album.landedPins") private var landedRaw = ""

    var visible: [Place] { store.franked.filter { $0.coordinate != nil && filter.matches($0.category) } }

    /// Orte eines Tages, verbunden in geplanter Reihenfolge.
    private var dayThreads: [(day: Int, coordinates: [CLLocationCoordinate2D])] {
        (4...9).map { day in (day, store.plan(for: day).filter { filter.matches($0.category) }.compactMap(\.coordinate)) }
            .filter { $0.1.count > 1 }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                    HStack(spacing: Stitch.Space.xs) {
                        ForEach(MapFilter.allCases) { item in
                            Button { withAnimation(.snappy) { filter = item } } label: {
                                HStack(spacing: Stitch.Space.xs) {
                                    if let symbol = item.symbol {
                                        StitchedSymbol(name: symbol, rows: 9, cell: 2, color: filter == item ? Stitch.onAccent : item.thread)
                                    }
                                    Text(item.title).font(.subheadline.weight(.semibold))
                                }
                                .padding(.horizontal, Stitch.Space.m).frame(minHeight: 44)
                                .foregroundStyle(filter == item ? Stitch.onAccent : Stitch.ink)
                                .background(filter == item ? Stitch.redFill : Stitch.card, in: Capsule())
                                .overlay(Capsule().strokeBorder(Stitch.ink.opacity(filter == item ? 0 : 0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(filter == item ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, Stitch.Space.page)
                }
                .scrollIndicators(.hidden)
                .padding(.vertical, Stitch.Space.xs)
                .background(LinenBackground())

            Map(position: $camera) {
                ForEach(dayThreads, id: \.day) { thread in
                    MapPolyline(coordinates: thread.coordinates)
                        .stroke(thread.day % 2 == 0 ? Stitch.cobalt : Stitch.red,
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [8, 7]))
                }
                ForEach(visible) { place in
                    if let coordinate = place.coordinate {
                        Annotation(place.title, coordinate: coordinate, anchor: .bottom) {
                            Button { withAnimation(.snappy) { selected = place } } label: {
                                StitchPin(place: place, selected: selected?.id == place.id,
                                          drops: !landed.contains(place.id) && !reduceMotion) {
                                    markLanded(place.id)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .onAppear { if !visible.isEmpty { camera = .automatic } }
            .onChange(of: visible.map(\.id)) { _, ids in if !ids.isEmpty { camera = .automatic } }
            .mapControls { MapUserLocationButton(); MapCompass() }
            .overlay(alignment: .bottom) {
                if let selected, let place = store.places.first(where: { $0.id == selected.id }) {
                    PlaceSheetCard(place: place, root: store.root, onDetails: { detail = place }, onClose: { withAnimation(.snappy) { self.selected = nil } })
                        .padding(Stitch.Space.s)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if visible.isEmpty {
                    VStack(spacing: Stitch.Space.xxs) {
                        Text("Noch keine Orte auf der Karte").font(.headline).foregroundStyle(Stitch.ink)
                        Text("Ideen, für die du dich entscheidest,\nlanden hier als Stecknadel.")
                            .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Stitch.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .stitchCard(.floating)
                    .padding(Stitch.Space.page)
                }
            }
        }
        .navigationTitle("Karte")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detail) { PlaceDetail(placeID: $0.id) }
    }

    private var landed: Set<String> { Set(landedRaw.split(separator: ",").map(String.init)) }
    private func markLanded(_ id: String) {
        var ids = landed; ids.insert(id); landedRaw = ids.sorted().joined(separator: ",")
    }
}

enum MapFilter: String, CaseIterable, Identifiable {
    case all, food, sights, view
    var id: String { rawValue }
    var title: String { switch self { case .all: "Alle"; case .food: "Essen"; case .sights: "Sehenswert"; case .view: "Aussicht" } }
    var symbol: String? { switch self { case .all: nil; case .food: "fork.knife"; case .sights: "building.columns.fill"; case .view: "sunrise.fill" } }
    var thread: Color { switch self { case .sights: Stitch.cobalt; default: Stitch.red } }
    func matches(_ category: String) -> Bool {
        switch self {
        case .all: true
        case .food: category == "Essen & Trinken"
        case .sights: category == "Sehenswert"
        case .view: category == "Aussicht"
        }
    }
}

extension Place {
    /// Gesticktes Symbol und Garnfarbe je Kategorie.
    var stitchSymbol: String {
        switch category {
        case "Essen & Trinken": "fork.knife"
        case "Sehenswert": "building.columns.fill"
        case "Aussicht": "sunrise.fill"
        case "Unterkunft": "bed.double.fill"
        case "Shopping": "bag.fill"
        default: "heart.fill"
        }
    }
    var stitchThread: Color { category == "Sehenswert" || category == "Unterkunft" ? Stitch.cobalt : Stitch.red }
}

/// Runder Stoff-Pin. Neue Orte fallen als Stecknadel auf die Karte und drücken eine kleine Delle in den Plan.
struct StitchPin: View {
    let place: Place
    let selected: Bool
    let drops: Bool
    var onLanded: () -> Void = {}
    @State private var fallen = false
    @State private var dent = false
    @State private var landedTick = 0

    var body: some View {
        let size: CGFloat = selected ? 58 : 46
        VStack(spacing: 0) {
            ZStack {
                LinenBackground()
                    .frame(width: size, height: size).clipShape(Circle())
                Circle().strokeBorder(place.stitchThread, style: StrokeStyle(lineWidth: selected ? 3 : 1.6, dash: selected ? [] : [4, 3]))
                    .padding(3)
                StitchedSymbol(name: place.stitchSymbol, rows: 11, cell: selected ? 2.6 : 2.1, color: place.stitchThread)
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.22), radius: 4, y: 3)
            Circle().fill(place.stitchThread).frame(width: 9, height: 9)
                .overlay(Circle().strokeBorder(Stitch.card, lineWidth: 2))
                .offset(y: -3)
        }
        .background(alignment: .bottom) {
            Ellipse().fill(.black.opacity(dent ? 0.28 : 0))
                .frame(width: dent ? 30 : 6, height: dent ? 8 : 2)
                .blur(radius: 2.5).offset(y: 3)
        }
        .offset(y: drops && !fallen ? -140 : 0)
        .scaleEffect(drops && !fallen ? 1.25 : 1, anchor: .bottom)
        .opacity(drops && !fallen ? 0 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: selected)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.9), trigger: landedTick)
        .onAppear {
            guard drops else { return }
            // Erst fallen, wenn die Karte steht; mehrere Nadeln leicht nacheinander.
            let delay = 0.8 + (place.id.stableTilt + 1) * 0.22
            withAnimation(.easeIn(duration: 0.34).delay(delay)) { fallen = true } completion: {
                landedTick += 1
                withAnimation(.easeOut(duration: 0.18)) { dent = true } completion: {
                    withAnimation(.easeOut(duration: 0.5)) { dent = false }
                    onLanded()
                }
            }
        }
        .accessibilityElement().accessibilityLabel(place.title)
    }
}

/// Tag eines Ortes wählen; der Ort kommt ans Ende des Tages.
struct DayMenu: View {
    @Environment(AlbumStore.self) private var store
    let place: Place
    var body: some View {
        Menu {
            Button("Noch offen") { store.assign(place, to: nil) }
            ForEach(4...9, id: \.self) { day in
                Button("\(day). Oktober") { store.assign(place, to: day) }
            }
        } label: {
            Label(place.day.map { "Am \($0). Oktober" } ?? "Tag festlegen", systemImage: "calendar")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.red)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityLabel(place.day.map { "Tag: \($0). Oktober, ändern" } ?? "Tag festlegen")
    }
}

/// Tagesplan: Orte pro Tag, per Ziehen sortierbar. Der Faden auf der Karte folgt dieser Reihenfolge.
struct DayPlanner: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var proposing = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { proposing = true } label: {
                        Label("Automatisch planen", systemImage: "wand.and.stars").font(.body.weight(.semibold))
                    }
                    .foregroundStyle(Stitch.red)
                    .disabled(store.franked.allSatisfy { $0.coordinate == nil || $0.category == "Unterkunft" })
                }
                .listRowBackground(Stitch.card)
                ForEach(4...9, id: \.self) { day in
                    let places = store.plan(for: day)
                    Section(TripDates.dayTitle(day)) {
                        if places.isEmpty {
                            Text("Noch nichts geplant").foregroundStyle(Stitch.inkSoft)
                        }
                        ForEach(places) { place in
                            HStack(spacing: Stitch.Space.s) {
                                AlbumPhoto(asset: place.image, root: store.root).frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                                Text(place.title).font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
                            }
                        }
                        .onMove { source, destination in
                            var ids = places.map(\.id)
                            ids.move(fromOffsets: source, toOffset: destination)
                            store.reorder(day: day, ids: ids)
                        }
                    }
                    .listRowBackground(Stitch.card)
                }
                let unplanned = store.franked.filter { $0.day == nil }
                if !unplanned.isEmpty {
                    Section("Noch ohne Tag") {
                        ForEach(unplanned) { place in
                            HStack {
                                Text(place.title).foregroundStyle(Stitch.ink)
                                Spacer()
                                DayMenu(place: place).fixedSize()
                            }
                        }
                    }
                    .listRowBackground(Stitch.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(LinenBackground())
            .navigationTitle("Tagesplan").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $proposing) { DayPlanPreview() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { EditButton() }
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
    }
}

/// Karte für den gewählten Ort über der Karte: Foto, Name, Route und Details.
struct PlaceSheetCard: View {
    let place: Place
    let root: URL
    var onDetails: () -> Void
    var onClose: () -> Void
    var body: some View {
        VStack(spacing: Stitch.Space.s) {
            HStack(alignment: .top, spacing: Stitch.Space.s) {
                AlbumPhoto(asset: place.image, root: root)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text(place.title).font(.title3.weight(.bold)).foregroundStyle(Stitch.ink).lineLimit(2)
                    Text(subtitle).font(.subheadline).foregroundStyle(Stitch.inkSoft).lineLimit(2)
                    if !place.note.isEmpty {
                        Text(place.note).font(.footnote).foregroundStyle(Stitch.inkSoft).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Button(action: onClose) { Image(systemName: "xmark").font(.footnote.weight(.bold)) }
                    .buttonStyle(HeaderIconButton()).accessibilityLabel("Schließen")
            }
            HStack(spacing: Stitch.Space.s) {
                if let coordinate = place.coordinate {
                    Button {
                        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                        item.name = place.title
                        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                    } label: { Label("Route", systemImage: "figure.walk") }
                    .buttonStyle(StitchButton(primary: true))
                }
                Button("Details", action: onDetails).buttonStyle(StitchButton())
            }
            DayMenu(place: place)
        }
        .padding(Stitch.Space.m)
        .background {
            RoundedRectangle(cornerRadius: Stitch.Radius.floating, style: .continuous).fill(Stitch.card)
                .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.floating - 6, style: .continuous)
                    .strokeBorder(Stitch.red.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])).padding(6))
                .stitchElevation(.floating)
        }
    }
    private var subtitle: String {
        var parts = [place.category]
        if let day = place.day { parts.append("\(day). Oktober") }
        if !place.address.isEmpty { parts = [place.address] + parts }
        return parts.joined(separator: " · ")
    }
}

struct PlaceDetail: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var placeID: String
    @State private var editing = false
    @State private var confirmDelete = false
    var place: Place? { store.places.first { $0.id == placeID } }
    var body: some View {
        NavigationStack {
            if let place {
                ScrollView {
                    VStack(alignment: .leading, spacing: Stitch.Space.l) {
                        PhotoCard(asset: place.image, root: store.root, title: place.title, subtitle: place.category).frame(height: 320)

                        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                            if !place.address.isEmpty {
                                Text(place.address).font(.subheadline).foregroundStyle(Stitch.inkSoft)
                            }
                            if !place.note.isEmpty {
                                Text(place.note).font(.body).foregroundStyle(Stitch.ink)
                            }
                            if let from = authorLine(place) {
                                Text(from).font(.footnote.weight(.semibold)).foregroundStyle(Stitch.red)
                            }
                        }

                        VStack(spacing: Stitch.Space.s) {
                            if let coordinate = place.coordinate {
                                Button {
                                    let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                                    item.name = place.title
                                    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                                } label: { Label("Route", systemImage: "figure.walk") }
                                .buttonStyle(StitchButton(primary: true))
                            }
                            Button(place.visited ? "Doch noch nicht besucht" : "Als besucht markieren") {
                                var p = place; p.visited.toggle(); store.upsert(p)
                            }
                            .buttonStyle(StitchButton())
                            if let url = LinkValidation.url(place.sourceURL) {
                                Link(destination: url) { Label("Bei \(place.sourceLabel) ansehen", systemImage: "arrow.up.right") }
                                    .buttonStyle(StitchButton())
                            }
                        }

                        VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                            if let source = place.image?.sourceURL, let url = URL(string: source) {
                                Link("Foto: \(place.image?.credit ?? "Quelle")", destination: url)
                            }
                            if case .external(let image) = place.image, let license = image.licenseName {
                                if let rawURL = image.licenseURL, let url = URL(string: rawURL) {
                                    Link("Lizenz: \(license)", destination: url)
                                } else {
                                    Text("Lizenz: \(license)")
                                }
                            }
                        }
                        .font(.caption).foregroundStyle(Stitch.inkSoft).tint(Stitch.inkSoft)

                        VStack(alignment: .leading, spacing: 0) {
                            Button("Zurück zu den Ideen") {
                                var p = place; p.franked = false; p.deferred = false; p.approvals = []; p.passedBy = []; p.day = nil; p.dayOrder = nil
                                store.upsert(p); dismiss()
                            }
                            .frame(minHeight: 44)
                            Button("Ort löschen", role: .destructive) { confirmDelete = true }
                                .frame(minHeight: 44)
                        }
                        .font(.body)
                    }
                    .padding(Stitch.Space.page)
                }
                .background(LinenBackground())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { Button("Bearbeiten") { editing = true } }
                }
                .sheet(isPresented: $editing) { PlaceEditor(place: place) }
                .confirmationDialog("Diesen Ort löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Löschen", role: .destructive) { var p = place; p.deleted = true; store.upsert(p); dismiss() }
                }
            }
        }
    }

    private func authorLine(_ place: Place) -> String? {
        guard place.author != store.me, place.author.localizedCaseInsensitiveCompare("Wir") != .orderedSame else { return nil }
        return "Von \(place.author) gesammelt"
    }
}
