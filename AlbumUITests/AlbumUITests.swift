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

    /// Rundgang über alle Bildschirme für die Layout-Prüfung. Braucht `TEST_RUNNER_ALBUM_PLAN_STORE` und `TEST_RUNNER_ALBUM_SHOT_DIR`.
    /// Mit `TEST_RUNNER_ALBUM_TODAY` (z. B. 2026-10-06) zeigt er den Stand während der Reise.
    func testScreenTour() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let store = environment["ALBUM_PLAN_STORE"], let dir = environment["ALBUM_SHOT_DIR"] else { throw XCTSkip("Kein Rundgang angefordert") }
        let prefix = environment["ALBUM_SHOT_SUFFIX"] ?? ""
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        if let today = environment["ALBUM_TODAY"] { app.launchEnvironment["ALBUM_TODAY"] = today }
        app.launch()
        func shot(_ name: String) {
            sleep(2)
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(prefix)\(name).png"))
        }
        func openMenu(_ item: String) {
            app.buttons["Mehr"].tap()
            let entry = app.buttons[item]
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            entry.tap()
        }
        XCTAssertTrue(app.buttons["Mehr"].waitForExistence(timeout: 15))
        sleep(6)
        shot("01-reise")
        app.swipeUp(); shot("02-reise-unten")

        app.tabBars.buttons["Ideen"].tap(); shot("03-ideen")

        app.tabBars.buttons["Karte"].tap(); shot("04-karte")
        let details = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Details zu'")).firstMatch
        if details.waitForExistence(timeout: 5) {
            details.tap(); shot("05-ortsdetail")
            app.swipeUp(); shot("06-ortsdetail-unten")
            app.buttons["Bearbeiten"].firstMatch.tap(); shot("07-editor-ort")
            app.buttons["Abbrechen"].tap()
            app.buttons["Fertig"].firstMatch.tap()
        }
        app.buttons["Automatisch planen"].tap()
        XCTAssertTrue(app.buttons["Übernehmen"].waitForExistence(timeout: 5))
        sleep(4); shot("08-vorschlag")
        app.buttons["Abbrechen"].tap()

        app.buttons["Idee hinzufügen"].tap(); shot("09-editor-neu")
        app.buttons["Abbrechen"].tap()

        openMenu("Reiseunterlagen"); shot("10-unterlagen")
        app.swipeUp(); shot("11-unterlagen-unten")
        app.buttons["Fertig"].firstMatch.tap()

        openMenu("Album teilen"); shot("12-teilen")
        app.buttons["Fertig"].firstMatch.tap()
    }
}
