import SwiftUI

@main struct AlbumApp: App {
    @State private var store: AlbumStore = {
        #if DEBUG
        if let name = ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] {
            return AlbumStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(name))
        }
        #endif
        return AlbumStore()
    }()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            AlbumRoot().environment(store).tint(AlbumStyle.red).preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await store.sync() } }
                }
                .onOpenURL { url in
                    if url.isFileURL && url.pathExtension.lowercased() == "pdf" {
                        do { try store.importPDF(url) } catch { store.error = error.localizedDescription }
                    } else if InvitationLink.token(from: url) != nil {
                        Task {
                            do { try await store.joinSharedTrip(url: url) }
                            catch { store.error = error.localizedDescription }
                        }
                    }
                }
                .task { await store.sync() }
                .alert("Album", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("OK") { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
    }
}
