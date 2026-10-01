import XCTest

/// Bewegungsmuster vom 01.10.2026. Alle laufen nur mit Wegwerf-Stores (Kopien von plan-demo, Name beginnt mit `slot-`)
/// und nie gegen die echte Reise. Mit `TEST_RUNNER_ALBUM_SHOT_DIR` liegen Standbilder dort.
final class AlbumMotionUITests: XCTestCase {
    private func launch(_ extra: [String: String] = [:]) throws -> (XCUIApplication, (String) -> Void) {
        let environment = ProcessInfo.processInfo.environment
        guard let store = environment["ALBUM_MOTION_STORE"], store.hasPrefix("slot-") else { throw XCTSkip("Kein Wegwerf-Store (TEST_RUNNER_ALBUM_MOTION_STORE=slot-…)") }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        for (key, value) in extra { app.launchEnvironment[key] = value }
        app.launch()
        let shots = environment["ALBUM_SHOT_DIR"].map { URL(fileURLWithPath: $0) }
        let shot = { (name: String) in
            if let shots { try? XCUIScreen.main.screenshot().pngRepresentation.write(to: shots.appendingPathComponent(name + ".png")) }
        }
        return (app, shot)
    }

    /// C · Einladung einlösen: zu kurz gezogen federt zurück, über der Schwelle startet der (simulierte) Beitritt,
    /// der scheitert zuerst (Karte federt zurück, Text bleibt ruhig), dann klappt es per Knopf.
    func testInvitationMoment() throws {
        let (app, shot) = try launch(["ALBUM_DEMO_INVITE": "failthenok", "ALBUM_DEMO_SENDER": "Mia"])
        let card = app.otherElements["Einladungs-Karte"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        sleep(1); shot("C-1-karte")
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Zu früh losgelassen: nichts passiert, der Knopf bleibt im Ausgangszustand.
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -50)), withVelocity: .slow, thenHoldForDuration: 0)
        XCTAssertTrue(app.buttons["Einladung einlösen"].isEnabled)
        sleep(1)
        // Halb gezogen (Standbild aus dem Hintergrund, während der Finger liegt), dann über der Schwelle losgelassen.
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.2) { shot("C-2-halb") }
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -170)), withVelocity: .slow, thenHoldForDuration: 2)
        // Erster Versuch scheitert: Text ruhig in der Ansicht, kein Alert, Karte wieder da.
        let failure = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'nicht geklappt'")).firstMatch
        XCTAssertTrue(failure.waitForExistence(timeout: 8))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        sleep(1); shot("C-3-fehler")
        XCTAssertTrue(card.exists)
        // Erneut versuchen ohne Ziehen: Der Knopf löst aus.
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.9) { shot("C-4-beitritt") }
        app.buttons["Einladung einlösen"].tap()
        XCTAssertTrue(app.buttons["Album wird geöffnet …"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Album geöffnet"].waitForExistence(timeout: 8))
        sleep(1); shot("C-5-zettel")
        XCTAssertTrue(app.buttons["Album ansehen"].isEnabled)
        app.buttons["Album ansehen"].tap()
        XCTAssertTrue(app.buttons["Idee hinzufügen"].waitForExistence(timeout: 5))
    }

    /// F · Abgleich-Insel: pulsiert während des (simulierten) Abgleichs, wächst mit Neuigkeiten auf, klappt per Tipp zu.
    func testSyncIsland() throws {
        let (app, shot) = try launch(["ALBUM_DEMO_SYNC": "1"])
        XCTAssertTrue(app.buttons["Mehr"].waitForExistence(timeout: 15))
        // Der Abgleich beginnt 2 s nach dem Start, die Kapsel pulsiert ab 0,5 s danach und wächst nach 2 s.
        for index in 0..<12 {
            let delay = 0.4 * Double(index)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { shot("F-1-pulsiert-\(index)") }
        }
        let island = app.descendants(matching: .any).matching(identifier: "Abgleich-Insel").firstMatch
        XCTAssertTrue(island.waitForExistence(timeout: 12))
        shot("F-2-waechst-0")
        usleep(250_000); shot("F-2-waechst-1")
        usleep(900_000); shot("F-3-offen")
        XCTAssertTrue(island.label.contains("Mia hat 2 Ideen eingeworfen"))
        XCTAssertTrue(island.label.contains("1× Ja"))
        island.tap()
        usleep(300_000); shot("F-4-zuklappen")
        sleep(1); shot("F-5-zu")
        // Zugeklappt reagiert die Kapsel nicht mehr auf Tipps.
        XCTAssertFalse(island.isHittable)
    }

    /// B · Foto-Stapel im Ortsdetail: wischen blättert zyklisch, Zähler blättert ohne Geste, Tippen öffnet das Foto groß.
    /// Braucht einen Ort mit drei Fotos; ALBUM_PHOTO_STACK_PLACE wählt ihn im Wegwerf-Store.
    func testPhotoStack() throws {
        let (app, shot) = try launch(["ALBUM_START_TAB": "Karte"])
        let grabber = app.buttons["Liste ausklappen"]
        XCTAssertTrue(grabber.waitForExistence(timeout: 15))
        grabber.tap()
        let photoPlace = ProcessInfo.processInfo.environment["ALBUM_PHOTO_STACK_PLACE"] ?? "Savoy"
        let detail = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Details zu' AND label CONTAINS %@", photoPlace)).firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 8))
        detail.tap()
        let counter = app.buttons["Foto-Zähler"]
        XCTAssertTrue(counter.waitForExistence(timeout: 8))
        let stack = app.otherElements["Foto-Stapel"]
        XCTAssertTrue(stack.exists)
        sleep(4); shot("B-1-stapel")
        XCTAssertTrue(counter.label.contains("1 von"))
        let start = stack.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.4))
        // Zu kurz gewischt: nichts blättert, der Stapel federt zurück.
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.9) { shot("B-2-halb") }
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -60, dy: 0)), withVelocity: .slow, thenHoldForDuration: 2.5)
        sleep(1)
        XCTAssertTrue(counter.label.contains("1 von"))
        // Weit genug: blättert weiter.
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.35) { shot("B-3-fliegt") }
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -170, dy: 0)), withVelocity: 500, thenHoldForDuration: 0)
        sleep(2); shot("B-4-zweites")
        XCTAssertTrue(counter.label.contains("2 von"))
        // Der Zähler blättert ohne Geste, nach dem letzten Foto wieder zum ersten.
        counter.tap(); sleep(1)
        XCTAssertTrue(counter.label.contains("3 von"))
        counter.tap(); sleep(1)
        XCTAssertTrue(counter.label.contains("1 von"))
        // Tippen aufs Foto öffnet es groß, mit Bildnachweis.
        stack.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.4)).tap()
        XCTAssertTrue(app.buttons["Foto schließen"].waitForExistence(timeout: 5))
        sleep(1); shot("B-5-vollbild")
        app.buttons["Foto schließen"].tap()
        XCTAssertTrue(counter.waitForExistence(timeout: 5))
    }

    /// D · Flug wird Bordkarte: Tippen lässt das angeheftete Ticket aufwachsen, Schließen kehrt um.
    func testBoardingPass() throws {
        let (app, shot) = try launch()
        XCTAssertTrue(app.buttons["Mehr"].waitForExistence(timeout: 15))
        sleep(4)
        app.swipeUp(); sleep(1)
        let ticket = app.descendants(matching: .any).matching(identifier: "Flug-Ticket").firstMatch
        XCTAssertTrue(ticket.waitForExistence(timeout: 5))
        shot("D-1-ticket")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.12) { shot("D-2-waechst") }
        ticket.tap()
        let close = app.buttons["Bordkarte schließen"]
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        sleep(2); shot("D-3-bordkarte")
        XCTAssertTrue(app.staticTexts["EW4241"].exists || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'EW4241'")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Reiseunterlagen"].exists)
        close.tap(); sleep(2)
        XCTAssertFalse(close.exists)
        shot("D-4-zu")
    }

    /// E · Als besucht markieren: zu früh losgelassen federt zurück, über der Schwelle rastet es ein, der Stempel landet.
    func testVisitedTrack() throws {
        let (app, shot) = try launch(["ALBUM_START_TAB": "Karte"])
        let grabber = app.buttons["Liste ausklappen"]
        XCTAssertTrue(grabber.waitForExistence(timeout: 15))
        grabber.tap()
        let savoy = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Details zu' AND label CONTAINS 'Savoy'")).firstMatch
        XCTAssertTrue(savoy.waitForExistence(timeout: 8))
        savoy.tap()
        let track = app.descendants(matching: .any).matching(identifier: "Besucht-Spur").firstMatch
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        sleep(2); shot("E-1-spur")
        let start = track.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        // Zu früh losgelassen: federt zurück, nichts ist besucht.
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.4) { shot("E-2-halb") }
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 120, dy: 0)), withVelocity: .slow, thenHoldForDuration: 2.5)
        sleep(1)
        XCTAssertEqual(track.label, "Als besucht markieren")
        // Über der Schwelle: das Label rastet ein, beim Loslassen ist der Ort besucht.
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.6) { shot("E-3-eingerastet") }
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 330, dy: 0)), withVelocity: .slow, thenHoldForDuration: 2.5)
        let done = expectation(for: NSPredicate(format: "label == 'Besucht'"), evaluatedWith: track)
        wait(for: [done], timeout: 5)
        sleep(2); shot("E-4-besucht")
    }
}
