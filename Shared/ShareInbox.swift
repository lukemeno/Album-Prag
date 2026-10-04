import Foundation

public struct ShareContext: Codable, Equatable {
    public let tripKey: String
    public let albumID: String
    public let updatedAt: Date
    public init(tripKey: String, albumID: String, updatedAt: Date = Date()) {
        self.tripKey = tripKey; self.albumID = albumID; self.updatedAt = updatedAt
    }
}

public enum ShareQueueState: String, Codable { case pending, failed, cancelled }

public struct ShareQueueItem: Codable, Equatable, Identifiable {
    public let id: String
    public let payload: String
    public let url: String?
    public let createdAt: Date
    public let tripKey: String
    public var attemptCount: Int
    public var state: ShareQueueState
    public var lastErrorCode: String?
    public init(id: String = UUID().uuidString, payload: String, url: String?, tripKey: String, createdAt: Date = Date(), attemptCount: Int = 0, state: ShareQueueState = .pending, lastErrorCode: String? = nil) {
        self.id = id; self.payload = payload; self.url = url; self.tripKey = tripKey; self.createdAt = createdAt; self.attemptCount = attemptCount; self.state = state; self.lastErrorCode = lastErrorCode
    }
}

public enum ShareInboxError: LocalizedError {
    case unavailable, missingContext, invalidInput
    public var errorDescription: String? {
        switch self {
        case .unavailable: return "Album konnte die gemeinsame Ablage nicht öffnen. Öffne Album einmal und versuche es erneut."
        case .missingContext: return "Album einmal öffnen, damit das Ziel der Sammlung feststeht."
        case .invalidInput: return "Es wurde kein gültiger Link oder Text gefunden."
        }
    }
}

public struct ShareInbox {
    public static let appGroup = "group.de.privatealbum.prague"
    private let fileManager: FileManager
    private let rootOverride: URL?
    public init(fileManager: FileManager = .default, root: URL? = nil) { self.fileManager = fileManager; self.rootOverride = root }

    public func containerURL() -> URL? { rootOverride ?? fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup) }
    private func contextURL() throws -> URL { guard let root = containerURL() else { throw ShareInboxError.unavailable }; return root.appendingPathComponent("ShareContext.json") }
    private func queueURL(_ id: String) throws -> URL { guard let root = containerURL() else { throw ShareInboxError.unavailable }; return root.appendingPathComponent("ShareQueue-\(id).json") }

    public func saveContext(_ context: ShareContext) throws {
        let destination = try contextURL()
        try atomicWrite(JSONEncoder().encode(context), to: destination)
    }

    public func loadContext() -> ShareContext? {
        guard let url = try? contextURL(), let bytes = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ShareContext.self, from: bytes)
    }

    public func save(_ item: ShareQueueItem) throws { try atomicWrite(JSONEncoder().encode(item), to: try queueURL(item.id)) }

    public func items() -> [ShareQueueItem] {
        guard let root = containerURL(), let urls = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
        return urls.filter { $0.lastPathComponent.hasPrefix("ShareQueue-") && $0.pathExtension == "json" }.map { url in
            if let bytes = try? Data(contentsOf: url), let item = try? JSONDecoder().decode(ShareQueueItem.self, from: bytes) { return item }
            let filename = url.deletingPathExtension().lastPathComponent
            let id = String(filename.dropFirst("ShareQueue-".count))
            return ShareQueueItem(id: id.isEmpty ? filename : id, payload: "", url: nil, tripKey: "", state: .failed, lastErrorCode: "queue-decode-failed")
        }.sorted { $0.createdAt < $1.createdAt }
    }

    public func update(_ item: ShareQueueItem) throws { try save(item) }
    public func remove(_ item: ShareQueueItem) throws { try fileManager.removeItem(at: try queueURL(item.id)) }

    private func atomicWrite(_ bytes: Data, to destination: URL) throws {
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        try bytes.write(to: temporary, options: .atomic)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary, backupItemName: nil, options: .usingNewMetadataOnly)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }
}
