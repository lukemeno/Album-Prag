import Foundation
import Supabase

enum AlbumSyncError: LocalizedError {
    case missingConfiguration
    case invalidInvitation
    case missingTrip
    case membershipLost

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Supabase ist noch nicht eingerichtet. Bitte SUPABASE_URL und SUPABASE_ANON_KEY in Config.xcconfig eintragen."
        case .invalidInvitation:
            return "Dieser Einladungslink ist ungültig oder nicht mehr verfügbar."
        case .missingTrip:
            return "Die gemeinsame Reise wurde nicht gefunden."
        case .membershipLost:
            return "Dieses iPhone ist nicht mehr mit der Reise verbunden. Bitte den Einladungslink noch einmal öffnen."
        }
    }
}

enum SupabaseConfiguration {
    static func client(bundle: Bundle = .main) throws -> SupabaseClient {
        guard let rawURL = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: rawURL), !rawURL.contains("YOUR_PROJECT"),
              let key = bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !key.isEmpty, !key.contains("YOUR_PUBLISHABLE_KEY") else {
            throw AlbumSyncError.missingConfiguration
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
}

@MainActor protocol AlbumSyncService: AnyObject {
    func createTrip(store: AlbumStore) async throws -> CollaborationState
    func joinTrip(token: String) async throws -> CollaborationState
    func sync(store: AlbumStore) async throws
    func startRealtime(onChange: @escaping @MainActor @Sendable () async -> Void)
}

private struct CreateTripResponse: Decodable {
    let tripID: UUID
    let inviteToken: String

    enum CodingKeys: String, CodingKey {
        case tripID = "trip_id"
        case inviteToken = "invite_token"
    }
}

private struct JoinTripRequest: Encodable { let inviteToken: String
    enum CodingKeys: String, CodingKey { case inviteToken = "invite_token" }
}

private struct JoinTripResponse: Decodable {
    let tripID: UUID
    enum CodingKeys: String, CodingKey { case tripID = "trip_id" }
}

private struct TripRow: Codable {
    let id: UUID
    let payload: TripInfo
    let updatedAt: Date
    enum CodingKeys: String, CodingKey { case id, payload; case updatedAt = "updated_at" }
}

private struct PlaceRow: Codable {
    let id: String
    let tripID: UUID
    let payload: Place
    let updatedAt: Date
    let deleted: Bool
    enum CodingKeys: String, CodingKey {
        case id, payload, deleted
        case tripID = "trip_id"
        case updatedAt = "updated_at"
    }
}

private struct DocumentRow: Codable {
    let id: String
    let tripID: UUID
    let name: String
    let filename: String
    let extractedText: String
    let storagePath: String
    let updatedAt: Date
    enum CodingKeys: String, CodingKey {
        case id, name, filename
        case tripID = "trip_id"
        case extractedText = "extracted_text"
        case storagePath = "storage_path"
        case updatedAt = "updated_at"
    }
}

@MainActor final class SupabaseSync: AlbumSyncService {
    private let client: SupabaseClient
    private var realtimeTask: Task<Void, Never>?
    private var realtimeTripID: UUID?
    private var activeTripID: UUID?

    static func configured(bundle: Bundle = .main) throws -> SupabaseSync {
        SupabaseSync(client: try SupabaseConfiguration.client(bundle: bundle))
    }

    init(client: SupabaseClient) { self.client = client }

    func createTrip(store: AlbumStore) async throws -> CollaborationState {
        try await ensureSession()
        let response: CreateTripResponse = try await client.functions.invoke("create-trip")
        activeTripID = response.tripID
        try await pushDirty(store: store, tripID: response.tripID)
        return CollaborationState(tripID: response.tripID, inviteToken: response.inviteToken)
    }

    func joinTrip(token: String) async throws -> CollaborationState {
        guard token.count >= 32 else { throw AlbumSyncError.invalidInvitation }
        try await ensureSession()
        let response: JoinTripResponse = try await client.functions.invoke(
            "join-trip",
            options: FunctionInvokeOptions(body: JoinTripRequest(inviteToken: token))
        )
        activeTripID = response.tripID
        // Beide iPhones merken sich die Einladung, damit eine verlorene Anmeldung wieder beitreten kann.
        return CollaborationState(tripID: response.tripID, inviteToken: token)
    }

