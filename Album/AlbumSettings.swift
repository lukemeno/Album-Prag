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
                VStack(alignment: .leading, spacing: 20) {
                    StitchedSymbol(name: "person.2.fill", rows: 20, cell: 4, color: Stitch.cobalt).frame(maxWidth: .infinity).padding(.vertical, 8)
                    Text("Geteiltes Album").font(AlbumStyle.display())
                    Text("Teilt Ideen, Orte und Reiseunterlagen zwischen euren iPhones. Der Einladungslink gilt nur für diese Reise.").font(AlbumStyle.body())
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dein Name").font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.muted)
                        TextField("Vorname", text: Binding(get: { store.myName }, set: { store.myName = $0 }))
                            .font(.title3).textContentType(.givenName)
                            .focused($nameFocused)
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                            .background(Stitch.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onTapGesture { nameFocused = true }
                    }
                    Text(store.syncStatus).font(AlbumStyle.body(13)).foregroundStyle(AlbumStyle.muted)
                    if let inviteURL = store.inviteURL {
                        ShareLink(item: inviteURL, subject: Text("Prag 2026")) {
                            Label("Einladung teilen", systemImage: "paperplane.fill")
                        }.buttonStyle(AlbumButton(primary: true))
                        Button {
                            UIPasteboard.general.url = inviteURL
                            linkCopied = true
                        } label: {
                            Label(linkCopied ? "Link kopiert" : "Link kopieren", systemImage: linkCopied ? "checkmark" : "doc.on.doc")
                        }.buttonStyle(AlbumButton())
                    } else if !store.isShared {
                        Button(preparing ? "Freigabe wird eingerichtet …" : "Album teilen") {
                            preparing = true
                            Task {
                                defer { preparing = false }
                                do { _ = try await store.createSharedTrip() }
                                catch { localError = error.localizedDescription }
                            }
                        }.buttonStyle(AlbumButton(primary: true)).disabled(preparing || store.syncing)
                    } else {
                        Label("Album ist verbunden", systemImage: "checkmark.seal.fill")
                            .font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.red)
                    }
                    if store.isShared {
                        Button(store.syncing ? "Wird abgeglichen …" : "Jetzt abgleichen") {
                            Task { await store.sync() }
                        }
                        .buttonStyle(AlbumButton()).disabled(store.syncing || preparing)
                    }
                    Text("Änderungen werden automatisch synchronisiert. Ohne Internet speichert die App sie auf dem Gerät und überträgt sie später.").font(AlbumStyle.body(13)).foregroundStyle(AlbumStyle.muted)
                    Divider()
                    Text("Aus Instagram & TikTok sammeln").font(AlbumStyle.serif(25))
                    Text("Kopiert einen Link in Instagram oder TikTok und fügt ihn über + ein. Oder einfach kopieren und die App öffnen: Album bietet den Link dann direkt an.").font(AlbumStyle.body())
                    Text("Privates Album · Prag 2026").font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.red)
                }.padding(20)
            }.background(LinenBackground()).navigationTitle("Geteiltes Album").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
                .alert("Freigabe fehlgeschlagen", isPresented: Binding(get: { localError != nil }, set: { if !$0 { localError = nil } })) { Button("OK") { localError = nil } } message: { Text(localError ?? "") }
        }
    }
}
