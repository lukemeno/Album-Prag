import SwiftUI

/// Ein geöffneter Einladungslink: wer eingeladen hat (wenn bekannt) und was beim Einlösen passiert.
/// `join` liefert nil bei Erfolg, sonst den Fehlertext.
struct InvitationRequest: Identifiable {
    let id = UUID()
    var sender: String?
    var join: @MainActor () async -> String?

    #if DEBUG
    /// Simulierter Beitritt für Tests (`ALBUM_DEMO_INVITE=ok|fail|failthenok`). Ruft nie Supabase auf.
    static func demo(_ mode: String, sender: String?) -> InvitationRequest {
        var attempts = 0
        return InvitationRequest(sender: sender) {
            attempts += 1
            try? await Task.sleep(for: .seconds(1.2))
            let fails = mode == "fail" || (mode == "failthenok" && attempts == 1)
            return fails ? "Das hat nicht geklappt. Dieser Einladungslink ist ungültig oder nicht mehr verfügbar." : nil
        }
    }
    #endif
}

/// Vollbild-Moment beim Einlösen: Eine gestickte Fahrkarte wird nach oben in den Schlitz gezogen (oder der Knopf getippt).
/// Erst ab der Schwelle beginnt der Beitritt; danach druckt der Schlitz einen Zettel mit dem Ergebnis.
struct InvitationMoment: View {
    let request: InvitationRequest
    var onDone: () -> Void
    @Environment(AlbumStore.self) private var store
    @State private var busy = false

    var body: some View {
        SlotScene(labels: SlotLabels(flap: "Album", cardLabel: ticketLabel, cardHint: "Nach oben ziehen zum Einlösen",
                                     action: "Einlösen", cardID: "Einladungs-Karte", buttonID: "Einladungs-Knopf",
                                     idle: "Einladung einlösen", working: "Album wird geöffnet …", done: "Album ansehen",
                                     announcement: "Einladung eingelöst. Album geöffnet. \(summary)"),
                  commit: {
                      busy = true
                      defer { busy = false }
                      return await request.join()
                  },
                  keepsCardWhenReduced: true, onFinished: onDone) {
            InvitationTicket(sender: request.sender)
        } receipt: {
            receipt
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onDone) { Image(systemName: "xmark") }
                .buttonStyle(HeaderIconButton())
                .disabled(busy)
                .opacity(busy ? 0 : 1)
                .padding(Stitch.Space.page)
                .accessibilityLabel("Schließen")
        }
    }

    private var ticketLabel: String {
        ["Einladung nach Prag, 4. bis 9. Oktober", request.sender.map { "von \($0)" }].compactMap { $0 }.joined(separator: ", ")
    }

    /// „13 Orte · 5 Tage“ aus den geladenen Daten; Tage nur, wenn schon welche geplant sind.
    private var summary: String {
        let places = store.places.count
        let days = Set(store.places.compactMap(\.day)).count
        var parts = [places == 1 ? "1 Ort" : "\(places) Orte"]
        if days > 0 { parts.append(days == 1 ? "1 Tag" : "\(days) Tage") }
        return parts.joined(separator: " · ")
    }

    private var receipt: some View {
        VStack(spacing: Stitch.Space.xxs) {
            Text("Album geöffnet").font(.headline).foregroundStyle(Stitch.ink)
            Text(summary).font(.subheadline.monospacedDigit()).foregroundStyle(Stitch.inkSoft)
        }
        .padding(.horizontal, Stitch.Space.l).padding(.vertical, Stitch.Space.m)
        .frame(width: 212)
        .background(Stitch.card)
        .overlay(alignment: .topLeading) { TackStitch().offset(x: Stitch.Space.xs, y: Stitch.Space.xs) }
        .overlay(alignment: .topTrailing) { TackStitch().offset(x: -Stitch.Space.xs, y: Stitch.Space.xs) }
        .stitchElevation(.pinned)
        .rotationEffect(.degrees(-1.5))
        .accessibilityElement(children: .combine)
    }
}

/// Die Fahrkarte: gesticktes „Prag“, Reisedaten, Perforation. Papier ist eckig und mit einem Heftstich am Stoff.
struct InvitationTicket: View {
    var sender: String?
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            HStack {
                Text("Einladung").font(.footnote.weight(.bold)).foregroundStyle(Stitch.red)
                Spacer()
                Image(systemName: "airplane").font(.body.weight(.semibold)).foregroundStyle(Stitch.red)
            }
            StitchedText(text: "Prag", rows: 22, cell: 3)
            PerforationLine()
            VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                Text("Prag · 4.–9. Oktober").font(.headline).foregroundStyle(Stitch.ink)
                if let sender {
                    Text("Von \(sender)").font(.footnote).foregroundStyle(Stitch.inkSoft)
                }
            }
        }
        .padding(Stitch.Space.m)
        .frame(width: 236, alignment: .leading)
        .background(Stitch.card)
        .overlay(alignment: .top) { TackStitch(color: Stitch.cobalt).offset(y: -Stitch.Space.xxs) }
        .stitchElevation(.floating)
    }
}
