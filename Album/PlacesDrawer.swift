import SwiftUI
import MapKit

/// Die Höhen des Blatts über der Karte, einschließlich vollständig geschlossen.
enum DrawerDetent: CaseIterable, Hashable { case hidden, collapsed, half, full }

/// Wählt den Rastpunkt aus der tatsächlichen Fingerposition und einem kleinen, begrenzten Schwunganteil.
/// So kann die Systemprognose einen Zug unterstützen, aber keinen kurzen Zug über mehrere Rastpunkte werfen.
enum DrawerDetentResolver {
    static func target(
        from current: DrawerDetent,
        actualTranslation: CGFloat,
        predictedTranslation: CGFloat,
        extents: [DrawerDetent: CGFloat]
    ) -> DrawerDetent {
        guard let startingExtent = extents[current] else { return current }

        let momentum = predictedTranslation - actualTranslation
        let nextExtent = extents.values
            .filter { momentum >= 0 ? $0 < startingExtent : $0 > startingExtent }
            .min { abs($0 - startingExtent) < abs($1 - startingExtent) }
        let neighboringDistance = nextExtent.map { abs($0 - startingExtent) } ?? 0
        let momentumLimit = min(64, neighboringDistance * 0.2)
        let boundedMomentum = min(max(momentum, -momentumLimit), momentumLimit)
        let projectedExtent = startingExtent - actualTranslation - boundedMomentum

        return DrawerDetent.allCases.reduce(current) { closest, candidate in
            guard let candidateExtent = extents[candidate],
                  let closestExtent = extents[closest] else { return closest }
            return abs(candidateExtent - projectedExtent) < abs(closestExtent - projectedExtent) ? candidate : closest
        }
    }
}

private enum DrawerDragAxis: Equatable { case horizontal, vertical }

// Local drawer text colors remain readable on the deeper paper surface.
private enum DrawerAccessibilityColors {
    static let accent = Stitch.dynamic(light: (160, 50, 34), dark: (236, 134, 114))
    // The drawer sits on an almost-white paper surface. Keep secondary labels
    // comfortably above the audit threshold in both appearances.
    static let secondary = Stitch.dynamic(light: (57, 53, 49), dark: (190, 181, 169))
}

