import SwiftUI

/// Startseite der Reise: Prag, die sechs Tage als Streifen, der Plan des gewählten Tages und die Tickets.
/// Vor der Reise steht der erste Tag offen, unterwegs „heute“ und danach der Erinnerungs-Einstieg.
struct ReiseView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var openIdeas: () -> Void
    var openMap: () -> Void
    var openDocuments: () -> Void
    var openSharing: () -> Void
    @State private var day: Int = TripDates.phase() == .after
        ? (DayPlanGenerator.days.last ?? 9)
        : (TripDates.tripDay() ?? DayPlanGenerator.days.first ?? 4)
    @State private var selected: Place?
    @State private var memoriesOpen = false
    @State private var refreshed = 0
    /// Solange das Herunterziehen abgleicht, wartet die Abgleich-Insel.
    @State private var refreshing = false

    private var today: Int? { TripDates.tripDay() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                header
                if TripDates.phase() == .after { memoriesEntry }
                DayStrip(selection: $day, today: today, photo: { coverPhoto(for: $0) })
                dayPlan
                tickets
                if !store.inbox.isEmpty { ideasWaiting }
            }
            .padding(.horizontal, Stitch.Space.page)
            .padding(.top, Stitch.Space.xs)
            .padding(.bottom, Stitch.Space.xxl)
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
        .sheet(item: $selected) { PlaceDetail(placeID: $0.id) }
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
        HStack(alignment: .top, spacing: Stitch.Space.s) {
            VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                Text("Prag").font(Stitch.Face.display(48, relativeTo: .largeTitle)).foregroundStyle(Stitch.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Stitch.inkSoft)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
            Spacer(minLength: 0)
            Button(action: openSharing) {
                Image(systemName: store.isShared ? "person.2.fill" : "person.badge.plus")
            }
            .buttonStyle(HeaderIconButton())
            .padding(.top, Stitch.Space.xs)
            .accessibilityLabel(store.isShared ? "Gemeinsames Album" : "Jemanden einladen")
        }
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
                    .foregroundStyle(Stitch.red)
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
                }
            }
            if day == today {
                Text(TripDates.dayTitle(day)).font(.subheadline).foregroundStyle(Stitch.inkSoft).padding(.top, -Stitch.Space.xs)
            }
            ForEach(flightsToday) { FlightTicket(leg: $0, legs: store.data.trip.flights ?? [], openDocuments: openDocuments) }
            if let next {
                NextStop(stop: next, root: store.root) { selected = next.place }
            }
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                if stop.id != next?.id {
                    StopRow(number: index + 1, stop: stop, root: store.root) { selected = stop.place }
                }
            }
            if stops.isEmpty {
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text("Noch nichts geplant").font(.headline).foregroundStyle(Stitch.ink)
                    Button("Tage planen", action: openMap).buttonStyle(TextActionButton())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .stitchCard()
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86), value: day)
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
                Image(systemName: "tray.full").font(.title3).foregroundStyle(Stitch.red)
                    .frame(width: Stitch.Size.thumb, height: Stitch.Size.thumb)
                    .background(Stitch.paperDeep, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.inbox.count == 1 ? "1 Idee wartet" : "\(store.inbox.count) Ideen warten").font(.headline).foregroundStyle(Stitch.ink)
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

// MARK: Tagesstreifen

