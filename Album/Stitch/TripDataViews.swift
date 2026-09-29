import SwiftUI
import MapKit

/// Ein Flug als Ticket: Strecke, Zeiten, Flugnummer, Buchungscode.
struct FlightCard: View {
    let flight: FlightLeg
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            HStack {
                Text(flight.direction == .outbound ? "Hinflug" : "Rückflug").font(.footnote.weight(.bold)).foregroundStyle(Stitch.red)
                Spacer()
                Text(flight.date).font(.footnote.weight(.semibold).monospacedDigit()).foregroundStyle(Stitch.inkSoft)
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text(flight.departure).font(.largeTitle.weight(.bold)).fontDesign(.rounded).monospacedDigit()
                    Text(flight.from).font(.subheadline.weight(.semibold))
                }
                Spacer()
                Image(systemName: "airplane").font(.title3).foregroundStyle(Stitch.red)
                Spacer()
                VStack(alignment: .trailing, spacing: Stitch.Space.xxs) {
                    Text(flight.arrival).font(.largeTitle.weight(.bold)).fontDesign(.rounded).monospacedDigit()
                    Text(flight.to).font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(Stitch.ink)
            PerforationLine()
            HStack(spacing: Stitch.Space.l) {
                fact("Flug", [flight.airline, flight.number].compactMap { $0 }.joined(separator: " "))
                if let arriveBy = flight.arriveBy { fact("Am Flughafen", "ab \(arriveBy)") }
                if let code = flight.bookingCode { fact("Buchungscode", code, copyable: true) }
            }
        }
        .stitchCard()
        .accessibilityElement(children: .combine)
    }

    private func fact(_ label: String, _ value: String, copyable: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
            Text(value).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(Stitch.ink)
                .textSelection(.enabled)
        }
        .contextMenu { if copyable { Button("Kopieren", systemImage: "doc.on.doc") { UIPasteboard.general.string = value } } }
    }

}

/// Das Hotel: Adresse (öffnet Karten), Check-in, Check-out und was inklusive ist.
struct HotelCard: View {
    let name: String
    let details: HotelDetails
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Label(name, systemImage: "bed.double.fill").font(.title3.weight(.bold)).foregroundStyle(Stitch.ink)
            if let address = details.address {
                Button {
                    let query = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "maps://?q=\(query)") { UIApplication.shared.open(url) }
                } label: {
                    Label(address, systemImage: "mappin.and.ellipse").font(.subheadline).multilineTextAlignment(.leading)
                }
                .foregroundStyle(Stitch.red)
            }
            if details.checkIn != nil || details.checkOut != nil {
                HStack(spacing: Stitch.Space.l) {
                    if let checkIn = details.checkIn { fact("Check-in", "ab \(checkIn)") }
                    if let checkOut = details.checkOut { fact("Check-out", "bis \(checkOut)") }
                }
            }
            if !details.included.isEmpty {
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text("Inklusive").font(.caption.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                    ForEach(details.included, id: \.self) { item in
                        Label(item, systemImage: "checkmark").font(.subheadline).foregroundStyle(Stitch.ink)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stitchCard()
    }
    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
            Text(value).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(Stitch.ink)
        }
    }
}

/// Nach dem Hochladen: was im PDF gefunden wurde, zum Übernehmen.
struct ExtractedTripSheet: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let extracted: ExtractedTrip
    @State private var applying = false
    @State private var applied = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.s) {
                    Text("Das steht in deinen Unterlagen. Mit „Übernehmen“ kommt alles in die Reisedaten und das Hotel auf die Karte.")
                        .font(.subheadline).foregroundStyle(Stitch.inkSoft)
                    ForEach(extracted.flights) { FlightCard(flight: $0) }
                    if let name = extracted.hotel.name {
                        HotelCard(name: name, details: extracted.hotel)
                    }
                    if !extracted.travelers.isEmpty || extracted.bookingNumber != nil {
                        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                            if !extracted.travelers.isEmpty {
                                Label(extracted.travelers.joined(separator: " & "), systemImage: "person.2.fill")
                            }
                            if let number = extracted.bookingNumber {
                                Label("Buchungsnummer \(number)", systemImage: "number").textSelection(.enabled)
                            }
                        }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.ink)
                    }
                    ForEach(extracted.notes, id: \.self) { note in
                        Label(note, systemImage: "info.circle").font(.footnote).foregroundStyle(Stitch.inkSoft)
                    }
                    if extracted.isEmpty {
                        Text("In diesem PDF haben wir keine Flüge oder Hoteldaten erkannt. Das Dokument bleibt trotzdem gespeichert.")
                            .font(.body).foregroundStyle(Stitch.inkSoft)
                    }
                }
                .padding(Stitch.Space.page)
            }
            .background(LinenBackground())
            .safeAreaInset(edge: .bottom) {
                if !extracted.isEmpty {
                    Button(applying ? "Wird übernommen …" : "Übernehmen") {
                        applying = true
                        Task {
                            await store.applyExtraction(extracted)
                            applied += 1
                            dismiss()
                        }
                    }
                    .buttonStyle(StitchButton(primary: true))
                    .disabled(applying)
                    .padding(Stitch.Space.page)
                    .background(.bar)
                }
            }
            .navigationTitle("Aus dem PDF gelesen").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Nicht jetzt") { dismiss() } } }
            .sensoryFeedback(.success, trigger: applied)
        }
    }
}
