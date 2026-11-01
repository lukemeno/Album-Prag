import Foundation
import PDFKit
import Supabase
import UIKit

enum AlbumSyncError: LocalizedError {
    case missingConfiguration
    case invalidInvitation
    case missingTrip
    case membershipLost
    case protocolUpgradeRequired
    case syncConflict
    case tripRemoved

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
        case .protocolUpgradeRequired:
            return "Diese gemeinsame Reise wurde aktualisiert. Bitte bringe Album auf den neuesten Stand und synchronisiere erneut."
        case .syncConflict:
            return "Ein anderes Gerät hat die gemeinsame Reise gerade geändert. Deine Änderungen sind gespeichert und werden beim nächsten Abgleich übertragen."
        case .tripRemoved:
            return "Diese Reise wurde gelöscht oder du bist nicht mehr dabei. Was hier liegt, bleibt auf diesem iPhone, bis du die Reise in der Übersicht löschst."
        }
    }
}

enum SupabaseConfiguration {
    /// Database coding shared by the production client and live integration tests.
    ///
    /// Supabase's current rows use ISO-8601 strings, while the original seed row
    /// contains a finite numeric date. Keep the SDK's encoder so all writes retain
    /// its normal ISO-8601 representation.
    static func databaseOptions() -> SupabaseClientOptions.DatabaseOptions {
        let decoder = JSONDecoder()
        let sdkDateDecodingStrategy = PostgrestClient.Configuration.jsonDecoder.dateDecodingStrategy
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if let number = try? container.decode(Double.self) {
                guard number.isFinite else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Date number must be finite"
                    )
                }

                // The old backend seed stores Date.distantPast as Unix seconds.
                // All other numeric JSON dates use Swift's reference-date seconds.
                if number == -62_135_769_600 {
                    return Date(timeIntervalSince1970: number)
                }
                return Date(timeIntervalSinceReferenceDate: number)
            }

            // Delegate string parsing to the SDK's own strategy so its supported
            // ISO-8601 variants remain the single source of truth.
            if case .custom(let decode) = sdkDateDecodingStrategy {
                return try decode(decoder)
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Supabase SDK date strategy is not custom"
            )
        }
        return SupabaseClientOptions.DatabaseOptions(decoder: decoder)
    }

    static func client(bundle: Bundle = .main) throws -> SupabaseClient {
        guard let rawURL = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: rawURL), !rawURL.contains("YOUR_PROJECT"),
              let key = bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !key.isEmpty, !key.contains("YOUR_PUBLISHABLE_KEY") else {
            throw AlbumSyncError.missingConfiguration
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(db: databaseOptions())
        )
    }
}

@MainActor protocol AlbumSyncService: AnyObject {
    func createTrip(store: AlbumStore) async throws -> CollaborationState
    func joinTrip(token: String) async throws -> CollaborationState
    func sync(store: AlbumStore) async throws
    func startRealtime(onChange: @escaping @MainActor @Sendable () async -> Void)
    func stopRealtime() async
    func authenticatedUserID() async throws -> String
    func tripRole(tripID: UUID) async throws -> TripMemberRole?
    func endMembership(tripID: UUID, deleteForEveryone: Bool) async throws
}

@MainActor extension AlbumSyncService {
    /// Test and alternate sync services may not expose an authenticated server identity.
    func authenticatedUserID() async throws -> String { throw AlbumSyncError.missingConfiguration }

    /// Lifecycle hook for stores that are replaced by the trip library. Older
    /// test doubles remain source compatible and simply do nothing.
    func stopRealtime() async {}

    func tripRole(tripID: UUID) async throws -> TripMemberRole? { throw AlbumSyncError.missingConfiguration }
    func endMembership(tripID: UUID, deleteForEveryone: Bool) async throws { throw AlbumSyncError.missingConfiguration }
}

enum TripMemberRole: String, Decodable { case owner, member }

private struct TripLifecycleRequest: Encodable {
    let tripID: UUID
    enum CodingKeys: String, CodingKey { case tripID = "trip_id" }
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

/// Postgres liefert Mikrosekunden; für CAS wird der exakte Text zurückgeschickt, nicht ein gerundetes `Date`.
private func parseSyncTimestamp(_ value: String) throws -> Date {
    for options: ISO8601DateFormatter.Options in [[.withInternetDateTime, .withFractionalSeconds], [.withInternetDateTime]] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        if let date = formatter.date(from: value) { return date }
    }
    throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid server sync timestamp"))
}

private struct TripRow: Codable {
    let id: UUID
    let payload: TripInfo
    let updatedAt: Date
    let revision: String
    enum CodingKeys: String, CodingKey { case id, payload; case updatedAt = "updated_at" }

    init(id: UUID, payload: TripInfo, updatedAt: Date, revision: String = "") {
        self.id = id
        self.payload = payload
        self.updatedAt = updatedAt
        self.revision = revision
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        payload = try values.decode(TripInfo.self, forKey: .payload)
        if let text = try? values.decode(String.self, forKey: .updatedAt), let date = try? parseSyncTimestamp(text) {
            revision = text
            updatedAt = date
        } else {
            updatedAt = try values.decode(Date.self, forKey: .updatedAt)
            revision = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(payload, forKey: .payload)
        try values.encode(updatedAt, forKey: .updatedAt)
    }
}

private struct PlaceRow: Codable {
    let id: String
    let tripID: UUID
    let payload: Place
    let updatedAt: Date
    let revision: String
    let deleted: Bool
    enum CodingKeys: String, CodingKey {
        case id, payload, deleted
        case tripID = "trip_id"
        case updatedAt = "updated_at"
    }

    init(id: String, tripID: UUID, payload: Place, updatedAt: Date, deleted: Bool, revision: String = "") {
        self.id = id
        self.tripID = tripID
        self.payload = payload
        self.updatedAt = updatedAt
        self.revision = revision
        self.deleted = deleted
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        tripID = try values.decode(UUID.self, forKey: .tripID)
        payload = try values.decode(Place.self, forKey: .payload)
        if let text = try? values.decode(String.self, forKey: .updatedAt), let date = try? parseSyncTimestamp(text) {
            revision = text
            updatedAt = date
        } else {
            updatedAt = try values.decode(Date.self, forKey: .updatedAt)
            revision = ""
        }
        deleted = try values.decode(Bool.self, forKey: .deleted)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(tripID, forKey: .tripID)
        try values.encode(payload, forKey: .payload)
        try values.encode(updatedAt, forKey: .updatedAt)
        try values.encode(deleted, forKey: .deleted)
    }
}

struct V2PlaceSyncPayload: Encodable, Equatable {
    let id: String
    let payload: Place
    let updatedAt: Date
    let deleted: Bool
    let expectedUpdatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, payload, deleted
        case updatedAt = "updated_at"
        case expectedUpdatedAt = "expected_updated_at"
    }
}

struct V2SyncRevision: Decodable, Equatable {
    let tripUpdatedAt: String
    let placeUpdatedAt: [String: String]
    enum CodingKeys: String, CodingKey { case tripUpdatedAt = "trip_updated_at", placeUpdatedAt = "place_updated_at" }
}

struct V2SyncParameters: Encodable {
    let tripID: UUID
    let tripPayload: TripInfo?
    let expectedTripUpdatedAt: String?
    let places: [V2PlaceSyncPayload]
    enum CodingKeys: String, CodingKey {
        case tripID = "p_trip_id", tripPayload = "p_trip_payload"
        case expectedTripUpdatedAt = "p_expected_trip_updated_at", places = "p_places"
    }

