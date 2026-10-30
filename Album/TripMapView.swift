import SwiftUI
import MapKit

struct TripMapView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var drawerMorph
    @State private var camera: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedID: String?
    @State private var selectionRequest = 0
    @State private var detail: Place?
    @State private var clusterSelection: MapPinGroup?
    @State private var lastTappedClusterID: String?
    @State private var filter = MapFilter.all
    @State private var query = ""
    @State private var detent = DrawerDetent.half
    @State private var coveredHeight: CGFloat = 0
    @State private var coveredWidth: CGFloat = 0
    @State private var hasAutoFittedCamera = false
    @State private var projectedPins: [MapPinProjection] = []
    @State private var projectedFingerprint: [String] = []
    /// Orte, die schon einmal auf der Karte gelandet sind. Nur neue fallen als Stecknadel.
    @AppStorage("album.landedPins") private var landedRaw = ""

    var visible: [Place] { store.franked.filter { $0.coordinate != nil && filter.matches($0.category) && matchesQuery($0) } }

    private func matchesQuery(_ place: Place) -> Bool {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || place.title.localizedCaseInsensitiveContains(text) || place.category.localizedCaseInsensitiveContains(text)
    }
    private var selectedDay: TripDay? { visible.first { $0.id == selectedID }?.plannedDate }

    /// Orte eines Tages, verbunden in geplanter Reihenfolge.
    private var dayThreads: [(day: TripDay, coordinates: [CLLocationCoordinate2D])] {
        store.tripCalendar.days.map { day in (day, store.plan(for: day).filter { filter.matches($0.category) }.compactMap(\.coordinate)) }
            .filter { $0.1.count > 1 }
    }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            ZStack(alignment: isLandscape ? .topLeading : .bottom) {
                map
                    // Das Kartenfenster folgt dem eingerasteten Blattrand; im Querformat bleibt rechts Kartenfläche frei.
                    .safeAreaPadding(.bottom, isLandscape ? 0 : min(coveredHeight, geo.size.height * 0.5))
                    .safeAreaPadding(.leading, isLandscape ? min(coveredWidth, geo.size.width * 0.5) : 0)
                    .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
                    .padding(.top, Stitch.Size.button + Stitch.Space.s + Stitch.Space.xs)
                    .padding(.horizontal, Stitch.Space.page)
                    .accessibilityHidden(detent == .full && !isLandscape)
                searchBar
                    .padding(.leading, isLandscape ? min(coveredWidth, geo.size.width * 0.5) : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                PlacesDrawer(detent: $detent, filter: $filter, query: query, selectedID: $selectedID, selectionRequest: $selectionRequest,
                             coveredHeight: $coveredHeight, coveredWidth: $coveredWidth, namespace: drawerMorph,
                             isLandscape: isLandscape, availableHeight: geo.size.height, availableWidth: geo.size.width,
                             onShow: show, onDetails: { detail = $0 })
                    .padding(.horizontal, isLandscape || detent == .full ? 0 : Stitch.Space.page)
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
                            Rectangle().fill(Stitch.card)
                                .matchedGeometryEffect(id: "places-drawer-surface", in: drawerMorph, isSource: true)
                                .clipShape(Capsule())
                        }
                        .stitchElevation(.floating)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(drawerTitle)
                    .accessibilityHint("Öffnet die Ortsliste")
                    .accessibilityIdentifier("map-drawer-reopen")
                    .padding(.bottom, isLandscape ? 0 : Stitch.Size.button + Stitch.Space.xxl + Stitch.Space.xs)
                    .padding(.top, isLandscape ? Stitch.Space.s : 0)
                    .padding(.leading, isLandscape ? Stitch.Space.s : 0)
                    .transition(.opacity)
                }
            }
        }
        .preference(key: AssistantBottomClearanceKey.self, value: coveredHeight)
        .navigationTitle("Karte")
        .navigationBarTitleDisplayMode(.inline)
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
            if let selectedID, !store.franked.contains(where: { $0.id == selectedID && newFilter.matches($0.category) }) {
                self.selectedID = nil
            }
        }
        .onChange(of: store.places.map(\.id)) { _, ids in
            lastTappedClusterID = nil
            if let detail, !ids.contains(detail.id) { self.detail = nil }
        }
        .onChange(of: store.data.albumID) { _, _ in resetCameraForTripChange() }
        .onChange(of: store.tripRegionContext) { _, _ in resetCameraForTripChange() }
    }

    /// Suchfeld und Filter über der Karte (Figma 05): Tippen filtert Karte und Liste nach Name oder Art.
    private var searchBar: some View {
        HStack(spacing: Stitch.Space.xs) {
            Image(systemName: "magnifyingglass").font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
                .accessibilityHidden(true)
            TextField("\(store.tripName) durchsuchen", text: $query)
                .font(Stitch.Face.body).foregroundStyle(Stitch.ink)
                .submitLabel(.search)
                .accessibilityIdentifier("map-search")
            Menu {
                Picker("Filter", selection: $filter) {
                    ForEach(MapFilter.allCases) { item in
                        if let symbol = item.symbol { Label(item.title, systemImage: symbol).tag(item) } else { Text(item.title).tag(item) }
                    }
                }
            } label: {
                Image(systemName: filter == .all ? "slider.horizontal.3" : "line.3.horizontal.decrease.circle.fill")
                    .font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
                    .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
            }
            .accessibilityLabel(filter == .all ? "Filter" : "Filter: \(filter.title)")
            .accessibilityIdentifier("map-filter")
        }
        .padding(.leading, Stitch.Space.m)
        .padding(.trailing, Stitch.Space.xxs)
        .frame(minHeight: Stitch.Size.button)
        .background(Stitch.card, in: Capsule())
        .overlay(Capsule().strokeBorder(Stitch.line))
        .padding(.horizontal, Stitch.Space.page)
        .padding(.top, Stitch.Space.xs)
    }

    private var drawerTitle: String {
        let count = store.franked.filter { filter.matches($0.category) && matchesQuery($0) }.count
        return count == 1 ? "1 Ort" : "\(count) Orte"
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $camera) {
                ForEach(dayThreads, id: \.day) { thread in
                    let isSelectedDay = selectedDay == thread.day
                    MapPolyline(coordinates: thread.coordinates)
                        .stroke(isSelectedDay ? Stitch.action : Stitch.inkSoft.opacity(0.28),
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
                let changed = visibleRegion.map { previous in
                    abs(region.center.latitude - previous.center.latitude) > tolerance
                        || abs(region.center.longitude - previous.center.longitude) > tolerance
                        || abs(region.span.latitudeDelta - previous.span.latitudeDelta) > tolerance
                        || abs(region.span.longitudeDelta - previous.span.longitudeDelta) > tolerance
                } ?? true
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
            .accessibilityLabel("Karte mit \(visible.count) beschlossenen Orten")
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
        let span = visibleRegion?.span ?? store.tripRegionContext.region?.span
            ?? MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)
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
        guard !hasAutoFittedCamera else { return }
        if let rect = Self.initialCameraRect(for: visible.compactMap(\.coordinate)) {
            hasAutoFittedCamera = true
            camera = .rect(rect)
        } else if let region = store.tripRegionContext.region {
            hasAutoFittedCamera = true
            visibleRegion = region
            camera = .region(region)
        }
    }

    private func resetCameraForTripChange() {
        hasAutoFittedCamera = false
        visibleRegion = nil
        selectedID = nil
        clusterSelection = nil
        lastTappedClusterID = nil
        if visible.isEmpty && store.tripRegionContext.region == nil {
            camera = .automatic
        }
        fitInitialCameraIfNeeded()
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
        let width: CGFloat = selected ? 52 : 38
        VStack(spacing: 2) {
            StampFrame(mat: place.mat, inset: 3, matWidth: 2) {
                AlbumPhoto(asset: place.displayImage, root: root, thumbnailWidth: 120)
                    .frame(width: width, height: width * 1.18)
                    .overlay {
                        if place.displayImage == nil {
                            Image(systemName: place.symbol).font(.footnote.weight(.semibold)).foregroundStyle(Stitch.ink)
                        }
                    }
            }
            Circle().fill(Stitch.action).frame(width: 7, height: 7)
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
        .accessibilityElement().accessibilityLabel(place.title)
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
                .background(Circle().fill(Stitch.action))
                .overlay(Circle().strokeBorder(Stitch.card, lineWidth: 1.5))
                .offset(x: 5, y: -3)
                .accessibilityHidden(true)
        }
        .frame(width: 58, height: 58)
        .accessibilityHidden(true)
    }

    private func stamp(_ place: Place, size: CGFloat) -> some View {
        StampFrame(mat: place.mat, inset: 2, matWidth: 2) {
            AlbumPhoto(asset: place.displayImage, root: root, thumbnailWidth: 96)
                .frame(width: size, height: size * 1.16)
                .overlay {
                    if place.displayImage == nil {
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
    @State private var choosingDay = false
    @State private var galleryOpen = false
    @State private var viewing: PhotoView?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var place: Place? { store.places.first { $0.id == placeID } }

    /// Ein Foto des Stapels im Vollbild, mit dem Rahmen, aus dem es wächst.
    private struct PhotoView: Identifiable {
        let id = UUID()
        let photo: PlaceImageAsset
        let source: CGRect
    }

    /// Ortsdetail nach Figma 10 (Kopf, Foto, Karte mit Kacheln, Fotos) und 11 (Weitere Infos: Ort und Adresse, Warum da hin, Planung, Bearbeiten).
    var body: some View {
        NavigationStack {
            if let place {
                VStack(spacing: 0) {
                    PlaceSheetHeader(title: place.title, onBack: { dismiss() }, onClose: { dismiss() })
                    ScrollView {
                        VStack(alignment: .leading, spacing: Stitch.Space.m) {
                            hero(place)
                            summaryCard(place)
                            if place.franked {
                                VisitedTrack(visited: place.visited) { var p = place; p.visited = true; store.upsert(p) }
                            }
                            if place.photoAssets.count > 1 { photosSection(place) }
                            SectionTitle("Weitere Infos").padding(.top, Stitch.Space.xs)
                            if !place.address.isEmpty || place.coordinate != nil { addressCard(place) }
                            if !place.note.isEmpty { noteCard(place) }
                            planningCard(place)
                            Button("Ort bearbeiten") { editing = true }
                                .buttonStyle(StitchButton())
                                .accessibilityLabel("Bearbeiten")
                            // Wikimedia verlangt die Nennung jeder Urheberin; leise ganz unten.
                            if hasCredits(place) { credits(place) }
                        }
                        .padding(.horizontal, Stitch.Space.page)
                        .padding(.bottom, Stitch.Space.xl)
                    }
                    .scrollIndicators(.hidden)
                }
                .background(PaperBackground())
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $editing) { PlaceEditor(place: place) }
                .sheet(isPresented: $choosingDay) {
                    DayChoiceSheet(place: place, store: store) { choosingDay = false }
                }
                .fullScreenCover(isPresented: $galleryOpen) {
                    PlaceGallery(place: place, root: store.root) { galleryOpen = false }
                }
                .fullScreenCover(item: $viewing) { PhotoViewer(place: place, root: store.root, source: $0.source, photo: $0.photo) }
            }
        }
        // Gelöscht (im Editor): Das Detail hat nichts mehr zu zeigen.
        .onChange(of: place == nil) { _, gone in if gone { dismiss() } }
    }

    private func hero(_ place: Place) -> some View {
        Group {
            if place.photoAssets.count > 1 {
                PhotoStack(photos: place.photoAssets, root: store.root, title: place.title, subtitle: place.category, showsCaption: false) { photo, source in
                    var instant = Transaction(animation: nil); instant.disablesAnimations = true
                    withTransaction(instant) { viewing = PhotoView(photo: photo, source: source) }
                }
                .frame(height: 300)
            } else {
                PhotoCard(asset: place.displayImage, root: store.root, title: place.title, subtitle: place.category, showsCaption: false).frame(height: 300)
            }
        }
        .overlay(alignment: .topLeading) {
            if place.visited {
                VisitedStamp().padding(Stitch.Space.m)
                    .transition(reduceMotion ? .opacity : .scale(scale: 1.8).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? Stitch.Motion.reducedFade : .spring(response: 0.34, dampingFraction: 0.55), value: place.visited)
    }

    /// Karte mit Name, Kategorie und Ort, Herkunft und den vier Kacheln Route, Plan, Teilen, Website.
    private func summaryCard(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Text(place.title).font(Stitch.Face.display(30)).foregroundStyle(Stitch.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(([place.category] + facts(place).prefix(1)).joined(separator: " · "))
                .font(Stitch.Face.subheadline).foregroundStyle(Stitch.inkSoft)
            if let from = authorLine(place) { Text(from).font(Stitch.Face.footnote).foregroundStyle(Stitch.inkSoft) }
            HStack(spacing: Stitch.Space.xs) {
                Button { openWalkingRoute(to: place) } label: { TileFace(title: "Route", symbol: "location") }
                    .buttonStyle(.plain).disabled(place.coordinate == nil).opacity(place.coordinate == nil ? 0.45 : 1)
                    .accessibilityLabel("Route")
                Button { choosingDay = true } label: { TileFace(title: "Plan", symbol: "plus", selected: place.plannedDate != nil) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Plan")
                    .accessibilityIdentifier("place-detail-plan")
                shareTile(place)
                websiteTile(place)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stitchCard(.pinned, padding: Stitch.Space.m)
    }

    @ViewBuilder private func shareTile(_ place: Place) -> some View {
        if let url = LinkValidation.url(place.sourceURL) {
            ShareLink(item: url, subject: Text(place.title)) { TileFace(title: "Teilen", symbol: "square.and.arrow.up") }
                .buttonStyle(.plain).accessibilityLabel("Teilen")
        } else {
            ShareLink(item: [place.title, place.address].filter { !$0.isEmpty }.joined(separator: ", ")) {
                TileFace(title: "Teilen", symbol: "square.and.arrow.up")
            }
            .buttonStyle(.plain).accessibilityLabel("Teilen")
        }
    }

    @ViewBuilder private func websiteTile(_ place: Place) -> some View {
        if let url = LinkValidation.url(place.sourceURL) {
            Link(destination: url) { TileFace(title: "Website", symbol: "globe") }
                .buttonStyle(.plain)
                .accessibilityLabel("Bei \(place.sourceLabel) ansehen")
        } else {
            TileFace(title: "Website", symbol: "globe").opacity(0.45).accessibilityHidden(true)
        }
    }

    private func photosSection(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            SectionTitle(title: "Fotos") {
                Button("Alle ansehen") { galleryOpen = true }
                    .buttonStyle(TextActionButton())
                    .accessibilityIdentifier("place-detail-gallery")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Stitch.Space.xs) {
                    ForEach(Array(place.photoAssets.enumerated()), id: \.offset) { _, asset in
                        Button { galleryOpen = true } label: {
                            AlbumPhoto(asset: asset, root: store.root, thumbnailWidth: 300)
                                .frame(width: 116, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.small, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Foto von \(place.title)")
                    }
                }
            }
        }
    }

    private func addressCard(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Text("Ort & Adresse").font(Stitch.Face.section).foregroundStyle(Stitch.ink)
            if !place.address.isEmpty {
                Text(place.address).font(Stitch.Face.subheadline).foregroundStyle(Stitch.inkSoft)
            }
            if place.coordinate != nil {
                Button("In Karten öffnen") { openInMaps(place) }.buttonStyle(StitchButton())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stitchCard(.pinned, padding: Stitch.Space.m)
    }

    private func noteCard(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            Text("Warum da hin?").font(Stitch.Face.section).foregroundStyle(Stitch.ink)
            Text(place.note).font(Stitch.Face.body).foregroundStyle(Stitch.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stitchCard(.pinned, padding: Stitch.Space.m)
    }

    private func planningCard(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Text("Planung").font(Stitch.Face.section).foregroundStyle(Stitch.ink)
            Button { choosingDay = true } label: {
                LabeledFieldBox(label: "Tag") {
                    Text(place.plannedDate.map { store.tripCalendar.dayTitle($0) } ?? "Noch offen")
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(place.plannedDate.map { "Tag, \(store.tripCalendar.dayTitle($0))" } ?? "Tag, noch offen")
            .accessibilityAddTraits(.isButton)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stitchCard(.pinned, padding: Stitch.Space.m)
    }

    /// Adresse, Tag, Herkunft – nur was stimmt.
    private func facts(_ place: Place) -> [String] {
        var lines: [String] = []
        if !place.address.isEmpty { lines.append(place.address) }
        return lines
    }

    private func authorLine(_ place: Place) -> String? {
        guard place.author != store.me, place.author.localizedCaseInsensitiveCompare("Wir") != .orderedSame else { return nil }
        return "Von \(place.author) eingeworfen"
    }

    private func openInMaps(_ place: Place) {
        guard let coordinate = place.coordinate else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = place.title
        item.openInMaps()
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

/// Galerie (Figma 12): dunkle Seite, großes Foto mit „Name · n von m“, Bildnachweis, Vorschaustreifen.
struct PlaceGallery: View {
    let place: Place
    let root: URL
    let onClose: () -> Void
    @State private var index = 0

    private var photos: [PlaceImageAsset] { place.photoAssets.isEmpty ? (place.displayImage.map { [$0] } ?? []) : place.photoAssets }

    var body: some View {
        VStack(spacing: 0) {
            PlaceSheetHeader(title: "Fotos", dark: true, onBack: onClose, onClose: onClose)
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.s) {
                    if photos.indices.contains(index) {
                        AlbumPhoto(asset: photos[index], root: root, thumbnailWidth: 1200)
                            .frame(height: 490).frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
                            .accessibilityLabel("Foto von \(place.title), \(index + 1) von \(photos.count)")
                        Text("\(place.title) · \(index + 1) von \(photos.count)")
                            .font(Stitch.Face.headline).foregroundStyle(Stitch.onAction).monospacedDigit()
                        if let credit = photos[index].credit {
                            Text("Foto: \(credit)").font(Stitch.Face.footnote).foregroundStyle(Stitch.onAction.opacity(0.85))
                        }
                    }
                    if photos.count > 1 {
                        HStack(spacing: Stitch.Space.xs) {
                            ForEach(Array(photos.enumerated()), id: \.offset) { offset, asset in
                                Button { index = offset } label: {
                                    AlbumPhoto(asset: asset, root: root, thumbnailWidth: 300)
                                        .frame(maxWidth: .infinity).frame(height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.small, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.small, style: .continuous)
                                            .strokeBorder(Stitch.onAction, lineWidth: offset == index ? 2 : 0))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Foto \(offset + 1) wählen")
                                .accessibilityAddTraits(offset == index ? .isSelected : [])
                            }
                        }
                    }
                }
                .padding(.horizontal, Stitch.Space.page).padding(.bottom, Stitch.Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background(Stitch.scrim.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
    }
}
