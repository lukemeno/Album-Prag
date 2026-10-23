import SwiftUI
import MapKit

struct NativeDiscoveryView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var session: DiscoverySession?
    @State private var cityQuery = ""
    @State private var task: Task<Void, Never>?
    @State private var message: String?
    private var discovery: DiscoverySession? { session }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.m) {
                    Text("Finde Orte passend zu eurer Reise. Die Auswahl basiert auf Wikidata und Wikipedia-Artikeln, nicht auf Bewertungen.")
                        .font(.subheadline).foregroundStyle(Stitch.inkSoft)
                    if let discovery {
                        interests(discovery)
                        if discovery.interests.isEmpty {
                            Text("Wähle mindestens ein Thema, um passende Orte zu sehen.").font(.headline)
                        } else {
                            cityPicker(discovery)
                            phaseContent(discovery)
                        }
                    } else { ProgressView("Entdecken wird vorbereitet …") }
                }.padding(Stitch.Space.page)
            }
            .background(Stitch.paper.ignoresSafeArea())
            .navigationTitle("Entdecken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() }.accessibilityIdentifier("discovery-close") } }
            .onAppear {
                if session == nil {
                    session = store.discoverySession
                    cityQuery = store.data.trip.destination ?? store.tripName
                }
                if let session, session.selectedCity != nil, task == nil {
                    task = Task {
                        await session.reloadIfNeeded()
                        if !Task.isCancelled { task = nil }
                    }
                }
            }
            .onDisappear { task?.cancel(); task = nil }
            .alert("Entdecken", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: { Text(message ?? "") }
        }
    }

    private func interests(_ session: DiscoverySession) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Text("Was interessiert dich?").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(DiscoveryInterest.allCases) { interest in
                    let selected = session.interests.contains(interest)
                    Button {
                        var next = session.interests
                        if selected { next.remove(interest) } else { next.insert(interest) }
                        session.saveInterests(next)
                    } label: {
                        Label(interest.title, systemImage: selected ? "checkmark.circle.fill" : "circle")
                            .font(.caption.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 40)
                    }.buttonStyle(StitchButton(primary: selected))
                        .accessibilityIdentifier("discovery-interest-\(interest.rawValue)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Button("Alle Themen") { session.saveInterests(Set(DiscoveryInterest.allCases)) }
                .font(.caption.weight(.semibold))
        }.stitchCard()
    }

    private func cityPicker(_ session: DiscoverySession) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Text("Welche Stadt besucht ihr?").font(.headline)
            if let city = session.selectedCity {
                HStack { Label("\(city.name), \(city.country)", systemImage: "mappin.and.ellipse"); Spacer(); Button("Ändern") { session.clearCity() } }
            } else {
                HStack {
                    TextField("Stadt suchen", text: $cityQuery).textInputAutocapitalization(.words)
                        .accessibilityIdentifier("discovery-city-query")
                    Button("Suchen") { task?.cancel(); task = Task { await session.searchCities(cityQuery) } }
                        .disabled(cityQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("discovery-search-cities")
                }
                if session.citySearchHadNoResults {
                    Text("Keine passende Stadt gefunden. Suche eine konkrete Stadt.")
                        .font(.caption).foregroundStyle(Stitch.inkSoft)
                        .accessibilityIdentifier("discovery-city-no-results")
                }
                ForEach(session.cityCandidates) { city in
                    Button { task?.cancel(); task = Task { await session.selectCity(city) } } label: {
                        HStack { Text("\(city.name), \(city.country)"); Spacer(); Image(systemName: "chevron.right") }
                    }.accessibilityIdentifier("discovery-city-\(city.qid)")
                }
            }
        }.stitchCard()
    }

    @ViewBuilder private func phaseContent(_ session: DiscoverySession) -> some View {
        if let catalog = session.catalog {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(catalog.coverage.radiusMeters / 1_000) km um das bestätigte Zentrum von \(catalog.city.name) · \(session.matchingItemCount) passende Orte")
                    .font(.caption.weight(.semibold))
                if catalog.cacheStatus == .stale {
                    Label("Zwischengespeicherte Ergebnisse · Stand \(catalog.fetchedAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "wifi.slash")
                        .font(.caption).foregroundStyle(Stitch.inkSoft)
                }
            }.accessibilityElement(children: .combine)
                .accessibilityIdentifier("discovery-catalog-summary")
        }
        switch session.phase {
        case .searchingCities: ProgressView("Städte werden gesucht …")
        case .loadingCatalog:
            VStack(alignment: .leading, spacing: Stitch.Space.s) {
                ProgressView("Orte werden geladen …")
                if session.catalog != nil { resultCards(session) }
            }
        case .needsInterests, .needsCity: EmptyView()
        case .cityChoices: Text("Bitte bestätige die passende Stadt.").font(.subheadline)
        case .failed(let error):
            VStack(alignment: .leading, spacing: 8) {
                Text(errorText(error)).font(.subheadline)
                Button("Erneut versuchen") { task?.cancel(); task = Task { await session.retry() } }
            }.stitchCard()
            if (session.catalog?.staleUntil ?? .distantPast) >= Date() {
                resultCards(session)
            }
        case .empty:
            VStack(alignment: .leading, spacing: Stitch.Space.s) {
                Text("Für diese Themen gibt es in diesem Katalog keine passenden Orte.").font(.subheadline)
                if let error = session.lastRefreshError { Text(errorText(error)).font(.caption).foregroundStyle(Stitch.inkSoft) }
            }.stitchCard()
        case .ready:
            resultCards(session)
            Button("Aktualisieren") { task?.cancel(); task = Task { await session.refresh() } }
                .font(.caption.weight(.semibold)).accessibilityIdentifier("discovery-refresh")
            if let error = session.lastRefreshError { Text(errorText(error)).font(.caption).foregroundStyle(Stitch.inkSoft) }
        }
    }

    @ViewBuilder private func resultCards(_ session: DiscoverySession) -> some View {
        ForEach(session.filteredItems) { item in discoveryCard(item, session: session) }
        if session.hasMore { Button("Weitere anzeigen") { session.showMore() }.buttonStyle(StitchButton(primary: false)).accessibilityIdentifier("discovery-more") }
    }

    private func discoveryCard(_ item: DiscoveryItem, session: DiscoverySession) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Text(item.name).font(.headline).accessibilityIdentifier("discovery-item-\(item.qid)")
            if let description = item.description, !description.isEmpty { Text(description).font(.subheadline).foregroundStyle(Stitch.inkSoft) }
            Text(item.interests.filter(session.interests.contains).map(\.title).joined(separator: " · "))
                .font(.caption.weight(.medium)).foregroundStyle(Stitch.red)
            Text("Etwa \(item.distanceMeters) m vom Stadtzentrum").font(.caption).foregroundStyle(Stitch.inkSoft)
            if let image = item.image {
                AsyncImage(url: image.imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView("Bild wird geladen …").frame(maxWidth: .infinity, minHeight: 150)
                    case .success(let picture):
                        picture.resizable().scaledToFill().frame(height: 150).clipped()
                    case .failure:
                        imagePlaceholder
                    @unknown default:
                        imagePlaceholder
                    }
                }
            } else { imagePlaceholder }
            DisclosureGroup("Details") {
                VStack(alignment: .leading, spacing: Stitch.Space.s) {
                    Text("Lage: \(item.latitude.formatted(.number.precision(.fractionLength(5)))), \(item.longitude.formatted(.number.precision(.fractionLength(5))))")
                        .font(.caption).foregroundStyle(Stitch.inkSoft)
                    let coordinate = CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
                    if canShowMapTiles {
                        let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))
                        Map(initialPosition: .region(region)) { Marker(item.name, coordinate: coordinate) }
                            .frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityLabel("Karte mit der Lage von \(item.name)")
                    } else {
                        Link("In Apple Karten öffnen", destination: mapURL(for: item))
                            .font(.caption)
                    }
                    Text("\(item.wikipediaLanguageCount) Wikipedia-Sprachartikel. Näherungswert für Bekanntheit, keine Bewertung oder Bestenliste.")
                        .font(.caption).foregroundStyle(Stitch.inkSoft)
                    if let image = item.image {
                        Text("Bildnachweis: \(image.credit) · \(image.licenseName)")
                            .font(.caption2).foregroundStyle(Stitch.inkSoft)
                        Link("Bildquelle öffnen", destination: image.sourceURL).font(.caption)
                        Link("Lizenzdetails öffnen", destination: image.licenseURL).font(.caption)
                    } else {
                        Text("Für diesen Ort ist kein geprüftes Bild verfügbar.").font(.caption).foregroundStyle(Stitch.inkSoft)
                    }
                }.padding(.top, Stitch.Space.s)
            }
            HStack {
                Link("Wikidata", destination: item.sourceURL).font(.caption)
                Spacer()
                adoptionButton(store.discoveryAdoptionStatus(item), item: item)
            }
        }.stitchCard()
    }
    private var imagePlaceholder: some View {
        Label("Kein geprüftes Bild verfügbar", systemImage: "photo").font(.caption).foregroundStyle(Stitch.inkSoft)
            .frame(maxWidth: .infinity, minHeight: 72).background(Stitch.paper, in: RoundedRectangle(cornerRadius: 10))
    }
    private var canShowMapTiles: Bool {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        return environment["ALBUM_TEST_STORE"] == nil || environment["ALBUM_DISCOVERY_LIVE_QA"] == "1"
        #else
        return true
        #endif
    }
    private func mapURL(for item: DiscoveryItem) -> URL {
        var components = URLComponents()
        components.scheme = "https"; components.host = "maps.apple.com"
        components.queryItems = [URLQueryItem(name: "ll", value: "\(item.latitude),\(item.longitude)"), URLQueryItem(name: "q", value: item.name)]
        return components.url ?? item.sourceURL
    }
    @ViewBuilder private func adoptionButton(_ result: DiscoveryAdoptionResult?, item: DiscoveryItem) -> some View {
        switch result {
        case .alreadyPresent(_, let planned): Text(planned ? "Bereits geplant" : "Bereits in euren Ideen").font(.caption).accessibilityIdentifier("discovery-existing-\(item.qid)")
        case .removed(let id): Button("Entfernt · wiederherstellen") { if store.restoreDiscoveryPlace(id: id) { message = "Ort wiederhergestellt." } }.accessibilityIdentifier("discovery-restore-\(item.qid)")
        case .added: Label("In euren Ideen", systemImage: "checkmark").font(.caption.weight(.semibold))
        case .failed: Text("Speichern fehlgeschlagen").font(.caption)
        case nil: Button("Als Idee übernehmen") { showAdoptionFeedback(item) }.font(.caption.weight(.semibold)).accessibilityIdentifier("discovery-adopt-\(item.qid)")
        }
    }
    private func showAdoptionFeedback(_ item: DiscoveryItem) {
        switch store.adoptDiscoveryItem(item) {
        case .added: message = "Zur gemeinsamen Ideenliste hinzugefügt."
        case .failed: message = "Speichern fehlgeschlagen. Bitte erneut versuchen."
        default: break
        }
    }
    private func errorText(_ error: DiscoveryServiceError) -> String {
        switch error {
        case .disabled: "Entdecken ist derzeit deaktiviert."
        case .unauthorized: "Die Anmeldung konnte nicht geprüft werden. Bitte erneut versuchen."
        case .offline: "Keine Verbindung. Gespeicherte Ergebnisse bleiben verfügbar."
        case .rateLimited: "Die Quelle begrenzt gerade Anfragen. Bitte später erneut versuchen."
        case .sourceUnavailable: "Die Datenquelle ist gerade nicht erreichbar."
        case .invalidRequest, .invalidResponse: "Die Anfrage konnte nicht verarbeitet werden."
        }
    }
}

