import SwiftUI
import MapKit

struct CollectionHomeView: View {
    @Environment(AlbumStore.self) private var store
    var add: () -> Void = {}
    @State private var composing = false
    @State private var selected: CollectionEntry?

    var body: some View {
        VStack(spacing: Stitch.Space.s) {
            if store.collectionPosts.isEmpty {
                Spacer()
                Text("Noch nichts gesammelt")
                    .font(Stitch.Face.title(28, relativeTo: .title)).foregroundStyle(Stitch.ink)
                Text("Links und Nachrichten bleiben hier, auch wenn du gerade offline bist.")
                    .font(.body).multilineTextAlignment(.center).foregroundStyle(Stitch.inkSoft)
                    .padding(.horizontal, Stitch.Space.l)
                Button { composing = true } label: { Label("In Sammlung", systemImage: "plus") }
                    .buttonStyle(StitchButton(primary: true))
                Spacer()
            } else {
                List(store.collectionPosts) { post in
                    Button { selected = post } label: { CollectionRow(post: post) }
                        .buttonStyle(.plain)
                        .listRowBackground(Stitch.card)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await store.refreshCollectionMetadataIfNeeded(limit: 12, force: true) }
            }
        }
        .background(PaperBackground())
        .navigationTitle("Sammlung")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("Sammeln", systemImage: "plus") { composing = true } } }
        .sheet(isPresented: $composing) { CollectionComposer() }
        .sheet(item: $selected) { CollectionDetailView(post: $0) }
        // Rechts Platz für den KI-Kreis, sonst liegt er über „Verwerfen“.
        .overlay(alignment: .bottom) { FailedShareQueueView().padding(.trailing, Stitch.Size.touch + Stitch.Space.s) }
        .task { await store.refreshCollectionMetadataIfNeeded(limit: 12) }
    }
}

private struct CollectionRow: View {
    @Environment(AlbumStore.self) private var store
    let post: CollectionEntry
    var body: some View {
        HStack(alignment: .top, spacing: Stitch.Space.s) {
            CollectionPreviewImage(url: post.thumbnailURL.flatMap(URL.init), fallback: post.url == nil ? "text.quote" : "link")
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                Text(post.displayTitle ?? post.text ?? "Gesammelter Beitrag")
                    .font(.headline).foregroundStyle(Stitch.ink).lineLimit(2)
                if let caption = post.caption, !caption.isEmpty { Text(caption).font(.subheadline).foregroundStyle(Stitch.inkSoft).lineLimit(2) }
                Text("Von \(post.authorName) · \(post.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(Stitch.inkSoft)
                let count = store.collectionHeartCount(for: post.id)
                if count > 0 { Label("\(count)", systemImage: "heart.fill").font(.caption).foregroundStyle(Stitch.red) }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Stitch.Space.xs)
        .accessibilityIdentifier("Collection-Post-\(post.id)")
    }
}

struct CollectionComposer: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var url = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Link oder Nachricht") {
                    TextField("https://…", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("Collection-URL")
                    TextField("Nachricht", text: $text, axis: .vertical).lineLimit(3...8).accessibilityIdentifier("Collection-Message")
                }
                if let error { Text(error).foregroundStyle(Stitch.red).font(.footnote) }
            }
            .scrollContentBackground(.hidden).background(PaperBackground())
            .navigationTitle("Sammeln")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { save() }.accessibilityIdentifier("Collection-Save").disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }

    private func save() {
        do {
            let post = try store.addCollectionPost(text: text, url: url.isEmpty ? nil : url)
            dismiss()
            if post.url != nil { Task { await store.refreshCollectionMetadata(for: post.id) } }
        } catch { self.error = error.localizedDescription }
    }
}

