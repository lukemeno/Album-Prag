import XCTest
import CoreLocation
@testable import Album

final class DayPlanTests: XCTestCase {
    private let hotel = CLLocationCoordinate2D(latitude: 50.0898, longitude: 14.4318)

    private func place(_ id: String, _ lat: Double, _ lng: Double, category: String = "Sehenswert", hours: String? = "", date: String? = nil) -> Place {
        var place = Place(id: id, title: id, category: category, lat: lat, lng: lng, franked: true,
                          plannedDate: date.flatMap(TripDay.init(rawValue:)), planningSchemaVersion: date == nil ? nil : 2)
        place.openingHours = hours
        return place
    }

    private func tripCalendar(_ start: String = "2027-04-30", _ end: String = "2027-05-03", now: String = "2027-04-30") -> TripCalendar {
        var trip = TripInfo()
        trip.startDate = TripDay(rawValue: start)
        trip.endDate = TripDay(rawValue: end)
        trip.timeZoneIdentifier = "Europe/Berlin"
        return TripCalendar(trip: trip, now: { Self.utcDate(now) })
    }

    private static func utcDate(_ raw: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw) ?? .distantPast
    }

    func testOpeningHoursCommonForms() throws {
        let museum = try XCTUnwrap(OpeningHours("Tu-Su 10:00-18:00; Mo off"))
        XCTAssertFalse(museum.isOpen(weekday: 0))
        XCTAssertTrue(museum.isOpen(weekday: 6, at: 17 * 60))
        XCTAssertFalse(museum.isOpen(weekday: 6, at: 9 * 60))

        let cafe = try XCTUnwrap(OpeningHours("Mo-Fr 08:00-22:00; Sa,Su 09:00-20:00"))
        XCTAssertEqual(cafe.summary(weekday: 5), "09:00–20:00")

        let bar = try XCTUnwrap(OpeningHours("18:00-02:00"))
        XCTAssertTrue(bar.isOpen(weekday: 2, at: 25 * 60))
        XCTAssertTrue(try XCTUnwrap(OpeningHours("24/7")).isOpen(weekday: 3, at: 3 * 60))

        // Exotisches bleibt unbekannt statt falsch geraten.
        XCTAssertNil(OpeningHours("Apr-Oct Mo-Su 09:00-18:00"))
        XCTAssertNil(OpeningHours("sunrise-sunset"))
        XCTAssertNil(OpeningHours(""))
    }

    func testOpeningHoursMatchNeedsTheName() {
        let elements = [["name": "Kavárna Slavia", "opening_hours": "Mo-Su 08:00-23:00"],
                        ["name": "Trafika", "opening_hours": "Mo-Fr 06:00-18:00"]]
        XCTAssertEqual(OpeningHoursService.bestMatch(elements, title: "Café Slavia"), nil)
        XCTAssertEqual(OpeningHoursService.bestMatch(elements, title: "Kavárna Slavia"), "Mo-Su 08:00-23:00")
    }

    func testCalendarDaysCrossMonthAndWeekdayUsesActualDate() {
        let calendar = tripCalendar("2027-04-30", "2027-05-03")
        XCTAssertEqual(calendar.days.map(\.rawValue), ["2027-04-30", "2027-05-01", "2027-05-02", "2027-05-03"])
        XCTAssertEqual(DayPlanGenerator.weekday(calendar.days[0], calendar: calendar), 4) // Freitag
        XCTAssertEqual(DayPlanGenerator.weekday(calendar.days[3], calendar: calendar), 0) // Montag
    }

    func testLeapDayAndYearBoundaryAreInclusive() {
        XCTAssertEqual(tripCalendar("2028-02-28", "2028-03-01").days.map(\.rawValue), ["2028-02-28", "2028-02-29", "2028-03-01"])
        XCTAssertEqual(tripCalendar("2026-12-29", "2027-01-03").days.map(\.rawValue), [
            "2026-12-29", "2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02", "2027-01-03"
        ])
    }

    func testNearbyPlacesShareADay() {
        let lesser = [place("a1", 50.0880, 14.4030), place("a2", 50.0875, 14.4045), place("a3", 50.0890, 14.4010)]
        let vinohrady = [place("b1", 50.0755, 14.4400), place("b2", 50.0760, 14.4420), place("b3", 50.0748, 14.4385)]
        let calendar = tripCalendar()
        let proposal = DayPlanGenerator.plan(places: lesser + vinohrady, hotel: hotel, calendar: calendar)
        let dayOf = { (id: String) in proposal.days.first { $0.value.contains { $0.id == id } }?.key }
        XCTAssertEqual(Set(lesser.map { dayOf($0.id) }).count, 1)
        XCTAssertEqual(Set(vinohrady.map { dayOf($0.id) }).count, 1)
        XCTAssertNotEqual(dayOf("a1"), dayOf("b1"))
        XCTAssertTrue(proposal.leftOver.isEmpty)
    }

    func testClosedWeekdayIsAvoidedAcrossMonthBoundary() {
        let calendar = tripCalendar()
        let museum = place("museum", 50.0870, 14.4200, hours: "Tu-Su 10:00-18:00; Mo off")
        let proposal = DayPlanGenerator.plan(places: [museum], hotel: hotel, calendar: calendar)
        let assigned = proposal.days.first { $0.value.contains { $0.id == "museum" } }?.key
        XCTAssertNotNil(assigned)
        XCTAssertNotEqual(assigned, calendar.days.last) // Monday, 3 May
    }

    func testFlightWindowsRequireMatchingActualDates() {
        let calendar = tripCalendar()
        let flights = [
            FlightLeg(direction: .outbound, number: "OUT", from: "A", to: "B", date: "30.04.2027", departure: "14:00", arrival: "15:55"),
            FlightLeg(direction: .inbound, number: "BACK", from: "B", to: "A", date: "2027-05-03", departure: "12:20", arrival: "13:35"),
            FlightLeg(direction: .outbound, number: "OLD", from: "A", to: "B", date: "30.04.2026", departure: "08:00", arrival: "08:30")
        ]
        let windows = DayPlanGenerator.windows(flights: flights, calendar: calendar)
        XCTAssertEqual(windows[calendar.days[0]]?.start, 15 * 60 + 55 + 90)
        XCTAssertEqual(windows[calendar.days[3]]?.end, 12 * 60 + 20 - 165)
        XCTAssertEqual(windows[calendar.days[1]], DayPlanGenerator.Window(start: 10 * 60, end: 22 * 60))
    }

    func testNoFlightsUseFullWindowsAndUndatedTripsKeepIdeasUnassigned() {
        let calendar = tripCalendar()
        let windows = DayPlanGenerator.windows(flights: [], calendar: calendar)
        XCTAssertTrue(windows.values.allSatisfy { $0 == DayPlanGenerator.Window(start: 10 * 60, end: 22 * 60) })

        var trip = TripInfo()
        trip.destination = "Berlin"
        let undated = TripCalendar(trip: trip, now: { Self.utcDate("2027-04-30") })
        let idea = place("idea", 52.52, 13.405)
        let proposal = DayPlanGenerator.plan(places: [idea], hotel: nil, calendar: undated)
        XCTAssertTrue(proposal.days.isEmpty)
        XCTAssertEqual(proposal.leftOver.map(\.id), ["idea"])
        XCTAssertNil(idea.plannedDate)
    }

    func testOneDayTravelUsesBothFlightBoundsAndEmptyWindowIsSafe() throws {
        let date = tripCalendar("2028-02-29", "2028-02-29")
        let flights = [
            FlightLeg(direction: .outbound, number: "OUT", from: "A", to: "B", date: "29.02.2028", departure: "09:00", arrival: "14:00"),
            FlightLeg(direction: .inbound, number: "BACK", from: "B", to: "A", date: "29.02.2028", departure: "16:00", arrival: "18:00")
        ]
        let windows = DayPlanGenerator.windows(flights: flights, calendar: date)
        let day = try XCTUnwrap(date.days.first)
        XCTAssertEqual(windows[day]?.start, 15 * 60 + 30)
        XCTAssertEqual(windows[day]?.end, 13 * 60 + 15)
        XCTAssertEqual(windows[day]?.minutes, 0)
        let proposal = DayPlanGenerator.plan(places: [place("one", 50.08, 14.42)], hotel: nil, flights: flights, calendar: date)
        XCTAssertEqual(proposal.days[day] ?? [], [])
        XCTAssertEqual(proposal.leftOver.map(\.id), ["one"])
    }

    func testRouteVisitsPointsOnALineInOrder() {
        let line = [place("far", 50.0898, 14.4018), place("near", 50.0898, 14.4218), place("mid", 50.0898, 14.4118)]
        XCTAssertEqual(DayPlanGenerator.route(line, from: hotel).map(\.id), ["near", "mid", "far"])
    }

    func testPlanningWithoutHotelStartsAtAnExistingPlace() throws {
        let calendar = tripCalendar("2027-05-01", "2027-05-01")
        let place = self.place("walk", 52.52, 13.405)
        let proposal = DayPlanGenerator.plan(places: [place], hotel: nil, calendar: calendar)
        let day = try XCTUnwrap(calendar.days.first)
        XCTAssertEqual(proposal.days[day]?.map(\.id), ["walk"])
        XCTAssertTrue(proposal.leftOver.isEmpty)
    }

    func testUnresolvedAndOutOfRangeAssignmentsAreNeverAutoMoved() {
        let calendar = tripCalendar()
        let outside = place("outside", 50.08, 14.42, date: "2027-04-29")
        let unresolved = Place(id: "legacy", title: "legacy", category: "Sehenswert", lat: 50.08, lng: 14.42,
                               franked: true, day: 4)
        let free = place("free", 50.081, 14.421)
        let proposal = DayPlanGenerator.plan(places: [outside, unresolved, free], hotel: hotel,
                                             calendar: calendar, keepAssigned: false)
        let assignedIDs = proposal.days.values.flatMap { $0.map(\.id) }
        XCTAssertTrue(assignedIDs.contains("free"))
        XCTAssertFalse(assignedIDs.contains("outside"))
        XCTAssertFalse(assignedIDs.contains("legacy"))
        XCTAssertEqual(Set(proposal.leftOver.map(\.id)), Set(["outside", "legacy"]))
    }

    func testAssignedPlacesStayUnlessReplanned() {
        let calendar = tripCalendar()
        let assignedDate = calendar.days[2]
        let fixed = place("fixed", 50.0755, 14.4400, date: assignedDate.rawValue)
        XCTAssertTrue(DayPlanGenerator.plan(places: [fixed], hotel: hotel, calendar: calendar).days[assignedDate]?.contains { $0.id == "fixed" } == true)
        let replanned = DayPlanGenerator.plan(places: [fixed], hotel: hotel, calendar: calendar, keepAssigned: false)
        XCTAssertEqual(replanned.days.values.flatMap { $0 }.count, 1)
    }

    func testOpeningHoursSurviveSync() throws {
        var original = Place(title: "Café")
        original.openingHours = "Mo-Su 08:00-22:00"
        let decoded = try JSONDecoder().decode(Place.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.openingHours, "Mo-Su 08:00-22:00")
    }
}

