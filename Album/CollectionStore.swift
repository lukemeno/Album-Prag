import Foundation

enum CollectionStoreError: LocalizedError, Equatable {
    case emptyPost
    case invalidURL
    case missingPost
    case emptyComment
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .emptyPost: return "Bitte eine Nachricht oder einen Link eingeben."
        case .invalidURL: return "Der Link muss mit http:// oder https:// beginnen."
        case .missingPost: return "Dieser Beitrag ist nicht mehr verfügbar."
        case .emptyComment: return "Bitte einen Kommentar eingeben."
        case .persistenceFailed: return "Der Beitrag konnte lokal nicht gespeichert werden."
        }
    }
}

@MainActor
extension AlbumStore {
    var participantID: String { collectionParticipantIDOverride ?? CollectionIdentity.participantID() }

    var collectionPosts: [CollectionEntry] {
        data.collectionEntries
            .filter { $0.kind == .post && !$0.deleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func collectionComments(for postID: String) -> [CollectionEntry] {
        data.collectionEntries
            .filter { $0.kind == .comment && $0.postID == postID && !$0.deleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func collectionPlaces(for postID: String) -> [Place] {
        let ids = Set(data.collectionEntries.filter { $0.kind == .placeLink && $0.postID == postID && !$0.deleted && $0.active != false }.compactMap(\.placeID))
        return places.filter { ids.contains($0.id) }
    }

    func collectionHeartCount(for postID: String) -> Int {
        data.collectionEntries.filter { $0.kind == .reaction && $0.postID == postID && $0.active == true && !$0.deleted }.count
    }

    func collectionIsHearted(_ postID: String) -> Bool {
        data.collectionEntries.contains { $0.kind == .reaction && $0.postID == postID && $0.authorID == participantID && $0.active == true && !$0.deleted }
    }

    @discardableResult
    func addCollectionPost(text: String, url: String? = nil, caption: String? = nil, deterministicID: String? = nil) throws -> CollectionEntry {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanURL = url?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty || !(cleanURL ?? "").isEmpty else { throw CollectionStoreError.emptyPost }
        var canonicalURL: URL?
        if let cleanURL, !cleanURL.isEmpty {
            guard let canonical = CollectionURL.canonicalize(cleanURL) else { throw CollectionStoreError.invalidURL }
            canonicalURL = canonical
        }
        let id: String
        let neutralTitle: String?
        if let canonicalURL {
            id = CollectionURL.postID(for: canonicalURL.absoluteString)!
            neutralTitle = CollectionURL.neutralTitle(for: canonicalURL)
        } else {
            id = deterministicID.map { "post-text-\($0)" } ?? "post-text-\(UUID().uuidString)"
            neutralTitle = nil
        }
        let captionSource: String? = caption ?? (canonicalURL == nil ? nil : cleanText)
        let cleanCaption = captionSource?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = data.collectionEntries.first(where: { $0.id == id && !$0.deleted }) {
            if let cleanCaption, !cleanCaption.isEmpty {
                let note = CollectionEntry.comment(id: deterministicID.map { "comment-\($0)" } ?? UUID().uuidString, postID: existing.id, authorID: participantID, authorName: me, text: cleanCaption)
                guard commitCollection([note]) else { throw CollectionStoreError.persistenceFailed }
            }
            return existing
        }
        let entry = CollectionEntry.post(id: id, authorID: participantID, authorName: me, text: canonicalURL == nil && !cleanText.isEmpty ? cleanText : nil, url: cleanURL, canonicalURL: canonicalURL?.absoluteString, displayTitle: neutralTitle, caption: nil)
        var records = [entry]
        if let cleanCaption, !cleanCaption.isEmpty {
            records.append(.comment(id: deterministicID.map { "comment-\($0)" } ?? UUID().uuidString, postID: entry.id, authorID: participantID, authorName: me, text: cleanCaption))
        }
        guard commitCollection(records) else { throw CollectionStoreError.persistenceFailed }
        return entry
    }

    @discardableResult
    func addCollectionComment(postID: String, text: String, deterministicID: String? = nil) throws -> CollectionEntry {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw CollectionStoreError.emptyComment }
        guard data.collectionEntries.contains(where: { $0.id == postID && $0.kind == .post && !$0.deleted }) else { throw CollectionStoreError.missingPost }
        let entry = CollectionEntry.comment(id: deterministicID ?? UUID().uuidString, postID: postID, authorID: participantID, authorName: me, text: clean)
        guard commitCollection(entry) else { throw CollectionStoreError.persistenceFailed }
        return entry
    }

    @discardableResult
    func setCollectionHeart(postID: String, active: Bool) throws -> CollectionEntry {
        guard data.collectionEntries.contains(where: { $0.id == postID && $0.kind == .post && !$0.deleted }) else { throw CollectionStoreError.missingPost }
        let id = CollectionEntry.reactionID(postID: postID, participantID: participantID)
        var entry = data.collectionEntries.first(where: { $0.id == id }) ?? CollectionEntry.reaction(postID: postID, participantID: participantID, authorName: me, active: active)
        entry.active = active; entry.deleted = false; entry.updatedAt = Date()
        guard commitCollection(entry) else { throw CollectionStoreError.persistenceFailed }
        return entry
    }

    @discardableResult
    func linkCollectionPlace(postID: String, placeID: String) throws -> CollectionEntry {
        guard data.collectionEntries.contains(where: { $0.id == postID && $0.kind == .post && !$0.deleted }), places.contains(where: { $0.id == placeID }) else { throw CollectionStoreError.missingPost }
        let entry = CollectionEntry.placeLink(postID: postID, placeID: placeID, authorID: participantID, authorName: me)
        if let old = data.collectionEntries.first(where: { $0.id == entry.id && !$0.deleted }) { return old }
        guard commitCollection(entry) else { throw CollectionStoreError.persistenceFailed }
        return entry
    }

    @discardableResult
    func unlinkCollectionPlace(postID: String, placeID: String) throws -> CollectionEntry {
        let id = CollectionEntry.placeLinkID(postID: postID, placeID: placeID)
        guard var entry = data.collectionEntries.first(where: { $0.id == id }) else { throw CollectionStoreError.missingPost }
        entry.deleted = true; entry.active = false; entry.updatedAt = Date()
        guard commitCollection(entry) else { throw CollectionStoreError.persistenceFailed }
        return entry
    }

    @discardableResult
    func tombstoneCollectionEntry(id: String) throws -> CollectionEntry {
        guard var entry = data.collectionEntries.first(where: { $0.id == id }) else { throw CollectionStoreError.missingPost }
        entry.deleted = true; entry.updatedAt = Date()
        guard commitCollection(entry) else { throw CollectionStoreError.persistenceFailed }
        return entry
    }

    @discardableResult
    func updateCollectionMetadata(id: String, title: String? = nil, caption: String? = nil, thumbnailURL: String? = nil, state: CollectionMetadataState? = nil, expectedToken: String? = nil, replaceThumbnailURL: Bool = false) -> Bool {
        guard var entry = data.collectionEntries.first(where: { $0.id == id && $0.kind == .post && !$0.deleted }) else { return false }
        if let expectedToken, data.collectionSync[id]?.mutationToken != expectedToken { return false }
        if let title, !title.isEmpty, (entry.displayTitle?.isEmpty ?? true || isNeutralCollectionTitle(entry.displayTitle, for: entry)) { entry.displayTitle = title }
        if let caption, !caption.isEmpty, entry.caption?.isEmpty ?? true { entry.caption = caption }
        if let thumbnailURL, !thumbnailURL.isEmpty, replaceThumbnailURL || entry.thumbnailURL?.isEmpty ?? true { entry.thumbnailURL = thumbnailURL }
        if let state { entry.metadataState = state }
        entry.updatedAt = Date()
        return commitCollection(entry)
    }

    func refreshCollectionMetadata(for id: String, force: Bool = false, fetchPreview: (URL) async throws -> OEmbedService.Preview = { try await OEmbedService.preview($0) }) async {
        guard !collectionMetadataRefreshIDs.contains(id) else { return }
        guard let entry = data.collectionEntries.first(where: { $0.id == id && $0.kind == .post && !$0.deleted }), let raw = entry.url ?? entry.canonicalURL, let url = LinkValidation.url(raw), let token = data.collectionSync[id]?.mutationToken else { return }
        let tripIdentity = data.collaboration?.tripID
        collectionMetadataRefreshIDs.insert(id)
        defer { collectionMetadataRefreshIDs.remove(id) }
        do {
            let preview = try await fetchPreview(url)
            guard !Task.isCancelled, data.collaboration?.tripID == tripIdentity else { return }
            guard isUsableCollectionPreview(preview, for: url) else {
                if data.collectionEntries.first(where: { $0.id == id })?.metadataState != .available {
                    _ = updateCollectionMetadata(id: id, state: .unavailable, expectedToken: token)
                }
                return
            }
            _ = updateCollectionMetadata(id: id, title: preview.conciseTitle, caption: preview.description, thumbnailURL: preview.thumbnail_url, state: .available, expectedToken: token, replaceThumbnailURL: force)
        } catch {
            guard !Task.isCancelled, let current = data.collectionEntries.first(where: { $0.id == id && $0.kind == .post && !$0.deleted }), current.metadataState != .available,
                  data.collaboration?.tripID == tripIdentity else { return }
            _ = updateCollectionMetadata(id: id, state: .unavailable, expectedToken: token)
        }
    }

    /// Performs one bounded, sequential backfill for links that have no usable preview.
    /// The session guard prevents view refreshes from creating an unbounded retry loop.
    func refreshCollectionMetadataIfNeeded(limit: Int = 3, force: Bool = false) async {
        let candidates = collectionPosts.filter { post in
            guard post.url != nil || post.canonicalURL != nil else { return false }
            if force { return true }
            if post.metadataState != .available { return !collectionMetadataBackfilledIDs.contains(post.id) }
            return post.thumbnailURL == nil && !collectionMetadataBackfilledIDs.contains(post.id)
        }.prefix(max(0, limit))
        for post in candidates {
            guard !Task.isCancelled else { return }
            if !force { collectionMetadataBackfilledIDs.insert(post.id) }
            await refreshCollectionMetadata(for: post.id, force: force)
        }
    }

    private func isNeutralCollectionTitle(_ title: String?, for entry: CollectionEntry) -> Bool {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return true }
        if title.hasSuffix("-Link") { return true }
        guard let raw = entry.url ?? entry.canonicalURL, let url = LinkValidation.url(raw) else { return false }
        let host = (url.host ?? "").replacingOccurrences(of: "www.", with: "")
        return title.caseInsensitiveCompare(host) == .orderedSame || title.caseInsensitiveCompare(CollectionURL.neutralTitle(for: url)) == .orderedSame
    }

    private func isUsableCollectionPreview(_ preview: OEmbedService.Preview, for url: URL) -> Bool {
        let title = preview.conciseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = (url.host ?? "").replacingOccurrences(of: "www.", with: "").lowercased()
        let neutral = CollectionURL.neutralTitle(for: url).lowercased()
        let usefulTitle = !title.isEmpty && !["instagram", "tiktok", "facebook", "reiseidee"].contains(title.lowercased()) && title.lowercased() != host && title.lowercased() != neutral && !title.lowercased().hasSuffix("-link")
        return usefulTitle || !(preview.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) || !(preview.thumbnail_url?.isEmpty ?? true)
    }

    private func commitCollection(_ entries: [CollectionEntry]) -> Bool {
        let previous = data
        let token = UUID().uuidString
        for var entry in entries {
            entry.updatedAt = Date()
            if let index = data.collectionEntries.firstIndex(where: { $0.id == entry.id }) { data.collectionEntries[index] = entry } else { data.collectionEntries.append(entry) }
            data.collectionSync[entry.id] = CollectionSyncMetadata(serverVersion: data.collectionSync[entry.id]?.serverVersion, mutationToken: token, lastErrorCode: nil)
            data.dirty.insert("collection:" + entry.id)
        }
        guard persist() else { data = previous; return false }
        scheduleCollectionSync()
        return true
    }

    private func commitCollection(_ entry: CollectionEntry) -> Bool { commitCollection([entry]) }
}

@MainActor
final class CollectionStore {
    let album: AlbumStore
    init(album: AlbumStore) { self.album = album }
    var entries: [CollectionEntry] { album.collectionPosts }
    var participantID: String { album.participantID }
    @discardableResult func post(text: String, url: String? = nil) throws -> CollectionEntry { try album.addCollectionPost(text: text, url: url) }
}
