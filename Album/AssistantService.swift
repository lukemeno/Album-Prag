import Foundation
import CoreLocation

enum AssistantServiceError: LocalizedError {
    case unavailable
    case invalidResponse
    case server(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Der Reise-Assistent ist gerade nicht erreichbar."
        case .invalidResponse: return "Die Antwort konnte nicht gelesen werden."
        case .server(let message): return message
        case .cancelled: return "Anfrage abgebrochen."
        }
    }
}

@MainActor struct AssistantService {
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func send(store: AlbumStore, message: String, history: [AssistantMessage], preferences: [String], location: CLLocationCoordinate2D?, webSearch: Bool) async throws -> AssistantReply {
        #if DEBUG
        if ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] != nil,
           let fixture = ProcessInfo.processInfo.environment["ALBUM_ASSISTANT_FIXTURE"], !fixture.isEmpty {
            if let data = fixture.data(using: .utf8), let reply = try? JSONDecoder().decode(AssistantReply.self, from: data) { return reply }
            return AssistantReply(answer: fixture, sources: [], places: [], plan: [], preferences: [], usage: nil)
        }
        #endif

        let client = try SupabaseConfiguration.client()
        if (try? await client.auth.session) == nil { _ = try await client.auth.signInAnonymously() }
        let authSession = try await client.auth.session
        let endpointValue = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String
        guard let endpointValue, let baseURL = URL(string: endpointValue), !endpointValue.contains("YOUR_PROJECT") else { throw AssistantServiceError.unavailable }
        let endpoint = baseURL.appendingPathComponent("functions/v1/assistant-chat")
        var request = URLRequest(url: endpoint, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        let context = AssistantContextBuilder.make(store: store, message: message)
        let body = AssistantWireRequest(
            requestID: UUID().uuidString,
            tripID: store.data.collaboration?.tripID,
            message: String(message.prefix(4_000)),
            history: history.suffix(12).map { .init(role: $0.role == "assistant" ? "assistant" : "user", text: String($0.text.prefix(1_300))) },
            context: context,
            preferences: preferences.prefix(30).map { String($0.prefix(200)) },
            location: location.map { .init(latitude: $0.latitude, longitude: $0.longitude) },
            webSearch: webSearch
        )
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AssistantServiceError.unavailable }
            if !(200..<300).contains(http.statusCode) {
                if let apiError = try? JSONDecoder().decode(AssistantAPIError.self, from: data) {
                    if apiError.code == "billing_required" || apiError.code == "credit_balance_exhausted" {
                        throw AssistantServiceError.server("Für den Assistenten fehlt noch OpenAI-Guthaben.")
                    }
                    throw AssistantServiceError.server(apiError.error)
                }
                throw AssistantServiceError.server("Die Anfrage konnte nicht verarbeitet werden.")
            }
            guard let reply = try? JSONDecoder().decode(AssistantReply.self, from: data) else { throw AssistantServiceError.invalidResponse }
            return reply
        } catch is CancellationError {
            throw AssistantServiceError.cancelled
        } catch let error as AssistantServiceError {
            throw error
        } catch {
            throw AssistantServiceError.server("Keine Verbindung zum Reise-Assistenten.")
        }
    }
}

private struct AssistantWireRequest: Encodable {
    struct History: Encodable { let role: String; let text: String }
    struct Location: Encodable { let latitude: Double; let longitude: Double }
    let requestID: String
    let tripID: UUID?
    let message: String
    let history: [History]
    let context: AssistantRequestContext
    let preferences: [String]
    let location: Location?
    let webSearch: Bool
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id", tripID = "trip_id", message, history, context, preferences, location
        case webSearch = "web_search"
    }
}

private struct AssistantRequestContext: Encodable {
    let trip: TripInfo
    let places: [ContextPlace]
    let documents: [ContextDocument]
    let collection: [ContextCollection]
}

private struct ContextPlace: Encodable {
    let id: String; let title: String; let note: String; let category: String; let address: String
    let lat: Double?; let lng: Double?; let day: Int?; let franked: Bool; let openingHours: String?
    enum CodingKeys: String, CodingKey { case id, title, note, category, address, lat, lng, day, franked; case openingHours = "opening_hours" }
}
private struct ContextDocument: Encodable { let id: String; let name: String; let text: String }
private struct ContextCollection: Encodable { let id: String; let text: String; let url: String? }
private struct AssistantAPIError: Decodable { let error: String; let code: String? }