extension DayPlanTests {
    func testDayListWithSpacesIsRead() throws {
        let hours = try XCTUnwrap(OpeningHours("Mo-Fr 08:00-20:00; Sa, Su 10:00-19:00"))
        XCTAssertTrue(hours.isOpen(weekday: 6, at: 11 * 60))
        XCTAssertFalse(hours.isOpen(weekday: 6, at: 9 * 60))
    }

    func testShortOSMNameStillMatches() {
        XCTAssertEqual(OpeningHoursService.bestMatch([["name": "Louvre", "opening_hours": "Mo-Su 08:00-23:30"]], title: "Café Louvre"), "Mo-Su 08:00-23:30")
    }
}

extension DayPlanTests {
    func testCafesAreSpreadAcrossDays() {
        let cafes = [place("c1", 50.0819, 14.4185, category: "Essen & Trinken"),
                     place("c2", 50.0814, 14.4136, category: "Essen & Trinken"),
                     place("c3", 50.0808, 14.4064, category: "Essen & Trinken")]
        let proposal = DayPlanGenerator.plan(places: cafes, hotel: hotel, calendar: tripCalendar())
        for stops in proposal.days.values {
            XCTAssertLessThanOrEqual(stops.filter { $0.place.category == "Essen & Trinken" }.count, 2)
        }
    }
}

