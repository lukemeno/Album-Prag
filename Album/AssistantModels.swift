import Foundation

struct AssistantReply: Codable, Equatable {
    var answer: String
    var sources: [AssistantSource]
    var places: [AssistantPlace]
    var plan: [AssistantDay]
    var preferences: [String]
    var usage: AssistantUsage?
}

struct AssistantSource: Codable, Equatable, Identifiable {
    var title: String
    var url: String?
    var documentID: String?
    var quote: String?
    var id: String { (documentID ?? url ?? "") + title }
    enum CodingKeys: String, CodingKey { case title, url, quote; case documentID = "document_id" }
}

struct AssistantPlace: Codable, Equatable, Identifiable {
    var existingID: String?
    var title: String
    var address: String
    var query: String
    var sourceURL: String?
    var id: String { existingID ?? (title + address + query) }
    enum CodingKeys: String, CodingKey { case title, address, query; case existingID = "existing_id"; case sourceURL = "source_url" }
}

struct AssistantDay: Codable, Equatable, Identifiable {
    var day: Int
    var placeIDs: [String]
    var note: String
    var id: Int { day }
    enum CodingKeys: String, CodingKey { case day, note; case placeIDs = "place_ids" }
}

struct AssistantUsage: Codable, Equatable {
    var usedUSD: Double
    var limitUSD: Double
    var remainingRequests: Int
    enum CodingKeys: String, CodingKey { case usedUSD = "used_usd"; case limitUSD = "limit_usd"; case remainingRequests = "remaining_requests" }
}

struct AssistantMessage: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var role: String
    var text: String
    var reply: AssistantReply?
    var createdAt = Date()
}
