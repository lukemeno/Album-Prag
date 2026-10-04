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
              lat: 50.08, lng: 14.42, franked: franked, day: day, dayOrder: order,
              updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private func makeStore(_ places: [Place]) -> AlbumStore {
        let store = AlbumStore(root: root(), shareInbox: ShareInbox(root: root()))
        store.data.places = places
        XCTAssertTrue(store.persist())
        return store
    }

    private func day(_ number: Int, _ ids: String...) -> AssistantDay {
        AssistantDay(day: number, placeIDs: ids, note: "")
    }

    func testApplyValidatesAndUndoRestoresOnlyTouchedAssignments() throws {
        let store = makeStore([place("a", day: 4, order: 0), place("b", day: 4, order: 1), place("untouched")])
        let actions = AssistantActions(store: store)

        try actions.apply([day(5, "a"), day(6, "b")], to: store)
        XCTAssertTrue(actions.canUndo)
        XCTAssertEqual(store.data.places.first(where: { $0.id == "a" })?.day, 5)
        XCTAssertEqual(store.data.places.first(where: { $0.id == "b" })?.day, 6)

        var unrelated = try XCTUnwrap(store.data.places.first(where: { $0.id == "untouched" }))
        unrelated.note = "Notiz der anderen Person"
        XCTAssertTrue(store.upsert(unrelated))

        try actions.undo(in: store)
        XCTAssertFalse(actions.canUndo)
        XCTAssertEqual(store.data.places.first(where: { $0.id == "a" })?.day, 4)
        XCTAssertEqual(store.data.places.first(where: { $0.id == "a" })?.dayOrder, 0)
        XCTAssertEqual(store.data.places.first(where: { $0.id == "b" })?.day, 4)
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
        XCTAssertEqual(store.data.places.first?.day, 5)
    }

    func testPersistedSnapshotReconstructsActionAndRejectsStalePlan() throws {
        let store = makeStore([place("a")])
        let original = AssistantActions(store: store)
        let encoded = try JSONEncoder().encode(original.snapshot)
        let decoded = try JSONDecoder().decode(AssistantActions.Snapshot.self, from: encoded)
        let restored = AssistantActions(store: store, snapshot: decoded)

        try restored.apply([day(4, "a")], to: store)
        XCTAssertEqual(store.data.places.first?.day, 4)

        let staleStore = makeStore([place("a")])
        let staleOriginal = AssistantActions(store: staleStore)
        let staleSnapshot = try JSONDecoder().decode(
            AssistantActions.Snapshot.self,
            from: JSONEncoder().encode(staleOriginal.snapshot)
        )
        var changed = try XCTUnwrap(staleStore.data.places.first)
        changed.note = "Nachträgliche Änderung"
        XCTAssertTrue(staleStore.upsert(changed))
        let staleRestored = AssistantActions(store: staleStore, snapshot: staleSnapshot)

        XCTAssertThrowsError(try staleRestored.apply([day(4, "a")], to: staleStore)) { error in
            XCTAssertEqual(error as? AssistantActions.ActionError, .staleRequest)
        }
    }
}
