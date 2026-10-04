import Foundation

/// The small, user-confirmed mutation surface for assistant-generated day plans.
///
/// An instance is created when the assistant request is sent.  It therefore owns
/// the request's local revision and refuses to apply a response to a different
/// version of the trip.
@MainActor
final class AssistantActions {
    enum ActionError: Error, Equatable, LocalizedError {
        case wrongStore
        case staleRequest
        case invalidPlan(String)
        case noUndo
        case undoConflict
        case persistenceFailed
        case refreshFailed

        var errorDescription: String? {
            switch self {
            case .wrongStore: "Diese Antwort gehört zu einer anderen Reise."
            case .staleRequest: "Die Reise wurde geändert, seit diese Antwort angefragt wurde."
            case .invalidPlan(let reason): reason
            case .noUndo: "Für diese Antwort gibt es keine Rücknahme."
            case .undoConflict: "Die betroffenen Orte wurden seit dem Anwenden geändert."
            case .persistenceFailed: "Der Tagesplan konnte nicht gespeichert werden."
            case .refreshFailed: "Die gemeinsame Reise konnte vor dem Anwenden nicht abgeglichen werden."
            }
        }
    }

    /// A value type shared with AlbumStore's narrow atomic day-assignment commit
    /// hook.  The hook is intentionally the only operation AssistantActions needs
    /// beyond the existing DayPlanProposal API.
    struct DayAssignment: Equatable {
        let placeID: String
        let day: Int?
        let dayOrder: Int?

        init(placeID: String, day: Int?, dayOrder: Int?) {
            self.placeID = placeID
            self.day = day
            self.dayOrder = dayOrder
        }
    }

    struct PlaceFingerprint: Codable, Equatable {
        let id: String
        let title: String
        let address: String
        let latitude: Double?
        let longitude: Double?
        let franked: Bool
        let deleted: Bool
        let day: Int?
        let dayOrder: Int?
        let updatedAt: Date

        init(_ place: Place) {
            id = place.id
            title = place.title
            address = place.address
            latitude = place.lat
            longitude = place.lng
            franked = place.franked
            deleted = place.deleted
            day = place.day
            dayOrder = place.dayOrder
            updatedAt = place.updatedAt
        }

        var withoutAssignment: PlaceFingerprint {
            PlaceFingerprint(id: id, title: title, address: address, latitude: latitude,
                             longitude: longitude, franked: franked, deleted: deleted,
                             day: nil, dayOrder: nil, updatedAt: updatedAt)
        }

        private init(id: String, title: String, address: String, latitude: Double?, longitude: Double?,
                     franked: Bool, deleted: Bool, day: Int?, dayOrder: Int?, updatedAt: Date) {
            self.id = id
            self.title = title
            self.address = address
            self.latitude = latitude
            self.longitude = longitude
            self.franked = franked
            self.deleted = deleted
            self.day = day
            self.dayOrder = dayOrder
            self.updatedAt = updatedAt
        }
    }

    /// Persisted with a chat response so a confirmed plan can still be
    /// validated after the assistant sheet or app has been reopened.
    struct Snapshot: Codable, Equatable {
        let albumID: String
        let collaborationTripID: UUID?
        let tripUpdatedAt: Date
        let places: [PlaceFingerprint]

        init(_ data: AlbumData) {
            albumID = data.albumID
            collaborationTripID = data.collaboration?.tripID
            tripUpdatedAt = data.trip.updatedAt
            places = data.places.map(PlaceFingerprint.init).sorted { lhs, rhs in
                if lhs.id != rhs.id { return lhs.id < rhs.id }
                return lhs.updatedAt < rhs.updatedAt
            }
        }
    }

    private struct UndoRecord {
        let assignments: [DayAssignment]
        let postApply: [String: PlaceFingerprint]
    }

    private weak var requestStore: AlbumStore?
    private let requestSnapshot: Snapshot
    private var undoRecord: UndoRecord?

    init(store: AlbumStore) {
        requestStore = store
        requestSnapshot = Snapshot(store.data)
    }

    init(store: AlbumStore, snapshot: Snapshot) {
        requestStore = store
        requestSnapshot = snapshot
    }

    var snapshot: Snapshot { requestSnapshot }

    var canUndo: Bool { undoRecord != nil }

