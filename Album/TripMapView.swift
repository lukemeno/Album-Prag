import SwiftUI
import MapKit

struct TripMapView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Zählt hoch, wenn „Tagesplan“ im Mehr-Menü gewählt wird: Dann klappt die Liste ganz auf.
    var expandRequest = 0
    @State private var camera: MapCameraPosition = .region(.init(center: .init(latitude: 50.087, longitude: 14.423), span: .init(latitudeDelta: 0.035, longitudeDelta: 0.035)))
    @State private var selectedID: String?
    @State private var detail: Place?
    @State private var filter = MapFilter.all
    @State private var detent = DrawerDetent.half
    @State private var coveredHeight: CGFloat = 0
    /// Orte, die schon einmal auf der Karte gelandet sind. Nur neue fallen als Stecknadel.
    @AppStorage("album.landedPins") private var landedRaw = ""

    var visible: [Place] { store.franked.filter { $0.coordinate != nil && filter.matches($0.category) } }

    /// Orte eines Tages, verbunden in geplanter Reihenfolge.
    private var dayThreads: [(day: Int, coordinates: [CLLocationCoordinate2D])] {
        (4...9).map { day in (day, store.plan(for: day).filter { filter.matches($0.category) }.compactMap(\.coordinate)) }
            .filter { $0.1.count > 1 }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                map
                    // Die Karte rahmt ihre Nadeln im sichtbaren Teil über dem Blatt. Höchstens bis zur halben Höhe:
                    // Ist die Liste ganz offen, sieht man die Karte ohnehin nicht, und sie soll nicht auf Europa zoomen.
                    .safeAreaPadding(.bottom, min(coveredHeight, geo.size.height * 0.5))
                    // Ganz offene Liste verdeckt die Karte; VoiceOver soll dann keine unsichtbaren Nadeln anbieten.
                    .accessibilityHidden(detent == .full)
                PlacesDrawer(detent: $detent, filter: $filter, selectedID: $selectedID, coveredHeight: $coveredHeight,
                             available: geo.size.height, onShow: show, onDetails: { detail = $0 })
            }
        }
        .navigationTitle("Karte")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detail) { PlaceDetail(placeID: $0.id) }
        .onChange(of: expandRequest) { _, _ in
            withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86)) { detent = .full }
        }
    }

    private var map: some View {
        Map(position: $camera) {
            ForEach(dayThreads, id: \.day) { thread in
                MapPolyline(coordinates: thread.coordinates)
                    .stroke(thread.day % 2 == 0 ? Stitch.cobalt : Stitch.red,
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [8, 7]))
            }
            ForEach(visible) { place in
                if let coordinate = place.coordinate {
                    Annotation(place.title, coordinate: coordinate, anchor: .bottom) {
                        Button { select(place) } label: {
                            StitchPin(place: place, selected: selectedID == place.id,
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
    }

    /// Nadel angetippt: Die Liste springt zum Ort und öffnet sich so weit, dass man ihn sieht.
    private func select(_ place: Place) {
        withAnimation(reduceMotion ? nil : .snappy) {
            selectedID = place.id
            if detent == .collapsed { detent = .half }
        }
    }

    /// Ort in der Liste angetippt: Die Karte fliegt hin, die Liste gibt die Karte frei.
    private func show(_ place: Place) {
        guard let coordinate = place.coordinate else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) {
            selectedID = place.id
            if detent == .full { detent = .half }
            camera = .region(MKCoordinateRegion(center: coordinate, span: .init(latitudeDelta: 0.012, longitudeDelta: 0.012)))
        }
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
            .stitchElevation(.pinned)
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

struct PlaceDetail: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var placeID: String
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var viewing: PhotoView?
    var place: Place? { store.places.first { $0.id == placeID } }

    /// Ein Foto des Stapels im Vollbild, mit dem Rahmen, aus dem es wächst.
    private struct PhotoView: Identifiable {
        let id = UUID()
        let photo: PlaceImageAsset
        let source: CGRect
    }
    var body: some View {
        NavigationStack {
            if let place {
                ScrollView {
                    VStack(alignment: .leading, spacing: Stitch.Space.l) {
                        if place.photoAssets.count > 1 {
                            PhotoStack(photos: place.photoAssets, root: store.root, title: place.title, subtitle: place.category) { photo, source in
                                var instant = Transaction(animation: nil); instant.disablesAnimations = true
                                withTransaction(instant) { viewing = PhotoView(photo: photo, source: source) }
                            }
                            .frame(height: 320)
                        } else {
                            PhotoCard(asset: place.image, root: store.root, title: place.title, subtitle: place.category).frame(height: 320)
                        }

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
                            if place.coordinate != nil {
                                Button { openWalkingRoute(to: place) } label: { Label("Route", systemImage: "figure.walk") }
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

                        // Nur wenn es etwas zu nennen gibt: Ein leerer Block würde den Abstand verdoppeln.
                        if hasCredits(place) {
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
                                // Weitere Fotos aus dem Foto-Streifen: Wikimedia verlangt die Nennung jeder Urheberin.
                                ForEach(place.gallery ?? [], id: \.imageURL) { image in
                                    if let url = URL(string: image.sourceURL) {
                                        Link("Foto: \(image.credit)\(image.licenseName.map { " · \($0)" } ?? "")", destination: url)
                                    }
                                }
                            }
                            .font(.caption).foregroundStyle(Stitch.inkSoft).tint(Stitch.inkSoft)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Button("Zurück zu den Ideen") {
                                var p = place; p.franked = false; p.deferred = false; p.approvals = []; p.passedBy = []; p.day = nil; p.dayOrder = nil
                                store.upsert(p); dismiss()
                            }
                            .frame(minHeight: Stitch.Size.touch)
                            Button("Ort löschen", role: .destructive) { confirmDelete = true }
                                .frame(minHeight: Stitch.Size.touch)
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
                .fullScreenCover(item: $viewing) { PhotoViewer(place: place, root: store.root, source: $0.source, photo: $0.photo) }
                .confirmationDialog("Diesen Ort löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Löschen", role: .destructive) { var p = place; p.deleted = true; store.upsert(p); dismiss() }
                }
            }
        }
    }

    private func hasCredits(_ place: Place) -> Bool {
        place.image?.sourceURL.flatMap(URL.init(string:)) != nil || !(place.gallery ?? []).isEmpty
    }

    private func authorLine(_ place: Place) -> String? {
        guard place.author != store.me, place.author.localizedCaseInsensitiveCompare("Wir") != .orderedSame else { return nil }
        return "Von \(place.author) gesammelt"
    }
}
