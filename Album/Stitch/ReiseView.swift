import SwiftUI

/// Startseite der Reise: Prag, die sechs Tage als Streifen, der Plan des gewählten Tages und die Tickets.
/// Vor der Reise steht der erste Tag offen, unterwegs „heute“ und danach der Erinnerungs-Einstieg.
struct ReiseView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var openIdeas: () -> Void
    var openMap: () -> Void
    var openDocuments: () -> Void
    var openSharing: () -> Void
    var openAdd: () -> Void
    @State private var day: Int = TripDates.phase() == .after
        ? (DayPlanGenerator.days.last ?? 9)
        : (TripDates.tripDay() ?? DayPlanGenerator.days.first ?? 4)
    @State private var selected: Place?
    @State private var memoriesOpen = false
    @State private var refreshed = 0
    /// Solange das Herunterziehen abgleicht, wartet die Abgleich-Insel.
    @State private var refreshing = false
    /// Das Ortsdetail wächst aus der Marke, die angetippt wurde.
    @Namespace private var placeZoom

    private var today: Int? { TripDates.tripDay() }

    var body: some View {
        GeometryReader { proxy in
            page.overlay(alignment: .top) { statusBarPaper(proxy) }
        }
    }

    /// Papier unter der Statusleiste: Beim Scrollen liegen Uhrzeit und Fotos nicht übereinander.
    /// Deckt den Bildschirm von oben bis zur sicheren Fläche, egal wo der Rahmen dieser Ansicht beginnt.
    private func statusBarPaper(_ proxy: GeometryProxy) -> some View {
        let top = max(proxy.frame(in: .global).minY, 0)
        return VStack(spacing: 0) {
            Stitch.paper.frame(height: top + proxy.safeAreaInsets.top)
            LinearGradient(colors: [Stitch.paper, Stitch.paper.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: Stitch.Space.xs)
        }
        .offset(y: -top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Stitch.Space.m) {
                header
                // Nach der Reise ist das Album das Wichtigste: gleich unter dem Titelfoto.
                if TripDates.phase() == .after { memoriesEntry }
                participants
                itinerary
                dayPlan
                tickets
                if !store.inbox.isEmpty { ideasWaiting }
            }
            .padding(.horizontal, Stitch.Space.page)
            .padding(.top, Stitch.Space.xs)
            // Unten Platz für den KI-Kreis, damit er nie den letzten Route-Knopf verdeckt.
            .padding(.bottom, Stitch.Space.xxl + Stitch.Size.touch)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            refreshing = true
            await store.sync()
            refreshed += 1
            refreshing = false
        }
        .sensoryFeedback(.impact(weight: .light), trigger: refreshed)
        .toolbar { islandItem }
        #if DEBUG
        .task { await demoSync() }
        #endif
        .background(PaperBackground())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { PlaceDetail(placeID: $0.id).zoomDestination(id: $0.id, in: placeZoom, enabled: !reduceMotion) }
        .sheet(isPresented: $memoriesOpen) {
            TripMemoriesView(openMap: {
                memoriesOpen = false
                openMap()
            })
            .environment(store)
        }
    }

    // MARK: Kopf

    private var header: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            HStack(spacing: Stitch.Space.s) {
                Text("Album")
                    .font(Stitch.Face.display(28, relativeTo: .title2))
                    .foregroundStyle(Stitch.ink)
                    .accessibilityAddTraits(.isHeader)
                if store.syncOffline {
                    OfflinePill()
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.8, anchor: .leading).combined(with: .opacity))
                }
                Spacer(minLength: Stitch.Space.s)
                Button(action: openSharing) {
                    Image(systemName: "person.2.fill")
                }
                .buttonStyle(HeaderIconButton())
                .accessibilityLabel("Teilnehmende verwalten")
                Button(action: openAdd) {
                    Image(systemName: "plus")
                }
                .buttonStyle(HeaderIconButton())
                .accessibilityLabel("Neue Idee")
            }
            .animation(reduceMotion ? Stitch.Motion.reducedFade : Stitch.Motion.panel, value: store.syncOffline)

            ZStack(alignment: .bottomLeading) {
                AlbumPhoto(asset: .bundled(name: "imgPragueCover"))
                    .accessibilityHidden(true)
                if !dynamicTypeSize.isAccessibilitySize {
                    LinearGradient(
                        colors: [.clear, Stitch.scrim.opacity(0.78)],
                        startPoint: .center, endPoint: .bottom
                    )
                    .accessibilityHidden(true)
                    heroTitle.foregroundStyle(Stitch.onAccent)
                        .padding(Stitch.Space.l)
                }
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topTrailing) {
                // Unterwegs: der Stempel des heutigen Tages, unter dem Menüknopf.
                if let today, !dynamicTypeSize.isAccessibilitySize {
                    DayPostmark(day: today)
                        .padding(.top, Stitch.Size.touch + Stitch.Space.l)
                        .padding(.trailing, Stitch.Space.l)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) { heroMenu.padding(Stitch.Space.s) }

            if dynamicTypeSize.isAccessibilitySize {
                heroTitle
                    .foregroundStyle(Stitch.ink)
                    .padding(.top, Stitch.Space.s)
            }
        }
    }

    private var heroTitle: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
            Text("Prag")
                .font(Stitch.Face.display(40, relativeTo: .largeTitle))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroMenu: some View {
        Menu {
            Button("Reiseunterlagen", systemImage: "doc.text", action: openDocuments)
            Button("Karte", systemImage: "map", action: openMap)
            Button("Teilen", systemImage: "square.and.arrow.up", action: openSharing)
            Link(destination: URL(string: "https://commons.wikimedia.org/wiki/File:Charles_Bridge_at_sunset.jpg")!) {
                Label("Foto: Thomas Fabian · CC BY-SA 2.0", systemImage: "photo")
            }
            Link(destination: URL(string: "https://creativecommons.org/licenses/by-sa/2.0/")!) {
                Label("Lizenz und Bildnachweis", systemImage: "info.circle")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .buttonStyle(HeaderIconButton())
        .accessibilityLabel("Reiseoptionen")
    }

    private var participants: some View {
        HStack(spacing: Stitch.Space.s) {
            HStack(spacing: -8) {
                ForEach(participantNames, id: \.self) { name in
                    Text(initials(for: name))
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 3)
                        .foregroundStyle(Stitch.ink)
                        .frame(width: 34, height: 34)
                        .background(Stitch.Mat.sky, in: Circle())
                        .overlay(Circle().stroke(Stitch.card, lineWidth: 2))
                        .accessibilityLabel(name)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(participantNames.joined(separator: ", "))

            Spacer(minLength: Stitch.Space.xs)

            Button(action: openSharing) {
                Label("Einladen", systemImage: "person.2")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Stitch.ink)
                    .padding(.horizontal, Stitch.Space.m)
                    .frame(minHeight: Stitch.Size.touch)
                    .background(Stitch.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(Stitch.rule, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Einladen")
        }
        .frame(minHeight: Stitch.Size.touch)
    }

    private var participantNames: [String] {
        var names = [store.me]
        if let partner, !names.contains(partner) { names.append(partner) }
        return names
    }

    private func initials(for name: String) -> String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" })
        if let first = words.first, let last = words.dropFirst().last, first != last {
            return (String(first.prefix(1)) + String(last.prefix(1))).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var itinerary: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reiseplan")
                    .font(Stitch.Face.title(20, relativeTo: .title2))
                    .foregroundStyle(Stitch.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Stitch.Space.s)
                Button(action: openMap) {
                    Label("Alle öffnen", systemImage: "calendar")
                }
                .buttonStyle(TextActionButton(tint: Stitch.ink))
                .accessibilityLabel("Alle Reisetage öffnen")
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: Stitch.Space.s) {
                        ForEach(DayPlanGenerator.days, id: \.self) { itineraryDay($0).id($0) }
                    }
                    .padding(.vertical, Stitch.Space.xxs)
                }
                .scrollIndicators(.hidden)
                // Der gewählte Tag steht immer mittig, auch am 8. Oktober beim Öffnen.
                .onAppear { proxy.scrollTo(day, anchor: .center) }
                .onChange(of: day) { _, newDay in
                    withAnimation(reduceMotion ? nil : Stitch.Motion.panel) { proxy.scrollTo(newDay, anchor: .center) }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: day)
        .padding(Stitch.Space.m)
        .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous).strokeBorder(Stitch.rule, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reisetage")
    }

    @ScaledMetric(relativeTo: .body) private var itineraryTileWidth: CGFloat = 90

    private func itineraryDay(_ day: Int) -> some View {
        let places = store.plan(for: day)
        let title = places.first?.title ?? "Noch frei"
        let selectedDay = day == self.day
        let width = max(90, itineraryTileWidth)
        return Button {
            self.day = day
        } label: {
            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                Text("\(day). OKT")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Stitch.inkSoft)
                    .lineLimit(1)
                Group {
                    if let asset = coverPhoto(for: day) {
                        AlbumPhoto(asset: asset, root: store.root, thumbnailWidth: 250)
                    } else {
                        // Ein freier Platz für eine Marke statt eines leeren Kastens.
                        RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous)
                            .strokeBorder(Stitch.rule, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .background(Stitch.paper, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.title3.weight(.medium))
                                    .foregroundStyle(Stitch.inkSoft)
                            }
                    }
                }
                .frame(width: 84, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Stitch.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, max(3, (width - 84) / 2))
            .padding(.vertical, Stitch.Space.xs)
            .background(selectedDay ? Stitch.selection : Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous)
                    .strokeBorder(selectedDay ? Stitch.Mat.sky : Stitch.rule, lineWidth: selectedDay ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(TripDates.dayTitle(day)), \(title)")
        .accessibilityAddTraits(selectedDay ? .isSelected : [])
    }

    /// „4.–9. Oktober · noch 3 Tage · mit Mia“ – nur was stimmt.
    private var subtitle: String {
        var parts = ["4.–9. Oktober"]
        switch TripDates.phase() {
        case .before:
            let days = TripDates.daysUntilStart()
            if days > 1 { parts.append("noch \(days) Tage") }
            else if days == 1 { parts.append("morgen geht’s los") }
        case .during:
            if let today { parts.append("Tag \(today - 3) von 6") }
        case .after:
            parts.append("6 Tage in Prag")
        }
        if let partner { parts.append("mit \(partner)") }
        return parts.joined(separator: " · ")
    }

    private var memoriesEntry: some View {
        let visited = store.franked.filter(\.visited)
        let ownPhotos = visited.filter { place in
            if case .uploaded = place.image { return true }
            return false
        }.count
        return Button { memoriesOpen = true } label: {
            HStack(spacing: Stitch.Space.m) {
                Image(systemName: "photo.stack")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Stitch.ink)
                    .frame(width: 48, height: 48)
                    .background(Stitch.paperDeep, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text("Erinnerungen ansehen")
                        .font(.headline).foregroundStyle(Stitch.ink)
                    Text(memorySummary(places: visited.count, photos: ownPhotos))
                        .font(.subheadline).foregroundStyle(Stitch.inkSoft)
                }
                Spacer(minLength: Stitch.Space.xs)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
            }
            .frame(minHeight: Stitch.Size.touch)
            .stitchCard(.pinned)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Erinnerungen ansehen")
        .accessibilityValue(memorySummary(places: visited.count, photos: ownPhotos))
        .accessibilityHint("Blättert durch besuchte Orte und Fotos")
    }

    private func memorySummary(places: Int, photos: Int) -> String {
        if places == 0 { return "Eure besuchten Orte und Fotos" }
        let placeCount = places == 1 ? "1 Ort erlebt" : "\(places) Orte erlebt"
        let photoCount = photos == 1 ? "1 eigenes Foto" : "\(photos) eigene Fotos"
        return "\(placeCount) · \(photoCount)"
    }

    /// Die andere Person, sobald sie im Album vorkommt.
    private var partner: String? {
        let names = store.places.flatMap { [$0.author] + $0.approvals }
        return names.first { $0 != store.me && !$0.isEmpty && $0.localizedCaseInsensitiveCompare("Wir") != .orderedSame }
    }

    private func coverPhoto(for day: Int) -> PlaceImageAsset? {
        store.plan(for: day).first { $0.image != nil }?.image
    }

    // MARK: Tag

    private var stops: [PlanStop] {
        let windows = DayPlanGenerator.windows(flights: store.data.trip.flights ?? [])
        return DayPlanGenerator.timeline(store.plan(for: day), day: day, window: windows[day]!, hotel: store.hotelCoordinate)
    }

    private var flightsToday: [FlightLeg] {
        (store.data.trip.flights ?? []).filter { $0.date.hasPrefix(String(format: "%02d.10.", day)) }
    }

    /// Während der Reise: der erste noch nicht besuchte Ort von heute.
    private var next: PlanStop? {
        guard day == today else { return nil }
        return stops.first { !$0.place.visited }
    }

    private var dayPlan: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            SectionTitle(title: day == today ? "Heute" : TripDates.dayTitle(day)) {
                if !stops.isEmpty {
                    Text(stops.count == 1 ? "1 Ort" : "\(stops.count) Orte").font(.footnote).foregroundStyle(Stitch.inkSoft)
                        .contentTransition(.numericText(value: Double(stops.count)))
                }
            }
            if day == today {
                Text(TripDates.dayTitle(day)).font(.subheadline).foregroundStyle(Stitch.inkSoft).padding(.top, -Stitch.Space.xs)
            }
            ForEach(flightsToday) { FlightTicket(leg: $0, legs: store.data.trip.flights ?? [], openDocuments: openDocuments) }
            if dayComplete {
                DayComplete(day: day, count: stops.count) { memoriesOpen = true }
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.94, anchor: .top).combined(with: .opacity))
            }
            if let next {
                NextStop(stop: next, root: store.root, zoom: placeZoom) { selected = next.place }
            }
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                if stop.id != next?.id {
                    StopRow(number: index + 1, stop: stop, root: store.root, zoom: placeZoom) { selected = stop.place }
                }
            }
            if stops.isEmpty { emptyDay }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86), value: day)
        // Wird ein Ort besucht, rückt der nächste weich nach oben; der Abschluss wächst ein.
        .animation(reduceMotion ? Stitch.Motion.reducedFade : Stitch.Motion.panel, value: next?.id)
        .animation(reduceMotion ? Stitch.Motion.reducedFade : Stitch.Motion.panel, value: dayComplete)
    }

    /// Heute ist jeder geplante Ort besucht.
    private var dayComplete: Bool {
        day == today && !stops.isEmpty && stops.allSatisfy { $0.place.visited }
    }

    /// Ein freier Tag ist eine Einladung, kein Fehler: der direkte Weg zu den Ideen oder zur Karte.
    private var emptyDay: some View {
        let waiting = store.inbox.count
        let actions = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Stitch.Space.s))
            : AnyLayout(HStackLayout(spacing: Stitch.Space.s))
        return VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Text("Noch frei")
                .font(Stitch.Face.place(26, relativeTo: .title2))
                .foregroundStyle(Stitch.ink)
            Text(waiting == 0
                 ? "Legt Orte von der Karte auf diesen Tag."
                 : waiting == 1 ? "1 Idee wartet noch auf eure Entscheidung." : "\(waiting) Ideen warten noch auf eure Entscheidung.")
                .font(.subheadline)
                .foregroundStyle(Stitch.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            actions {
                if waiting > 0 {
                    Button("Ideen ansehen", action: openIdeas).buttonStyle(StitchButton(primary: true))
                }
                Button("Tage planen", action: openMap).buttonStyle(StitchButton(primary: waiting == 0))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stitchCard()
    }

    // MARK: Unterlagen

    private var tickets: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            SectionTitle(title: "Unterlagen") {
                Button("Alle", action: openDocuments).buttonStyle(TextActionButton())
                    .accessibilityLabel("Alle Reiseunterlagen")
            }
            let legs = store.data.trip.flights ?? []
            if legs.isEmpty {
                Button(action: openDocuments) {
                    TicketRow(symbol: "airplane", title: "Flüge hinzufügen", detail: "Das Album liest PDFs automatisch.", stub: nil)
                }
                .buttonStyle(.plain)
            } else {
                // Am Reisetag steht der Flug oben im Tagesplan; hier bleiben die übrigen.
                ForEach(legs.filter { !flightsToday.contains($0) }) {
                    FlightTicket(leg: $0, legs: legs, openDocuments: openDocuments)
                }
            }
            Button(action: openDocuments) {
                let hotel = store.data.trip.hotelDetails
                TicketRow(symbol: "bed.double", title: hotel?.name ?? store.data.trip.hotel,
                          detail: [hotel?.checkIn.map { "Check-in ab \($0)" }, hotel?.checkOut.map { "Check-out bis \($0)" }]
                            .compactMap { $0 }.joined(separator: " · ").nilIfEmpty ?? "Unterkunft",
                          stub: store.data.trip.bookingNumber, mat: Stitch.Mat.lilac)
            }
            .buttonStyle(.plain)
        }
    }

    private var ideasWaiting: some View {
        Button(action: openIdeas) {
            HStack(spacing: Stitch.Space.s) {
                Image(systemName: "tray.full").font(.title3).foregroundStyle(Stitch.ink)
                    .frame(width: Stitch.Size.thumb, height: Stitch.Size.thumb)
                    .background(Stitch.paperDeep, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.inbox.count == 1 ? "1 Idee wartet" : "\(store.inbox.count) Ideen warten").font(.headline).foregroundStyle(Stitch.ink)
                        .contentTransition(.numericText(value: Double(store.inbox.count)))
                        .animation(reduceMotion ? nil : .snappy, value: store.inbox.count)
                    Text("Ja, Nein oder Offen").font(.subheadline).foregroundStyle(Stitch.inkSoft)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
            }
            .stitchCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: Abgleich

    /// Die Insel sitzt links in der Leiste, wo sonst nichts steht; ohne eigene Glasfläche des Systems.
    @ToolbarContentBuilder private var islandItem: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) { SyncIsland(suppressed: refreshing) }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { SyncIsland(suppressed: refreshing) }
        }
    }

    #if DEBUG
    /// `ALBUM_DEMO_SYNC=1|none`: zeigt die Abgleich-Insel mit simulierten Neuigkeiten, ohne zu schreiben oder abzugleichen.
    private func demoSync() async {
        guard let mode = ProcessInfo.processInfo.environment["ALBUM_DEMO_SYNC"] else { return }
        try? await Task.sleep(for: .seconds(2))
        store.syncing = true
        try? await Task.sleep(for: .seconds(2))
        if mode != "none" {
            var before = store.places
            if !before.contains(where: \.franked) {
                before.append(Place(id: "demo-shared", title: "Karlsbrücke", author: store.me,
                                    franked: true, approvals: [store.me]))
            }
            var after = before
            after.append(Place(title: "Café Savoy", author: "Mia"))
            after.append(Place(title: "Strahov", author: "Mia"))
            if let index = after.firstIndex(where: { $0.franked }) { after[index].approvals.append("Mia") }
            store.syncChange = SyncChange.between(before: before, after: after, me: store.me)
        }
        store.syncing = false
    }
    #endif
}