    func sync(store: AlbumStore) async throws {
        guard let collaboration = store.data.collaboration else { throw AlbumSyncError.missingTrip }
        try await ensureSession()
        try await ensureMembership(tripID: collaboration.tripID, inviteToken: collaboration.inviteToken)
        activeTripID = collaboration.tripID

        let tripRows: [TripRow] = try await client.from("trips")
            .select().eq("id", value: collaboration.tripID).execute().value
        let remotePlaces: [PlaceRow] = try await client.from("places")
            .select().eq("trip_id", value: collaboration.tripID).execute().value
        let remoteDocuments: [DocumentRow] = try await client.from("documents")
            .select().eq("trip_id", value: collaboration.tripID).execute().value

        if let remoteTrip = tripRows.first {
            let localDate = store.data.trip.updatedAt
            store.data.trip = AlbumMerge.trip(local: store.data.trip, remote: remoteTrip.payload)
            if remoteTrip.updatedAt > localDate { store.data.dirty.remove("trip") }
        }

        for row in remotePlaces {
            let index = store.data.places.firstIndex { $0.id == row.id }
            let local = index.map { store.data.places[$0] }
            let merged = AlbumMerge.place(local: local, remote: row.payload)
            if let index { store.data.places[index] = merged } else { store.data.places.append(merged) }
            try await downloadImageIfNeeded(merged, tripID: collaboration.tripID, into: store.root)
            if local == nil || row.updatedAt > (local?.updatedAt ?? .distantPast) { store.data.dirty.remove(row.id) }
        }

        for row in remoteDocuments {
            let index = store.data.documents.firstIndex { $0.id == row.id }
            let local = index.map { store.data.documents[$0] }
            let remote = TravelDocument(id: row.id, name: row.name, filename: row.filename, extractedText: row.extractedText, updatedAt: row.updatedAt)
            let merged = AlbumMerge.document(local: local, remote: remote)
            if let index { store.data.documents[index] = merged } else { store.data.documents.append(merged) }
            if local == nil || row.updatedAt > (local?.updatedAt ?? .distantPast) {
                store.data.dirty.remove("doc-" + row.id)
                try await downloadDocument(row, into: store.root)
            }
        }

        guard store.persist() else { throw CocoaError(.fileWriteUnknown) }
        try await pushDirty(store: store, tripID: collaboration.tripID)
        guard store.persist() else { throw CocoaError(.fileWriteUnknown) }
    }

