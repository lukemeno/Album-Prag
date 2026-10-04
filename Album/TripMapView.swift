import SwiftUI
import MapKit

struct TripMapView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var drawerMorph
    @State private var camera: MapCameraPosition = .region(.init(center: .init(latitude: 50.087, longitude: 14.423), span: .init(latitudeDelta: 0.035, longitudeDelta: 0.035)))
    @State private var visibleRegion = MKCoordinateRegion(center: .init(latitude: 50.087, longitude: 14.423), span: .init(latitudeDelta: 0.035, longitudeDelta: 0.035))
    @State private var selectedID: String?
    @State private var selectionRequest = 0
    @State private var detail: Place?
    @State private var clusterSelection: MapPinGroup?
    @State private var lastTappedClusterID: String?
    @State private var filter = MapFilter.all
    @State private var searchQuery = ""
    @State private var detent = DrawerDetent.half
    @State private var coveredHeight: CGFloat = 0
    @State private var coveredWidth: CGFloat = 0
    @State private var hasAutoFittedCamera = false
    @State private var projectedPins: [MapPinProjection] = []
    @State private var projectedFingerprint: [String] = []
    /// Orte, die schon einmal auf der Karte gelandet sind. Nur neue fallen als Stecknadel.
    @AppStorage("album.landedPins") private var landedRaw = ""

    var visible: [Place] { store.franked.filter { $0.coordinate != nil && filter.matches($0) && $0.matchesMapSearch(searchQuery) } }
    private var selectedDay: Int? { visible.first { $0.id == selectedID }?.day }

    /// Orte eines Tages, verbunden in geplanter Reihenfolge.
    private var dayThreads: [(day: Int, coordinates: [CLLocationCoordinate2D])] {
        (4...9).map { day in (day, store.plan(for: day).filter { filter.matches($0) && $0.matchesMapSearch(searchQuery) }.compactMap(\.coordinate)) }
            .filter { $0.1.count > 1 }
    }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            ZStack(alignment: isLandscape ? .topLeading : .bottom) {
                map
                    // Die Karte läuft vollflächig bis unter Statusleiste und Suchfeld; nur der Drawer gibt
                    // den sichtbaren Ausschnitt frei.
                    .safeAreaPadding(.bottom, isLandscape ? 0 : min(coveredHeight, geo.size.height * 0.5))
                    .safeAreaPadding(.leading, isLandscape ? min(coveredWidth, geo.size.width * 0.5) : 0)
                    .accessibilityHidden(detent == .full && !isLandscape)
                PlacesDrawer(detent: $detent, filter: $filter, selectedID: $selectedID, selectionRequest: $selectionRequest,
                             coveredHeight: $coveredHeight, coveredWidth: $coveredWidth, searchQuery: searchQuery, namespace: drawerMorph,
                             isLandscape: isLandscape, availableHeight: geo.size.height, availableWidth: geo.size.width,
                             onShow: show, onDetails: { detail = $0 })
                if detent == .hidden {
                    Button {
                        withAnimation(reduceMotion ? nil : Stitch.Motion.panel) {
                            detent = .half
                        }
                    } label: {
                        HStack(spacing: Stitch.Space.s) {
                            Image(systemName: "list.bullet")
                                .font(.subheadline.weight(.semibold))
                            Text(drawerTitle)
                                .font(.subheadline.weight(.semibold))
                                .matchedGeometryEffect(id: "places-drawer-title", in: drawerMorph, isSource: true)
                        }
                        .foregroundStyle(Stitch.ink)
                        .padding(.horizontal, Stitch.Space.m)
                        .frame(minHeight: Stitch.Size.touch)
                        .background {
                            PaperBackground()
                                .matchedGeometryEffect(id: "places-drawer-surface", in: drawerMorph, isSource: true)
                                .clipShape(Capsule())
                        }
                        .stitchElevation(.floating)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(drawerTitle)
                    .accessibilityHint("Öffnet die Ortsliste")
                    .accessibilityIdentifier("map-drawer-reopen")
                    .padding(.bottom, isLandscape ? 0 : Stitch.Space.s)
                    .padding(.top, isLandscape ? Stitch.Space.s : 0)
                    .padding(.leading, isLandscape ? Stitch.Space.s : 0)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .top) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Stitch.inkSoft)
                    TextField("Prag durchsuchen", text: $searchQuery)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .submitLabel(.search)
                        .accessibilityIdentifier("map-search")
                        .accessibilityLabel("Karte durchsuchen")
                        .accessibilityHint("Sucht Orte nach Name oder Adresse")
                    Menu {
                        Picker("Kategorie", selection: $filter) {
                            ForEach(MapFilter.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                    }
                    .accessibilityLabel("Karte filtern")
                }
                .foregroundStyle(Stitch.ink)
                .padding(.leading, 18)
                .padding(.trailing, 4)
                .frame(minHeight: 56)
                .background(Stitch.card.opacity(0.96), in: Capsule())
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .opacity(detent == .full && !isLandscape ? 0 : 1)
                .allowsHitTesting(detent != .full || isLandscape)
            }
        }
        .preference(key: AssistantBottomClearanceKey.self, value: coveredHeight)
        .navigationTitle("Karte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: searchQuery) { _, _ in
            // A search changes cluster membership. Do not let a previous
            // two-tap cluster state turn the first tap on a new result into
            // the member sheet unexpectedly.
            lastTappedClusterID = nil
            clusterSelection = nil
            if let selectedID, !visible.contains(where: { $0.id == selectedID }) { self.selectedID = nil }
        }
        .sheet(item: $detail) { PlaceDetail(placeID: $0.id) }
        .sheet(item: $clusterSelection) { group in
            ClusterMemberPicker(places: group.places) { place in
                guard let current = visible.first(where: { $0.id == place.id }) else {
                    clusterSelection = nil
                    return
                }
                clusterSelection = nil
                select(current)
            }
        }
        .onChange(of: filter) { _, newFilter in
            lastTappedClusterID = nil
            clusterSelection = nil
            if let selectedID, !store.franked.contains(where: { $0.id == selectedID && newFilter.matches($0) }) {
                self.selectedID = nil
            }
        }
        .onChange(of: store.places.map(\.id)) { _, ids in
            lastTappedClusterID = nil
            if let detail, !ids.contains(detail.id) { self.detail = nil }
        }
    }

    private var drawerTitle: String {
        let count = store.franked.filter {
            filter.matches($0) && $0.matchesMapSearch(searchQuery)
        }.count
        return count == 1 ? "1 Ort" : "\(count) Orte"
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $camera) {
                ForEach(dayThreads, id: \.day) { thread in
                    let isSelectedDay = selectedDay == thread.day
                    MapPolyline(coordinates: thread.coordinates)
                        .stroke(isSelectedDay ? Stitch.red : Stitch.teal.opacity(0.28),
                                style: StrokeStyle(lineWidth: isSelectedDay ? 2.5 : 1.5,
                                                   lineCap: .round, lineJoin: .round,
                                                   dash: isSelectedDay ? [] : [3, 5]))
                }
                ForEach(mapPinGroups) { group in
                    Annotation(group.title, coordinate: group.coordinate, anchor: .bottom) {
                        if let place = group.place {
                            Button { select(place) } label: {
                                StampPin(place: place, root: store.root, selected: selectedID == place.id,
                                          drops: !landed.contains(place.id) && !reduceMotion) {
                                    markLanded(place.id)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("map-pin-\(place.id)")
                        } else {
                            Button { handleClusterTap(group) } label: {
                                StampClusterPin(places: group.places, root: store.root)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("map-cluster-\(group.id)")
                            .accessibilityLabel("\(group.places.count) Orte")
                            .accessibilityHint("Vergrößert die Karte auf diese Orte oder öffnet die Ortsauswahl")
                        }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .onAppear {
                fitInitialCameraIfNeeded()
                refreshProjectedPins(using: proxy)
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                let region = context.region
                guard region.center.latitude.isFinite,
                      region.center.longitude.isFinite,
                      region.span.latitudeDelta.isFinite,
                      region.span.longitudeDelta.isFinite,
                      region.span.latitudeDelta > 0,
                      region.span.longitudeDelta > 0 else { return }

                let tolerance = 1e-7
                let changed = abs(region.center.latitude - visibleRegion.center.latitude) > tolerance
                    || abs(region.center.longitude - visibleRegion.center.longitude) > tolerance
                    || abs(region.span.latitudeDelta - visibleRegion.span.latitudeDelta) > tolerance
                    || abs(region.span.longitudeDelta - visibleRegion.span.longitudeDelta) > tolerance
                if changed { visibleRegion = region }
                refreshProjectedPins(using: proxy)
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { _ in
                refreshProjectedPins(using: proxy)
            }
            .onChange(of: visibleProjectionFingerprint) { _, _ in
                fitInitialCameraIfNeeded()
                if let selectedID, !visible.contains(where: { $0.id == selectedID }) { self.selectedID = nil }
                refreshProjectedPins(using: proxy)
            }
            .mapControls { MapUserLocationButton(); MapCompass() }
            .accessibilityLabel("Prag-Karte mit \(visible.count) beschlossenen Orten")
            .accessibilityHint("Karte verschieben oder zoomen; Stecknadeln wählen den Ort in der Liste aus und heben seinen Tag hervor")
        }
    }

    private var visibleProjectionFingerprint: [String] {
        visible.map { place in
            "\(place.id)|\(place.coordinate?.latitude ?? .nan)|\(place.coordinate?.longitude ?? .nan)"
        }
    }

    private var mapPinGroups: [MapPinGroup] {
        guard projectedFingerprint == visibleProjectionFingerprint,
              projectedPins.count == visible.count else {
            return visible.map { MapPinGroup(places: [$0]) }
        }
        return pinGroups(using: projectedPins)
    }

    private func refreshProjectedPins(using proxy: MapProxy) {
        let fingerprint = visibleProjectionFingerprint
        guard !visible.isEmpty else {
            if !projectedPins.isEmpty || !projectedFingerprint.isEmpty {
                projectedPins = []
                projectedFingerprint = []
            }
            return
        }

        let projected = visible.compactMap { place -> MapPinProjection? in
            guard let coordinate = place.coordinate,
                  let point = proxy.convert(coordinate, to: .local),
                  point.x.isFinite,
                  point.y.isFinite else { return nil }
            return MapPinProjection(id: place.id, point: point)
        }
        guard projected.count == visible.count else { return }
        guard projectedFingerprint != fingerprint || Self.projectionsChanged(projected, comparedTo: projectedPins) else { return }
        projectedPins = projected
        projectedFingerprint = fingerprint
    }

    private func pinGroups(using projections: [MapPinProjection]) -> [MapPinGroup] {
        let placesByID = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0) })
        let projected = projections
        let selected = projected.first { $0.id == selectedID }
        let candidates = projected.filter { $0.id != selectedID }
        var clusters = MapPinClustering.clusters(from: candidates, collisionDistance: 64)
        if let selected { clusters.append(MapPinCluster(memberIDs: [selected.id], center: selected.point)) }

        return clusters.compactMap { cluster in
            let places = cluster.memberIDs.compactMap { placesByID[$0] }
            guard !places.isEmpty else { return nil }
            return MapPinGroup(places: places)
        }
        .sorted {
            let leftSelected = $0.places.contains { $0.id == selectedID }
            let rightSelected = $1.places.contains { $0.id == selectedID }
            if leftSelected != rightSelected { return !leftSelected }
            return $0.id < $1.id
        }
    }

    static func projectionsChanged(_ candidate: [MapPinProjection], comparedTo existing: [MapPinProjection], tolerance: CGFloat = 0.5) -> Bool {
        guard candidate.count == existing.count else { return true }
        return zip(candidate, existing).contains { current, previous in
            current.id != previous.id
                || abs(current.point.x - previous.point.x) > tolerance
                || abs(current.point.y - previous.point.y) > tolerance
        }
    }

    private func zoom(into group: MapPinGroup) {
        let span = visibleRegion.span
        let region = MKCoordinateRegion(
            center: group.coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: max(min(span.latitudeDelta * 0.42, 0.012), 0.0002),
                longitudeDelta: max(min(span.longitudeDelta * 0.42, 0.012), 0.0002)
            )
        )
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
            camera = .region(region)
        }
    }

    private func handleClusterTap(_ group: MapPinGroup) {
        guard !group.places.isEmpty else { return }
        if lastTappedClusterID == group.id {
            let currentMembers = group.places.filter { place in
                visible.contains { $0.id == place.id }
            }
            guard !currentMembers.isEmpty else { return }
            detail = nil
            clusterSelection = MapPinGroup(places: currentMembers)
            lastTappedClusterID = nil
            return
        }
        lastTappedClusterID = group.id
        zoom(into: group)
    }

    private func fitInitialCameraIfNeeded() {
        guard !hasAutoFittedCamera, !visible.isEmpty else { return }
        guard let rect = Self.initialCameraRect(for: visible.compactMap(\.coordinate)) else { return }
        hasAutoFittedCamera = true
        camera = .rect(rect)
    }

    /// Builds a stable initial fit without leaving MapKit in content-driven automatic mode.
    static func initialCameraRect(for coordinates: [CLLocationCoordinate2D]) -> MKMapRect? {
        let valid = coordinates.filter { coordinate in
            coordinate.latitude.isFinite && coordinate.longitude.isFinite
        }
        guard !valid.isEmpty else { return nil }

        let points = valid.map(MKMapPoint.init)
        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        let meanLatitude = valid.map(\.latitude).reduce(0, +) / Double(valid.count)
        let metersPerMapPoint = MKMetersPerMapPointAtLatitude(meanLatitude)
        guard metersPerMapPoint.isFinite, metersPerMapPoint > 0 else { return nil }

        let minimumExtent = 500 / metersPerMapPoint
        let width = max(maxX - minX, minimumExtent) * 1.25
        let height = max(maxY - minY, minimumExtent) * 1.25
        guard width.isFinite, width > 0, height.isFinite, height > 0 else { return nil }

        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        return MKMapRect(
            x: centerX - width / 2,
            y: centerY - height / 2,
            width: width,
            height: height
        )
    }

    /// Nadel angetippt: Die Liste springt zum Ort und öffnet sich so weit, dass man ihn sieht.
    private func select(_ place: Place) {
        withAnimation(reduceMotion ? nil : .snappy) {
            selectedID = place.id
            selectionRequest += 1
            if detent == .collapsed || detent == .hidden { detent = .half }
        }
    }

    /// Ort in der Liste angetippt: Die Karte fliegt hin, die Liste gibt die Karte frei.
    private func show(_ place: Place) {
        guard let coordinate = place.coordinate else {
            detail = place
            return
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) {
            selectedID = place.id
            selectionRequest += 1
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
    case all, food, sights, view, visited
    var id: String { rawValue }
    var title: String { switch self { case .all: "Alle"; case .food: "Essen"; case .sights: "Sehenswert"; case .view: "Aussicht"; case .visited: "Besucht" } }
    var symbol: String? { switch self { case .all: nil; case .food: "fork.knife"; case .sights: "building.columns"; case .view: "binoculars"; case .visited: "checkmark.seal" } }
    /// Nur die Kategorie; „Besucht“ ist ein Status und lässt hier jede Kategorie durch.
    func matches(_ category: String) -> Bool {
        switch self {
        case .all, .visited: true
        case .food: category == "Essen & Trinken"
        case .sights: category == "Sehenswert"
        case .view: category == "Aussicht"
        }
    }
    /// Kategorie und Status zusammen: Nach der Reise zeigt „Besucht“ genau, wo ihr wart.
    func matches(_ place: Place) -> Bool {
        self == .visited ? place.visited : matches(place.category)
    }
}

/// Ein Ort auf der Karte als kleine Briefmarke mit Foto. Neue Orte fallen auf die Karte und drücken eine kleine Delle in den Plan.
struct StampPin: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let place: Place
    let root: URL
    let selected: Bool
    let drops: Bool
    var onLanded: () -> Void = {}
    @State private var fallen = false
    @State private var dent = false
    @State private var landedTick = 0

    var body: some View {
        // Pins bleiben echte Fotomarker und sind auf der Karte auch mit großen
        // Fingern zuverlässig erreichbar. Die blaue Kontur markiert die Auswahl.
        let width: CGFloat = selected ? 82 : 70
        VStack(spacing: 2) {
            ZStack {
                AlbumPhoto(asset: place.image, root: root, thumbnailWidth: 120, placeholderSymbol: place.symbol, placeholderTint: place.mat)
                    .frame(width: width, height: width * 0.86)
                    .overlay {
                        if place.image == nil {
                            Image(systemName: place.symbol).font(.footnote.weight(.semibold)).foregroundStyle(Stitch.ink)
                        }
                    }
            }
            .padding(4)
            .background(Stitch.card, in: RoundedRectangle(cornerRadius: 10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.blue : .white, lineWidth: selected ? 4 : 3)
            }
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            Circle().fill(selected ? Color.blue : .white).frame(width: 9, height: 9)
                .overlay(Circle().strokeBorder(selected ? Color.blue : Stitch.ink, lineWidth: 1.5))
        }
        .background(alignment: .bottom) {
            Ellipse().fill(.black.opacity(dent ? 0.28 : 0))
                .frame(width: dent ? 30 : 6, height: dent ? 8 : 2)
                .blur(radius: 2.5).offset(y: 3)
        }
        .offset(y: drops && !fallen ? -140 : 0)
        .scaleEffect(drops && !fallen ? 1.25 : 1, anchor: .bottom)
        .opacity(drops && !fallen ? 0 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.72), value: selected)
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
        .accessibilityElement()
        .accessibilityLabel(place.title)
        .accessibilityHint(selected
                           ? "Ausgewählt; hebt den Ort in der Ortsliste hervor"
                           : "Wählt den Ort aus und zeigt ihn in der Ortsliste")
    }
}

