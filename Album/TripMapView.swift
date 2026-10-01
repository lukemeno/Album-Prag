import SwiftUI
import MapKit

struct TripMapView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    }

    private var map: some View {
        Map(position: $camera) {
            ForEach(dayThreads, id: \.day) { thread in
                MapPolyline(coordinates: thread.coordinates)
                    .stroke(thread.day % 2 == 0 ? Stitch.teal : Stitch.red,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            ForEach(visible) { place in
                if let coordinate = place.coordinate {
                    Annotation(place.title, coordinate: coordinate, anchor: .bottom) {
                        Button { select(place) } label: {
                            StampPin(place: place, root: store.root, selected: selectedID == place.id,
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
    var symbol: String? { switch self { case .all: nil; case .food: "fork.knife"; case .sights: "building.columns"; case .view: "binoculars" } }
    func matches(_ category: String) -> Bool {
        switch self {
        case .all: true
        case .food: category == "Essen & Trinken"
        case .sights: category == "Sehenswert"
        case .view: category == "Aussicht"
        }
    }
}

/// Ein Ort auf der Karte als kleine Briefmarke mit Foto. Neue Orte fallen auf die Karte und drücken eine kleine Delle in den Plan.
struct StampPin: View {
    let place: Place
    let root: URL
    let selected: Bool
    let drops: Bool
    var onLanded: () -> Void = {}
    @State private var fallen = false
    @State private var dent = false
    @State private var landedTick = 0

    var body: some View {
        let width: CGFloat = selected ? 52 : 38
        VStack(spacing: 2) {
            StampFrame(mat: place.mat, inset: 3, matWidth: 2) {
                AlbumPhoto(asset: place.image, root: root, thumbnailWidth: 120)
                    .frame(width: width, height: width * 1.18)
                    .overlay {
                        if place.image == nil {
                            Image(systemName: place.symbol).font(.footnote.weight(.semibold)).foregroundStyle(Stitch.ink)
                        }
                    }
            }
            Circle().fill(Stitch.red).frame(width: 7, height: 7)
                .overlay(Circle().strokeBorder(Stitch.card, lineWidth: 1.5))
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
            // Erst fallen, wenn die Karte steht; mehrere Marken leicht nacheinander.
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
    @State private var viewing: PhotoView?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                        hero(place)

                        if !facts(place).isEmpty || !place.note.isEmpty {
                            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                                if !place.note.isEmpty {
                                    Text(place.note).font(.body).foregroundStyle(Stitch.ink)
                                }
                                ForEach(facts(place), id: \.self) { line in
                                    Text(line).font(.subheadline).foregroundStyle(Stitch.inkSoft)
                                }
                            }
                        }

                        VStack(spacing: Stitch.Space.s) {
                            if place.coordinate != nil {
                                Button { openWalkingRoute(to: place) } label: { Label("Route", systemImage: "figure.walk") }
                                    .buttonStyle(StitchButton(primary: true))
                            }
                            if place.franked {
                                VisitedTrack(visited: place.visited) { var p = place; p.visited = true; store.upsert(p) }
                            }
                            if let url = LinkValidation.url(place.sourceURL) {
                                Link(destination: url) { Label("Bei \(place.sourceLabel) ansehen", systemImage: "arrow.up.right") }
                                    .buttonStyle(StitchButton())
                            }
                        }

                        // Wikimedia verlangt die Nennung jeder Urheberin; leise ganz unten.
                        if hasCredits(place) { credits(place) }
                    }
                    .padding(Stitch.Space.page)
                }
                .background(PaperBackground())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen", systemImage: "xmark") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) { Button("Bearbeiten") { editing = true } }
                }
                .sheet(isPresented: $editing) { PlaceEditor(place: place) }
                .fullScreenCover(item: $viewing) { PhotoViewer(place: place, root: store.root, source: $0.source, photo: $0.photo) }
            }
        }
        // Gelöscht (im Editor): Das Detail hat nichts mehr zu zeigen.
        .onChange(of: place == nil) { _, gone in if gone { dismiss() } }
    }

    private func hero(_ place: Place) -> some View {
        Group {
            if place.photoAssets.count > 1 {
                PhotoStack(photos: place.photoAssets, root: store.root, title: place.title, subtitle: place.category) { photo, source in
                    var instant = Transaction(animation: nil); instant.disablesAnimations = true
                    withTransaction(instant) { viewing = PhotoView(photo: photo, source: source) }
                }
                .frame(height: 340)
            } else {
                PhotoCard(asset: place.image, root: store.root, title: place.title, subtitle: place.category).frame(height: 340)
            }
        }
        .overlay(alignment: .topLeading) {
            if place.visited {
                VisitedStamp().padding(Stitch.Space.m)
                    .transition(reduceMotion ? .opacity : .scale(scale: 1.8).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.34, dampingFraction: 0.55), value: place.visited)
    }

    /// Adresse, Tag, Herkunft – nur was stimmt.
    private func facts(_ place: Place) -> [String] {
        var lines: [String] = []
        if !place.address.isEmpty { lines.append(place.address) }
        if let day = place.day { lines.append(TripDates.dayTitle(day)) }
        if place.author != store.me, place.author.localizedCaseInsensitiveCompare("Wir") != .orderedSame {
            lines.append("Von \(place.author) eingeworfen")
        }
        return lines
    }

    private func hasCredits(_ place: Place) -> Bool {
        place.image?.sourceURL.flatMap(URL.init(string:)) != nil || !(place.gallery ?? []).isEmpty
    }

    private func credits(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
            if let source = place.image?.sourceURL, let url = URL(string: source) {
                let license: String? = if case .external(let image) = place.image { image.licenseName } else { nil }
                Link("Foto: \(place.image?.credit ?? "Quelle")\(license.map { " · \($0)" } ?? "")", destination: url)
            }
            ForEach(place.gallery ?? [], id: \.imageURL) { image in
                if let url = URL(string: image.sourceURL) {
                    Link("Foto: \(image.credit)\(image.licenseName.map { " · \($0)" } ?? "")", destination: url)
                }
            }
        }
        .font(.caption).foregroundStyle(Stitch.inkSoft).tint(Stitch.inkSoft)
    }
}
