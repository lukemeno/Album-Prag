import XCTest
@testable import Album

@MainActor final class DiscoveryTests: XCTestCase {
    private struct FixtureService: DiscoveryServiceProtocol {
        var city: DiscoveryCity
        var result: DiscoveryCatalog
        func searchCities(query: String, languageCode: String) async throws -> [DiscoveryCity] { [city] }
        func catalog(cityQID: String, languageCode: String) async throws -> DiscoveryCatalog { result }
    }
    @MainActor private final class RefreshTrackingService: DiscoveryServiceProtocol {
        let city: DiscoveryCity
        private(set) var catalogCalls = 0
        init(city: DiscoveryCity) { self.city = city }
        func searchCities(query: String, languageCode: String) async throws -> [DiscoveryCity] { [city] }
        func catalog(cityQID: String, languageCode: String) async throws -> DiscoveryCatalog {
            catalogCalls += 1
            throw DiscoveryServiceError.offline
        }
    }
    @MainActor private final class CitySearchService: DiscoveryServiceProtocol {
        var cities: [DiscoveryCity] = []
        func searchCities(query: String, languageCode: String) async throws -> [DiscoveryCity] { cities }
        func catalog(cityQID: String, languageCode: String) async throws -> DiscoveryCatalog { throw DiscoveryServiceError.offline }
    }

    private func fixture() -> (DiscoveryCity, DiscoveryCatalog, DiscoveryItem) {
        let city = DiscoveryCity(qid: "Q1085", name: "Prag", country: "Tschechien", latitude: 50.08, longitude: 14.43, sourceURL: URL(string: "https://www.wikidata.org/wiki/Q1085")!)
        let item = DiscoveryItem(qid: "Q123", name: "Prager Burg", description: "Burganlage", latitude: 50.09, longitude: 14.40,
                                 interests: [.history, .architecture], wikipediaLanguageCount: 24,
                                 sourceURL: URL(string: "https://www.wikidata.org/wiki/Q123")!, distanceMeters: 2400, image: nil)
        let catalog = DiscoveryCatalog(protocolVersion: 1, catalogVersion: 1, rankingVersion: 1, city: city, languageCode: "de",
                                       coverage: .init(kind: .radius, radiusMeters: 25_000, label: "25 km"), items: [item],
                                       fetchedAt: Date(timeIntervalSince1970: 1_800_000_000), expiresAt: Date(timeIntervalSince1970: 1_800_604_800),
                                       staleUntil: Date(timeIntervalSince1970: 1_803_000_000), cacheStatus: .fresh)
        return (city, catalog, item)
    }
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Discovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testInterestsAndCatalogPersistPerParticipant() async throws {
        let directory = try root(); let (city, catalog, _) = fixture()
        let first = AlbumStore(root: directory); first.data.places = []; first.collectionParticipantIDOverride = "person-a"
        let service = FixtureService(city: city, result: catalog)
        let session = DiscoverySession(store: first, service: service)
        session.saveInterests([.history, .architecture])
        await session.selectCity(city)
        XCTAssertEqual(session.filteredItems.map(\.qid), ["Q123"])

        let reopened = AlbumStore(root: directory); reopened.data.places = []; reopened.collectionParticipantIDOverride = "person-a"
        let restored = DiscoverySession(store: reopened, service: service)
        XCTAssertEqual(restored.interests, [.history, .architecture])
        XCTAssertEqual(restored.selectedCity, city)
        XCTAssertEqual(restored.catalog, catalog)

        reopened.collectionParticipantIDOverride = "person-b"
        let otherPerson = DiscoverySession(store: reopened, service: service)
        XCTAssertTrue(otherPerson.interests.isEmpty)
        XCTAssertNil(otherPerson.selectedCity)
    }