struct CollectionDetailView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let post: CollectionEntry
    @State private var comment = ""
    @State private var addingPlace: Place?
    @State private var selectedPlace: Place?
    @State private var error: String?
    @State private var confirmDelete = false
    @State private var placeCandidates: [CollectionPlaceSuggestion] = []
    @State private var findingPlaces = false
    @State private var placeSearchTask: Task<Void, Never>?
    @State private var placesSearched = false
    @State private var refreshingPreview = false
    @State private var captionExpanded = false
    private var livePost: CollectionEntry { store.data.collectionEntries.first(where: { $0.id == post.id }) ?? post
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.m) {
                    Text(livePost.displayTitle ?? (livePost.url == nil ? "Gesammelte Nachricht" : "Gesammelter Beitrag")).font(Stitch.Face.title(30, relativeTo: .title)).foregroundStyle(Stitch.ink)
                    if let thumbnail = livePost.thumbnailURL.flatMap(URL.init) {
                        CollectionPreviewImage(url: thumbnail, fallback: "link")
                            .frame(maxWidth: .infinity).frame(height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.card))
                            .accessibilityLabel("Link-Vorschau")
                    }
                    if let caption = livePost.caption, !caption.isEmpty {
                        Text(caption).font(.body).foregroundStyle(Stitch.ink).lineLimit(captionExpanded ? nil : 6)
                        if caption.count > 420 {
                            Button(captionExpanded ? "Weniger anzeigen" : "Mehr anzeigen") { captionExpanded.toggle() }
                                .font(.footnote.weight(.medium)).foregroundStyle(Stitch.red)
                        }
                    }
                    if livePost.url != nil {
                        Button(refreshingPreview ? "Vorschau wird geladen …" : "Vorschau aktualisieren") { refreshPreview() }
                            .font(.footnote.weight(.medium)).foregroundStyle(Stitch.red).disabled(refreshingPreview)
                            .accessibilityIdentifier("Collection-Refresh-Preview")
                    }
                    if let text = livePost.text, !text.isEmpty { Text(text).font(.body).foregroundStyle(Stitch.inkSoft) }
                    if let rawURL = livePost.url, let url = URL(string: rawURL) { Link(destination: url) { Label("Quelle öffnen", systemImage: "arrow.up.right.square") }.font(.body.weight(.medium)) }
                    if dynamicTypeSize.isAccessibilitySize {
                        actionButtons(axis: .vertical)
                    } else {
                        ViewThatFits(in: .horizontal) {
                            actionButtons(axis: .horizontal)
                            actionButtons(axis: .vertical)
                        }
                    }
                    if !store.collectionPlaces(for: livePost.id).isEmpty {
                        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                            Text("Orte").font(.headline)
                            ForEach(store.collectionPlaces(for: livePost.id)) { place in
                                HStack {
                                    Button(place.title) { selectedPlace = place }.font(.body)
                                    Spacer()
                                    Button("Lösen") { unlink(place) }.font(.caption)
                                }
                            }
                        }
                    }
                    placeSuggestionSection
                    VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                        Text("Kommentare").font(.headline)
                        ForEach(store.collectionComments(for: livePost.id)) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) { Text(item.authorName).font(.caption.weight(.semibold)); Text(item.text ?? "").font(.body) }
                                Spacer()
                                Menu {
                                    Button("Kommentar löschen", role: .destructive) { deleteComment(item) }
                                } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("Kommentaroptionen") }
                            }
                            .padding(.vertical, Stitch.Space.xxs)
                        }
                        HStack { TextField("Kommentar", text: $comment).accessibilityIdentifier("Collection-Comment"); Button("Senden") { addComment() }.accessibilityIdentifier("Collection-Comment-Send").disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                    }
                    if let error { Text(error).foregroundStyle(Stitch.red).font(.footnote) }
                }
                .padding(Stitch.Space.page)
            }
            .background(PaperBackground())
            .navigationTitle("Beitrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Beitrag löschen", systemImage: "trash", role: .destructive) { confirmDelete = true } }
            }
            .confirmationDialog("Diesen Beitrag löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { deletePost() }
            }
            .sheet(item: $addingPlace) { draft in
                PlaceEditor(place: draft, autoSourceEnrichment: false) { saved in
                    do { _ = try store.linkCollectionPlace(postID: livePost.id, placeID: saved.id) } catch { self.error = error.localizedDescription }
                }
            }
            .sheet(item: $selectedPlace) { place in PlaceDetail(placeID: place.id) }
            .onDisappear { placeSearchTask?.cancel() }
            .onChange(of: livePost.id) { _, _ in
                placeSearchTask?.cancel(); placeCandidates = []; placesSearched = false
            }
        }
    }

    @ViewBuilder private var placeSuggestionSection: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            HStack {
                Text("Orte aus dem Beitrag").font(.headline)
                Spacer()
                Button(findingPlaces ? "Suche …" : "Orte erkennen") { findPlaces() }
                    .font(.footnote.weight(.semibold)).disabled(findingPlaces)
            }
            if findingPlaces { ProgressView().controlSize(.small) }
            if placesSearched && placeCandidates.isEmpty {
                Text("Kein Ort erkannt").font(.subheadline).foregroundStyle(Stitch.inkSoft)
            }
            ForEach(placeCandidates) { suggestion in
                Button {
                    let draft = Place(title: suggestion.name, note: "Aus dem Beitrag erkannt: \(suggestion.candidate.query)", sourceURL: livePost.url ?? "", author: store.me, address: suggestion.address, lat: suggestion.coordinate.latitude, lng: suggestion.coordinate.longitude)
                    addingPlace = draft
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.name).font(.body.weight(.medium)).foregroundStyle(Stitch.ink)
                        if !suggestion.address.isEmpty { Text(suggestion.address).font(.caption).foregroundStyle(Stitch.inkSoft) }
                        Text("Als Ort speichern").font(.caption.weight(.semibold)).foregroundStyle(Stitch.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Stitch.Space.xxs)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private func actionButtons(axis: Axis.Set) -> some View {
        if axis == .horizontal {
            HStack {
                heartButton
                placeButton
            }
        } else {
            VStack(alignment: .leading) {
                heartButton
                placeButton
            }
        }
    }

    private var heartButton: some View {
        Button { toggleHeart() } label: { Label(store.collectionIsHearted(livePost.id) ? "Herz entfernen" : "Herz geben", systemImage: store.collectionIsHearted(livePost.id) ? "heart.fill" : "heart") }.buttonStyle(StitchButton())
            .accessibilityValue("\(store.collectionHeartCount(for: livePost.id)) Herzen")
            .accessibilityIdentifier("Collection-Heart")
    }

    private var placeButton: some View {
        Button { addingPlace = Place(title: "", sourceURL: livePost.url ?? "", author: store.me) } label: { Label("Ort hinzufügen", systemImage: "mappin.and.ellipse") }.buttonStyle(StitchButton(primary: true))
            .accessibilityIdentifier("Collection-Add-Place")
    }

    private func toggleHeart() { do { _ = try store.setCollectionHeart(postID: livePost.id, active: !store.collectionIsHearted(livePost.id)) } catch { self.error = error.localizedDescription } }
    private func addComment() { do { _ = try store.addCollectionComment(postID: livePost.id, text: comment); comment = "" } catch { self.error = error.localizedDescription } }
    private func unlink(_ place: Place) { do { _ = try store.unlinkCollectionPlace(postID: livePost.id, placeID: place.id) } catch { self.error = error.localizedDescription } }
    private func deleteComment(_ item: CollectionEntry) { do { _ = try store.tombstoneCollectionEntry(id: item.id) } catch { self.error = error.localizedDescription } }
    private func deletePost() { do { _ = try store.tombstoneCollectionEntry(id: livePost.id); dismiss() } catch { self.error = error.localizedDescription } }

    private func findPlaces() {
        placeSearchTask?.cancel()
        let id = livePost.id
        let sharedText = [livePost.text] + store.collectionComments(for: id).compactMap(\.text)
        let candidates = CollectionPlaceExtractor.candidates(title: livePost.displayTitle, caption: livePost.caption, comments: sharedText.compactMap { $0 })
        findingPlaces = true; placesSearched = true; placeCandidates = []
        placeSearchTask = Task { @MainActor in
            let resolved = await CollectionPlaceResolver.resolve(candidates, around: store.hotelCoordinate, limit: 6)
            guard !Task.isCancelled, livePost.id == id else { return }
            placeCandidates = resolved; findingPlaces = false
        }
    }

    private func refreshPreview() {
        refreshingPreview = true
        Task { @MainActor in
            await store.refreshCollectionMetadata(for: livePost.id, force: true)
            guard !Task.isCancelled else { return }
            refreshingPreview = false
        }
    }
}

