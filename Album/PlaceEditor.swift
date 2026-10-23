import SwiftUI
import MapKit
import PhotosUI
import LinkPresentation

struct PlaceEditor: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State var place: Place
    var autoSourceEnrichment = true
    var onSaved: ((Place) -> Void)?
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var enriching = false
    @State private var imageSearching = false
    @State private var pendingImageSearch: Bool?
    @State private var imageChoices: ImageChoices?
    @State private var searchTask: Task<Void, Never>?
    @State private var imageTask: Task<Void, Never>?
    @State private var photoTask: Task<Void, Never>?
    @State private var searchGeneration = 0
    @State private var enrichGeneration = 0
    @State private var imageGeneration = 0
    @State private var photoGeneration = 0
    @State private var photoItem: PhotosPickerItem?
    @State private var photoPickerPresented = false
    @State private var pendingPhotoID: String?
    @State private var posting = false
    @State private var confirmDelete = false
    @State private var editorFinished = false
    /// Schon gespeichert? Dann gibt es Zurücklegen und Löschen.
    private var exists: Bool { store.places.contains { $0.id == place.id } }
    private var editorTitle: String { exists ? "Bearbeiten" : "Neue Idee" }
    let categories = ["Idee", "Sehenswert", "Essen & Trinken", "Aussicht", "Unterkunft", "Shopping"]
    var valid: Bool {
        !place.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (place.sourceURL.isEmpty || LinkValidation.url(place.sourceURL) != nil)
    }
    var body: some View {
        NavigationStack {
            Form {
                editorFormContent
            }
            .accessibilityIdentifier("PlaceEditor-Form")
            .scrollContentBackground(.hidden).background(PaperBackground())
                .confirmationDialog("Diesen Ort löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Löschen", role: .destructive) {
                        place.deleted = true
                        guard store.upsert(place) else { return }
                        endEditor(preservePendingPhoto: false)
                        dismiss()
                    }
                } message: { Text("Er verschwindet auch auf dem anderen iPhone.") }
                .navigationTitle(dynamicTypeSize.isAccessibilitySize ? "" : editorTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !dynamicTypeSize.isAccessibilitySize {
                        ToolbarItem(placement: .cancellationAction) { Button("Abbrechen", action: cancel).font(.body).accessibilityIdentifier("PlaceEditor-Cancel") }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Speichern", action: save).font(.body).accessibilityIdentifier("PlaceEditor-Save").disabled(!valid || posting)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: Stitch.Space.s) {
                            Button("Abbrechen", action: cancel)
                                .buttonStyle(StitchButton())
                                .accessibilityIdentifier("PlaceEditor-Cancel")
                                .frame(maxWidth: .infinity)
                            Button("Speichern", action: save)
                                .buttonStyle(StitchButton(primary: true))
                                .accessibilityIdentifier("PlaceEditor-Save")
                                .disabled(!valid || posting)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, Stitch.Space.page).padding(.vertical, Stitch.Space.xs)
                        .background {
                            PaperBackground()
                                .overlay(alignment: .top) { Stitch.rule.frame(height: 1) }
                        }
                    }
                }
                .onAppear {
                    editorFinished = false
                    query = place.title == "Neue Reiseidee" ? "" : place.title
                }
                .sheet(item: $imageChoices) { choices in
                    PlaceImagePicker(choices: choices, root: store.root) { selected in
                        guard !editorFinished, PlaceImageService.matchesRequest(choices.place, place) else { return }
                        place.image = selected.asset(for: place, userSelected: true)
                        let others = choices.images.filter { $0.imageURL != selected.imageURL && $0.confidence == .verified }
                        place.gallery = selected.confidence == .verified ? PlaceImageService.gallery(from: [selected] + others, for: place) : []
                        imageChoices = nil
                    } streetView: {
                        guard !editorFinished, PlaceImageService.matchesRequest(choices.place, place) else { return }
                        imageChoices = nil
                        beginStreetView(for: choices.place)
                    }
                }
                .task(id: place.sourceURL) {
                    invalidateLocationSearch(clearResults: true)
                    invalidateSourceEnrichment()
                    guard autoSourceEnrichment else { return }
                    // Gültiger Link: Vorschau laden und bei fehlendem Ort eine Kandidatensuche vorbereiten.
                    guard let url = LinkValidation.url(place.sourceURL), needsSourceEnrichment(for: url) else { return }
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    await enrich()
                }
                .overlay { if posting { LetterSlotDrop(place: place, root: store.root) { dismiss() }.transition(.opacity) } }
                .onDisappear {
                    // Das Öffnen eines Kind-Pickers darf den Draft nicht aufräumen.
                    guard !imageChoicesPresented else { return }
                    finishEditorIfNeeded()
                }
                .onChange(of: photoItem) { _, item in
                    guard let item else { return }
                    beginPhotoImport(item)
                }
        }
    }

    @ViewBuilder
    private var editorFormContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Section {
                Text(editorTitle)
                    .font(Stitch.Face.title(30, relativeTo: .largeTitle))
                    .foregroundStyle(Stitch.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .listRowBackground(Color.clear)
        }
        ideaSection
        locationSection
        if place.franked { planningSection }
        if exists { managementSection }
    }

    private var ideaSection: some View {
        Section {
            TextField("Name der Idee", text: $place.title)
                .font(.body).frame(minHeight: Stitch.Size.touch)
                .accessibilityLabel("Name der Idee")
                .accessibilityIdentifier("PlaceEditor-Title")
            TextField("Link zur Idee", text: $place.sourceURL)
                .font(.body).frame(minHeight: Stitch.Size.touch)
                .accessibilityLabel("Link von TikTok oder Instagram")
                .accessibilityIdentifier("PlaceEditor-Source")
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            if !place.sourceURL.isEmpty && LinkValidation.url(place.sourceURL) == nil {
                Text("Der Link muss mit https:// beginnen.").font(.footnote).foregroundStyle(Stitch.red)
            }
            if enriching {
                Label { Text("Vorschau wird geladen …") } icon: { ProgressView() }.foregroundStyle(Stitch.inkSoft)
            }
            Picker("Kategorie", selection: $place.category) { ForEach(categories, id: \.self) { Text($0) } }
            TextField("Warum da hin?", text: $place.note, axis: .vertical)
                .font(.body).lineLimit(3...6)
                .accessibilityLabel("Warum möchtet ihr dorthin?")
        } header: {
            Text("Idee").foregroundStyle(Stitch.ink)
        }
        .listRowBackground(Stitch.card)
    }

    private var locationSection: some View {
        Section { locationSearchAndImageControls } header: { Text("Ort").foregroundStyle(Stitch.ink) }
            .listRowBackground(Stitch.card)
    }

    @ViewBuilder
    private var locationSearchAndImageControls: some View {
        locationSearchField
        if let searchError { Text(searchError).font(.footnote).foregroundStyle(Stitch.red) }
        ForEach(Array(results.enumerated()), id: \.offset) { _, item in locationResultRow(item) }
        if place.coordinate != nil { selectedLocationControls }
    }

    private var locationSearchField: some View {
        HStack {
            TextField("Ort oder Adresse", text: queryBinding)
                .font(.body).frame(minHeight: Stitch.Size.touch)
                .accessibilityLabel("Ort oder Adresse suchen")
                .submitLabel(.search).onSubmit { search() }
            Button(action: search) {
                if searching { ProgressView() } else { Image(systemName: "magnifyingglass") }
            }
            .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching)
            .accessibilityLabel("Ort suchen")
        }
    }

    @ViewBuilder
    private var selectedLocationControls: some View {
        Label(place.address.isEmpty ? "Ort gefunden" : place.address, systemImage: "checkmark.circle.fill")
            .foregroundStyle(Stitch.red)
        Button(imageSearching ? "Bilder werden gesucht …" : "Bild wählen") { beginImageSearch(force: true) }
            .disabled(imageSearching)
        photoPickerControl
        if place.image != nil { selectedImageView }
    }

    private var photoPickerControl: some View {
        Button {
            photoPickerPresented = true
        } label: {
            Label("Eigenes Foto wählen", systemImage: "photo.on.rectangle")
        }
        .photosPicker(isPresented: $photoPickerPresented, selection: $photoItem, matching: .images)
    }

    @ViewBuilder
    private var selectedImageView: some View {
        AlbumPhoto(asset: place.image, root: store.root, thumbnailWidth: 500)
            .frame(height: 160).clipped().accessibilityLabel("Gewähltes Bild")
        if let credit = place.image?.credit {
            let license: String? = if case .external(let image) = place.image { image.licenseName } else { nil }
            Text("Foto: \(credit)\(license.map { " · \($0)" } ?? "")")
                .font(.footnote).foregroundStyle(Stitch.inkSoft)
        }
        Button("Bild entfernen", role: .destructive) { place.image = nil; place.gallery = [] }
    }

    private var planningSection: some View {
        Section("Planung") {
            Toggle("Schon besucht", isOn: $place.visited)
            let calendar = store.tripCalendar
            if place.plannedDate == nil, let legacyDay = place.day {
                Text("Alter Reisetag \(legacyDay) ließ sich keinem Datum zuordnen. Bitte neu wählen.")
                    .font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
            Picker("Tag", selection: plannedDateBinding) {
                Text("Noch offen").tag(nil as TripDay?)
                if let date = place.plannedDate, !calendar.contains(date) {
                    Text("\(calendar.dayTitle(date)) · außerhalb des Zeitraums").tag(Optional(date))
                }
                ForEach(calendar.days) { Text(calendar.dayTitle($0)).tag(Optional($0)) }
            }
        }
        .listRowBackground(Stitch.card)
    }

    private var plannedDateBinding: Binding<TripDay?> {
        Binding(
            get: { place.plannedDate },
            set: { date in
                if place.plannedDate != date { place.dayOrder = nil }
                place.plannedDate = date
                place.planningSchemaVersion = 2
                if date != nil { place.day = nil }
            }
        )
    }

    private var managementSection: some View {
        Section {
            if place.franked {
                Button("Zurück zu den Ideen") {
                    place.franked = false; place.deferred = false
                    place.plannedDate = nil; place.day = nil; place.dayOrder = nil
                    guard store.upsert(place) else { return }
                    endEditor(preservePendingPhoto: true)
                    dismiss()
                }
            }
            Button("Ort löschen", role: .destructive) { confirmDelete = true }
        } footer: {
            Text(place.franked ? "Zurück zu den Ideen nimmt den Ort aus dem Plan; eure bisherigen Stimmen bleiben erhalten." : "")
        }
        .listRowBackground(Stitch.card)
    }

    private var imageChoicesPresented: Bool { imageChoices != nil || photoPickerPresented }

    @ViewBuilder
    private func locationResultRow(_ item: MKMapItem) -> some View {
        Button {
            let oldCoordinate = place.coordinate
            let newCoordinate = item.placemark.coordinate
            let locationMoved = PlaceImageService.locationMoved(from: oldCoordinate, to: newCoordinate)
            place.title = item.name ?? place.title
            place.address = item.placemark.title ?? ""
            place.lat = newCoordinate.latitude
            place.lng = newCoordinate.longitude
            if locationMoved {
                if PlaceImageService.shouldDiscardImageAfterLocationMove(place.image) { place.image = nil }
                place.gallery = nil
            }
            results = []
            beginImageSearch(force: false)
        } label: {
            VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                Text(item.name ?? "Ort")
                Text(item.placemark.title ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        let isNew = !store.places.contains { $0.id == place.id }
        guard store.upsert(place) else { return }
        if place.coordinate == nil {
            Task { await store.refreshPlaceImage(id: place.id) }
        }
        // Erst nach einem erfolgreichen Persistieren darf die laufende Arbeit enden.
        endEditor(preservePendingPhoto: true)
        onSaved?(place)
        // Neue Ideen werden sichtbar eingeworfen; gespeichert ist schon vorher.
        if isNew { withAnimation(.easeOut(duration: 0.2)) { posting = true } } else { dismiss() }
    }

    func search() {
        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        let currentQuery = query
        let currentSourceURL = place.sourceURL
        let context = store.tripRegionContext(for: place)
        searching = true; searchError = nil
        searchTask = Task { @MainActor in
            defer { if !editorFinished, searchGeneration == generation { searching = false } }
            if ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] != nil {
                guard !Task.isCancelled, !editorFinished, searchGeneration == generation,
                      self.query == currentQuery, place.sourceURL == currentSourceURL,
                      store.tripRegionContext(for: place) == context else { return }
                results = []
                searchError = "Kein Treffer. Bitte Name oder Adresse ergänzen."
                return
            }
            let request = MKLocalSearch.Request()
            let trimmedQuery = currentQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            request.naturalLanguageQuery = context.region == nil
                ? [trimmedQuery, context.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                : trimmedQuery
            if let region = context.region {
                request.region = region
            } else if let coordinate = place.coordinate {
                request.region = MKCoordinateRegion(center: coordinate, span: .init(latitudeDelta: 0.15, longitudeDelta: 0.15))
            }
            do {
                let response = try await MKLocalSearch(request: request).start()
                try Task.checkCancellation()
                guard !editorFinished, searchGeneration == generation, self.query == currentQuery,
                      place.sourceURL == currentSourceURL, store.tripRegionContext(for: place) == context else { return }
                results = response.mapItems
                if results.isEmpty { searchError = "Kein Treffer. Bitte Name oder Adresse ergänzen." }
            } catch {
                guard !editorFinished, !Task.isCancelled, searchGeneration == generation, self.query == currentQuery,
                      place.sourceURL == currentSourceURL, store.tripRegionContext(for: place) == context else { return }
                searchError = "Ortssuche fehlgeschlagen. Bitte erneut versuchen."
            }
        }
    }
    func enrich() async {
        guard let url = LinkValidation.url(place.sourceURL) else { return }
        enrichGeneration += 1
        let generation = enrichGeneration
        let requestedSourceURL = place.sourceURL
        let queryAtStart = query
        let searchGenerationAtStart = searchGeneration
        enriching = true
        defer { if !editorFinished, enrichGeneration == generation { enriching = false } }
        do {
            let preview = try await OEmbedService.preview(url)
            guard !editorFinished, !Task.isCancelled, enrichGeneration == generation,
                  place.sourceURL == requestedSourceURL else { return }
            let shouldSearch = SourceMetadataPolicy.apply(
                preview,
                pageURL: url,
                to: &place,
                query: &query,
                queryWasUnchanged: searchGeneration == searchGenerationAtStart && query == queryAtStart
            )
            if shouldSearch { search() }
        } catch {
            guard !editorFinished, !Task.isCancelled, enrichGeneration == generation,
                  place.sourceURL == requestedSourceURL,
                  searchGeneration == searchGenerationAtStart, query == queryAtStart else { return }
            searchError = error.localizedDescription
        }
    }

    private func needsSourceEnrichment(for url: URL) -> Bool {
        if place.coordinate == nil { return true }
        if place.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || place.title == "Neue Reiseidee" { return true }
        switch place.image {
        case nil: return true
        case .linkPreview(let pageURL, _, _): return pageURL != url.absoluteString
        case .bundled, .external, .uploaded: return false
        }
    }

    private func invalidateLocationSearch(clearResults: Bool) {
        searchGeneration += 1
        searchTask?.cancel()
        searchTask = nil
        searching = false
        searchError = nil
        if clearResults { results = [] }
    }

    private func invalidateSourceEnrichment() {
        enrichGeneration += 1
        enriching = false
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { query },
            set: { value in
                guard value != query else { return }
                query = value
                invalidateLocationSearch(clearResults: true)
            }
        )
    }

    private func beginImageSearch(force: Bool) {
        imageTask?.cancel()
        photoTask?.cancel()
        imageGeneration += 1
        photoGeneration += 1
        imageSearching = false
        pendingImageSearch = nil
        let generation = imageGeneration
        imageTask = Task { await findImage(force: force, generation: generation) }
    }

    private func beginStreetView(for requested: Place) {
        imageTask?.cancel()
        photoTask?.cancel()
        imageGeneration += 1
        photoGeneration += 1
        imageSearching = false
        pendingImageSearch = nil
        let generation = imageGeneration
        imageTask = Task { await useStreetView(for: requested, generation: generation) }
    }

    private func isCurrentImageOperation(_ generation: Int) -> Bool {
        !editorFinished && !Task.isCancelled && imageGeneration == generation
    }

    private func findImage(force: Bool, generation: Int) async {
        guard isCurrentImageOperation(generation) else { return }
        if imageSearching {
            pendingImageSearch = (pendingImageSearch ?? false) || force
            return
        }
        imageSearching = true
        defer {
            if imageGeneration == generation {
                imageSearching = false
                pendingImageSearch = nil
            }
        }
        var nextForce = force
        while isCurrentImageOperation(generation), PlaceImageService.shouldSearch(for: place, force: nextForce) {
            pendingImageSearch = nil
            await resolveImage(force: nextForce, generation: generation)
            guard isCurrentImageOperation(generation), let pending = pendingImageSearch else { return }
            nextForce = pending
        }
    }

    private func resolveImage(force: Bool, generation: Int) async {
        let requested = place
        let context = store.tripRegionContext(for: requested)
        do {
            let result = try await PlaceImageService.search(
                for: requested,
                region: context.name,
                languageCode: context.preferredLanguageCode
            )
            guard isCurrentImageOperation(generation), PlaceImageService.matchesRequest(requested, place), requested.image == place.image,
                  store.tripRegionContext(for: requested) == context else { return }
            if force, !result.choices.isEmpty {
                imageChoices = ImageChoices(place: requested, images: result.choices)
                searchError = nil
                return
            }
            if force, result.choices.isEmpty, PlaceImageService.isUserChosen(requested.image) {
                // Ein eigenes oder bewusst gewähltes Bild bleibt, bis die Person den Apple-Fallback ausdrücklich auswählt.
                imageChoices = ImageChoices(place: requested, images: [])
                searchError = nil
                return
            }
            let found = result.automaticImages
            if let result = found.first {
                place.image = result.asset(for: place)
                place.gallery = PlaceImageService.gallery(from: found, for: place)
            } else if result.isCurrent, !result.choices.isEmpty {
                // Unsichere Treffer werden nie automatisch übernommen, sondern ausdrücklich geprüft.
                imageChoices = ImageChoices(place: requested, images: result.choices)
                searchError = nil
            } else {
                guard isCurrentImageOperation(generation) else { return }
                await useStreetView(for: requested, generation: generation)
                return
            }
            searchError = nil
        } catch {
            guard isCurrentImageOperation(generation), PlaceImageService.matchesRequest(requested, place), requested.image == place.image,
                  store.tripRegionContext(for: requested) == context else { return }
            if force, PlaceImageService.isUserChosen(requested.image) {
                imageChoices = ImageChoices(place: requested, images: [])
                searchError = nil
                return
            }
            guard isCurrentImageOperation(generation) else { return }
            await useStreetView(for: requested, remoteSearchFailed: true, generation: generation)
        }
    }

    private func useStreetView(for requested: Place, remoteSearchFailed: Bool = false, generation: Int) async {
        guard let coordinate = requested.coordinate else { return }
        guard isCurrentImageOperation(generation) else { return }
        let local = await PlaceImageResolver.localSnapshot(at: coordinate)
        guard isCurrentImageOperation(generation), PlaceImageService.matchesRequest(requested, place), requested.image == place.image else { return }
        guard let local else {
            searchError = remoteSearchFailed
                ? "Die Bildsuche und die Apple-Karten-Vorschau sind gerade nicht verfügbar. Das bisherige Bild bleibt erhalten."
                : "Für diesen Ort ist keine Apple-Karten-Vorschau verfügbar. Das bisherige Bild bleibt erhalten."
            return
        }
        do {
            guard isCurrentImageOperation(generation) else { return }
            var uploaded = try PlaceImageStorage.save(local.data, root: store.root)
            guard isCurrentImageOperation(generation), PlaceImageService.matchesRequest(requested, place), requested.image == place.image else {
                PlaceImageStorage.remove(uploaded, root: store.root)
                return
            }
            removePendingPhoto()
            uploaded.resolvedFor = ResolvedPlaceIdentity(title: requested.title, latitude: coordinate.latitude, longitude: coordinate.longitude, category: requested.category, address: requested.address)
            uploaded.generatedSource = local.source
            pendingPhotoID = uploaded.id
            place.image = .uploaded(uploaded)
            place.gallery = []
            searchError = nil
        } catch {
            guard isCurrentImageOperation(generation) else { return }
            searchError = "Die Apple-Karten-Vorschau konnte nicht gespeichert werden."
        }
    }

    private func beginPhotoImport(_ item: PhotosPickerItem) {
        imageTask?.cancel()
        photoTask?.cancel()
        imageGeneration += 1
        photoGeneration += 1
        imageSearching = false
        pendingImageSearch = nil
        let generation = photoGeneration
        photoTask = Task { await importPhoto(item, generation: generation) }
    }

    private func importPhoto(_ item: PhotosPickerItem, generation: Int) async {
        do {
            guard !editorFinished, !Task.isCancelled, photoGeneration == generation else { return }
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            guard !editorFinished, !Task.isCancelled, photoGeneration == generation else { return }
            let uploaded = try PlaceImageStorage.save(data, root: store.root)
            guard !editorFinished, !Task.isCancelled, photoGeneration == generation else {
                PlaceImageStorage.remove(uploaded, root: store.root)
                return
            }
            if let pendingPhotoID {
                PlaceImageStorage.remove(.init(id: pendingPhotoID, storagePath: nil, pixelWidth: 0, pixelHeight: 0), root: store.root)
            }
            place.image = .uploaded(uploaded)
            place.gallery = []
            pendingPhotoID = uploaded.id
            searchError = nil
        } catch {
            guard !editorFinished, photoGeneration == generation, !Task.isCancelled else { return }
            searchError = "Das Foto konnte nicht gespeichert werden."
        }
    }

    func cancel() {
        endEditor(preservePendingPhoto: false)
        dismiss()
    }

    private func finishEditorIfNeeded() {
        guard !editorFinished else { return }
        endEditor(preservePendingPhoto: false)
    }

    /// Beendet alle laufenden Editor-Operationen. Ein erfolgreicher Save übernimmt
    /// das verwaltete Foto in den Store; Cancel/externes Verschwinden räumt es auf.
    private func endEditor(preservePendingPhoto: Bool) {
        guard !editorFinished else { return }
        editorFinished = true
        searchGeneration += 1
        enrichGeneration += 1
        imageGeneration += 1
        photoGeneration += 1
        searchTask?.cancel()
        imageTask?.cancel()
        photoTask?.cancel()
        searchTask = nil
        imageTask = nil
        photoTask = nil
        searching = false
        enriching = false
        imageSearching = false
        pendingImageSearch = nil
        imageChoices = nil
        if preservePendingPhoto {
            // Nur das aktuell gespeicherte Pending-Foto gehört nach Save weiter
            // zum Ort. Ein vorheriger Fallback darf nach Bildwechsel/Entfernen
            // nicht als verwaiste Datei liegen bleiben.
            if let pendingPhotoID,
               case .uploaded(let selected) = place.image,
               selected.id == pendingPhotoID {
                self.pendingPhotoID = nil
            } else {
                removePendingPhoto()
            }
        } else {
            removePendingPhoto()
        }
    }

    func removePendingPhoto() {
        guard let pendingPhotoID else { return }
        PlaceImageStorage.remove(.init(id: pendingPhotoID, storagePath: nil, pixelWidth: 0, pixelHeight: 0), root: store.root)
        self.pendingPhotoID = nil
    }
}

enum SourceMetadataPolicy {
    /// Übernimmt nur verwaltete Linkdaten. Der Ort selbst bleibt immer eine bewusste Auswahl aus MapKit.
    static func apply(
        _ preview: OEmbedService.Preview,
        pageURL: URL,
        to place: inout Place,
        query: inout String,
        queryWasUnchanged: Bool
    ) -> Bool {
        let previewTitle = preview.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentTitle = place.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if (currentTitle.isEmpty || place.title == "Neue Reiseidee"), !previewTitle.isEmpty {
            place.title = previewTitle
        }

        switch place.image {
        case nil, .linkPreview:
            place.image = .linkPreview(
                pageURL: pageURL.absoluteString,
                thumbnailURL: preview.thumbnail_url,
                credit: place.sourceLabel
            )
        case .bundled, .external, .uploaded:
            break
        }
        if let author = preview.author_name, place.note.isEmpty { place.note = "Quelle: \(author)" }
        if let description = preview.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty, place.note.isEmpty {
            place.note = description
        }

        guard place.coordinate == nil, queryWasUnchanged else { return false }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = place.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty, !title.isEmpty, place.title != "Neue Reiseidee" {
            query = title
            return true
        }
        return !title.isEmpty && trimmedQuery.localizedCaseInsensitiveCompare(title) == .orderedSame
    }
}

struct OEmbedService {
    struct Preview: Decodable, Equatable {
        var title: String
        var thumbnail_url: String?
        var author_name: String?
        var description: String?

        init(title: String, thumbnail_url: String? = nil, author_name: String? = nil, description: String? = nil) {
            self.title = title
            self.thumbnail_url = thumbnail_url
            self.author_name = author_name
            self.description = description
        }

        private enum CodingKeys: String, CodingKey { case title, thumbnail_url, author_name, description }

        var conciseTitle: String {
            OEmbedService.conciseTitle(title)
        }

        var meaningful: Bool {
            !conciseTitle.isEmpty || !(thumbnail_url?.isEmpty ?? true) || !(description?.isEmpty ?? true)
        }
    }

    enum PreviewError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            "Die Link-Vorschau ist gerade nicht verfügbar. Titel und Ort kannst du direkt ergänzen."
        }
    }

    static func preview(_ url: URL) async throws -> Preview {
        #if DEBUG
        if let title = ProcessInfo.processInfo.environment["ALBUM_LINK_PREVIEW_TITLE"] {
            return Preview(
                title: title,
                thumbnail_url: ProcessInfo.processInfo.environment["ALBUM_LINK_PREVIEW_IMAGE"],
                author_name: ProcessInfo.processInfo.environment["ALBUM_LINK_PREVIEW_AUTHOR"],
                description: ProcessInfo.processInfo.environment["ALBUM_LINK_PREVIEW_DESCRIPTION"]
            )
        }
        #endif
        let host = url.host?.lowercased() ?? ""
        if host == "share.google" {
            do {
                let response = try await fetchHTML(url)
                guard let title = PlaceLinkMetadata.placeName(from: response.url) else {
                    throw PreviewError.unavailable
                }
                return Preview(title: title)
            } catch {
                if Task.isCancelled { throw error }
                throw PreviewError.unavailable
            }
        }
        if let title = PlaceLinkMetadata.placeName(from: url) {
            return Preview(title: title)
        }
        if PlaceLinkMetadata.isMapProviderURL(url) { throw PreviewError.unavailable }
        let isTikTok = host == "tiktok.com" || host.hasSuffix(".tiktok.com")
        if isTikTok {
            do {
                return try await tiktokOEmbed(for: url)
            } catch {
                if Task.isCancelled { throw error }
                // Short TikTok URLs often have no oEmbed record. Resolve the redirect
                // and use the public HTML metadata as a bounded, unauthenticated fallback.
                guard !Task.isCancelled else { throw CancellationError() }
                if let html = try? await fetchHTML(url) {
                    guard !Task.isCancelled else { throw CancellationError() }
                    if html.url != url, let preview = try? await tiktokOEmbed(for: html.url), preview.meaningful { return preview }
                    if let preview = parseHTMLPreview(html.data, baseURL: html.url), preview.meaningful { return normalized(preview) }
                }
                throw PreviewError.unavailable
            }
        }

        if let html = try? await fetchHTML(url), let preview = parseHTMLPreview(html.data, baseURL: html.url), preview.meaningful {
            return normalized(preview)
        }
        guard !Task.isCancelled else { throw CancellationError() }
        do {
            let metadata = try await LPMetadataProvider().startFetchingMetadata(for: url)
            let title = clean(metadata.title)
            guard let title, !isBlockedMetadata(title) else { throw PreviewError.unavailable }
            return Preview(title: title)
        } catch {
            if Task.isCancelled { throw error }
            throw PreviewError.unavailable
        }
    }

    // Kept internal for deterministic parser tests and for callers that need to
    // inspect a preview without making a network request.
    static func parseHTMLPreview(_ data: Data, baseURL: URL) -> Preview? {
        guard data.count <= 2_000_000, let html = String(data: data, encoding: .utf8) else { return nil }
        let tags = metaTags(in: html)
        let ogTitle = firstMeta(["og:title", "twitter:title"], tags: tags)
        let titleTag = html.match(#"(?is)<title\b[^>]*>(.*?)</title>"#).map { decodeEntities(stripTags($0)) }
        let title = clean(ogTitle ?? titleTag)
        let description = clean(firstMeta(["og:description", "twitter:description", "description"], tags: tags))
        let image = resolvedURL(firstMeta(["og:image", "twitter:image", "twitter:image:src"], tags: tags), baseURL: baseURL)
        let author = clean(firstMeta(["author", "article:author", "twitter:creator"], tags: tags))
        if let title, isBlockedMetadata(title) { return nil }
        guard title != nil || description != nil || image != nil else { return nil }
        return Preview(title: title ?? "", thumbnail_url: image, author_name: author, description: description)
    }

    static func conciseTitle(_ raw: String) -> String {
        let value = decodeEntities(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }
        let first = value.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? value
        let sentence = first.split(whereSeparator: { ".!?".contains($0) }).first.map(String.init) ?? first
        let result = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.count <= 80 { return result }
        let prefix = String(result.prefix(80))
        if let cut = prefix.lastIndex(where: { $0 == " " || $0 == ":" || $0 == "," }) {
            return String(prefix[..<cut]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct HTMLResponse { let data: Data; let url: URL }

    private static func requestData(_ url: URL, accept: String) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("Album/1.0", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else { throw PreviewError.unavailable }
        var data = Data()
        let expected = http.expectedContentLength > 0 ? Int(http.expectedContentLength) : 0
        data.reserveCapacity(min(expected, 2_000_000))
        for try await byte in bytes {
            try Task.checkCancellation()
            data.append(byte)
            if data.count > 2_000_000 { throw PreviewError.unavailable }
        }
        return (data, response)
    }

    private static func tiktokOEmbed(for url: URL) async throws -> Preview {
        var components = URLComponents(string: "https://www.tiktok.com/oembed")!
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        let (data, _) = try await requestData(components.url!, accept: "application/json")
        guard let decoded = try? JSONDecoder().decode(Preview.self, from: data), decoded.meaningful else { throw PreviewError.unavailable }
        return normalized(decoded)
    }

    private static func fetchHTML(_ url: URL) async throws -> HTMLResponse {
        let (data, response) = try await requestData(url, accept: "text/html,application/xhtml+xml")
        guard let resolved = response.url else { throw PreviewError.unavailable }
        return HTMLResponse(data: data, url: resolved)
    }

    private static func normalized(_ preview: Preview) -> Preview {
        let full = decodeEntities(preview.title).trimmingCharacters(in: .whitespacesAndNewlines)
        let short = conciseTitle(full)
        var description = preview.description.map { decodeEntities($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        if description?.isEmpty == true { description = nil }
        if full.count > short.count, (description ?? "").isEmpty { description = full }
        return Preview(title: short.isEmpty ? full : short, thumbnail_url: preview.thumbnail_url, author_name: preview.author_name, description: description)
    }

    private static func metaTags(in html: String) -> [String: String] {
        var result: [String: String] = [:]
        for tag in html.matches(#"(?is)<meta\b[^>]*>"#) {
            let attributes = attributes(in: tag)
            guard let key = (attributes["property"] ?? attributes["name"] ?? attributes["itemprop"])?.lowercased(), let value = attributes["content"] else { continue }
            result[key] = decodeEntities(value).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    private static func attributes(in tag: String) -> [String: String] {
        var result: [String: String] = [:]
        guard let expression = try? NSRegularExpression(pattern: #"(?is)([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))"#) else { return result }
        let range = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        for match in expression.matches(in: tag, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: tag) else { continue }
            let valueRange = (2...4).compactMap { Range(match.range(at: $0), in: tag) }.first
            guard let valueRange else { continue }
            result[String(tag[keyRange]).lowercased()] = String(tag[valueRange])
        }
        return result
    }

    private static func firstMeta(_ keys: [String], tags: [String: String]) -> String? { keys.lazy.compactMap { tags[$0] }.first }
    private static func resolvedURL(_ raw: String?, baseURL: URL) -> String? {
        guard let raw = clean(raw), !raw.isEmpty, !raw.lowercased().hasPrefix("data:") else { return nil }
        guard let url = URL(string: raw, relativeTo: baseURL)?.absoluteURL,
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url.absoluteString
    }
    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let text = decodeEntities(stripTags(value)).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
    private static func stripTags(_ value: String) -> String { value.replacingOccurrences(of: #"(?is)<[^>]+>"#, with: " ", options: .regularExpression) }
    private static func isBlockedMetadata(_ value: String) -> Bool {
        let lower = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return ["log in", "login", "sign in", "anmelden", "challenge", "captcha", "verify", "zugriff verweigert", "access denied"].contains { lower.contains($0) }
    }
    private static func decodeEntities(_ value: String) -> String {
        var result = value
        let entities = [
            "&amp;":"&", "&quot;":"\"", "&#39;":"'", "&apos;":"'", "&lt;":"<", "&gt;":">", "&nbsp;":" ",
            "&eacute;":"é", "&Eacute;":"É", "&ouml;":"ö", "&Ouml;":"Ö", "&uuml;":"ü", "&Uuml;":"Ü",
            "&ccaron;":"č", "&Ccaron;":"Č", "&scaron;":"š", "&Scaron;":"Š", "&mdash;":"—", "&ndash;":"–", "&hellip;":"…",
            "&ldquo;":"“", "&rdquo;":"”", "&lsquo;":"‘", "&rsquo;":"’"
        ]
        for (key, replacement) in entities { result = result.replacingOccurrences(of: key, with: replacement) }
        for match in result.matches(#"&#x([0-9a-fA-F]+);"#) where match.count > 4 {
            let hex = String(match.dropFirst(3).dropLast())
            if let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) { result = result.replacingOccurrences(of: match, with: String(Character(scalar))) }
        }
        for match in result.matches(#"&#(\d+);"#) where match.count > 3 {
            if let value = UInt32(match.dropFirst(2).dropLast()), let scalar = UnicodeScalar(value) { result = result.replacingOccurrences(of: match, with: String(Character(scalar))) }
        }
        return result
    }
}

private extension String {
    func matches(_ pattern: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..<endIndex, in: self)
        return expression.matches(in: self, range: range).compactMap { Range($0.range, in: self).map { String(self[$0]) } }
    }
    func match(_ pattern: String) -> String? { matches(pattern).first }
}

enum PlaceLinkMetadata {
    private static let googleDomains = [
        "google.com", "google.de", "google.cz", "google.co.uk", "google.at", "google.ch",
        "google.fr", "google.it", "google.es", "google.nl", "google.pl", "google.sk"
    ]

    static func placeName(from url: URL) -> String? {
        var candidate = url
        for depth in 0...3 {
            if candidate.host?.lowercased() == "consent.google.com" {
                guard depth < 3,
                      let destination = queryValue("continue", in: candidate, formEncoded: false),
                      let destinationURL = URL(string: destination),
                      isGoogleHost(destinationURL.host) else { return nil }
                candidate = destinationURL
                continue
            }
            return directPlaceName(from: candidate)
        }
        return nil
    }

    static func isMapProviderURL(_ url: URL) -> Bool {
        if isAppleMapsHost(url.host) || url.host?.lowercased() == "consent.google.com" { return true }
        guard isGoogleHost(url.host) else { return false }
        return url.path == "/search" || url.path.hasPrefix("/search/")
            || url.path == "/maps" || url.path.hasPrefix("/maps/")
            || url.host?.lowercased().hasPrefix("maps.") == true
    }

    private static func directPlaceName(from url: URL) -> String? {
        let path = url.path
        if isGoogleHost(url.host) {
            if path == "/search" || path.hasPrefix("/search/") {
                guard let kgmid = queryValue("kgmid", in: url),
                      !kgmid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return normalized(queryValue("q", in: url))
            }
            guard path == "/maps" || path.hasPrefix("/maps/") || url.host?.lowercased().hasPrefix("maps.") == true else {
                return nil
            }
            let components = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? path)
                .split(separator: "/", omittingEmptySubsequences: true)
                .map { decode(String($0), formEncoded: true) }
            if let placeIndex = components.firstIndex(of: "place"), components.indices.contains(placeIndex + 1),
               let title = normalized(components[placeIndex + 1]) {
                return title
            }
            return normalized(queryValue("q", in: url) ?? queryValue("query", in: url))
        }
        guard isAppleMapsHost(url.host) else { return nil }
        return normalized(queryValue("name", in: url) ?? queryValue("q", in: url))
    }

    private static func isGoogleHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return googleDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private static func isAppleMapsHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "maps.apple.com" || host == "maps.apple.com.cn"
    }

    private static func queryValue(_ name: String, in url: URL, formEncoded: Bool = true) -> String? {
        guard let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery else { return nil }
        for item in query.split(separator: "&", omittingEmptySubsequences: false) {
            let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard decode(String(pair[0]), formEncoded: true) == name, pair.count == 2 else { continue }
            return decode(String(pair[1]), formEncoded: formEncoded)
        }
        return nil
    }

    private static func decode(_ value: String, formEncoded: Bool) -> String {
        let escaped = formEncoded ? value.replacingOccurrences(of: "+", with: " ") : value
        return escaped.removingPercentEncoding ?? escaped
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let title = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.rangeOfCharacter(from: .letters) != nil else { return nil }
        let lower = title.lowercased()
        guard !["google", "google search", "google maps", "maps", "search"].contains(lower),
              !lower.hasPrefix("place_id:"), !lower.hasPrefix("query_place_id:") else { return nil }
        return title
    }
}

private struct ImageChoices: Identifiable {
    let id = UUID()
    let place: Place
    let images: [PlaceImage]
}

private struct PlaceImagePicker: View {
    let choices: ImageChoices
    let root: URL
    let select: (PlaceImage) -> Void
    let streetView: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Stitch.Space.l) {
                    Text("Prüfe, ob das Foto wirklich \(choices.place.title) zeigt.")
                        .font(.subheadline).foregroundStyle(Stitch.inkSoft)
                        .multilineTextAlignment(.center)
                    if choices.images.isEmpty {
                        Text("Kein Ortsfoto gefunden").font(.headline).foregroundStyle(Stitch.ink)
                    }
                    ForEach(Array(choices.images.enumerated()), id: \.offset) { index, image in
                        VStack(spacing: Stitch.Space.xs) {
                            Button { select(image) } label: {
                                VStack(spacing: Stitch.Space.s) {
                                    AlbumPhoto(asset: image.asset(for: choices.place), root: root, thumbnailWidth: 500)
                                        .frame(height: 180).clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.thumb))
                                    Text(image.caption ?? "Ortsfoto").font(.subheadline.weight(.semibold))
                                    if image.confidence != .verified {
                                        Text("Ortszuordnung bitte prüfen").font(.footnote).foregroundStyle(Stitch.inkSoft)
                                    }
                                }
                                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                                .foregroundStyle(Stitch.ink)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("place-image-choice-\(index)")
                            Text(image.credit).font(.footnote).foregroundStyle(Stitch.inkSoft)
                            Link("Quelle ansehen", destination: image.sourceURL)
                                .font(.footnote).frame(minHeight: Stitch.Size.touch)
                            if let licenseName = image.licenseName {
                                Link("Lizenz · \(licenseName)", destination: image.licenseURL ?? image.sourceURL)
                                    .font(.footnote).frame(minHeight: Stitch.Size.touch)
                            }
                        }
                        .stitchCard(padding: Stitch.Space.m)
                    }
                    Button(action: streetView) { Label("Apple-Karten-Vorschau", systemImage: "binoculars") }
                        .buttonStyle(StitchButton())
                }
                .padding(Stitch.Space.page)
            }
            .background(PaperBackground())
            .navigationTitle("Bild wählen").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
    }
}
