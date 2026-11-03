import XCTest
@testable import Album

/// Fehlerfälle der Album-Zuordnung (UX-DURCHGANG.md, Paket 1): Zeitzone am Tagesrand, fehlende
/// Aufnahmedaten oder Koordinaten, Fotos außerhalb der Reise, 300-m-Rand, zwei nahe Orte, gelöschte Fotos.
final class AlbumRecapTests: XCTestCase {
    private let letna = (lat: 50.0966, lng: 14.4165)

    private func calendar(start: String? = "2026-10-04", end: String? = "2026-10-09") -> TripCalendar {
        var trip = TripInfo()
        trip.startDate = start.flatMap(TripDay.init(rawValue:))
        trip.endDate = end.flatMap(TripDay.init(rawValue:))
        trip.timeZoneIdentifier = "Europe/Prague"
        return TripCalendar(trip: trip)
    }

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    private func photo(_ id: String, takenAt: String? = nil, createdAt: String = "2026-10-20T10:00:00Z",
                       at coordinate: (lat: Double, lng: Double)? = nil, placeID: String? = nil, deleted: Bool = false) -> TripMemoryPhoto {
        TripMemoryPhoto(id: id, placeID: placeID, authorName: "Luke", createdAt: date(createdAt),
                        takenAt: takenAt.map(date), latitude: coordinate?.lat, longitude: coordinate?.lng,
                        width: 10, height: 10, sha256: id, thumbnailSHA256: id, deleted: deleted)
    }

    private func place(_ id: String, day: String?, at coordinate: (lat: Double, lng: Double)? = nil, visited: Bool = false) -> Place {
        Place(id: id, title: id, category: "Aussicht", author: "Luke", lat: coordinate?.lat, lng: coordinate?.lng,
              franked: true, visited: visited, plannedDate: day.flatMap(TripDay.init(rawValue:)))
    }

    private func days(_ recap: AlbumRecap) -> [String] { recap.days.map { $0.day?.rawValue ?? "ohne" } }

    func testLatePhotoInPragueStaysOnItsLocalDay() {
        // 23:30 in Prag ist 21:30 UTC – derselbe Kalendertag, nicht der nächste.
        let recap = AlbumRecap(places: [], photos: [photo("late", takenAt: "2026-10-04T21:30:00Z")], calendar: calendar())
        XCTAssertEqual(days(recap), ["2026-10-04"])
        XCTAssertEqual(recap.days.first?.photos.map(\.id), ["late"])
    }

    func testPhotoWithoutTakenAtFallsBackToCreatedAt() {
        let recap = AlbumRecap(places: [], photos: [photo("old", createdAt: "2026-10-05T09:00:00Z")], calendar: calendar())
        XCTAssertEqual(days(recap), ["2026-10-05"])
    }

    func testPhotoOutsideTheTripGoesToOtherPhotos() {
        let recap = AlbumRecap(places: [], photos: [photo("home", takenAt: "2026-10-20T09:00:00Z")], calendar: calendar())
        XCTAssertTrue(recap.days.isEmpty)
        XCTAssertEqual(recap.otherPhotos.map(\.id), ["home"])
    }

    func testWithoutTripDatesPhotosStillGroupByDay() {
        let recap = AlbumRecap(places: [], photos: [photo("p", takenAt: "2026-10-20T09:00:00Z")], calendar: calendar(start: nil, end: nil))
        XCTAssertEqual(days(recap), ["2026-10-20"])
        XCTAssertTrue(recap.otherPhotos.isEmpty)
    }

    func testNearbyPhotoOnThePlannedDayMarksPlaceVisited() {
        let recap = AlbumRecap(places: [place("Letna", day: "2026-10-04", at: letna)],
                               photos: [photo("p", takenAt: "2026-10-04T10:00:00Z", at: (50.0980, 14.4165))], // ~156 m
                               calendar: calendar())
        XCTAssertEqual(recap.days.first?.places.map(\.id), ["Letna"])
    }

