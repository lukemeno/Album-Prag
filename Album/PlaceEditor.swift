import SwiftUI
import MapKit
import PhotosUI
import LinkPresentation

struct PlaceEditor: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var place: Place
    var frankOnSave = false
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var enriching = false
    @State private var imageSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingPhotoID: String?
    @State private var posting = false
    let categories = ["Idee", "Sehenswert", "Essen & Trinken", "Aussicht", "Unterkunft", "Shopping"]
    var valid: Bool {
        !place.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (place.sourceURL.isEmpty || LinkValidation.url(place.sourceURL) != nil) && (!frankOnSave || place.coordinate != nil)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Idee") {
                    TextField("Name der Idee", text: $place.title)
                    TextField("Link von TikTok, Instagram …", text: $place.sourceURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !place.sourceURL.isEmpty && LinkValidation.url(place.sourceURL) == nil {
                        Text("Der Link muss mit https:// beginnen.").font(.footnote).foregroundStyle(Stitch.red)
                    }
                    if enriching {
                        Label { Text("Vorschau wird geladen …") } icon: { ProgressView() }.foregroundStyle(Stitch.inkSoft)
                    }
                    Picker("Kategorie", selection: $place.category) { ForEach(categories, id: \.self) { Text($0) } }
                    TextField("Warum da hin?", text: $place.note, axis: .vertical).lineLimit(3...6)
                }
                .listRowBackground(Stitch.card)
                Section {
                    HStack {
                        TextField("Ort oder Adresse in Prag", text: $query).submitLabel(.search).onSubmit { search() }
                        Button(action: search) { if searching { ProgressView() } else { Image(systemName: "magnifyingglass") } }.disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching).accessibilityLabel("Ort suchen")
                    }
                    if let searchError { Text(searchError).font(.footnote).foregroundStyle(Stitch.red) }
                    ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                        Button {
                            place.title = item.name ?? place.title
                            place.address = item.placemark.title ?? ""
                            place.lat = item.placemark.coordinate.latitude
                            place.lng = item.placemark.coordinate.longitude
                            results = []
                            Task { await findImage(force: false) }
                        } label: {
                            VStack(alignment: .leading, spacing: Stitch.Space.xxs) { Text(item.name ?? "Ort"); Text(item.placemark.title ?? "").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    if place.coordinate != nil {
                        Label(place.address.isEmpty ? "Ort gefunden" : place.address, systemImage: "checkmark.circle.fill").foregroundStyle(Stitch.red)
                        Button(imageSearching ? "Bild wird gesucht …" : "Bild neu suchen") { Task { await findImage(force: true) } }
                            .disabled(imageSearching)
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Eigenes Foto wählen", systemImage: "photo.on.rectangle")
                        }
                        if place.image != nil {
                            Button("Bild entfernen", role: .destructive) { place.image = nil }
                        }
                    }
                } header: { Text("Ort") } footer: { Text("Such den Ort, damit er auf der Karte erscheint.") }
                .listRowBackground(Stitch.card)
                if place.franked {
                    Section("Planung") {
                        Toggle("Schon besucht", isOn: $place.visited)
                        Picker("Tag", selection: $place.day) {
                            Text("Noch offen").tag(nil as Int?)
                            ForEach(4...9, id: \.self) { Text(TripDates.dayTitle($0)).tag(Optional($0)) }
                        }
                    }
                    .listRowBackground(Stitch.card)
                }
            }.scrollContentBackground(.hidden).background(LinenBackground())
                .navigationTitle(frankOnSave ? "Wo ist das?" : "Idee").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { cancel() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") {
                        let isNew = !store.places.contains { $0.id == place.id }
                        if frankOnSave { place = store.decided(place, approve: true) }
                        removeUnusedPendingPhoto()
                        store.upsert(place)
                        pendingPhotoID = nil
                        // Neue Ideen werden sichtbar eingeworfen; gespeichert ist schon vorher.
                        if isNew { withAnimation(.easeOut(duration: 0.2)) { posting = true } } else { dismiss() }
                    }.disabled(!valid || posting) }
                }
                .onAppear { query = place.title == "Neue Reiseidee" ? "" : place.title }
                .task(id: place.sourceURL) {
                    // Gültiger Link: Vorschau von selbst laden, kurz nach dem Tippen.
                    guard place.image == nil || place.title.isEmpty, LinkValidation.url(place.sourceURL) != nil else { return }
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    await enrich()
                }
                .overlay { if posting { LetterSlotDrop(place: place, root: store.root) { dismiss() }.transition(.opacity) } }
                .onDisappear { searchTask?.cancel() }
                .onChange(of: photoItem) { _, item in
                    guard let item else { return }
                    Task { await importPhoto(item) }
                }
        }
    }
    func search() {
        searchTask?.cancel()
        let currentQuery = query
        searching = true; searchError = nil
        searchTask = Task { @MainActor in
            defer { searching = false }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = currentQuery + " Prag"
            request.region = MKCoordinateRegion(center: .init(latitude: 50.087, longitude: 14.423), span: .init(latitudeDelta: 0.15, longitudeDelta: 0.15))
            do {
                let response = try await MKLocalSearch(request: request).start()
                try Task.checkCancellation()
                results = response.mapItems
                if results.isEmpty { searchError = "Kein Treffer. Bitte Name oder Adresse ergänzen." }
            } catch { if !Task.isCancelled { searchError = "Ortssuche fehlgeschlagen. Bitte erneut versuchen." } }
        }
    }
    func enrich() async {
        guard let url = LinkValidation.url(place.sourceURL) else { return }
        enriching = true; defer { enriching = false }
        do {
            let preview = try await OEmbedService.preview(url)
            if place.title.isEmpty || place.title == "Neue Reiseidee" { place.title = preview.title }
            place.image = .linkPreview(pageURL: url.absoluteString, thumbnailURL: preview.thumbnail_url, credit: place.sourceLabel)
            if let author = preview.author_name, place.note.isEmpty { place.note = "Quelle: \(author)" }
        } catch { searchError = error.localizedDescription }
    }

    func findImage(force: Bool) async {
        guard !imageSearching, PlaceImageService.shouldSearch(for: place, force: force) else { return }
        imageSearching = true; defer { imageSearching = false }
        do {
            let found = try await PlaceImageService.images(for: place)
            if let result = found.first {
                place.image = result.asset(for: place)
                place.gallery = PlaceImageService.gallery(from: found, for: place)
            } else if let coordinate = place.coordinate, let data = await PlaceImageResolver.lookAroundSnapshot(at: coordinate) {
                // Kein Wikimedia-Foto: Straßenansicht genau an diesem Ort.
                let uploaded = try PlaceImageStorage.save(data, root: store.root)
                pendingPhotoID = uploaded.id
                place.image = .uploaded(uploaded)
            } else {
                searchError = "Kein passendes Bild gefunden."
                return
            }
            searchError = nil
        } catch {
            searchError = "Bildsuche fehlgeschlagen. Bitte erneut versuchen."
        }
    }

    func importPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            if let pendingPhotoID {
                PlaceImageStorage.remove(.init(id: pendingPhotoID, storagePath: nil, pixelWidth: 0, pixelHeight: 0), root: store.root)
            }
            let uploaded = try PlaceImageStorage.save(data, root: store.root)
            place.image = .uploaded(uploaded)
            pendingPhotoID = uploaded.id
            searchError = nil
        } catch { searchError = "Das Foto konnte nicht gespeichert werden." }
    }

    func cancel() {
        removePendingPhoto()
        dismiss()
    }

    func removeUnusedPendingPhoto() {
        guard let pendingPhotoID else { return }
        guard case .uploaded(let selected) = place.image, selected.id == pendingPhotoID else {
            removePendingPhoto()
            return
        }
    }

    func removePendingPhoto() {
        guard let pendingPhotoID else { return }
        PlaceImageStorage.remove(.init(id: pendingPhotoID, storagePath: nil, pixelWidth: 0, pixelHeight: 0), root: store.root)
        self.pendingPhotoID = nil
    }
}

struct OEmbedService {
    struct Preview: Decodable { var title: String; var thumbnail_url: String?; var author_name: String? }
    static func preview(_ url: URL) async throws -> Preview {
        let host = url.host?.lowercased() ?? ""
        guard host == "tiktok.com" || host.hasSuffix(".tiktok.com") else {
            let metadata = try await LPMetadataProvider().startFetchingMetadata(for: url)
            return Preview(title: metadata.title ?? url.host ?? "Reiseidee", thumbnail_url: nil, author_name: nil)
        }
        var components = URLComponents(string: "https://www.tiktok.com/oembed")!
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: components.url!, timeoutInterval: 15))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "Album", code: 4, userInfo: [NSLocalizedDescriptionKey: "Die Vorschau ist nicht verfügbar. Titel und Ort kannst du direkt ergänzen."])
        }
        return try JSONDecoder().decode(Preview.self, from: data)
    }
}