    func testDestinationChangeClearsCityAndCatalogButKeepsInterests() async throws {
        let (city, catalog, _) = fixture(); let store = AlbumStore(root: try root()); store.data.places = []
        store.discoveryServiceOverride = FixtureService(city: city, result: catalog)
        let session = store.discoverySession
        session.saveInterests([.natureParks])
        await session.selectCity(city)
        var trip = store.data.trip; trip.destination = "Tokyo"
        XCTAssertTrue(store.updateTrip(trip))
        XCTAssertEqual(session.interests, [.natureParks])
        XCTAssertNil(session.selectedCity); XCTAssertNil(session.catalog)
        XCTAssertEqual(session.phase, .needsCity)
    }

    func testAdoptionAddsUnplannedIdeaWithoutVotesOrPlanning() throws {
        let (_, _, item) = fixture(); let store = AlbumStore(root: try root()); store.data.places = []
        XCTAssertEqual(store.adoptDiscoveryItem(item), .added(placeID: "discovery-q123"))
        let place = try XCTUnwrap(store.data.places.first)
        XCTAssertEqual(place.sourceURL, "https://www.wikidata.org/wiki/Q123")
        XCTAssertEqual(place.approvals, []); XCTAssertEqual(place.passedBy, [])
        XCTAssertFalse(place.franked); XCTAssertFalse(place.deferred); XCTAssertFalse(place.deleted)
        XCTAssertNil(place.plannedDate); XCTAssertNil(place.day); XCTAssertNil(place.dayOrder); XCTAssertNil(place.planningUpdatedAt)
        XCTAssertEqual(store.adoptDiscoveryItem(item), .alreadyPresent(placeID: place.id, planned: false))
    }

    func testDeletedQIDIsNotSilentlyRevivedAndCanBeExplicitlyRestored() throws {
        let (_, _, item) = fixture(); let store = AlbumStore(root: try root());
        store.data.places = [Place(id: "discovery-q123", title: "Eigener Titel", note: "Notiz erhalten", sourceURL: item.sourceURL.absoluteString, category: "Idee", deleted: true)]
        XCTAssertEqual(store.adoptDiscoveryItem(item), .removed(placeID: "discovery-q123"))
        XCTAssertTrue(store.data.places[0].deleted)
        XCTAssertTrue(store.restoreDiscoveryPlace(id: "discovery-q123"))
        XCTAssertFalse(store.data.places[0].deleted)
        XCTAssertEqual(store.data.places[0].note, "Notiz erhalten")
    }

    func testSameNameOnlyDeduplicatesWithinOneHundredMeters() throws {
        let (_, _, item) = fixture(); let store = AlbumStore(root: try root())
        store.data.places = [Place(id: "nearby", title: "PRAGER-BURG", lat: item.latitude, lng: item.longitude + 0.0002)]
        XCTAssertEqual(store.adoptDiscoveryItem(item), .alreadyPresent(placeID: "nearby", planned: false))
        store.data.places = [Place(id: "far", title: "Prager Burg", lat: item.latitude, lng: item.longitude + 0.01)]
        XCTAssertEqual(store.adoptDiscoveryItem(item), .added(placeID: "discovery-q123"))
    }

    func testSharingCopiesLocalPersonalStateButJoiningAnotherTripDoesNot() throws {
        let (city, catalog, _) = fixture(); let store = AlbumStore(root: try root()); store.data.places = []
        let session = DiscoverySession(store: store, service: FixtureService(city: city, result: catalog))
        session.saveInterests([.art, .natureParks])
        store.data.collaboration = CollaborationState(tripID: UUID(), inviteToken: nil)
        session.switchToCurrentScope(copyLocal: true)
        XCTAssertEqual(session.interests, [.art, .natureParks])

        store.data.collaboration = CollaborationState(tripID: UUID(), inviteToken: nil)
        session.switchToCurrentScope(copyLocal: false)
        XCTAssertTrue(session.interests.isEmpty)
        XCTAssertNil(session.selectedCity)
    }

