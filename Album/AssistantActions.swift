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
        let date: TripDay?
        let dayOrder: Int?
        /// Nur für die Rücknahme: ein vorher ungelöster alter Tageswert wird unverändert wiederhergestellt.
        let legacyDay: Int?

        init(placeID: String, date: TripDay?, dayOrder: Int?, legacyDay: Int? = nil) {
            self.placeID = placeID
            self.date = date
            self.dayOrder = dayOrder
            self.legacyDay = date == nil ? legacyDay : nil
        }
    }

    private struct PlaceFingerprint: Equatable {
        let id: String
        let title: String
        let address: String
        let latitude: Double?
        let longitude: Double?
        let franked: Bool
        let deleted: Bool
        let plannedDate: TripDay?
        let legacyDay: Int?
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
            plannedDate = place.plannedDate
            legacyDay = place.day
            dayOrder = place.dayOrder
            updatedAt = place.updatedAt
        }
    }

    private struct RequestSnapshot: Equatable {
        let albumID: String
        let collaborationTripID: UUID?
        let tripUpdatedAt: Date
        let tripStartDate: TripDay?
        let tripEndDate: TripDay?
        let tripTimeZoneIdentifier: String?
        let planningSchemaVersion: Int?
        let places: [PlaceFingerprint]

        init(_ data: AlbumData) {
            albumID = data.albumID
            collaborationTripID = data.collaboration?.tripID
            tripUpdatedAt = data.trip.updatedAt
            tripStartDate = data.trip.startDate
            tripEndDate = data.trip.endDate
            tripTimeZoneIdentifier = data.trip.timeZoneIdentifier
            planningSchemaVersion = data.trip.planningSchemaVersion
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
    private let requestSnapshot: RequestSnapshot
    private var undoRecord: UndoRecord?

    init(store: AlbumStore) {
        requestStore = store
        requestSnapshot = RequestSnapshot(store.data)
    }

    var canUndo: Bool { undoRecord != nil }

    /// Refreshes the local snapshot immediately before applying a response.
    /// This closes the normal stale-local-window, but remains a best-effort
    /// client-side guard until the backend exposes a compare-and-set revision.
    func refreshBeforeApply(to store: AlbumStore) async throws {
        guard requestStore === store else { throw ActionError.wrongStore }
        guard await store.refreshForAssistantApply() else { throw ActionError.refreshFailed }
        guard RequestSnapshot(store.data) == requestSnapshot else { throw ActionError.staleRequest }
    }

    /// Validates the request revision and applies the response as one atomic commit.
    /// The response can only assign existing, franked, located places to dates inside the trip range.
    func apply(_ days: [AssistantDay], protocolVersion: Int = AssistantProtocol.version, to store: AlbumStore) throws {
        guard requestStore === store else { throw ActionError.wrongStore }
        guard RequestSnapshot(store.data) == requestSnapshot else { throw ActionError.staleRequest }
        guard undoRecord == nil else { throw ActionError.invalidPlan("Diese Antwort wurde bereits angewendet.") }
        guard !days.isEmpty else { throw ActionError.invalidPlan("Der Tagesplan ist leer.") }

        let calendar = store.tripCalendar
        guard calendar.isValidRange else {
            throw ActionError.invalidPlan("Lege zuerst einen gültigen Reisezeitraum fest, bevor du Tage planst.")
        }

        var seen = Set<String>()
        var seenDays = Set<TripDay>()
        var before: [String: DayAssignment] = [:]
        var proposed: [TripDay: [String]] = [:]

        for assistantDay in days {
            let date: TripDay
            if protocolVersion == 2 {
                guard let proposedDate = assistantDay.date, calendar.contains(proposedDate) else {
                    throw ActionError.invalidPlan("Der Tagesplan enthält ein Datum außerhalb des Reisezeitraums.")
                }
                date = proposedDate
            } else {
                guard protocolVersion == 1, Self.isExplicitLegacyContext(store.data.trip),
                      let legacyDay = assistantDay.day, (4...9).contains(legacyDay),
                      let legacyDate = calendar.days.first(where: { $0.dayOfMonth == legacyDay }) else {
                    throw ActionError.invalidPlan("Dieser alte Tagesplan passt nicht eindeutig zu dieser Reise.")
                }
                date = legacyDate
            }
            guard seenDays.insert(date).inserted else {
                throw ActionError.invalidPlan("Jeder Reisetag darf nur einmal vorkommen.")
            }
            var ids: [String] = []
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
                before[placeID] = DayAssignment(placeID: placeID, date: place.plannedDate, dayOrder: place.dayOrder, legacyDay: place.day)
                ids.append(placeID)
            }
            proposed[date] = ids
        }

        let assignments = proposed.keys.sorted().flatMap { date in
            (proposed[date] ?? []).enumerated().map { index, placeID in
                DayAssignment(placeID: placeID, date: date, dayOrder: index)
            }
        }
        guard store.applyAssistantDayAssignments(assignments) else { throw ActionError.persistenceFailed }

        let changedIDs: [String] = before.keys.sorted().compactMap { id -> String? in
            guard let old = before[id] else { return nil }
            guard let current = store.data.places.first(where: { $0.id == id }) else { return nil }
            guard current.plannedDate != old.date || current.dayOrder != old.dayOrder || current.day != old.legacyDay else { return nil }
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

    /// Alte Antworten mit Tageszahlen gelten nur für die bekannte Prag-Reise vom 4.–9. Oktober 2026.
    private static func isExplicitLegacyContext(_ trip: TripInfo) -> Bool {
        let city = [trip.title, trip.destination].compactMap { $0 }.contains { value in
            ["Prag", "Prague", "Praha"].contains { candidate in
                value.localizedCaseInsensitiveCompare(candidate) == .orderedSame
            }
        }
        let seededHotel = trip.hotel.localizedCaseInsensitiveCompare("Hotel Urban Crème") == .orderedSame
        return trip.startDate == TripInfo.legacyPragueStart && trip.endDate == TripInfo.legacyPragueEnd
            && (city || seededHotel)
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
