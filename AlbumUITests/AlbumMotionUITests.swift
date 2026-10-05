import XCTest

/// Bewegungsmuster vom 01.10.2026. Fixture-abhängige Tests laufen nur mit einem isolierten vorbereiteten Store.
final class AlbumMotionUITests: XCTestCase {
    private var reduceMotionRequested: Bool {
        ProcessInfo.processInfo.environment["ALBUM_QA_REDUCE_MOTION"] == "1"
    }

    private func launch(_ extra: [String: String] = [:], allowEmptyStore: Bool = false) throws -> (XCUIApplication, (String) -> Void) {
        let environment = ProcessInfo.processInfo.environment
        let configuredStore = environment["ALBUM_MOTION_STORE"]
        let store: String
        if let configuredStore {
            guard configuredStore.hasPrefix("slot-") else {
                throw XCTSkip("Der Motion-Test benötigt einen isolierten Store mit Präfix slot-.")
            }
            store = configuredStore
        } else if allowEmptyStore {
            store = "slot-motion-\(UUID().uuidString)"
        } else {
            throw XCTSkip("Der Motion-Test benötigt einen vorbereiteten, isolierten Store mit Präfix slot-.")
        }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        for (key, value) in extra { app.launchEnvironment[key] = value }
        let reduceMotionFlag = environment["ALBUM_QA_REDUCE_MOTION"] ?? "missing"
        XCTAssertTrue(["1", "0", "missing"].contains(reduceMotionFlag), "ALBUM_QA_REDUCE_MOTION muss 1, 0 oder missing sein")
        if reduceMotionFlag != "missing" { app.launchEnvironment["ALBUM_QA_REDUCE_MOTION"] = reduceMotionFlag }
        let reduceMotionRequested = reduceMotionFlag == "1"
        let startupMarker = XCTAttachment(string: "motion-runtime-20261002-v2; ALBUM_QA_REDUCE_MOTION=\(reduceMotionFlag); ALBUM_TEST_STORE=slot-*")
        startupMarker.name = "Motion runtime revision"
        startupMarker.lifetime = .keepAlways
        add(startupMarker)
        print("motion-runtime-20261002-v2; ALBUM_QA_REDUCE_MOTION=\(reduceMotionFlag); ALBUM_TEST_STORE=slot-*")
        app.launch()
        if reduceMotionRequested {
            let root = app.descendants(matching: .any).matching(identifier: "qa-reduce-motion-root").firstMatch
            XCTAssertTrue(root.waitForExistence(timeout: 15), "Der isolierte Root muss die reduzierte SwiftUI-Umgebung über seine QA-ID belegen")
        }
        let shots = environment["ALBUM_SHOT_DIR"].map { URL(fileURLWithPath: $0) }
        let shot = { (name: String) in
            if let shots { try? XCUIScreen.main.screenshot().pngRepresentation.write(to: shots.appendingPathComponent(name + ".png")) }
        }
        return (app, shot)
    }

