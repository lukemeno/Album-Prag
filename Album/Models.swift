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
    var category: String?
    var address: String?

    func matches(_ place: Place) -> Bool {
        guard let coordinate = place.coordinate else { return false }
        let sameTitle = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            == place.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return sameTitle && abs(latitude - coordinate.latitude) < 0.0001 && abs(longitude - coordinate.longitude) < 0.0001
            && (category == nil || category == place.category) && (address == nil || address == place.address)
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
    /// Version der Foto-Auswahl, mit der das Bild gefunden wurde. Ältere Bilder werden einmal neu gesucht.
    var ranking: Int?
    var userSelected: Bool?
}

enum GeneratedPlaceImageSource: String, Codable, Equatable {
    case lookAround
    case mapSnapshot

    var credit: String {
        switch self {
        case .lookAround: "Apple Karten · Straßenansicht"
        case .mapSnapshot: "Apple Karten · Kartenansicht"
        }
    }
}

struct UploadedPlaceImage: Codable, Equatable {
    let id: String
    var storagePath: String?
    let pixelWidth: Int
    let pixelHeight: Int
    var resolvedFor: ResolvedPlaceIdentity?
    /// Nur von der App erzeugte Ansichten tragen eine Quelle; eigene Fotos bleiben nil.
    var generatedSource: GeneratedPlaceImageSource? = nil

    var filename: String { "place-image-\(id).jpg" }
}

enum PlaceImageAsset: Codable, Equatable {
    case bundled(name: String)
    case linkPreview(pageURL: String, thumbnailURL: String?, credit: String?)
    case external(ExternalPlaceImage)
    case uploaded(UploadedPlaceImage)

    var isSourcePreview: Bool {
        if case .linkPreview = self { return true }
        return false
    }

    var remoteURL: String? {
        switch self {
        case .linkPreview(_, let thumbnailURL, _): thumbnailURL
        case .external(let image): image.imageURL
        default: nil
        }
    }

    /// Kleinere Fassung für Vorschaubilder („…/500px-Datei.jpg“). Wikimedia liefert nur feste Breiten aus,
    /// andere enden mit HTTP 400; deshalb die nächste erlaubte Breite ab der gewünschten.
    func remoteURL(width: Int) -> String? {
        guard let url = remoteURL else { return nil }
        guard case .external(let image) = self, image.provider == .wikimedia else { return url }
        let allowed = [120, 250, 330, 500, 960, 1280, 1920]
        let bucket = allowed.first { $0 >= width } ?? allowed.last!
        return url.replacingOccurrences(of: #"/\d+px-"#, with: "/\(bucket)px-", options: .regularExpression)
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
        case .uploaded(let image): image.generatedSource?.credit
        default: nil
        }
    }

