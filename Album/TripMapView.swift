import SwiftUI
import MapKit

struct TripMapView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onAdd: () -> Void = {}
    var onShare: () -> Void = {}
    @State private var camera: MapCameraPosition = .region(.init(center: .init(latitude: 50.087, longitude: 14.423), span: .init(latitudeDelta: 0.035, longitudeDelta: 0.035)))
    @State private var selected: Place?
    @State private var detail: Place?
    @State private var filter = MapFilter.all
    @State private var documents = false
    @State private var planner = false
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
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    StitchedText(text: "Prag", rows: 20, cell: 2.3)
                        .accessibilityLabel("Prag auf der Karte")
                    Spacer()
                    Button { planner = true } label: { Image(systemName: "calendar") }
                        .buttonStyle(HeaderIconButton()).accessibilityLabel("Tagesplan")
                    Button { documents = true } label: { Image(systemName: "ticket") }
                        .buttonStyle(HeaderIconButton()).accessibilityLabel("Reisedaten und Dokumente")
                    Button(action: onShare) { Image(systemName: "person.2") }
                        .buttonStyle(HeaderIconButton()).accessibilityLabel("Geteiltes Album verwalten")
                    Button(action: onAdd) { Image(systemName: "plus") }
                        .buttonStyle(HeaderIconButton()).accessibilityLabel("Idee hinzufügen")
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(MapFilter.allCases) { item in
                            Button { withAnimation(.snappy) { filter = item } } label: {
                                HStack(spacing: 7) {
                                    if let symbol = item.symbol {
                                        StitchedSymbol(name: symbol, rows: 9, cell: 2, color: filter == item ? Stitch.onAccent : item.thread)
                                    }
                                    Text(item.title).font(.subheadline.weight(.semibold))
                                }
                                .padding(.horizontal, 14).frame(minHeight: 40)
                                .foregroundStyle(filter == item ? Stitch.onAccent : Stitch.ink)
                                .background(filter == item ? Stitch.red : Stitch.card, in: Capsule())
                                .overlay(Capsule().strokeBorder(Stitch.ink.opacity(filter == item ? 0 : 0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(filter == item ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -16)
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
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
                            StitchPin(place: place, selected: selected?.id == place.id,
                                      drops: !landed.contains(place.id) && !reduceMotion) {
                                markLanded(place.id)
                            }
                            .onTapGesture { withAnimation(.snappy) { selected = place } }
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
                        .padding(12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if visible.isEmpty {
                    VStack(spacing: 6) {
                        Text("Noch keine Orte auf der Karte").font(.headline).foregroundStyle(Stitch.ink)
                        Text("Ideen, für die ihr euch entscheidet,\nlanden hier als Stecknadel.")
                            .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Stitch.inkSoft)
                    }
                    .padding(18).frame(maxWidth: .infinity)
                    .background(Stitch.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(16)
                }
            }
        }
        .sheet(item: $detail) { PlaceDetail(placeID: $0.id) }
        .sheet(isPresented: $documents) { TripDocumentsView() }
        .sheet(isPresented: $planner) { DayPlanner() }
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
        case "Essen & Trinken": "cup.and.saucer.fill"
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
        .accessibilityElement().accessibilityLabel(place.title).accessibilityAddTraits(.isButton)
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
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .accessibilityLabel(place.day.map { "Tag: \($0). Oktober, ändern" } ?? "Tag festlegen")
    }
}

/// Tagesplan: Orte pro Tag, per Ziehen sortierbar. Der Faden auf der Karte folgt dieser Reihenfolge.
struct DayPlanner: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(4...9, id: \.self) { day in
                    let places = store.plan(for: day)
                    Section("\(day). Oktober") {
                        if places.isEmpty {
                            Text("Noch nichts geplant").foregroundStyle(Stitch.inkSoft)
                        }
                        ForEach(places) { place in
                            HStack(spacing: 12) {
                                AlbumPhoto(asset: place.image, root: store.root).frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(LinenBackground())
            .navigationTitle("Tagesplan").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
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
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                AlbumPhoto(asset: place.image, root: root)
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
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
            HStack(spacing: 10) {
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
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Stitch.card)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Stitch.red.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])).padding(6))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
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
                    VStack(alignment: .leading, spacing: 18) {
                        PhotoCard(asset: place.image, root: store.root, title: place.title, subtitle: place.category).frame(height: 320)
                        Text(place.address).font(AlbumStyle.body()).foregroundStyle(AlbumStyle.muted)
                        if !place.note.isEmpty { Text(place.note).font(AlbumStyle.body()) }
                        if let source = place.image?.sourceURL, let url = URL(string: source) {
                            Link("Bild: \(place.image?.credit ?? "Quelle") ↗", destination: url).font(AlbumStyle.body(12)).foregroundStyle(AlbumStyle.muted)
                        }
                        if case .external(let image) = place.image, let license = image.licenseName {
                            if let rawURL = image.licenseURL, let url = URL(string: rawURL) {
                                Link("Lizenz: \(license) ↗", destination: url).font(AlbumStyle.body(12)).foregroundStyle(AlbumStyle.muted)
                            } else {
                                Text("Lizenz: \(license)").font(AlbumStyle.body(12)).foregroundStyle(AlbumStyle.muted)
                            }
                        }
                        Text(place.author.localizedCaseInsensitiveCompare("Wir") == .orderedSame ? "Von euch gesammelt" : "Von \(place.author) gesammelt").font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.red)
                        if let url = LinkValidation.url(place.sourceURL) { Link("Original bei \(place.sourceLabel) öffnen ↗", destination: url).font(AlbumStyle.body()) }
                        if let coordinate = place.coordinate {
                            Button("Route in Apple Karten") {
                                let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                                item.name = place.title
                                item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                            }.buttonStyle(AlbumButton(primary: true))
                        }
                        Button(place.visited ? "Doch noch nicht besucht" : "Als besucht markieren") { var p = place; p.visited.toggle(); store.upsert(p) }.buttonStyle(AlbumButton())
                        Button("Zurück zu den Ideen") {
                            var p = place; p.franked = false; p.deferred = false; p.approvals = []; p.passedBy = []; p.day = nil; p.dayOrder = nil
                            store.upsert(p); dismiss()
                        }.font(AlbumStyle.body())
                        Button("Idee löschen", role: .destructive) { confirmDelete = true }.font(AlbumStyle.body()).padding(.top, 10)
                    }.padding(16)
                }.background(LinenBackground()).navigationTitle("Ort").navigationBarTitleDisplayMode(.inline)
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
}
