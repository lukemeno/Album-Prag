import SwiftUI
import MapKit

/// Die drei Höhen des Blatts über der Karte.
enum DrawerDetent: CaseIterable { case collapsed, half, full }

/// Ein Stück Leinen über der Karte: alle beschlossenen Orte nach Tagen, mit Fotos, Route und Tag.
/// Ersetzt das frühere Tagesplan-Blatt; Planen und Umsortieren passieren hier.
/// Bewusst Teil der Karten-Ansicht statt eines Systemblatts, damit die Tab-Leiste erreichbar bleibt.
struct PlacesDrawer: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var detent: DrawerDetent
    @Binding var filter: MapFilter
    @Binding var selectedID: String?
    /// Höhe, die das Blatt gerade verdeckt; die Karte richtet ihren Inhalt darüber aus.
    @Binding var coveredHeight: CGFloat
    /// Platz zwischen Navigationsleiste und Tab-Leiste.
    let available: CGFloat
    var onShow: (Place) -> Void
    var onDetails: (Place) -> Void

    @State private var headerHeight: CGFloat = 150
    @State private var drag: CGFloat = 0
    @State private var editing = false
    @State private var proposing = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                .contentShape(Rectangle())
                .gesture(dragGesture)
            if currentHeight > headerHeight + 1 {
                if editing { editList } else { list }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: currentHeight, alignment: .top)
        .background(alignment: .top) {
            // Das Leinen reicht unter die Tab-Leiste, der Inhalt endet über ihr.
            LinenBackground()
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Stitch.Radius.floating, topTrailingRadius: Stitch.Radius.floating, style: .continuous))
                .stitchElevation(.floating)
                .ignoresSafeArea(edges: .bottom)
        }
        .onChange(of: detent) { _, _ in reportCovered() }
        .onChange(of: available) { _, _ in reportCovered() }
        .onChange(of: headerHeight) { _, _ in reportCovered() }
        .onAppear(perform: reportCovered)
        .onChange(of: editing) { _, isEditing in if isEditing { move(to: .full) } }
        .sheet(isPresented: $proposing) { DayPlanPreview() }
    }

    // MARK: Höhe

    private func height(for detent: DrawerDetent) -> CGFloat {
        switch detent {
        case .collapsed: headerHeight
        case .half: max(headerHeight, available * 0.5)
        case .full: max(headerHeight, available)
        }
    }

    private var currentHeight: CGFloat {
        min(max(height(for: detent) - drag, headerHeight), max(headerHeight, available))
    }

    private func reportCovered() { coveredHeight = height(for: detent) }

    private func move(to target: DrawerDetent) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86)) { detent = target; drag = 0 }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { drag = $0.translation.height }
            .onEnded { value in
                // Schwung zählt mit: Ein kurzes Wischen nach oben öffnet, auch wenn der Finger nur wenig zurücklegt.
                let projected = height(for: detent) - value.predictedEndTranslation.height
                let target = DrawerDetent.allCases.min { abs(height(for: $0) - projected) < abs(height(for: $1) - projected) } ?? detent
                if target != .full { editing = false }
                move(to: target)
            }
    }

    // MARK: Kopf

    private var planned: [Place] { store.franked.filter { $0.category != "Unterkunft" } }

    private var header: some View {
        VStack(spacing: Stitch.Space.s) {
            grabber
            HStack(alignment: .center, spacing: Stitch.Space.s) {
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text(title).font(.title3.weight(.bold)).foregroundStyle(Stitch.ink)
                    Text(subtitle).font(.footnote).foregroundStyle(Stitch.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if !planned.isEmpty {
                    Button { proposing = true } label: { Image(systemName: "wand.and.stars") }
                        .buttonStyle(HeaderIconButton())
                        .accessibilityLabel("Automatisch planen")
                    Button(editing ? "Fertig" : "Bearbeiten") { editing.toggle() }
                        .font(.body.weight(.semibold)).foregroundStyle(Stitch.red)
                        .frame(minHeight: Stitch.Size.touch)
                }
            }
            .padding(.horizontal, Stitch.Space.page)
            if !planned.isEmpty && !editing { filterChips }
        }
        .padding(.bottom, Stitch.Space.s)
    }

    private var title: String {
        if planned.isEmpty { return "Noch keine Orte" }
        let count = visiblePlaces.count
        return count == 1 ? "1 Ort" : "\(count) Orte"
    }

    private var subtitle: String {
        if planned.isEmpty { return "Ideen, für die du dich entscheidest, landen hier." }
        if let today = TripDates.tripDay() {
            let count = store.plan(for: today).count
            return count == 0 ? "Heute ist noch nichts geplant" : "Heute \(count == 1 ? "1 Ort" : "\(count) Orte")"
        }
        let days = Set(planned.compactMap(\.day)).count
        let open = planned.filter { $0.day == nil }.count
        var parts = [days == 1 ? "1 Tag geplant" : "\(days) Tage geplant"]
        if open > 0 { parts.append("\(open) ohne Tag") }
        return parts.joined(separator: " · ")
    }

    /// Griff als kurzer Vorstich auf einer Saumlinie: Ziehen oder Tippen ändert die Höhe.
    private var grabber: some View {
        Button {
            move(to: detent == .half ? .full : .half)
        } label: {
            // Saumlinie links und rechts, in der Mitte der kräftigere Stich als Griff.
            HStack(spacing: Stitch.Space.xs) {
                seam
                StitchLine().stroke(Stitch.inkSoft, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 4]))
                    .frame(width: 44, height: 3)
                seam
            }
            .padding(.horizontal, Stitch.Space.l)
            .frame(maxWidth: .infinity, minHeight: Stitch.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Wischen am Griff bewegt das Blatt; nur ein Tipp ohne Bewegung zählt als Knopfdruck.
        .highPriorityGesture(dragGesture)
        .accessibilityLabel(detent == .full ? "Liste einklappen" : "Liste ausklappen")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(to: detent == .collapsed ? .half : .full)
            case .decrement: move(to: detent == .full ? .half : .collapsed)
            @unknown default: break
            }
        }
    }

    private var seam: some View {
        StitchLine().stroke(Stitch.inkSoft.opacity(0.25), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 5]))
            .frame(height: 1)
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Stitch.Space.xs) {
                ForEach(MapFilter.allCases) { item in
                    Button { withAnimation(reduceMotion ? nil : .snappy) { filter = item } } label: {
                        HStack(spacing: Stitch.Space.xs) {
                            if let symbol = item.symbol {
                                StitchedSymbol(name: symbol, rows: 9, cell: 2, color: filter == item ? Stitch.onAccent : item.thread)
                            }
                            Text(item.title).font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, Stitch.Space.m).frame(minHeight: Stitch.Size.touch)
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
    }

    // MARK: Liste

    private struct Section: Identifiable {
        /// Immer mit „section-“ davor: Orte und Abschnitte teilen sich die Kennungen der Liste.
        let id: String
        let title: String
        var isToday = false
        let stops: [PlanStop]
    }

    private var visiblePlaces: [Place] { store.franked.filter { filter.matches($0.category) } }

    private var sections: [Section] {
        let windows = DayPlanGenerator.windows(flights: store.data.trip.flights ?? [])
        let today = TripDates.tripDay()
        var result: [Section] = []
        // Die Unterkunft zuerst: Unterwegs ist ihre Adresse das, was man am häufigsten sucht.
        let hotels = visiblePlaces.filter { $0.category == "Unterkunft" }
        if !hotels.isEmpty {
            result.append(Section(id: "section-hotel", title: "Unterkunft", stops: hotels.map { PlanStop(place: $0, slot: "", note: nil) }))
        }
        for day in DayPlanGenerator.days {
            // Zeiten aus dem ganzen Tag rechnen, erst dann filtern: Ein Filter verschiebt keine Uhrzeiten.
            let stops = DayPlanGenerator.timeline(store.plan(for: day), day: day, window: windows[day]!, hotel: store.hotelCoordinate)
                .filter { filter.matches($0.place.category) }
            // Mit Filter nur Tage mit Treffern; ohne Filter alle Reisetage, damit freie Tage sichtbar sind.
            guard !stops.isEmpty || filter == .all else { continue }
            result.append(Section(id: "section-day-\(day)", title: TripDates.dayTitle(day), isToday: day == today, stops: stops))
        }
        let open = visiblePlaces.filter { $0.day == nil && $0.category != "Unterkunft" }
        if !open.isEmpty {
            result.append(Section(id: "section-open", title: "Noch ohne Tag", stops: open.map { PlanStop(place: $0, slot: "", note: nil) }))
        }
        return result
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Rhythmus wie überall: Überschrift → Inhalt 12, Karte → Karte 12, Abschnitt → Abschnitt 32.
                LazyVStack(alignment: .leading, spacing: Stitch.Space.xl) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: Stitch.Space.s) {
                            sectionHeader(section)
                            if section.stops.isEmpty {
                                Text("Noch frei").font(.subheadline).foregroundStyle(Stitch.inkSoft)
                            }
                            ForEach(section.stops) { stop in
                                PlaceRow(stop: stop, root: store.root, selected: selectedID == stop.id,
                                         onShow: { onShow(stop.place) }, onDetails: { onDetails(stop.place) })
                                    .id(stop.id)
                            }
                        }
                        .id(section.id)
                    }
                }
                .padding(.horizontal, Stitch.Space.page)
                .padding(.top, Stitch.Space.s)
                .padding(.bottom, Stitch.Space.xl)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selectedID) { _, id in
                guard let id else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { proxy.scrollTo(id, anchor: .top) }
            }
            .onAppear {
                // Während der Reise beginnt die Liste bei heute.
                if let today = TripDates.tripDay() { proxy.scrollTo("section-day-\(today)", anchor: .top) }
            }
        }
    }

    private func sectionHeader(_ section: Section) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Stitch.Space.xs) {
            if section.isToday { Text("Heute").font(.headline).foregroundStyle(Stitch.red) }
            Text(section.title).font(.headline).foregroundStyle(Stitch.ink)
            Spacer(minLength: 0)
            if !section.stops.isEmpty {
                Text(section.stops.count == 1 ? "1 Ort" : "\(section.stops.count) Orte")
                    .font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Bearbeiten

    private var editList: some View {
        List {
            ForEach(DayPlanGenerator.days, id: \.self) { day in
                let places = store.plan(for: day)
                SwiftUI.Section(TripDates.dayTitle(day)) {
                    if places.isEmpty { Text("Noch frei").foregroundStyle(Stitch.inkSoft) }
                    ForEach(places) { editRow($0) }
                        .onMove { source, destination in
                            var ids = places.map(\.id)
                            ids.move(fromOffsets: source, toOffset: destination)
                            store.reorder(day: day, ids: ids)
                        }
                }
                .listRowBackground(Stitch.card)
            }
            let open = planned.filter { $0.day == nil }
            if !open.isEmpty {
                SwiftUI.Section("Noch ohne Tag") { ForEach(open) { editRow($0) } }
                    .listRowBackground(Stitch.card)
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
    }

    private func editRow(_ place: Place) -> some View {
        HStack(spacing: Stitch.Space.s) {
            AlbumPhoto(asset: place.image, root: store.root, thumbnailWidth: 120).frame(width: Stitch.Size.thumb, height: Stitch.Size.thumb)
                .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                .accessibilityHidden(true)
            Text(place.title).font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
            Spacer(minLength: 0)
            DayMenu(place: place)
        }
    }
}

/// Ein Ort als Stoffkarte: Name, Art, Tageszeit, Fotos und die zwei Wege, die man unterwegs braucht.
private struct PlaceRow: View {
    let stop: PlanStop
    let root: URL
    let selected: Bool
    var onShow: () -> Void
    var onDetails: () -> Void
    private var place: Place { stop.place }

    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Button(action: onShow) {
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: Stitch.Space.xs) {
                        Text(place.title).font(.headline).foregroundStyle(Stitch.ink).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        if place.visited {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Stitch.cobalt).accessibilityLabel("Besucht")
                        }
                    }
                    HStack(spacing: Stitch.Space.xs) {
                        StitchedSymbol(name: place.stitchSymbol, rows: 9, cell: 1.9, color: place.stitchThread)
                            .accessibilityHidden(true)
                        Text(meta).font(.subheadline).foregroundStyle(stop.note == nil ? Stitch.inkSoft : Stitch.red)
                    }
                    if !place.note.isEmpty {
                        Text(place.note).font(.footnote).foregroundStyle(Stitch.inkSoft).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Zeigt den Ort auf der Karte")
            .accessibilityIdentifier("place-row-\(place.id)")

            if !photos.isEmpty { photoStrip }

            HStack(spacing: Stitch.Space.l) {
                if place.coordinate != nil {
                    Button { openWalkingRoute(to: place) } label: { Label("Route", systemImage: "figure.walk") }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.red).frame(minHeight: Stitch.Size.touch)
                }
                if place.category != "Unterkunft" { DayMenu(place: place) }
                Spacer(minLength: 0)
                Button(action: onDetails) { Image(systemName: "info.circle").font(.title3) }
                    .foregroundStyle(Stitch.inkSoft).frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                    .accessibilityLabel("Details zu \(place.title)")
            }
        }
        .stitchCard()
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: Stitch.Radius.card - Stitch.Space.xxs, style: .continuous)
                    .strokeBorder(Stitch.red, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .padding(Stitch.Space.xxs)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// „Sehenswert · vormittags · bis 18:00“ – nur was stimmt; Unbekanntes bleibt weg.
    private var meta: String {
        var parts = [place.category]
        if !stop.slot.isEmpty { parts.append(stop.slot) }
        if let note = stop.note { parts.append(note) } else if let hint = closingHint { parts.append(hint) }
        return parts.joined(separator: " · ")
    }

    private var closingHint: String? {
        guard let day = place.day, let hours = place.openingHours.flatMap(OpeningHours.init) else { return nil }
        let ranges = hours.ranges(weekday: DayPlanGenerator.weekday(day))
        guard let last = ranges.last, !(last.lowerBound == 0 && last.upperBound >= 1440) else { return nil }
        return "bis \(OpeningHours.clock(last.upperBound))"
    }

    private var photos: [PlaceImageAsset] {
        guard let main = place.image else { return [] }
        return [main] + (place.gallery ?? []).map(PlaceImageAsset.external)
    }

    private var photoStrip: some View {
        Group {
            if photos.count == 1 {
                photo(photos[0]).frame(maxWidth: .infinity).frame(height: 150)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: Stitch.Space.xs) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { _, asset in
                            photo(asset).frame(width: 164, height: 124)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
        .accessibilityHidden(true)
    }

    private func photo(_ asset: PlaceImageAsset) -> some View {
        Button(action: onDetails) {
            AlbumPhoto(asset: asset, root: root, thumbnailWidth: 480)
                .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Tag eines Ortes wählen; der Ort kommt ans Ende des Tages.
struct DayMenu: View {
    @Environment(AlbumStore.self) private var store
    let place: Place
    var body: some View {
        Menu {
            Picker("Tag", selection: Binding(get: { place.day }, set: { store.assign(place, to: $0) })) {
                Text("Noch ohne Tag").tag(nil as Int?)
                ForEach(DayPlanGenerator.days, id: \.self) { Text(TripDates.dayTitle($0)).tag(Optional($0)) }
            }
        } label: {
            Label(place.day == nil ? "Tag festlegen" : "Tag ändern", systemImage: "calendar")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.red)
                .frame(minHeight: Stitch.Size.touch)
        }
        .accessibilityLabel(place.day.map { "Tag ändern, jetzt \(TripDates.dayTitle($0))" } ?? "Tag festlegen")
    }
}

/// Gerade Linie für gestrichelte Stiche.
private struct StitchLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { $0.move(to: CGPoint(x: rect.minX, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
    }
}

/// Fußweg in Apple Karten.
func openWalkingRoute(to place: Place) {
    guard let coordinate = place.coordinate else { return }
    let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    item.name = place.title
    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
}
