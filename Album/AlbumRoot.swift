import SwiftUI

enum AlbumTab: String, CaseIterable { case album = "Album", inbox = "Inbox", map = "Karte"
    var symbol: String { switch self { case .album: return "square.on.square"; case .inbox: return "envelope"; case .map: return "map" } }
}
struct AlbumRoot: View {
    @Environment(AlbumStore.self) private var store
    @State private var tab: AlbumTab = .album
    @State private var adding = false
    @State private var settings = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image("imgSculpture").resizable().scaledToFit().frame(width: 32, height: 32)
                        .background(AlbumStyle.paper, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(AlbumStyle.gold, lineWidth: 0.75))
                    Text(tab.rawValue).font(AlbumStyle.serif())
                    Spacer()
                    if tab == .inbox { Text("\(store.inbox.count) übrig").font(AlbumStyle.body(12)).foregroundStyle(AlbumStyle.muted) }
                    Button { adding = true } label: { Image(systemName: "plus").frame(width: 40, height: 40) }.accessibilityLabel("Idee hinzufügen")
                    Button { settings = true } label: { Image(systemName: "person.2.fill").frame(width: 40, height: 40) }.accessibilityLabel("Geteiltes Album verwalten")
                }.padding(.horizontal, 16).padding(.vertical, 4)
                Group {
                    switch tab {
                    case .album: HomeView(openInbox: { tab = .inbox }, openMap: { tab = .map })
                    case .inbox: InboxView()
                    case .map: TripMapView()
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 0) {
                    ForEach(AlbumTab.allCases, id: \.self) { item in
                        Button { tab = item } label: {
                            VStack(spacing: 5) {
                                Image(item == .album ? "imgIconAlbum" : item == .inbox ? "imgIconInbox" : "imgIconKarte").renderingMode(.template).resizable().scaledToFit().frame(width: 20, height: 20)
                                Text(item.rawValue).font(AlbumStyle.ticket)
                                Capsule().fill(tab == item ? AlbumStyle.red : .clear).frame(width: 18, height: 3)
                            }.frame(maxWidth: .infinity).frame(height: 54)
                        }.foregroundStyle(tab == item ? AlbumStyle.red : AlbumStyle.muted)
                            .accessibilityAddTraits(tab == item ? .isSelected : [])
                    }
                }.padding(.top, 8).background(AlbumStyle.deep)
                    .overlay(alignment: .top) { Rectangle().fill(AlbumStyle.gold).frame(height: 0.5) }
            }.background(AlbumStyle.paper).foregroundStyle(AlbumStyle.ink)
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $adding) { PlaceEditor(place: Place(title: "")) }
                .sheet(isPresented: $settings) { AlbumSettings() }
                .sensoryFeedback(.selection, trigger: tab)
        }
    }
}

struct HomeView: View {
    @Environment(AlbumStore.self) private var store
    var openInbox: () -> Void
    var openMap: () -> Void
    @State private var documents = false
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button(action: openMap) {
                    PhotoCard(asset: .bundled(name: "imgPhotoCharlesBridge"), title: "Prag", subtitle: "4.–9. Okt 2026 · Wir zwei", detail: "\(store.franked.count) frankiert · \(store.inbox.count) offen", display: true).frame(height: 420)
                }.buttonStyle(.plain).accessibilityLabel("Prag, 4. bis 9. Oktober 2026. Reise öffnen")
                Button { documents = true } label: { BoardingPassView(trip: store.data.trip) }.buttonStyle(.plain)
                Button(action: openInbox) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("INBOX").font(AlbumStyle.ticket).tracking(0.6).foregroundStyle(AlbumStyle.red)
                            Text("\(store.inbox.count) Ideen zum Frankieren").font(AlbumStyle.body()).foregroundStyle(AlbumStyle.ink)
                        }
                        Spacer()
                        HStack(spacing: -8) {
                            ForEach(Array(store.inbox.prefix(3))) { p in
                                AlbumPhoto(asset: p.image, root: store.root).frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 4)).overlay(RoundedRectangle(cornerRadius: 4).stroke(AlbumStyle.white, lineWidth: 2))
                            }
                        }
                    }.padding(.vertical, 6)
                }.buttonStyle(.plain)
                HStack {
                    Image(systemName: "bed.double")
                    Text(store.data.trip.hotel).font(AlbumStyle.serif())
                    Spacer()
                }.foregroundStyle(AlbumStyle.muted).padding(.vertical, 6)
            }.padding(16).padding(.top, -8)
        }.sheet(isPresented: $documents) { TripDocumentsView() }
    }
}

struct BoardingPassView: View {
    let trip: TripInfo
    var hasFlight: Bool { !trip.outbound.isEmpty || !trip.arrival.isEmpty }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(hasFlight ? "ANREISE · 4. OKT" : "REISE · 4.–9. OKT").font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.muted)
                if hasFlight {
                    HStack { Text(trip.outbound); Spacer(); Text("→").font(AlbumStyle.serif()).foregroundStyle(AlbumStyle.gold); Spacer(); Text(trip.arrival) }.font(AlbumStyle.display(42)).minimumScaleFactor(0.6).lineLimit(1)
                    Text(trip.route).font(AlbumStyle.serif())
                } else {
                    Text("Noch keine Anreise eingetragen").font(AlbumStyle.serif(28))
                    Text("Tickets & Reisedaten hinzufügen").font(AlbumStyle.body(13)).foregroundStyle(AlbumStyle.muted)
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            Text(trip.flightNumber.isEmpty ? "PRAG 2026" : trip.flightNumber).font(AlbumStyle.ticket).rotationEffect(.degrees(90)).fixedSize().frame(width: 36, height: 130).background(AlbumStyle.deep)
        }.foregroundStyle(AlbumStyle.ink).background(AlbumStyle.white, in: RoundedRectangle(cornerRadius: 20))
            .clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AlbumStyle.gold, lineWidth: 0.8))
    }
}