    func startRealtime(onChange: @escaping @MainActor @Sendable () async -> Void) {
        guard let tripID = activeTripID, realtimeTripID != tripID else { return }
        realtimeTask?.cancel()
        realtimeTripID = tripID
        realtimeTask = Task { [client] in
            let channel = client.channel("trip-\(tripID.uuidString)")
            let placeChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "places", filter: .eq("trip_id", value: tripID))
            let documentChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "documents", filter: .eq("trip_id", value: tripID))
            let tripChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "trips", filter: .eq("id", value: tripID))
            do { try await channel.subscribeWithError() } catch { return }
            await withTaskGroup(of: Void.self) { group in
                group.addTask { for await _ in placeChanges { await onChange() } }
                group.addTask { for await _ in documentChanges { await onChange() } }
                group.addTask { for await _ in tripChanges { await onChange() } }
            }
        }
    }

    private func ensureSession() async throws {
        if (try? await client.auth.session) == nil { _ = try await client.auth.signInAnonymously() }
    }

    /// Geht die anonyme Anmeldung verloren, meldet sich die App neu an und ist dann kein Mitglied mehr:
    /// Lesen liefert leere Listen, Schreiben scheitert an den Zugriffsregeln. Dann mit der gemerkten Einladung neu beitreten.
    private func ensureMembership(tripID: UUID, inviteToken: String?) async throws {
        struct MemberRow: Decodable { let user_id: UUID }
        let rows: [MemberRow] = try await client.from("trip_members")
            .select("user_id").eq("trip_id", value: tripID).limit(1).execute().value
        guard rows.isEmpty else { return }
        guard let inviteToken, inviteToken.count >= 32 else { throw AlbumSyncError.membershipLost }
        let response: JoinTripResponse = try await client.functions.invoke(
            "join-trip",
            options: FunctionInvokeOptions(body: JoinTripRequest(inviteToken: inviteToken))
        )
        guard response.tripID == tripID else { throw AlbumSyncError.membershipLost }
    }

    private func pushDirty(store: AlbumStore, tripID: UUID) async throws {
        if store.data.dirty.contains("trip") {
            let row = TripRow(id: tripID, payload: store.data.trip, updatedAt: store.data.trip.updatedAt)
            try await client.from("trips").update(row).eq("id", value: tripID).execute()
            store.data.dirty.remove("trip")
        }
        for index in store.data.places.indices where store.data.dirty.contains(store.data.places[index].id) {
            var place = store.data.places[index]
            if case .uploaded(var image) = place.image, image.storagePath == nil {
                let path = "\(tripID.uuidString)/\(place.id)/\(image.id).jpg"
                let bytes = try Data(contentsOf: PlaceImageStorage.localURL(for: image, root: store.root))
                guard bytes.count <= 5_000_000 else { throw NSError(domain: "Album", code: 5, userInfo: [NSLocalizedDescriptionKey: "Bitte ein Foto unter 5 MB verwenden."]) }
                try await client.storage.from("trip-images").upload(
                    path,
                    data: bytes,
                    options: FileOptions(cacheControl: "86400", contentType: "image/jpeg", upsert: true)
                )
                image.storagePath = path
                place.image = .uploaded(image)
                store.data.places[index] = place
            }
            let row = PlaceRow(id: place.id, tripID: tripID, payload: place, updatedAt: place.updatedAt, deleted: place.deleted)
            try await client.from("places").upsert(row, onConflict: "trip_id,id").execute()
            store.data.dirty.remove(place.id)
        }
        for document in store.data.documents where store.data.dirty.contains("doc-" + document.id) {
            let path = "\(tripID.uuidString)/\(document.id).pdf"
            let file = store.root.appendingPathComponent(document.filename)
            let bytes = try Data(contentsOf: file)
            guard bytes.count <= 25_000_000 else { throw NSError(domain: "Album", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bitte ein PDF unter 25 MB verwenden."]) }
            try await client.storage.from("trip-files").upload(
                path,
                data: bytes,
                options: FileOptions(cacheControl: "3600", contentType: "application/pdf", upsert: true)
            )
            let row = DocumentRow(id: document.id, tripID: tripID, name: document.name, filename: document.filename, extractedText: document.extractedText, storagePath: path, updatedAt: document.updatedAt)
            try await client.from("documents").upsert(row, onConflict: "trip_id,id").execute()
            store.data.dirty.remove("doc-" + document.id)
        }
        let imageDeletes = store.data.dirty.filter { $0.hasPrefix("image-delete:") }
        for marker in imageDeletes {
            let path = String(marker.dropFirst("image-delete:".count))
            try await client.storage.from("trip-images").remove(paths: [path])
            store.data.dirty.remove(marker)
        }
    }

    private func downloadDocument(_ row: DocumentRow, into root: URL) async throws {
        let destination = root.appendingPathComponent(row.filename)
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        let bytes = try await client.storage.from("trip-files").download(path: row.storagePath)
        try bytes.write(to: destination, options: .atomic)
    }

    private func downloadImageIfNeeded(_ place: Place, tripID: UUID, into root: URL) async throws {
        guard case .uploaded(let image) = place.image, let path = image.storagePath else { return }
        let destination = PlaceImageStorage.localURL(for: image, root: root)
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        let expectedPrefix = "\(tripID.uuidString)/\(place.id)/"
        guard path.hasPrefix(expectedPrefix) else { throw CocoaError(.fileReadNoPermission) }
        let bytes = try await client.storage.from("trip-images").download(path: path)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: destination, options: .atomic)
    }
}
