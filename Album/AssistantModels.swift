import Foundation

struct AssistantReply: Codable, Equatable {
    var protocolVersion: Int
    var answer: String
    var sources: [AssistantSource]
    var places: [AssistantPlace]
    var plan: [AssistantDay]
    var preferences: [String]
    var usage: AssistantUsage?

    init(protocolVersion: Int = AssistantProtocol.version, answer: String, sources: [AssistantSource], places: [AssistantPlace], plan: [AssistantDay], preferences: [String], usage: AssistantUsage?) {
        self.protocolVersion = protocolVersion
        self.answer = answer
        self.sources = sources
        self.places = places
        self.plan = plan
        self.preferences = preferences
        self.usage = usage
    }

    enum CodingKeys: String, CodingKey { case protocolVersion = "protocol_version", answer, sources, places, plan, preferences, usage }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // Gespeicherte Antworten ohne Version stammen aus Protokoll 1 und bleiben lesbar.
        protocolVersion = try values.decodeIfPresent(Int.self, forKey: .protocolVersion) ?? 1
        answer = try values.decode(String.self, forKey: .answer)
        sources = try values.decode([AssistantSource].self, forKey: .sources)
        places = try values.decode([AssistantPlace].self, forKey: .places)
        plan = try values.decode([AssistantDay].self, forKey: .plan)
        preferences = try values.decode([String].self, forKey: .preferences)
        usage = try values.decodeIfPresent(AssistantUsage.self, forKey: .usage)
    }
}

/// Protokoll 2: Plantage sind ISO-Kalenderdaten innerhalb des Reisezeitraums.
enum AssistantProtocol {
    static let version = 2
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
    /// Kalendertag aus Protokoll 2. `day` bleibt nur zum Lesen alter Antworten aus Protokoll 1.
    var date: TripDay?
    var day: Int?
    var placeIDs: [String]
    var note: String
    var id: String { date?.rawValue ?? "legacy-\(day ?? 0)" }

    init(date: TripDay, placeIDs: [String], note: String) {
        self.date = date
        self.day = nil
        self.placeIDs = placeIDs
        self.note = note
    }

    init(day: Int, placeIDs: [String], note: String) {
        self.date = nil
        self.day = day
        self.placeIDs = placeIDs
        self.note = note
    }

    enum CodingKeys: String, CodingKey { case date, day, note; case placeIDs = "place_ids" }
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