    // Explizites null, damit die RPC-Signatur mit vier Parametern eindeutig getroffen wird.
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(tripID, forKey: .tripID)
        try values.encode(tripPayload, forKey: .tripPayload)
        try values.encode(expectedTripUpdatedAt, forKey: .expectedTripUpdatedAt)
        try values.encode(places, forKey: .places)
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

struct CollectionSyncRow: Codable {
    let id: String
    let tripID: UUID
    let payload: CollectionEntry
    let version: Int64
    let deleted: Bool
    let updatedAt: Date
    enum CodingKeys: String, CodingKey {
        case id, payload, version, deleted
        case tripID = "trip_id"
        case updatedAt = "updated_at"
    }
}

private struct TripFeatureRow: Decodable {
    let id: UUID
    let tripID: UUID
    let kind: String
    let payload: TripMemoryPhoto
    let ownerID: UUID
    let version: Int64
    let mutationToken: UUID
    let deleted: Bool
    let storagePath: String?
    enum CodingKeys: String, CodingKey {
        case id, kind, payload, version, deleted
        case tripID = "trip_id", ownerID = "owner_id", mutationToken = "mutation_token", storagePath = "storage_path"
    }
}

private struct CommitTripFeatureParameters: Encodable {
    let tripID: UUID; let id: UUID; let kind = "photo"; let payload: String; let ownerID: UUID
    let deleted: Bool; let mutationToken: UUID; let expectedVersion: Int64?; let storagePath: String?
    enum CodingKeys: String, CodingKey {
        case kind = "p_kind", payload = "p_payload", deleted = "p_deleted"
        case tripID = "p_trip_id", id = "p_id", ownerID = "p_owner_id", mutationToken = "p_mutation_token"
        case expectedVersion = "p_expected_version", storagePath = "p_storage_path"
    }
}

@MainActor
protocol CollectionSyncTransport: AnyObject {
    func pull(tripID: UUID) async throws -> [CollectionSyncRow]
    func insert(_ row: CollectionSyncRow) async throws -> CollectionSyncRow
    func fetch(id: String, tripID: UUID) async throws -> CollectionSyncRow?
    func update(_ row: CollectionSyncRow, expectedVersion: Int64) async throws -> CollectionSyncRow?
}

@MainActor
private final class SupabaseCollectionSyncTransport: CollectionSyncTransport {
    let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func pull(tripID: UUID) async throws -> [CollectionSyncRow] {
        try await client.from("collection_entries").select().eq("trip_id", value: tripID).execute().value
    }

    func insert(_ row: CollectionSyncRow) async throws -> CollectionSyncRow {
        let response: [CollectionSyncRow] = try await client.from("collection_entries").insert(row).select().execute().value
        return response.first ?? row
    }

    func fetch(id: String, tripID: UUID) async throws -> CollectionSyncRow? {
        let response: [CollectionSyncRow] = try await client.from("collection_entries").select().eq("trip_id", value: tripID).eq("id", value: id).execute().value
        return response.first
    }

    func update(_ row: CollectionSyncRow, expectedVersion: Int64) async throws -> CollectionSyncRow? {
        let response: [CollectionSyncRow] = try await client.from("collection_entries")
            .update(row).eq("trip_id", value: row.tripID).eq("id", value: row.id).eq("version", value: String(expectedVersion)).select().execute().value
        return response.first
    }
}

@MainActor
protocol SupabaseSyncWriteTransport: AnyObject {
    func updateTrip(tripID: UUID, payload: TripInfo) async throws
    func syncTripV2(tripID: UUID, tripPayload: TripInfo?, expectedTripUpdatedAt: String?, places: [V2PlaceSyncPayload]) async throws -> V2SyncRevision
    func uploadImage(path: String, data: Data) async throws
    func upsertPlace(id: String, tripID: UUID, payload: Place, updatedAt: Date, deleted: Bool) async throws
    func uploadDocument(path: String, data: Data) async throws
    func upsertDocument(id: String, tripID: UUID, name: String, filename: String, extractedText: String, storagePath: String, updatedAt: Date) async throws
    func removeImage(path: String) async throws
}

@MainActor
protocol SupabaseStorageDownloadTransport: AnyObject {
    func download(bucket: String, path: String) async throws -> Data
}

@MainActor
private final class SupabaseStorageDownloadTransportLive: SupabaseStorageDownloadTransport {
    let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    func download(bucket: String, path: String) async throws -> Data {
        try await client.storage.from(bucket).download(path: path)
    }
}

@MainActor
private final class SupabaseSyncWriteTransportLive: SupabaseSyncWriteTransport {
    let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    func updateTrip(tripID: UUID, payload: TripInfo) async throws {
        try await client.from("trips")
            .update(TripRow(id: tripID, payload: payload, updatedAt: payload.updatedAt))
            .eq("id", value: tripID)
            .execute()
    }

    func syncTripV2(tripID: UUID, tripPayload: TripInfo?, expectedTripUpdatedAt: String?, places: [V2PlaceSyncPayload]) async throws -> V2SyncRevision {
        try await client.rpc("sync_trip_v2", params: V2SyncParameters(tripID: tripID, tripPayload: tripPayload,
                                                                    expectedTripUpdatedAt: expectedTripUpdatedAt, places: places)).execute().value
    }

    func uploadImage(path: String, data: Data) async throws {
        try await client.storage.from("trip-images").upload(
            path,
            data: data,
            options: FileOptions(cacheControl: "86400", contentType: "image/jpeg", upsert: true)
        )
    }

    func upsertPlace(id: String, tripID: UUID, payload: Place, updatedAt: Date, deleted: Bool) async throws {
        try await client.from("places")
            .upsert(PlaceRow(id: id, tripID: tripID, payload: payload, updatedAt: updatedAt, deleted: deleted), onConflict: "trip_id,id")
            .execute()
    }

    func uploadDocument(path: String, data: Data) async throws {
        try await client.storage.from("trip-files").upload(
            path,
            data: data,
            options: FileOptions(cacheControl: "3600", contentType: "application/pdf", upsert: true)
        )
    }

    func upsertDocument(id: String, tripID: UUID, name: String, filename: String, extractedText: String, storagePath: String, updatedAt: Date) async throws {
        let row = DocumentRow(id: id, tripID: tripID, name: name, filename: filename, extractedText: extractedText, storagePath: storagePath, updatedAt: updatedAt)
        try await client.from("documents").upsert(row, onConflict: "trip_id,id").execute()
    }

    func removeImage(path: String) async throws {
        try await client.storage.from("trip-images").remove(paths: [path])
    }
}

@MainActor
protocol SupabaseRealtimeTransport: AnyObject {
    func subscribe(tripID: UUID, onChange: @escaping @MainActor @Sendable () async -> Void) async throws
}

struct SupabaseRealtimeReadiness {
    enum Failure: Error { case unavailable }
    private var postgresReady = false
    private var replicationReady = false

