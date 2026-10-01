import SwiftUI

/// Startseite der Reise: gesticktes „Prag“, das Brückenmotiv als Fortschritt und angeheftete Orte.
/// Während der Reise tritt der Planungsfortschritt zurück und „Heute“ steht oben.
struct ReiseView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var openIdeas: () -> Void
    var openDocuments: () -> Void
    @State private var shownStitches: Double = 0
    @State private var finished = 0
    @State private var selected: Place?
    @State private var bellRings = 0
    /// Solange das Herunterziehen abgleicht, gibt die Klingel die Rückmeldung; die Abgleich-Insel wartet.
    @State private var refreshing = false
    /// Zählt hoch, wenn die Bordkarte aufwächst: Die Seite rollt dann, bis sie über der Tab-Leiste steht.
    @State private var ticketRequests = 0

    private let motif = StitchGrid(pattern: CharlesBridgeMotif.rows)
    private var decided: Int { store.franked.count }
    private var total: Int { store.franked.count + store.inbox.count + store.deferred.count }
    private var targetStitches: Double {
        guard total > 0 else { return 0 }
        return Double(motif.cells.count) * Double(decided) / Double(total)
    }
    private var tripDay: Int? { TripDates.tripDay() }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: Stitch.Space.xs) {
                    TramBell(rings: bellRings)
                    StitchedText(text: "Prag", rows: 30, cell: 3.1)
                    Text("4.–9. Oktober").font(.subheadline.weight(.medium)).foregroundStyle(Stitch.inkSoft)
                }

                if let day = tripDay {
                    TodayPlan(day: day, places: store.plan(for: day), root: store.root,
                              flights: (store.data.trip.flights ?? []).filter { $0.date.hasPrefix(String(format: "%02d.10.", day)) }) { selected = $0 }
                        .padding(.top, Stitch.Space.xl)
                } else {
                    GeometryReader { geo in
                        StitchPatternView(motif, cell: geo.size.width / CGFloat(motif.columns), stitched: shownStitches)
                            .frame(maxWidth: .infinity)
                    }
                    .aspectRatio(CGFloat(motif.columns) / CGFloat(motif.rows), contentMode: .fit)
                    .padding(.top, Stitch.Space.xl)
                    .accessibilityElement()
                    .accessibilityLabel("Stickbild der Karlsbrücke, \(decided) von \(total) Ideen beschlossen")

                    HStack(alignment: .center, spacing: Stitch.Space.m) {
                        if TripDates.daysUntilStart() >= 0 { TearCalendar() }
                        progressCard
                    }
                    .padding(.top, Stitch.Space.l)
                }

                pinned.padding(.top, Stitch.Space.xl).id("pinned")
            }
            .padding(.horizontal, Stitch.Space.page).padding(.bottom, Stitch.Space.xl)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            refreshing = true
            await store.sync()
            bellRings += 1
            refreshing = false
        }
        .toolbar { islandItem }
        #if DEBUG
        .task { await demoSync() }
        #endif
        .background(LinenBackground())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: stitchToTarget)
        .onChange(of: targetStitches) { _, _ in stitchToTarget() }
        .sensoryFeedback(.impact(weight: .light), trigger: finished)
        .sheet(item: $selected) { PlaceDetail(placeID: $0.id) }
        .onChange(of: ticketRequests) { _, _ in
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9)) { proxy.scrollTo("pinned", anchor: .bottom) }
            }
        }
        }
    }

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
        var after = store.places
        if mode != "none" {
            after.append(Place(title: "Café Savoy", author: "Mia"))
            after.append(Place(title: "Strahov", author: "Mia"))
            if let index = after.firstIndex(where: { $0.franked }) { after[index].approvals.append("Mia") }
            store.syncChange = SyncChange.between(before: store.places, after: after, me: store.me)
        }
        store.syncing = false
    }
    #endif

    private var progressCard: some View {
        Button(action: openIdeas) {
            HStack(spacing: Stitch.Space.xs) {
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text(progressLine).font(.headline).foregroundStyle(Stitch.ink)
                    if decided == 0 && total > 0 {
                        Text("Jede Idee, für die du dich entscheidest, stickt ein Stück der Brücke.")
                            .font(.footnote).foregroundStyle(Stitch.inkSoft)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Stitch.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .stitchCard()
        }
        .buttonStyle(.plain)
    }

    private var progressLine: String {
        if total == 0 { return "Noch keine Ideen" }
        if decided == 0 { return store.inbox.count == 1 ? "1 Idee offen" : "\(store.inbox.count) Ideen offen" }
        if store.inbox.isEmpty { return "\(decided) beschlossen · alles entschieden" }
        return "\(decided) beschlossen · \(store.inbox.count) offen"
    }

    private func stitchToTarget() {
        guard shownStitches != targetStitches else { return }
        if reduceMotion { shownStitches = targetStitches; return }
        let distance = abs(targetStitches - shownStitches)
        withAnimation(.easeInOut(duration: min(1.6, 0.35 + distance / 400))) {
            shownStitches = targetStitches
        } completion: { finished += 1 }
    }

    private var pinned: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            Text("Angeheftet").font(.title3.weight(.bold)).foregroundStyle(Stitch.ink)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Stitch.Space.m) {
                    FlightTicket(trip: store.data.trip, openDocuments: openDocuments, onOpen: { ticketRequests += 1 })
                    ForEach(store.franked) { place in
                        Button { selected = place } label: { PinnedPolaroid(place: place, root: store.root) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, Stitch.Space.m).padding(.horizontal, Stitch.Space.xxs)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            if store.franked.isEmpty {
                Text("Orte, für die du dich entscheidest, werden hier angeheftet.")
                    .font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
        }
    }
}

/// Runder Knopf nur mit Symbol, 44 × 44.
struct HeaderIconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
            .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
            .background(Stitch.card.opacity(configuration.isPressed ? 1 : 0.85), in: Circle())
            .stitchElevation(.flat)
    }
}

