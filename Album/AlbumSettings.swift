import SwiftUI

/// Gemeinsames Album: dein Name und genau ein Weg, die andere Person dazuzuholen.
/// Abgeglichen wird von selbst und per Herunterziehen auf „Reise“.
struct AlbumSettings: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var preparing = false
    @State private var localError: String?
    @FocusState private var nameFocused: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                    VStack(alignment: .leading, spacing: Stitch.Space.s) {
                        Postmark(top: "ALBUM", bottom: "FÜR ZWEI", size: 84)
                        Text(store.isShared ? "Ihr teilt dieses Album" : "Zu zweit planen")
                            .font(Stitch.Face.display(32, relativeTo: .largeTitle)).foregroundStyle(Stitch.ink)
                        Text("Ideen, Orte und Unterlagen landen auf beiden iPhones. Der Link gilt nur für diese Reise.")
                            .font(.body).foregroundStyle(Stitch.inkSoft)
                    }

                    VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                        Text("Dein Name").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                        StitchTextField(placeholder: "Vorname", text: Binding(get: { store.myName }, set: { store.myName = $0 }),
                                        focused: $nameFocused) { nameFocused = false }
                            .textContentType(.givenName)
                    }

                    VStack(alignment: .leading, spacing: Stitch.Space.s) {
                        if let inviteURL = store.inviteURL {
                            ShareLink(item: inviteURL, subject: Text("Prag 2026"), message: Text("Komm in unser Prag-Album")) {
                                Label("Einladung senden", systemImage: "paperplane")
                            }
                            .buttonStyle(StitchButton(primary: true))
                        } else if !store.isShared {
                            Button {
                                preparing = true
                                Task {
                                    defer { preparing = false }
                                    do { _ = try await store.createSharedTrip() }
                                    catch { localError = error.localizedDescription }
                                }
                            } label: {
                                if preparing { ProgressView().tint(Stitch.onAccent) } else { Label("Einladung erstellen", systemImage: "link") }
                            }
                            .buttonStyle(StitchButton(primary: true)).disabled(preparing || store.syncing)
                        }
                        Label(store.syncStatus, systemImage: store.isShared ? "arrow.triangle.2.circlepath" : "iphone")
                            .font(.footnote).foregroundStyle(Stitch.inkSoft)
                    }
                }
                .padding(Stitch.Space.page)
            }
            .background(PaperBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen", systemImage: "xmark") { dismiss() } } }
            .alert("Einladung hat nicht geklappt", isPresented: Binding(get: { localError != nil }, set: { if !$0 { localError = nil } })) { Button("OK") { localError = nil } } message: { Text(localError ?? "") }
        }
    }
}
