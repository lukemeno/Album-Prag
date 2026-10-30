import SwiftUI

/// Vorschlag ansehen, bevor er übernommen wird: Tage mit Orten in Reihenfolge, ungefähre Tageszeit, Hinweise.
struct DayPlanPreview: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var keepAssigned = true
    @State private var proposal: DayPlanProposal?
    @State private var applied = 0

    /// Vorschlag (Figma 18): Hinweis, Schalter „Bestehende Zuordnung behalten“ als Himmelblau-Fläche, Tage mit weißen Ortskarten,
    /// unten „Vorschlag übernehmen“. Die Navigationsleiste heißt weiter „Vorschlag“, „Übernehmen“ bleibt in der Leiste erreichbar.
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.m) {
                    Text("Vorschlag · Änderungen werden erst nach Übernahme gespeichert. Nahe Orte landen am selben Tag, jeder Tag ist eine Runde ab dem Hotel. Öffnungszeiten stammen aus OpenStreetMap.")
                        .font(Stitch.Face.subheadline).foregroundStyle(Stitch.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Toggle("Schon geplante Orte behalten", isOn: $keepAssigned)
                        .font(Stitch.Face.subheadline.weight(.semibold)).foregroundStyle(Stitch.ink)
                        .tint(Stitch.ink)
                        .padding(.horizontal, Stitch.Space.m).frame(minHeight: Stitch.Size.touch)
                        .background(Stitch.Stamp.sky, in: RoundedRectangle(cornerRadius: Stitch.Radius.small, style: .continuous))
                    if let proposal {
                        ForEach(store.tripCalendar.days) { day in
                            let stops = proposal.days[day] ?? []
                            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                                Text(store.tripCalendar.dayTitle(day)).font(Stitch.Face.section).foregroundStyle(Stitch.ink)
                                    .accessibilityAddTraits(.isHeader)
                                if stops.isEmpty {
                                    Text("Frei").font(Stitch.Face.subheadline).foregroundStyle(Stitch.inkSoft)
                                }
                                ForEach(stops) { stop in
                                    HStack(spacing: Stitch.Space.s) {
                                        AlbumPhoto(asset: stop.place.displayImage, root: store.root, thumbnailWidth: 120)
                                            .frame(width: 66, height: 66).background(stop.place.mat)
                                            .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.small, style: .continuous))
                                            .accessibilityHidden(true)
                                        VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                                            Text(stop.place.title).font(Stitch.Face.headline).foregroundStyle(Stitch.ink)
                                            Text(stop.note.map { "\(stop.slot) · \($0)" } ?? stop.slot)
                                                .font(Stitch.Face.footnote).foregroundStyle(stop.note == nil ? Stitch.inkSoft : Stitch.action)
                                                .monospacedDigit()
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(Stitch.Space.s)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
                                    .stitchElevation(.pinned)
                                    .accessibilityElement(children: .combine)
                                }
                            }
                        }
                        if !proposal.leftOver.isEmpty {
                            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                                Text(store.unresolvedLegacyPlaces.isEmpty && store.outOfRangePlannedPlaces.isEmpty
                                     ? "Passt nicht mehr rein" : "Nicht eingeplant")
                                    .font(Stitch.Face.section).foregroundStyle(Stitch.ink)
                                ForEach(proposal.leftOver) { Text($0.title).font(Stitch.Face.body).foregroundStyle(Stitch.ink) }
                            }
                        }
                    } else {
                        Label { Text("Öffnungszeiten werden geprüft …") } icon: { ProgressView() }
                            .foregroundStyle(Stitch.inkSoft)
                    }
                }
                .padding(.horizontal, Stitch.Space.page).padding(.bottom, Stitch.Space.l)
            }
            .accessibilityIdentifier("day-plan-preview-list")
            .scrollIndicators(.hidden)
            .background(PaperBackground())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("Vorschlag übernehmen") { applyProposal() }
                    .buttonStyle(InkPillButton())
                    .disabled(proposal == nil)
                    .accessibilityIdentifier("day-plan-apply")
                    .padding(.horizontal, Stitch.Space.page).padding(.vertical, Stitch.Space.xs)
                    .background { PaperBackground() }
            }
            .navigationTitle("Vorschlag").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") { applyProposal() }
                        .disabled(proposal == nil)
                }
            }
            .task(id: keepAssigned) {
                let requestedKeepAssigned = keepAssigned
                proposal = nil
                let nextProposal = await store.proposeDayPlan(keepAssigned: requestedKeepAssigned)
                guard !Task.isCancelled, requestedKeepAssigned == keepAssigned else { return }
                proposal = nextProposal
            }
            .sensoryFeedback(.success, trigger: applied)
        }
    }

    private func applyProposal() {
        guard let proposal, store.apply(proposal) else { return }
        applied += 1
        dismiss()
    }
}