private struct MapPinGroup: Identifiable {
    let places: [Place]

    var id: String { places.map(\.id).sorted().joined(separator: "|") }
    var title: String { places.count == 1 ? places[0].title : "\(places.count) Orte" }
    var place: Place? { places.count == 1 ? places.first : nil }
    var coordinate: CLLocationCoordinate2D {
        let coordinates = places.compactMap(\.coordinate)
        let count = Double(max(coordinates.count, 1))
        return CLLocationCoordinate2D(
            latitude: coordinates.map(\.latitude).reduce(0, +) / count,
            longitude: coordinates.map(\.longitude).reduce(0, +) / count
        )
    }
}

private struct ClusterMemberPicker: View {
    let places: [Place]
    let select: (Place) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(places) { place in
                Button {
                    select(place)
                } label: {
                    VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                        Text(place.title)
                            .font(.body.weight(.semibold))
                        if !place.address.isEmpty {
                            Text(place.address)
                                .font(.caption)
                                .foregroundStyle(Stitch.inkSoft)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("map-cluster-choice-\(place.id)")
            }
            .navigationTitle("Orte auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct StampClusterPin: View {
    let places: [Place]
    let root: URL
    @ScaledMetric(relativeTo: .caption2) private var badgePadding: CGFloat = 5
    @ScaledMetric(relativeTo: .caption2) private var badgeMinSize: CGFloat = 21

    private var featured: [Place] {
        Array(places.sorted { lhs, rhs in
            if (lhs.image != nil) != (rhs.image != nil) { return lhs.image != nil }
            return lhs.id < rhs.id
        }.prefix(2))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if featured.count > 1 {
                stamp(featured[0], size: 31)
                    .rotationEffect(.degrees(-7))
                    .offset(x: -7, y: 6)
            }
            if let front = featured.last {
                stamp(front, size: 34)
                    .rotationEffect(.degrees(3))
                    .offset(x: 2, y: 4)
            }
            Text("\(places.count)")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .allowsTightening(true)
                .padding(.horizontal, badgePadding)
                .frame(minWidth: badgeMinSize, minHeight: badgeMinSize)
                .background(Circle().fill(Stitch.red))
                .overlay(Circle().strokeBorder(Stitch.card, lineWidth: 1.5))
                .offset(x: 5, y: -3)
                .accessibilityHidden(true)
        }
        .frame(width: 58, height: 58)
        .accessibilityHidden(true)
    }

    private func stamp(_ place: Place, size: CGFloat) -> some View {
        StampFrame(mat: place.mat, inset: 2, matWidth: 2) {
            AlbumPhoto(asset: place.image, root: root, thumbnailWidth: 96, placeholderSymbol: place.symbol, placeholderTint: place.mat)
                .frame(width: size, height: size * 1.16)
                .overlay {
                    if place.image == nil {
                        Image(systemName: place.symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Stitch.ink)
                    }
                }
        }
    }
}

struct PlaceDetail: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var placeID: String
    @State private var editing = false
    @State private var viewing: PhotoView?
    /// Zählt „Zum Reiseplan hinzufügen“ für Haptik und Symbol-Hüpfer.
    @State private var plannedTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var place: Place? { store.places.first { $0.id == placeID } }

    /// Ein Foto des Stapels im Vollbild, mit dem Rahmen, aus dem es wächst.
    private struct PhotoView: Identifiable {
        let id = UUID()
        let photo: PlaceImageAsset
        let source: CGRect
    }
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let heroHeight = isLandscape
                ? min(max(geometry.size.height * 0.62, 260), 440)
                : min(max(geometry.size.height * 0.46, 360), 520)
            NavigationStack {
                if let place {
                    ScrollView {
                        VStack(spacing: 0) {
                            AlbumPhoto(asset: place.image, root: store.root, placeholderSymbol: place.symbol, placeholderTint: place.mat)
                                // The reference keeps the first photo full bleed and gives the
                                // sheet roughly half of the available screen height.
                                .frame(height: heroHeight)
                                .accessibilityHidden(true)
                                .overlay(alignment: .bottomTrailing) { photoCredit(place) }
                                .overlay(alignment: .top) {
                                    HStack {
                                        Button { dismiss() } label: {
                                            Image(systemName: "chevron.left")
                                                .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                                                .background(Stitch.card.opacity(0.94), in: Circle())
                                        }
                                        .accessibilityLabel("Schließen")
                                        Spacer()
                                        Button { editing = true } label: {
                                            Image(systemName: "ellipsis")
                                                .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                                                .background(Stitch.card.opacity(0.94), in: Circle())
                                        }
                                        .accessibilityLabel("Bearbeiten")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Stitch.ink)
                                    .padding(Stitch.Space.page)
                                }
                            VStack(alignment: .leading, spacing: 20) {
                                Capsule().fill(Stitch.inkSoft.opacity(0.3))
                                    .frame(width: 36, height: 4)
                                    .frame(maxWidth: .infinity)
                                HStack(alignment: .firstTextBaseline, spacing: Stitch.Space.s) {
                                    Text(place.title)
                                        .font(Stitch.Face.title(30, relativeTo: .largeTitle))
                                        .foregroundStyle(Stitch.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .accessibilityAddTraits(.isHeader)
                                    Spacer(minLength: Stitch.Space.xs)
                                    Button {
                                        if place.franked { editing = true }
                                        else { addToPlan(place) }
                                    } label: {
                                        Image(systemName: place.franked ? "bookmark.fill" : "bookmark")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(Stitch.ink)
                                            .contentTransition(.symbolEffect(.replace))
                                            .symbolEffect(.bounce, value: reduceMotion ? 0 : plannedTick)
                                            .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                                            .background(place.franked ? Stitch.selection : Stitch.paperDeep, in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .sensoryFeedback(.success, trigger: plannedTick)
                                    .accessibilityLabel(place.franked ? "Plan ändern" : "Zum Reiseplan hinzufügen")
                                    .accessibilityValue(place.franked ? "Im Reiseplan" : "Nicht im Reiseplan")
                                }
                                Label(place.category, systemImage: "mappin.and.ellipse")
                                    .font(.body)
                                    .foregroundStyle(Stitch.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                                PlaceStatusTrail(place: place)
                                    .animation(reduceMotion ? Stitch.Motion.reducedFade : Stitch.Motion.panel, value: place.franked)
                                    .animation(reduceMotion ? Stitch.Motion.reducedFade : Stitch.Motion.panel, value: place.visited)
                                if !facts(place).isEmpty || !place.note.isEmpty {
                                    VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                                        if !place.note.isEmpty {
                                            Text(place.note)
                                                .font(.body)
                                                .foregroundStyle(Stitch.ink)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        ForEach(facts(place), id: \.self) { line in
                                            Text(line)
                                                .font(.body)
                                                .foregroundStyle(Stitch.inkSoft)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                detailActions(place)
                                if place.franked {
                                    VisitedTrack(visited: place.visited) { var p = place; p.visited = true; store.upsert(p) }
                                }
                                if place.photoAssets.count > 1 {
                                    Text("Fotos")
                                        .font(Stitch.Face.place(22, relativeTo: .title3))
                                        .foregroundStyle(Stitch.ink)
                                    PhotoGallery(photos: place.photoAssets, root: store.root, title: place.title) { photo, source in
                                        var instant = Transaction(animation: nil); instant.disablesAnimations = true
                                        withTransaction(instant) { viewing = PhotoView(photo: photo, source: source) }
                                    }
                                    .frame(height: 132)
                                }
                                if hasCredits(place) { credits(place) }
                            }
                            .padding(Stitch.Space.page)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Stitch.card, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
                            .padding(.top, -24)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .background(Stitch.card)
                    .toolbar(.hidden, for: .navigationBar)
                    .sheet(isPresented: $editing) { PlaceEditor(place: place) }
                    .fullScreenCover(item: $viewing) { PhotoViewer(place: place, root: store.root, source: $0.source, photo: $0.photo) }
                }
            }
        }
        // Gelöscht (im Editor): Das Detail hat nichts mehr zu zeigen.
        .onChange(of: place == nil) { _, gone in if gone { dismiss() } }
    }

    @ViewBuilder private func detailActions(_ place: Place) -> some View {
        // Four compact tiles fit the reference on regular sizes. Accessibility
        // sizes use two columns so labels stay readable and tappable.
        if dynamicTypeSize.isAccessibilitySize {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Stitch.Space.s), GridItem(.flexible(), spacing: Stitch.Space.s)], spacing: Stitch.Space.s) {
                detailActionGridItems(place)
            }
        } else {
            HStack(spacing: Stitch.Space.xs) {
                detailActionRowItems(place)
            }
        }
    }

    @ViewBuilder private func detailActionRowItems(_ place: Place) -> some View {
        Button { openWalkingRoute(to: place) } label: {
            detailActionLabel("Route", symbol: "location", disabled: place.coordinate == nil)
        }
        .buttonStyle(.plain)
        .disabled(place.coordinate == nil)

        Button { editing = true } label: {
            detailActionLabel("Plan ändern", symbol: "plus", selected: true)
        }
        .buttonStyle(.plain)

        if let url = LinkValidation.url(place.sourceURL) {
            ShareLink(item: url) { detailActionLabel("Teilen", symbol: "square.and.arrow.up") }
                .buttonStyle(.plain)
            Link(destination: url) { detailActionLabel("Website", symbol: "safari") }
                .buttonStyle(.plain)
        } else {
            Button {} label: { detailActionLabel("Teilen", symbol: "square.and.arrow.up", disabled: true) }
                .buttonStyle(.plain)
                .disabled(true)
            Button {} label: { detailActionLabel("Website", symbol: "safari", disabled: true) }
                .buttonStyle(.plain)
                .disabled(true)
        }
    }

    @ViewBuilder private func detailActionGridItems(_ place: Place) -> some View {
        Button { openWalkingRoute(to: place) } label: {
            detailActionLabel("Route", symbol: "location", disabled: place.coordinate == nil)
        }
        .buttonStyle(.plain)
        .disabled(place.coordinate == nil)

        Button { editing = true } label: {
            detailActionLabel("Plan ändern", symbol: "plus", selected: true)
        }
        .buttonStyle(.plain)

        if let url = LinkValidation.url(place.sourceURL) {
            ShareLink(item: url) { detailActionLabel("Teilen", symbol: "square.and.arrow.up") }
                .buttonStyle(.plain)
            Link(destination: url) { detailActionLabel("Website", symbol: "safari") }
                .buttonStyle(.plain)
        } else {
            Button {} label: { detailActionLabel("Teilen", symbol: "square.and.arrow.up", disabled: true) }
                .buttonStyle(.plain)
                .disabled(true)
            Button {} label: { detailActionLabel("Website", symbol: "safari", disabled: true) }
                .buttonStyle(.plain)
                .disabled(true)
        }
    }

    private func detailActionLabel(_ title: String, symbol: String, selected: Bool = false, disabled: Bool = false) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 21, weight: .regular))
            Text(title).font(.caption).multilineTextAlignment(.center)
        }
        .foregroundStyle(disabled ? Stitch.inkSoft : Stitch.ink)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(selected ? Stitch.selection : Stitch.paper, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Stitch.rule.opacity(0.6), lineWidth: 0.5))
    }

