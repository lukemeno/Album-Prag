import SwiftUI
import UIKit

struct AlbumSettings: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var preparing = false
    @State private var localError: String?
    @State private var linkCopied = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image("imgSculpture").resizable().scaledToFit().frame(height: 120).frame(maxWidth: .infinity)
                    Text("Geteiltes Album").font(AlbumStyle.display())
                    Text("Teilt Ideen, Orte und Reiseunterlagen zwischen euren iPhones. Der Einladungslink gilt nur für diese Reise.").font(AlbumStyle.body())
                    Text(store.syncStatus).font(AlbumStyle.body(13)).foregroundStyle(AlbumStyle.muted)
                    if let inviteURL = store.inviteURL {
                        ShareLink(item: inviteURL, subject: Text("Prag 2026")) {
                            Label("EINLADUNG TEILEN", systemImage: "paperplane.fill")
                        }.buttonStyle(AlbumButton(primary: true))
                        Button {
                            UIPasteboard.general.url = inviteURL
                            linkCopied = true
                        } label: {
                            Label(linkCopied ? "LINK KOPIERT" : "LINK KOPIEREN", systemImage: linkCopied ? "checkmark" : "doc.on.doc")
                        }.buttonStyle(AlbumButton())
                    } else if !store.isShared {
                        Button(preparing ? "FREIGABE WIRD EINGERICHTET …" : "ALBUM TEILEN") {
                            preparing = true
                            Task {
                                defer { preparing = false }
                                do { _ = try await store.createSharedTrip() }
                                catch { localError = error.localizedDescription }
                            }
                        }.buttonStyle(AlbumButton(primary: true)).disabled(preparing || store.syncing)
                    } else {
                        Label("ALBUM IST VERBUNDEN", systemImage: "checkmark.seal.fill")
                            .font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.red)
                    }
                    if store.isShared {
                        Button(store.syncing ? "WIRD ABGEGLICHEN …" : "JETZT ABGLEICHEN") {
                            Task { await store.sync() }
                        }
                        .buttonStyle(AlbumButton()).disabled(store.syncing || preparing)
                    }
                    Text("Änderungen werden automatisch synchronisiert. Ohne Internet speichert die App sie auf dem Gerät und überträgt sie später.").font(AlbumStyle.body(13)).foregroundStyle(AlbumStyle.muted)
                    Divider()
                    Text("Aus Instagram & TikTok sammeln").font(AlbumStyle.serif(25))
                    Text("Kopiert einen Link in Instagram oder TikTok und fügt ihn in Album über + ein. Vor dem Frankieren bestätigt ihr den Ort.").font(AlbumStyle.body())
                    Text("Privates Album · Prag 2026").font(AlbumStyle.ticket).foregroundStyle(AlbumStyle.red)
                }.padding(20)
            }.background(AlbumStyle.paper).navigationTitle("Geteiltes Album").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
                .alert("Freigabe fehlgeschlagen", isPresented: Binding(get: { localError != nil }, set: { if !$0 { localError = nil } })) { Button("OK") { localError = nil } } message: { Text(localError ?? "") }
        }
    }
}
