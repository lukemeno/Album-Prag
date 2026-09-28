import Foundation
import CoreLocation

enum PlaceImageProvider: String, Codable, Equatable {
    case sourcePreview
    case wikimedia
    case tripadvisor
    case legacy
}

struct ResolvedPlaceIdentity: Codable, Equatable {
    let title: String
    let latitude: Double
    let longitude: Double

    func matches(_ place: Place) -> Bool {
        guard let coordinate = place.coordinate else { return false }
        let sameTitle = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            == place.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return sameTitle && abs(latitude - coordinate.latitude) < 0.0001 && abs(longitude - coordinate.longitude) < 0.0001
    }
}

struct ExternalPlaceImage: Codable, Equatable {
    let imageURL: String
    let sourceURL: String
    let credit: String
    let provider: PlaceImageProvider
    var licenseName: String?
    var licenseURL: String?
    var providerPlaceID: String?
    var resolvedFor: ResolvedPlaceIdentity?
}

struct UploadedPlaceImage: Codable, Equatable {
    let id: String
    var storagePath: String?
    let pixelWidth: Int
    let pixelHeight: Int

    var filename: String { "place-image-\(id).jpg" }
}

enum PlaceImageAsset: Codable, Equatable {
    case bundled(name: String)
    case linkPreview(pageURL: String, thumbnailURL: String?, credit: String?)
    case external(ExternalPlaceImage)
    case uploaded(UploadedPlaceImage)

    var remoteURL: String? {
        switch self {
        case .linkPreview(_, let thumbnailURL, _): thumbnailURL
        case .external(let image): image.imageURL
        default: nil
        }
    }

    var bundledName: String {
        if case .bundled(let name) = self { return name }
        return ""
    }

    var sourceURL: String? {
        switch self {
        case .linkPreview(let pageURL, _, _): pageURL
        case .external(let image): image.sourceURL
        default: nil
        }
    }

    var credit: String? {
        switch self {
        case .linkPreview(_, _, let credit): credit
        case .external(let image): image.credit
        default: nil
        }
    }

    var isUploaded: Bool {
        if case .uploaded = self { return true }
        return false
    }
}

struct Place: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var note = ""
    var sourceURL = ""
    var category = "Idee"
    var author = "Wir"
    var image: PlaceImageAsset?
    var address = ""
    var lat: Double?
    var lng: Double?
    var franked = false
    var deferred = false
    var deleted = false
    var visited = false
    var day: Int?
    /// Reihenfolge innerhalb eines Tages (kleiner = früher).
    var dayOrder: Int?
    /// Namen derer, die „Dafür“ gesagt haben.
    var approvals: [String] = []
    /// Namen derer, die einen Vorschlag der anderen auf „Später“ gelegt haben.
    var passedBy: [String] = []
    /// Öffnungszeiten aus OpenStreetMap; "" heißt: nachgesehen, nichts gefunden. Nil: noch nicht nachgesehen.
    var openingHours: String?
    var updatedAt = Date()
    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lng, lat.isFinite, lng.isFinite,
              (-90...90).contains(lat), (-180...180).contains(lng) else { return nil }
        return .init(latitude: lat, longitude: lng)
    }
    var sourceLabel: String {
        guard let host = URL(string: sourceURL)?.host?.lowercased() else { return "Gesammelt" }
        if host == "tiktok.com" || host.hasSuffix(".tiktok.com") { return "TikTok" }
        if host == "instagram.com" || host.hasSuffix(".instagram.com") { return "Instagram" }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    init(id: String = UUID().uuidString, title: String, note: String = "", sourceURL: String = "", category: String = "Idee", author: String = "Wir", image: PlaceImageAsset? = nil, address: String = "", lat: Double? = nil, lng: Double? = nil, franked: Bool = false, deferred: Bool = false, deleted: Bool = false, visited: Bool = false, day: Int? = nil, dayOrder: Int? = nil, approvals: [String] = [], passedBy: [String] = [], updatedAt: Date = Date()) {
        self.id = id; self.title = title; self.note = note; self.sourceURL = sourceURL; self.category = category; self.author = author
        self.image = image; self.address = address; self.lat = lat; self.lng = lng; self.franked = franked; self.deferred = deferred
        self.deleted = deleted; self.visited = visited; self.day = day; self.dayOrder = dayOrder
        self.approvals = approvals; self.passedBy = passedBy; self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, note, sourceURL, category, author, image, address, lat, lng, franked, deferred, deleted, visited, day, dayOrder, approvals, passedBy, openingHours, updatedAt
        case imageName, remoteImage, imageSourceURL, imageCredit
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try values.decode(String.self, forKey: .title)
        note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
        sourceURL = try values.decodeIfPresent(String.self, forKey: .sourceURL) ?? ""
        category = try values.decodeIfPresent(String.self, forKey: .category) ?? "Idee"
        author = try values.decodeIfPresent(String.self, forKey: .author) ?? "Wir"
        address = try values.decodeIfPresent(String.self, forKey: .address) ?? ""
        lat = try values.decodeIfPresent(Double.self, forKey: .lat)
        lng = try values.decodeIfPresent(Double.self, forKey: .lng)
        franked = try values.decodeIfPresent(Bool.self, forKey: .franked) ?? false
        deferred = try values.decodeIfPresent(Bool.self, forKey: .deferred) ?? false
        deleted = try values.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
        visited = try values.decodeIfPresent(Bool.self, forKey: .visited) ?? false
        day = try values.decodeIfPresent(Int.self, forKey: .day)
        dayOrder = try values.decodeIfPresent(Int.self, forKey: .dayOrder)
        approvals = try values.decodeIfPresent([String].self, forKey: .approvals) ?? []
        passedBy = try values.decodeIfPresent([String].self, forKey: .passedBy) ?? []
        openingHours = try values.decodeIfPresent(String.self, forKey: .openingHours)
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        if let current = try values.decodeIfPresent(PlaceImageAsset.self, forKey: .image) {
            image = current
        } else if let remote = try values.decodeIfPresent(String.self, forKey: .remoteImage) {
            image = .external(ExternalPlaceImage(
                imageURL: remote,
                sourceURL: try values.decodeIfPresent(String.self, forKey: .imageSourceURL) ?? sourceURL,
                credit: try values.decodeIfPresent(String.self, forKey: .imageCredit) ?? "Quelle",
                provider: .legacy
            ))
        } else if let name = try values.decodeIfPresent(String.self, forKey: .imageName), !name.isEmpty {
            image = .bundled(name: name)
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id); try values.encode(title, forKey: .title); try values.encode(note, forKey: .note)
        try values.encode(sourceURL, forKey: .sourceURL); try values.encode(category, forKey: .category); try values.encode(author, forKey: .author)
        try values.encodeIfPresent(image, forKey: .image); try values.encode(address, forKey: .address); try values.encodeIfPresent(lat, forKey: .lat)
        try values.encodeIfPresent(lng, forKey: .lng); try values.encode(franked, forKey: .franked); try values.encode(deferred, forKey: .deferred)
        try values.encode(deleted, forKey: .deleted); try values.encode(visited, forKey: .visited); try values.encodeIfPresent(day, forKey: .day)
        try values.encodeIfPresent(dayOrder, forKey: .dayOrder); try values.encode(approvals, forKey: .approvals); try values.encode(passedBy, forKey: .passedBy)
        try values.encodeIfPresent(openingHours, forKey: .openingHours); try values.encode(updatedAt, forKey: .updatedAt)
    }

    static let examples: [Place] = [
        Place(id: "example-letna", title: "Letná", note: "Park mit Blick über die Moldau.", category: "Aussicht", image: .bundled(name: "imgPhotoLetna"), lat: 50.0966, lng: 14.4165, updatedAt: .distantPast),
        Place(id: "example-oldtown", title: "Altstädter Ring", note: "Route durch die Altstadt planen.", category: "Sehenswert", image: .bundled(name: "imgPhotoOldTown"), lat: 50.0875, lng: 14.4213, updatedAt: .distantPast),
        Place(id: "example-cafe", title: "Café auswählen", note: "Café oder Restaurant als Idee ergänzen.", category: "Essen & Trinken", image: .bundled(name: "imgThumbCafe"), updatedAt: .distantPast)
    ]
}

