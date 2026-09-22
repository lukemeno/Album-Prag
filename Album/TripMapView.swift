import SwiftUI
import MapKit

struct TripMapView: View {
    @Environment(AlbumStore.self) private var store
    @State private var camera: MapCameraPosition = .region(.init(center: .init(latitude: 50.087, longitude: 14.423), span: .init(latitudeDelta: 0.035, longitudeDelta: 0.035)))
    @State private var selected: Place?
    @State private var filter = "Alle"
    @State private var documents = false
    var visible: [Place] { store.franked.filter { $0.coordinate != nil && (filter == "Alle" || $0.category == filter) } }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prag auf der Karte").font(AlbumStyle.display(26))
                    Text("4.–9. OKTOBER 2026").font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.muted)
                }
                Spacer()
                Button { documents = true } label: { Image(systemName: "ticket").padding(12) }.accessibilityLabel("Reisedaten und Dokumente")
            }.padding(.horizontal, 16).padding(.bottom, 12)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Alle", "Sehenswert", "Essen & Trinken", "Aussicht", "Unterkunft", "Shopping", "Idee"], id: \.self) { category in
                        Button(category) { filter = category }.font(AlbumStyle.body(12)).padding(.horizontal, 13).padding(.vertical, 9)
                            .background(filter == category ? AlbumStyle.red : AlbumStyle.deep, in: Capsule())
                            .foregroundStyle(filter == category ? AlbumStyle.white : AlbumStyle.ink)
                    }
                }.padding(.horizontal, 16)
            }.padding(.bottom, 10)
            Map(position: $camera) {
                ForEach(visible) { place in
                    if let coordinate = place.coordinate {
                        Annotation(place.title, coordinate: coordinate, anchor: .bottom) {
                            Button { selected = place } label: { StampPin(title: place.title, category: place.category, selected: selected?.id == place.id) }.buttonStyle(.plain)
                        }.annotationTitles(.hidden)
                    }
                }
            }.mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .onAppear { if !visible.isEmpty { camera = .automatic } }
                .onChange(of: visible.map(\.id)) { _, ids in if !ids.isEmpty { camera = .automatic } }
                .mapControls { MapCompass(); MapScaleView() }
                .overlay(alignment: .bottom) {
                    if visible.isEmpty {
                        VStack(spacing: 5) {
                            Text("Noch keine Orte auf der Karte").font(AlbumStyle.serif(24))
                            Text("Frankierte Ideen aus der Inbox\nerscheinen hier als Pins.").font(AlbumStyle.body(13)).multilineTextAlignment(.center).foregroundStyle(AlbumStyle.muted)
                        }.padding(18).frame(maxWidth: .infinity).background(AlbumStyle.paper, in: RoundedRectangle(cornerRadius: 20)).padding(16)
                    }
                }
            if !visible.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(visible) { place in
                            Button { selected = place } label: {
                                HStack(spacing: 10) {
                                    AlbumPhoto(asset: place.image, root: store.root).frame(width: 44, height: 52).clipShape(RoundedRectangle(cornerRadius: 4))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(place.title).font(AlbumStyle.serif()).lineLimit(1)
                                        Text(place.visited ? "BESUCHT" : place.day.map { "\($0). OKTOBER" } ?? place.category.uppercased()).font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.muted)
                                    }
                                }.padding(10).frame(width: 230, alignment: .leading).background(AlbumStyle.white, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                        }
                    }.padding(12)
                }.background(AlbumStyle.paper)
            }
        }.sheet(item: $selected) { PlaceDetail(placeID: $0.id) }
            .sheet(isPresented: $documents) { TripDocumentsView() }
    }
}

struct PlaceDetail: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var placeID: String
    @State private var editing = false
    @State private var confirmDelete = false
    var place: Place? { store.places.first { $0.id == placeID } }
    var body: some View {
        NavigationStack {
            if let place {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PhotoCard(asset: place.image, root: store.root, title: place.title, subtitle: place.category).frame(height: 320)
                        Text(place.address).font(AlbumStyle.body()).foregroundStyle(AlbumStyle.muted)
                        if !place.note.isEmpty { Text(place.note).font(AlbumStyle.body()) }
                        if let source = place.image?.sourceURL, let url = URL(string: source) {
                            Link("Bild: \(place.image?.credit ?? "Quelle") ↗", destination: url).font(AlbumStyle.body(12)).foregroundStyle(AlbumStyle.muted)
                        }
                        if case .external(let image) = place.image, let license = image.licenseName {
                            if let rawURL = image.licenseURL, let url = URL(string: rawURL) {
                                Link("Lizenz: \(license) ↗", destination: url).font(AlbumStyle.body(12)).foregroundStyle(AlbumStyle.muted)
                            } else {
                                Text("Lizenz: \(license)").font(AlbumStyle.body(12)).foregroundStyle(AlbumStyle.muted)
                            }
                        }
                        Text("GESAMMELT VON \(place.author.uppercased())").font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.red)
                        if let url = LinkValidation.url(place.sourceURL) { Link("Original bei \(place.sourceLabel) öffnen ↗", destination: url).font(AlbumStyle.body()) }
                        if let coordinate = place.coordinate {
                            Button("IN APPLE KARTEN ÖFFNEN") {
                                let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                                item.name = place.title
                                item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                            }.buttonStyle(AlbumButton(primary: true))
                        }
                        Button(place.visited ? "ALS UNBESUCHT MARKIEREN" : "ALS BESUCHT MARKIEREN") { var p = place; p.visited.toggle(); store.upsert(p) }.buttonStyle(AlbumButton())
                        Button("Zurück in die Inbox") { var p = place; p.franked = false; p.deferred = false; store.upsert(p); dismiss() }.font(AlbumStyle.body())
                        Button("Idee löschen", role: .destructive) { confirmDelete = true }.font(AlbumStyle.body()).padding(.top, 10)
                    }.padding(16)
                }.background(AlbumStyle.paper).navigationTitle("Ort").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                        ToolbarItem(placement: .primaryAction) { Button("Bearbeiten") { editing = true } }
                    }
                    .sheet(isPresented: $editing) { PlaceEditor(place: place) }
                    .confirmationDialog("Diesen Ort löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Löschen", role: .destructive) { var p = place; p.deleted = true; store.upsert(p); dismiss() }
                    }
            }
        }
    }
}