// MARK: Orte im Tagesplan

/// Der nächste Ort während der Reise: groß, als Marke, mit Route im Daumenbereich.
private struct NextStop: View {
    let stop: PlanStop
    let root: URL
    let zoom: Namespace.ID
    var open: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.m) {
            Button(action: open) {
                HStack(alignment: .top, spacing: Stitch.Space.m) {
                    StampFrame(mat: stop.place.mat) {
                        AlbumPhoto(asset: stop.place.image, root: root, thumbnailWidth: 400, placeholderSymbol: stop.place.symbol, placeholderTint: stop.place.mat).frame(width: 96, height: 112)
                    }
                    .zoomSource(id: stop.place.id, in: zoom)
                    VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                        Text("Als Nächstes").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.ink)
                        Text(stop.place.title).font(Stitch.Face.place(28, relativeTo: .title)).foregroundStyle(Stitch.ink)
                            .lineLimit(3).multilineTextAlignment(.leading)
                        Text([stop.place.category, stop.slot].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(Stitch.inkSoft)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            if stop.place.coordinate != nil {
                Button { openWalkingRoute(to: stop.place) } label: { Label("Route", systemImage: "figure.walk") }
                    .buttonStyle(StitchButton(primary: true))
                    .accessibilityLabel("Route zu \(stop.place.title)")
            }
        }
        .stitchCard(.pinned)
    }
}

