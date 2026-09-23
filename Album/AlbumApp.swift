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
    /// Als Test-Host für Unit-Tests nie mit der echten Datenbank abgleichen.
    private let isUnitTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    var body: some Scene {
        WindowGroup {
            AlbumRoot().environment(store).tint(AlbumStyle.red)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active && !isUnitTestHost { Task { await store.sync(); await store.refreshPlaceImages() } }
                }
                .onOpenURL { url in
                    if url.isFileURL && url.pathExtension.lowercased() == "pdf" {
                        do {
                            let id = UUID().uuidString
                            try store.importPDF(url, id: id)
                            if let doc = store.data.documents.first(where: { $0.id == id }) {
                                let extracted = store.extraction(from: doc)
                                if !extracted.isEmpty { store.pendingExtraction = extracted }
                            }
                        } catch { store.error = error.localizedDescription }
                    } else if InvitationLink.token(from: url) != nil {
                        Task {
                            do { try await store.joinSharedTrip(url: url) }
                            catch { store.error = error.localizedDescription }
                        }
                    }
                }
                .task { if !isUnitTestHost { await store.sync(); await store.refreshPlaceImages() } }
                .alert("Album", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("OK") { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
    }
}