    mutating func receive(extensionName name: String?, status: String?) throws -> Bool {
        guard name == "postgres_changes" || name == "system" else { return false }
        if status == "error" || status == "timeout" { throw Failure.unavailable }
        guard status == "ok" else { return false }
        if name == "postgres_changes" { postgresReady = true }
        if name == "system" { replicationReady = true }
        return postgresReady && replicationReady
    }
}

@MainActor
private final class SupabaseRealtimeTransportLive: SupabaseRealtimeTransport {
    let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    func subscribe(tripID: UUID, onChange: @escaping @MainActor @Sendable () async -> Void) async throws {
        // Every attempt owns a distinct topic so an old cancelled task can never
        // remove a channel that a newer retry has already started using.
        let channel = client.channel("trip-\(tripID.uuidString)-\(UUID().uuidString)") {
            $0.broadcast.replicationReady = true
        }
        // Register this stream before subscribing: the server's replication-ready
        // system event is emitted during the join and must not be missed.
        let systemMessages = channel.system()
        // Keep the wire filter spelling aligned with the backend's UUID form so
        // the SDK's exact callback-filter comparison can match its reply metadata.
        let tripFilterValue = tripID.uuidString.lowercased()
        let placeChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "places", filter: .eq("trip_id", value: tripFilterValue))
        let documentChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "documents", filter: .eq("trip_id", value: tripFilterValue))
        let tripChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "trips", filter: .eq("id", value: tripFilterValue))
        let collectionChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "collection_entries", filter: .eq("trip_id", value: tripFilterValue))
        let tripFeatureChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "trip_feature_entries", filter: .eq("trip_id", value: tripFilterValue))
        do {
            try await channel.subscribeWithError()
            try await waitForReplicationReady(systemMessages)
            try Task.checkCancellation()
            await onChange()
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in placeChanges {
                        guard !Task.isCancelled else { break }
                        await onChange()
                    }
                }
                group.addTask {
                    for await _ in documentChanges {
                        guard !Task.isCancelled else { break }
                        await onChange()
                    }
                }
                group.addTask {
                    for await _ in tripChanges {
                        guard !Task.isCancelled else { break }
                        await onChange()
                    }
                }
                group.addTask {
                    for await _ in collectionChanges {
                        guard !Task.isCancelled else { break }
                        await onChange()
                    }
                }
                group.addTask {
                    for await _ in tripFeatureChanges {
                        guard !Task.isCancelled else { break }
                        await onChange()
                    }
                }
            }
        } catch {
            await client.removeChannel(channel)
            throw error
        }
        await client.removeChannel(channel)
    }

    private enum ReplicationReadinessError: Error { case unavailable, timedOut }

    private func waitForReplicationReady(_ messages: AsyncStream<RealtimeMessageV2>) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                var readiness = SupabaseRealtimeReadiness()
                for await message in messages {
                    try Task.checkCancellation()
                    if try readiness.receive(extensionName: message.payload["extension"]?.stringValue,
                                             status: message.payload["status"]?.stringValue) {
                        return
                    }
                }
                throw ReplicationReadinessError.unavailable
            }
            group.addTask {
                try await Task.sleep(for: .seconds(10))
                throw ReplicationReadinessError.timedOut
            }
            defer { group.cancelAll() }
            try await group.next()
        }
    }

}

private enum CollectionCASFailure: Error { case conflict, missing }
private enum RemoteFileValidationError: Error { case invalidPDF, invalidImage }
private struct DownloadedFile {
    let data: Data
    let destination: URL
}

private struct LocalFileState: Equatable {
    let exists: Bool
    let data: Data?
}

/// Zuletzt gelesene Server-Revisionen je Reise; Grundlage für das CAS von `sync_trip_v2`.
private struct V2RevisionCache: Codable {
    var tripUpdatedAt: String?
    var placeUpdatedAt: [String: String] = [:]
    var knownPlaceIDs: Set<String> = []
}

@MainActor final class SupabaseSync: AlbumSyncService {
    private let client: SupabaseClient
    private let collectionTransport: any CollectionSyncTransport
    private let writeTransport: any SupabaseSyncWriteTransport
    private let storageDownloadTransport: any SupabaseStorageDownloadTransport
    private let realtimeTransport: any SupabaseRealtimeTransport
    private var realtimeTask: Task<Void, Never>?
    private var realtimeTripID: UUID?
    private var realtimeAttemptID: UUID?
    private(set) var isRealtimeReady = false
    private var activeTripID: UUID?
    private var revisionCaches: [UUID: V2RevisionCache] = [:]

    static func configured(bundle: Bundle = .main) throws -> SupabaseSync {
        SupabaseSync(client: try SupabaseConfiguration.client(bundle: bundle))
    }

    init(client: SupabaseClient,
         collectionTransport: (any CollectionSyncTransport)? = nil,
         writeTransport: (any SupabaseSyncWriteTransport)? = nil,
         realtimeTransport: (any SupabaseRealtimeTransport)? = nil,
         storageDownloadTransport: (any SupabaseStorageDownloadTransport)? = nil) {
        self.client = client
        self.collectionTransport = collectionTransport ?? SupabaseCollectionSyncTransport(client: client)
        self.writeTransport = writeTransport ?? SupabaseSyncWriteTransportLive(client: client)
        self.storageDownloadTransport = storageDownloadTransport ?? SupabaseStorageDownloadTransportLive(client: client)
        self.realtimeTransport = realtimeTransport ?? SupabaseRealtimeTransportLive(client: client)
    }

    deinit {
        realtimeTask?.cancel()
    }

    #if DEBUG
    convenience init(collectionTransport: any CollectionSyncTransport) {
        self.init(client: SupabaseClient(supabaseURL: URL(string: "https://example.invalid")!, supabaseKey: "test"), collectionTransport: collectionTransport)
    }

    convenience init(writeTransport: any SupabaseSyncWriteTransport) {
        self.init(client: SupabaseClient(supabaseURL: URL(string: "https://example.invalid")!, supabaseKey: "test"), writeTransport: writeTransport)
    }

    convenience init(writeTransport: any SupabaseSyncWriteTransport, realtimeTransport: any SupabaseRealtimeTransport) {
        self.init(client: SupabaseClient(supabaseURL: URL(string: "https://example.invalid")!, supabaseKey: "test"), writeTransport: writeTransport, realtimeTransport: realtimeTransport)
    }

    convenience init(storageDownloadTransport: any SupabaseStorageDownloadTransport) {
        self.init(client: SupabaseClient(supabaseURL: URL(string: "https://example.invalid")!, supabaseKey: "test"), storageDownloadTransport: storageDownloadTransport)
    }
#endif

    func createTrip(store: AlbumStore) async throws -> CollaborationState {
        try await ensureSession()
        let response: CreateTripResponse = try await client.functions.invoke("create-trip")
        activeTripID = response.tripID
        let tripRows: [TripRow] = try await client.from("trips").select().eq("id", value: response.tripID).execute().value
        if let tripRow = tripRows.first, !tripRow.revision.isEmpty {
            var cache = revisionCache(tripID: response.tripID, store: store)
            cache.tripUpdatedAt = tripRow.revision
            saveRevisionCache(cache, tripID: response.tripID, store: store)
        }
        try await pushDirty(store: store, tripID: response.tripID)
        return CollaborationState(tripID: response.tripID, inviteToken: response.inviteToken)
    }

