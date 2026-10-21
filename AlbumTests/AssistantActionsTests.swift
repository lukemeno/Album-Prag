import XCTest
import CoreLocation
@testable import Album

@MainActor
final class AssistantActionsTests: XCTestCase {
    private var roots: [URL] = []

    override func tearDownWithError() throws {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots.removeAll()
        try super.tearDownWithError()
    }

    private func root() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("assistant-actions-\(UUID().uuidString)", isDirectory: true)
        roots.append(url)
        return url
    }

    private func place(_ id: String, day: Int? = nil, order: Int? = nil, franked: Bool = true) -> Place {
        Place(id: id, title: id, category: "Sehenswert", address: "(id)-Adresse",
              lat: 50.08, lng: 14.42, franked: franked,
              plannedDate: day.flatMap { TripDay(rawValue: String(format: "2026-10-%02d", $0)) }, dayOrder: order,
              updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private func makeStore(_ places: [Place]) -> AlbumStore {
        let store = AlbumStore(root: root(), shareInbox: ShareInbox(root: root()))
        store.data.places = places
        store.data.trip.title = "Prag"
        store.data.trip.destination = "Prag"
        store.data.trip.startDate = TripDay(rawValue: "2026-10-04")
        store.data.trip.endDate = TripDay(rawValue: "2026-10-09")
        store.data.trip.planningSchemaVersion = 2
        XCTAssertTrue(store.persist())
        return store
    }

    private func day(_ number: Int, _ ids: String...) -> AssistantDay {
        AssistantDay(date: TripDay(rawValue: String(format: "2026-10-%02d", number))!, placeIDs: ids, note: "")
    }

    func testApplyValidatesAndUndoRestoresOnlyTouchedAssignments() throws {
        let store = makeStore([place("a", day: 4, order: 0), place("b", day: 4, order: 1), place("untouched")])
        let actions = AssistantActions(store: store)

        try actions.apply([day(5, "a"), day(6, "b")], to: store)
        XCTAssertTrue(actions.canUndo)
        XCTAssertEqual(store.data.places.first(where: { $0.id == "a" })?.plannedDate?.rawValue, "2026-10-05")
        XCTAssertEqual(store.data.places.first(where: { $0.id == "b" })?.plannedDate?.rawValue, "2026-10-06")

        var unrelated = try XCTUnwrap(store.data.places.first(where: { $0.id == "untouched" }))
        unrelated.note = "Notiz der anderen Person"
        XCTAssertTrue(store.upsert(unrelated))

        try actions.undo(in: store)
        XCTAssertFalse(actions.canUndo)
        XCTAssertEqual(store.data.places.first(where: { $0.id == "a" })?.plannedDate?.rawValue, "2026-10-04")
        XCTAssertEqual(store.data.places.first(where: { $0.id == "a" })?.dayOrder, 0)
        XCTAssertEqual(store.data.places.first(where: { $0.id == "b" })?.plannedDate?.rawValue, "2026-10-04")
        XCTAssertEqual(store.data.places.first(where: { $0.id == "b" })?.dayOrder, 1)
        XCTAssertEqual(store.data.places.first(where: { $0.id == "untouched" })?.note, "Notiz der anderen Person")
    }

    func testApplyRejectsUnknownDuplicateUnfrankedDeletedAndUnlocatedPlaces() throws {
        var deleted = place("deleted"); deleted.deleted = true
        let store = makeStore([place("good"), place("unfranked", franked: false), deleted, Place(id: "unlocated", title: "unlocated", franked: true)])

        let unknown = AssistantActions(store: store)
        XCTAssertThrowsError(try unknown.apply([day(4, "missing")], to: store)) { error in
            XCTAssertEqual(error as? AssistantActions.ActionError, .invalidPlan("Der Tagesplan verweist auf einen unbekannten Ort."))
        }
        let duplicate = AssistantActions(store: store)
        XCTAssertThrowsError(try duplicate.apply([day(4, "good"), day(5, "good")], to: store))
        let unfranked = AssistantActions(store: store)
        XCTAssertThrowsError(try unfranked.apply([day(4, "unfranked")], to: store))
        let deletedAction = AssistantActions(store: store)
        XCTAssertThrowsError(try deletedAction.apply([day(4, "deleted")], to: store))
        let unlocated = AssistantActions(store: store)
        XCTAssertThrowsError(try unlocated.apply([day(4, "unlocated")], to: store))
    }

    func testApplyRejectsInvalidDayAndStalePlaceOrTripRevision() throws {
        let store = makeStore([place("a")])
        let invalidDay = AssistantActions(store: store)
        XCTAssertThrowsError(try invalidDay.apply([day(3, "a")], to: store))

        let changedPlace = AssistantActions(store: store)
        var edited = try XCTUnwrap(store.data.places.first)
        edited.title = "Changed after request"
        XCTAssertTrue(store.upsert(edited))
        XCTAssertThrowsError(try changedPlace.apply([day(4, "a")], to: store)) { error in
            XCTAssertEqual(error as? AssistantActions.ActionError, .staleRequest)
        }

        let tripStore = makeStore([place("a")])
        let tripAction = AssistantActions(store: tripStore)
        var trip = tripStore.data.trip
        trip.notes = "Neue Reise"
        XCTAssertTrue(tripStore.updateTrip(trip))
        XCTAssertThrowsError(try tripAction.apply([day(4, "a")], to: tripStore)) { error in
            XCTAssertEqual(error as? AssistantActions.ActionError, .staleRequest)
        }
    }

    func testApplyPersistenceFailureRollsBackAndDoesNotEnableUndo() throws {
        let store = makeStore([place("a", day: 4, order: 0), place("b", day: 4, order: 1)])
        let before = store.data.places
        let actions = AssistantActions(store: store)
        let albumFile = store.root.appendingPathComponent("album.json")
        try FileManager.default.removeItem(at: albumFile)
        try FileManager.default.createDirectory(at: albumFile, withIntermediateDirectories: false)

        XCTAssertThrowsError(try actions.apply([day(5, "a"), day(6, "b")], to: store)) { error in
            XCTAssertEqual(error as? AssistantActions.ActionError, .persistenceFailed)
        }
        XCTAssertFalse(actions.canUndo)
        XCTAssertEqual(store.data.places, before)
    }

    func testUndoRejectsAChangedTouchedPlace() throws {
        let store = makeStore([place("a", day: 4, order: 0)])
        let actions = AssistantActions(store: store)
        try actions.apply([day(5, "a")], to: store)

        var changed = try XCTUnwrap(store.data.places.first)
        changed.note = "Someone edited this after applying"
        XCTAssertTrue(store.upsert(changed))
        XCTAssertThrowsError(try actions.undo(in: store)) { error in
            XCTAssertEqual(error as? AssistantActions.ActionError, .undoConflict)
        }
        XCTAssertTrue(actions.canUndo)
        XCTAssertEqual(store.data.places.first?.plannedDate?.rawValue, "2026-10-05")
    }

    func testV2PlanRejectsDatesOutsideTripRange() throws {
        let store = makeStore([place("a")])
        let actions = AssistantActions(store: store)
        let outside = AssistantDay(date: TripDay(rawValue: "2026-10-10")!, placeIDs: ["a"], note: "")
        XCTAssertThrowsError(try actions.apply([outside], to: store)) { error in
            guard case .invalidPlan = error as? AssistantActions.ActionError else { return XCTFail("\(error)") }
        }
        XCTAssertNil(store.data.places.first?.plannedDate)
        XCTAssertFalse(actions.canUndo)
    }

    func testV1ReplyIsOnlyAcceptedForTheKnownPragueTrip() throws {
        let store = makeStore([place("a")])
        try AssistantActions(store: store).apply([AssistantDay(day: 7, placeIDs: ["a"], note: "")], protocolVersion: 1, to: store)
        XCTAssertEqual(store.data.places.first?.plannedDate?.rawValue, "2026-10-07")
        XCTAssertNil(store.data.places.first?.day, "Neue Zuordnungen schreiben keine Tageszahl")

        let berlin = makeStore([place("b")])
        berlin.data.trip.title = "Berlin"
        berlin.data.trip.destination = "Berlin"
        berlin.data.trip.hotel = ""
        berlin.data.trip.startDate = TripDay(rawValue: "2027-05-01")
        berlin.data.trip.endDate = TripDay(rawValue: "2027-05-09")
        XCTAssertTrue(berlin.persist())
        XCTAssertThrowsError(try AssistantActions(store: berlin).apply([AssistantDay(day: 5, placeIDs: ["b"], note: "")], protocolVersion: 1, to: berlin))
        XCTAssertNil(berlin.data.places.first?.plannedDate)
    }

    func testUndoRestoresUnresolvedLegacyDay() throws {
        var legacy = place("legacy")
        legacy.day = 31
        let store = makeStore([legacy])
        let actions = AssistantActions(store: store)
        try actions.apply([day(5, "legacy")], to: store)
        XCTAssertEqual(store.data.places.first?.plannedDate?.rawValue, "2026-10-05")
        XCTAssertNil(store.data.places.first?.day)

        try actions.undo(in: store)
        XCTAssertNil(store.data.places.first?.plannedDate)
        XCTAssertEqual(store.data.places.first?.day, 31, "Ein ungelöster alter Wert geht durch Rücknahme nicht verloren")
    }

    func testStoredV1ReplyDecodesWithLegacyDay() throws {
        let json = #"{"answer":"a","sources":[],"places":[],"plan":[{"day":5,"place_ids":["x"],"note":""}],"preferences":[]}"#
        let reply = try JSONDecoder().decode(AssistantReply.self, from: Data(json.utf8))
        XCTAssertEqual(reply.protocolVersion, 1)
        XCTAssertEqual(reply.plan.first?.day, 5)
        XCTAssertNil(reply.plan.first?.date)

        let v2 = #"{"protocol_version":2,"answer":"a","sources":[],"places":[],"plan":[{"date":"2026-10-05","place_ids":["x"],"note":""}],"preferences":[]}"#
        let decoded = try JSONDecoder().decode(AssistantReply.self, from: Data(v2.utf8))
        XCTAssertEqual(decoded.protocolVersion, 2)
        XCTAssertEqual(decoded.plan.first?.date?.rawValue, "2026-10-05")
    }
}