@MainActor private enum AssistantContextBuilder {
    static func make(store: AlbumStore, message: String) -> AssistantRequestContext {
        var trip = store.data.trip
        trip.hotel = String(trip.hotel.prefix(300)); trip.outbound = String(trip.outbound.prefix(300)); trip.arrival = String(trip.arrival.prefix(300))
        trip.route = String(trip.route.prefix(300)); trip.flightNumber = String(trip.flightNumber.prefix(150)); trip.notes = String(trip.notes.prefix(2_000))
        let places = store.places.prefix(150).map { place in
            ContextPlace(id: String(place.id.prefix(180)), title: String(place.title.prefix(180)), note: String(place.note.prefix(500)), category: String(place.category.prefix(100)), address: String(place.address.prefix(300)),
                         lat: place.lat, lng: place.lng, day: place.day, franked: place.franked, openingHours: place.openingHours.map { String($0.prefix(400)) })
        }
        let keywords = Set(message.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 3 })
        var docs = store.data.documents.compactMap { doc -> ContextDocument? in
            let hits = keywords.filter { doc.extractedText.range(of: $0, options: .caseInsensitive) != nil || doc.name.range(of: $0, options: .caseInsensitive) != nil }
            guard !hits.isEmpty || keywords.contains(where: { ["flug", "hotel", "unterlagen", "buchung", "dokument", "checkin"].contains($0) }) else { return nil }
            let excerpt: String
            if let keyword = hits.sorted().first,
                                      let range = doc.extractedText.range(of: keyword, options: .caseInsensitive) {
                let start = doc.extractedText.index(range.lowerBound, offsetBy: -min(700, doc.extractedText.distance(from: doc.extractedText.startIndex, to: range.lowerBound)))
                let end = doc.extractedText.index(range.upperBound, offsetBy: min(1_800, doc.extractedText.distance(from: range.upperBound, to: doc.extractedText.endIndex)))
                excerpt = String(doc.extractedText[start..<end])
            } else { excerpt = String(doc.extractedText.prefix(2_500)) }
            return ContextDocument(id: doc.id, name: doc.name, text: String((excerpt.isEmpty ? doc.extractedText : excerpt).prefix(1_500)))
        }
        docs = Array(docs.prefix(5))
        let collection = store.data.collectionEntries.filter { !$0.deleted }.prefix(100).map {
            ContextCollection(id: String($0.id.prefix(180)), text: String(($0.text ?? $0.caption ?? $0.displayTitle ?? "").prefix(700)), url: ($0.url ?? $0.canonicalURL).flatMap { String($0.prefix(1_000)) })
        }
        var contextPlaces = Array(places)
        var context = AssistantRequestContext(trip: trip, places: contextPlaces, documents: docs, collection: collection)
        while encodedSize(context) > 40_000 {
            if !docs.isEmpty { docs.removeLast() }
            else if !context.collection.isEmpty { context = AssistantRequestContext(trip: trip, places: context.places, documents: context.documents, collection: Array(context.collection.dropLast())) }
            else if !contextPlaces.isEmpty { contextPlaces.removeLast(); context = AssistantRequestContext(trip: trip, places: contextPlaces, documents: context.documents, collection: context.collection) }
            else { break }
            context = AssistantRequestContext(trip: trip, places: contextPlaces, documents: docs, collection: context.collection)
        }
        return context
    }

    private static func encodedSize(_ context: AssistantRequestContext) -> Int {
        (try? JSONEncoder().encode(context).count) ?? .max
    }
}

@MainActor final class AssistantLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    private var timedOut = false

    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }

    func request() async -> CLLocationCoordinate2D? {
        guard continuation == nil else { return nil }
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.timedOut = false
            manager.requestWhenInUseAuthorization()
            if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse { manager.startUpdatingLocation() }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard let self, self.continuation != nil else { return }
                self.timedOut = true; self.manager.stopUpdatingLocation(); self.continuation?.resume(returning: nil); self.continuation = nil
            }
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse { manager.startUpdatingLocation() }
        else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted { continuation?.resume(returning: nil); continuation = nil }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, !timedOut else { return }
        manager.stopUpdatingLocation(); continuation?.resume(returning: location.coordinate); continuation = nil
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.stopUpdatingLocation(); continuation?.resume(returning: nil); continuation = nil
    }
}
