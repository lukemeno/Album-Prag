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
    @State private var library: TripLibrary = TripLibrary()
    @State private var invitation: InvitationRequest?
    @Environment(\.scenePhase) private var scenePhase
    /// Automatisierte und isolierte UI-Tests dürfen weder echte Daten synchronisieren noch Bilder nachladen.
    private let isUnitTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private let isIsolatedStoreTest = ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] != nil
    var body: some Scene {
        WindowGroup {
            AlbumExperienceRoot().environment(library).tint(Stitch.redFill)
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
                        ensureActiveTrip()
                        if let store = library.activeStore {
                            configureQA(store)
                            if nativeShareQA { store.publishShareContext(); store.drainShareQueue() }
                            else if !isUnitTestHost && !isIsolatedStoreTest { store.drainShareQueue() }
                            store.resumeAutomaticPhotoResolution()
                            if !isUnitTestHost && !isIsolatedStoreTest { Task { await store.sync(); await store.refreshPlaceImages(automatic: true) } }
                        }
                    } else if phase == .inactive || phase == .background {
                        library.activeStore?.pauseAutomaticPhotoResolution()
                        library.refreshActiveEntry()
                    }
                }
                .onChange(of: library.activeID) { _, _ in
                    guard let store = library.activeStore else { return }
                    configureQA(store)
                    store.resumeAutomaticPhotoResolution()
                    if !isUnitTestHost && !isIsolatedStoreTest {
                        Task {
                            await store.sync()
                            await store.refreshPlaceImages(automatic: true)
                        }
                    }
                }
                .onOpenURL { url in
                    if url.isFileURL && url.pathExtension.lowercased() == "pdf" {
                        do {
                            guard let store = library.activeStore else { library.error = "Öffne zuerst eine Reise."; return }
                            let id = UUID().uuidString
                            try store.importPDF(url, id: id)
                            if let doc = store.data.documents.first(where: { $0.id == id }) {
                                let extracted = store.extraction(from: doc)
                                if !extracted.isEmpty { store.pendingExtraction = extracted }
                            }
                        } catch { library.error = error.localizedDescription }
                    } else if InvitationLink.token(from: url) != nil {
                        let request = InvitationRequest(sender: nil) {
                            do {
                                _ = try await library.joinInvitation(url)
                                return nil
                            } catch {
                                return "Das hat nicht geklappt. \(error.localizedDescription)"
                            }
                        }
                        if library.activeStore != nil { invitation = request }
                        else {
                            Task {
                                if let message = await request.join() { library.error = message }
                            }
                        }
                    }
                }
                .fullScreenCover(item: $invitation) { request in
                    if let store = library.activeStore {
                        InvitationMoment(request: request, onDone: { invitation = nil }).environment(store)
                    } else {
                        ProgressView().task { invitation = nil }
                    }
                }
                .task {
                    ensureActiveTrip()
                    guard let store = library.activeStore else { return }
                    configureQA(store)
#if DEBUG
                    if invitation == nil, let mode = ProcessInfo.processInfo.environment["ALBUM_DEMO_INVITE"] {
                        invitation = .demo(mode, sender: ProcessInfo.processInfo.environment["ALBUM_DEMO_SENDER"])
                    }
#endif
                    if nativeShareQA {
                        if ShareInbox().containerURL() == nil { library.error = "Native-Share-QA benötigt die App-Group group.de.privatealbum.prague." }
                        else { store.publishShareContext(); store.drainShareQueue() }
                    } else if !isUnitTestHost && !isIsolatedStoreTest { store.drainShareQueue() }
                    store.resumeAutomaticPhotoResolution()
                    if !isUnitTestHost && !isIsolatedStoreTest { await store.sync(); await store.refreshPlaceImages(automatic: true) }
                }
                .alert("Album", isPresented: Binding(get: { presentedError != nil }, set: { if !$0 { clearPresentedError() } })) {
                    Button("OK") { clearPresentedError() }
                } message: { Text(presentedError ?? "") }
        }
    }

    private func ensureActiveTrip() {
        guard library.activeStore == nil else { return }
        if library.restoreLastOpenedTrip() { return }
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard environment["ALBUM_TEST_STORE"] != nil else { return }
        let fixtureFlag = ["ALBUM_GLOBAL_IMAGE_QA", "ALBUM_AUTO_PHOTO_QA", "ALBUM_AUTO_PHOTO_LIVE_QA", "ALBUM_LIVE_IMAGE_QA", "ALBUM_DISCOVERY_QA", "ALBUM_DISCOVERY_LIVE_QA", "ALBUM_LEGACY_HOME_QA"].contains { environment[$0] == "1" }
        guard fixtureFlag, let id = library.createBlankTrip(title: "QA-Reise", destination: "Prag") else { return }
        _ = library.open(id)
        #endif
    }

    private var presentedError: String? {
        library.error ?? library.activeStore?.error
    }

    private func clearPresentedError() {
        library.error = nil
        library.activeStore?.error = nil
    }

    #if DEBUG
    private func configureQA(_ store: AlbumStore) {
        let environment = ProcessInfo.processInfo.environment
        let root = store.root
        // The card-first shell is an explicit compatibility fixture for the
        // older native-port UI tests only. It is never created in a normal
        // install or by a user-created blank trip.
        let hasSpecializedFixture = ["ALBUM_GLOBAL_IMAGE_QA", "ALBUM_AUTO_PHOTO_QA", "ALBUM_AUTO_PHOTO_LIVE_QA", "ALBUM_LIVE_IMAGE_QA", "ALBUM_DISCOVERY_QA", "ALBUM_DISCOVERY_LIVE_QA"].contains { environment[$0] == "1" }
        if environment["ALBUM_LEGACY_HOME_QA"] == "1" && !hasSpecializedFixture && store.places.isEmpty {
            var trip = TripInfo.legacyPrague()
            trip.title = "Prag"
            _ = store.updateTrip(trip)
            store.data.places = Place.examples
            _ = store.persist()
        }
        if environment["ALBUM_GLOBAL_IMAGE_QA"] == "1" && store.places.isEmpty {
            var trip = store.data.trip; trip.title = "Japan"; trip.destination = "Tokyo"; _ = store.updateTrip(trip)
            store.data.places = [
                Place(id: "global-tokyo", title: "Tokyo Tower", category: "Sehenswert"),
                Place(id: "global-cafe", title: "Café Central", category: "Essen & Trinken"),
                Place(id: "global-ramen", title: "Ramen", category: "Essen & Trinken"),
                Place(id: "global-retry", title: "Tokyo Skytree", category: "Sehenswert")
            ]; _ = store.persist()
        }
        if environment["ALBUM_GLOBAL_IMAGE_QA"] == "1" {
            var retryCount = 0
            store.placeResolutionResolver = { place, _ in
                let tokyo = PlaceResolutionCandidate(id: "qa-tokyo", title: place.title, address: "Tokyo, Japan", latitude: 35.6586, longitude: 139.7454, category: place.category)
                if place.id == "global-cafe" { return .needsReview([tokyo, PlaceResolutionCandidate(id: "qa-cafe-2", title: place.title, address: "Chiyoda, Tokyo, Japan", latitude: 35.68, longitude: 139.76, category: place.category)], .ambiguous) }
                if place.id == "global-ramen" { return .needsReview([], .genericConcept) }
                if place.id == "global-retry" { retryCount += 1; return retryCount == 1 ? .failed(retryable: true) : .resolved(tokyo) }
                return .resolved(tokyo)
            }
            store.placeImageSearchResolver = { place, _ in
                let fixtureURL = root.appendingPathComponent("qa-photo.png")
                if !FileManager.default.fileExists(atPath: fixtureURL.path), let bytes = UIImage(systemName: "photo")?.pngData() { try bytes.write(to: fixtureURL, options: .atomic) }
                return PlaceImageSearchResult(image: PlaceImage(imageURL: fixtureURL, sourceURL: URL(string: "https://commons.wikimedia.org/")!, credit: "Lokale Testaufnahme", provider: .wikimedia, licenseName: "CC0", licenseURL: nil, providerPlaceID: "qa-local", confidence: .verified, caption: place.title), candidates: [], selectionVersion: PlaceImageService.ranking)
            }
        }
        if environment["ALBUM_AUTO_PHOTO_QA"] == "1" {
            store.placeResolutionResolver = { place, _ in
                .resolved(PlaceResolutionCandidate(id: "auto-photo-qa", title: place.title, address: "Tokyo, Japan", latitude: 35.6586, longitude: 139.7454, category: place.category))
            }
            store.placeImageSearchResolver = { place, _ in
                let fixtureURL = root.appendingPathComponent("auto-photo-qa.png")
                if !FileManager.default.fileExists(atPath: fixtureURL.path), let bytes = UIImage(systemName: "photo.fill")?.pngData() { try bytes.write(to: fixtureURL, options: .atomic) }
                return PlaceImageSearchResult(image: PlaceImage(imageURL: fixtureURL, sourceURL: URL(string: "https://commons.wikimedia.org/wiki/Category:Tokyo_Tower")!, credit: "Automatisches Testfoto", provider: .wikimedia, licenseName: "CC0", licenseURL: nil, providerPlaceID: "auto-photo-qa", confidence: .verified, caption: place.title), candidates: [], selectionVersion: PlaceImageService.ranking)
            }
        }
        if environment["ALBUM_AUTO_PHOTO_LIVE_QA"] == "1" {
            store.data.trip.destination = "Prag"; _ = store.persist()
            store.placeResolutionResolver = { place, context in await PlaceResolver.resolve(place: place, context: context) }
            store.placeImageSearchResolver = { _, _ in PlaceImageSearchResult(image: nil, candidates: [], selectionVersion: PlaceImageService.ranking) }
            store.placeSourcePreviewResolver = { place, _ in await PlaceImageService.sourcePreview(for: place, allowNetworkFallback: true) }
        }
        if environment["ALBUM_LIVE_IMAGE_QA"] == "1" {
            if store.places.isEmpty {
                var trip = store.data.trip
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
        if environment["ALBUM_DISCOVERY_QA"] == "1" {
            if store.places.isEmpty {
                var trip = store.data.trip; trip.title = "Prag"; trip.destination = "Prag"; _ = store.updateTrip(trip)
                store.data.places = [Place(id: "existing-bridge", title: "Karlsbrücke", sourceURL: "https://www.wikidata.org/wiki/Q204871", category: "Sehenswert", lat: 50.0865, lng: 14.4114), Place(id: "removed-cathedral", title: "Veitsdom", sourceURL: "https://www.wikidata.org/wiki/Q5949", category: "Sehenswert", lat: 50.0909, lng: 14.4005, deleted: true)]
                _ = store.persist()
            }
            store.discoveryServiceOverride = DiscoveryQAFixtureService()
        }
    }
    #else
    private func configureQA(_ store: AlbumStore) {}
    #endif
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
