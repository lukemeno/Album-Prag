import XCTest
import UIKit

final class AlbumUITests: XCTestCase {
    func testSelectTravelDay() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let store = environment["ALBUM_PLAN_STORE"], store.hasPrefix("slot-") else {
            throw XCTSkip("Kein Wegwerf-Tagesplan angefordert")
        }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_TODAY"] = "2026-10-06"
        app.launch()
        func shot(_ name: String) {
            guard let dir = environment["ALBUM_SHOT_DIR"] else { return }
            let prefix = environment["ALBUM_SHOT_SUFFIX"] ?? ""
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(prefix + name + ".png"))
        }
        let firstDay = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sonntag, 4.'")).firstMatch
        XCTAssertTrue(firstDay.waitForExistence(timeout: 15))
        shot("13-tagesauswahl")
        firstDay.tap()
        XCTAssertTrue(app.staticTexts["Noch nichts geplant"].waitForExistence(timeout: 5))
        let plannedRoute = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Route zu'")).firstMatch
        XCTAssertFalse(plannedRoute.exists)
        let today = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Dienstag, 6.'")).firstMatch
        today.tap()
        XCTAssertTrue(plannedRoute.waitForExistence(timeout: 5))
        app.tabBars.buttons["Ideen"].tap()
        XCTAssertTrue(app.buttons["Offen"].waitForExistence(timeout: 5))
        shot("14-ideen-layout")
        app.tabBars.buttons["Karte"].tap()
        XCTAssertTrue(app.buttons["Tage planen"].waitForExistence(timeout: 5))
        shot("15-karte-layout")
    }

    func testOpenIdeasRemainUndecidedAfterRelaunch() {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "ui-" + UUID().uuidString
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launch()
        app.buttons["Ideen"].tap()
        for _ in 0..<3 {
            let open = app.buttons["Offen"]
            XCTAssertTrue(open.waitForExistence(timeout: 5))
            open.tap()
        }
        XCTAssertTrue(app.staticTexts["Noch offen"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.buttons["Ideen"].tap()
        XCTAssertTrue(app.otherElements["Inbox-Ticket"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Offen"].exists)
        XCTAssertFalse(app.staticTexts["Alles entschieden"].exists)
    }

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
        XCTAssertTrue(app.buttons["Nein"].waitForExistence(timeout: 5))
        let ticket = app.otherElements["Inbox-Ticket"]
        XCTAssertTrue(ticket.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Offen"].exists)
        app.buttons["Offen"].tap()
        XCTAssertTrue(app.buttons["Letzte Entscheidung rückgängig"].waitForExistence(timeout: 5))
        app.buttons["Letzte Entscheidung rückgängig"].tap()
        ticket.swipeLeft()
        XCTAssertTrue(app.buttons["Letzte Entscheidung rückgängig"].waitForExistence(timeout: 5))
        for _ in 0..<2 { app.buttons["Nein"].tap() }
        XCTAssertTrue(app.buttons["Idee bearbeiten"].waitForExistence(timeout: 5))
        app.terminate(); app.launch(); app.buttons["Ideen"].tap()
        XCTAssertTrue(app.buttons["Idee bearbeiten"].waitForExistence(timeout: 5))
        app.buttons["Nein"].tap()
        XCTAssertTrue(app.buttons["Letzte Entscheidung rückgängig"].exists)
        app.buttons["Letzte Entscheidung rückgängig"].tap()
        app.buttons["Karte"].tap()
        XCTAssertTrue(app.navigationBars["Karte"].waitForExistence(timeout: 5))
    }

    /// Briefkasten per Finger: erst zu kurz gezogen (Feder zurück), dann eingeworfen, danach eine zweite Idee per Knopf.
    /// Läuft nur mit einem Wegwerf-Store (`TEST_RUNNER_ALBUM_SLOT_STORE`, Name beginnt mit `slot-`); speichert dort echte Ideen.
    /// Mit `TEST_RUNNER_ALBUM_SHOT_DIR` liegen Standbilder dort.
    func testLetterSlotThrow() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let store = environment["ALBUM_SLOT_STORE"], store.hasPrefix("slot-") else { throw XCTSkip("Kein Wegwerf-Store für den Einwurf") }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launch()
        let shots = environment["ALBUM_SHOT_DIR"].map { URL(fileURLWithPath: $0) }
        func shot(_ name: String) { if let shots { try? XCUIScreen.main.screenshot().pngRepresentation.write(to: shots.appendingPathComponent(name + ".png")) } }
        func newIdea(_ name: String) {
            XCTAssertTrue(app.buttons["Idee hinzufügen"].waitForExistence(timeout: 15))
            app.buttons["Idee hinzufügen"].tap()
            let title = app.textFields["Name der Idee"]
            XCTAssertTrue(title.waitForExistence(timeout: 5))
            title.tap(); title.typeText(name)
            app.buttons["Speichern"].tap()
        }

        newIdea("Café Slavia")
        let card = app.otherElements["Einwurf-Karte"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        sleep(1); shot("A-1-idle")
        // Zu früh losgelassen: die Karte federt zurück, der Knopf bleibt im Ausgangszustand.
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -50)), withVelocity: .slow, thenHoldForDuration: 0)
        XCTAssertTrue(app.buttons["Nach oben einwerfen"].isEnabled)
        XCTAssertTrue(card.exists)
        sleep(1)
        // Halb gezogen (Standbild aus dem Hintergrund, während der Finger liegt), dann über der Schwelle losgelassen.
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.2) { shot("A-2-halb") }
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -150)), withVelocity: .slow, thenHoldForDuration: 2)
        XCTAssertTrue(app.staticTexts["Liegt bei Ideen"].waitForExistence(timeout: 5))
        usleep(700_000); shot("A-3-zettel")
        XCTAssertTrue(app.buttons["Eingeworfen"].exists)
        XCTAssertFalse(app.buttons["Eingeworfen"].isEnabled)
        // Danach schließt der Editor wie bisher.
        XCTAssertTrue(app.buttons["Idee hinzufügen"].waitForExistence(timeout: 6))

        // Gleichwertige Schaltfläche: Tippen wirft von selbst ein.
        newIdea("Petřín")
        let button = app.buttons["Nach oben einwerfen"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.staticTexts["Liegt bei Ideen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Idee hinzufügen"].waitForExistence(timeout: 6))

        // Beide Ideen sind gespeichert, auch wenn sie nur über die Schaltfläche oder gar nicht eingeworfen wurden.
        app.terminate(); app.launch()
        app.buttons["Ideen"].tap()
        XCTAssertTrue(app.staticTexts["Café Slavia"].waitForExistence(timeout: 5) || app.staticTexts["Petřín"].waitForExistence(timeout: 5))
    }

    /// Ideen-Stapel: Auffächern, Anheben mit Neigung, Füllung und Label, Foto im Vollbild, Entscheiden.
    /// Läuft nur mit einem Wegwerf-Store mit offenen Ideen (`TEST_RUNNER_ALBUM_INBOX_STORE`, Name beginnt mit `slot-`); entscheidet dort echte Ideen.
    /// Mit `TEST_RUNNER_ALBUM_SHOT_DIR` liegen Standbilder dort.
    func testInboxStack() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let store = environment["ALBUM_INBOX_STORE"], store.hasPrefix("slot-") else { throw XCTSkip("Kein Wegwerf-Store mit offenen Ideen") }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Ideen"
        app.launch()
        let shots = environment["ALBUM_SHOT_DIR"].map { URL(fileURLWithPath: $0) }
        func shot(_ name: String) { if let shots { try? XCUIScreen.main.screenshot().pngRepresentation.write(to: shots.appendingPathComponent(name + ".png")) } }
        func later(_ seconds: Double, _ name: String) { DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { shot(name) } }

        let ticket = app.otherElements["Inbox-Ticket"]
        XCTAssertTrue(ticket.waitForExistence(timeout: 15))
        sleep(2); shot("B-1-stapel")

        // Foto groß: Tippen öffnet, halb nach unten ziehen federt zurück, der Knopf schließt.
        let photoButton = app.buttons["Foto vergrößern"]
        XCTAssertTrue(photoButton.waitForExistence(timeout: 5))
        photoButton.tap()
        XCTAssertTrue(app.buttons["Foto schließen"].waitForExistence(timeout: 5))
        sleep(1); shot("B-4-vollbild")
        let middle = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.46))
        later(1.0, "B-5-halb-zu")
        middle.press(forDuration: 0.05, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: 80)), withVelocity: .slow, thenHoldForDuration: 1.5)
        XCTAssertTrue(app.buttons["Foto schließen"].exists)
        app.buttons["Foto schließen"].tap()
        XCTAssertTrue(ticket.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Foto schließen"].waitForExistence(timeout: 1))
        sleep(1)

        // Unter der Schwelle losgelassen: Feder zurück, nichts entschieden.
        let start = ticket.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        later(0.25, "B-2a-ziehen"); later(0.45, "B-2b-ziehen")
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 70, dy: 0)), withVelocity: 250, thenHoldForDuration: 1.2)
        XCTAssertTrue(ticket.waitForExistence(timeout: 5))
        sleep(1)
        // Über der Schwelle: Label rastet ein, beim Loslassen ist „Ja“ entschieden.
        later(1.0, "B-3-eingerastet")
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 140, dy: 0)), withVelocity: 900, thenHoldForDuration: 1.5)
        XCTAssertTrue(app.buttons["Letzte Entscheidung rückgängig"].waitForExistence(timeout: 5))
        sleep(2); shot("B-6-nach-entscheid")
        app.buttons["Nein"].tap()
        XCTAssertTrue(app.buttons["Letzte Entscheidung rückgängig"].waitForExistence(timeout: 5))
    }

    /// Namensabfrage mit getipptem Namen. Braucht `TEST_RUNNER_ALBUM_SHOT_DIR`; „Los geht’s“ wird nie getippt.
    func testNamePromptStitch() throws {
        guard let dir = ProcessInfo.processInfo.environment["ALBUM_SHOT_DIR"] else { throw XCTSkip("Kein Standbild angefordert") }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "ui-" + UUID().uuidString
        app.launchArguments += ["-album.myName", ""]
        app.launch()
        let field = app.textFields["Vorname"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        sleep(1)
        field.tap(); field.typeText("Mathilde")
        sleep(1)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("C-nameprompt.png"))
        XCTAssertEqual(field.value as? String, "Mathilde")
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
        let auto = app.buttons["Tage planen"].firstMatch
        XCTAssertTrue(auto.waitForExistence(timeout: 15))
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
        let rowID = environment["ALBUM_MAP_ROW_ID"] ?? "lokal"
        let row = app.buttons["place-row-\(rowID)"]
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
        let close = app.buttons["Schließen"].firstMatch
        XCTAssertTrue(app.buttons["Idee einwerfen"].firstMatch.waitForExistence(timeout: 15))
        sleep(4)
        shot("01-reise")
        app.swipeUp(); shot("02-reise-unten")
        let ticket = app.buttons["Flug-Ticket"].firstMatch
        if ticket.exists { ticket.tap(); shot("02b-bordkarte"); ticket.tap() }
        app.swipeDown(); app.swipeDown()

        app.tabBars.buttons["Ideen"].tap(); shot("03-ideen")

        app.tabBars.buttons["Karte"].tap(); shot("04-karte")
        let details = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Details zu'")).firstMatch
        if details.waitForExistence(timeout: 5) {
            details.tap(); shot("05-ortsdetail")
            app.swipeUp(); shot("06-ortsdetail-unten")
            app.buttons["Bearbeiten"].firstMatch.tap(); shot("07-editor-ort")
            app.swipeUp(); shot("07b-editor-unten")
            app.buttons["Abbrechen"].tap()
            close.tap()
        }
        app.buttons["Tage planen"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Übernehmen"].waitForExistence(timeout: 5))
        sleep(4); shot("08-vorschlag")
        app.buttons["Abbrechen"].tap()

        app.buttons["Idee einwerfen"].firstMatch.tap(); shot("09-editor-neu")
        app.buttons["Abbrechen"].tap()

        app.tabBars.buttons["Reise"].tap()
        app.swipeUp()
        app.buttons["Alle Reiseunterlagen"].firstMatch.tap(); shot("10-unterlagen")
        app.swipeUp(); shot("11-unterlagen-unten")
        close.tap()
        app.swipeDown(); app.swipeDown()

        let share = app.buttons["Jemanden einladen"].exists ? app.buttons["Jemanden einladen"] : app.buttons["Gemeinsames Album"]
        share.firstMatch.tap(); shot("12-teilen")
        close.tap()
    }
}