    /// C · Einladung einlösen: zu kurz gezogen federt zurück, über der Schwelle startet der (simulierte) Beitritt,
    /// der scheitert zuerst (Karte federt zurück, Text bleibt ruhig), dann klappt es per Knopf.
    func testInvitationMoment() throws {
        let (app, shot) = try launch(["ALBUM_DEMO_INVITE": "failthenok", "ALBUM_DEMO_SENDER": "Mia"], allowEmptyStore: true)
        let card = app.otherElements["Einladungs-Karte"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        if reduceMotionRequested {
            let redeem = app.buttons["Einladung einlösen"]
            XCTAssertTrue(redeem.waitForExistence(timeout: 5))
            XCTAssertTrue(redeem.isEnabled)
            redeem.tap()
            let failure = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'nicht geklappt'")).firstMatch
            XCTAssertTrue(failure.waitForExistence(timeout: 8), "Der reduzierte Slot muss den ersten fehlgeschlagenen Einlöseversuch sichtbar melden")
            XCTAssertTrue(card.exists)
            XCTAssertTrue(redeem.isEnabled)
            redeem.tap()
        } else {
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
        }
        XCTAssertTrue(app.buttons["Album wird geöffnet …"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Album geöffnet"].waitForExistence(timeout: 8))
        sleep(1); shot("C-5-zettel")
        XCTAssertTrue(app.buttons["Album ansehen"].isEnabled)
        app.buttons["Album ansehen"].tap()
        XCTAssertTrue(app.tabBars.buttons["Reise"].waitForExistence(timeout: 5))
    }

    /// F · Abgleich-Insel: pulsiert während des (simulierten) Abgleichs, wächst mit Neuigkeiten auf, klappt per Tipp zu.
    func testSyncIsland() throws {
        let (app, shot) = try launch(["ALBUM_DEMO_SYNC": "1"], allowEmptyStore: true)
        XCTAssertTrue(app.tabBars.buttons["Reise"].waitForExistence(timeout: 15))
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
        // Die Insel klappt nach 5 s von selbst zu. Jede Abfrage und ein Bildschirmfoto kosten in der Cloud
        // bis zu einer Sekunde; deshalb Werte einmal lesen, sofort tippen und erst danach prüfen.
        let label = island.label
        let height = island.frame.height
        island.tap()
        XCTAssertTrue(label.contains("Mia hat 2 Ideen eingeworfen"))
        XCTAssertTrue(label.contains("1× Ja"))
        XCTAssertGreaterThanOrEqual(height, 44, "Die geöffnete Abgleich-Insel bleibt mindestens 44 Punkte hoch")
        usleep(300_000); shot("F-4-zuklappen")
        sleep(1); shot("F-5-zu")
        // Zugeklappt reagiert die Kapsel nicht mehr auf Tipps.
        XCTAssertFalse(island.isHittable)
    }

    /// B · Foto-Stapel: Er lebt in den Erinnerungen (das Ortsdetail zeigt Fotos als Streifen).
    /// Wischen blättert zyklisch, der Zähler blättert ohne Geste, Tippen öffnet das Foto groß.
    /// Der Demo-Rückblick liefert Letná mit zwei Fotos.
    func testPhotoStack() throws {
        let (app, shot) = try launch(["ALBUM_TODAY": "2026-10-10", "ALBUM_DEMO_MEMORIES": "1"], allowEmptyStore: true)
        let memories = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Erinnerungen ansehen'")).firstMatch
        XCTAssertTrue(memories.waitForExistence(timeout: 15))
        memories.tap()
        let counter = app.buttons["Foto-Zähler"].firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 8))
        let stack = app.otherElements["Foto-Stapel"].firstMatch
        XCTAssertTrue(stack.exists)
        sleep(2); shot("B-1-stapel")
        XCTAssertTrue(counter.label.contains("1 von 2"))
        if reduceMotionRequested {
            // Reduced Motion disables the PhotoStack gesture; the counter is the supported equivalent.
            counter.tap(); sleep(1)
            XCTAssertTrue(counter.label.contains("2 von 2"))
            counter.tap(); sleep(1)
            XCTAssertTrue(counter.label.contains("1 von 2"))
        } else {
            let start = stack.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.4))
            // Zu kurz gewischt: nichts blättert, der Stapel federt zurück.
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.9) { shot("B-2-halb") }
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -60, dy: 0)), withVelocity: .slow, thenHoldForDuration: 2.5)
            sleep(1)
            XCTAssertTrue(counter.label.contains("1 von 2"))
            // Weit genug: blättert weiter.
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.35) { shot("B-3-fliegt") }
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -170, dy: 0)), withVelocity: 500, thenHoldForDuration: 0)
            sleep(2); shot("B-4-zweites")
            XCTAssertTrue(counter.label.contains("2 von 2"))
            // Der Zähler blättert ohne Geste, nach dem letzten Foto wieder zum ersten.
            counter.tap(); sleep(1)
            XCTAssertTrue(counter.label.contains("1 von 2"))
        }
        // Tippen aufs Foto öffnet es groß, mit Bildnachweis.
        stack.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.4)).tap()
        XCTAssertTrue(app.buttons["Foto schließen"].waitForExistence(timeout: 5))
        sleep(1); shot("B-5-vollbild")
        app.buttons["Foto schließen"].tap()
        XCTAssertTrue(counter.waitForExistence(timeout: 5))
    }

    /// D · Flug wird Bordkarte: Tippen lässt das angeheftete Ticket aufwachsen, Schließen kehrt um.
    func testBoardingPass() throws {
        let (app, shot) = try launch(["ALBUM_DEMO_MOTION": "1"], allowEmptyStore: true)
        XCTAssertTrue(app.tabBars.buttons["Reise"].waitForExistence(timeout: 15))
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
        XCTAssertTrue(app.buttons["Unterlagen öffnen"].exists)
        close.tap(); sleep(2)
        XCTAssertFalse(close.exists)
        shot("D-4-zu")
    }

    /// E · Als besucht markieren: zu früh losgelassen federt zurück, über der Schwelle rastet es ein, der Stempel landet.
    func testVisitedTrack() throws {
        let (app, shot) = try launch(["ALBUM_START_TAB": "Karte", "ALBUM_DEMO_MOTION": "1"], allowEmptyStore: true)
        let grabber = app.buttons["Liste ausklappen"]
        XCTAssertTrue(grabber.waitForExistence(timeout: 15))
        grabber.tap()
        let savoy = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Details zu' AND label CONTAINS 'Savoy'")).firstMatch
        XCTAssertTrue(savoy.waitForExistence(timeout: 8))
        savoy.tap()
        let track = app.descendants(matching: .any).matching(identifier: "Besucht-Spur").firstMatch
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        sleep(2); shot("E-1-spur")
        if reduceMotionRequested {
            XCTAssertEqual(track.label, "Als besucht markieren")
            track.tap()
            let done = expectation(for: NSPredicate(format: "label == 'Besucht'"), evaluatedWith: track)
            wait(for: [done], timeout: 5)
            XCTAssertEqual(track.label, "Besucht")
            shot("E-4-besucht")
            return
        }
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
