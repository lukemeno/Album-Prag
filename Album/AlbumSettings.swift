import SwiftUI
import UIKit

struct AlbumSettings: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var preparing = false
    @State private var localError: String?
    @State private var linkCopied = false
    @FocusState private var nameFocused: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                    VStack(spacing: Stitch.Space.s) {
                        StitchedSymbol(name: "person.2.fill", rows: 20, cell: 4, color: Stitch.cobalt)
                        Text("Ideen, Orte und Unterlagen landen auf beiden iPhones. Der Link gilt nur für diese Reise.")
                            .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Stitch.inkSoft)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                        Text("Dein Name").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                        StitchTextField(placeholder: "Vorname", text: Binding(get: { store.myName }, set: { store.myName = $0 }),
                                        focused: $nameFocused) { nameFocused = false }
                            .textContentType(.givenName)
                    }

                    VStack(alignment: .leading, spacing: Stitch.Space.s) {
                        if let inviteURL = store.inviteURL {
                            ShareLink(item: inviteURL, subject: Text("Prag 2026")) {
                                Label("Einladung senden", systemImage: "paperplane.fill")
                            }.buttonStyle(StitchButton(primary: true))
                            Button {
                                UIPasteboard.general.url = inviteURL
                                linkCopied = true
                            } label: {
                                Label(linkCopied ? "Link kopiert" : "Link kopieren", systemImage: linkCopied ? "checkmark" : "doc.on.doc")
                            }.buttonStyle(StitchButton())
                        } else if !store.isShared {
                            Button(preparing ? "Wird eingerichtet …" : "Album teilen") {
                                preparing = true
                                Task {
                                    defer { preparing = false }
                                    do { _ = try await store.createSharedTrip() }
                                    catch { localError = error.localizedDescription }
                                }
                            }.buttonStyle(StitchButton(primary: true)).disabled(preparing || store.syncing)
                        }
                        if store.isShared {
                            Button(store.syncing ? "Wird abgeglichen …" : "Jetzt abgleichen") {
                                Task { await store.sync() }
                            }
                            .buttonStyle(StitchButton()).disabled(store.syncing || preparing)
                        }
                        Text(store.syncStatus).font(.footnote).foregroundStyle(Stitch.inkSoft)
                    }
                }
                .padding(Stitch.Space.page)
            }
            .background(LinenBackground())
            .navigationTitle("Geteiltes Album").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .alert("Teilen hat nicht geklappt", isPresented: Binding(get: { localError != nil }, set: { if !$0 { localError = nil } })) { Button("OK") { localError = nil } } message: { Text(localError ?? "") }
        }
    }
}