extension DayPlanTests {
    func testMealsAreNotBackToBack() {
        let order = DayPlanGenerator.separateMeals([
            place("ring", 50.0875, 14.4213), place("louvre", 50.0819, 14.4185, category: "Essen & Trinken"),
            place("slavia", 50.0814, 14.4136, category: "Essen & Trinken"), place("bridge", 50.0865, 14.4114),
        ])
        XCTAssertEqual(order.map(\.id), ["ring", "louvre", "bridge", "slavia"])
    }

    func testOldWikimediaPhotosAreSearchedOnce() {
        var place = place("letna", 50.0966, 14.4165, category: "Aussicht")
        let identity = ResolvedPlaceIdentity(title: place.title, latitude: 50.0966, longitude: 14.4165)
        place.image = .external(ExternalPlaceImage(imageURL: "https://x/a.jpg", sourceURL: "https://x", credit: "x", provider: .wikimedia, resolvedFor: identity))
        XCTAssertTrue(PlaceImageService.shouldSearch(for: place, force: false))
        place.image = .external(ExternalPlaceImage(imageURL: "https://x/a.jpg", sourceURL: "https://x", credit: "x", provider: .wikimedia, resolvedFor: identity, ranking: PlaceImageService.ranking))
        XCTAssertFalse(PlaceImageService.shouldSearch(for: place, force: false))
    }
}

