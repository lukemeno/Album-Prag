import XCTest
import CoreLocation
@testable import Album

@MainActor
final class DayPlanCommitRegressionTests: XCTestCase {
    private var roots: [URL] = []

    override func tearDownWithError() throws {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots.removeAll()
        try super.tearDownWithError()
    }

    private func makeRoot() -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("day-plan-commit-\(UUID().uuidString)", isDirectory: true)
        roots.append(root)
        return root
    }

    private func makeStore(root: URL) -> AlbumStore {
        let store = AlbumStore(root: root)
        store.data.trip = TripInfo.legacyPrague()
        store.data.trip.planningSchemaVersion = 2
        store.data.schemaVersion = 2
        return store
    }

    private func date(_ day: Int) -> TripDay {
        TripDay(rawValue: String(format: "2026-10-%02d", day))!
    }

    private func makePlace(_ id: String, day: Int? = 4, order: Int? = 0) -> Place {
        Place(id: id, title: id, category: "Sehenswert", lat: 50.0875, lng: 14.4213,
              franked: true, plannedDate: day.map(date), planningSchemaVersion: 2, dayOrder: order)
    }

    private func proposal(_ places: [Place], day: Int, store: AlbumStore) -> DayPlanProposal {
        DayPlanProposal(days: [date(day): places.map { PlanStop(place: $0, slot: "vormittags", note: nil) }],
                        leftOver: [], calendarSnapshot: store.tripCalendar.snapshot, sourceAlbumID: store.data.albumID)
    }

    private func encoded(_ data: AlbumData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(data)
    }

    func testApplyPersistsWholeBatchAndNoOpDoesNotMutate() throws {
        let root = makeRoot()
        let store = makeStore(root: root)
        let places = [makePlace("a"), makePlace("b", order: 1)]
        store.data.places = places
        XCTAssertTrue(store.persist())

        XCTAssertTrue(store.apply(proposal(places, day: 5, store: store)))
        let reopened = makeStore(root: root)
        XCTAssertEqual(reopened.plan(for: date(5)).map(\.id), ["a", "b"])

        let beforeNoOp = reopened.data
        XCTAssertTrue(reopened.apply(proposal(reopened.plan(for: date(5)).map { $0 }, day: 5, store: reopened)))
        XCTAssertEqual(try encoded(reopened.data), try encoded(beforeNoOp))
    }

    func testApplyRollsBackEntireBatchAndDirtyOnPersistenceFailure() throws {
        let root = makeRoot()
        let store = makeStore(root: root)
        let places = [makePlace("a"), makePlace("b", order: 1)]
        store.data.places = places
        store.data.dirty = ["already-dirty"]
        XCTAssertTrue(store.persist())
        let before = store.data

        let albumFile = root.appendingPathComponent("album.json")
        try FileManager.default.removeItem(at: albumFile)
        try FileManager.default.createDirectory(at: albumFile, withIntermediateDirectories: false)

        XCTAssertFalse(store.apply(proposal(places, day: 5, store: store)))
        XCTAssertEqual(try encoded(store.data), try encoded(before))
        XCTAssertEqual(store.data.dirty, before.dirty)
        XCTAssertEqual(store.plan(for: date(4)).map(\.id), ["a", "b"])
    }

    func testApplyRevalidatesStopsAgainstCurrentPlacesAndKeepsCurrentFields() throws {
        let root = makeRoot()
        let store = makeStore(root: root)
        var renamed = makePlace("renamed")
        renamed.title = "Aktueller Nutzername"
        var deleted = makePlace("deleted")
        deleted.deleted = true
        deleted.plannedDate = nil
        deleted.dayOrder = nil
        var unfranked = makePlace("unfranked")
        unfranked.franked = false
        unfranked.plannedDate = nil
        unfranked.dayOrder = nil
        store.data.places = [renamed, deleted, unfranked]
        XCTAssertTrue(store.persist())

        var proposalPlace = renamed
        proposalPlace.title = "Alter Vorschlagstitel"
        let proposal = DayPlanProposal(days: [date(6): [
            PlanStop(place: proposalPlace, slot: "vormittags", note: nil),
            PlanStop(place: deleted, slot: "mittags", note: nil),
            PlanStop(place: unfranked, slot: "abends", note: nil)
        ]], leftOver: [], calendarSnapshot: store.tripCalendar.snapshot, sourceAlbumID: store.data.albumID)

        XCTAssertTrue(store.apply(proposal))
        XCTAssertEqual(store.data.places.first(where: { $0.id == renamed.id })?.title, "Aktueller Nutzername")
        XCTAssertEqual(store.data.places.first(where: { $0.id == renamed.id })?.plannedDate, date(6))
        XCTAssertNil(store.data.places.first(where: { $0.id == deleted.id })?.plannedDate)
        XCTAssertNil(store.data.places.first(where: { $0.id == unfranked.id })?.plannedDate)
    }

    func testApplyRejectsProposalWhenTripChangesAfterPreview() throws {
        let store = makeStore(root: makeRoot())
        let place = makePlace("stale-preview")
        store.data.places = [place]
        XCTAssertTrue(store.persist())
        let proposal = proposal([place], day: 5, store: store)

        var changedTrip = store.data.trip
        changedTrip.endDate = date(8)
        XCTAssertTrue(store.updateTrip(changedTrip))
        XCTAssertFalse(store.apply(proposal))
        XCTAssertEqual(store.data.places.first?.plannedDate, date(4))
    }

    func testApplyRejectsProposalFromDifferentAlbumWithSameCalendar() throws {
        let store = makeStore(root: makeRoot())
        let place = makePlace("foreign-preview")
        store.data.places = [place]
        XCTAssertTrue(store.persist())
        var proposal = proposal([place], day: 5, store: store)
        proposal.sourceAlbumID = "another-album"

        XCTAssertFalse(store.apply(proposal))
        XCTAssertEqual(store.data.places.first?.plannedDate, date(4))
    }
}