/// Foto im Polaroid-Rahmen, mit einem Heftstich an den Stoff geheftet.
struct PinnedPolaroid: View {
    let place: Place
    let root: URL
    @ScaledMetric(relativeTo: .footnote) private var side: CGFloat = 120
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            AlbumPhoto(asset: place.image, root: root).frame(width: side, height: side)
            Text(place.title).font(.footnote.weight(.semibold)).foregroundStyle(Stitch.ink).lineLimit(1)
                .frame(width: side, alignment: .leading)
        }
        .padding(Stitch.Space.xs).padding(.bottom, Stitch.Space.xxs)
        .background(Stitch.card)
        .stitchElevation(.pinned)
        .overlay(alignment: .top) { TackStitch(color: Stitch.cobalt).offset(y: -Stitch.Space.xxs) }
        .rotationEffect(.degrees(place.id.stableTilt * 3))
        .accessibilityElement(children: .combine)
    }
}

/// Die Anreise als angehefteter Ticket-Abschnitt; öffnet die Reiseunterlagen.
struct PinnedTicket: View {
    let trip: TripInfo
    /// Ohne Rahmen nur der Inhalt, damit `FlightTicket` die Hülle selbst wachsen lässt.
    var chrome = true
    @ScaledMetric(relativeTo: .footnote) private var width: CGFloat = 152
    private var flight: FlightLeg? { trip.flights?.first { $0.direction == .outbound } }
    var body: some View {
        if chrome {
            content
                .padding(Stitch.Space.s)
                .frame(width: width, alignment: .topLeading)
                .frame(minHeight: width, alignment: .topLeading)
                .background(Stitch.card)
                .stitchElevation(.pinned)
                .overlay(alignment: .top) { TackStitch(color: Stitch.cobalt).offset(y: -Stitch.Space.xxs) }
                .rotationEffect(.degrees(2))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(flight.map { "Anreise \($0.number), \($0.from) nach \($0.to)" } ?? "Reiseunterlagen öffnen")
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            Image(systemName: "airplane").font(.title3.weight(.semibold)).foregroundStyle(Stitch.ink)
            PerforationLine()
            if let flight {
                Text(flight.number).font(.headline).foregroundStyle(Stitch.ink)
                Text("\(flight.from) → \(flight.to)").font(.subheadline).foregroundStyle(Stitch.ink)
                Text("\(flight.date.prefix(6)) · \(flight.departure)").font(.footnote.monospacedDigit()).foregroundStyle(Stitch.inkSoft)
            } else if !trip.flightNumber.isEmpty {
                Text(trip.flightNumber).font(.headline).foregroundStyle(Stitch.ink)
                if !trip.route.isEmpty { Text(trip.route).font(.subheadline).foregroundStyle(Stitch.ink) }
            } else {
                Text("Anreise").font(.headline).foregroundStyle(Stitch.ink)
                Text("Tickets & Reisedaten hinzufügen").font(.footnote).foregroundStyle(Stitch.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Karlsbrücke mit Altstädter und Kleinseitner Brückenturm als Stickmuster (48 × 29).
enum CharlesBridgeMotif {
    static let rows = [
        ".........y......................................",
        "........kbk.....................................",
        "........bbb..........................y..........",
        ".......kbbbk........................kbk.........",
        ".......bbbbb........................bbb.........",
        "......kbbbbbk......y...............kbbbk........",
        "......bbbbbbb.....kbk..............bbbbb........",
        ".....kbbbbbbbk....bbb.............kbbbbbk.......",
        "....y.rrrrrrr.y...bbb.............yrrrrry.......",
        "....ryrrrrrrryr...rrr..............rrrrr........",
        "....rrkrrkrrkrr...rkr..............rkrkr........",
        "....rrkrrkrrkrr...rkr..............rkrkr........",
        "....rrkrrkrrkrr...rrr..............rrrrr........",
        "....rrrrrrrrrrr...rrr...k......k...rrrrr...k....",
        "....rrrrrrrrrrr...rrr..kkk....kkk..rkrkr..kkk...",
        "....rrrrrrrrrrr...rrr...k..y...k...rrrrr...k.y..",
        "....rrrkkkkkrrr...rrr...k.kbk..k...rrrrr...k.b..",
        "....rrkk...kkrr...rrr..kkk.b..kkk..rrrrr..kkkb..",
        "yyyyrrk.....krryyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy",
        "rrrrrrk.....krrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr",
        "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr",
        "rrrr.......rrrrr.......rrrrr.......rrrrr.......r",
        "rrr.........rrr.........rrr.........rrr.........",
        "rr...........r...........r...........r..........",
        "rr...........r...........r...........r..........",
        ".bbb..bbbb...b...bbbb..b.b..bbbb...b.b..bbbb..bb",
        "bbbbbbb..bbbbbbbbb..bbbbbbbbb..bbbbbbbb..bbbbbbb",
        "..bbb....bbb...bbb....bbb...bbb....bbb....bbb...",
        "......bb.........bb.........bb.........bb.......",
    ]
}