    var resolvedFor: ResolvedPlaceIdentity? {
        switch self {
        case .external(let image): image.resolvedFor
        case .uploaded(let image): image.resolvedFor
        case .bundled, .linkPreview: nil
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
    /// Namen derer, die bei einem Vorschlag der anderen „Nein“ gesagt haben.
    var passedBy: [String] = []
    /// Öffnungszeiten aus OpenStreetMap; "" heißt: nachgesehen, nichts gefunden. Nil: noch nicht nachgesehen.
    var openingHours: String?
    /// Weitere Fotos neben `image` für den Foto-Streifen (höchstens zwei). Nil: noch nicht gesucht.
    var gallery: [ExternalPlaceImage]?
    var updatedAt = Date()
    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lng, lat.isFinite, lng.isFinite,
              (-90...90).contains(lat), (-180...180).contains(lng) else { return nil }
        return .init(latitude: lat, longitude: lng)
    }
    var mapLink: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        var items = [URLQueryItem(name: "q", value: [title, address.isEmpty ? "Prag" : address].filter { !$0.isEmpty }.joined(separator: ", "))]
        if let coordinate {
            items.append(URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"))
        }
        components.queryItems = items
        return components.url!
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
        case id, title, note, sourceURL, category, author, image, address, lat, lng, franked, deferred, deleted, visited, day, dayOrder, approvals, passedBy, openingHours, gallery, updatedAt
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
        gallery = try values.decodeIfPresent([ExternalPlaceImage].self, forKey: .gallery)
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
        try values.encodeIfPresent(openingHours, forKey: .openingHours); try values.encodeIfPresent(gallery, forKey: .gallery)
        try values.encode(updatedAt, forKey: .updatedAt)
    }

    static let examples: [Place] = [
        Place(id: "example-letna", title: "Letná Park", note: "Park mit Blick über die Moldau.", category: "Aussicht", image: .bundled(name: "imgPhotoLetna"), lat: 50.0966, lng: 14.4165, updatedAt: .distantPast),
        Place(id: "example-oldtown", title: "Altstädter Ring", note: "Route durch die Altstadt planen.", category: "Sehenswert", image: .bundled(name: "imgPhotoOldTown"), lat: 50.0875, lng: 14.4213, updatedAt: .distantPast),
        Place(id: "example-cafe", title: "Café auswählen", note: "Café oder Restaurant als Idee ergänzen.", category: "Essen & Trinken", image: .bundled(name: "imgThumbCafe"), updatedAt: .distantPast),
        Place(id: "prague-genesis-second-hand", title: "Genesis Second Hand", note: "Second-Hand-Laden; genaue Filiale noch auswählen.", sourceURL: "https://www.glamourcabaret.cz/m/nejlepsi-prazske-second-handy-obchody-s-vintage-recyklovanou-modou", category: "Shopping", updatedAt: .distantPast),
        Place(id: "prague-3some-vintage", title: "3SOME Vintage", note: "Vintage-Shop; genaue Adresse vor dem Besuch prüfen.", sourceURL: "https://www.glamourcabaret.cz/m/nejlepsi-prazske-second-handy-obchody-s-vintage-recyklovanou-modou", category: "Shopping", updatedAt: .distantPast),
        Place(id: "prague-old-czech-chimney-cake", title: "Old Czech Chimney Cake · Karlova 25", note: "Trdelník / Chimney Cake.", sourceURL: "https://www.oldczechchimney.com/", category: "Essen & Trinken", address: "Karlova 145/25, 110 00 Praha 1", updatedAt: .distantPast),
        Place(id: "prague-our-lady-victorious", title: "Church of Our Lady Victorious", note: "Kirche mit dem Prager Jesulein (Infant Jesus of Prague).", sourceURL: "https://prague.eu/en/objevujte/church-of-our-lady-victorious-church-of-the-infant-jesus-kostel-panny-marie-vitezne/", category: "Sehenswert", address: "Karmelitská 9, 118 00 Praha 1", updatedAt: .distantPast),
        Place(id: "prague-st-nicholas-old-town", title: "St Nicholas Church · Old Town", note: "Nikolauskirche am Altstädter Ring.", sourceURL: "https://prague.eu/en/objevujte/st-nicholas-church-kostel-sv-mikulase/", category: "Sehenswert", address: "Staroměstské náměstí, 110 00 Praha 1", updatedAt: .distantPast),
        Place(id: "prague-orthodox-cathedral-cyril-methodius", title: "Orthodox Cathedral of Saints Cyril and Methodius", note: "Orthodoxe Kathedrale und Gedenkstätte der Heydrich-Attentäter.", sourceURL: "https://prague.eu/en/spiritual-prague/pilgrimage-routes/cyril-and-methodius-route/", category: "Sehenswert", address: "Resslova 9a, 120 00 Praha 2", updatedAt: .distantPast),
        Place(id: "prague-venice-cruise", title: "Prague Venice · Čertovka", note: "Bootsfahrt durch die Prager Kanäle und Čertovka (Little Venice).", sourceURL: "https://www.prague-venice.cz/en/detail", category: "Idee", address: "Křižovnické náměstí, 110 00 Praha 1", updatedAt: .distantPast),
        Place(id: "prague-planetum-program", title: "Planetarium Prag", note: "Planetarium mit modernisiertem LED-Dome.", sourceURL: "https://prague.eu/de/objevujte/planetarium-prag-planetarium-praha/", category: "Idee", address: "Královská obora 233, 170 21 Praha 7", updatedAt: .distantPast),
        Place(id: "prague-alchemiae", title: "Speculum Alchemiae", note: "Alchemie-Museum in der Prager Altstadt.", sourceURL: "https://prague.eu/en/objevujte/speculum-alchemiae-mirror-of-alchemy-zrcadlo-alchymie/", category: "Sehenswert", address: "Haštalská 795/1, 110 00 Praha 1", lat: 50.0907544, lng: 14.4224672, updatedAt: .distantPast),
        Place(id: "prague-ghost-legends-tour", title: "Geister- und Legenden-Tour", note: "Atmosphärischer Abendspaziergang; Treffpunkt Kožná 500/6 in der Altstadt.", sourceURL: "https://spectrumtours.cz/de/tours/ghost-and-legends-tour", category: "Idee", address: "Kožná 500/6, 110 00 Praha 1", updatedAt: .distantPast),
        Place(id: "prague-premyslids-exhibition", title: "Die Přemysliden · Nationalmuseum", note: "Sonderausstellung vom 24. April bis 15. Oktober 2026.", sourceURL: "https://www.nm.cz/en/program/exhibitions/the-premyslids-a-ruling-dynasty-and-its-age", category: "Idee", address: "Václavské náměstí 68, 110 00 Praha 1", updatedAt: .distantPast),
        Place(id: "prague-alchemists-magicians-museum", title: "Alchemisten- und Magiermuseum", note: "Museum nahe der Prager Burg im Haus, in dem Alchemist Edward Kelley lebte.", sourceURL: "https://prague.eu/de/objevujte/alchymisten-und-magier-museum-des-alten-prags-muzeum-alchymistu-a-magu-stare-prahy/", category: "Idee", address: "Jánský vršek 8, 118 00 Praha 1", updatedAt: .distantPast),
        Place(id: "prague-franz-kafka-museum", title: "Franz Kafka Museum", note: "Ausstellung zu Leben und Werk Franz Kafkas in der Herget-Ziegelei.", sourceURL: "https://kafkamuseum.cz/de", category: "Idee", address: "Cihelná 2b, 118 00 Praha 1", updatedAt: .distantPast),
        suggestion("knedelin", "Knedlín", category: "Essen & Trinken"),
        suggestion("koncept-bar", "Koncept Bar", category: "Essen & Trinken", note: "Matcha"),
        suggestion("pasta-fresca", "Pasta Fresca", category: "Essen & Trinken"),
        suggestion("jun-matcha", "Jun Matcha", category: "Essen & Trinken", note: "Matcha"),
        suggestion("na-prikope", "Na Příkopě", category: "Shopping", note: "Einkaufsstraße"),
        suggestion("kolacherie", "Sweet Treat at Kolacherie", category: "Essen & Trinken"),
        suggestion("prague-castle", "Prague Castle", category: "Sehenswert"),
        suggestion("golden-lane", "Golden Lane", category: "Sehenswert"),
        suggestion("charles-bridge-sunset", "Charles Bridge · Sunset", category: "Aussicht", note: "Sonnenuntergang an der Karlsbrücke"),
        suggestion("pho-bar", "Pho Bar", category: "Essen & Trinken"),
        suggestion("void-cafe", "Void Cafe", category: "Essen & Trinken"),
        suggestion("bistro-monk", "Bistro Monk", category: "Essen & Trinken"),
        suggestion("coffee-cube", "Coffee Cube", category: "Essen & Trinken"),
        suggestion("coffee-room", "Coffee Room", category: "Essen & Trinken"),
        suggestion("golden-egg", "Golden Egg", category: "Essen & Trinken"),
        suggestion("v-zahrade", "V Zahradě Restaurant", category: "Essen & Trinken"),
        Place(id: "prague-staromestske-namesti-cafe", title: "Café · Staroměstské náměstí 4/1", note: "Café an der angegebenen Adresse.", sourceURL: "https://www.google.com/maps/search/?api=1&query=Starom%C4%9Bstsk%C3%A9+n%C3%A1m%C4%9Bst%C3%AD+4%2F1+Prague", category: "Essen & Trinken", address: "Staroměstské náměstí 4/1, 110 00 Praha 1", updatedAt: .distantPast),
        suggestion("national-museum", "National Museum", category: "Sehenswert"),
        suggestion("state-opera", "State Opera", category: "Sehenswert"),
        suggestion("u-mateje", "U Matěje", category: "Essen & Trinken"),
        suggestion("historic-tram-42", "Historic Tram Line 42", category: "Idee", note: "Sightseeing mit der historischen Straßenbahn"),
        suggestion("municipal-library", "Municipal Library of Prague", category: "Sehenswert"),
        suggestion("anezsky-klaster", "Anežský klášter", category: "Sehenswert"),
        suggestion("jan-hus-memorial", "Jan Hus Memorial", category: "Sehenswert"),
        suggestion("astronomical-clock", "Prague Astronomical Clock", category: "Sehenswert"),
        suggestion("our-lady-before-tyn", "Church of Our Lady before Týn", category: "Sehenswert"),
        suggestion("head-of-franz-kafka", "Head of Franz Kafka", category: "Sehenswert"),
        suggestion("sigmund-freud-sculpture", "Man Hanging Out · Sigmund Freud Sculpture", category: "Sehenswert"),
        suggestion("havels-market", "Havels Market", category: "Shopping"),
        suggestion("cafe-letka", "Café Letka", category: "Essen & Trinken"),
        suggestion("natureza-vegetarian-house", "Natureza Vegetarian House", category: "Essen & Trinken"),
        suggestion("bokovka", "Bokovka Bar", category: "Essen & Trinken"),
        suggestion("etapa", "Etapa", category: "Essen & Trinken"),
        suggestion("ema-espresso", "Ema Espresso", category: "Essen & Trinken"),
        suggestion("bjukitchen", "Bjukitchen", category: "Essen & Trinken"),
        suggestion("baracnicka-rychta", "Baráčnická rychta", category: "Essen & Trinken"),
        suggestion("di-tutti", "di tutti", category: "Essen & Trinken"),
        suggestion("cafe-savoy", "Café Savoy", category: "Essen & Trinken"),
        suggestion("st-vitus-cathedral", "St Vitus Cathedral", category: "Sehenswert"),
        suggestion("lennon-wall", "Lennon Wall", category: "Sehenswert"),
        suggestion("eska", "Eska", category: "Essen & Trinken"),
        suggestion("riegrovy-sady", "Riegrovy Sady", category: "Aussicht"),
        suggestion("petrin-hill", "Petřín Hill", category: "Aussicht"),
        suggestion("petrin-tower", "Petřín Tower", category: "Aussicht"),
        suggestion("strahov-library", "Strahov Monastery Library", category: "Sehenswert"),
        suggestion("the-vintage-prague", "The Vintage Prague", category: "Shopping"),
        suggestion("vintage-therapy", "Vintage Therapy", category: "Shopping"),
        suggestion("almo-vintage", "Almo Vintage", category: "Shopping"),
        suggestion("old-town-hall-tower", "Old Town Hall Tower", category: "Aussicht"),
        suggestion("jazz-republic", "Jazz Republic", category: "Essen & Trinken"),
        suggestion("waldstein-gardens", "Waldstein Gardens · Valdštejnská zahrada", category: "Sehenswert"),
        suggestion("strelecky-island", "Střelecký Island", category: "Sehenswert"),
        suggestion("pilsner-urquell-experience", "Pilsner Urquell Experience", category: "Sehenswert"),
        suggestion("st-wenceslas-vineyard", "St Wenceslas Vineyard", category: "Aussicht"),
        suggestion("mala-strana", "Malá Strana", category: "Sehenswert"),
        suggestion("havlickovy-sady-grebovka", "Havlíčkovy Sady · Grébovka", category: "Aussicht"),
        suggestion("vysehrad-citadel", "Vyšehrad Citadel", category: "Sehenswert"),
        suggestion("naplavka", "Náplavka", category: "Sehenswert"),
        suggestion("josefov", "Josefov", category: "Sehenswert"),
        suggestion("kampa-island", "Kampa Island", category: "Sehenswert"),
        suggestion("dancing-house", "Dancing House", category: "Sehenswert"),
        suggestion("stare-mesto", "Staré Město", category: "Sehenswert"),
        suggestion("karlstejn-castle", "Karlštejn Castle", category: "Sehenswert", note: "Tagesausflug ab Prag", query: "Karlštejn Castle, Czechia"),
        suggestion("kutna-hora", "Kutná Hora", category: "Sehenswert", note: "Tagesausflug ab Prag", query: "Kutná Hora, Czechia"),
        suggestion("sedlec-ossuary", "Sedlec Ossuary", category: "Sehenswert", note: "Beinhaus in Sedlec bei Kutná Hora", query: "Sedlec Ossuary, Kutná Hora, Czechia")
    ]

    private static func suggestion(_ id: String, _ title: String, category: String, note: String = "", query: String? = nil) -> Place {
        let searchTerm = query ?? "\(title) Prague"
        let encodedQuery = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
        return Place(
            id: "prague-\(id)",
            title: title,
            note: note,
            sourceURL: "https://www.google.com/maps/search/?api=1&query=\(encodedQuery)",
            category: category,
            updatedAt: .distantPast
        )
    }
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
    var albumID = UUID().uuidString
    var places = Place.examples
    var trip = TripInfo()
    var documents: [TravelDocument] = []
    var dirty: Set<String> = []
    var collaboration: CollaborationState?
    var collectionEntries: [CollectionEntry] = []
    var collectionSync: [String: CollectionSyncMetadata] = [:]

    private enum CodingKeys: String, CodingKey {
        case albumID, places, trip, documents, dirty, collaboration, collectionEntries, collectionSync
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        albumID = try values.decodeIfPresent(String.self, forKey: .albumID) ?? UUID().uuidString
        places = try values.decodeIfPresent([Place].self, forKey: .places) ?? Place.examples
        trip = try values.decodeIfPresent(TripInfo.self, forKey: .trip) ?? TripInfo()
        documents = try values.decodeIfPresent([TravelDocument].self, forKey: .documents) ?? []
        dirty = try values.decodeIfPresent(Set<String>.self, forKey: .dirty) ?? []
        collaboration = try values.decodeIfPresent(CollaborationState.self, forKey: .collaboration)
        collectionEntries = try values.decodeIfPresent([CollectionEntry].self, forKey: .collectionEntries) ?? []
        collectionSync = try values.decodeIfPresent([String: CollectionSyncMetadata].self, forKey: .collectionSync) ?? [:]
    }
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