    func testServiceDistinguishesAuthorizationFromEmergencyDisable() {
        XCTAssertEqual(DiscoveryService.classifyHTTP(status: 401), .unauthorized)
        XCTAssertEqual(DiscoveryService.classifyHTTP(status: 403, code: "unauthorized"), .unauthorized)
        XCTAssertEqual(DiscoveryService.classifyHTTP(status: 503, code: "disabled"), .disabled)
        XCTAssertEqual(DiscoveryService.classifyHTTP(status: 429, retryAfter: 60), .rateLimited(retryAfter: 60))
    }

    func testExpiredSuccessfulCatalogResponseIsRejected() async throws {
        let (city, catalog, _) = fixture()
        let expired = DiscoveryCatalog(protocolVersion: 1, catalogVersion: 1, rankingVersion: 1, city: city,
                                       languageCode: catalog.languageCode, coverage: catalog.coverage, items: catalog.items,
                                       fetchedAt: Date(timeIntervalSince1970: 1), expiresAt: Date(timeIntervalSince1970: 2),
                                       staleUntil: Date(timeIntervalSince1970: 3), cacheStatus: .fresh)
        let store = AlbumStore(root: try root()); store.data.places = []
        let session = DiscoverySession(store: store, service: FixtureService(city: city, result: expired))
        session.saveInterests([.history])
        await session.selectCity(city)
        XCTAssertNil(session.catalog)
        XCTAssertEqual(session.phase, .failed(.invalidResponse))
    }

    func testEmptyCitySearchShowsStateAndClearsOnNewSearchOrDestinationChange() async throws {
        let (city, _, _) = fixture(); let store = AlbumStore(root: try root()); store.data.places = []
        let service = CitySearchService(); store.discoveryServiceOverride = service
        let session = store.discoverySession
        session.saveInterests([.architecture])
        await session.searchCities("Deutschland")
        XCTAssertTrue(session.citySearchHadNoResults)
        XCTAssertEqual(session.phase, .needsCity)

        service.cities = [city]
        await session.searchCities("Prag")
        XCTAssertFalse(session.citySearchHadNoResults)
        XCTAssertEqual(session.cityCandidates, [city])

        service.cities = []
        await session.searchCities("unbekanntes Land")
        XCTAssertTrue(session.citySearchHadNoResults)
        var trip = store.data.trip; trip.destination = "Tokyo"
        XCTAssertTrue(store.updateTrip(trip))
        XCTAssertFalse(session.citySearchHadNoResults)
    }

    func testReopeningRefreshesExpiredFreshnessButKeepsUsableStaleCatalogOffline() async throws {
        let directory = try root(); let (city, catalog, _) = fixture(); let now = Date()
        let stale = DiscoveryCatalog(protocolVersion: 1, catalogVersion: 1, rankingVersion: 1, city: city,
                                     languageCode: catalog.languageCode, coverage: catalog.coverage, items: catalog.items,
                                     fetchedAt: now.addingTimeInterval(-172_800), expiresAt: now.addingTimeInterval(-3_600),
                                     staleUntil: now.addingTimeInterval(86_400), cacheStatus: .fresh)
        let firstStore = AlbumStore(root: directory); firstStore.data.places = []
        let first = DiscoverySession(store: firstStore, service: FixtureService(city: city, result: stale))
        first.saveInterests([.history]); await first.selectCity(city)
        XCTAssertEqual(first.catalog?.cacheStatus, .stale)

        let reopenedStore = AlbumStore(root: directory); reopenedStore.data.places = []
        reopenedStore.collectionParticipantIDOverride = firstStore.participantID
        let tracking = RefreshTrackingService(city: city)
        let reopened = DiscoverySession(store: reopenedStore, service: tracking)
        await reopened.reloadIfNeeded()
        XCTAssertEqual(tracking.catalogCalls, 1)
        XCTAssertEqual(reopened.catalog?.cacheStatus, .stale)
        XCTAssertEqual(reopened.filteredItems.map(\.qid), ["Q123"])
        XCTAssertEqual(reopened.lastRefreshError, .offline)
    }
}