/// Ein Ort im Tagesplan: Nummer, kleine Marke, Name in Serif, Art und Tageszeit; rechts Route.
private struct StopRow: View {
    let number: Int
    let stop: PlanStop
    let root: URL
    let zoom: Namespace.ID
    var open: () -> Void
    private var place: Place { stop.place }
    var body: some View {
        HStack(spacing: Stitch.Space.s) {
            Button(action: open) {
                HStack(spacing: Stitch.Space.s) {
                    StampFrame(mat: place.mat, inset: 4, matWidth: 2, elevation: .flat) {
                        AlbumPhoto(asset: place.image, root: root, thumbnailWidth: 160, placeholderSymbol: place.symbol, placeholderTint: place.mat).frame(width: 44, height: 52)
                    }
                    .zoomSource(id: place.id, in: zoom)
                    VStack(alignment: .leading, spacing: 2) {
                    Text(place.title).font(Stitch.Face.place(21, relativeTo: .headline)).foregroundStyle(place.visited ? Stitch.inkSoft : Stitch.ink)
                            .strikethrough(place.visited, color: Stitch.inkSoft)
                            .lineLimit(2).multilineTextAlignment(.leading)
                        Text(meta).font(.footnote).foregroundStyle(stop.note == nil ? Stitch.inkSoft : Stitch.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(number). \(place.title), \(meta)\(place.visited ? ", besucht" : "")")
            if place.coordinate != nil && !place.visited {
                Button { openWalkingRoute(to: place) } label: { Image(systemName: "figure.walk") }
                    .buttonStyle(HeaderIconButton())
                    .accessibilityLabel("Route zu \(place.title)")
            }
        }
        .padding(.vertical, Stitch.Space.xxs)
    }

    private var meta: String {
        [place.category, stop.slot, stop.note ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

// MARK: Kleine Momente

/// Leise Kapsel neben dem Titel, solange der Abgleich nicht durchkommt. Tippen versucht es erneut.
private struct OfflinePill: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var attempts = 0
    var body: some View {
        Button {
            attempts += 1
            Task { await store.sync() }
        } label: {
            HStack(spacing: Stitch.Space.xxs) {
                Image(systemName: "wifi.slash")
                    .symbolEffect(.pulse, isActive: store.syncing && !reduceMotion)
                Text(store.syncing ? "Verbinde …" : "Offline")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Stitch.inkSoft)
            .padding(.horizontal, Stitch.Space.s)
            .frame(minHeight: 30)
            .background(Stitch.paperDeep, in: Capsule())
            .frame(minHeight: Stitch.Size.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.syncing)
        .sensoryFeedback(.selection, trigger: attempts)
        .accessibilityLabel("Offline. Alles ist auf diesem iPhone gespeichert.")
        .accessibilityHint("Tippen, um erneut abzugleichen")
    }
}

/// Unterwegs: Beim ersten Öffnen eines Reisetags drückt ein Poststempel mit dem Datum auf das Titelfoto.
/// Danach liegt er still dort, bis der nächste Tag beginnt.
private struct DayPostmark: View {
    static let storageKey = "album.postmarkedDay"
    let day: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed: Bool
    @State private var thump = 0

    init(day: Int) {
        self.day = day
        _landed = State(initialValue: UserDefaults.standard.integer(forKey: Self.storageKey) == day)
    }

    var body: some View {
        Postmark(bottom: String(format: "%d.10.26", day), color: .white, size: 74)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .scaleEffect(landed ? 1 : 1.7)
            .blur(radius: landed ? 0 : 5)
            .opacity(landed ? 0.94 : 0)
            .sensoryFeedback(.impact(weight: .heavy, intensity: 0.85), trigger: thump)
            .task(id: day) {
                guard UserDefaults.standard.integer(forKey: Self.storageKey) != day else { landed = true; return }
                landed = false
                // Erst ankommen lassen, dann stempeln.
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .spring(response: 0.26, dampingFraction: 0.58)) { landed = true }
                UserDefaults.standard.set(day, forKey: Self.storageKey)
                // Der Schlag kommt, wenn der Stempel aufsetzt.
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 110))
                thump += 1
            }
            .accessibilityHidden(true)
    }
}

/// Alle Orte des Tages besucht: ein ruhiger Abschluss mit Stempel und dem Weg zu den Erinnerungen.
private struct DayComplete: View {
    let day: Int
    let count: Int
    var openMemories: () -> Void
    var body: some View {
        HStack(spacing: Stitch.Space.m) {
            Postmark(bottom: String(format: "%d.10.26", day), color: Stitch.teal, size: 64)
            VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                Text("Heute alles erlebt")
                    .font(Stitch.Face.title(20, relativeTo: .title3))
                    .foregroundStyle(Stitch.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(count == 1 ? "1 Ort abgestempelt" : "\(count) Orte abgestempelt")
                    .font(.subheadline)
                    .foregroundStyle(Stitch.inkSoft)
                Button("Erinnerungen ansehen", action: openMemories)
                    .buttonStyle(TextActionButton(tint: Stitch.red))
            }
            Spacer(minLength: 0)
        }
        .stitchCard(.pinned)
        .accessibilityElement(children: .contain)
    }
}

// MARK: Tickets

/// Ticket mit Abschnitt rechts: Symbol, Titel, Zeile darunter; der Abschnitt trägt einen Code.
struct TicketRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let symbol: String
    let title: String
    let detail: String
    var stub: String?
    var mat: Color = Stitch.paperDeep
    @ScaledMetric(relativeTo: .footnote) private var stubWidth: CGFloat = 84
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: Stitch.Space.s) {
                Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
                    .frame(width: 36, height: 36).background(mat, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(Stitch.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail).font(.footnote).foregroundStyle(Stitch.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(Stitch.Space.s)
            if let stub {
                Text(stub).font(Stitch.Face.ticket).foregroundStyle(Stitch.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: stubWidth).frame(maxHeight: .infinity)
                    .background(Stitch.paperDeep)
            }
        }
        .frame(minHeight: 68)
        .background(Stitch.card)
        .clipShape(TicketShape(stub: stub == nil ? 0 : stubWidth, notch: stub == nil ? 0 : 8))
        .overlay(alignment: .trailing) {
            if stub != nil {
                Rectangle().fill(.clear).frame(width: 1)
                    .overlay(Line().stroke(Stitch.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    .padding(.vertical, Stitch.Space.s).offset(x: -stubWidth)
            }
        }
        .stitchElevation(.pinned)
        .accessibilityElement(children: .combine)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path { Path { $0.move(to: CGPoint(x: rect.midX, y: 0)); $0.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)) } }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
