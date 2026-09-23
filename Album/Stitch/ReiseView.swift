import SwiftUI

/// Startseite der Reise: gesticktes „Prag“, das Brückenmotiv als Fortschritt und angeheftete Orte.
struct ReiseView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var openIdeas: () -> Void
    var onAdd: () -> Void
    var onShare: () -> Void
    @State private var shownStitches: Double = 0
    @State private var finished = 0
    @State private var selected: Place?
    @State private var documents = false
    @State private var bellRings = 0

    private let motif = StitchGrid(pattern: CharlesBridgeMotif.rows)
    private var decided: Int { store.franked.count }
    private var total: Int { store.franked.count + store.inbox.count + store.deferred.count }
    private var targetStitches: Double {
        guard total > 0 else { return 0 }
        return Double(motif.cells.count) * Double(decided) / Double(total)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    TabHeader(onAdd: onAdd, onShare: onShare)
                    TramBell(rings: bellRings).padding(.top, 6)
                }
                StitchedText(text: "Prag", rows: 30, cell: 3.1)
                    .padding(.top, 4)
                Text("4.–9. Oktober · \(store.data.trip.hotel)")
                    .font(.subheadline.weight(.medium)).foregroundStyle(Stitch.inkSoft)
                    .padding(.top, 10)

                if let day = TripDates.tripDay() {
                    TodayPlan(day: day, places: store.franked.filter { $0.day == day }, root: store.root) { selected = $0 }
                        .padding(.top, 24)
                }

                GeometryReader { geo in
                    StitchPatternView(motif, cell: geo.size.width / CGFloat(motif.columns), stitched: shownStitches)
                        .frame(maxWidth: .infinity)
                }
                .aspectRatio(CGFloat(motif.columns) / CGFloat(motif.rows), contentMode: .fit)
                .padding(.top, 28)
                .accessibilityElement()
                .accessibilityLabel("Stickbild der Karlsbrücke, \(decided) von \(total) Ideen beschlossen")

                HStack(alignment: .center, spacing: 18) {
                    if TripDates.daysUntilStart() >= 0 && TripDates.tripDay() == nil {
                        TearCalendar().padding(.top, 4)
                    }
                    Button(action: openIdeas) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                TackStitch(size: 11)
                                Text(progressLine).font(.subheadline.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Image(systemName: "chevron.right").font(.caption.weight(.bold))
                            }
                            Text("Jede beschlossene Idee stickt ein Stück der Brücke.")
                                .font(.footnote).foregroundStyle(Stitch.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(Stitch.ink)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Stitch.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 22)

                pinned.padding(.top, 30)
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await store.sync()
            bellRings += 1
        }
        .background(LinenBackground())
        .onAppear(perform: stitchToTarget)
        .onChange(of: targetStitches) { _, _ in stitchToTarget() }
        .sensoryFeedback(.impact(weight: .light), trigger: finished)
        .sheet(item: $selected) { PlaceDetail(placeID: $0.id) }
        .sheet(isPresented: $documents) { TripDocumentsView() }
    }

    private var progressLine: String {
        if total == 0 { return "Noch keine Ideen" }
        if store.inbox.isEmpty { return "\(decided) Orte fest · alles entschieden" }
        return "\(decided) Orte fest · \(store.inbox.count) offen"
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Angeheftet").font(.title3.weight(.bold)).foregroundStyle(Stitch.ink)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    Button { documents = true } label: { PinnedTicket(trip: store.data.trip) }.buttonStyle(.plain)
                    ForEach(store.franked) { place in
                        Button { selected = place } label: { PinnedPolaroid(place: place, root: store.root) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 14).padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            if store.franked.isEmpty {
                Text("Orte, die ihr in den Ideen beschließt, werden hier angeheftet.")
                    .font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
        }
    }
}

/// Kopfzeile mit den beiden globalen Aktionen.
struct TabHeader: View {
    var title: String? = nil
    var subtitle: String? = nil
    var onAdd: () -> Void
    var onShare: () -> Void
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.largeTitle.weight(.bold)).foregroundStyle(Stitch.ink)
                    if let subtitle { Text(subtitle).font(.subheadline.weight(.medium)).foregroundStyle(Stitch.inkSoft) }
                }
            }
            Spacer()
            Button(action: onShare) { Image(systemName: "person.2") }
                .accessibilityLabel("Geteiltes Album verwalten")
                .buttonStyle(HeaderIconButton())
            Button(action: onAdd) { Image(systemName: "plus") }
                .accessibilityLabel("Idee hinzufügen")
                .buttonStyle(HeaderIconButton())
        }
        .padding(.top, 6)
    }
}

struct HeaderIconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
            .frame(width: 44, height: 44)
            .background(Stitch.card.opacity(configuration.isPressed ? 1 : 0.8), in: Circle())
            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }
}

/// Foto im Polaroid-Rahmen, mit einem Heftstich an den Stoff geheftet.
struct PinnedPolaroid: View {
    let place: Place
    let root: URL
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AlbumPhoto(asset: place.image, root: root).frame(width: 118, height: 118)
            Text(place.title).font(.footnote.weight(.semibold)).foregroundStyle(Stitch.ink).lineLimit(1)
                .frame(width: 118, alignment: .leading)
        }
        .padding(8).padding(.bottom, 4)
        .background(Stitch.card)
        .shadow(color: .black.opacity(0.16), radius: 5, x: 1, y: 3)
        .overlay(alignment: .top) { TackStitch(color: Stitch.cobalt, size: 11).offset(y: -4) }
        .rotationEffect(.degrees(place.id.stableTilt * 3))
        .accessibilityElement(children: .combine)
    }
}

/// Die Anreise als angehefteter Ticket-Abschnitt.
struct PinnedTicket: View {
    let trip: TripInfo
    private var hasFlight: Bool { !trip.outbound.isEmpty || !trip.arrival.isEmpty || !trip.flightNumber.isEmpty }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "airplane").font(.title3.weight(.semibold)).foregroundStyle(Stitch.ink)
            if hasFlight {
                if !trip.flightNumber.isEmpty { Text(trip.flightNumber).font(.headline).foregroundStyle(Stitch.ink) }
                if !trip.route.isEmpty { Text(trip.route).font(.subheadline).foregroundStyle(Stitch.ink) }
                Text([trip.outbound, trip.arrival].filter { !$0.isEmpty }.joined(separator: " → "))
                    .font(.footnote.monospacedDigit()).foregroundStyle(Stitch.inkSoft)
            } else {
                Text("Anreise").font(.headline).foregroundStyle(Stitch.ink)
                Text("Tickets & Reisedaten hinzufügen").font(.footnote).foregroundStyle(Stitch.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HStack(spacing: 1.5) {
                ForEach(0..<22, id: \.self) { i in
                    Rectangle().fill(Stitch.ink.opacity(0.75)).frame(width: i % 3 == 0 ? 2 : 1, height: 16)
                }
            }
        }
        .padding(12)
        .frame(width: 150, height: 160, alignment: .topLeading)
        .background(Stitch.card)
        .overlay(alignment: .top) {
            Rectangle().fill(.clear).frame(height: 1)
                .overlay(Line().stroke(Stitch.ink.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                .offset(y: 26)
        }
        .shadow(color: .black.opacity(0.14), radius: 5, x: 1, y: 3)
        .overlay(alignment: .top) { TackStitch(color: Stitch.cobalt, size: 11).offset(y: -4) }
        .rotationEffect(.degrees(2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hasFlight ? "Anreise \(trip.flightNumber) \(trip.route)" : "Reisedaten hinzufügen")
    }
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path { Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: rect.width, y: 0)) } }
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