    /// Refreshes the local snapshot immediately before applying a response.
    /// This closes the normal stale-local-window, but remains a best-effort
    /// client-side guard until the backend exposes a compare-and-set revision.
    func refreshBeforeApply(to store: AlbumStore) async throws {
        guard requestStore === store else { throw ActionError.wrongStore }
        guard await store.refreshForAssistantApply() else { throw ActionError.refreshFailed }
        guard Snapshot(store.data) == requestSnapshot else { throw ActionError.staleRequest }
    }

    /// Validates the request revision and applies the response as one proposal.
    /// The response can only assign existing, franked, located places to days 4–9.
    func apply(_ days: [AssistantDay], to store: AlbumStore) throws {
        guard requestStore === store else { throw ActionError.wrongStore }
        guard Snapshot(store.data) == requestSnapshot else { throw ActionError.staleRequest }
        guard undoRecord == nil else { throw ActionError.invalidPlan("Diese Antwort wurde bereits angewendet.") }
        guard !days.isEmpty else { throw ActionError.invalidPlan("Der Tagesplan ist leer.") }

        var seen = Set<String>()
        var seenDays = Set<Int>()
        var proposalDays: [Int: [PlanStop]] = [:]
        var before: [String: DayAssignment] = [:]

        for assistantDay in days {
            guard (4...9).contains(assistantDay.day) else {
                throw ActionError.invalidPlan("Der Tagesplan enthält einen ungültigen Reisetag.")
            }
            guard seenDays.insert(assistantDay.day).inserted else {
                throw ActionError.invalidPlan("Jeder Reisetag darf nur einmal vorkommen.")
            }
            var stops: [PlanStop] = []
            for placeID in assistantDay.placeIDs {
                guard seen.insert(placeID).inserted else {
                    throw ActionError.invalidPlan("Ein Ort darf nur einmal im Tagesplan vorkommen.")
                }
                guard let place = store.data.places.first(where: { $0.id == placeID }) else {
                    throw ActionError.invalidPlan("Der Tagesplan verweist auf einen unbekannten Ort.")
                }
                guard place.franked, !place.deleted else {
                    throw ActionError.invalidPlan("Der Tagesplan darf nur aktive, beschlossene Orte enthalten.")
                }
                guard place.coordinate != nil else {
                    throw ActionError.invalidPlan("Jeder geplante Ort braucht eine gespeicherte Koordinate.")
                }
                before[placeID] = DayAssignment(placeID: placeID, day: place.day, dayOrder: place.dayOrder)
                stops.append(PlanStop(place: place, slot: "", note: nil))
            }
            proposalDays[assistantDay.day] = stops
        }

        let proposal = DayPlanProposal(days: proposalDays, leftOver: [])
        guard store.apply(proposal) else { throw ActionError.persistenceFailed }

        let changedIDs: [String] = before.keys.sorted().compactMap { id -> String? in
            guard let old = before[id] else { return nil }
            guard let current = store.data.places.first(where: { $0.id == id }) else { return nil }
            guard current.day != old.day || current.dayOrder != old.dayOrder else { return nil }
            return id
        }
        guard !changedIDs.isEmpty else { return }

        var postApply: [String: PlaceFingerprint] = [:]
        for id in changedIDs {
            guard let current = store.data.places.first(where: { $0.id == id }) else {
                throw ActionError.persistenceFailed
            }
            postApply[id] = PlaceFingerprint(current)
        }
        undoRecord = UndoRecord(
            assignments: changedIDs.compactMap { before[$0] },
            postApply: postApply
        )
    }

    /// Restores only the day fields touched by the preceding successful apply.
    /// AlbumStore performs the final mutation, persistence and sync scheduling
    /// atomically through its narrow `applyAssistantDayAssignments` hook.
    func undo(in store: AlbumStore) throws {
        guard requestStore === store else { throw ActionError.wrongStore }
        guard let undoRecord else { throw ActionError.noUndo }

        for assignment in undoRecord.assignments {
            guard let current = store.data.places.first(where: { $0.id == assignment.placeID }),
                  let expected = undoRecord.postApply[assignment.placeID],
                  PlaceFingerprint(current) == expected else {
                throw ActionError.undoConflict
            }
        }

        guard store.applyAssistantDayAssignments(undoRecord.assignments) else {
            throw ActionError.persistenceFailed
        }
        self.undoRecord = nil
    }
}
