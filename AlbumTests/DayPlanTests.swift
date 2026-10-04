import XCTest
import CoreLocation
@testable import Album

final class DayPlanTests: XCTestCase {
    private let hotel = CLLocationCoordinate2D(latitude: 50.0898, longitude: 14.4318)

    private func place(_ id: String, _ lat: Double, _ lng: Double, category: String = "Sehenswert", hours: String? = "", day: Int? = nil) -> Place {
        var place = Place(id: id, title: id, category: category, lat: lat, lng: lng, franked: true, day: day)
        place.openingHours = hours
        return place
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

    func testNearbyPlacesShareADay() {
        // Kleinseite und Vinohrady, je drei Orte.
        let lesser = [place("a1", 50.0880, 14.4030), place("a2", 50.0875, 14.4045), place("a3", 50.0890, 14.4010)]
        let vinohrady = [place("b1", 50.0755, 14.4400), place("b2", 50.0760, 14.4420), place("b3", 50.0748, 14.4385)]
        let proposal = DayPlanGenerator.plan(places: lesser + vinohrady, hotel: hotel)
        let dayOf = { (id: String) in proposal.days.first { $0.value.contains { $0.id == id } }?.key }
        XCTAssertEqual(Set(lesser.map { dayOf($0.id) }).count, 1)
        XCTAssertEqual(Set(vinohrady.map { dayOf($0.id) }).count, 1)
        XCTAssertNotEqual(dayOf("a1"), dayOf("b1"))
        XCTAssertTrue(proposal.leftOver.isEmpty)
    }

    func testClosedDaysAreAvoided() {
        // 5. Oktober 2026 ist ein Montag.
        XCTAssertEqual(DayPlanGenerator.weekday(5), 0)
        let museum = place("museum", 50.0870, 14.4200, hours: "Tu-Su 10:00-18:00; Mo off")
        let proposal = DayPlanGenerator.plan(places: [museum], hotel: hotel)
        XCTAssertFalse(proposal.days[5]?.contains { $0.id == "museum" } ?? false)
    }

    func testFlightDaysAreShort() {
        let flights = [
            FlightLeg(direction: .outbound, number: "EW4241", from: "CGN", to: "PRG", date: "04.10.2026", departure: "14:45", arrival: "15:55"),
            FlightLeg(direction: .inbound, number: "EW773", from: "PRG", to: "CGN", date: "09.10.2026", departure: "12:20", arrival: "13:35"),
        ]
        let windows = DayPlanGenerator.windows(flights: flights)
        XCTAssertEqual(windows[4]?.start, 15 * 60 + 55 + 90)
        XCTAssertEqual(windows[9]?.end, 12 * 60 + 20 - 165)
        XCTAssertLessThan(windows[9]!.minutes, windows[6]!.minutes)
    }

    func testRouteVisitsPointsOnALineInOrder() {
        let line = [place("far", 50.0898, 14.4018), place("near", 50.0898, 14.4218), place("mid", 50.0898, 14.4118)]
        XCTAssertEqual(DayPlanGenerator.route(line, from: hotel).map(\.id), ["near", "mid", "far"])
    }

    func testAssignedPlacesStayUnlessReplanned() {
        let fixed = place("fixed", 50.0755, 14.4400, day: 7)
        XCTAssertTrue(DayPlanGenerator.plan(places: [fixed], hotel: hotel).days[7]!.contains { $0.id == "fixed" })
        let replanned = DayPlanGenerator.plan(places: [fixed], hotel: hotel, keepAssigned: false)
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
        let proposal = DayPlanGenerator.plan(places: cafes, hotel: hotel)
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

    func testLargeWikimediaPhotosUseAnAllowedWidth() {
        // Ideenkarte, Ortsdetail und Vollbild fragen ohne eigene Breite an; 1600 px liefert Wikimedia nicht aus.
        let legacy = PlaceImageAsset.external(ExternalPlaceImage(
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Letna.jpg/1600px-Letna.jpg",
            sourceURL: "https://commons.wikimedia.org/wiki/File:Letna.jpg", credit: "x", provider: .legacy))
        XCTAssertEqual(legacy.remoteURL(width: AlbumPhoto.fullWidth), "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Letna.jpg/1280px-Letna.jpg")
        let other = PlaceImageAsset.external(ExternalPlaceImage(
            imageURL: "https://example.com/1600px-photo.jpg", sourceURL: "https://example.com", credit: "x", provider: .legacy))
        XCTAssertEqual(other.remoteURL(width: AlbumPhoto.fullWidth), "https://example.com/1600px-photo.jpg")
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
        let stops = DayPlanGenerator.timeline(day, day: 6, window: window, hotel: hotel)
        XCTAssertEqual(stops.map(\.id), ["a", "b"])
        XCTAssertEqual(stops.first?.slot, "vormittags")
    }
}