/// Ein Blatt Papier über der Karte: alle beschlossenen Orte nach Tagen, mit Fotos, Route und Tag.
/// Ersetzt das frühere Tagesplan-Blatt; Planen und Umsortieren passieren hier.
/// Bewusst Teil der Karten-Ansicht statt eines Systemblatts, damit die Tab-Leiste erreichbar bleibt.
struct PlacesDrawer: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var detent: DrawerDetent
    @Binding var filter: MapFilter
    @Binding var selectedID: String?
    @Binding var selectionRequest: Int
    /// Eingerasteter Blattrand, damit die Karte zwischen Rastpunkten stabil bleibt.
    @Binding var coveredHeight: CGFloat
    @Binding var coveredWidth: CGFloat
    var searchQuery: String = ""
    let namespace: Namespace.ID
    let isLandscape: Bool
    let availableHeight: CGFloat
    let availableWidth: CGFloat
    var onShow: (Place) -> Void
    var onDetails: (Place) -> Void

    @State private var headerSize = CGSize(width: 360, height: 150)
    @State private var drag: CGFloat = 0
    @State private var dragAxis: DrawerDragAxis?
    @State private var handledSelectionRequest = 0
    @State private var pendingSelectionRequest: Int?
    @State private var initialScrollApplied = false
    @State private var pendingInitialScrollTarget: String?
    @State private var editing = false
    @State private var proposing = false

    var body: some View {
        VStack(spacing: 0) {
            if detent != .hidden {
                if isLandscape && dynamicTypeSize.isAccessibilitySize {
                    compactLandscapeHeader
                    Group {
                        if editing { editList } else { compactLandscapeList }
                    }
                } else {
                    header
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { headerSize = $0 }
                        .contentShape(Rectangle())
                    Group {
                        if editing { editList } else { list }
                    }
                    .accessibilityHidden(!isLandscape && detent == .collapsed && drag == 0)
                }
            }
        }
        .frame(width: isLandscape ? layoutExtent : nil,
               height: isLandscape ? nil : layoutExtent,
               alignment: .topLeading)
        .frame(maxWidth: isLandscape ? nil : .infinity,
               maxHeight: isLandscape ? .infinity : nil,
               alignment: .topLeading)
        .clipped()
        .background(alignment: .topLeading) {
            if detent != .hidden {
                // Das Papier reicht unter Tab-Leiste oder an die linke Bildschirmkante.
                PaperBackground()
                    .matchedGeometryEffect(id: "places-drawer-surface", in: namespace, isSource: detent != .hidden)
                    .clipShape(surfaceShape)
                    .stitchElevation(.floating)
                    .ignoresSafeArea(edges: isLandscape ? .leading : .bottom)
            }
        }
        // Unterhalb des kleinsten Blatts bleibt der Kopf vollständig und fährt als Einheit aus dem Bild.
        .offset(x: isLandscape ? currentExtent - layoutExtent : 0,
                y: isLandscape ? 0 : layoutExtent - currentExtent)
        .onChange(of: detent) { _, _ in reportCovered() }
        .onChange(of: availableHeight) { _, _ in reportCovered() }
        .onChange(of: availableWidth) { _, _ in reportCovered() }
        .onChange(of: isLandscape) { _, _ in
            drag = 0
            dragAxis = nil
            reportCovered()
        }
        .onChange(of: headerSize) { _, _ in reportCovered() }
        .onAppear(perform: reportCovered)
        .onChange(of: editing) { _, isEditing in if isEditing { move(to: .full) } }
        .sensoryFeedback(.selection, trigger: detent)
        .sheet(isPresented: $proposing) { DayPlanPreview() }
    }

    // MARK: Größe

    private var availableExtent: CGFloat { isLandscape ? availableWidth : availableHeight }

    private func extent(for detent: DrawerDetent) -> CGFloat {
        switch detent {
        case .hidden: 0
        case .collapsed: isLandscape ? min(360, availableWidth) : headerSize.height
        case .half:
            isLandscape ? min(max(availableWidth * 0.46, 420), availableWidth) : max(headerSize.height, availableHeight * 0.5)
        case .full:
            isLandscape ? min(max(availableWidth * 0.66, 480), availableWidth) : max(headerSize.height, availableHeight)
        }
    }

    private var currentExtent: CGFloat {
        min(max(extent(for: detent) - drag, 0), max(availableExtent, isLandscape ? headerSize.width : headerSize.height))
    }

    private var layoutExtent: CGFloat {
        // Beim Schließen bleibt das innere Layout am gestarteten Rastpunkt stabil;
        // die ganze Fläche folgt dem Finger über den Offset, statt die Liste pro Frame neu zu setzen.
        max(max(extent(for: detent), currentExtent), extent(for: .collapsed))
    }

    private var surfaceShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: isLandscape ? 0 : Stitch.Radius.floating,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: isLandscape ? Stitch.Radius.floating : 0,
            topTrailingRadius: Stitch.Radius.floating,
            style: .continuous
        )
    }

    private func reportCovered() {
        let settledExtent = extent(for: detent)
        let newHeight = isLandscape ? 0 : settledExtent
        let newWidth = isLandscape ? settledExtent : 0
        if coveredHeight != newHeight { coveredHeight = newHeight }
        if coveredWidth != newWidth { coveredWidth = newWidth }
    }

    private func move(to target: DrawerDetent) {
        withAnimation(reduceMotion ? nil : Stitch.Motion.panel) {
            detent = target
            drag = 0
        }
    }

    private func updateDrag(_ value: DragGesture.Value) {
        let translation = value.translation
        let primary = isLandscape ? abs(translation.width) : abs(translation.height)
        let secondary = isLandscape ? abs(translation.height) : abs(translation.width)
        let activeAxis: DrawerDragAxis = isLandscape ? .horizontal : .vertical
        if dragAxis == nil {
            guard max(primary, secondary) >= 8 else { return }
            if primary > secondary * 1.1 {
                dragAxis = activeAxis
            } else if secondary > primary * 1.1 {
                dragAxis = isLandscape ? .vertical : .horizontal
            }
        }
        if dragAxis == activeAxis { drag = isLandscape ? -translation.width : translation.height }
    }

    private var grabberGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { updateDrag($0) }
            .exclusively(before: TapGesture())
            .onEnded { result in
                switch result {
                case .first(let value): finishDrag(value)
                case .second: toggleGrabber()
                }
            }
    }

    private func finishDrag(_ value: DragGesture.Value) {
        defer {
            dragAxis = nil
            drag = 0
        }
        let activeAxis: DrawerDragAxis = isLandscape ? .horizontal : .vertical
        guard dragAxis == activeAxis else { return }
        let actualTranslation = isLandscape ? -value.translation.width : value.translation.height
        let predictedTranslation = isLandscape ? -value.predictedEndTranslation.width : value.predictedEndTranslation.height
        let extents = Dictionary(uniqueKeysWithValues: DrawerDetent.allCases.map { ($0, extent(for: $0)) })
        let target = DrawerDetentResolver.target(
            from: detent,
            actualTranslation: actualTranslation,
            predictedTranslation: predictedTranslation,
            extents: extents
        )
        if target != .full { editing = false }
        move(to: target)
    }

    private func toggleGrabber() {
        move(to: detent == .half ? .full : .half)
    }

    // MARK: Kopf

    private var planned: [Place] { store.franked.filter { $0.category != "Unterkunft" } }

    private var header: some View {
        VStack(spacing: Stitch.Space.s) {
            grabber
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                    HStack(alignment: .top, spacing: Stitch.Space.s) {
                        headerIdentity
                        Spacer(minLength: 0)
                        closeHeaderButton
                    }
                    if hasHeaderActions { accessibleHeaderActions }
                }
                .padding(.horizontal, Stitch.Space.page)
            } else {
                HStack(alignment: .center, spacing: Stitch.Space.s) {
                    headerIdentity
                    Spacer(minLength: 0)
                    if hasHeaderActions { headerActionsMenu }
                    closeHeaderButton
                }
                .padding(.horizontal, Stitch.Space.page)
            }
        }
        .padding(.bottom, Stitch.Space.s)
    }

    /// Landscape + Large Type bekommt einen kompakten festen Werkzeugkopf. Titel,
    /// Untertitel und Filter liegen darunter in derselben vertikalen Liste wie die
    /// Ortszeilen, damit die Liste nicht auf die Resthöhe des alten Headers schrumpft.
    private var compactLandscapeHeader: some View {
        VStack(spacing: 0) {
            grabber
            HStack(spacing: Stitch.Space.s) {
                Spacer(minLength: 0)
                if editing {
                    Button { editing = false } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fertig")
                } else {
                    Menu {
                        planDaysButton
                        organizeButton
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Listenaktionen")
                }
                closeHeaderButton
            }
            .padding(.horizontal, Stitch.Space.page)
        }
        .frame(minHeight: Stitch.Size.touch)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { headerSize = $0 }
    }

    private var headerIdentity: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
            Text(title)
                .font(Stitch.Face.title(24, relativeTo: .title3))
                .foregroundStyle(Stitch.ink)
                .fixedSize(horizontal: false, vertical: true)
                .matchedGeometryEffect(id: "places-drawer-title", in: namespace, isSource: detent != .hidden)
            Text(subtitle).font(.footnote).foregroundStyle(DrawerAccessibilityColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var hasHeaderActions: Bool { !planned.isEmpty && (!isLandscape || detent != .collapsed) }

    /// Planung und Sortierung bleiben erreichbar, nehmen im ruhigen Referenzkopf
    /// aber keinen eigenen Textstreifen ein. Die Kategorieauswahl bleibt in
    /// demselben nativen Menü wie die übrigen Listenaktionen.
    private var headerActionsMenu: some View {
        Menu {
            if !editing { planDaysButton }
            organizeButton
            Divider()
            Picker("Kategorie", selection: $filter) {
                ForEach(MapFilter.allCases) { item in
                    Label(item.title, systemImage: item.symbol ?? "square.grid.2x2").tag(item)
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 19, weight: .semibold))
                .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The menu owns the planning action, so VoiceOver and existing UI flows
        // can still discover it by its established name.
        .accessibilityLabel("Listenaktionen")
        .accessibilityHint("Öffnet Tage planen, Ordnen und Filter")
    }

    private var planDaysButton: some View {
        Button("Tage planen") { proposing = true }
            .buttonStyle(TextActionButton())
            .accessibilityHint("Schlägt für jeden Tag eine Runde vor")
    }

    private var organizeButton: some View {
        Button(editing ? "Fertig" : "Ordnen") { editing.toggle() }
            .buttonStyle(TextActionButton(tint: Stitch.ink))
            .accessibilityHint(editing ? "" : "Tage und Reihenfolge von Hand ändern")
    }

    private var closeHeaderButton: some View {
        Button {
            editing = false
            move(to: .hidden)
        } label: {
            Image(systemName: "xmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Stitch.inkSoft)
                .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Liste schließen")
    }

    private var accessibleHeaderActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Stitch.Space.l) {
                if !editing { planDaysButton }
                organizeButton
            }
            VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                if !editing { planDaysButton }
                organizeButton
            }
        }
    }

    private var title: String {
        if planned.isEmpty { return "Noch keine Orte" }
        let count = visiblePlaces.count
        return count == 1 ? "1 Ort" : "\(count) Orte"
    }

    private var subtitle: String {
        if planned.isEmpty { return "Hier erscheinen Orte, denen ihr zustimmt." }
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

    /// Griff: Ziehen oder Tippen ändert die Höhe.
    private var grabber: some View {
        Capsule().fill(Stitch.inkSoft.opacity(0.4)).frame(width: 40, height: 5)
            .frame(maxWidth: .infinity, minHeight: Stitch.Size.touch)
            .contentShape(Rectangle())
            .gesture(grabberGesture)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
        .accessibilityLabel(detent == .full ? "Liste einklappen" : "Liste ausklappen")
        .accessibilityHint("Ziehen ändert die Höhe der Ortsliste")
        .accessibilityAction { toggleGrabber() }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(to: detent == .collapsed ? .half : .full)
            case .decrement:
                switch detent {
                case .full: move(to: .half)
                case .half: move(to: .collapsed)
                case .collapsed: move(to: .hidden)
                case .hidden: break
                }
            @unknown default: break
            }
        }
    }

    // MARK: Liste

    private struct Section: Identifiable {
        /// Immer mit „section-“ davor: Orte und Abschnitte teilen sich die Kennungen der Liste.
        let id: String
        let title: String
        var isToday = false
        let stops: [PlanStop]
    }

    private enum ListItem: Identifiable {
        case section(Section, topSpacing: CGFloat)
        case empty(String)
        case place(PlanStop)

        var id: String {
            switch self {
            case .section(let section, _): section.id
            case .empty(let sectionID): "empty-\(sectionID)"
            case .place(let stop): stop.id
            }
        }
    }

    private var visiblePlaces: [Place] { store.franked.filter { filter.matches($0.category) && $0.matchesMapSearch(searchQuery) } }

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
                .filter { filter.matches($0.place.category) && $0.place.matchesMapSearch(searchQuery) }
            // Mit Filter nur Tage mit Treffern; ohne Filter alle Reisetage, damit freie Tage sichtbar sind.
            guard !stops.isEmpty || (filter == .all && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) else { continue }
            result.append(Section(id: "section-day-\(day)", title: TripDates.dayTitle(day), isToday: day == today, stops: stops))
        }
        let open = visiblePlaces.filter { $0.day == nil && $0.category != "Unterkunft" }
        if !open.isEmpty {
            result.append(Section(id: "section-open", title: "Noch ohne Tag", stops: open.map { PlanStop(place: $0, slot: "", note: nil) }))
        }
        return result
    }

    private var listItems: [ListItem] {
        sections.enumerated().flatMap { index, section in
            var items: [ListItem] = [.section(section, topSpacing: index == 0 ? 0 : Stitch.Space.xl)]
            if section.stops.isEmpty {
                items.append(.empty(section.id))
            } else {
                items.append(contentsOf: section.stops.map(ListItem.place))
            }
            return items
        }
    }

    private var list: some View {
        drawerList(includesHeader: false)
    }

    private var compactLandscapeList: some View {
        drawerList(includesHeader: true)
    }

    private func drawerList(includesHeader: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Rhythmus wie überall: Überschrift → Inhalt 12, Karte → Karte 12, Abschnitt → Abschnitt 32.
                LazyVStack(alignment: .leading, spacing: 0) {
                    if includesHeader {
                        headerIdentity
                            .padding(.bottom, Stitch.Space.s)
                    }
                    ForEach(listItems) { item in
                        switch item {
                        case .section(let section, let topSpacing):
                            sectionHeader(section)
                                .padding(.top, topSpacing)
                        case .empty:
                            Text("Noch frei").font(.subheadline).foregroundStyle(DrawerAccessibilityColors.secondary)
                                .padding(.top, Stitch.Space.s)
                        case .place(let stop):
                            PlaceRow(stop: stop, root: store.root, selected: selectedID == stop.id,
                                     onShow: { onShow(stop.place) }, onDetails: { onDetails(stop.place) })
                                .padding(.top, Stitch.Space.s)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, Stitch.Space.page)
                .padding(.top, Stitch.Space.s)
                .padding(.bottom, Stitch.Space.xl)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("map-places-list")
            .onChange(of: selectionRequest) { _, _ in
                updateListPosition(using: proxy)
            }
            .onChange(of: detent) { _, _ in
                updateListPosition(using: proxy)
            }
            .onAppear {
                updateListPosition(using: proxy)
            }
        }
    }

    private var listIsVisible: Bool {
        isLandscape || detent == .half || detent == .full
    }

    @discardableResult
    private func revealPendingSelection(using proxy: ScrollViewProxy) -> Bool {
        guard listIsVisible,
              selectionRequest != handledSelectionRequest,
              let selectedID,
              sections.contains(where: { section in section.stops.contains { $0.id == selectedID } }) else { return false }

        let request = selectionRequest
        let expectedID = selectedID
        let expectedFilter = filter.rawValue
        guard pendingSelectionRequest != request else { return true }
        pendingSelectionRequest = request
        DispatchQueue.main.async {
            guard self.pendingSelectionRequest == request else { return }
            guard request == selectionRequest,
                  self.selectedID == expectedID,
                  self.filter.rawValue == expectedFilter,
                  self.listIsVisible,
                  self.sections.contains(where: { section in section.stops.contains { $0.id == expectedID } }) else {
                self.pendingSelectionRequest = nil
                return
            }
            self.pendingSelectionRequest = nil
            self.handledSelectionRequest = request
            self.initialScrollApplied = true
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                proxy.scrollTo(expectedID, anchor: .top)
            }
        }
        return true
    }

    private func updateListPosition(using proxy: ScrollViewProxy) {
        guard listIsVisible else { return }
        if revealPendingSelection(using: proxy) { return }
        guard !initialScrollApplied,
              selectionRequest == 0,
              selectedID == nil,
              let today = TripDates.tripDay() else { return }
        let targetID = "section-day-\(today)"
        let expectedFilter = filter.rawValue
        guard sections.contains(where: { $0.id == targetID }) else { return }
        guard pendingInitialScrollTarget != targetID else { return }
        pendingInitialScrollTarget = targetID
        DispatchQueue.main.async {
            guard self.pendingInitialScrollTarget == targetID else { return }
            guard !self.initialScrollApplied,
                  self.selectionRequest == 0,
                  self.selectedID == nil,
                  self.filter.rawValue == expectedFilter,
                  self.listIsVisible,
                  self.sections.contains(where: { $0.id == targetID }) else {
                self.pendingInitialScrollTarget = nil
                return
            }
            self.pendingInitialScrollTarget = nil
            self.initialScrollApplied = true
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                proxy.scrollTo(targetID, anchor: .top)
            }
        }
    }

    private func sectionHeader(_ section: Section) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Stitch.Space.xs) {
            if section.isToday { Text("Heute").font(.subheadline.weight(.semibold)).foregroundStyle(DrawerAccessibilityColors.accent) }
            Text(section.title).font(.headline).foregroundStyle(Stitch.ink)
            Spacer(minLength: 0)
            if !section.stops.isEmpty {
                Text(section.stops.count == 1 ? "1 Ort" : "\(section.stops.count) Orte")
                    .font(.footnote).foregroundStyle(DrawerAccessibilityColors.secondary)
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
                    if places.isEmpty { Text("Noch frei").foregroundStyle(DrawerAccessibilityColors.secondary) }
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

/// Ein Ort als Zeile: kleine Marke, Name in Serif, Art und Tageszeit; darunter Route und Tag.
/// Tippen zeigt ihn auf der Karte, der Pfeil öffnet das Detail.
private struct PlaceRow: View {
    let stop: PlanStop
    let root: URL
    let selected: Bool
    var onShow: () -> Void
    var onDetails: () -> Void
    private var place: Place { stop.place }

    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            HStack(spacing: Stitch.Space.s) {
                Button(action: onShow) {
                    HStack(spacing: Stitch.Space.s) {
                        AlbumPhoto(asset: place.image, root: root, thumbnailWidth: 160)
                            .frame(width: 64, height: 66)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: Stitch.Space.xs) {
                                Text(place.title).font(.system(.headline, design: .serif)).foregroundStyle(Stitch.ink)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                if place.visited {
                                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Stitch.teal).accessibilityLabel("Besucht")
                                }
                            }
                            Text(meta).font(.footnote).foregroundStyle(stop.note == nil ? DrawerAccessibilityColors.secondary : DrawerAccessibilityColors.accent)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        // At accessibility sizes the action tiles still need their
                        // 44pt targets, so give the title/meta column the first claim
                        // on the remaining width and let it grow vertically.
                        .layoutPriority(1)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(place.coordinate == nil ? "Keine Kartenposition verfügbar; öffnet die Ortsdetails" : "Zeigt den Ort auf der Karte")
                .accessibilityIdentifier("place-row-\(place.id)")
                Button(action: onDetails) {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold)).foregroundStyle(DrawerAccessibilityColors.secondary)
                        .frame(minWidth: Stitch.Size.touch, minHeight: Stitch.Size.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Details zu \(place.title)")
                .accessibilityIdentifier("place-details-\(place.id)")
                if place.category != "Unterkunft" {
                    DayMenu(place: place, compact: true)
                }
            }
        }
        .padding(Stitch.Space.s)
        .background(selected ? Stitch.selection : Stitch.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous)
                .strokeBorder(Color.clear, lineWidth: 0)
                .allowsHitTesting(false)
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
}

/// Tag eines Ortes wählen; der Ort kommt ans Ende des Tages.
struct DayMenu: View {
    @Environment(AlbumStore.self) private var store
    let place: Place
    var compact = false
    var body: some View {
        Menu {
            Picker("Tag", selection: Binding(get: { place.day }, set: { store.assign(place, to: $0) })) {
                Text("Noch ohne Tag").tag(nil as Int?)
                ForEach(DayPlanGenerator.days, id: \.self) { Text(TripDates.dayTitle($0)).tag(Optional($0)) }
            }
        } label: {
            Group {
                if compact {
                    Image(systemName: "calendar")
                } else {
                    Label(place.day.map { "\($0). Okt" } ?? "Tag festlegen", systemImage: "calendar")
                }
            }
            .font(.subheadline.weight(.semibold)).foregroundStyle(DrawerAccessibilityColors.accent)
            .frame(minWidth: Stitch.Size.touch, minHeight: Stitch.Size.touch)
        }
        .accessibilityLabel(place.day.map { "Tag ändern, jetzt \(TripDates.dayTitle($0))" } ?? "Tag festlegen")
    }
}

/// Fußweg in Apple Karten.
func openWalkingRoute(to place: Place) {
    guard let coordinate = place.coordinate else { return }
    let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    item.name = place.title
    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
}
