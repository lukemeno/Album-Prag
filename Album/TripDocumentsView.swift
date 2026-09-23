import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct TripDocumentsView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var selected: TravelDocument?
    @State private var editing = false
    @State private var extraction: ExtractedTrip?
    private var trip: TripInfo { store.data.trip }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Reiseunterlagen").font(AlbumStyle.display())
                    Text("Prag · 4.–9. Oktober 2026").font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.red)
                    if let flights = trip.flights, !flights.isEmpty {
                        ForEach(flights) { FlightCard(flight: $0) }
                    } else {
                        BoardingPassView(trip: trip)
                    }
                    if let details = trip.hotelDetails {
                        HotelCard(name: details.name ?? trip.hotel, details: details)
                    } else {
                        Label(trip.hotel, systemImage: "bed.double").font(AlbumStyle.serif(25))
                    }
                    if let travelers = trip.travelers, !travelers.isEmpty {
                        Label(travelers.joined(separator: " & "), systemImage: "person.2.fill").font(.subheadline.weight(.semibold))
                    }
                    if let number = trip.bookingNumber {
                        Label("Buchungsnummer \(number)", systemImage: "number").font(.subheadline.weight(.semibold)).textSelection(.enabled)
                    }
                    if !trip.notes.isEmpty { Text(trip.notes).font(AlbumStyle.body()).foregroundStyle(AlbumStyle.muted) }
                    Button("Reisedaten bearbeiten") { editing = true }.buttonStyle(AlbumButton())
                    Divider()
                    Text("Dokumente").font(AlbumStyle.serif(28))
                    ForEach(store.data.documents) { doc in
                        HStack(spacing: 10) {
                            Button { selected = doc } label: {
                                HStack { Image(systemName: "doc.richtext"); Text(doc.name).font(AlbumStyle.body()).multilineTextAlignment(.leading); Spacer(); Image(systemName: "chevron.right") }
                                    .padding(16).background(AlbumStyle.white, in: RoundedRectangle(cornerRadius: 14))
                            }
                            Button { extraction = store.extraction(from: doc) } label: { Image(systemName: "text.viewfinder") }
                                .buttonStyle(HeaderIconButton())
                                .accessibilityLabel("Daten aus \(doc.name) lesen")
                        }
                    }
                    Button("PDF hinzufügen") { importing = true }.buttonStyle(AlbumButton(primary: true))
                    Text("Das Original bleibt gespeichert. Enthaltenen Text könnt ihr prüfen und Reisedaten daraus übernehmen. Gescannte PDFs bleiben als Dokument lesbar.").font(AlbumStyle.body(13)).foregroundStyle(AlbumStyle.muted)
                }.padding(16)
            }.background(LinenBackground()).navigationTitle("Reiseunterlagen").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in
                    do {
                        let id = UUID().uuidString
                        try store.importPDF(result.get(), id: id)
                        if let doc = store.data.documents.first(where: { $0.id == id }) { extraction = store.extraction(from: doc) }
                    } catch { store.error = error.localizedDescription }
                }
                .sheet(item: $extraction) { ExtractedTripSheet(extracted: $0) }
                .sheet(item: $selected) { DocumentDetail(document: $0) }
                .sheet(isPresented: $editing) { TripEditor(trip: store.data.trip) }
        }
    }
}

struct DocumentDetail: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let document: TravelDocument
    @State private var showText = false
    var body: some View {
        NavigationStack {
            Group {
                if showText {
                    ScrollView { Text(document.extractedText.isEmpty ? "Dieses PDF enthält keinen auslesbaren Text. Bitte das Original ansehen." : document.extractedText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }
                } else { PDFReader(url: store.root.appendingPathComponent(document.filename)) }
            }.navigationTitle(document.name).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { Button(showText ? "Original" : "Text") { showText.toggle() } }
                    ToolbarItem(placement: .bottomBar) { ShareLink(item: store.root.appendingPathComponent(document.filename)) { Label("PDF teilen", systemImage: "square.and.arrow.up") } }
                }
        }
    }
}
struct PDFReader: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; view.document = PDFDocument(url: url); return view }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
struct TripEditor: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var trip: TripInfo
    var body: some View {
        NavigationStack {
            Form {
                Section("Prag · 4.–9. Oktober 2026") {
                    TextField("Unterkunft", text: $trip.hotel)
                    TextField("Abflug, z. B. 14:45", text: $trip.outbound)
                    TextField("Ankunft, z. B. 15:55", text: $trip.arrival)
                    TextField("Route, z. B. CGN → PRG", text: $trip.route)
                    TextField("Flugnummer", text: $trip.flightNumber)
                    TextField("Rückreise, Check-in & Notizen", text: $trip.notes, axis: .vertical).lineLimit(4...10)
                }
            }.scrollContentBackground(.hidden).background(LinenBackground()).navigationTitle("Reisedaten").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") { store.updateTrip(trip); dismiss() } }
                }
        }
    }
}