private struct CollectionPreviewImage: View {
    let url: URL?
    let fallback: String
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { fallbackView }
                }
            } else { fallbackView }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Stitch.paper)
    }
    private var fallbackView: some View {
        Image(systemName: fallback).font(.title2).foregroundStyle(Stitch.inkSoft.opacity(0.7))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Stitch.paper)
    }
}

private struct FailedShareQueueView: View {
    @Environment(AlbumStore.self) private var store
    @State private var item: ShareQueueItem?
    var body: some View {
        Group {
            if let item {
                HStack {
                    Text("Geteilten Beitrag nicht importiert").font(.footnote)
                    Spacer()
                    Button("Erneut versuchen") {
                        var retry = item
                        retry.state = .pending; retry.lastErrorCode = nil
                        do { try store.shareInbox.update(retry); self.item = nil; store.drainShareQueue() }
                        catch { store.shareQueueError = error.localizedDescription }
                    }.font(.footnote.weight(.semibold))
                    Button("Verwerfen", role: .destructive) {
                        do { try store.shareInbox.remove(item); self.item = nil; store.shareQueueRevision += 1 }
                        catch { store.shareQueueError = error.localizedDescription }
                    }.font(.footnote)
                }
                .padding(Stitch.Space.s).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 12)).padding(Stitch.Space.s)
            } else if let error = store.shareQueueError {
                Text(error).font(.footnote).padding(Stitch.Space.s).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 12)).padding(Stitch.Space.s)
            }
        }
        .task { reload() }
        .onChange(of: store.shareQueueRevision) { _, _ in reload() }
    }

    private func reload() { item = store.shareInbox.items().first(where: { $0.state == .failed }) }
}
