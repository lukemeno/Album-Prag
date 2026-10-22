import XCTest
@testable import Album

final class TripCalendarTests: XCTestCase {
    func testTripDayAcceptsOnlyStrictRealISOCalendarDates() throws {
        XCTAssertNotNil(TripDay(rawValue: "2028-02-29"))
        XCTAssertNil(TripDay(rawValue: "2027-02-29"))
        XCTAssertNil(TripDay(rawValue: "2026-2-03"))
        XCTAssertNil(TripDay(rawValue: "2026-04-31"))
        XCTAssertNil(TripDay(rawValue: "2026-04-03T00:00:00Z"))

        let day = try XCTUnwrap(TripDay(rawValue: "2028-02-29"))
        XCTAssertEqual(try JSONDecoder().decode(TripDay.self, from: JSONEncoder().encode(day)), day)
    }

    func testInclusiveRangeCrossesDSTUsingTripZone() throws {
        var trip = TripInfo()
        trip.startDate = TripDay(rawValue: "2027-03-27")
        trip.endDate = TripDay(rawValue: "2027-03-30")
        trip.timeZoneIdentifier = "Europe/Berlin"
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-03-27T23:30:00Z"))
        let calendar = TripCalendar(trip: trip, now: { now })

        XCTAssertTrue(calendar.isValidRange)
        XCTAssertEqual(calendar.days.map(\.rawValue), ["2027-03-27", "2027-03-28", "2027-03-29", "2027-03-30"])
        XCTAssertEqual(calendar.today.rawValue, "2027-03-28")
        XCTAssertEqual(calendar.phase, .during)
        XCTAssertTrue(calendar.contains(try XCTUnwrap(TripDay(rawValue: "2027-03-30"))))
        XCTAssertFalse(calendar.contains(try XCTUnwrap(TripDay(rawValue: "2027-03-31"))))
        XCTAssertNotNil(calendar.date(for: try XCTUnwrap(TripDay(rawValue: "2027-03-31"))))
    }

    func testRioRangeCrossesYearBoundary() throws {
        var trip = TripInfo()
        trip.startDate = TripDay(rawValue: "2026-12-29")
        trip.endDate = TripDay(rawValue: "2027-01-03")
        trip.timeZoneIdentifier = "America/Sao_Paulo"
        let calendar = TripCalendar(trip: trip)

        XCTAssertEqual(calendar.days.map(\.rawValue), [
            "2026-12-29", "2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02", "2027-01-03"
        ])
    }

    func testLeapYearMonthBoundaryIsInclusive() throws {
        var trip = TripInfo()
        trip.startDate = TripDay(rawValue: "2028-02-28")
        trip.endDate = TripDay(rawValue: "2028-03-01")
        let calendar = TripCalendar(trip: trip)
        XCTAssertEqual(calendar.days.map(\.rawValue), ["2028-02-28", "2028-02-29", "2028-03-01"])
    }

    func testSingleDayAndRangeBoundAreExplicit() throws {
        var trip = TripInfo()
        trip.startDate = TripDay(rawValue: "2028-02-29")
        trip.endDate = trip.startDate
        XCTAssertEqual(TripCalendar(trip: trip).days.count, 1)

        trip.startDate = TripDay(rawValue: "2020-01-01")
        trip.endDate = TripDay(rawValue: "2031-01-01")
        XCTAssertFalse(TripCalendar(trip: trip).isValidRange)
        XCTAssertTrue(TripCalendar(trip: trip).days.isEmpty)
    }

    func testLegacyPragueCalendarKeepsTodaysGermanLabels() throws {
        let calendar = TripCalendar(trip: .legacyPrague())
        XCTAssertEqual(calendar.days.map(\.rawValue), (4...9).map { String(format: "2026-10-%02d", $0) })
        let sunday = try XCTUnwrap(TripDay(rawValue: "2026-10-04"))
        XCTAssertEqual(calendar.dayTitle(sunday), "Sonntag, 4. Oktober")
        XCTAssertEqual(calendar.weekday(sunday), "So")
        XCTAssertEqual(calendar.weekday(sunday, style: .wide), "Sonntag")
        XCTAssertEqual(calendar.shortDate(sunday), "4. Okt")
        XCTAssertEqual(calendar.dayMonth(sunday), "4. Oktober")
        XCTAssertEqual(calendar.rangeLabel(), "4.–9. Okt")
        XCTAssertEqual(DayPlanGenerator.weekday(try XCTUnwrap(TripDay(rawValue: "2026-10-05")), calendar: calendar), 0)
    }

    func testUndatedTripHasNoDaysPhaseOrToday() {
        var trip = TripInfo()
        trip.destination = "Berlin"
        let calendar = TripCalendar(trip: trip)
        XCTAssertTrue(calendar.days.isEmpty)
        XCTAssertNil(calendar.phase)
        XCTAssertNil(calendar.todayInTrip)
        XCTAssertNil(calendar.rangeLabel())
        XCTAssertNil(calendar.daysUntilStart)
    }
}
