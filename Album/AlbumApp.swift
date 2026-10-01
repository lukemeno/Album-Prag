import SwiftUI

@main struct AlbumApp: App {
    init() {
        // Ortsfotos bleiben zwischengespeichert, damit Karte und Liste auch mit schwachem Netz in Prag Bilder zeigen.
        URLCache.shared = URLCache(memoryCapacity: 40_000_000, diskCapacity: 250_000_000)
    }
    @State private var store: AlbumStore = {
        #if DEBUG
        if let name = ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] {
            return AlbumStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(name))
        }
        #endif
        return AlbumStore()
    }()
    @Environment(\.scenePhase) private var scenePhase
    /// Ein geöffneter Einladungslink zeigt erst den Moment mit der Fahrkarte; der Beitritt startet beim Einlösen.
    @State private var invitation: InvitationRequest?
    /// Als Test-Host für Unit-Tests nie mit der echten Datenbank abgleichen.
    private let isUnitTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    var body: some Scene {
        WindowGroup {
            AlbumRoot().environment(store).tint(Stitch.redFill)
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
                        invitation = InvitationRequest(sender: nil) {
                            do { try await store.joinSharedTrip(url: url); return nil }
                            catch { return "Das hat nicht geklappt. \(error.localizedDescription)" }
                        }
                    }
                }
                .fullScreenCover(item: $invitation) { request in
                    InvitationMoment(request: request) { invitation = nil }.environment(store)
                }
                #if DEBUG
                .onAppear {
                    if let mode = ProcessInfo.processInfo.environment["ALBUM_DEMO_INVITE"], invitation == nil {
                        invitation = .demo(mode, sender: ProcessInfo.processInfo.environment["ALBUM_DEMO_SENDER"])
                    }
                }
                #endif
                .task { if !isUnitTestHost { await store.sync(); await store.refreshPlaceImages() } }
                .alert("Album", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("OK") { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
    }
}
