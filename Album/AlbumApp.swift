import SwiftUI
import UIKit

@main struct AlbumApp: App {
#if DEBUG && targetEnvironment(simulator)
    private let nativeShareQA = ProcessInfo.processInfo.environment["ALBUM_QA_NATIVE_SHARE"] == "1"
#else
    private let nativeShareQA = false
#endif

    init() {
        // Ortsfotos bleiben zwischengespeichert, damit Karte und Liste auch mit schwachem Netz in Prag Bilder zeigen.
        URLCache.shared = URLCache(memoryCapacity: 40_000_000, diskCapacity: 250_000_000)
        // Große und kleine Leistentitel in Fraunces wie „Album“ und „Reiseplan“, nicht in der Systemschrift.
        // iOS 26 liest große Titel nur aus einer UINavigationBarAppearance; der Hintergrund bleibt der des Systems.
        if let large = UIFont(name: "Fraunces-SemiBold", size: 34), let inline = UIFont(name: "Fraunces-SemiBold", size: 18) {
            let ink = UIColor(Stitch.ink)
            let largeAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large), .foregroundColor: ink
            ]
            let inlineAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: inline), .foregroundColor: ink
            ]
            let appearance = UINavigationBarAppearance()
            appearance.largeTitleTextAttributes = largeAttributes
            appearance.titleTextAttributes = inlineAttributes
            // Am oberen Rand wie üblich ohne Fläche, beim Scrollen die Systemfläche.
            let edge = UINavigationBarAppearance()
            edge.configureWithTransparentBackground()
            edge.largeTitleTextAttributes = largeAttributes
            edge.titleTextAttributes = inlineAttributes
            let bar = UINavigationBar.appearance()
            bar.standardAppearance = appearance
            bar.compactAppearance = appearance
            bar.scrollEdgeAppearance = edge
            bar.largeTitleTextAttributes = largeAttributes
            bar.titleTextAttributes = inlineAttributes
        }
    }
    @State private var store: AlbumStore = {
        #if DEBUG
        if let name = ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] {
            let safeName = String(name.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
            guard !safeName.isEmpty else { return AlbumStore() }
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let root = support.appendingPathComponent("AlbumUITests", isDirectory: true)
                .appendingPathComponent(safeName, isDirectory: true)
            return AlbumStore(root: root)
        }
        #endif
        return AlbumStore()
    }()
    @Environment(\.scenePhase) private var scenePhase
    /// Ein geöffneter Einladungslink zeigt erst den Moment mit der Fahrkarte; der Beitritt startet beim Einlösen.
    @State private var invitation: InvitationRequest?
    /// Automatisierte und isolierte UI-Tests dürfen weder echte Daten synchronisieren noch Bilder nachladen.
    private let isUnitTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private let isIsolatedStoreTest = ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] != nil
    var body: some Scene {
        WindowGroup {
            AlbumRoot().environment(store).tint(Stitch.redFill)
                #if DEBUG
                // Screen-Tour: Dunkelmodus erzwingen, ohne die Simulator-Einstellung zu ändern (nur isolierte Teststores).
                .preferredColorScheme(ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] != nil
                                      && ProcessInfo.processInfo.environment["ALBUM_COLOR_SCHEME"] == "dark" ? .dark : nil)
                .transformEnvironment(\._accessibilityReduceMotion) { value in
                    let isolatedStore = ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] != nil
                    if isolatedStore && ProcessInfo.processInfo.environment["ALBUM_QA_REDUCE_MOTION"] == "1" {
                        value = true
                    }
                }
                #endif
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        if nativeShareQA {
                            store.publishShareContext()
                            store.drainShareQueue()
                        } else if !isUnitTestHost && !isIsolatedStoreTest {
                            store.drainShareQueue()
                        }
                        if !isUnitTestHost && !isIsolatedStoreTest {
                            Task { await store.sync(); await store.locateUnplacedPlaces(); await store.refreshPlaceImages() }
                        }
                    }
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
                .task {
                    if nativeShareQA {
                        if ShareInbox().containerURL() == nil {
                            store.error = "Native-Share-QA benötigt die App-Group group.de.privatealbum.prague."
                        } else {
                            store.publishShareContext()
                            store.drainShareQueue()
                        }
                    } else if !isUnitTestHost && !isIsolatedStoreTest {
                        store.drainShareQueue()
                    }
                    if !isUnitTestHost && !isIsolatedStoreTest {
                        await store.sync(); await store.locateUnplacedPlaces(); await store.refreshPlaceImages()
                    }
                }
                .alert("Album", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("OK") { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
    }
}
