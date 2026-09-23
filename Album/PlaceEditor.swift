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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    if !place.sourceURL.isEmpty && LinkValidation.url(place.sourceURL) == nil { Text("Bitte einen vollständigen http(s)-Link eingeben.").foregroundStyle(AlbumStyle.red) }
                    Button(enriching ? "Vorschau wird geladen …" : "Linkvorschau laden") { Task { await enrich() } }.disabled(enriching || LinkValidation.url(place.sourceURL) == nil)
                    Picker("Kategorie", selection: $place.category) { ForEach(categories, id: \.self) { Text($0) } }
                    TextField("Gesammelt von", text: $place.author)
                    TextField("Warum wollen wir hierhin?", text: $place.note, axis: .vertical).lineLimit(3...6)
                }
                Section {
                    HStack {
                        TextField("Ort oder Adresse in Prag", text: $query).submitLabel(.search).onSubmit { search() }
                        Button(action: search) { if searching { ProgressView() } else { Image(systemName: "magnifyingglass") } }.disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching).accessibilityLabel("Ort suchen")
                    }
                    if let searchError { Text(searchError).font(AlbumStyle.body(13)).foregroundStyle(AlbumStyle.red) }
                    ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                        Button {
                            place.title = item.name ?? place.title
                            place.address = item.placemark.title ?? ""
                            place.lat = item.placemark.coordinate.latitude
                            place.lng = item.placemark.coordinate.longitude
                            results = []
                            Task { await findImage(force: false) }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) { Text(item.name ?? "Ort"); Text(item.placemark.title ?? "").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    if place.coordinate != nil {
                        Label(place.address.isEmpty ? "Ort bestätigt" : place.address, systemImage: "checkmark.circle.fill").foregroundStyle(AlbumStyle.red)
                        Button(imageSearching ? "Bild wird gesucht …" : "Bild neu suchen") { Task { await findImage(force: true) } }
                            .disabled(imageSearching)
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Eigenes Foto wählen", systemImage: "photo.on.rectangle")
                        }
                        if place.image != nil {
                            Button("Bild entfernen", role: .destructive) { place.image = nil }
                        }
                    }
                } header: { Text("Auf der Karte bestätigen") } footer: { Text("Wähle den passenden Suchtreffer. Seine Koordinaten werden einmal gespeichert. Damit ein Ort auf die Karte kommt, muss er bestätigt sein.") }
                if place.franked {
                    Section("Planung") {
                        Toggle("Schon besucht", isOn: $place.visited)
                        Picker("Tag", selection: $place.day) {
                            Text("Noch offen").tag(nil as Int?)
                            ForEach(4...9, id: \.self) { Text("\($0). Oktober").tag(Optional($0)) }
                        }
                    }
                }
            }.scrollContentBackground(.hidden).background(LinenBackground())
                .navigationTitle(frankOnSave ? "Ort bestätigen" : "Idee").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { cancel() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") {
                        let isNew = !store.places.contains { $0.id == place.id }
                        if frankOnSave { place.franked = true; place.deferred = false }
                        removeUnusedPendingPhoto()
                        store.upsert(place)
                        pendingPhotoID = nil
                        // Neue Ideen werden sichtbar eingeworfen; gespeichert ist schon vorher.
                        if isNew && !reduceMotion { withAnimation(.easeOut(duration: 0.2)) { posting = true } } else { dismiss() }
                    }.disabled(!valid || posting) }
                }
                .onAppear { query = place.title == "Neue Reiseidee" ? "" : place.title }
                .task {
                    // Aus der Zwischenablage übernommen: Vorschau gleich laden.
                    if place.title.isEmpty, LinkValidation.url(place.sourceURL) != nil { await enrich() }
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
            guard let result = try await PlaceImageService.image(for: place) else {
                searchError = "Kein passendes Bild gefunden."
                return
            }
            place.image = result.asset(for: place)
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
