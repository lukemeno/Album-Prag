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
    private var hasFlights: Bool { !(trip.flights ?? []).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                    section("Anreise") {
                        if let flights = trip.flights, !flights.isEmpty {
                            ForEach(flights) { FlightCard(flight: $0) }
                        } else {
                            Button { importing = true } label: {
                                HStack(spacing: Stitch.Space.s) {
                                    Image(systemName: "airplane").font(.title3).foregroundStyle(Stitch.ink)
                                    VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                                        Text("Noch keine Flüge").font(.headline).foregroundStyle(Stitch.ink)
                                        Text("Füg deine Buchungsbestätigung als PDF hinzu, dann steht alles hier.")
                                            .font(.footnote).foregroundStyle(Stitch.inkSoft)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "plus").font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .stitchCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    section("Unterkunft") {
                        if let details = trip.hotelDetails {
                            HotelCard(name: details.name ?? trip.hotel, details: details)
                        } else {
                            Label(trip.hotel, systemImage: "bed.double.fill").font(.headline).foregroundStyle(Stitch.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .stitchCard()
                        }
                        if trip.travelers?.isEmpty == false || trip.bookingNumber != nil || !trip.notes.isEmpty {
                            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                                if let travelers = trip.travelers, !travelers.isEmpty {
                                    Label(travelers.joined(separator: " & "), systemImage: "person.2.fill")
                                }
                                if let number = trip.bookingNumber {
                                    Label("Buchung \(number)", systemImage: "number").textSelection(.enabled)
                                }
                                if !trip.notes.isEmpty {
                                    Label(trip.notes, systemImage: "note.text")
                                }
                            }
                            .font(.subheadline).foregroundStyle(Stitch.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .stitchCard()
                        }
                    }

                    section("Dokumente") {
                        ForEach(store.data.documents) { doc in
                            HStack(spacing: Stitch.Space.xs) {
                                Button { selected = doc } label: {
                                    HStack(spacing: Stitch.Space.s) {
                                        Image(systemName: "doc.text").foregroundStyle(Stitch.ink)
                                            .frame(width: 36, height: 36).background(Stitch.paperDeep, in: Circle())
                                        Text(doc.name).font(.body).foregroundStyle(Stitch.ink).multilineTextAlignment(.leading)
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Stitch.inkSoft)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .stitchCard()
                                }
                                .buttonStyle(.plain)
                                Button("Auslesen") { extraction = store.extraction(from: doc) }
                                    .buttonStyle(AlbumTextActionButtonStyle())
                                    .accessibilityLabel("Flüge und Hotel aus \(doc.name) übernehmen")
                            }
                        }
                        Button("PDF hinzufügen", systemImage: "plus") { importing = true }
                            .buttonStyle(AlbumActionButtonStyle(primary: !hasFlights))
                        Text("Das Original bleibt gespeichert. Flüge und Hotel übernimmt Album aus dem Text.")
                            .font(.footnote).foregroundStyle(Stitch.inkSoft)
                    }

                    section("Wechsel zu Expo") {
                        Text("Teile dieses Backup und öffne es anschließend in der Expo-App unter „Album übertragen“.")
                            .font(.footnote).foregroundStyle(Stitch.inkSoft)
                        ShareLink(item: store.root.appendingPathComponent("album.json")) {
                            Label("Album-Backup exportieren", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(AlbumActionButtonStyle(primary: false))
                    }
                }
                .padding(Stitch.Space.page)
            }
            .background(PaperBackground())
            .navigationTitle("Unterlagen").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Bearbeiten") { editing = true } }
            }
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

    /// Abschnitt mit Überschrift: 8 pt zwischen Überschrift und Inhalt, 12 pt zwischen Karten.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            SectionTitle(title)
            content()
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
                    ScrollView {
                        Text(document.extractedText.isEmpty ? "Dieses PDF enthält keinen auslesbaren Text. Bitte das Original ansehen." : document.extractedText)
                            .font(.body)
                            .foregroundStyle(Stitch.ink)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .stitchCard()
                            .padding(Stitch.Space.page)
                    }
                } else { PDFReader(url: store.root.appendingPathComponent(document.filename)) }
            }.navigationTitle(document.name).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Schließen", systemImage: "xmark") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { Button(showText ? "Original" : "Als Text") { showText.toggle() } }
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
                Section {
                    TextField("Unterkunft", text: $trip.hotel)
                    TextField("Abflug, z. B. 14:45", text: $trip.outbound)
                    TextField("Ankunft, z. B. 15:55", text: $trip.arrival)
                    TextField("Route, z. B. CGN → PRG", text: $trip.route)
                    TextField("Flugnummer", text: $trip.flightNumber)
                    TextField("Notizen", text: $trip.notes, axis: .vertical)
                        .lineLimit(4...10)
                        .accessibilityLabel("Notizen")
                        .accessibilityIdentifier("TripEditor-Notes")
                }
                .listRowBackground(Stitch.card)
            }.scrollContentBackground(.hidden).background(PaperBackground()).navigationTitle("Reisedaten").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") { if store.updateTrip(trip) { dismiss() } } }
                }
        }
    }
}
