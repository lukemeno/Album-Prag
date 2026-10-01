import SwiftUI

/// Startseite der Reise, eine Spalte von oben nach unten: Prag mit Datum, ein Foto, die Reisetage mit dem
/// Plan des gewählten Tages, Anreise und Unterkunft mit den Unterlagen, die beschlossenen Orte und der
/// Stand der Ideen. Während der Reise ist „heute“ vorgewählt, davor der Anreisetag.
struct ReiseView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var openIdeas: () -> Void
    var openDocuments: () -> Void
    @State private var selected: Place?
    /// Vom Finger gewählter Tag; nil heißt: der Tag, der von selbst gilt.
    @State private var chosenDay: Int?
    /// Solange das Herunterziehen abgleicht, wartet die Abgleich-Insel.
    @State private var refreshing = false
    @State private var refreshTick = 0
    /// Zählt hoch, wenn die Bordkarte aufwächst: Die Seite rollt dann, bis sie über der Tab-Leiste steht.
    @State private var ticketRequests = 0

    private var decided: Int { store.franked.count }
    private var total: Int { store.franked.count + store.inbox.count + store.deferred.count }
    private var tripDay: Int? { TripDates.tripDay() }
    /// Der Tag, der ohne Zutun gilt: heute während der Reise, sonst der erste Reisetag.
    private var day: Int { chosenDay ?? tripDay ?? DayPlanGenerator.days.first ?? 4 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                    header
                    hero
                    days
                    travel.id("anreise")
                    pinned
                    ideas
                }
                .padding(.horizontal, Stitch.Space.page)
                .padding(.top, Stitch.Space.xs)
                .padding(.bottom, Stitch.Space.xl)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                refreshing = true
                await store.sync()
                refreshTick += 1
                refreshing = false
            }
            .toolbar { islandItem }
            #if DEBUG
            .task { await demoSync() }
            #endif
            .background(LinenBackground())
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.success, trigger: refreshTick)
            .sheet(item: $selected) { PlaceDetail(placeID: $0.id) }
            .onChange(of: ticketRequests) { _, _ in
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    withAnimation(Stitch.Motion.maybe(reduceMotion, Stitch.Motion.sheet)) { proxy.scrollTo("anreise", anchor: .bottom) }
                }
            }
        }
    }

    // MARK: Kopf

    /// „Prag“ in Serifenschrift – das einzige Schmuckstück der Seite –, darunter Zeitraum und Stand der Reise.
    private var header: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
            Text("Prag")
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(Stitch.ink)
            HStack(spacing: Stitch.Space.xs) {
                Text("4.–9. Oktober").font(.subheadline.weight(.medium)).foregroundStyle(Stitch.inkSoft)
                Text("·").font(.subheadline).foregroundStyle(Stitch.rule)
                Text(standing).font(.subheadline.weight(.medium)).foregroundStyle(Stitch.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Eine Zeile, die sagt, wo die Reise steht: davor zählt sie, unterwegs nennt sie den Tag, danach ist sie vorbei.
    private var standing: String {
        if let tripDay { return "Tag \(tripDay - 3) von \(DayPlanGenerator.days.count)" }
        let days = TripDates.daysUntilStart()
        if days > 1 { return "Noch \(days) Tage" }
        if days == 1 { return "Noch 1 Tag" }
        if days == 0 { return "Heute geht’s los" }
        return "Reise vorbei"
    }

    // MARK: Foto

    /// Das erste beschlossene Foto, höchstens 200 hoch; Tippen führt zum Ort. Ohne Orte bleibt die Stelle leer.
    private var heroPlace: Place? {
        store.franked.first { $0.image != nil && $0.category != "Unterkunft" }
    }

    @ViewBuilder private var hero: some View {
        if let place = heroPlace {
            Button { selected = place } label: {
                PhotoCard(asset: place.image, root: store.root, title: place.title, subtitle: place.category, thumbnailWidth: 960)
                    .frame(height: 200)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(place.title), \(place.category)")
            .accessibilityHint("Zeigt den Ort")
        }
    }

    // MARK: Tage

    private var days: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            AlbumSectionHeader(title: TripDates.dayTitle(day), highlight: day == tripDay ? "Heute" : nil)
            DayStrip(selected: day, today: tripDay, counts: plannedCounts) { chosenDay = $0 }
            DayPlanRows(day: day, places: store.plan(for: day), root: store.root, flights: flights(on: day)) { selected = $0 }
        }
    }

    private var plannedCounts: [Int: Int] {
        Dictionary(uniqueKeysWithValues: DayPlanGenerator.days.map { ($0, store.plan(for: $0).count) })
    }

    private func flights(on day: Int) -> [FlightLeg] {
        (store.data.trip.flights ?? []).filter { $0.date.hasPrefix(String(format: "%02d.10.", day)) }
    }

    // MARK: Anreise, Unterkunft, Unterlagen

    private var travel: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            AlbumSectionHeader(title: "Anreise & Unterkunft")
            FlightTicket(trip: store.data.trip, openDocuments: openDocuments, onOpen: { ticketRequests += 1 })
            if let hotel = hotelLine { hotelCard(hotel) }
            Button(action: openDocuments) {
                HStack(spacing: Stitch.Space.s) {
                    Image(systemName: "doc.text").font(.body.weight(.semibold)).foregroundStyle(Stitch.red)
                    Text("Reiseunterlagen").font(.headline).foregroundStyle(Stitch.ink)
                    Spacer(minLength: 0)
                    Text(documentCount).font(.footnote).foregroundStyle(Stitch.inkSoft)
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Stitch.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .stitchCard()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Flüge, Hotel und PDFs")
        }
    }

    private var documentCount: String {
        let count = store.data.documents.count
        if count == 0 { return "noch leer" }
        return count == 1 ? "1 PDF" : "\(count) PDFs"
    }

    /// Name, Adresse und Zeiten der Unterkunft – nur was wirklich in den Reisedaten steht.
    private var hotelLine: (name: String, address: String?, checkIn: String?, checkOut: String?)? {
        let trip = store.data.trip
        let details = trip.hotelDetails
        let name = details?.name ?? trip.hotel
        guard !name.isEmpty else { return nil }
        return (name, details?.address, details?.checkIn, details?.checkOut)
    }

    private func hotelCard(_ hotel: (name: String, address: String?, checkIn: String?, checkOut: String?)) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            HStack(spacing: Stitch.Space.xs) {
                Image(systemName: "bed.double").font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                Text(hotel.name).font(.headline).foregroundStyle(Stitch.ink)
            }
            if let address = hotel.address, !address.isEmpty {
                Button { openMaps(address) } label: {
                    Text(address).font(.subheadline).multilineTextAlignment(.leading)
                }
                .foregroundStyle(Stitch.red)
                .accessibilityLabel("Adresse \(address), in Karten öffnen")
            }
            if hotel.checkIn != nil || hotel.checkOut != nil {
                HStack(spacing: Stitch.Space.m) {
                    if let checkIn = hotel.checkIn { Text("Check-in ab \(checkIn)") }
                    if let checkOut = hotel.checkOut { Text("Check-out bis \(checkOut)") }
                }
                .font(.footnote.monospacedDigit()).foregroundStyle(Stitch.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stitchCard()
    }

    private func openMaps(_ address: String) {
        let query = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(query)") { UIApplication.shared.open(url) }
    }

    // MARK: Beschlossene Orte

    @ViewBuilder private var pinned: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            AlbumSectionHeader(title: "Beschlossen", detail: decided > 0 ? (decided == 1 ? "1 Ort" : "\(decided) Orte") : "")
            if store.franked.isEmpty {
                Text("Orte, für die du dich entscheidest, stehen hier.")
                    .font(.subheadline).foregroundStyle(Stitch.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .stitchCard()
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: Stitch.Space.s) {
                        ForEach(store.franked) { place in
                            Button { selected = place } label: { PinnedStamp(place: place, root: store.root) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, Stitch.Space.xxs)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
    }

    // MARK: Ideen

    private var ideas: some View {
        Button(action: openIdeas) {
            HStack(spacing: Stitch.Space.s) {
                Image(systemName: "lightbulb").font(.body.weight(.semibold)).foregroundStyle(Stitch.red)
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text(progressLine).font(.headline).foregroundStyle(Stitch.ink)
                    if decided == 0 && total > 0 {
                        Text("Entscheide dich, dann wandern die Orte in den Plan.")
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
}

/// Ein beschlossener Ort als kleine Marke: Foto mit Zähnung, darunter der Name.
struct PinnedStamp: View {
    let place: Place
    let root: URL
    @ScaledMetric(relativeTo: .footnote) private var side: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            StampPhoto(asset: place.image, root: root, thumbnailWidth: 500, spacing: 16)
                .frame(width: side, height: side)
            Text(place.title).font(.footnote.weight(.semibold)).foregroundStyle(Stitch.ink).lineLimit(1)
                .frame(width: side, alignment: .leading)
        }
        .padding(Stitch.Space.xs)
        .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous).strokeBorder(Stitch.rule, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Die Anreise als Ticket-Abschnitt; öffnet die Reiseunterlagen.
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
                .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous).strokeBorder(Stitch.rule, lineWidth: 1))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(flight.map { "Anreise \($0.number), \($0.from) nach \($0.to)" } ?? "Reiseunterlagen öffnen")
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            Image(systemName: "airplane").font(.title3.weight(.semibold)).foregroundStyle(Stitch.red)
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