    func testPhotoJustBeyondThreeHundredMetresDoesNotCount() {
        let recap = AlbumRecap(places: [place("Letna", day: "2026-10-04", at: letna)],
                               photos: [photo("p", takenAt: "2026-10-04T10:00:00Z", at: (50.0994, 14.4165))], // ~311 m
                               calendar: calendar())
        XCTAssertEqual(recap.days.first?.places, [])
        XCTAssertEqual(recap.days.first?.photos.map(\.id), ["p"])
    }

    func testNearbyPhotoOnAnotherDayDoesNotCount() {
        let recap = AlbumRecap(places: [place("Letna", day: "2026-10-05", at: letna)],
                               photos: [photo("p", takenAt: "2026-10-04T10:00:00Z", at: letna)], calendar: calendar())
        XCTAssertFalse(recap.days.contains { !$0.places.isEmpty })
    }

    func testPlaceWithoutCoordinatesOrPhotoWithoutGPSNeedsTheManualMark() {
        let recap = AlbumRecap(places: [place("NoGeo", day: "2026-10-04"), place("Letna", day: "2026-10-04", at: letna)],
                               photos: [photo("p", takenAt: "2026-10-04T10:00:00Z")], calendar: calendar())
        XCTAssertEqual(recap.days.first?.places, [])
    }

    func testLinkedPhotoMarksItsPlaceVisitedEvenWithoutDistance() {
        let recap = AlbumRecap(places: [place("Savoy", day: "2026-10-05")],
                               photos: [photo("p", takenAt: "2026-10-05T10:00:00Z", placeID: "Savoy")], calendar: calendar())
        XCTAssertEqual(recap.days.first?.places.map(\.id), ["Savoy"])
    }

    func testPhotoNearTwoPlacesCountsForBoth() {
        let recap = AlbumRecap(places: [place("A", day: "2026-10-04", at: letna), place("B", day: "2026-10-04", at: (50.0970, 14.4170))],
                               photos: [photo("p", takenAt: "2026-10-04T10:00:00Z", at: letna)], calendar: calendar())
        XCTAssertEqual(Set(recap.days.first?.places.map(\.id) ?? []), ["A", "B"])
    }

    func testManualMarkStillCountsAndPlacesWithoutDayComeLast() {
        let recap = AlbumRecap(places: [place("Loose", day: nil, visited: true), place("Marked", day: "2026-10-06", visited: true)],
                               photos: [], calendar: calendar())
        XCTAssertEqual(days(recap), ["2026-10-06", "ohne"])
    }

    func testDeletedPhotosAreIgnored() {
        let recap = AlbumRecap(places: [place("Letna", day: "2026-10-04", at: letna)],
                               photos: [photo("gone", takenAt: "2026-10-04T10:00:00Z", at: letna, deleted: true)], calendar: calendar())
        XCTAssertTrue(recap.days.isEmpty)
        XCTAssertTrue(recap.otherPhotos.isEmpty)
    }

    func testOldPhotoPayloadWithoutNewFieldsStillDecodes() throws {
        let json = #"{"id":"x","caption":"","authorID":"","authorName":"Luke","createdAt":1790000000,"width":1,"height":1,"filename":"x.jpg","thumbnailFilename":"x-thumb.jpg","sha256":"a","thumbnailSHA256":"b","deleted":false}"#
        let decoded = try JSONDecoder().decode(TripMemoryPhoto.self, from: Data(json.utf8))
        XCTAssertNil(decoded.takenAt)
        XCTAssertNil(decoded.latitude)
        let roundTrip = try JSONDecoder().decode(TripMemoryPhoto.self, from: JSONEncoder().encode(
            photo("y", takenAt: "2026-10-04T10:00:00Z", at: letna)))
        XCTAssertEqual(roundTrip.takenAt, date("2026-10-04T10:00:00Z"))
        XCTAssertEqual(roundTrip.latitude, letna.lat)
    }
}