extension DayPlanTests {
    func testWikimediaThumbnailsLoadSmallerFiles() {
        let asset = PlaceImageAsset.external(ExternalPlaceImage(
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Letna.jpg/1600px-Letna.jpg",
            sourceURL: "https://commons.wikimedia.org/wiki/File:Letna.jpg", credit: "x", provider: .wikimedia))
        // Nur feste Breiten sind erlaubt: 480 wird zu 500.
        XCTAssertEqual(asset.remoteURL(width: 480), "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Letna.jpg/500px-Letna.jpg")
    }

    func testGallerySurvivesSyncAndIsRequestedOnce() throws {
        let identity = ResolvedPlaceIdentity(title: "Letná", latitude: 50.0966, longitude: 14.4165)
        let photo = ExternalPlaceImage(imageURL: "https://x/1.jpg", sourceURL: "https://x", credit: "A", provider: .wikimedia, resolvedFor: identity, ranking: PlaceImageService.ranking)
        var letna = place("letna", 50.0966, 14.4165, category: "Aussicht")
        letna.image = .external(photo)
        XCTAssertTrue(PlaceImageService.needsGallery(letna))
        letna.gallery = [photo]
        XCTAssertFalse(PlaceImageService.needsGallery(letna))
        let decoded = try JSONDecoder().decode(Place.self, from: JSONEncoder().encode(letna))
        XCTAssertEqual(decoded.gallery?.first?.credit, "A")
    }

    func testTimelineGivesTheListTheSameSlotsAsThePlan() {
        let day = [place("a", 50.0880, 14.4030), place("b", 50.0875, 14.4045)]
        let window = DayPlanGenerator.Window(start: 10 * 60, end: 22 * 60)
        let calendar = tripCalendar()
        let stops = DayPlanGenerator.timeline(day, day: calendar.days[0], window: window, start: hotel, calendar: calendar)
        XCTAssertEqual(stops.map(\.id), ["a", "b"])
        XCTAssertEqual(stops.first?.slot, "vormittags")
    }
}
