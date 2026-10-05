import XCTest
import UIKit

final class AlbumUITests: XCTestCase {
    func testLiveSourcePhotoAndLinksOnIdeaCard() throws {
        guard ProcessInfo.processInfo.environment["ALBUM_LIVE_SOURCE_PHOTO"] == "1" else {
            throw XCTSkip("Live-Quellenbildprüfung benötigt ALBUM_LIVE_SOURCE_PHOTO=1")
        }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-photo-source"
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_QA_APPEARANCE"] = "dark"
        app.launchEnvironment["ALBUM_IMAGE_RESPONSE_BASE64"] = "eyJpbWFnZSI6bnVsbCwiY2FuZGlkYXRlcyI6W10sInNlbGVjdGlvbl92ZXJzaW9uIjozfQ=="
        app.launchEnvironment["ALBUM_DISABLE_LOOK_AROUND"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["Ideen"].waitForExistence(timeout: 10))
        app.buttons["Ideen"].tap()
        XCTAssertTrue(app.buttons["idea-source-link"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["idea-source-link"].isHittable)
        XCTAssertTrue(app.buttons["idea-map-link"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["place-photo-loaded"].waitForExistence(timeout: 45), "Das Quellenbild muss von der echten Ortsseite geladen werden")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Speculum-live-source-photo-links"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMissingSeedPhotoShowsLocationFallback() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-photo-fallback-\(UUID().uuidString)"
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_DEMO_PHOTO_FALLBACK"] = "1"
        app.launchEnvironment["ALBUM_IMAGE_RESPONSE_BASE64"] = "eyJpbWFnZSI6bnVsbCwiY2FuZGlkYXRlcyI6W10sInNlbGVjdGlvbl92ZXJzaW9uIjozfQ=="
        app.launchEnvironment["ALBUM_DISABLE_LOOK_AROUND"] = "1"
        app.launchArguments += ["-AppleInterfaceStyle", "Dark"]
        app.launch()
        XCTAssertTrue(app.buttons["Ideen"].waitForExistence(timeout: 10))
        app.buttons["Ideen"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Speculum Alchemiae")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Apple Karten")).firstMatch.waitForExistence(timeout: 40))
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Speculum-location-fallback"
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["ALBUM_SHOT_DIR"] {
            try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: directory).appendingPathComponent("speculum-fallback.png"))
        }
    }

    /// Apple's full-screen audit is intentionally opt-in; it takes minutes and can trigger simulator diagnostics.
    func auditAccessibilityWhenEnabled(_ app: XCUIApplication, screen: String) throws {
        guard ProcessInfo.processInfo.environment["ALBUM_RUN_ACCESSIBILITY_AUDITS"] == "1" else { return }
        print("Running Apple Accessibility Audit: \(screen)")
        try auditAccessibility(app, screen: screen)
    }

    func auditAccessibility(_ app: XCUIApplication, screen: String, file: StaticString = #filePath, line: UInt = #line) throws {
        var findings: [String] = []
        var unsuppressedCount = 0
        var auditError: Error?
        do {
            try app.performAccessibilityAudit { issue in
            let element = issue.element
            let suppressed: Bool
            // MapKit owns this required legal link; its compact attribution cannot be resized by the app.
            let mapAttribution = issue.compactDescription.hasPrefix("Hit area is too small")
                && element?.label == "Rechtl. Informationen"
                && issue.detailedDescription.contains("MKAttributionLabel")
            // Verified in Stitch.swift: ink (28,25,21) on card (251,248,242) is 16.5:1.
            // XCTest occasionally attributes a contrast failure to this custom-font label anyway.
            let measuredHotelContrastFalsePositive = issue.compactDescription.hasPrefix("Contrast failed")
                && element?.label == "Hotel Urban Crème"
            // Decorative stamps and the rear, non-interactive marks in the fan are purposefully fixed-size.
            let decorativeStamp = (issue.compactDescription.contains("Dynamic Type") || issue.compactDescription == "Text clipped")
                && ["PRAHA", "FRANKIERT", "Essen & Trinken", "Sehenswert"].contains(element?.label ?? "")
            // This status is hidden from VoiceOver and exposed through the parent only when expanded.
            let collapsedSyncLabel = (issue.compactDescription.contains("Dynamic Type") || issue.compactDescription == "Text clipped")
                && element?.label == "Abgleich"
            let measuredPaletteContrastFalsePositive = issue.compactDescription.hasPrefix("Contrast failed")
                && ["Unterkunft", "3 Ideen warten", "Ja, Nein oder Offen"].contains(element?.label ?? "")

            suppressed = mapAttribution || measuredHotelContrastFalsePositive || decorativeStamp || collapsedSyncLabel
                || measuredPaletteContrastFalsePositive
            findings.append("""
            \(issue.compactDescription) [\(String(describing: issue.auditType))] suppressed=\(suppressed)
            Label: \(element?.label ?? "<none>")
            Identifier: \(element?.identifier ?? "<none>")
            Type: \(String(describing: element?.elementType))
            Frame: \(String(describing: element?.frame))
            Debug description:
            \(element?.debugDescription ?? "<none>")
            \(issue.detailedDescription)
            """)
            if !suppressed { unsuppressedCount += 1 }
            return suppressed
            }
        } catch {
            auditError = error
        }
        if !findings.isEmpty {
            let attachment = XCTAttachment(string: "Screen: \(screen)\n\n" + findings.joined(separator: "\n\n") + "\n\nApp debugDescription:\n" + app.debugDescription)
            attachment.name = "Accessibility findings — \(screen)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        if let auditError { throw auditError }
        guard unsuppressedCount > 0 else { return }
        XCTFail("Accessibility-Audit auf \(screen): \(unsuppressedCount) Fund(e); Details im Testanhang.", file: file, line: line)
    }

    func testSelectTravelDay() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let store = environment["ALBUM_PLAN_STORE"], store.hasPrefix("slot-") else {
            throw XCTSkip("Kein Wegwerf-Tagesplan angefordert")
        }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_TODAY"] = "2026-10-06"
        app.launchEnvironment["ALBUM_START_TAB"] = "Reise"
        app.launch()
        func shot(_ name: String) {
            guard let dir = environment["ALBUM_SHOT_DIR"] else { return }
            let prefix = environment["ALBUM_SHOT_SUFFIX"] ?? ""
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(prefix + name + ".png"))
        }
        let firstDay = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sonntag, 4. Oktober,")).firstMatch
        XCTAssertTrue(firstDay.waitForExistence(timeout: 15))
        shot("13-tagesauswahl")
        firstDay.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Altstädter Ring'" )).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Letná'" )).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Route zu Altstädter Ring"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Route zu Letná"].waitForExistence(timeout: 5))
        let today = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Dienstag, 6. Oktober,'" )).firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Prager Burg'" )).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Route zu Prager Burg"].waitForExistence(timeout: 5))
        firstDay.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Altstädter Ring'" )).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Letná'" )).firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["Ideen"].tap()
        XCTAssertTrue(app.staticTexts["Alles entschieden"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Idee einwerfen"].waitForExistence(timeout: 5))
        shot("14-ideen-layout")
        app.tabBars.buttons["Karte"].tap()
        let actions = app.buttons["Listenaktionen"]
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        actions.tap()
        XCTAssertTrue(app.buttons["Tage planen"].waitForExistence(timeout: 5))
        shot("15-karte-layout")
    }

    func testAfterTripOpensMemoriesAndReturnsToMap() {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "ui-" + UUID().uuidString
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_TODAY"] = "2026-10-10"
        app.launch()

        let memories = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Erinnerungen ansehen'")).firstMatch
        XCTAssertTrue(memories.waitForExistence(timeout: 15))
        let lastDay = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Freitag, 9.'")).firstMatch
        XCTAssertTrue(lastDay.isSelected, "Nach der Reise ist der letzte Reisetag vorausgewählt")
        memories.tap()
        XCTAssertTrue(app.navigationBars["Erinnerungen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Noch keine besuchten Orte"].exists)
        app.buttons["Karte öffnen"].tap()
        XCTAssertTrue(app.tabBars.buttons["Karte"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Karte"].isSelected)
    }

    func testPopulatedTripMemoriesBrowsePhotosAndPlaces() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "ui-" + UUID().uuidString
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_TODAY"] = "2026-10-10"
        app.launchEnvironment["ALBUM_DEMO_MEMORIES"] = "1"
        app.launch()

        let memories = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Erinnerungen ansehen'")).firstMatch
        XCTAssertTrue(memories.waitForExistence(timeout: 15))
        memories.tap()
        XCTAssertTrue(app.staticTexts["Sonntag, 4. Oktober"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Montag, 5. Oktober"].exists)
        try auditAccessibility(app, screen: "Erinnerungen")
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            let landscapeCounter = app.buttons["Foto-Zähler"].firstMatch
            XCTAssertTrue(landscapeCounter.waitForExistence(timeout: 5))
            XCTAssertTrue(landscapeCounter.isHittable, "Der Foto-Stapel bleibt im Querformat bedienbar")
        }
        XCUIDevice.shared.orientation = .portrait
        let memoryScreenshot = XCTAttachment(screenshot: app.screenshot())
        memoryScreenshot.name = "Besuchte Orte und Fotos im Reise-Rückblick"
        memoryScreenshot.lifetime = .keepAlways
        add(memoryScreenshot)

        let counter = app.buttons["Foto-Zähler"].firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 5))
        XCTAssertTrue(counter.label.contains("1 von 2"))
        let stackedPhoto = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Foto von Letná'")).firstMatch
        XCTAssertTrue(stackedPhoto.waitForExistence(timeout: 5), "Das vordere Stapelfoto soll als ein großes VoiceOver-Ziel erscheinen")
        stackedPhoto.tap()
        XCTAssertTrue(app.buttons["Foto schließen"].waitForExistence(timeout: 5))
        let viewerPhoto = app.images["Foto von Letná"]
        XCTAssertTrue(viewerPhoto.waitForExistence(timeout: 5))
        sleep(2)
        let fullPhotoScreenshot = XCTAttachment(screenshot: app.screenshot())
        fullPhotoScreenshot.name = "Ganzes Foto im Vollbild"
        fullPhotoScreenshot.lifetime = .keepAlways
        add(fullPhotoScreenshot)
        for (orientation, name) in [
            (UIDeviceOrientation.landscapeLeft, "Vollbildfoto Querformat links"),
            (.landscapeRight, "Vollbildfoto Querformat rechts")
        ] {
            XCUIDevice.shared.orientation = orientation
            sleep(2)
            XCTAssertTrue(app.buttons["Foto schließen"].isHittable, "Foto schließen bleibt in \(name) erreichbar")
            let frame = app.windows.firstMatch.frame
            XCTAssertGreaterThan(frame.width, frame.height, "Das Vollbildfoto muss sich an \(name) anpassen")
            XCTAssertEqual(viewerPhoto.frame.midX, frame.midX, accuracy: 40, "Das Foto muss in \(name) im sichtbaren Fenster zentriert bleiben")
            XCTAssertEqual(viewerPhoto.frame.midY, frame.midY, accuracy: 40, "Das Foto muss in \(name) auch vertikal im sichtbaren Fenster zentriert bleiben")
            if orientation == .landscapeLeft {
                let landscapeScreenshot = XCTAttachment(screenshot: app.screenshot())
                landscapeScreenshot.name = name
                landscapeScreenshot.lifetime = .keepAlways
                add(landscapeScreenshot)
            }
        }
        XCUIDevice.shared.orientation = .portrait
        sleep(2)
        XCTAssertLessThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
        app.buttons["Foto schließen"].tap()

        counter.tap()
        XCTAssertTrue(counter.label.contains("2 von 2"), "Der Foto-Stapel muss offline weiterblättern können")

        let photo = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Foto von Altstädter Ring'")).firstMatch
        for _ in 0..<4 where !photo.isHittable { app.swipeUp() }
        XCTAssertTrue(photo.isHittable)
        photo.tap()
        XCTAssertTrue(app.buttons["Foto schließen"].waitForExistence(timeout: 5))
        app.buttons["Foto schließen"].tap()

        let noPhotoPlace = app.buttons["Café Savoy, Foto ergänzen"]
        XCTAssertTrue(noPhotoPlace.waitForExistence(timeout: 5))
        noPhotoPlace.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Besucht-Spur").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Schließen"].exists)
    }

    func testOpenIdeasRemainUndecidedAfterRelaunch() {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-open-" + UUID().uuidString
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_DEMO_INBOX"] = "1"
        app.launch()
        app.buttons["Ideen"].tap()
        for _ in 0..<3 {
            let open = app.buttons["Offen"]
            XCTAssertTrue(open.waitForExistence(timeout: 5))
            open.tap()
        }
        XCTAssertTrue(app.staticTexts["Noch offen"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "ALBUM_DEMO_INBOX")
        app.launch()
        app.buttons["Ideen"].tap()
        XCTAssertTrue(app.otherElements["Inbox-Ticket"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Offen"].exists)
        XCTAssertFalse(app.staticTexts["Alles entschieden"].exists)
    }

    func testCreateIdeaAndPersistence() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-create-" + UUID().uuidString
        app.launchEnvironment["ALBUM_EMPTY_TEST_STORE"] = "1"
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launch()
        let add = app.buttons["Neue Idee"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        add.tap()
        let title = app.textFields["PlaceEditor-Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Unser Testcafe")
        app.buttons["PlaceEditor-Save"].tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        app.tabBars.buttons["Ideen"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Unser Testcafe")).firstMatch.waitForExistence(timeout: 8), "Die neu gespeicherte Idee bleibt nach Neustart erhalten")
        XCTAssertTrue(app.buttons["Ja"].exists)
        XCTAssertTrue(app.buttons["Nein"].exists)
        XCTAssertTrue(app.buttons["Offen"].exists)
    }

    /// Briefkasten per Finger: erst zu kurz gezogen (Feder zurück), dann eingeworfen, danach eine zweite Idee per Knopf.
    /// Nutzt standardmäßig einen eigens angelegten Wegwerf-Store; `ALBUM_SLOT_STORE` kann ihn gezielt überschreiben.
    /// Mit `ALBUM_SHOT_DIR` liegen Standbilder dort.
    func testLetterSlotThrow() throws {
        let environment = ProcessInfo.processInfo.environment
        let store = environment["ALBUM_SLOT_STORE"] ?? "slot-letter-\(UUID().uuidString)"
        guard store.hasPrefix("slot-") else { throw XCTSkip("Der Store für den Einwurf muss mit slot- beginnen") }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_EMPTY_TEST_STORE"] = "1"
        app.launch()
        let shots = environment["ALBUM_SHOT_DIR"].map { URL(fileURLWithPath: $0) }
        func shot(_ name: String) { if let shots { try? XCUIScreen.main.screenshot().pngRepresentation.write(to: shots.appendingPathComponent(name + ".png")) } }
        func newIdea(_ name: String) {
            XCTAssertTrue(app.buttons["Idee einwerfen"].waitForExistence(timeout: 15))
            app.buttons["Idee einwerfen"].tap()
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
        XCTAssertTrue(app.buttons["Idee einwerfen"].waitForExistence(timeout: 6))

        // Gleichwertige Schaltfläche: Tippen wirft von selbst ein.
        newIdea("Petřín")
        let button = app.buttons["Nach oben einwerfen"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.staticTexts["Liegt bei Ideen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Idee einwerfen"].waitForExistence(timeout: 6))

        // Beide Ideen sind gespeichert, auch wenn sie nur über die Schaltfläche oder gar nicht eingeworfen wurden.
        app.terminate()
        let reopened = XCUIApplication()
        reopened.launchEnvironment["ALBUM_TEST_STORE"] = store
        reopened.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        reopened.launchEnvironment["ALBUM_EMPTY_TEST_STORE"] = "1"
        reopened.launch()
        reopened.buttons["Ideen"].tap()
        for title in ["Café Slavia", "Petřín"] {
            let restoredIdea = reopened.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS %@", title)
            ).firstMatch
            XCTAssertTrue(restoredIdea.waitForExistence(timeout: 5), "\(title) bleibt nach dem Neustart gespeichert")
        }
    }

    func testInboxPositiveDecisionUndoAndRelaunchRemovesCard() {
        let store = "slot-ideas-positive-\(UUID().uuidString)"
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Ideen"
        app.launchEnvironment["ALBUM_DEMO_INBOX"] = "1"
        app.launch()

        let card = app.otherElements["Inbox-Ticket"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        let title = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH 'Karlsbrücke'")
        ).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Die konkrete Demo-Idee muss der erste Stapel sein")

        app.buttons["Ja"].tap()
        XCTAssertTrue(app.buttons["Letzte Entscheidung rückgängig"].waitForExistence(timeout: 5))
        app.buttons["Letzte Entscheidung rückgängig"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Undo muss dieselbe Idee zurückbringen")

        app.buttons["Ja"].tap()
        XCTAssertTrue(app.buttons["Letzte Entscheidung rückgängig"].waitForExistence(timeout: 5))
        app.terminate()

        let reopened = XCUIApplication()
        reopened.launchEnvironment["ALBUM_TEST_STORE"] = store
        reopened.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        reopened.launchEnvironment["ALBUM_START_TAB"] = "Ideen"
        reopened.launchEnvironment["ALBUM_EMPTY_TEST_STORE"] = "1"
        reopened.launch()
        XCTAssertTrue(reopened.buttons["Ideen"].waitForExistence(timeout: 10))
        let removedTitle = reopened.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH 'Karlsbrücke'")
        ).firstMatch
        XCTAssertFalse(removedTitle.waitForExistence(timeout: 3), "Positive Entscheidung darf nach Relaunch nicht wieder offen erscheinen")
        XCTAssertTrue(reopened.otherElements["Inbox-Ticket"].waitForExistence(timeout: 5), "Der Reststapel muss erhalten bleiben")
    }

    func testUnlocatedIdeasVoteByRightSwipeAndButtonWithoutEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-unlocated-votes-\(UUID().uuidString)"
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Ideen"
        app.launchEnvironment["ALBUM_DEMO_INBOX"] = "1"
        app.launchEnvironment["ALBUM_DEMO_INBOX_UNLOCATED"] = "1"
        app.launch()

        let card = app.otherElements["Inbox-Ticket"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 220, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Café Slavia'")).firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(app.textFields["PlaceEditor-Title"].exists, "Ein Ja-Swipe darf auch ohne Kartenposition keinen Speichereditor öffnen")

        app.buttons["Ja"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Petřín'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["PlaceEditor-Title"].exists, "Die Ja-Schaltfläche muss dieselbe direkte Abstimmung ausführen")

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "ALBUM_DEMO_INBOX")
        app.launchEnvironment.removeValue(forKey: "ALBUM_DEMO_INBOX_UNLOCATED")
        app.launch()
        XCTAssertTrue(app.otherElements["Inbox-Ticket"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Petřín'")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Alle"].tap()
        let matched = app.buttons["Ideas-All-Row-motion-inbox-bridge"]
        XCTAssertTrue(matched.waitForExistence(timeout: 5))
        XCTAssertTrue(matched.label.contains("Im Reiseplan"))
        XCTAssertTrue(app.buttons["Ideas-All-Row-motion-inbox-cafe"].exists)
    }

    func testDeferredIdeasCanBeViewedAndRestoredFromArchive() {
        let store = "slot-deferred-archive-\(UUID().uuidString)"
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Ideen"
        app.launchEnvironment["ALBUM_DEMO_INBOX"] = "1"
        app.launch()

        XCTAssertTrue(app.otherElements["Inbox-Ticket"].waitForExistence(timeout: 15))
        app.buttons["Nein"].tap()
        XCTAssertTrue(app.buttons["Letzte Entscheidung rückgängig"].waitForExistence(timeout: 5))
        let deferredTitle = app.staticTexts["Deferred-Idea-motion-inbox-bridge-Title"]
        app.buttons["Weggelegt"].tap()
        XCTAssertTrue(deferredTitle.waitForExistence(timeout: 5), "Abgelehnte Ideen müssen im Archiv sichtbar sein")

        app.buttons["Deferred-Idea-motion-inbox-bridge-Restore"].tap()
        XCTAssertFalse(deferredTitle.waitForExistence(timeout: 2), "Wiederhergestellte Ideen verlassen das Archiv")
        app.buttons["Entdecken"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Karlsbrücke'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testAllIdeasSearchOpensLiveDetailAndClears() {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-all-ideas-\(UUID().uuidString)"
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Ideen"
        app.launchEnvironment["ALBUM_DEMO_INBOX"] = "1"
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Ideen"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Ideen"].tap()
        XCTAssertTrue(app.otherElements["Inbox-Ticket"].waitForExistence(timeout: 10))
        app.buttons["Ja"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Café Slavia'" )).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Nein"].tap()

        let all = app.buttons["Alle"]
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        all.tap()

        XCTAssertTrue(app.scrollViews["Ideas-All-List"].waitForExistence(timeout: 5))
        let count = app.staticTexts["Ideas-All-Count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertTrue(count.label.contains("3"), "Alle drei gespeicherten Ideen müssen im Zähler erscheinen")
        let agreed = app.buttons["Ideas-All-Row-motion-inbox-bridge"]
        let declined = app.buttons["Ideas-All-Row-motion-inbox-cafe"]
        XCTAssertTrue(agreed.waitForExistence(timeout: 5))
        XCTAssertTrue(declined.waitForExistence(timeout: 5))
        XCTAssertTrue(agreed.label.contains("Im Reiseplan"))
        XCTAssertTrue(declined.label.contains("Weggelegt"))

        let search = app.textFields["Ideas-All-Search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Nicht vorhanden")
        XCTAssertTrue(app.staticTexts["Keine Treffer"].waitForExistence(timeout: 5))
        XCTAssertTrue(count.label.contains("0"), "Die Suche muss die Trefferzahl aktualisieren")
        app.buttons["Ideas-All-Search-Clear"].tap()
        XCTAssertTrue(agreed.waitForExistence(timeout: 5))

        search.tap()
        search.typeText("Karlsbrücke")

        let row = app.buttons["Ideas-All-Row-motion-inbox-bridge"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.staticTexts["Karlsbrücke"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Schließen"].waitForExistence(timeout: 5))
        app.buttons["Schließen"].tap()

        XCTAssertTrue(app.buttons["Ideas-All-Search-Clear"].waitForExistence(timeout: 5))
        app.buttons["Ideas-All-Search-Clear"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    func testInboxSubthresholdOpposingReleasesKeepSameCardUndecided() {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-ideas-abort-\(UUID().uuidString)"
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Ideen"
        app.launchEnvironment["ALBUM_DEMO_INBOX"] = "1"
        app.launch()

        let card = app.otherElements["Inbox-Ticket"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        let title = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH 'Karlsbrücke'")
        ).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 50, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0)
        XCTAssertTrue(title.exists)
        XCTAssertTrue(app.buttons["Ja"].exists)
        XCTAssertFalse(app.buttons["Letzte Entscheidung rückgängig"].exists)

        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -50, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0)
        XCTAssertTrue(title.exists, "Gegenzug unterhalb der Schwelle darf die Idee nicht entscheiden")
        XCTAssertTrue(app.buttons["Nein"].exists)
        XCTAssertFalse(app.buttons["Letzte Entscheidung rückgängig"].exists)
    }

    /// Ideen-Stapel: Auffächern, Anheben mit Neigung, Füllung und Label, Foto im Vollbild, Entscheiden.
    /// Verwendet einen lokalen Wegwerf-Store mit drei eingebetteten Demo-Ideen.
    /// Mit `ALBUM_SHOT_DIR` liegen Standbilder dort.
    func testInboxStack() throws {
        let environment = ProcessInfo.processInfo.environment
        let store = environment["ALBUM_INBOX_STORE"] ?? "slot-inbox-\(UUID().uuidString)"
        guard store.hasPrefix("slot-") else { throw XCTSkip("Der Inbox-Store muss mit slot- beginnen") }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Ideen"
        app.launchEnvironment["ALBUM_DEMO_INBOX"] = "1"
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

    /// Namensabfrage mit getipptem Namen; der Screenshot wird dem XCTest-Ergebnis angehängt.
    func testNamePromptStitch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "ui-" + UUID().uuidString
        app.launchArguments += ["-album.myName", ""]
        app.launch()
        let field = app.textFields["Vorname"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        sleep(1)
        field.tap(); field.typeText("Mathilde")
        sleep(1)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "A-Namensfeld-Schreibschlitten"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertEqual(field.value as? String, "Mathilde")
    }

    /// Braucht vorbereitete Orte (`ALBUM_PLAN_STORE`) und Netz für die Öffnungszeiten.
    /// Mit `ALBUM_SHOT_DIR` werden Screenshots der Vorschau dort abgelegt.
    func testAutomaticDayPlanPreview() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let store = environment["ALBUM_AUTOPLAN_STORE"], store.hasPrefix("slot-") else { throw XCTSkip("Keine unzugewiesene Autoplan-Fixture") }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Karte"
        app.launch()
        let auto = app.buttons["Tage planen"]
        let initialExpand = app.buttons["Liste ausklappen"]
        XCTAssertTrue(initialExpand.waitForExistence(timeout: 5))
        initialExpand.tap()
        XCTAssertTrue(app.buttons["Liste einklappen"].waitForExistence(timeout: 5))
        let unassignedRow = app.buttons["place-row-qa-oldtown"]
        XCTAssertTrue(unassignedRow.waitForExistence(timeout: 5))
        let unassignedControls = app.buttons.matching(NSPredicate(format: "label == 'Tag festlegen'"))
        XCTAssertTrue(unassignedControls.firstMatch.waitForExistence(timeout: 5), "Die isolierte Autoplan-Fixture muss vor der Vorschau ungeplante Orte ausweisen")
        let actions = app.buttons["Listenaktionen"]
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        actions.tap()
        XCTAssertTrue(auto.waitForExistence(timeout: 5))
        auto.tap()
        XCTAssertTrue(app.navigationBars["Vorschlag"].waitForExistence(timeout: 5))
        let apply = app.buttons["Übernehmen"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5))
        let ready = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: apply)
        wait(for: [ready], timeout: 90)
        let proposalLabels = app.descendants(matching: .any)
        let proposalList = proposalLabels.matching(identifier: "day-plan-preview-list").firstMatch
        XCTAssertTrue(proposalList.waitForExistence(timeout: 5))
        func assertProposalPlace(_ title: String) {
            let label = proposalLabels.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
            for _ in 0..<8 where !label.exists { proposalList.swipeUp() }
            XCTAssertTrue(label.waitForExistence(timeout: 5), "Vorschlag muss \(title) enthalten")
        }
        assertProposalPlace("Altstädter Ring")
        assertProposalPlace("Letná")
        assertProposalPlace("Prager Burg")
        let shots = environment["ALBUM_SHOT_DIR"].map { URL(fileURLWithPath: $0) }
        func shot(_ name: String) { if let shots { try? XCUIScreen.main.screenshot().pngRepresentation.write(to: shots.appendingPathComponent(name + ".png")) } }
        shot("plan-1")
        proposalList.swipeUp(); shot("plan-2")
        proposalList.swipeUp(); shot("plan-3")
        apply.tap()
        // Der Tagesplan lebt jetzt in der Liste auf der Karte.
        XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: 5))
        let fullList = app.buttons["Liste einklappen"]
        if !fullList.waitForExistence(timeout: 5) {
            let expand = app.buttons["Liste ausklappen"]
            XCTAssertTrue(expand.waitForExistence(timeout: 5))
            expand.tap()
            XCTAssertTrue(fullList.waitForExistence(timeout: 5))
        }
        let mapList = app.scrollViews["map-places-list"]
        XCTAssertTrue(mapList.waitForExistence(timeout: 5))
        let oldtownRow = app.buttons["place-row-qa-oldtown"]
        let castleRow = app.buttons["place-row-qa-castle"]
        for _ in 0..<8 where !oldtownRow.isHittable { mapList.swipeDown() }
        XCTAssertTrue(oldtownRow.isHittable, "Die angewandte Zuweisung muss Altstädter Ring in der Kartenliste erreichbar machen")
        let assignmentScreenshot = XCTAttachment(screenshot: app.screenshot())
        assignmentScreenshot.name = "Autoplan Altstädter Ring nach Übernahme"
        assignmentScreenshot.lifetime = .keepAlways
        add(assignmentScreenshot)
        let assignmentAX = XCTAttachment(string: app.debugDescription)
        assignmentAX.name = "Autoplan AX nach Übernahme Altstädter Ring"
        assignmentAX.lifetime = .keepAlways
        add(assignmentAX)
        for _ in 0..<8 where !castleRow.isHittable { mapList.swipeUp() }
        XCTAssertTrue(castleRow.isHittable, "Die angewandte Zuordnung muss Prager Burg nach eigenständigem Scrollen erreichbar machen")
        app.buttons["Listenaktionen"].tap()
        app.buttons["Ordnen"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tag ändern, jetzt'" )).firstMatch.waitForExistence(timeout: 5), "Nach Übernehmen muss mindestens ein Ort einer konkreten Reise zugeordnet sein")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == 'Tag festlegen'" )).count, 0, "Die unzugewiesene Autoplan-Fixture darf nach Übernehmen keine ungeplanten Orte behalten")
        app.buttons["Listenaktionen"].tap()
        app.buttons["Fertig"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: 10))
        let reloadExpand = app.buttons["Liste ausklappen"]
        if reloadExpand.waitForExistence(timeout: 5) { reloadExpand.tap() }
        XCTAssertTrue(app.buttons["Liste einklappen"].waitForExistence(timeout: 5))
        app.buttons["Listenaktionen"].tap()
        app.buttons["Ordnen"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tag ändern, jetzt'" )).firstMatch.waitForExistence(timeout: 5), "Die Tageszuordnung muss nach Relaunch erhalten bleiben")
        shot("plan-applied")
    }

    /// Karte mit Liste in allen Höhen. Braucht vorbereitete Orte (`ALBUM_PLAN_STORE`).
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
        // Ein kurzer echter Weg darf nicht als Grabber-Tap auf die volle Höhe umschalten.
        let shortHandle = app.buttons["Liste ausklappen"]
        XCTAssertTrue(shortHandle.waitForExistence(timeout: 5))
        let shortStart = shortHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        shortStart.press(forDuration: 0.1,
                        thenDragTo: shortStart.withOffset(CGVector(dx: 0, dy: 32)),
                        withVelocity: .slow,
                        thenHoldForDuration: 0)
        sleep(1)
        XCTAssertTrue(app.buttons["Liste ausklappen"].exists, "Ein kurzer Grabber-Drag muss auf halber Höhe bleiben")
        XCTAssertFalse(app.buttons["Liste einklappen"].exists, "Ein kurzer Grabber-Drag darf keinen Tap auf volle Höhe auslösen")

        // Für das Schließen wird bewusst vom aktuellen Grabberzentrum bis in den sichtbaren unteren Fensterbereich gezogen.
        let handle = app.buttons["Liste ausklappen"]
        XCTAssertTrue(handle.waitForExistence(timeout: 4))
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        start.press(forDuration: 0.1,
                    thenDragTo: end,
                    withVelocity: .slow,
                    thenHoldForDuration: 0)
        sleep(1)
        let hiddenDrawer = app.buttons["map-drawer-reopen"]
        XCTAssertTrue(hiddenDrawer.waitForExistence(timeout: 4), "Die Ortsliste lässt sich nicht vollständig schließen")
        shot("map-hidden")
        hiddenDrawer.tap()
        XCTAssertTrue(app.buttons["Liste ausklappen"].waitForExistence(timeout: 4), "Die geschlossene Ortsliste lässt sich nicht wieder öffnen")

        // iOS ignoriert Hochkant umgedreht auf iPhone-Modellen ohne Home-Button.
        for (orientation, name) in [
            (UIDeviceOrientation.landscapeLeft, "map-landscape-left"),
            (.landscapeRight, "map-landscape-right")
        ] {
            XCUIDevice.shared.orientation = orientation
            sleep(3)
            XCTAssertTrue(app.textFields["map-search"].exists, "Karte bleibt in \(name) sichtbar")
            let expectsLandscape = orientation == .landscapeLeft || orientation == .landscapeRight
            let frame = app.windows.firstMatch.frame
            XCTAssertEqual(frame.width > frame.height, expectsLandscape, "Fenstergeometrie passt nicht zu \(name): \(frame)")
            XCTAssertEqual(XCUIDevice.shared.orientation, orientation, "Simulator meldet nicht \(name)")
            shot(name)
        }
        XCUIDevice.shared.orientation = .portrait
        sleep(3)
        XCTAssertTrue(app.textFields["map-search"].exists, "Karte kehrt ins Hochformat zurück")
        let portraitFrame = app.windows.firstMatch.frame
        XCTAssertLessThan(portraitFrame.width, portraitFrame.height, "Fenstergeometrie bleibt nach der Rotation im Querformat")
        XCTAssertEqual(XCUIDevice.shared.orientation, .portrait)
        shot("map-portrait-restored")
    }

    /// Zusammengefasste Fotomarken zoomen in den Bereich; ein einzelner Pin öffnet denselben Ort in der Liste.
    func testMapPinClustersZoomToPlaces() throws {
        guard let store = ProcessInfo.processInfo.environment["ALBUM_PLAN_STORE"] else {
            throw XCTSkip("Keine vorbereiteten Orte")
        }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Karte"
        app.launch()

        let closeList = app.buttons["Liste schließen"]
        XCTAssertTrue(closeList.waitForExistence(timeout: 15))
        closeList.tap()
        let collapsedDrawer = app.buttons["map-drawer-reopen"]
        XCTAssertTrue(collapsedDrawer.waitForExistence(timeout: 5), "Geschlossene Liste muss als öffnende Kapsel erreichbar bleiben")
        XCTAssertFalse(closeList.exists, "Das Ortsblatt muss wirklich geschlossen sein")

        let clusterQuery = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'map-cluster-'"))
        XCTAssertTrue(clusterQuery.firstMatch.waitForExistence(timeout: 10), "Nahe Fotomarken sollen als Gruppe erscheinen")
        let firstCluster = clusterQuery.firstMatch
        let prefix = "map-cluster-"
        let memberIDs = String(firstCluster.identifier.dropFirst(prefix.count)).split(separator: "|").map(String.init)
        let expectedPlaceID = try XCTUnwrap(memberIDs.first, "Der Cluster braucht mindestens einen Ort")
        let pin = app.buttons["map-pin-\(expectedPlaceID)"]
        firstCluster.tap()

        let containingPlace = clusterQuery.matching(
            NSPredicate(format: "identifier CONTAINS %@", expectedPlaceID)
        ).firstMatch
        let memberChoice = app.buttons["map-cluster-choice-\(expectedPlaceID)"]
        for _ in 0..<8 {
            if pin.waitForExistence(timeout: 1) { break }
            if memberChoice.waitForExistence(timeout: 1) {
                memberChoice.tap()
                break
            }
            XCTAssertTrue(containingPlace.waitForExistence(timeout: 4), "Der Ort muss beim Hineinzoomen in einer Gruppe auffindbar bleiben")
            containingPlace.tap()
        }
        XCTAssertTrue(pin.waitForExistence(timeout: 5), "Ein Ort aus dem angetippten Cluster soll nach Zoom oder Mitgliederauswahl einzeln anwählbar sein")
        pin.tap()
        XCTAssertTrue(closeList.waitForExistence(timeout: 5), "Der Pin muss das Ortsblatt wieder öffnen")

        let selectedRow = app.buttons["place-row-\(expectedPlaceID)"]
        XCTAssertTrue(selectedRow.waitForExistence(timeout: 8), "Die Pin-Auswahl muss denselben Ort in der Liste zeigen")
        let detailsButton = app.buttons["place-details-\(expectedPlaceID)"]
        XCTAssertTrue(detailsButton.waitForExistence(timeout: 5), "Der Detail-Button des ausgewählten Orts muss sichtbar sein")
        let placesList = app.scrollViews["map-places-list"]
        XCTAssertTrue(placesList.waitForExistence(timeout: 5), "Die Ortsliste muss für die sichtbare Detailprüfung vorhanden sein")
        for _ in 0..<8 where !detailsButton.isHittable {
            placesList.swipeUp()
        }
        XCTAssertTrue(detailsButton.isHittable, "Der Detail-Button muss nach dem gezielten Scrollen tatsächlich sichtbar und erreichbar sein")
        XCTAssertGreaterThanOrEqual(detailsButton.frame.width, 44, "Der Detail-Button muss mindestens 44 pt breit sein")
        XCTAssertGreaterThanOrEqual(detailsButton.frame.height, 44, "Der Detail-Button muss mindestens 44 pt hoch sein")
        try auditAccessibilityWhenEnabled(app, screen: "Karte mit ausgewähltem Ort")
    }

    /// Rundgang über alle Bildschirme für die Layout-Prüfung. Braucht `ALBUM_PLAN_STORE` und `ALBUM_SHOT_DIR`.
    /// Mit `ALBUM_TODAY` (z. B. 2026-10-06) zeigt er den Stand während der Reise.
    func testScreenTour() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let store = environment["ALBUM_PLAN_STORE"], let dir = environment["ALBUM_SHOT_DIR"] else { throw XCTSkip("Kein Rundgang angefordert") }
        let prefix = environment["ALBUM_SHOT_SUFFIX"] ?? ""
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Reise"
        app.launchEnvironment["ALBUM_TODAY"] = environment["ALBUM_TODAY"] ?? "2026-10-06"
        app.launch()
        func shot(_ name: String) {
            sleep(2)
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(prefix)\(name).png"))
        }
        XCTAssertTrue(app.buttons["Idee einwerfen"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sonntag, 4. Oktober,")).firstMatch.waitForExistence(timeout: 5))
        shot("01-reise")
        XCTAssertTrue(app.buttons["Alle Reiseunterlagen"].waitForExistence(timeout: 5))
        let ticket = app.buttons["Flug-Ticket"].firstMatch
        if ticket.exists {
            ticket.tap()
            XCTAssertTrue(app.buttons["Bordkarte schließen"].waitForExistence(timeout: 5))
            shot("02b-bordkarte")
            app.buttons["Bordkarte schließen"].tap()
        }

        app.tabBars.buttons["Ideen"].tap()
        XCTAssertTrue(app.staticTexts["Alles entschieden"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Idee einwerfen"].waitForExistence(timeout: 5))
        shot("03-ideen")

        app.tabBars.buttons["Karte"].tap()
        XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: 5))
        shot("04-karte")
        let expandDrawer = app.buttons["Liste ausklappen"]
        XCTAssertTrue(expandDrawer.waitForExistence(timeout: 5))
        expandDrawer.tap()
        XCTAssertTrue(app.buttons["Liste einklappen"].waitForExistence(timeout: 5), "Die Karte muss für die Detailprüfung vollständig geöffnet sein")
        let details = app.buttons["place-details-qa-oldtown"]
        XCTAssertTrue(details.waitForExistence(timeout: 8), "Die Demo-Orte müssen eine erreichbare Detailansicht haben")
        let placesList = app.scrollViews["map-places-list"]
        XCTAssertTrue(placesList.waitForExistence(timeout: 5))
        let todaySection = app.staticTexts["Dienstag, 6. Oktober"]
        let todayVisible = expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: todaySection)
        wait(for: [todayVisible], timeout: 5)
        for _ in 0..<8 where !details.isHittable {
            if details.exists && details.frame.minY < placesList.frame.minY {
                placesList.swipeDown()
            } else if details.exists && details.frame.maxY > placesList.frame.maxY {
                placesList.swipeUp()
            } else if todaySection.isHittable {
                placesList.swipeDown()
            } else {
                placesList.swipeUp()
            }
        }
        XCTAssertTrue(details.isHittable, "Der Tagesstart darf die Detailzeile nicht außerhalb des sichtbaren Kartenlistenbereichs lassen")
        details.tap(); shot("05-ortsdetail")
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
        app.buttons["Bearbeiten"].tap(); shot("07-editor-ort")
        XCTAssertTrue(app.buttons["PlaceEditor-Cancel"].waitForExistence(timeout: 5))
        app.buttons["PlaceEditor-Cancel"].tap()
        XCTAssertTrue(app.buttons["Schließen"].waitForExistence(timeout: 5))
        app.buttons["Schließen"].tap()
        XCTAssertTrue(app.buttons["Tage planen"].waitForExistence(timeout: 5))
        app.buttons["Tage planen"].tap()
        XCTAssertTrue(app.navigationBars["Vorschlag"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Übernehmen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Altstädter Ring'")).firstMatch.waitForExistence(timeout: 90))
        shot("08-vorschlag")
        app.buttons["Abbrechen"].tap()

        app.buttons["Idee einwerfen"].tap(); shot("09-editor-neu")
        XCTAssertTrue(app.buttons["PlaceEditor-Cancel"].waitForExistence(timeout: 5))
        app.buttons["PlaceEditor-Cancel"].tap()

        app.tabBars.buttons["Reise"].tap()
        XCTAssertTrue(app.buttons["Alle Reiseunterlagen"].waitForExistence(timeout: 5))
        app.buttons["Alle Reiseunterlagen"].tap(); shot("10-unterlagen")
        XCTAssertTrue(app.navigationBars["Unterlagen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Schließen"].waitForExistence(timeout: 5))
        app.buttons["Schließen"].tap()

        let share = app.buttons["Jemanden einladen"].exists ? app.buttons["Jemanden einladen"] : app.buttons["Gemeinsames Album"]
        XCTAssertTrue(share.firstMatch.waitForExistence(timeout: 5))
        share.firstMatch.tap(); shot("12-teilen")
        XCTAssertTrue(app.buttons["Schließen"].waitForExistence(timeout: 5))
        app.buttons["Schließen"].tap()
    }
}

extension AlbumUITests {
    func testCancelDelayedPlaceImageSearch() throws {
        let store = "slot-image-cancel-\(UUID().uuidString)"
        let response = """
        {"selection_version":3,"image":null,"candidates":[
          {"image_url":"https://example.com/late-result.jpg","source_url":"https://example.com/late-result","credit":"Late QA Result","provider":"wikimedia","license_name":"CC BY 4.0","license_url":"https://creativecommons.org/licenses/by/4.0/","confidence":"suggested","caption":"Delayed result"}
        ]}
        """
        let marker = XCTAttachment(string: "late-resolver-runtime-20261002-v1; ALBUM_TEST_STORE=\(store); ALBUM_IMAGE_RESPONSE_DELAY_MS=12000")
        marker.name = "Late resolver runtime marker"
        marker.lifetime = .keepAlways
        add(marker)

        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_IMAGE_RESPONSE_BASE64"] = Data(response.utf8).base64EncodedString()
        app.launchEnvironment["ALBUM_IMAGE_RESPONSE_DELAY_MS"] = "12000"
        app.launchEnvironment["ALBUM_DEMO_IMAGE_CHOICE"] = "1"
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Karte"
        app.launch()

        let list = app.buttons["Liste ausklappen"]
        XCTAssertTrue(list.waitForExistence(timeout: 15))
        list.tap()
        let details = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Details zu' AND label CONTAINS 'Café Louvre'")).firstMatch
        XCTAssertTrue(details.waitForExistence(timeout: 10))
        details.tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
        app.buttons["Bearbeiten"].firstMatch.tap()

        // Persist the fixture-backed place before starting the late-result scenario.
        // The relaunch below must read this baseline from the isolated store rather
        // than reseeding it through ALBUM_DEMO_IMAGE_CHOICE.
        let baselineSave = app.buttons["PlaceEditor-Save"].exists
            ? app.buttons["PlaceEditor-Save"]
            : app.buttons["Speichern"]
        XCTAssertTrue(baselineSave.waitForExistence(timeout: 5))
        XCTAssertTrue(baselineSave.isHittable, "Baseline-Speichern muss vor dem Late-Resolver hittable sein")
        baselineSave.tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
        app.buttons["Bearbeiten"].firstMatch.tap()

        let choose = app.buttons["Bild wählen"]
        for _ in 0..<6 where !choose.isHittable { app.swipeUp() }
        XCTAssertTrue(choose.waitForExistence(timeout: 5))
        XCTAssertTrue(choose.isHittable, "Bild wählen muss vor dem verzögerten Resolver-Tap hittable sein")
        choose.tap()
        XCTAssertTrue(app.buttons["Bilder werden gesucht …"].waitForExistence(timeout: 5), "Der isolierte Bildresolver muss vor Cancel sichtbar beschäftigt sein")
        let cancel = app.buttons["PlaceEditor-Cancel"].exists ? app.buttons["PlaceEditor-Cancel"] : app.buttons["Abbrechen"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(cancel.isHittable, "Cancel muss vor dem verspäteten Ergebnis hittable sein")
        let beforeCancelAX = XCTAttachment(string: app.debugDescription)
        beforeCancelAX.name = "Late resolver vor Cancel AX"
        beforeCancelAX.lifetime = .keepAlways
        add(beforeCancelAX)
        let beforeCancelScreenshot = XCTAttachment(screenshot: app.screenshot())
        beforeCancelScreenshot.name = "Late resolver vor Cancel"
        beforeCancelScreenshot.lifetime = .keepAlways
        add(beforeCancelScreenshot)
        cancel.tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5), "Cancel muss zum unveränderten Ortsdetail zurückkehren")
        sleep(13)
        XCTAssertFalse(app.navigationBars["Bild wählen"].exists, "Das verspätete Ergebnis darf kein Bildauswahl-Sheet nach Cancel öffnen")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Late QA Result'")).firstMatch.exists)
        let afterDelayAX = XCTAttachment(string: app.debugDescription)
        afterDelayAX.name = "Late resolver nach verspätetem Ergebnis AX"
        afterDelayAX.lifetime = .keepAlways
        add(afterDelayAX)
        let afterDelayScreenshot = XCTAttachment(screenshot: app.screenshot())
        afterDelayScreenshot.name = "Late resolver nach verspätetem Ergebnis"
        afterDelayScreenshot.lifetime = .keepAlways
        add(afterDelayScreenshot)

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "ALBUM_DEMO_IMAGE_CHOICE")
        app.launchEnvironment.removeValue(forKey: "ALBUM_IMAGE_RESPONSE_BASE64")
        app.launchEnvironment.removeValue(forKey: "ALBUM_IMAGE_RESPONSE_DELAY_MS")
        app.launch()
        XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: 10))
        let relaunchedList = app.buttons["Liste ausklappen"]
        XCTAssertTrue(relaunchedList.waitForExistence(timeout: 10), "Der persistierte Baseline-Store muss die Kartenliste erneut öffnen")
        relaunchedList.tap()
        let relaunchedDetails = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Details zu' AND label CONTAINS 'Café Louvre'")).firstMatch
        XCTAssertTrue(relaunchedDetails.waitForExistence(timeout: 10))
        relaunchedDetails.tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
        app.buttons["Bearbeiten"].firstMatch.tap()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Late QA Result'")).firstMatch.exists, "Der verspätete Resolver darf keinen Foto-Draft persistieren")
        let relaunchedCancel = app.buttons["PlaceEditor-Cancel"].exists ? app.buttons["PlaceEditor-Cancel"] : app.buttons["Abbrechen"]
        XCTAssertTrue(relaunchedCancel.waitForExistence(timeout: 5))
        relaunchedCancel.tap()
    }

    func testChoosePlaceImageAndPersistence() throws {
        let store = "slot-image-\(UUID().uuidString)"
        let credit = "Café Louvre Testarchiv"
        let response = """
        {"selection_version":3,"image":null,"candidates":[
          {"image_url":"https://example.com/cafe-louvre-main.jpg","source_url":"https://commons.wikimedia.org/wiki/File:Cafe_Louvre_main.jpg","credit":"Erste Quelle","provider":"wikimedia","license_name":"CC BY 4.0","license_url":"https://creativecommons.org/licenses/by/4.0/","confidence":"suggested","caption":"Café Louvre außen"},
          {"image_url":"https://example.com/cafe-louvre-interior.jpg","source_url":"https://commons.wikimedia.org/wiki/File:Cafe_Louvre_interior.jpg","credit":"Café Louvre Testarchiv","provider":"wikimedia","license_name":"CC BY-SA 4.0","license_url":"https://creativecommons.org/licenses/by-sa/4.0/","confidence":"suggested","caption":"Café Louvre innen"}
        ]}
        """
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_IMAGE_RESPONSE_BASE64"] = Data(response.utf8).base64EncodedString()
        app.launchEnvironment["ALBUM_DEMO_IMAGE_CHOICE"] = "1"
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Karte"
        app.launch()
        func hasElement(label: String) -> Bool {
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", label)).firstMatch.exists
        }
        func edit() {
            let details = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Details zu'")).firstMatch
            XCTAssertTrue(details.waitForExistence(timeout: 15))
            details.tap()
            app.buttons["Bearbeiten"].firstMatch.tap()
        }
        func reveal(_ button: XCUIElement) {
            for _ in 0..<4 where !button.isHittable { app.swipeUp() }
            XCTAssertTrue(button.isHittable)
        }
        edit()
        let choose = app.buttons["Bild wählen"]
        reveal(choose)
        choose.tap()
        XCTAssertTrue(app.navigationBars["Bild wählen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Ortszuordnung bitte prüfen"].exists)
        XCTAssertTrue(hasElement(label: "Quelle ansehen"))
        XCTAssertTrue(hasElement(label: "Lizenz · CC BY-SA 4.0"))
        let alternative = app.buttons["place-image-choice-1"]
        reveal(alternative)
        alternative.tap()
        let chosenCredit = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Foto: \(credit)")).firstMatch
        for _ in 0..<4 where !chosenCredit.isHittable { app.swipeUp() }
        XCTAssertTrue(chosenCredit.exists)
        app.buttons["Speichern"].tap()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Foto: \(credit) · CC BY-SA 4.0"))
            .firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(hasElement(label: "Lizenz · CC BY-SA 4.0"))
        app.terminate()
        app.launch()
        edit()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Foto: \(credit) · CC BY-SA 4.0"))
            .firstMatch.waitForExistence(timeout: 5))
        app.buttons["Abbrechen"].tap()
    }

    func testNativePhotoPickerSelectionSaveAndRelaunch() throws {
        let store = "slot-native-photo-save-\(UUID().uuidString)"
        let marker = XCTAttachment(string: "native-photo-save-runtime-20261002-v1; ALBUM_TEST_STORE=\(store)")
        marker.name = "Native photo Save store marker"
        marker.lifetime = .keepAlways
        add(marker)

        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_DEMO_IMAGE_CHOICE"] = "1"
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Karte"
        app.launch()

        func openEditor() {
            XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: 15))
            let list = app.buttons["Liste ausklappen"]
            XCTAssertTrue(list.waitForExistence(timeout: 10))
            list.tap()
            let details = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Details zu' AND label CONTAINS 'Café Louvre'" )).firstMatch
            XCTAssertTrue(details.waitForExistence(timeout: 10))
            details.tap()
            XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
            app.buttons["Bearbeiten"].tap()
        }

        func saveEditor() {
            let save = app.buttons["PlaceEditor-Save"].exists ? app.buttons["PlaceEditor-Save"] : app.buttons["Speichern"]
            XCTAssertTrue(save.waitForExistence(timeout: 5))
            XCTAssertTrue(save.isHittable, "Speichern muss im Native-Photo-Test hittable sein")
            save.tap()
            XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
        }

        func selectObservedNativePhoto() {
            let ownPhoto = app.buttons["Eigenes Foto wählen"]
            let form = app.descendants(matching: .any).matching(identifier: "PlaceEditor-Form").firstMatch
            XCTAssertTrue(form.waitForExistence(timeout: 5))
            for _ in 0..<8 where !ownPhoto.isHittable { form.swipeUp() }
            XCTAssertTrue(ownPhoto.waitForExistence(timeout: 5))
            XCTAssertTrue(ownPhoto.isHittable)
            let before = XCTAttachment(screenshot: app.screenshot())
            before.name = "Native photo picker vor Auswahl"
            before.lifetime = .keepAlways
            add(before)
            ownPhoto.tap()

            let picker = app.navigationBars["Fotos"]
            XCTAssertTrue(picker.waitForExistence(timeout: 10), "Der beobachtete native Fotos-Picker muss geöffnet werden")
            let pickerScroll = app.scrollViews["photosView_content_scroll_view"]
            XCTAssertTrue(pickerScroll.waitForExistence(timeout: 5), "Der beobachtete PhotosPicker-ScrollView muss vorhanden sein")
            let assets = pickerScroll.descendants(matching: .image).matching(identifier: "PXGGridLayout-Info")
            XCTAssertGreaterThan(assets.count, 0, "Der native Picker muss mindestens ein beobachtetes Bildziel exponieren")
            let asset = assets.firstMatch
            XCTAssertTrue(asset.waitForExistence(timeout: 5))
            let assetFrame = asset.frame
            XCTAssertGreaterThan(assetFrame.width, 0, "Das beobachtete native Bildziel muss einen positiven Frame haben")
            XCTAssertGreaterThan(assetFrame.height, 0, "Das beobachtete native Bildziel muss einen positiven Frame haben")
            XCTAssertTrue(pickerScroll.frame.contains(assetFrame), "Das beobachtete Bildziel muss vollständig im PhotosPicker-ScrollView liegen")
            XCTAssertTrue(app.windows.firstMatch.frame.contains(assetFrame), "Das beobachtete Bildziel muss im App-Fenster liegen")
            let pickerAX = XCTAttachment(string: app.debugDescription)
            pickerAX.name = "Native photo picker vor Auswahl AX"
            pickerAX.lifetime = .keepAlways
            add(pickerAX)
            // PhotosUI exposes these visible cells as non-hittable Image AX nodes;
            // tap the observed node's own center instead of inventing a grid coordinate.
            asset.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

            XCTAssertTrue(app.navigationBars["Bearbeiten"].waitForExistence(timeout: 10), "Die Auswahl muss zum Editor zurückkehren")
            let chosen = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Gewähltes Bild")).firstMatch
            for _ in 0..<8 where !chosen.isHittable { form.swipeUp() }
            XCTAssertTrue(chosen.waitForExistence(timeout: 10), "Nach der nativen Auswahl muss das gewählte Bild im Editor erscheinen")
            let after = XCTAttachment(screenshot: app.screenshot())
            after.name = "Native photo picker nach Auswahl"
            after.lifetime = .keepAlways
            add(after)
            let afterAX = XCTAttachment(string: app.debugDescription)
            afterAX.name = "Native photo picker nach Auswahl AX"
            afterAX.lifetime = .keepAlways
            add(afterAX)
        }

        openEditor()
        saveEditor() // Persist the no-photo baseline before the real picker flow.
        app.buttons["Bearbeiten"].tap()
        selectObservedNativePhoto()
        saveEditor()

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "ALBUM_DEMO_IMAGE_CHOICE")
        app.launch()
        openEditor()
        let reloadedImage = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Gewähltes Bild")).firstMatch
        XCTAssertTrue(reloadedImage.waitForExistence(timeout: 10), "Das per PhotosPicker gespeicherte Bild muss nach Relaunch im Editor erscheinen")
        let reload = XCTAttachment(screenshot: app.screenshot())
        reload.name = "Native photo picker nach Relaunch"
        reload.lifetime = .keepAlways
        add(reload)
        app.buttons["Abbrechen"].tap()
    }

    func testNativePhotoPickerSelectionCancelLeavesBaseline() throws {
        let store = "slot-native-photo-cancel-\(UUID().uuidString)"
        let marker = XCTAttachment(string: "native-photo-cancel-runtime-20261002-v1; ALBUM_TEST_STORE=\(store)")
        marker.name = "Native photo Cancel store marker"
        marker.lifetime = .keepAlways
        add(marker)

        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_DEMO_IMAGE_CHOICE"] = "1"
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Karte"
        app.launch()

        func openEditor() {
            XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: 15))
            let list = app.buttons["Liste ausklappen"]
            XCTAssertTrue(list.waitForExistence(timeout: 10))
            list.tap()
            let details = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Details zu' AND label CONTAINS 'Café Louvre'" )).firstMatch
            XCTAssertTrue(details.waitForExistence(timeout: 10))
            details.tap()
            XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
            app.buttons["Bearbeiten"].tap()
        }

        func saveBaseline() {
            let save = app.buttons["PlaceEditor-Save"].exists ? app.buttons["PlaceEditor-Save"] : app.buttons["Speichern"]
            XCTAssertTrue(save.waitForExistence(timeout: 5))
            XCTAssertTrue(save.isHittable)
            save.tap()
            XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
        }

        openEditor()
        saveBaseline()
        app.buttons["Bearbeiten"].tap()

        let form = app.descendants(matching: .any).matching(identifier: "PlaceEditor-Form").firstMatch
        let ownPhoto = app.buttons["Eigenes Foto wählen"]
        XCTAssertTrue(form.waitForExistence(timeout: 5))
        for _ in 0..<8 where !ownPhoto.isHittable { form.swipeUp() }
        XCTAssertTrue(ownPhoto.waitForExistence(timeout: 5))
        XCTAssertTrue(ownPhoto.isHittable)
        ownPhoto.tap()
        let picker = app.navigationBars["Fotos"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Der native Fotos-Picker muss für den Cancel-Test geöffnet werden")
        let pickerScroll = app.scrollViews["photosView_content_scroll_view"]
        XCTAssertTrue(pickerScroll.waitForExistence(timeout: 5))
        let assets = pickerScroll.descendants(matching: .image).matching(identifier: "PXGGridLayout-Info")
        XCTAssertGreaterThan(assets.count, 0, "Der native Picker muss ein beobachtetes Bildziel exponieren")
        let asset = assets.firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 5))
        let assetFrame = asset.frame
        XCTAssertGreaterThan(assetFrame.width, 0, "Das beobachtete native Bildziel muss einen positiven Frame haben")
        XCTAssertGreaterThan(assetFrame.height, 0, "Das beobachtete native Bildziel muss einen positiven Frame haben")
        XCTAssertTrue(pickerScroll.frame.contains(assetFrame), "Das beobachtete Bildziel muss vollständig im PhotosPicker-ScrollView liegen")
        XCTAssertTrue(app.windows.firstMatch.frame.contains(assetFrame), "Das beobachtete Bildziel muss im App-Fenster liegen")
        let beforeCancel = XCTAttachment(screenshot: app.screenshot())
        beforeCancel.name = "Native photo picker Cancel vor Auswahl"
        beforeCancel.lifetime = .keepAlways
        add(beforeCancel)
        // The native image node is visible but not AX-hittable; use its observed center.
        asset.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(app.navigationBars["Bearbeiten"].waitForExistence(timeout: 10))
        let chosen = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Gewähltes Bild")).firstMatch
        for _ in 0..<8 where !chosen.isHittable { form.swipeUp() }
        XCTAssertTrue(chosen.waitForExistence(timeout: 10), "Die Auswahl muss vor Cancel im Editor sichtbar sein")
        let afterSelection = XCTAttachment(screenshot: app.screenshot())
        afterSelection.name = "Native photo picker Cancel nach Auswahl"
        afterSelection.lifetime = .keepAlways
        add(afterSelection)
        let cancel = app.buttons["PlaceEditor-Cancel"].exists ? app.buttons["PlaceEditor-Cancel"] : app.buttons["Abbrechen"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(cancel.isHittable)
        cancel.tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "ALBUM_DEMO_IMAGE_CHOICE")
        app.launch()
        openEditor()
        let reloadedImage = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Gewähltes Bild")).firstMatch
        XCTAssertFalse(reloadedImage.waitForExistence(timeout: 5), "Cancel darf kein eigenes Foto persistieren")
        let reload = XCTAttachment(screenshot: app.screenshot())
        reload.name = "Native photo picker Cancel nach Relaunch"
        reload.lifetime = .keepAlways
        add(reload)
        app.buttons["Abbrechen"].tap()
    }

    /// Native PhotosPicker probe only: observes the real system hierarchy and does not select or persist an asset.
    func testInspectSystemPhotoPicker() throws {
        let store = "slot-photo-picker-\(UUID().uuidString)"
        let marker = XCTAttachment(string: "Native PhotosPicker probe; ALBUM_TEST_STORE=\(store); source=Eigenes Foto wählen; no asset selection")
        marker.name = "Native PhotosPicker startup marker"
        marker.lifetime = .keepAlways
        add(marker)

        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_DEMO_IMAGE_CHOICE"] = "1"
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Karte"
        app.launch()
        XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: 15))
        let startupAX = XCTAttachment(string: app.debugDescription)
        startupAX.name = "Native PhotosPicker startup AX"
        startupAX.lifetime = .keepAlways
        add(startupAX)

        let list = app.buttons["Liste ausklappen"]
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        list.tap()
        let details = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Details zu' AND label CONTAINS 'Café Louvre'" )).firstMatch
        XCTAssertTrue(details.waitForExistence(timeout: 10), "Der isolierte Bildwahl-Ort muss im Kartenblatt sichtbar sein")
        details.tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
        app.buttons["Bearbeiten"].tap()

        let ownPhoto = app.buttons["Eigenes Foto wählen"]
        for _ in 0..<8 where !ownPhoto.isHittable { app.swipeUp() }
        XCTAssertTrue(ownPhoto.waitForExistence(timeout: 5), "Die Editorquelle Eigenes Foto wählen muss exponiert sein")
        XCTAssertTrue(ownPhoto.isHittable, "Die Editorquelle Eigenes Foto wählen muss hittable sein")
        ownPhoto.tap()

        // PhotosPicker kann je iOS-Version in einem separaten Systemprozess oder als
        // systemverwaltetes Blatt erscheinen. Erst die beobachtete Hierarchie entscheidet.
        let systemCandidates = [
            XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow"),
            XCUIApplication(bundleIdentifier: "com.apple.PhotosUI")
        ]
        var pickerAX = ""
        for candidate in systemCandidates where candidate.wait(for: .runningForeground, timeout: 4) {
            pickerAX = candidate.debugDescription
            break
        }
        let hostAX = app.debugDescription
        let pickerVisibleInHost = hostAX.localizedCaseInsensitiveContains("photos")
            || hostAX.localizedCaseInsensitiveContains("fotos")
            || hostAX.localizedCaseInsensitiveContains("photospicker")
        XCTAssertTrue(!pickerAX.isEmpty || pickerVisibleInHost, "Nach Eigenes Foto wählen muss eine beobachtbare native Picker-Hierarchie erscheinen")

        let observedAX = XCTAttachment(string: pickerAX.isEmpty ? hostAX : pickerAX)
        observedAX.name = "Native PhotosPicker observed AX"
        observedAX.lifetime = .keepAlways
        add(observedAX)
        let observedScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        observedScreenshot.name = "Native PhotosPicker observed screenshot"
        observedScreenshot.lifetime = .keepAlways
        add(observedScreenshot)

        // Probe ends without tapping a filename, image, permission action, or Save.
        app.terminate()
    }
}
