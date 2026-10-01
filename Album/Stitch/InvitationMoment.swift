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

/// Vollbild-Moment beim Einlösen: Eine Fahrkarte als Briefmarke wird nach oben in den Schlitz gezogen (oder der Knopf getippt).
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
            Text("Album geöffnet").font(Stitch.Face.place(22, relativeTo: .headline)).foregroundStyle(Stitch.ink)
            Text(summary).font(.subheadline.monospacedDigit()).foregroundStyle(Stitch.inkSoft)
        }
        .padding(.horizontal, Stitch.Space.l).padding(.vertical, Stitch.Space.m)
        .frame(width: 228)
        .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
        .overlay(alignment: .topTrailing) { Postmark(bottom: "4.–9.10.", size: 48).offset(x: 14, y: -18) }
        .stitchElevation(.pinned)
        .accessibilityElement(children: .combine)
    }
}

/// Die Fahrkarte als Briefmarke: „Prag“ in Fraunces, Reisedaten, Perforation, Poststempel.
struct InvitationTicket: View {
    var sender: String?
    var body: some View {
        StampFrame(mat: Stitch.Mat.sky, inset: 9, matWidth: 5, elevation: .floating) {
            VStack(alignment: .leading, spacing: Stitch.Space.s) {
                Image(systemName: "airplane").font(.body.weight(.semibold)).foregroundStyle(Stitch.red)
                Text("Prag").font(Stitch.Face.display(52, relativeTo: .largeTitle)).foregroundStyle(Stitch.ink)
                PerforationLine()
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text("4.–9. Oktober").font(Stitch.Face.place(22, relativeTo: .headline)).foregroundStyle(Stitch.ink)
                    Text(sender.map { "Einladung von \($0)" } ?? "Einladung").font(.footnote).foregroundStyle(Stitch.inkSoft)
                }
            }
            .padding(Stitch.Space.m)
            .frame(width: 220, alignment: .leading)
            .background(Stitch.card)
            .overlay(alignment: .topTrailing) { Postmark(bottom: "2026", size: 56).padding(Stitch.Space.s) }
        }
    }
}
