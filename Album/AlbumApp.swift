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
        URLCache.shared = URLCache(memoryCapacity: 20_000_000, diskCapacity: 100_000_000)
    }
    @State private var store: AlbumStore = {
        #if DEBUG
        if let name = ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] {
            let safeName = String(name.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
            guard !safeName.isEmpty else { return AlbumStore() }
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let root = support.appendingPathComponent("AlbumUITests", isDirectory: true)
                .appendingPathComponent(safeName, isDirectory: true)
            let existed = FileManager.default.fileExists(atPath: root.appendingPathComponent("album.json").path)
            let store = AlbumStore(root: root)
            if ProcessInfo.processInfo.environment["ALBUM_GLOBAL_IMAGE_QA"] == "1" {
                if !existed {
                    var trip = TripInfo()
                    trip.title = "Japan"
                    trip.destination = "Tokyo"
                    _ = store.updateTrip(trip)
                    store.data.places = [
                        Place(id: "global-tokyo", title: "Tokyo Tower", category: "Sehenswert"),
                        Place(id: "global-cafe", title: "Café Central", category: "Essen & Trinken"),
                        Place(id: "global-ramen", title: "Ramen", category: "Essen & Trinken"),
                        Place(id: "global-retry", title: "Tokyo Skytree", category: "Sehenswert")
                    ]
                    _ = store.persist()
                }
                var retryCount = 0
                store.placeResolutionResolver = { place, _ in
                    let tokyo = PlaceResolutionCandidate(id: "qa-tokyo", title: place.title,
                        address: "Tokyo, Japan", latitude: 35.6586, longitude: 139.7454, category: place.category)
                    switch place.id {
                    case "global-cafe":
                        let second = PlaceResolutionCandidate(id: "qa-cafe-2", title: "Café Central",
                            address: "Chiyoda, Tokyo, Japan", latitude: 35.68, longitude: 139.76, category: place.category)
                        return .needsReview([tokyo, second], .ambiguous)
                    case "global-ramen": return .needsReview([], .genericConcept)
                    case "global-retry":
                        retryCount += 1
                        if retryCount == 1 { return .failed(retryable: true) }
                        return .resolved(tokyo)
                    default: return .resolved(tokyo)
                    }
                }
                store.placeImageSearchResolver = { place, _ in
                    let fixtureURL = root.appendingPathComponent("qa-photo.png")
                    if !FileManager.default.fileExists(atPath: fixtureURL.path),
                       let bytes = UIImage(systemName: "photo")?.pngData() {
                        try bytes.write(to: fixtureURL)
                    }
                    let image = PlaceImage(imageURL: fixtureURL,
                        sourceURL: URL(string: "https://commons.wikimedia.org/")!, credit: "Lokale Testaufnahme",
                        provider: .wikimedia, licenseName: "CC0", licenseURL: nil,
                        providerPlaceID: "qa-local", confidence: .verified, caption: place.title)
                    return PlaceImageSearchResult(image: image, candidates: [], selectionVersion: PlaceImageService.ranking)
                }
            }
            if ProcessInfo.processInfo.environment["ALBUM_AUTO_PHOTO_QA"] == "1" {
                store.placeResolutionResolver = { place, _ in
                    let candidate = PlaceResolutionCandidate(id: "auto-photo-qa", title: place.title,
                        address: "Tokyo, Japan", latitude: 35.6586, longitude: 139.7454, category: place.category)
                    return .resolved(candidate)
                }
                store.placeImageSearchResolver = { place, _ in
                    let fixtureURL = root.appendingPathComponent("auto-photo-qa.png")
                    if !FileManager.default.fileExists(atPath: fixtureURL.path),
                       let bytes = UIImage(systemName: "photo.fill")?.pngData() {
                        try bytes.write(to: fixtureURL, options: .atomic)
                    }
                    let image = PlaceImage(imageURL: fixtureURL,
                        sourceURL: URL(string: "https://commons.wikimedia.org/wiki/Category:Tokyo_Tower")!,
                        credit: "Automatisches Testfoto", provider: .wikimedia,
                        licenseName: "CC0", licenseURL: nil, providerPlaceID: "auto-photo-qa",
                        confidence: .verified, caption: place.title)
                    return PlaceImageSearchResult(image: image, candidates: [], selectionVersion: PlaceImageService.ranking)
                }
            }
            if ProcessInfo.processInfo.environment["ALBUM_LIVE_IMAGE_QA"] == "1" {
                if !existed {
                    var trip = TripInfo()
                    trip.title = "Japan · Bildtest"
                    trip.destination = "Tokyo, Japan"
                    _ = store.updateTrip(trip)
                    store.data.places = [
                        Place(id: "live-tokyo", title: "Tokyo Tower", category: "Sehenswert", lat: 35.65858, lng: 139.74543),
                        Place(id: "live-sensoji", title: "Sensō-ji", category: "Sehenswert", lat: 35.7148, lng: 139.7967),
                        Place(id: "live-skytree", title: "Tokyo Skytree", category: "Sehenswert", lat: 35.7101, lng: 139.8107)
                    ]
                    _ = store.persist()
                }
                store.placeImageSearchResolver = { place, context in
                    try await PlaceImageService.search(for: place, region: context.name,
                                                       languageCode: context.preferredLanguageCode)
                }
            }
            if ProcessInfo.processInfo.environment["ALBUM_DISCOVERY_QA"] == "1"
                || ProcessInfo.processInfo.environment["ALBUM_DISCOVERY_LIVE_QA"] == "1" {
                let fixture = ProcessInfo.processInfo.environment["ALBUM_DISCOVERY_QA"] == "1"
                if !existed {
                    var trip = TripInfo()
                    trip.title = "Prag"
                    trip.destination = "Prag"
                    _ = store.updateTrip(trip)
                    store.data.places = fixture ? [
                        Place(id: "existing-bridge", title: "Karlsbrücke", sourceURL: "https://www.wikidata.org/wiki/Q204871",
                              category: "Sehenswert", lat: 50.0865, lng: 14.4114),
                        Place(id: "removed-cathedral", title: "Veitsdom", sourceURL: "https://www.wikidata.org/wiki/Q5949",
                              category: "Sehenswert", lat: 50.0909, lng: 14.4005, deleted: true)
                    ] : []
                    _ = store.persist()
                }
                if fixture { store.discoveryServiceOverride = DiscoveryQAFixtureService() }
            }
            return store
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
            AlbumExperienceRoot().environment(store).tint(Stitch.redFill)
                #if DEBUG
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
                        store.resumeAutomaticPhotoResolution()
                        if !isUnitTestHost && !isIsolatedStoreTest { Task { await store.sync(); await store.refreshPlaceImages(automatic: true) } }
                    } else if phase == .inactive || phase == .background {
                        store.pauseAutomaticPhotoResolution()
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
                    store.resumeAutomaticPhotoResolution()
                    if !isUnitTestHost && !isIsolatedStoreTest { await store.sync(); await store.refreshPlaceImages(automatic: true) }
                }
                .alert("Album", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("OK") { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
    }
}

#if DEBUG
private struct DiscoveryQAFixtureService: DiscoveryServiceProtocol {
    private var city: DiscoveryCity {
        DiscoveryCity(qid: "Q1085", name: "Prag", country: "Tschechien", latitude: 50.087, longitude: 14.421,
                      sourceURL: URL(string: "https://www.wikidata.org/wiki/Q1085")!)
    }
    func searchCities(query: String, languageCode: String) async throws -> [DiscoveryCity] { [city] }
    func catalog(cityQID: String, languageCode: String) async throws -> DiscoveryCatalog {
        let values: [(String, String, Double, Double, Int)] = [
            ("Q193369", "Prager Burg", 50.0908, 14.4006, 66),
            ("Q204871", "Karlsbrücke", 50.0865, 14.4114, 62),
            ("Q5949", "Veitsdom", 50.0909, 14.4005, 60)
        ]
        let items = values.map { qid, name, latitude, longitude, count in
            DiscoveryItem(qid: qid, name: name, description: "Lokaler Testvorschlag", latitude: latitude, longitude: longitude,
                          interests: [.architecture, .history], wikipediaLanguageCount: count,
                          sourceURL: URL(string: "https://www.wikidata.org/wiki/\(qid)")!, distanceMeters: 1000, image: nil)
        }
        let now = Date()
        return DiscoveryCatalog(protocolVersion: 1, catalogVersion: 1, rankingVersion: 1, city: city,
                                languageCode: "de", coverage: DiscoveryCoverage(kind: .radius, radiusMeters: 25000, label: "25 km um Prag"),
                                items: items, fetchedAt: now, expiresAt: now.addingTimeInterval(7 * 86400),
                                staleUntil: now.addingTimeInterval(30 * 86400), cacheStatus: .fresh)
    }
}
#endif