    private func addToPlan(_ place: Place) {
        withAnimation(reduceMotion ? Stitch.Motion.reducedFade : Stitch.Motion.press) {
            _ = store.upsert(store.decided(place, approve: true))
        }
        plannedTick += 1
        AccessibilityNotification.Announcement("Zum Reiseplan hinzugefügt").post()
    }

    /// Bildnachweis direkt am Foto; ausführlich mit Lizenz steht er unten im Blatt.
    @ViewBuilder private func photoCredit(_ place: Place) -> some View {
        if case .external(let image) = place.image, !image.credit.isEmpty {
            Text("Foto: \(image.credit)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, Stitch.Space.xs)
                .padding(.vertical, 3)
                .background(.black.opacity(0.45), in: Capsule())
                // Links bleibt Platz, unten liegt das Blatt 24 pt über dem Foto.
                .padding(.leading, 96)
                .padding(.trailing, Stitch.Space.s)
                .padding(.bottom, 24 + Stitch.Space.xs)
                .accessibilityHidden(true)
        }
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
        place.image?.credit != nil || !(place.gallery ?? []).isEmpty
    }

    private func credits(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
            if let source = place.image?.sourceURL, let url = URL(string: source) {
                let license: String? = if case .external(let image) = place.image { image.licenseName } else { nil }
                Link("Foto: \(place.image?.credit ?? "Quelle")\(license.map { " · \($0)" } ?? "")", destination: url)
                if case .external(let image) = place.image,
                   let licenseName = image.licenseName,
                   let licenseURL = image.licenseURL.flatMap(URL.init(string:)) {
                    Link("Lizenz · \(licenseName)", destination: licenseURL)
                }
            } else if let credit = place.image?.credit {
                Text(credit)
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

/// Idee → Geplant → Besucht: überall dieselben drei Wörter für denselben Weg eines Orts.
private struct PlaceStatusTrail: View {
    let place: Place
    private static let steps: [(title: String, symbol: String)] = [
        ("Idee", "lightbulb"), ("Geplant", "calendar"), ("Besucht", "checkmark.seal.fill")
    ]
    private var current: Int { place.visited ? 2 : place.franked ? 1 : 0 }

    var body: some View {
        // Passt die ganze Zeile nicht (große Schrift, schmales Querformat), steht nur der aktuelle Schritt da.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Stitch.Space.xxs) {
                ForEach(Self.steps.indices, id: \.self) { index in
                    if index > 0 {
                        Capsule()
                            .fill(index <= current ? Stitch.ink.opacity(0.45) : Stitch.rule)
                            .frame(width: 12, height: 2)
                    }
                    step(index)
                }
            }
            step(current)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status")
        .accessibilityValue(Self.steps[current].title)
    }

    private func step(_ index: Int) -> some View {
        let isCurrent = index == current
        return Label(Self.steps[index].title, systemImage: Self.steps[index].symbol)
            .font(.footnote.weight(isCurrent ? .semibold : .regular))
            .foregroundStyle(isCurrent ? (index == 2 ? Stitch.teal : Stitch.ink) : Stitch.inkSoft)
            .padding(.horizontal, Stitch.Space.xs)
            .padding(.vertical, 5)
            .background(isCurrent ? Stitch.selection : Color.clear, in: Capsule())
    }
}

/// A quiet horizontal gallery for the detail sheet. It renders only assets that
/// already belong to the place and keeps every photo a normal rounded thumbnail.
private struct PhotoGallery: View {
    let photos: [PlaceImageAsset]
    let root: URL
    let title: String
    let onOpen: (PlaceImageAsset, CGRect) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: Stitch.Space.s) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                    PhotoGalleryCell(photo: photo, root: root, title: title, index: index, total: photos.count, onOpen: onOpen)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .accessibilityIdentifier("Foto-Galerie")
    }
}

private struct PhotoGalleryCell: View {
    let photo: PlaceImageAsset
    let root: URL
    let title: String
    let index: Int
    let total: Int
    let onOpen: (PlaceImageAsset, CGRect) -> Void
    @State private var frame: CGRect = .zero

    var body: some View {
        Button { onOpen(photo, frame) } label: {
            AlbumPhoto(asset: photo, root: root, thumbnailWidth: 500)
                .frame(width: 156, height: 124)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Stitch.rule.opacity(0.5), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .accessibilityLabel("Foto von \(title), \(index + 1) von \(total)")
    }
}

extension Place {
    func matchesMapSearch(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || title.localizedStandardContains(trimmed) || address.localizedStandardContains(trimmed)
    }
}