struct TripInfo: Codable {
    var hotel = "Hotel Urban Crème"
    var outbound = ""
    var arrival = ""
    var route = ""
    var flightNumber = ""
    var notes = ""
    var updatedAt = Date.distantPast
    // Aus Reiseunterlagen gelesen. Optional, damit ältere Daten weiter geladen werden.
    var flights: [FlightLeg]?
    var hotelDetails: HotelDetails?
    var bookingNumber: String?
    var travelers: [String]?
}

struct FlightLeg: Codable, Equatable, Identifiable {
    enum Direction: String, Codable { case outbound, inbound }
    var direction: Direction
    var number: String
    var airline: String?
    var from: String
    var to: String
    /// Datum als „04.10.2026“.
    var date: String
    var departure: String
    var arrival: String
    /// Spätestens am Flughafen sein.
    var arriveBy: String?
    var bookingCode: String?
    var id: String { direction.rawValue + number }
    var route: String { "\(from) → \(to)" }
}

struct HotelDetails: Codable, Equatable {
    var name: String?
    var address: String?
    var checkIn: String?
    var checkOut: String?
    var included: [String] = []
}

struct TravelDocument: Codable, Identifiable {
    var id = UUID().uuidString
    var name: String
    var filename: String
    var extractedText: String
    var updatedAt = Date()
}

struct CollaborationState: Codable, Equatable {
    var tripID: UUID
    var inviteToken: String?
}

struct AlbumData: Codable {
    var places = Place.examples
    var trip = TripInfo()
    var documents: [TravelDocument] = []
    var dirty: Set<String> = []
    var collaboration: CollaborationState?
}

enum AlbumMerge {
    static func place(local: Place?, remote: Place) -> Place {
        guard let local else { return remote }
        var merged = remote.updatedAt > local.updatedAt ? remote : local
        // Stimmen gehen nie verloren: Wer offline abgestimmt hat, bleibt gezählt.
        merged.approvals = union(local.approvals, remote.approvals)
        merged.passedBy = union(local.passedBy, remote.passedBy)
        if !merged.approvals.isEmpty && !merged.deleted { merged.franked = true }
        return merged
    }

    private static func union(_ a: [String], _ b: [String]) -> [String] {
        var seen = Set<String>()
        return (a + b).filter { seen.insert($0).inserted }
    }

    static func trip(local: TripInfo, remote: TripInfo) -> TripInfo {
        remote.updatedAt > local.updatedAt ? remote : local
    }

    static func document(local: TravelDocument?, remote: TravelDocument) -> TravelDocument {
        guard let local else { return remote }
        return remote.updatedAt > local.updatedAt ? remote : local
    }
}

enum InvitationLink {
    static func make(token: String) -> URL? {
        var components = URLComponents()
        components.scheme = "album"
        components.host = "join"
        components.path = "/" + token
        return components.url
    }

    static func token(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "album", url.host?.lowercased() == "join" else { return nil }
        let token = url.pathComponents.dropFirst().first ?? ""
        return token.count >= 32 ? token : nil
    }
}

enum LinkValidation {
    static func url(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
    static func firstURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
              let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let url = match.url else { return nil }
        return self.url(url.absoluteString)
    }
}
