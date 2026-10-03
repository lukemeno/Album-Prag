import XCTest
@testable import Album

@MainActor
final class CollectionTests: XCTestCase {
    private var root: URL!
    private var previousParticipant: String?

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("collection-\(UUID().uuidString)")
        previousParticipant = UserDefaults.standard.string(forKey: CollectionIdentity.defaultsKey)
        UserDefaults.standard.set("participant-test", forKey: CollectionIdentity.defaultsKey)
    }

    override func tearDownWithError() throws {
        if let previousParticipant { UserDefaults.standard.set(previousParticipant, forKey: CollectionIdentity.defaultsKey) } else { UserDefaults.standard.removeObject(forKey: CollectionIdentity.defaultsKey) }
        try? FileManager.default.removeItem(at: root)
        try super.tearDownWithError()
    }

    private func legacyAlbumJSON() throws -> Data {
        let encoded = try JSONEncoder().encode(AlbumData())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "albumID")
        object.removeValue(forKey: "collectionEntries")
        object.removeValue(forKey: "collectionSync")
        return try JSONSerialization.data(withJSONObject: object)
    }

    func testOldAlbumJSONDecodesWithoutCollectionFields() throws {
        let json = try legacyAlbumJSON()
        let album = try JSONDecoder().decode(AlbumData.self, from: json)
        XCTAssertTrue(album.collectionEntries.isEmpty)
        XCTAssertTrue(album.collectionSync.isEmpty)
        XCTAssertFalse(album.albumID.isEmpty)
    }

    func testLegacyAlbumIDIsPersistedAndShareContextRemainsStable() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let old = try legacyAlbumJSON()
        try old.write(to: root.appendingPathComponent("album.json"))
        let shareRoot = root.appendingPathComponent("share-context")
        let first = AlbumStore(root: root, shareInbox: ShareInbox(root: shareRoot))
        let firstID = first.data.albumID
        first.publishShareContext()
        let second = AlbumStore(root: root, shareInbox: ShareInbox(root: shareRoot))
        XCTAssertEqual(second.data.albumID, firstID)
        XCTAssertEqual(ShareInbox(root: shareRoot).loadContext()?.tripKey, "local:\(firstID)")
    }

    func testFreshAlbumIDIsPersistedBeforeShareContext() throws {
        let shareRoot = root.appendingPathComponent("fresh-share-context")
        let first = AlbumStore(root: root, shareInbox: ShareInbox(root: shareRoot))
        let firstID = first.data.albumID
        first.publishShareContext()
        let context = try XCTUnwrap(ShareInbox(root: shareRoot).loadContext())
        try ShareInbox(root: shareRoot).save(ShareQueueItem(payload: "QA", url: "https://example.com/qa", tripKey: context.tripKey))
        let reopened = AlbumStore(root: root, shareInbox: ShareInbox(root: shareRoot))
        reopened.drainShareQueue()

        XCTAssertEqual(reopened.data.albumID, firstID)
        XCTAssertEqual(ShareInbox(root: shareRoot).loadContext()?.tripKey, "local:\(firstID)")
        XCTAssertEqual(reopened.collectionPosts.count, 1)
    }

    func testCanonicalSocialClipsAndMeaningfulParameters() throws {
        let tiktok = try XCTUnwrap(CollectionURL.canonicalize("HTTPS://WWW.TikTok.com/@creator/video/123?utm_source=x&foo=2#comment"))
        XCTAssertEqual(tiktok.absoluteString, "https://www.tiktok.com/video/123")
        let generic = try XCTUnwrap(CollectionURL.canonicalize("https://example.com/clip?utm_source=x&foo=2"))
        XCTAssertEqual(generic.absoluteString, "https://example.com/clip?foo=2")
        let instagram = try XCTUnwrap(CollectionURL.canonicalize("https://instagram.com/reel/AbC_9?igshid=x"))
        XCTAssertEqual(instagram.absoluteString, "https://www.instagram.com/reel/AbC_9")
        XCTAssertEqual(CollectionURL.neutralTitle(for: try XCTUnwrap(URL(string: "https://evil-tiktok.example/clip"))), "evil-tiktok.example")
        let different = CollectionURL.postID(for: "https://instagram.com/p/AbC_9")
        XCTAssertNotEqual(CollectionURL.postID(for: "https://instagram.com/p/abc_9"), different)
    }

    func testHTMLPreviewDecodesEntitiesAndResolvesRelativeImage() throws {
        let html = #"<html><head><meta property="og:title" content="Rathaus &amp; Uhr"><meta property="og:description" content="Prag &#x1F3DB;&#xfe0f;"><meta property="og:image" content="/images/clock.jpg"></head></html>"#.data(using: .utf8)!
        let preview = try XCTUnwrap(OEmbedService.parseHTMLPreview(html, baseURL: URL(string: "https://example.com/reels/42")!))
        XCTAssertEqual(preview.title, "Rathaus & Uhr")
        XCTAssertEqual(preview.thumbnail_url, "https://example.com/images/clock.jpg")
        XCTAssertTrue(preview.description?.unicodeScalars.contains(where: { $0.value == 0x1F3DB }) == true)
    }

    func testBlockedLoginMetadataIsIgnored() {
        let html = Data(#"<meta property="og:title" content="Log in · TikTok"><meta property="og:image" content="/login.png">"#.utf8)
        XCTAssertNil(OEmbedService.parseHTMLPreview(html, baseURL: URL(string: "https://www.tiktok.com/@a/video/1")!))
    }

    func testPlaceCandidatesKeepLandmarksAndRejectBroadCityText() {
        let caption = "Mein ausführliches Fazit ⬇️ 🕰️ Rathaus-Uhr: 10:00\nPrager Burg\nKloster Strahov Bibliothek: wunderschön\n#prague #travel"
        let candidates = CollectionPlaceExtractor.candidates(title: "Prag Wochenende", caption: caption, comments: ["Karlsbrücke: morgens", "Wir lieben die Stadt"])
        let names = Set(candidates.map { $0.query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) })
        XCTAssertTrue(names.contains("rathaus-uhr"))
        XCTAssertTrue(names.contains("prager burg"))
        XCTAssertTrue(names.contains("kloster strahov bibliothek"))
        XCTAssertTrue(names.contains("karlsbrucke"))
        XCTAssertFalse(names.contains("prag"))
        XCTAssertFalse(names.contains("mein ausführliches fazit"))
    }

    func testRealSharedTikTokCaptionKeepsLandmarkHeadings() {
        let caption = "Mein ausführliches Fazit ⬇️ 🕰️ Rathaus-Uhr:  • das stündliche Apostel-Spiel“ ist total kurz (nur ~45 Sekunden), trotzdem Menschenmassen um die Uhr  • Social Media ist da halt fake • aber: tolle Kulisse am Marktplatz • eine der ältesten astronomischen Uhren der Welt ⛴️ meine Unterkunft:  • ehemaliges Flusskreuzfahrt-Schiff • gute Lage etwas außerhalb, aber mit Öffis in 10min im Zentrum  ⛪️ St. Nikolaus-Kirche: • eine der bedeutendsten barocken Kirchen Europas • wunderschöne Architektur  • Eintritt aber ~6€ und es gibt auch tolle Kirchen, die du kostenlos besuchen kannst - z.B. die Church of our Lady Victorious  🦫 Nutrias auf Archers Island:  • definitiv ein Highlight, super süß • aber: bin mir nicht sicher ob ich das füttern so gut finde, habe es daher nicht gemacht  🚆 Öffis fahren:  • total entspannt - Straßenbahnen fahren häufig und sind pünktlich Tickets sind super günstig (~6€ für 24h)!  🛳️ Touri-Bootsfahrt:  • gebucht über @getyourguide (unbezahlte Werbung) • hab ich eigentlich nur gemacht um der Kälte zu entfliehen…war aber ganz cool, wenn auch kurz  • tolle views  …und es gibt Aperol 😂 🏰 Prager Burg (jaa, nicht Schloss - sorry 😅): • riesige, super beeindruckende Anlage • kostenlos außer du möchtest auch die Innenräume sehen  • plane dann aber Wartezeiten ein - sehr voll  🍦Baumstriezel probieren:  • kurz enttäuschend, dass das gar nicht typisch tschechisch ist (obwohl es die an jeder Ecke in Prag gibt) • trotzdem halt einfach so lecker 🤷🏻‍♀️ 🍩 Typisch Tschechische Kolace:  • auch gut, aber fand die bisschen trocken  📚 Kloster Strahov Bibliothek:  • super schlechte Orga  • hatte schon Tickets, aber bin nach über 1h Warten draußen in der Schlange wieder gegangen  ⛲️ Grotta Umělá jeskyně:  • wunderschönes Hidden Gem in einem großen Park • easy mit den Öffis zu erreichen  🎄 Prager Weihnachtsmarkt:  • fand ich überbewertet  • tolle Location, aber Angebot nicht besonders  🌉 Karlsbrücke:  • Must-Do um auf die andere Seite zu kommen  • tolle Architektur und views  • kann aber voll werden  Totally overrated fand ich übrigens das Dancing House - wer auch? 🤭 #realtalk #reisetipps #pragtipps #prag"
        let queries = CollectionPlaceExtractor.candidates(title: "Mein ausführliches Fazit", caption: caption, comments: []).map(\.query)
        XCTAssertTrue(queries.contains("Prager Burg"), "\(queries)")
        XCTAssertTrue(queries.contains("Karlsbrücke"), "\(queries)")
        XCTAssertTrue(queries.contains("Kloster Strahov Bibliothek"), "\(queries)")
        XCTAssertFalse(queries.contains(where: { $0.hasPrefix("Mein ausführliches") }))
    }

    func testPlaceResolverRejectsUnrelatedMapName() {
        XCTAssertTrue(CollectionPlaceResolver.namesMatch(name: "Karlsbrücke", query: "Karlsbrücke"))
        XCTAssertFalse(CollectionPlaceResolver.namesMatch(name: "Café Louvre", query: "Karlsbrücke"))
        XCTAssertFalse(CollectionPlaceResolver.namesMatch(name: "Café Louvre", query: "Café Savoy"))
        XCTAssertFalse(CollectionPlaceResolver.namesMatch(name: "Café", query: "Café Savoy"))
        XCTAssertTrue(CollectionPlaceResolver.namesMatch(name: "Café Savoy", query: "Café Savoy"))
    }

    func testMetadataRefreshKeepsNotesAndReplacesExpiredThumbnail() async throws {
        let store = AlbumStore(root: root)
        let post = try store.addCollectionPost(text: "Unsere Notiz", url: "https://example.com/place")
        XCTAssertTrue(store.updateCollectionMetadata(id: post.id, title: "Eigener Titel", caption: "Bestehender Text", thumbnailURL: "https://example.com/old.jpg", state: .available))
        await store.refreshCollectionMetadata(for: post.id, force: true) { _ in
            OEmbedService.Preview(title: "Externer Titel", thumbnail_url: "https://example.com/new.jpg", description: "Neuer Text")
        }
        let updated = try XCTUnwrap(store.collectionPosts.first)
        XCTAssertEqual(updated.displayTitle, "Eigener Titel")
        XCTAssertEqual(updated.caption, "Bestehender Text")
        XCTAssertEqual(updated.thumbnailURL, "https://example.com/new.jpg")
        XCTAssertEqual(store.collectionComments(for: post.id).first?.text, "Unsere Notiz")
    }

    func testMetadataRefreshRejectsResultAfterConcurrentMutation() async throws {
        let store = AlbumStore(root: root)
        let post = try store.addCollectionPost(text: "", url: "https://example.com/place")
        await store.refreshCollectionMetadata(for: post.id) { _ in
            XCTAssertTrue(store.updateCollectionMetadata(id: post.id, caption: "Währenddessen ergänzt"))
            return OEmbedService.Preview(title: "Veraltetes Ergebnis", thumbnail_url: "https://example.com/stale.jpg")
        }
        let updated = try XCTUnwrap(store.collectionPosts.first)
        XCTAssertEqual(updated.caption, "Währenddessen ergänzt")
        XCTAssertNil(updated.thumbnailURL)
        XCTAssertEqual(updated.displayTitle, "example.com")
    }

    func testMetadataRefreshFailurePreservesGoodPreview() async throws {
        let store = AlbumStore(root: root)
        let post = try store.addCollectionPost(text: "", url: "https://example.com/place")
        XCTAssertTrue(store.updateCollectionMetadata(id: post.id, title: "Café Savoy", thumbnailURL: "https://example.com/good.jpg", state: .available))
        await store.refreshCollectionMetadata(for: post.id, force: true) { _ in throw URLError(.notConnectedToInternet) }
        let updated = try XCTUnwrap(store.collectionPosts.first)
        XCTAssertEqual(updated.displayTitle, "Café Savoy")
        XCTAssertEqual(updated.thumbnailURL, "https://example.com/good.jpg")
        XCTAssertEqual(updated.metadataState, .available)
    }

    func testPlatformNameAloneIsNotAUsefulPreview() async throws {
        let store = AlbumStore(root: root)
        let post = try store.addCollectionPost(text: "", url: "https://www.instagram.com/reel/abc")
        await store.refreshCollectionMetadata(for: post.id) { _ in OEmbedService.Preview(title: "Instagram") }
        XCTAssertEqual(store.collectionPosts.first?.metadataState, .unavailable)
        XCTAssertEqual(store.collectionPosts.first?.displayTitle, "Instagram-Link")
    }

    func testOriginalTikTokURLIsRetainedWhileIdentityDropsHandle() throws {
        let store = AlbumStore(root: root)
        let post = try store.addCollectionPost(text: "", url: "https://www.tiktok.com/@creator/video/123?utm_source=share")
        XCTAssertEqual(post.url, "https://www.tiktok.com/@creator/video/123?utm_source=share")
        XCTAssertEqual(post.canonicalURL, "https://www.tiktok.com/video/123")
        XCTAssertEqual(post.id, CollectionURL.postID(for: "https://tiktok.com/@other/video/123"))
    }

    func testStorePersistsTextLinkCommentReactionAndPlaceLink() throws {
        let store = AlbumStore(root: root)
        store.data.places = [Place(id: "place-a", title: "Manueller Ort")]
        let post = try store.addCollectionPost(text: "Merken", url: "https://example.com/clip?b=2&a=1")
        _ = try store.addCollectionComment(postID: post.id, text: "Später ansehen")
        _ = try store.setCollectionHeart(postID: post.id, active: true)
        _ = try store.linkCollectionPlace(postID: post.id, placeID: "place-a")
        XCTAssertEqual(store.collectionComments(for: post.id).count, 2)
        XCTAssertEqual(store.collectionHeartCount(for: post.id), 1)
        XCTAssertEqual(store.collectionPlaces(for: post.id).map(\.id), ["place-a"])

        let restarted = AlbumStore(root: root)
        XCTAssertEqual(restarted.collectionPosts.map(\.id), [post.id])
        XCTAssertEqual(restarted.collectionHeartCount(for: post.id), 1)
    }

    func testDuplicateCanonicalLinkKeepsIndependentNotes() throws {
        let store = AlbumStore(root: root)
        let first = try store.addCollectionPost(text: "", url: "https://www.tiktok.com/@a/video/42", caption: "Erste Notiz")
        let second = try store.addCollectionPost(text: "", url: "https://tiktok.com/@b/video/42", caption: "Zweite Notiz")
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(Set(store.collectionComments(for: first.id).compactMap(\.text)), ["Erste Notiz", "Zweite Notiz"])
    }

    func testUnlikeUsesStableReactionRecordAndRemainsSyncable() throws {
        let store = AlbumStore(root: root)
        store.collectionParticipantIDOverride = "participant-a"
        let post = try store.addCollectionPost(text: "clip")
        _ = try store.setCollectionHeart(postID: post.id, active: true)
        let other = AlbumStore(root: root)
        other.collectionParticipantIDOverride = "participant-b"
        _ = try other.setCollectionHeart(postID: post.id, active: true)
        XCTAssertEqual(other.collectionHeartCount(for: post.id), 2)
        store.collectionParticipantIDOverride = "participant-a"
        _ = try store.setCollectionHeart(postID: post.id, active: false)
        XCTAssertEqual(store.collectionHeartCount(for: post.id), 0)
        let reactions = store.data.collectionEntries.filter { $0.kind == .reaction && $0.postID == post.id }
        XCTAssertEqual(reactions.count, 1)
        XCTAssertEqual(reactions.first?.active, false)
        XCTAssertTrue(store.data.dirty.contains("collection:\(reactions[0].id)"))
    }

    func testFailedPersistenceRollsBackCollectionMutation() throws {
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent("collection-blocker-\(UUID().uuidString)")
        try Data("blocker".utf8).write(to: blocker)
        let store = AlbumStore(root: blocker)
        XCTAssertThrowsError(try store.addCollectionPost(text: "cannot save")) { error in
            XCTAssertEqual(error as? CollectionStoreError, .persistenceFailed)
        }
        XCTAssertTrue(store.data.collectionEntries.isEmpty)
        XCTAssertThrowsError(try store.addCollectionPost(text: "Notiz", url: "https://example.com/clip"))
        XCTAssertTrue(store.data.collectionEntries.isEmpty)
    }

    func testShareInboxRoundTripRetryAndDiscardWithInjectedRoot() throws {
        let queueRoot = root.appendingPathComponent("share")
        let inbox = ShareInbox(root: queueRoot)
        try inbox.saveContext(ShareContext(tripKey: "local:test", albumID: "album-test"))
        var item = ShareQueueItem(payload: "Später ansehen", url: "https://example.com/a", tripKey: "local:test")
        try inbox.save(item)
        XCTAssertEqual(inbox.items().map(\.id), [item.id])
        item.state = .failed; item.attemptCount = 1; item.lastErrorCode = "persist"
        try inbox.update(item)
        XCTAssertEqual(inbox.items().first?.state, .failed)
        try inbox.remove(item)
        XCTAssertTrue(inbox.items().isEmpty)
    }

    func testCorruptShareQueueFileStaysVisibleUntilExplicitDiscard() throws {
        let queueRoot = root.appendingPathComponent("corrupt-share")
        try FileManager.default.createDirectory(at: queueRoot, withIntermediateDirectories: true)
        let file = queueRoot.appendingPathComponent("ShareQueue-corrupt.json")
        try Data("{broken".utf8).write(to: file)
        let inbox = ShareInbox(root: queueRoot)
        let item = try XCTUnwrap(inbox.items().first)
        XCTAssertEqual(item.state, .failed)
        XCTAssertEqual(item.lastErrorCode, "queue-decode-failed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        try inbox.remove(item)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testDrainingSameShareItemTwiceCreatesOnePostAndOneNote() throws {
        let queueRoot = root.appendingPathComponent("share-idempotent")
        let inbox = ShareInbox(root: queueRoot)
        let store = AlbumStore(root: root, shareInbox: inbox)
        store.publishShareContext()
        let context = try XCTUnwrap(inbox.loadContext())
        let item = ShareQueueItem(id: "queue-1", payload: "Meine Notiz", url: "https://www.tiktok.com/@creator/video/7", tripKey: context.tripKey)
        try inbox.save(item)
        store.drainShareQueue()
        try inbox.save(item)
        store.drainShareQueue()
        XCTAssertEqual(store.collectionPosts.count, 1)
        XCTAssertEqual(store.collectionComments(for: store.collectionPosts[0].id).count, 1)
        XCTAssertTrue(inbox.items().isEmpty)
    }

    func testAlbumSyncKeepsDirtyMutationMadeWhileUploadAwaits() async throws {
        let store = AlbumStore(root: root)
        store.collectionParticipantIDOverride = "participant-a"
        store.data.collaboration = CollaborationState(tripID: UUID(), inviteToken: nil)
        let post = try store.addCollectionPost(text: "before")
        let service = PausingCollectionSyncService()
        store.syncService = service
        let syncTask = Task { await store.sync() }
        while !service.didCaptureSnapshot { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertTrue(store.updateCollectionMetadata(id: post.id, caption: "during upload"))
        service.resume()
        await syncTask.value
        XCTAssertTrue(store.data.dirty.contains("collection:\(post.id)"))
    }

    func testRealCollectionPushEngineKeepsNewPayloadDuringConditionalUpdate() async throws {
        let store = AlbumStore(root: root)
        store.collectionParticipantIDOverride = "participant-a"
        let post = try store.addCollectionPost(text: "before")
        if var metadata = store.data.collectionSync[post.id] { metadata.serverVersion = 1; store.data.collectionSync[post.id] = metadata }
        let transport = CollectionTransportFake()
        transport.rows[post.id] = CollectionSyncRow(id: post.id, tripID: UUID(), payload: post, version: 1, deleted: false, updatedAt: post.updatedAt)
        transport.holdUpdate = true
        let sync = SupabaseSync(collectionTransport: transport)
        let tripID = transport.rows[post.id]!.tripID
        let task = Task { try await sync.pushCollectionEntriesForTesting(store: store, tripID: tripID) }
        while !transport.didEnterUpdate { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertTrue(store.updateCollectionMetadata(id: post.id, caption: "neu während Upload"))
        transport.resume()
        try await task.value
        XCTAssertEqual(store.data.collectionEntries.first(where: { $0.id == post.id })?.caption, "neu während Upload")
        XCTAssertEqual(store.data.collectionSync[post.id]?.serverVersion, 2)
        XCTAssertTrue(store.data.dirty.contains("collection:\(post.id)"))
    }

    func testRealCollectionPushEngineSkipsUniqueConflictAfterConcurrentMutation() async throws {
        let store = AlbumStore(root: root)
        store.collectionParticipantIDOverride = "participant-a"
        let post = try store.addCollectionPost(text: "before")
        let transport = CollectionTransportFake()
        let tripID = UUID()
        transport.rows[post.id] = CollectionSyncRow(id: post.id, tripID: tripID, payload: post, version: 4, deleted: false, updatedAt: post.updatedAt)
        transport.insertConflicts = 1
        transport.holdFetch = true
        let sync = SupabaseSync(collectionTransport: transport)
        let task = Task { try await sync.pushCollectionEntriesForTesting(store: store, tripID: tripID) }
        while !transport.didEnterFetch { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertTrue(store.updateCollectionMetadata(id: post.id, caption: "neu während Conflict"))
        transport.resume()
        try await task.value
        XCTAssertEqual(store.data.collectionEntries.first(where: { $0.id == post.id })?.caption, "neu während Conflict")
        XCTAssertEqual(store.data.collectionSync[post.id]?.serverVersion, 4)
        XCTAssertTrue(store.data.dirty.contains("collection:\(post.id)"))
    }
}

@MainActor
private final class PausingCollectionSyncService: AlbumSyncService {
    var didCaptureSnapshot = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var snapshotID: String?
    private var snapshotToken: String?

    func createTrip(store: AlbumStore) async throws -> CollaborationState { fatalError("unused") }
    func joinTrip(token: String) async throws -> CollaborationState { fatalError("unused") }
    func startRealtime(onChange: @escaping @MainActor @Sendable () async -> Void) {}

    func sync(store: AlbumStore) async throws {
        guard let entry = store.data.collectionEntries.first(where: { $0.kind == .post }), let metadata = store.data.collectionSync[entry.id] else { return }
        snapshotID = entry.id; snapshotToken = metadata.mutationToken; didCaptureSnapshot = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in self.continuation = continuation }
        guard let snapshotID, let snapshotToken else { return }
        guard store.data.collectionSync[snapshotID]?.mutationToken == snapshotToken else { return }
        if var metadata = store.data.collectionSync[snapshotID] { metadata.serverVersion = 1; store.data.collectionSync[snapshotID] = metadata }
        store.data.dirty.remove("collection:\(snapshotID)")
    }

    func resume() { continuation?.resume(); continuation = nil }
}

@MainActor
private final class CollectionTransportFake: CollectionSyncTransport {
    enum Failure: Error { case conflict }
    var rows: [String: CollectionSyncRow] = [:]
    var insertConflicts = 0
    var holdUpdate = false
    var holdFetch = false
    var didEnterUpdate = false
    var didEnterFetch = false
    private var continuation: CheckedContinuation<Void, Never>?

    func pull(tripID: UUID) async throws -> [CollectionSyncRow] { rows.values.filter { $0.tripID == tripID } }

    func insert(_ row: CollectionSyncRow) async throws -> CollectionSyncRow {
        if insertConflicts > 0 { insertConflicts -= 1; throw Failure.conflict }
        rows[row.id] = row
        return row
    }

    func fetch(id: String, tripID: UUID) async throws -> CollectionSyncRow? {
        if holdFetch { didEnterFetch = true; await wait() }
        return rows[id]
    }

    func update(_ row: CollectionSyncRow, expectedVersion: Int64) async throws -> CollectionSyncRow? {
        if holdUpdate { didEnterUpdate = true; await wait() }
        guard let current = rows[row.id], current.version == expectedVersion else { return nil }
        let updated = CollectionSyncRow(id: row.id, tripID: row.tripID, payload: row.payload, version: expectedVersion + 1, deleted: row.deleted, updatedAt: row.updatedAt)
        rows[row.id] = updated
        return updated
    }

    func resume() { continuation?.resume(); continuation = nil }
    private func wait() async { await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in self.continuation = continuation } }
}
