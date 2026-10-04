import Foundation
import CryptoKit

enum CollectionEntryKind: String, Codable, CaseIterable {
    case post
    case comment
    case reaction
    case placeLink
}

enum CollectionMetadataState: String, Codable {
    case pending
    case available
    case unavailable
    case cancelled
}

struct CollectionEntry: Codable, Equatable, Identifiable {
    let id: String
    let kind: CollectionEntryKind
    var postID: String?
    var authorID: String
    var authorName: String
    var createdAt: Date
    var updatedAt: Date
    var text: String?
    var url: String?
    var canonicalURL: String?
    var displayTitle: String?
    var caption: String?
    var thumbnailURL: String?
    var metadataState: CollectionMetadataState?
    var placeID: String?
    var active: Bool?
    var deleted: Bool

    static func post(id: String, authorID: String, authorName: String, text: String?, url: String?, canonicalURL: String?, displayTitle: String?, caption: String? = nil, thumbnailURL: String? = nil, now: Date = Date()) -> CollectionEntry {
        CollectionEntry(id: id, kind: .post, postID: nil, authorID: authorID, authorName: authorName, createdAt: now, updatedAt: now, text: text, url: url, canonicalURL: canonicalURL, displayTitle: displayTitle, caption: caption, thumbnailURL: thumbnailURL, metadataState: url == nil ? nil : .pending, placeID: nil, active: nil, deleted: false)
    }

    static func comment(id: String = UUID().uuidString, postID: String, authorID: String, authorName: String, text: String, now: Date = Date()) -> CollectionEntry {
        CollectionEntry(id: id, kind: .comment, postID: postID, authorID: authorID, authorName: authorName, createdAt: now, updatedAt: now, text: text, url: nil, canonicalURL: nil, displayTitle: nil, caption: nil, thumbnailURL: nil, metadataState: nil, placeID: nil, active: nil, deleted: false)
    }

    static func reaction(postID: String, participantID: String, authorName: String, active: Bool, now: Date = Date()) -> CollectionEntry {
        CollectionEntry(id: reactionID(postID: postID, participantID: participantID), kind: .reaction, postID: postID, authorID: participantID, authorName: authorName, createdAt: now, updatedAt: now, text: nil, url: nil, canonicalURL: nil, displayTitle: nil, caption: nil, thumbnailURL: nil, metadataState: nil, placeID: nil, active: active, deleted: false)
    }

    static func placeLink(postID: String, placeID: String, authorID: String, authorName: String, now: Date = Date()) -> CollectionEntry {
        CollectionEntry(id: placeLinkID(postID: postID, placeID: placeID), kind: .placeLink, postID: postID, authorID: authorID, authorName: authorName, createdAt: now, updatedAt: now, text: nil, url: nil, canonicalURL: nil, displayTitle: nil, caption: nil, thumbnailURL: nil, metadataState: nil, placeID: placeID, active: true, deleted: false)
    }

    static func reactionID(postID: String, participantID: String) -> String { "reaction-" + digest(postID + "\u{1F}" + participantID) }
    static func placeLinkID(postID: String, placeID: String) -> String { "place-link-" + digest(postID + "\u{1F}" + placeID) }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct CollectionSyncMetadata: Codable, Equatable {
    var serverVersion: Int64?
    var mutationToken: String
    var lastErrorCode: String?
}

enum CollectionURL {
    static let trackingParameters: Set<String> = ["fbclid", "gclid", "igsh", "igshid"]

    static func canonicalize(_ raw: String) -> URL? {
        guard let input = LinkValidation.url(raw), var components = URLComponents(url: input, resolvingAgainstBaseURL: false), let host = components.host else { return nil }
        let scheme = components.scheme?.lowercased() ?? "https"
        let lowerHost = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        var path = components.path.isEmpty ? "/" : components.path.replacingOccurrences(of: "//", with: "/")
        if path.count > 1 { path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/")); path = "/" + path }
        if (lowerHost == "tiktok.com" || lowerHost.hasSuffix(".tiktok.com")), let match = path.range(of: #"/@[^/]+/video/([0-9]+)"#, options: .regularExpression), let videoID = path[match].split(separator: "/").last {
            components.host = "www.tiktok.com"
            components.path = "/video/\(videoID)"
            components.query = nil
        } else if (lowerHost == "instagram.com" || lowerHost.hasSuffix(".instagram.com")), let match = path.range(of: #"/(p|reel|tv)/([^/]+)"#, options: .regularExpression) {
            components.host = "www.instagram.com"
            let clip = String(path[match]).split(separator: "/").suffix(2).joined(separator: "/")
            components.path = "/" + clip
            components.query = nil
        } else {
            components.host = lowerHost
            components.path = path
            let parameters = (components.queryItems ?? []).filter { item in
                let name = item.name.lowercased()
                return !name.hasPrefix("utm_") && !trackingParameters.contains(name)
            }.sorted { lhs, rhs in
                if lhs.name == rhs.name { return (lhs.value ?? "") < (rhs.value ?? "") }
                return lhs.name < rhs.name
            }
            components.queryItems = parameters.isEmpty ? nil : parameters
        }
        if (scheme == "http" && components.port == 80) || (scheme == "https" && components.port == 443) { components.port = nil }
        components.scheme = scheme
        components.fragment = nil
        guard let result = components.url else { return nil }
        return result
    }

    static func postID(for raw: String) -> String? {
        guard let url = canonicalize(raw) else { return nil }
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return "post-" + digest
    }

    static func neutralTitle(for url: URL) -> String {
        let host = url.host?.lowercased() ?? "Link"
        if host == "tiktok.com" || host.hasSuffix(".tiktok.com") { return "TikTok-Link" }
        if host == "instagram.com" || host.hasSuffix(".instagram.com") { return "Instagram-Link" }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}

enum CollectionIdentity {
    static let defaultsKey = "album.participantID"

    static func participantID(defaults: UserDefaults = .standard) -> String {
        if let value = defaults.string(forKey: defaultsKey), !value.isEmpty { return value }
        let value = UUID().uuidString
        defaults.set(value, forKey: defaultsKey)
        return value
    }
}
