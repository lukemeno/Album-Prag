import Foundation
import Observation

private struct DiscoveryEnvelope: Codable { var schemaVersion = 1; var scopes: [String: DiscoveryState] = [:] }
private struct DiscoveryState: Codable {
    var interests: Set<DiscoveryInterest> = []
    var selectedCity: DiscoveryCity?
    var destinationFingerprint = ""
    var catalog: DiscoveryCatalog?
    var catalogRequestLanguageCode: String?
}

@MainActor @Observable final class DiscoverySession {
    private let store: AlbumStore
    private let service: any DiscoveryServiceProtocol
    private(set) var interests: Set<DiscoveryInterest> = []
    private(set) var selectedCity: DiscoveryCity?
    private(set) var cityCandidates: [DiscoveryCity] = []
    private(set) var citySearchHadNoResults = false
    private(set) var catalog: DiscoveryCatalog?
    private var catalogRequestLanguageCode: String?
    private(set) var phase: DiscoveryPhase = .needsInterests
    private(set) var lastRefreshError: DiscoveryServiceError?
    private(set) var visibleCount = 12
    private var generation = 0
    private var loadedScope: String?
    private var lastCityQuery = ""
    private var envelope = DiscoveryEnvelope()
    private var destination = ""

    init(store: AlbumStore, service: (any DiscoveryServiceProtocol)? = nil) {
        self.store = store; self.service = service ?? store.discoveryServiceOverride ?? DiscoveryService()
        destination = store.data.trip.destination ?? store.tripName
        load()
    }
    private var matchingItems: [DiscoveryItem] {
        guard let catalog else { return [] }
        return catalog.items.filter { !$0.interests.filter(interests.contains).isEmpty }
            .sorted { a, b in
                if a.wikipediaLanguageCount != b.wikipediaLanguageCount { return a.wikipediaLanguageCount > b.wikipediaLanguageCount }
                if a.distanceMeters != b.distanceMeters { return a.distanceMeters < b.distanceMeters }
                return a.qid < b.qid
            }
    }
    var filteredItems: [DiscoveryItem] { Array(matchingItems.prefix(visibleCount)) }
    var matchingItemCount: Int { matchingItems.count }
    var hasMore: Bool { visibleCount < min(60, matchingItems.count) }

    func saveInterests(_ values: Set<DiscoveryInterest>) {
        interests = values
        phase = values.isEmpty ? .needsInterests : selectedCity == nil ? .needsCity : catalog == nil ? .ready : (filteredItems.isEmpty ? .empty : .ready)
        save()
    }
    func updateInterests(_ values: Set<DiscoveryInterest>) { saveInterests(values) }
    func searchCities(_ query: String) async {
        guard !interests.isEmpty else { phase = .needsInterests; return }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { phase = .needsCity; return }
        citySearchHadNoResults = false
        lastCityQuery = q
        generation += 1; let request = generation; let requestedLanguage = languageCode
        phase = .searchingCities; cityCandidates = []; lastRefreshError = nil
        do {
            let result = try await service.searchCities(query: q, languageCode: requestedLanguage)
            guard !Task.isCancelled, request == generation, requestedLanguage == languageCode, destinationFingerprint == fingerprint(currentDestination) else { return }
            cityCandidates = Array(result.prefix(5)); citySearchHadNoResults = cityCandidates.isEmpty
            phase = cityCandidates.isEmpty ? .needsCity : .cityChoices
        } catch let error as DiscoveryServiceError { if !Task.isCancelled, request == generation, requestedLanguage == languageCode { citySearchHadNoResults = false; phase = .failed(error) } }
        catch { if !Task.isCancelled, request == generation, requestedLanguage == languageCode { citySearchHadNoResults = false; phase = .failed(.sourceUnavailable(retryAfter: nil)) } }
    }
    func selectCity(_ city: DiscoveryCity) async {
        generation += 1; selectedCity = city; catalog = nil; catalogRequestLanguageCode = nil; visibleCount = 12; cityCandidates = []; citySearchHadNoResults = false
        save(); await loadCatalog(generation: generation)
    }
    func refresh() async {
        guard selectedCity != nil else { return }
        discardUnusableCatalog()
        generation += 1; lastRefreshError = nil; await loadCatalog(generation: generation)
    }
    func reloadIfNeeded() async {
        discardUnusableCatalog()
        if selectedCity != nil && (catalog == nil || (catalog?.expiresAt ?? .distantFuture) < Date()) { await refresh() }
    }
    func retry() async {
        if selectedCity != nil { await refresh() }
        else if !cityCandidates.isEmpty { phase = .cityChoices }
        else if !lastCityQuery.isEmpty { await searchCities(lastCityQuery) }
    }
    func showMore() { visibleCount = min(60, visibleCount + 12) }
    func clearCity() { generation += 1; selectedCity = nil; catalog = nil; catalogRequestLanguageCode = nil; cityCandidates = []; citySearchHadNoResults = false; phase = interests.isEmpty ? .needsInterests : .needsCity; save() }
    func destinationDidChange() {
        let next = currentDestination
        guard fingerprint(next) != fingerprint(destination) else { return }
        generation += 1; destination = next; selectedCity = nil; catalog = nil; catalogRequestLanguageCode = nil; cityCandidates = []; citySearchHadNoResults = false
        phase = interests.isEmpty ? .needsInterests : .needsCity; save()
    }