    func authenticatedUserID() async throws -> String {
        try await ensureSession()
        return (try await client.auth.session).user.id.uuidString.lowercased()
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

    /// Ein CAS-Konflikt bedeutet, dass zwischen Lesen und Schreiben jemand anderes geschrieben hat;
    /// ein zweiter Durchlauf liest den neuen Stand und versucht es genau einmal erneut.
    func sync(store: AlbumStore) async throws {
        do {
            try await syncPass(store: store)
        } catch AlbumSyncError.syncConflict {
            try await syncPass(store: store)
        }
    }

    private func syncPass(store: AlbumStore) async throws {
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
        let remoteCollections = try await collectionTransport.pull(tripID: collaboration.tripID)
        let remotePhotos: [TripFeatureRow] = try await client.from("trip_feature_entries").select()
            .eq("trip_id", value: collaboration.tripID).eq("kind", value: "photo").execute().value

        recordRevisions(trip: tripRows.first, places: remotePlaces, tripID: collaboration.tripID, store: store)

        if let remoteTrip = tripRows.first {
            let localDate = store.data.trip.updatedAt
            let localTrip = store.data.trip
            let mergedTrip = AlbumMerge.trip(local: localTrip, remote: remoteTrip.payload)
            store.data.trip = mergedTrip
            let ledgerNeedsUpload = mergedTrip.expenses != remoteTrip.payload.expenses
                || mergedTrip.settlements != remoteTrip.payload.settlements
            if ledgerNeedsUpload {
                // Independent offline ledger entries were unioned into the remote
                // winner; publish that union without changing scalar LWW fields.
                store.data.dirty.insert("trip")
            } else if remoteTrip.updatedAt > localDate {
                store.data.dirty.remove("trip")
            }
        }

        for row in remotePlaces {
            try await applyPlaceRow(row, store: store, tripID: collaboration.tripID)
        }

        if let remoteTrip = tripRows.first {
            stageV2Transition(store: store, remoteTripVersion: remoteTrip.payload.planningSchemaVersion,
                              remotePlaceIDs: Set(remotePlaces.map(\.id)))
        }

        for row in remoteDocuments {
            try await applyDocumentRow(row, store: store)
        }

        for row in remoteCollections {
            let local = store.data.collectionEntries.first(where: { $0.id == row.id })
            let marker = "collection:" + row.id
            let localVersion = store.data.collectionSync[row.id]?.serverVersion
            if !store.data.dirty.contains(marker) || local == nil {
                if local == nil || row.version > (localVersion ?? 0) {
                    if let index = store.data.collectionEntries.firstIndex(where: { $0.id == row.id }) { store.data.collectionEntries[index] = row.payload } else { store.data.collectionEntries.append(row.payload) }
                    store.data.collectionSync[row.id] = CollectionSyncMetadata(serverVersion: row.version, mutationToken: store.data.collectionSync[row.id]?.mutationToken ?? UUID().uuidString, lastErrorCode: nil)
                    if local == nil { store.data.dirty.remove(marker) }
                }
            }
        }

        for row in remotePhotos { try await applyTripPhotoRow(row, store: store, tripID: collaboration.tripID) }

        guard store.persist() else { throw CocoaError(.fileWriteUnknown) }
        try await pushDirty(store: store, tripID: collaboration.tripID)
        guard store.persist() else { throw CocoaError(.fileWriteUnknown) }
    }

    func startRealtime(onChange: @escaping @MainActor @Sendable () async -> Void) {
        guard !Task.isCancelled else { return }
        guard let tripID = activeTripID, realtimeTripID != tripID else { return }
        realtimeTask?.cancel()
        realtimeTripID = tripID
        isRealtimeReady = false
        let attemptID = UUID()
        realtimeAttemptID = attemptID
        let transport = realtimeTransport
        let guardedChange: @MainActor @Sendable () async -> Void = { [weak self] in
            guard let self,
                  !Task.isCancelled,
                  self.realtimeTripID == tripID,
                  self.realtimeAttemptID == attemptID else { return }
            await onChange()
            guard !Task.isCancelled,
                  self.realtimeTripID == tripID,
                  self.realtimeAttemptID == attemptID else { return }
            self.isRealtimeReady = true
        }
        realtimeTask = Task { [weak self] in
            do { try await transport.subscribe(tripID: tripID, onChange: guardedChange) } catch { }
            await self?.realtimeFinished(tripID: tripID, attemptID: attemptID)
        }
    }

    func stopRealtime() async {
        let task = realtimeTask
        realtimeTask = nil
        realtimeTripID = nil
        realtimeAttemptID = nil
        isRealtimeReady = false
        task?.cancel()
        await task?.value
    }

    private func realtimeFinished(tripID: UUID, attemptID: UUID) {
        guard realtimeAttemptID == attemptID else { return }
        realtimeAttemptID = nil
        realtimeTask = nil
        realtimeTripID = nil
        isRealtimeReady = false
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
        let response: JoinTripResponse
        do {
            response = try await client.functions.invoke(
                "join-trip",
                options: FunctionInvokeOptions(body: JoinTripRequest(inviteToken: inviteToken))
            )
        } catch FunctionsError.httpError(404, _) {
            // The invitation no longer resolves: the trip was deleted.
            throw AlbumSyncError.tripRemoved
        }
        guard response.tripID == tripID else { throw AlbumSyncError.membershipLost }
    }

    func tripRole(tripID: UUID) async throws -> TripMemberRole? {
        struct RoleRow: Decodable { let role: TripMemberRole }
        try await ensureSession()
        let me = try await authenticatedUserID()
        let rows: [RoleRow] = try await client.from("trip_members").select("role")
            .eq("trip_id", value: tripID).eq("user_id", value: me).limit(1).execute().value
        return rows.first?.role
    }

    /// Owners delete for everyone, members leave. The server answers "gone"
    /// with 200 when the trip no longer exists, so a retry is harmless.
    func endMembership(tripID: UUID, deleteForEveryone: Bool) async throws {
        try await ensureSession()
        try await client.functions.invoke(
            deleteForEveryone ? "delete-trip" : "leave-trip",
            options: FunctionInvokeOptions(body: TripLifecycleRequest(tripID: tripID))
        )
    }

    /// Merkt sich die gelesenen Server-Revisionen als CAS-Basis. Lokale, noch nicht übertragene Änderungen
    /// überschreiben beim nächsten Schreiben den gelesenen Stand (wie bisher); das CAS schützt das Fenster
    /// zwischen Lesen und Schreiben.
    private func recordRevisions(trip: TripRow?, places: [PlaceRow], tripID: UUID, store: AlbumStore) {
        var revisions = revisionCache(tripID: tripID, store: store)
        if let trip, !trip.revision.isEmpty { revisions.tripUpdatedAt = trip.revision }
        for row in places where !row.revision.isEmpty { revisions.placeUpdatedAt[row.id] = row.revision }
        revisions.knownPlaceIDs.formUnion(places.map(\.id))
        saveRevisionCache(revisions, tripID: tripID, store: store)
    }

    /// Übergang v1→v2: Ist die Reise auf dem Server noch v1, werden Reise und alle dort vorhandenen Orte
    /// in einem atomaren `sync_trip_v2`-Aufruf umgestellt. Neu gezogene Orte mit alten Tageszahlen werden
    /// vorher wie beim Laden umgerechnet; ungelöste Werte bleiben erhalten.
    private func stageV2Transition(store: AlbumStore, remoteTripVersion: Int?, remotePlaceIDs: Set<String>) {
        store.normalizeLegacyPlanning()
        guard remoteTripVersion != 2, store.data.trip.planningSchemaVersion == 2 else { return }
        store.data.trip.updatedAt = Date()
        store.data.dirty.insert("trip")
        for index in store.data.places.indices {
            let id = store.data.places[index].id
            guard remotePlaceIDs.contains(id) || store.data.dirty.contains(id) else { continue }
            store.data.places[index].planningSchemaVersion = 2
            store.data.dirty.insert(id)
        }
    }

    private func pushDirty(store: AlbumStore, tripID: UUID) async throws {
        let isV2Trip = store.data.trip.planningSchemaVersion == 2
        let tripSnapshot = store.data.dirty.contains("trip") ? store.data.trip : nil
        if let snapshot = tripSnapshot, !isV2Trip {
            try await performSyncWrite { try await writeTransport.updateTrip(tripID: tripID, payload: snapshot) }
            if encodedEqual(store.data.trip, snapshot) { store.data.dirty.remove("trip") }
        }
        var v2PlaceWrites: [Place] = []
        let placeIDs = store.data.places.filter { store.data.dirty.contains($0.id) }.map(\.id)
        for placeID in placeIDs {
            guard let index = store.data.places.firstIndex(where: { $0.id == placeID }) else { continue }
            let snapshot = store.data.places[index]
            var place = snapshot
            if case .uploaded(let image) = snapshot.image, image.storagePath == nil {
                let path = "\(tripID.uuidString)/\(snapshot.id)/\(image.id).jpg"
                let bytes = try Data(contentsOf: PlaceImageStorage.localURL(for: image, root: store.root))
                guard bytes.count <= 5_000_000 else { throw NSError(domain: "Album", code: 5, userInfo: [NSLocalizedDescriptionKey: "Bitte ein Foto unter 5 MB verwenden."]) }
                try await writeTransport.uploadImage(path: path, data: bytes)
                guard let currentIndex = store.data.places.firstIndex(where: { $0.id == placeID }) else { continue }
                place = store.data.places[currentIndex]
                switch place.image {
                case .uploaded(var currentImage) where currentImage.id == image.id && currentImage.storagePath == nil:
                    currentImage.storagePath = path
                    place.image = .uploaded(currentImage)
                    store.data.places[currentIndex] = place
                case .uploaded(let currentImage) where currentImage.id != image.id && currentImage.storagePath == nil:
                    continue
                default:
                    break
                }
            }
            if isV2Trip {
                place.planningSchemaVersion = 2
                v2PlaceWrites.append(place)
            } else {
                try await performSyncWrite {
                    try await writeTransport.upsertPlace(id: place.id, tripID: tripID, payload: place, updatedAt: place.updatedAt, deleted: place.deleted)
                }
                if let currentIndex = store.data.places.firstIndex(where: { $0.id == placeID }), store.data.places[currentIndex] == place {
                    store.data.dirty.remove(placeID)
                }
            }
        }
        if isV2Trip, tripSnapshot != nil || !v2PlaceWrites.isEmpty {
            try await pushV2(store: store, tripID: tripID, tripSnapshot: tripSnapshot, places: v2PlaceWrites)
        }
        let documentIDs = store.data.documents.filter { store.data.dirty.contains("doc-" + $0.id) }.map(\.id)
        for documentID in documentIDs {
            guard let index = store.data.documents.firstIndex(where: { $0.id == documentID }) else { continue }
            let snapshot = store.data.documents[index]
            let path = "\(tripID.uuidString)/\(snapshot.id).pdf"
            let file = store.root.appendingPathComponent(snapshot.filename)
            let bytes = try Data(contentsOf: file)
            guard bytes.count <= 25_000_000 else { throw NSError(domain: "Album", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bitte ein PDF unter 25 MB verwenden."]) }
            try await writeTransport.uploadDocument(path: path, data: bytes)
            guard let currentIndex = store.data.documents.firstIndex(where: { $0.id == documentID }), encodedEqual(store.data.documents[currentIndex], snapshot) else { continue }
            try await writeTransport.upsertDocument(id: snapshot.id, tripID: tripID, name: snapshot.name, filename: snapshot.filename, extractedText: snapshot.extractedText, storagePath: path, updatedAt: snapshot.updatedAt)
            if let currentIndex = store.data.documents.firstIndex(where: { $0.id == documentID }), encodedEqual(store.data.documents[currentIndex], snapshot) {
                store.data.dirty.remove("doc-" + documentID)
            }
        }
        try await pushCollectionEntries(store: store, tripID: tripID)
        try await pushTripPhotos(store: store, tripID: tripID)
        let imageDeletes = store.data.dirty.filter { $0.hasPrefix("image-delete:") }
        for marker in imageDeletes {
            let path = String(marker.dropFirst("image-delete:".count))
            try await writeTransport.removeImage(path: path)
            store.data.dirty.remove(marker)
        }
    }

    /// Reise und Orte als ein atomarer Batch mit CAS je Zeile. Ohne bekannte Basis für eine bestehende
    /// Zeile wird nicht geschrieben; der nächste Abgleich liest sie zuerst.
    private func pushV2(store: AlbumStore, tripID: UUID, tripSnapshot: TripInfo?, places: [Place]) async throws {
        var revisions = revisionCache(tripID: tripID, store: store)
        if tripSnapshot != nil && revisions.tripUpdatedAt == nil { throw AlbumSyncError.syncConflict }
        if places.contains(where: { revisions.placeUpdatedAt[$0.id] == nil && revisions.knownPlaceIDs.contains($0.id) }) {
            throw AlbumSyncError.syncConflict
        }
        let writes = places.map { place in
            V2PlaceSyncPayload(id: place.id, payload: place, updatedAt: place.updatedAt, deleted: place.deleted,
                               expectedUpdatedAt: revisions.placeUpdatedAt[place.id])
        }
        var result: V2SyncRevision?
        try await performSyncWrite {
            result = try await writeTransport.syncTripV2(tripID: tripID, tripPayload: tripSnapshot,
                                                         expectedTripUpdatedAt: tripSnapshot == nil ? nil : revisions.tripUpdatedAt,
                                                         places: writes)
        }
        guard let result else { return }
        revisions.tripUpdatedAt = result.tripUpdatedAt
        for (id, updatedAt) in result.placeUpdatedAt { revisions.placeUpdatedAt[id] = updatedAt }
        revisions.knownPlaceIDs.formUnion(writes.map(\.id))
        saveRevisionCache(revisions, tripID: tripID, store: store)
        if let snapshot = tripSnapshot, encodedEqual(store.data.trip, snapshot) { store.data.dirty.remove("trip") }
        for write in writes {
            guard let current = store.data.places.first(where: { $0.id == write.id }) else { continue }
            var acknowledged = current
            acknowledged.planningSchemaVersion = 2
            guard acknowledged == write.payload else { continue }
            if let index = store.data.places.firstIndex(where: { $0.id == write.id }) { store.data.places[index] = acknowledged }
            store.data.dirty.remove(write.id)
        }
    }

    private func performSyncWrite(_ operation: () async throws -> Void) async throws {
        do {
            try await operation()
        } catch {
            let message = String(describing: error) + " " + error.localizedDescription
            if message.contains("ALBUM_SYNC_CONFLICT") { throw AlbumSyncError.syncConflict }
            if message.contains("ALBUM_PROTOCOL_UPGRADE_REQUIRED") { throw AlbumSyncError.protocolUpgradeRequired }
            throw error
        }
    }

    private func revisionCache(tripID: UUID, store: AlbumStore) -> V2RevisionCache {
        if let cached = revisionCaches[tripID] { return cached }
        let cached = (try? Data(contentsOf: revisionCacheURL(tripID: tripID, store: store)))
            .flatMap { try? JSONDecoder().decode(V2RevisionCache.self, from: $0) } ?? V2RevisionCache()
        revisionCaches[tripID] = cached
        return cached
    }

    private func saveRevisionCache(_ cache: V2RevisionCache, tripID: UUID, store: AlbumStore) {
        revisionCaches[tripID] = cache
        guard let bytes = try? JSONEncoder().encode(cache) else { return }
        try? bytes.write(to: revisionCacheURL(tripID: tripID, store: store), options: .atomic)
    }

    private func revisionCacheURL(tripID: UUID, store: AlbumStore) -> URL {
        store.root.appendingPathComponent("sync-v2-\(tripID.uuidString).json")
    }

    private func encodedEqual<T: Encodable>(_ lhs: T, _ rhs: T) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let left = try? encoder.encode(lhs), let right = try? encoder.encode(rhs) else { return false }
        return left == right
    }

    #if DEBUG
    func pushDirtyForTesting(store: AlbumStore, tripID: UUID) async throws {
        try await pushDirty(store: store, tripID: tripID)
    }

    func activateTripForTesting(_ tripID: UUID) {
        activeTripID = tripID
    }

    func seedRevisionCacheForTesting(_ revision: V2SyncRevision, tripID: UUID, store: AlbumStore) {
        saveRevisionCache(V2RevisionCache(tripUpdatedAt: revision.tripUpdatedAt, placeUpdatedAt: revision.placeUpdatedAt,
                                          knownPlaceIDs: Set(revision.placeUpdatedAt.keys)), tripID: tripID, store: store)
    }

    func stageV2TransitionForTesting(store: AlbumStore, remoteTripVersion: Int?, remotePlaceIDs: Set<String>) {
        stageV2Transition(store: store, remoteTripVersion: remoteTripVersion, remotePlaceIDs: remotePlaceIDs)
    }

    func recordRevisionsForTesting(tripRevision: String, placeRevisions: [String: String], tripID: UUID, store: AlbumStore) {
        let trip = TripRow(id: tripID, payload: store.data.trip, updatedAt: Date(), revision: tripRevision)
        let places = placeRevisions.map { id, revision in
            PlaceRow(id: id, tripID: tripID, payload: store.data.places.first { $0.id == id } ?? Place(id: id, title: id),
                     updatedAt: Date(), deleted: false, revision: revision)
        }
        recordRevisions(trip: trip, places: places, tripID: tripID, store: store)
    }
    #endif

    private func pushCollectionEntries(store: AlbumStore, tripID: UUID) async throws {
        let markers = store.data.dirty.filter { $0.hasPrefix("collection:") }.sorted()
        for marker in markers {
            let id = String(marker.dropFirst("collection:".count))
            guard let index = store.data.collectionEntries.firstIndex(where: { $0.id == id }) else { store.data.dirty.remove(marker); continue }
            let entry = store.data.collectionEntries[index]
            let metadata = store.data.collectionSync[id] ?? CollectionSyncMetadata(serverVersion: nil, mutationToken: UUID().uuidString, lastErrorCode: nil)
            let token = metadata.mutationToken
            if store.data.collectionSync[id] == nil { store.data.collectionSync[id] = metadata }
            var acknowledgedVersion: Int64?
            if let expected = metadata.serverVersion {
                acknowledgedVersion = try await updateCollectionWithRetry(store: store, tripID: tripID, id: id, entry: entry, expectedVersion: expected, snapshotToken: token)
            } else {
                do {
                    acknowledgedVersion = try await insertCollection(entry, tripID: tripID)
                } catch {
                    // A concurrent canonical insert is expected. Load it and retry with its version.
                    guard let row = try await collectionTransport.fetch(id: id, tripID: tripID) else { throw error }
                    if store.data.collectionSync[id]?.mutationToken != token {
                        acknowledgedVersion = row.version
                    } else {
                        let merged = mergeCollectionEntry(local: entry, remote: row.payload)
                        store.data.collectionEntries[index] = merged
                        store.data.collectionSync[id] = CollectionSyncMetadata(serverVersion: row.version, mutationToken: token, lastErrorCode: nil)
                        acknowledgedVersion = try await updateCollectionWithRetry(store: store, tripID: tripID, id: id, entry: merged, expectedVersion: row.version, snapshotToken: token)
                    }
                }
            }
            guard let acknowledgedVersion else { throw CollectionCASFailure.missing }
            let currentToken = store.data.collectionSync[id]?.mutationToken
            store.data.collectionSync[id] = CollectionSyncMetadata(serverVersion: acknowledgedVersion, mutationToken: currentToken ?? token, lastErrorCode: nil)
            if currentToken == token { store.data.dirty.remove(marker) }
        }
    }

    private func pushTripPhotos(store: AlbumStore, tripID: UUID) async throws {
        let dirtyIDs = store.data.tripMemories.filter { store.data.dirty.contains("photo-" + $0.id) }.map(\.id)
        guard !dirtyIDs.isEmpty else { return }
        let actorID = try await client.auth.session.user.id
        for id in dirtyIDs {
            guard let index = store.data.tripMemories.firstIndex(where: { $0.id == id }) else { continue }
            var snapshot = store.data.tripMemories[index]
            let token = store.data.tripMemorySync[id]?.mutationToken ?? UUID().uuidString
            if snapshot.authorID.isEmpty {
                snapshot.authorID = actorID.uuidString.lowercased()
                if snapshot.authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { snapshot.authorName = store.me }
            }
            guard UUID(uuidString: snapshot.authorID) == actorID else {
                throw NSError(domain: "Album", code: 403, userInfo: [NSLocalizedDescriptionKey: "Nur die Person, die dieses Foto hinzugefügt hat, kann es ändern."])
            }
            let expectedPath = "\(tripID.uuidString.lowercased())/\(actorID.uuidString.lowercased())/\(id).jpg"
            snapshot.storagePath = expectedPath
            if !snapshot.deleted {
                if store.data.tripMemorySync[id]?.serverVersion == nil {
                    let originalURL = TripMemoryStorage.localURL(for: snapshot, thumbnail: false, root: store.root)
                    let thumbnailURL = TripMemoryStorage.localURL(for: snapshot, thumbnail: true, root: store.root)
                    let original = try Data(contentsOf: originalURL), thumbnail = try Data(contentsOf: thumbnailURL)
                    guard original.count <= 5_000_000, thumbnail.count <= 300_000,
                          isJPEG(original), isJPEG(thumbnail),
                          TripMemoryStorage.digest(original).caseInsensitiveCompare(snapshot.sha256) == .orderedSame,
                          TripMemoryStorage.digest(thumbnail).caseInsensitiveCompare(snapshot.thumbnailSHA256) == .orderedSame else {
                        throw RemoteFileValidationError.invalidImage
                    }
                    let thumbPath = "\(tripID.uuidString.lowercased())/\(actorID.uuidString.lowercased())/\(snapshot.thumbnailFilename)"
                    try await uploadTripPhoto(original, path: expectedPath, digest: snapshot.sha256)
                    try await uploadTripPhoto(thumbnail, path: thumbPath, digest: snapshot.thumbnailSHA256)
                }
            } else if snapshot.storagePath == nil && !snapshot.authorID.isEmpty {
                // A photo created and deleted offline is represented by a metadata-only tombstone.
                snapshot.storagePath = nil
            }
            guard let currentIndex = store.data.tripMemories.firstIndex(where: { $0.id == id }),
                  store.data.tripMemorySync[id]?.mutationToken == token else { continue }
            store.data.tripMemories[currentIndex].authorID = snapshot.authorID
            store.data.tripMemories[currentIndex].authorName = snapshot.authorName
            store.data.tripMemories[currentIndex].storagePath = snapshot.storagePath
            guard store.persist() else { throw CocoaError(.fileWriteUnknown) }
            let encoder = JSONEncoder()
            let payload = String(decoding: try encoder.encode(snapshot), as: UTF8.self)
            let currentVersion = store.data.tripMemorySync[id]?.serverVersion
            let params = CommitTripFeatureParameters(tripID: tripID, id: UUID(uuidString: id) ?? UUID(), payload: payload,
                ownerID: actorID, deleted: snapshot.deleted, mutationToken: UUID(uuidString: token) ?? UUID(),
                expectedVersion: currentVersion, storagePath: snapshot.storagePath)
            let row: TripFeatureRow = try await client.rpc("commit_trip_feature", params: params).execute().value
            if snapshot.deleted, let path = snapshot.storagePath {
                let thumbPath = path.replacingOccurrences(of: ".jpg", with: "-thumb.jpg")
                try await client.storage.from("trip-album").remove(paths: [path, thumbPath])
            }
            guard store.data.tripMemories.contains(where: { $0.id == id }) else { continue }
            let currentToken = store.data.tripMemorySync[id]?.mutationToken
            store.data.tripMemorySync[id] = TripMemorySyncMetadata(serverVersion: row.version, mutationToken: currentToken ?? token)
            if currentToken == token { store.data.dirty.remove("photo-" + id) }
            if snapshot.deleted { TripMemoryStorage.remove(snapshot, root: store.root) }
        }
    }

    private func uploadTripPhoto(_ data: Data, path: String, digest: String) async throws {
        if let existing = try? await storageDownloadTransport.download(bucket: "trip-album", path: path) {
            if TripMemoryStorage.digest(existing).caseInsensitiveCompare(digest) == .orderedSame { return }
            try await client.storage.from("trip-album").remove(paths: [path])
        }
        try await client.storage.from("trip-album").upload(path, data: data,
            options: FileOptions(cacheControl: "86400", contentType: "image/jpeg", upsert: false))
    }

    private func isJPEG(_ data: Data) -> Bool { data.count >= 3 && data[0] == 0xff && data[1] == 0xd8 && data[2] == 0xff }

    private func applyTripPhotoRow(_ row: TripFeatureRow, store: AlbumStore, tripID: UUID) async throws {
        guard row.kind == "photo", row.id.uuidString.lowercased() == row.payload.id.lowercased(),
              row.ownerID.uuidString.lowercased() == row.payload.authorID.lowercased() else { return }
        var photo = row.payload
        photo.deleted = row.deleted
        photo.storagePath = row.storagePath
        let existingIndex = store.data.tripMemories.firstIndex { $0.id == photo.id }
        let isDirty = store.data.dirty.contains("photo-" + photo.id)
        store.data.tripMemorySync[photo.id] = TripMemorySyncMetadata(serverVersion: row.version,
            mutationToken: store.data.tripMemorySync[photo.id]?.mutationToken ?? row.mutationToken.uuidString)
        if photo.deleted {
            if let existingIndex { store.data.tripMemories[existingIndex] = photo } else { store.data.tripMemories.append(photo) }
            store.data.dirty.remove("photo-" + photo.id)
            TripMemoryStorage.remove(photo, root: store.root)
            return
        }
        guard !isDirty else { return }
        if !photo.deleted {
            let prefix = "\(tripID.uuidString.lowercased())/\(row.ownerID.uuidString.lowercased())/"
            guard let originalPath = row.storagePath, originalPath.hasPrefix(prefix),
                  originalPath == prefix + photo.filename else { throw CocoaError(.fileReadNoPermission) }
            let thumbPath = prefix + photo.thumbnailFilename
            let originalURL = TripMemoryStorage.localURL(for: photo, thumbnail: false, root: store.root)
            let thumbURL = TripMemoryStorage.localURL(for: photo, thumbnail: true, root: store.root)
            let cachedOriginal = try? Data(contentsOf: originalURL), cachedThumb = try? Data(contentsOf: thumbURL)
            let cacheIsValid = cachedOriginal.map { isJPEG($0) && TripMemoryStorage.digest($0).caseInsensitiveCompare(photo.sha256) == .orderedSame } == true
                && cachedThumb.map { isJPEG($0) && TripMemoryStorage.digest($0).caseInsensitiveCompare(photo.thumbnailSHA256) == .orderedSame } == true
            if !cacheIsValid {
                let originalState = localFileState(at: originalURL), thumbState = localFileState(at: thumbURL)
                let originalBytes = try await storageDownloadTransport.download(bucket: "trip-album", path: originalPath)
                let thumbBytes = try await storageDownloadTransport.download(bucket: "trip-album", path: thumbPath)
                guard originalBytes.count <= 5_000_000, thumbBytes.count <= 300_000,
                      isJPEG(originalBytes), isJPEG(thumbBytes), UIImage(data: originalBytes) != nil, UIImage(data: thumbBytes) != nil,
                      TripMemoryStorage.digest(originalBytes).caseInsensitiveCompare(photo.sha256) == .orderedSame,
                      TripMemoryStorage.digest(thumbBytes).caseInsensitiveCompare(photo.thumbnailSHA256) == .orderedSame else {
                    throw RemoteFileValidationError.invalidImage
                }
                guard localFileState(at: originalURL) == originalState, localFileState(at: thumbURL) == thumbState,
                      !store.data.dirty.contains("photo-" + photo.id) else { return }
                try commit(DownloadedFile(data: originalBytes, destination: originalURL))
                try commit(DownloadedFile(data: thumbBytes, destination: thumbURL))
            }
        }
        if let existingIndex { store.data.tripMemories[existingIndex] = photo } else { store.data.tripMemories.append(photo) }
        store.data.dirty.remove("photo-" + photo.id)
    }

    #if DEBUG
    func pushCollectionEntriesForTesting(store: AlbumStore, tripID: UUID) async throws {
        try await pushCollectionEntries(store: store, tripID: tripID)
    }
    #endif

    private func insertCollection(_ entry: CollectionEntry, tripID: UUID) async throws -> Int64 {
        let row = CollectionSyncRow(id: entry.id, tripID: tripID, payload: entry, version: 1, deleted: entry.deleted, updatedAt: entry.updatedAt)
        return try await collectionTransport.insert(row).version
    }

    private func updateCollection(_ entry: CollectionEntry, tripID: UUID, expectedVersion: Int64) async throws -> Int64 {
        let row = CollectionSyncRow(id: entry.id, tripID: tripID, payload: entry, version: expectedVersion + 1, deleted: entry.deleted, updatedAt: entry.updatedAt)
        guard let updated = try await collectionTransport.update(row, expectedVersion: expectedVersion) else { throw CollectionCASFailure.conflict }
        return updated.version
    }

    private func updateCollectionWithRetry(store: AlbumStore, tripID: UUID, id: String, entry: CollectionEntry, expectedVersion: Int64, snapshotToken: String) async throws -> Int64 {
        var current = entry
        var version = expectedVersion
        for attempt in 0..<3 {
            guard store.data.collectionSync[id]?.mutationToken == snapshotToken else { return version }
            do {
                return try await updateCollection(current, tripID: tripID, expectedVersion: version)
            } catch CollectionCASFailure.conflict where attempt < 2 {
                guard let row = try await collectionTransport.fetch(id: id, tripID: tripID) else { throw CollectionCASFailure.missing }
                guard store.data.collectionSync[id]?.mutationToken == snapshotToken else { return row.version }
                current = mergeCollectionEntry(local: current, remote: row.payload)
                version = row.version
                if let index = store.data.collectionEntries.firstIndex(where: { $0.id == id }) { store.data.collectionEntries[index] = current }
                store.data.collectionSync[id] = CollectionSyncMetadata(serverVersion: version, mutationToken: snapshotToken, lastErrorCode: nil)
            }
        }
        throw CollectionCASFailure.conflict
    }

    private func mergeCollectionEntry(local: CollectionEntry, remote: CollectionEntry) -> CollectionEntry {
        var merged = remote
        merged.deleted = local.deleted || remote.deleted
        merged.updatedAt = max(local.updatedAt, remote.updatedAt)
        switch local.kind {
        case .post:
            merged.metadataState = local.metadataState ?? remote.metadataState
            if let value = local.text, !value.isEmpty { merged.text = (remote.text?.isEmpty == false) ? remote.text : value }
            if let value = local.caption, !value.isEmpty { merged.caption = (remote.caption?.isEmpty == false) ? remote.caption : value }
            if let value = local.displayTitle, !value.isEmpty { merged.displayTitle = (remote.displayTitle?.isEmpty == false) ? remote.displayTitle : value }
            if let value = local.thumbnailURL, !value.isEmpty { merged.thumbnailURL = (remote.thumbnailURL?.isEmpty == false) ? remote.thumbnailURL : value }
        case .reaction, .placeLink:
            merged.active = local.active
        case .comment:
            merged.text = remote.text ?? local.text
        }
        return merged
    }

    private func applyPlaceRow(_ row: PlaceRow, store: AlbumStore, tripID: UUID) async throws {
        let index = store.data.places.firstIndex { $0.id == row.id }
        let local = index.map { store.data.places[$0] }
        let dirty = store.data.dirty.contains(row.id)
        let shouldApplyRemote = local == nil || dirty || row.updatedAt > (local?.updatedAt ?? .distantPast)
        let mayRepairCache = !dirty && (local == nil || row.updatedAt >= (local?.updatedAt ?? .distantPast))
        let merged = shouldApplyRemote ? AlbumMerge.place(local: local, remote: row.payload) : (local ?? row.payload)
        let destination = downloadDestination(for: merged, root: store.root)
        let fileState = localFileState(at: destination)
        let downloaded = try await downloadImageIfNeeded(merged, tripID: tripID, into: store.root, allowRemoteOverwrite: mayRepairCache)
        guard store.data.places.first(where: { $0.id == row.id }) == local,
              store.data.dirty.contains(row.id) == dirty,
              localFileState(at: destination) == fileState else { return }
        if let downloaded { try commit(downloaded) }
        guard shouldApplyRemote else { return }
        if let currentIndex = store.data.places.firstIndex(where: { $0.id == row.id }) {
            store.data.places[currentIndex] = merged
        } else {
            store.data.places.append(merged)
        }
        if !dirty { store.data.dirty.remove(row.id) }
    }

    private func applyDocumentRow(_ row: DocumentRow, store: AlbumStore) async throws {
        let index = store.data.documents.firstIndex { $0.id == row.id }
        let local = index.map { store.data.documents[$0] }
        let dirty = store.data.dirty.contains("doc-" + row.id)
        let mayAdoptRemote = local == nil || (!dirty && row.updatedAt > (local?.updatedAt ?? .distantPast))
        let mayRepairCache = !dirty && (local == nil || row.updatedAt >= (local?.updatedAt ?? .distantPast))
        let destination = store.root.appendingPathComponent(row.filename)
        let fileState = localFileState(at: destination)
        let downloaded = try await downloadDocument(row, into: store.root, allowRemoteOverwrite: mayRepairCache)
        guard encodedEqual(store.data.documents.first(where: { $0.id == row.id }), local),
              store.data.dirty.contains("doc-" + row.id) == dirty,
              localFileState(at: destination) == fileState else { return }
        if let downloaded { try commit(downloaded) }
        guard mayAdoptRemote else { return }
        let remote = TravelDocument(id: row.id, name: row.name, filename: row.filename, extractedText: row.extractedText, updatedAt: row.updatedAt)
        if let currentIndex = store.data.documents.firstIndex(where: { $0.id == row.id }) {
            store.data.documents[currentIndex] = remote
        } else {
            store.data.documents.append(remote)
        }
        store.data.dirty.remove("doc-" + row.id)
    }

    private func downloadDocument(_ row: DocumentRow, into root: URL, allowRemoteOverwrite: Bool) async throws -> DownloadedFile? {
        guard allowRemoteOverwrite else { return nil }
        let destination = root.appendingPathComponent(row.filename)
        if PDFDocument(url: destination) != nil { return nil }
        let bytes = try await storageDownloadTransport.download(bucket: "trip-files", path: row.storagePath)
        guard PDFDocument(data: bytes) != nil else { throw RemoteFileValidationError.invalidPDF }
        return DownloadedFile(data: bytes, destination: destination)
    }

    private func downloadImageIfNeeded(_ place: Place, tripID: UUID, into root: URL, allowRemoteOverwrite: Bool) async throws -> DownloadedFile? {
        guard case .uploaded(let image) = place.image, let path = image.storagePath else { return nil }
        guard allowRemoteOverwrite else { return nil }
        let destination = PlaceImageStorage.localURL(for: image, root: root)
        if let localBytes = try? Data(contentsOf: destination), UIImage(data: localBytes) != nil { return nil }
        let expectedPrefix = "\(tripID.uuidString)/\(place.id)/"
        guard path.hasPrefix(expectedPrefix) else { throw CocoaError(.fileReadNoPermission) }
        let bytes = try await storageDownloadTransport.download(bucket: "trip-images", path: path)
        guard UIImage(data: bytes) != nil else { throw RemoteFileValidationError.invalidImage }
        return DownloadedFile(data: bytes, destination: destination)
    }

    private func downloadDestination(for place: Place, root: URL) -> URL {
        guard case .uploaded(let image) = place.image else { return root.appendingPathComponent("images/unused") }
        return PlaceImageStorage.localURL(for: image, root: root)
    }

    private func localFileState(at url: URL) -> LocalFileState {
        let exists = FileManager.default.fileExists(atPath: url.path)
        return LocalFileState(exists: exists, data: try? Data(contentsOf: url))
    }

    private func commit(_ file: DownloadedFile) throws {
        try FileManager.default.createDirectory(at: file.destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try file.data.write(to: file.destination, options: .atomic)
    }

    #if DEBUG
    func reconcileDocumentForTesting(local: TravelDocument?, remote: TravelDocument, storagePath: String, root: URL, dirty: Bool = false) async throws -> TravelDocument? {
        let store = AlbumStore(root: root)
        if let local { store.data.documents = [local] }
        if dirty { store.data.dirty = ["doc-" + (local?.id ?? remote.id)] }
        let row = DocumentRow(id: remote.id, tripID: UUID(), name: remote.name, filename: remote.filename, extractedText: remote.extractedText, storagePath: storagePath, updatedAt: remote.updatedAt)
        try await applyDocumentRow(row, store: store)
        return store.data.documents.first
    }

    func reconcileDocumentForTesting(store: AlbumStore, remote: TravelDocument, storagePath: String) async throws {
        let row = DocumentRow(id: remote.id, tripID: UUID(), name: remote.name, filename: remote.filename, extractedText: remote.extractedText, storagePath: storagePath, updatedAt: remote.updatedAt)
        try await applyDocumentRow(row, store: store)
    }

    func reconcilePlaceForTesting(local: Place?, remote: Place, tripID: UUID, root: URL, dirty: Bool = false) async throws -> Place? {
        let store = AlbumStore(root: root)
        if let local { store.data.places = [local] }
        if dirty { store.data.dirty = [local?.id ?? remote.id] }
        let row = PlaceRow(id: remote.id, tripID: tripID, payload: remote, updatedAt: remote.updatedAt, deleted: remote.deleted)
        try await applyPlaceRow(row, store: store, tripID: tripID)
        return store.data.places.first
    }

    func reconcilePlaceForTesting(store: AlbumStore, remote: Place, tripID: UUID) async throws {
        let row = PlaceRow(id: remote.id, tripID: tripID, payload: remote, updatedAt: remote.updatedAt, deleted: remote.deleted)
        try await applyPlaceRow(row, store: store, tripID: tripID)
    }
    #endif
}