/// Die sechs Reisetage nebeneinander. Der gewählte Tag ist breit und zeigt sein erstes Foto,
/// die anderen sind schmale Marken mit senkrechter Beschriftung. Tippen oder seitlich wischen wählt.
private struct DayStrip: View {
    @Binding var selection: Int
    let today: Int?
    let photo: (Int) -> PlaceImageAsset?
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 150
    @ScaledMetric(relativeTo: .body) private var accessibleTileWidth: CGFloat = 184
    private let narrow: CGFloat = 38
    private let days = DayPlanGenerator.days

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.horizontal) {
                    HStack(spacing: Stitch.Space.s) {
                        ForEach(days, id: \.self) { day in accessibleTile(day) }
                    }
                    .padding(.vertical, Stitch.Space.xxs)
                }
                .scrollIndicators(.hidden)
            } else {
                GeometryReader { geo in
                    let gap: CGFloat = 6
                    let wide = max(narrow, geo.size.width - CGFloat(days.count - 1) * (narrow + gap))
                    HStack(spacing: gap) {
                        ForEach(days, id: \.self) { day in
                            tile(day, width: day == selection ? wide : narrow)
                        }
                    }
                }
                .frame(height: height)
            }
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : height)
        .animation(reduceMotion ? Stitch.Motion.reducedFade : .spring(response: 0.42, dampingFraction: 0.82), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .gesture(DragGesture(minimumDistance: 24).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) else { return }
            let step = value.translation.width < 0 ? 1 : -1
            selection = min(max(selection + step, days.first!), days.last!)
        })
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reisetage")
    }

    private func accessibleTile(_ day: Int) -> some View {
        let selectedDay = day == selection
        let count = store.plan(for: day).count
        return Button { selection = day } label: {
            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                Text(weekday(day, style: .wide))
                    .font(.headline)
                    .fixedSize(horizontal: true, vertical: false)
                Text("\(day). Oktober")
                    .font(.subheadline)
                    .fixedSize(horizontal: true, vertical: false)
                if count > 0 {
                    Text(count == 1 ? "1 Ort" : "\(count) Orte")
                        .font(.footnote)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .foregroundStyle(Stitch.ink)
            .fixedSize(horizontal: true, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .padding(Stitch.Space.m)
            .background(selectedDay ? Stitch.card : Stitch.paperDeep,
                        in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous)
                    .strokeBorder(day == today ? Stitch.red : Stitch.rule, lineWidth: day == today ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .frame(width: accessibleTileWidth)
        .accessibilityLabel("\(TripDates.dayTitle(day)), \(count == 0 ? "nichts geplant" : count == 1 ? "1 Ort" : "\(count) Orte")\(day == today ? ", heute" : "")")
        .accessibilityAddTraits(selectedDay ? .isSelected : [])
    }

    private func tile(_ day: Int, width: CGFloat) -> some View {
        let open = day == selection
        let asset = photo(day)
        let count = store.plan(for: day).count
        return Button { selection = day } label: {
            ZStack(alignment: open ? .bottomLeading : .center) {
                if open, asset != nil {
                    AlbumPhoto(asset: asset, root: store.root, thumbnailWidth: 640)
                    LinearGradient(colors: [.clear, Stitch.scrim.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                } else {
                    (open ? Stitch.card : Stitch.paperDeep)
                }
                if open {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(weekday(day, style: .wide)).font(.footnote.weight(.semibold))
                        Text("\(day). Okt").font(Stitch.Face.place(34, relativeTo: .title)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(asset != nil ? Stitch.onAccent : Stitch.ink)
                    .padding(Stitch.Space.s)
                    .transition(.opacity)
                } else {
                    VStack(spacing: Stitch.Space.xs) {
                        Text("\(day)").font(Stitch.Face.place(24, relativeTo: .title3)).foregroundStyle(Stitch.ink)
                        Text(weekday(day, style: .abbreviated).uppercased())
                            .font(.caption2.weight(.semibold)).tracking(0.6).foregroundStyle(Stitch.inkSoft)
                            .fixedSize()
                            .rotationEffect(.degrees(-90))
                            .frame(width: 16, height: 30)
                        if count > 0 {
                            Circle().fill(Stitch.red).frame(width: 5, height: 5).accessibilityHidden(true)
                        }
                    }
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous)
                    .strokeBorder(day == today ? Stitch.red : Stitch.rule, lineWidth: day == today ? 2 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(TripDates.dayTitle(day)), \(count == 0 ? "nichts geplant" : count == 1 ? "1 Ort" : "\(count) Orte")\(day == today ? ", heute" : "")")
        .accessibilityAddTraits(open ? .isSelected : [])
    }

    private func weekday(_ day: Int, style: Date.FormatStyle.Symbol.Weekday) -> String {
        let date = TripDates.calendar.date(from: DateComponents(year: 2026, month: 10, day: day))!
        return date.formatted(.dateTime.weekday(style).locale(Locale(identifier: "de_DE")))
            .replacingOccurrences(of: ".", with: "")
    }
}

// MARK: Orte im Tagesplan

/// Der nächste Ort während der Reise: groß, als Marke, mit Route im Daumenbereich.
private struct NextStop: View {
    let stop: PlanStop
    let root: URL
    var open: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.m) {
            Button(action: open) {
                HStack(alignment: .top, spacing: Stitch.Space.m) {
                    StampFrame(mat: stop.place.mat) {
                        AlbumPhoto(asset: stop.place.displayImage, root: root, thumbnailWidth: 400).frame(width: 96, height: 112)
                    }
                    VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                        Text("Als Nächstes").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.red)
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
    var open: () -> Void
    private var place: Place { stop.place }
    var body: some View {
        HStack(spacing: Stitch.Space.s) {
            Button(action: open) {
                HStack(spacing: Stitch.Space.s) {
                    StampFrame(mat: place.mat, inset: 4, matWidth: 2, elevation: .flat) {
                        AlbumPhoto(asset: place.displayImage, root: root, thumbnailWidth: 160).frame(width: 44, height: 52)
                    }
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
