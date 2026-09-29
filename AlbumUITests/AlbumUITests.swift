import XCTest
import UIKit

final class AlbumUITests: XCTestCase {
    func testCreateIdeaAndPersistence() {
        UIPasteboard.general.items = [] // keine Reste früherer Läufe
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "ui-" + UUID().uuidString
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launch()
        XCTAssertTrue(app.buttons["Idee hinzufügen"].waitForExistence(timeout: 15))
        app.buttons["Idee hinzufügen"].tap()
        let title = app.textFields["Name der Idee"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Unser Testcafe")
        app.buttons["Speichern"].tap()
        app.terminate(); app.launch()
        app.buttons["Ideen"].tap()
        XCTAssertTrue(app.buttons["Später"].waitForExistence(timeout: 5))
        let ticket = app.otherElements["Inbox-Ticket"]
        XCTAssertTrue(ticket.waitForExistence(timeout: 5))
        ticket.swipeLeft()
        XCTAssertTrue(app.buttons["Letzte Entscheidung rückgängig"].waitForExistence(timeout: 5))
        for _ in 0..<2 { app.buttons["Später"].tap() }
        XCTAssertTrue(app.buttons["Idee bearbeiten"].waitForExistence(timeout: 5))
        app.terminate(); app.launch(); app.buttons["Ideen"].tap()
        XCTAssertTrue(app.buttons["Idee bearbeiten"].waitForExistence(timeout: 5))
        app.buttons["Später"].tap()
        XCTAssertTrue(app.buttons["Letzte Entscheidung rückgängig"].exists)
        app.buttons["Letzte Entscheidung rückgängig"].tap()
        app.buttons["Karte"].tap()
        XCTAssertTrue(app.navigationBars["Karte"].waitForExistence(timeout: 5))
    }

    /// Braucht vorbereitete Orte im Simulator (`TEST_RUNNER_ALBUM_PLAN_STORE`) und Netz für die Öffnungszeiten.
    /// Mit `TEST_RUNNER_ALBUM_SHOT_DIR` werden Screenshots der Vorschau dort abgelegt.
    func testAutomaticDayPlanPreview() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let store = environment["ALBUM_PLAN_STORE"] else { throw XCTSkip("Keine vorbereiteten Orte") }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launch()
        XCTAssertTrue(app.buttons["Mehr"].waitForExistence(timeout: 15))
        app.buttons["Mehr"].tap()
        // Das Menü klappt animiert auf; erst tippen, wenn der Eintrag da ist.
        let planner = app.buttons["Tagesplan"]
        XCTAssertTrue(planner.waitForExistence(timeout: 5))
        planner.tap()
        let auto = app.buttons["Automatisch planen"]
        XCTAssertTrue(auto.waitForExistence(timeout: 10))
        auto.tap()
        let apply = app.buttons["Übernehmen"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5))
        let ready = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: apply)
        wait(for: [ready], timeout: 90)
        let shots = environment["ALBUM_SHOT_DIR"].map { URL(fileURLWithPath: $0) }
        func shot(_ name: String) { if let shots { try? XCUIScreen.main.screenshot().pngRepresentation.write(to: shots.appendingPathComponent(name + ".png")) } }
        shot("plan-1")
        app.swipeUp(); shot("plan-2")
        app.swipeUp(); shot("plan-3")
        apply.tap()
        // Der Tagesplan lebt jetzt in der Liste auf der Karte.
        XCTAssertTrue(app.navigationBars["Karte"].waitForExistence(timeout: 5))
        shot("plan-applied")
    }

    /// Karte mit Liste in allen Höhen. Braucht vorbereitete Orte (`TEST_RUNNER_ALBUM_PLAN_STORE`).
    func testMapListHeightsAndSelection() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let store = environment["ALBUM_PLAN_STORE"] else { throw XCTSkip("Keine vorbereiteten Orte") }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Karte"
        app.launch()
        let shots = environment["ALBUM_SHOT_DIR"].map { URL(fileURLWithPath: $0) }
        let suffix = environment["ALBUM_SHOT_SUFFIX"] ?? ""
        func shot(_ name: String) { if let shots { try? XCUIScreen.main.screenshot().pngRepresentation.write(to: shots.appendingPathComponent(name + suffix + ".png")) } }

        let grabber = app.buttons["Liste ausklappen"]
        XCTAssertTrue(grabber.waitForExistence(timeout: 15))
        sleep(8) // Fotos laden
        shot("map-half")
        grabber.tap()
        XCTAssertTrue(app.buttons["Liste einklappen"].waitForExistence(timeout: 5))
        sleep(2)
        shot("map-full")
        // Ort in der Liste antippen: Die Karte fliegt hin, die Liste gibt die Karte frei.
        let row = app.buttons["place-row-lokal"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap(); sleep(3); shot("map-selected")
        app.buttons["Liste ausklappen"].swipeDown(velocity: .fast)
        sleep(2)
        shot("map-collapsed")
    }
}