    func switchToCurrentScope(copyLocal: Bool) {
        let old = loadedScope
        loadedScope = scope
        var state = envelope.scopes[scope] ?? DiscoveryState()
        if copyLocal, let old, let localState = envelope.scopes[old] { state = localState }
        if state.destinationFingerprint != fingerprint(currentDestination) { state.selectedCity = nil; state.catalog = nil }
        state.destinationFingerprint = fingerprint(currentDestination)
        envelope.scopes[scope] = state
        apply(state)
        destination = currentDestination; persist()
    }
    private func loadCatalog(generation request: Int) async {
        guard let city = selectedCity else { phase = .needsCity; return }
        let requestedLanguage = languageCode
        phase = .loadingCatalog
        do {
            let result = try await service.catalog(cityQID: city.qid, languageCode: requestedLanguage)
            guard !Task.isCancelled, request == generation, requestedLanguage == languageCode, selectedCity?.qid == city.qid,
                  fingerprint(destination) == fingerprint(currentDestination) else { return }
            guard result.staleUntil >= Date() else { throw DiscoveryServiceError.invalidResponse }
            catalog = usableCatalog(result); catalogRequestLanguageCode = requestedLanguage
            visibleCount = 12; phase = filteredItems.isEmpty ? .empty : .ready; lastRefreshError = nil; save()
        } catch let error as DiscoveryServiceError {
            if !Task.isCancelled, request == generation, requestedLanguage == languageCode {
                if let catalog, catalog.staleUntil >= Date() { self.catalog = usableCatalog(catalog); lastRefreshError = error; phase = filteredItems.isEmpty ? .empty : .ready }
                else { phase = .failed(error) }
            }
        } catch {
            if !Task.isCancelled, request == generation, requestedLanguage == languageCode {
                if let catalog, catalog.staleUntil >= Date() { self.catalog = usableCatalog(catalog); lastRefreshError = .sourceUnavailable(retryAfter: nil); phase = filteredItems.isEmpty ? .empty : .ready }
                else { phase = .failed(.sourceUnavailable(retryAfter: nil)) }
            }
        }
    }
    private var languageCode: String { Locale.current.language.languageCode?.identifier ?? "en" }
    private var currentDestination: String { store.data.trip.destination ?? store.tripName }
    private var scope: String { store.data.collaboration.map { "trip:\($0.tripID.uuidString.lowercased())" } ?? "album:\(store.data.albumID)" }
    private var destinationFingerprint: String { fingerprint(destination) }
    private func fingerprint(_ value: String) -> String {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let words = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(words).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    private var fileURL: URL {
        func safe(_ raw: String) -> String { raw.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" ? String($0) : "_" }.joined() }
        return store.root.appendingPathComponent("discovery-\(safe(store.data.albumID))-\(safe(store.participantID)).json")
    }
    private func load() {
        if let data = try? Data(contentsOf: fileURL), let decoded = try? JSONDecoder.discovery.decode(DiscoveryEnvelope.self, from: data) { envelope = decoded }
        loadedScope = scope
        var state = envelope.scopes[scope] ?? DiscoveryState()
        var changed = false
        if state.destinationFingerprint != fingerprint(currentDestination) { state.selectedCity = nil; state.catalog = nil; state.catalogRequestLanguageCode = nil; state.destinationFingerprint = fingerprint(currentDestination); changed = true }
        if let cached = state.catalog, cached.staleUntil < Date() { state.catalog = nil; state.catalogRequestLanguageCode = nil; changed = true }
        if state.catalog != nil, state.catalogRequestLanguageCode != languageCode { state.catalog = nil; state.catalogRequestLanguageCode = nil; changed = true }
        envelope.scopes[scope] = state
        apply(state)
        if changed { persist() }
    }
    private func apply(_ state: DiscoveryState) {
        interests = state.interests; selectedCity = state.selectedCity
        catalogRequestLanguageCode = state.catalogRequestLanguageCode
        catalog = state.catalog.flatMap { $0.staleUntil >= Date() && state.catalogRequestLanguageCode == languageCode ? usableCatalog($0) : nil }
        if let cached = state.catalog, catalog == nil { selectedCity = state.selectedCity }
        phase = interests.isEmpty ? .needsInterests : selectedCity == nil ? .needsCity : catalog == nil ? .ready : (filteredItems.isEmpty ? .empty : .ready)
    }
    private func usableCatalog(_ value: DiscoveryCatalog) -> DiscoveryCatalog {
        let status: DiscoveryCacheStatus = value.expiresAt < Date() ? .stale : value.cacheStatus
        return DiscoveryCatalog(protocolVersion: value.protocolVersion, catalogVersion: value.catalogVersion, rankingVersion: value.rankingVersion,
                                city: value.city, languageCode: value.languageCode, coverage: value.coverage, items: value.items,
                                fetchedAt: value.fetchedAt, expiresAt: value.expiresAt, staleUntil: value.staleUntil, cacheStatus: status)
    }
    private func discardUnusableCatalog() {
        guard let catalog, catalog.staleUntil < Date() || catalogRequestLanguageCode != languageCode else { return }
        self.catalog = nil; catalogRequestLanguageCode = nil; save()
    }
    private func save() {
        envelope.scopes[scope] = DiscoveryState(interests: interests, selectedCity: selectedCity, destinationFingerprint: fingerprint(currentDestination), catalog: catalog, catalogRequestLanguageCode: catalogRequestLanguageCode)
        loadedScope = scope; persist()
    }
    private func persist() {
        do { let encoder = JSONEncoder.discovery; try encoder.encode(envelope).write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen]) } catch { store.error = "Entdecken konnte nicht gespeichert werden: \(error.localizedDescription)" }
    }
}

private extension JSONEncoder { static var discovery: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e } }
private extension JSONDecoder { static var discovery: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d } }
