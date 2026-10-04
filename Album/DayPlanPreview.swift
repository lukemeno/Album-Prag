import SwiftUI

/// Vorschlag ansehen, bevor er übernommen wird: Tage mit Orten in Reihenfolge, ungefähre Tageszeit, Hinweise.
struct DayPlanPreview: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var keepAssigned = true
    @State private var proposal: DayPlanProposal?
    @State private var applied = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Schon geplante Orte behalten", isOn: $keepAssigned)
                } footer: {
                    Text("Nahe Orte landen am selben Tag, jeder Tag ist eine Runde ab dem Hotel. Öffnungszeiten stammen aus OpenStreetMap.")
                }
                .listRowBackground(Stitch.card)

                if let proposal {
                    ForEach(DayPlanGenerator.days, id: \.self) { day in
                        let stops = proposal.days[day] ?? []
                        Section(TripDates.dayTitle(day)) {
                            if stops.isEmpty {
                                Text("Frei").foregroundStyle(Stitch.inkSoft)
                            }
                            ForEach(stops) { stop in
                                HStack(spacing: Stitch.Space.s) {
                                    AlbumPhoto(asset: stop.place.image, root: store.root, thumbnailWidth: 120).frame(width: Stitch.Size.thumb, height: Stitch.Size.thumb)
                                        .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                                        Text(stop.place.title).font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
                                        Text(stop.note.map { "\(stop.slot) · \($0)" } ?? stop.slot)
                                            .font(.footnote).foregroundStyle(stop.note == nil ? Stitch.inkSoft : Stitch.red)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .listRowBackground(Stitch.card)
                    }
                    if !proposal.leftOver.isEmpty {
                        Section("Passt nicht mehr rein") {
                            ForEach(proposal.leftOver) { Text($0.title).foregroundStyle(Stitch.ink) }
                        }
                        .listRowBackground(Stitch.card)
                    }
                } else {
                    Section {
                        Label { Text("Öffnungszeiten werden geprüft …") } icon: { ProgressView() }
                            .foregroundStyle(Stitch.inkSoft)
                    }
                    .listRowBackground(Stitch.card)
                }
            }
            .accessibilityIdentifier("day-plan-preview-list")
            .scrollContentBackground(.hidden)
            .background(PaperBackground())
            .navigationTitle("Vorschlag").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        guard let proposal, store.apply(proposal) else { return }
                        applied += 1
                        dismiss()
                    }
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
}
