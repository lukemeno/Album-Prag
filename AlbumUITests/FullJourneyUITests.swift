import XCTest
import UIKit

/// End-to-end journeys which cross more than one sheet or tab.  Every test uses
/// a caller-owned AlbumUITests store; without a prepared slot it skips rather
/// than opening or mutating the user's normal album.
final class FullJourneyUITests: XCTestCase {
    private let wait: TimeInterval = 12

    private func launchFixture(today: String = "2026-10-06", startTab: String = "Reise", demoMemories: Bool = false, dynamicType: String? = nil) throws -> XCUIApplication {
        let environment = ProcessInfo.processInfo.environment
        guard let configured = environment["ALBUM_JOURNEY_STORE"], configured.hasPrefix("slot-") else {
            throw XCTSkip("ALBUM_JOURNEY_STORE muss auf einen vorbereiteten slot-Store zeigen")
        }
        let store = demoMemories ? "slot-journey-memories-\(UUID().uuidString)" : configured

        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_TODAY"] = today
        app.launchEnvironment["ALBUM_START_TAB"] = startTab
        if let dynamicType { app.launchEnvironment["ALBUM_QA_DYNAMIC_TYPE"] = dynamicType }
        if let reduceMotion = environment["ALBUM_QA_REDUCE_MOTION"] {
            app.launchEnvironment["ALBUM_QA_REDUCE_MOTION"] = reduceMotion
        }
        if demoMemories {
            app.launchEnvironment["ALBUM_DEMO_MEMORIES"] = "1"
        }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Reise"].waitForExistence(timeout: wait))
        return app
    }

    private func rotate(_ app: XCUIApplication, _ orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        if orientation == .portrait {
            XCTAssertLessThan(window.frame.width, window.frame.height)
        } else {
            XCTAssertGreaterThan(window.frame.width, window.frame.height)
        }
    }

    private func restorePortrait() {
        XCUIDevice.shared.orientation = .portrait
    }

    private func attachAX(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = "\(name)-AX"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func revealVisitedToggle(_ app: XCUIApplication, _ toggle: XCUIElement, name: String) -> XCUIElement {
        let form = app.descendants(matching: .any).matching(identifier: "PlaceEditor-Form").firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 5), "Der benannte Ortseditor-Formularcontainer muss erreichbar sein")
        for _ in 0..<8 {
            if toggle.exists && toggle.isHittable { break }
            form.swipeUp()
        }
        XCTAssertTrue(toggle.isHittable, "\(name) muss nach dem Scrollen sichtbar und hittable sein")
        let nested = toggle.descendants(matching: .switch)
        XCTAssertEqual(nested.count, 1, "\(name) muss genau einen verschachtelten echten Switch enthalten")
        let control = nested.firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 3), "\(name) muss als echter verschachtelter Switch exponiert sein")
        XCTAssertTrue(control.isHittable, "\(name) muss als echter Switch hittable sein")
        XCTAssertTrue(toggle.frame.contains(control.frame), "Der echte Switch muss innerhalb der gelabelten Zeile liegen")
        attachAX(app, name: "\(name)-vor-Tap")
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "\(name)-vor-Tap"
        before.lifetime = .keepAlways
        add(before)
        return control
    }

    private func waitForSwitchValue(_ toggle: XCUIElement, _ value: String, name: String) {
        let changed = expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: toggle)
        wait(for: [changed], timeout: 3)
        XCTAssertEqual(toggle.value as? String, value, name)
    }

    func testTravelDocumentsEditCancelSaveAndNestedDismissalAcrossOrientations() throws {
        defer { restorePortrait() }
        let app = try launchFixture()

        let documents = app.buttons["Alle Reiseunterlagen"]
        XCTAssertTrue(documents.waitForExistence(timeout: wait))
        documents.tap()
        XCTAssertTrue(app.navigationBars["Unterlagen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["QA Hotel"].waitForExistence(timeout: 5), "Fixture-Reiseinformationen sind sichtbar")
        XCTAssertTrue(app.staticTexts["Luke"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Buchung QA-2026'")).firstMatch.exists)

        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight, .portrait] {
            rotate(app, orientation)
            XCTAssertTrue(app.navigationBars["Unterlagen"].exists)
            XCTAssertTrue(app.buttons["Schließen"].isHittable)
        }

        // Open the nested trip editor, exercise the keyboard, then cancel.
        app.buttons["Bearbeiten"].tap()
        XCTAssertTrue(app.navigationBars["Reisedaten"].waitForExistence(timeout: 5))
        let notes = app.textFields["TripEditor-Notes"]
        XCTAssertTrue(notes.waitForExistence(timeout: 5), "Reisedaten-Notizfeld ist erreichbar")
        let originalNotes = notes.value as? String ?? ""
        notes.tap()
        notes.typeText(" Journey")
        app.buttons["Abbrechen"].tap()
        XCTAssertTrue(app.navigationBars["Unterlagen"].waitForExistence(timeout: 5))
        app.buttons["Bearbeiten"].tap()
        XCTAssertTrue(app.navigationBars["Reisedaten"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["TripEditor-Notes"].value as? String, originalNotes, "Abbrechen verwirft die Notizänderung")
        app.buttons["Abbrechen"].tap()

        // Save a second edit, then dismiss the outer sheet.
        app.buttons["Bearbeiten"].tap()
        XCTAssertTrue(app.navigationBars["Reisedaten"].waitForExistence(timeout: 5))
        let editorNotes = app.textFields["TripEditor-Notes"]
        XCTAssertTrue(editorNotes.waitForExistence(timeout: 5))
        editorNotes.tap()
        editorNotes.typeText(" Saved")
        app.buttons["Speichern"].tap()
        XCTAssertTrue(app.navigationBars["Unterlagen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Saved'")).firstMatch.exists, "Speichern aktualisiert die Unterlagenansicht")
        app.buttons["Schließen"].tap()
        XCTAssertTrue(app.tabBars.buttons["Reise"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Alle Reiseunterlagen"].waitForExistence(timeout: 5))
        app.buttons["Alle Reiseunterlagen"].tap()
        XCTAssertTrue(app.navigationBars["Unterlagen"].waitForExistence(timeout: 5))
        app.buttons["Bearbeiten"].tap()
        XCTAssertTrue(app.navigationBars["Reisedaten"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.textFields["TripEditor-Notes"].value as? String)?.contains("Saved") == true, "Gespeicherte Notiz bleibt nach Relaunch erhalten")
        app.buttons["Abbrechen"].tap()
        app.buttons["Schließen"].tap()
    }

    func testPlaceEditorCancelSaveAndExplicitVisitedUndoThroughNestedSheets() throws {
        defer { restorePortrait() }
        let journeyRevision = XCTAttachment(string: "Journey revision: inner-switch-20261002-v1")
        journeyRevision.name = "Journey revision: inner-switch-20261002-v1"
        journeyRevision.lifetime = .keepAlways
        add(journeyRevision)
        print("Journey revision: inner-switch-20261002-v1")
        let app = try launchFixture(startTab: "Karte")
        XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: wait))

        let qaPlaceRow = app.buttons["place-row-qa-oldtown"]
        let placesList = app.descendants(matching: .any).matching(identifier: "map-places-list").firstMatch
        XCTAssertTrue(placesList.waitForExistence(timeout: 5), "Die benannte Ortsliste muss erreichbar sein")
        let qaPlaceDetails = app.buttons["Details zu Altstädter Ring"]
        for _ in 0..<8 where !qaPlaceDetails.isHittable { placesList.swipeDown() }
        XCTAssertTrue(qaPlaceRow.waitForExistence(timeout: 8), "Die vorbereitete QA-Ortszeile muss nach dem Rückscrollen erreichbar sein")
        XCTAssertTrue(qaPlaceDetails.waitForExistence(timeout: 5), "Die Detailaktion der QA-Ortszeile muss erreichbar sein")
        XCTAssertTrue(qaPlaceDetails.isHittable, "Die Detailaktion muss nach dem Rückscrollen sichtbar sein")
        qaPlaceDetails.tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))

        // Detail -> editor -> cancel must leave the detail sheet open.
        app.buttons["Bearbeiten"].tap()
        let title = app.textFields["PlaceEditor-Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let originalTitle = title.value as? String ?? ""
        title.tap()
        title.typeText(" cancelled")
        app.buttons["PlaceEditor-Cancel"].tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))

        // Re-open the editor and use the visible toggle to mark visited.
        app.buttons["Bearbeiten"].tap()
        XCTAssertEqual(app.textFields["PlaceEditor-Title"].value as? String, originalTitle, "Abbrechen verwirft die Titeländerung")
        let visited = app.switches["Schon besucht"]
        let visitedControl = revealVisitedToggle(app, visited, name: "Besucht aktivieren")
        XCTAssertEqual(visited.value as? String, "0", "Die Fixture startet mit einem unbesuchten Ort")
        XCTAssertEqual(visitedControl.value as? String, "0")
        visitedControl.tap()
        waitForSwitchValue(visitedControl, "1", name: "Besucht wird über den echten Toggle aktiviert")
        XCTAssertEqual(visited.value as? String, "1", "Das äußere AX-Label übernimmt den neuen Zustand")
        let afterActivate = XCTAttachment(screenshot: app.screenshot())
        afterActivate.name = "Besucht aktivieren-nach-Tap"
        afterActivate.lifetime = .keepAlways
        add(afterActivate)
        attachAX(app, name: "Besucht aktivieren-nach-Tap")
        app.buttons["PlaceEditor-Save"].tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
        let visitedTrack = app.descendants(matching: .any).matching(identifier: "Besucht-Spur").firstMatch
        XCTAssertTrue(visitedTrack.waitForExistence(timeout: 5))
        XCTAssertEqual(visitedTrack.label, "Besucht")

        // Persisted visited state must survive a relaunch before undo is attempted.
        app.buttons["Schließen"].tap()
        XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: 8))
        let relaunchedQAPlaceRow = app.buttons["place-row-qa-oldtown"]
        let relaunchedPlacesList = app.descendants(matching: .any).matching(identifier: "map-places-list").firstMatch
        XCTAssertTrue(relaunchedPlacesList.waitForExistence(timeout: 5), "Die benannte Ortsliste muss nach Relaunch erreichbar sein")
        let relaunchedQAPlaceDetails = app.buttons["Details zu Altstädter Ring"]
        for _ in 0..<8 where !relaunchedQAPlaceDetails.isHittable { relaunchedPlacesList.swipeDown() }
        XCTAssertTrue(relaunchedQAPlaceRow.waitForExistence(timeout: 8), "Nach Relaunch muss dieselbe QA-Ortszeile nach dem Rückscrollen erreichbar sein")
        XCTAssertTrue(relaunchedQAPlaceDetails.waitForExistence(timeout: 5), "Die Detailaktion derselben QA-Ortszeile muss nach Relaunch erreichbar sein")
        XCTAssertTrue(relaunchedQAPlaceDetails.isHittable, "Dieselbe Detailaktion muss nach dem Rückscrollen sichtbar sein")
        relaunchedQAPlaceDetails.tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
        let persistedTrack = app.descendants(matching: .any).matching(identifier: "Besucht-Spur").firstMatch
        XCTAssertTrue(persistedTrack.waitForExistence(timeout: 5))
        XCTAssertEqual(persistedTrack.label, "Besucht", "Besucht bleibt nach Relaunch erhalten")

        // Explicit undo: inspect the current detail, open editor again, turn it off, save.
        app.buttons["Bearbeiten"].tap()
        let undoVisited = app.switches["Schon besucht"]
        let undoControl = revealVisitedToggle(app, undoVisited, name: "Besucht zurücknehmen")
        XCTAssertEqual(undoVisited.value as? String, "1")
        XCTAssertEqual(undoControl.value as? String, "1")
        undoControl.tap()
        waitForSwitchValue(undoControl, "0", name: "Rückgängigmachen erfolgt über den aktuellen UI-Zustand")
        XCTAssertEqual(undoVisited.value as? String, "0", "Das äußere AX-Label übernimmt den Undo-Zustand")
        let afterUndo = XCTAttachment(screenshot: app.screenshot())
        afterUndo.name = "Besucht zurücknehmen-nach-Tap"
        afterUndo.lifetime = .keepAlways
        add(afterUndo)
        attachAX(app, name: "Besucht zurücknehmen-nach-Tap")
        app.buttons["PlaceEditor-Save"].tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
        let undoneTrack = app.descendants(matching: .any).matching(identifier: "Besucht-Spur").firstMatch
        XCTAssertTrue(undoneTrack.waitForExistence(timeout: 5))
        XCTAssertEqual(undoneTrack.label, "Als besucht markieren", "Der Besuch ist über den aktuellen Toggle zurückgenommen")

        // Keep the nested sheet path usable after the round trip in both landscapes.
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight, .portrait] {
            rotate(app, orientation)
            XCTAssertTrue(app.buttons["Schließen"].isHittable)
        }
        app.buttons["Schließen"].tap()
        XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: 5))
    }

    func testMemoriesJourneyRotatesAndDismisses() throws {
        defer { restorePortrait() }
        let app = try launchFixture(today: "2026-10-10", demoMemories: true)
        let memories = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Erinnerungen ansehen'" )).firstMatch
        XCTAssertTrue(memories.waitForExistence(timeout: wait))
        memories.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Reiseerinnerungen").firstMatch.waitForExistence(timeout: 5))
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight, .portrait] {
            rotate(app, orientation)
            XCTAssertTrue(app.buttons["Fertig"].isHittable)
        }
        app.buttons["Fertig"].tap()
        XCTAssertTrue(app.tabBars.buttons["Reise"].waitForExistence(timeout: 5))
    }

    func testMemoriesPhotoPullAndNestedReturn() throws {
        defer { restorePortrait() }
        let app = try launchFixture(today: "2026-10-10", demoMemories: true)
        let memories = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Erinnerungen ansehen'" )).firstMatch
        XCTAssertTrue(memories.waitForExistence(timeout: wait))
        memories.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Reiseerinnerungen").firstMatch.waitForExistence(timeout: 5))

        let stackedPhoto = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Foto von Letná'" )).firstMatch
        XCTAssertTrue(stackedPhoto.waitForExistence(timeout: 5), "Das Demo-Stapelfoto muss im Erinnerungsrückblick erreichbar sein")
        stackedPhoto.tap()
        let viewerPhoto = app.images["Foto von Letná"]
        XCTAssertTrue(viewerPhoto.waitForExistence(timeout: 5))
        let close = app.buttons["Foto schließen"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))

        let reduceMotion = ProcessInfo.processInfo.environment["ALBUM_QA_REDUCE_MOTION"] == "1"
        if reduceMotion {
            // PhotoViewer disables its pull gesture for Reduce Motion; X is the supported close path.
            attachAX(app, name: "Memories-Viewer-ReduceMotion-vor-X")
            close.tap()
            XCTAssertTrue(stackedPhoto.waitForExistence(timeout: 5), "X muss im Reduce-Motion-Zweig zum Erinnerungsstapel zurückkehren")
        } else {
            let beforeShortPull = XCTAttachment(screenshot: app.screenshot())
            beforeShortPull.name = "Memories-Viewer-vor-kurzem-Pull"
            beforeShortPull.lifetime = .keepAlways
            add(beforeShortPull)
            attachAX(app, name: "Memories-Viewer-vor-kurzem-Pull")

            let shortStart = viewerPhoto.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            shortStart.press(forDuration: 0.1,
                             thenDragTo: shortStart.withOffset(CGVector(dx: 0, dy: 60)),
                             withVelocity: .slow,
                             thenHoldForDuration: 0)
            sleep(1)
            XCTAssertTrue(close.exists, "Ein kurzer Pull darf den Memories-Viewer nicht schließen")
            XCTAssertTrue(viewerPhoto.exists, "Das Foto muss nach dem abgebrochenen Pull sichtbar bleiben")
            let afterShortPull = XCTAttachment(screenshot: app.screenshot())
            afterShortPull.name = "Memories-Viewer-nach-kurzem-Pull"
            afterShortPull.lifetime = .keepAlways
            add(afterShortPull)
            attachAX(app, name: "Memories-Viewer-nach-kurzem-Pull")

            let fullStart = viewerPhoto.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            fullStart.press(forDuration: 0.1,
                            thenDragTo: fullStart.withOffset(CGVector(dx: 0, dy: 220)),
                            withVelocity: .slow,
                            thenHoldForDuration: 0)
            let viewerClosed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: close)
            wait(for: [viewerClosed], timeout: 5)
            XCTAssertFalse(close.exists, "Der vollständige Pull muss den Vollbildviewer schließen")
            XCTAssertTrue(stackedPhoto.waitForExistence(timeout: 5), "Ein vollständiger Pull muss zum Erinnerungsstapel zurückkehren")
        }

        // Re-open and verify the explicit X path independently from the pull path.
        stackedPhoto.tap()
        XCTAssertTrue(app.buttons["Foto schließen"].waitForExistence(timeout: 5))
        app.buttons["Foto schließen"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Reiseerinnerungen").firstMatch.exists)

        // Erinnerungsort öffnen und das verschachtelte Ortsdetail wieder schließen.
        let place = app.buttons["Ort ansehen: Letná"]
        XCTAssertTrue(place.waitForExistence(timeout: 5))
        place.tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Schließen"].isHittable)
        app.buttons["Schließen"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Reiseerinnerungen").firstMatch.exists)

        app.buttons["Fertig"].tap()
        XCTAssertTrue(app.tabBars.buttons["Reise"].waitForExistence(timeout: 5))
    }

    func testLargeTypeMapAndEditorJourney() throws {
        defer { restorePortrait() }
        let app = try launchFixture(startTab: "Karte", dynamicType: "accessibility5")
        XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: wait))

        let listToggle = app.buttons["Liste ausklappen"]
        XCTAssertTrue(listToggle.waitForExistence(timeout: 5))
        listToggle.tap()
        let placesList = app.descendants(matching: .any).matching(identifier: "map-places-list").firstMatch
        XCTAssertTrue(placesList.waitForExistence(timeout: 5), "Die Kartenliste muss im Large-Type-Lauf benannt erreichbar sein")

        let headerControls = ["Tage planen", "Ordnen", "Liste schließen"]
        let qaPlaceDetails = app.buttons["Details zu Altstädter Ring"]
        func revealQADetails(_ phase: String) {
            var trace: [String] = []
            func dragPlaces(by deltaY: CGFloat, viewport: CGRect) {
                let window = app.windows.firstMatch.frame
                var safeViewport = viewport.intersection(window)
                let overlay = app.descendants(matching: .any).matching(identifier: "AdditionalDimmingOverlay").firstMatch
                if overlay.exists {
                    let overlayFrame = overlay.frame
                    let overlapsHorizontally = overlayFrame.maxX > safeViewport.minX && overlayFrame.minX < safeViewport.maxX
                    let coversBottom = overlayFrame.minY > safeViewport.minY &&
                        overlayFrame.minY < safeViewport.maxY &&
                        overlayFrame.maxY >= safeViewport.maxY
                    if overlapsHorizontally && coversBottom {
                        safeViewport = CGRect(x: safeViewport.minX,
                                              y: safeViewport.minY,
                                              width: safeViewport.width,
                                              height: overlayFrame.minY - safeViewport.minY - 12)
                    }
                }
                guard viewport.width.isFinite, viewport.height.isFinite, viewport.width > 0, viewport.height > 0,
                      safeViewport.width.isFinite, safeViewport.height.isFinite,
                      safeViewport.width > 0, safeViewport.height > 0 else {
                    trace.append("drag skipped originalViewport=\(viewport) safeViewport=\(safeViewport)")
                    return
                }
                let maxDistance = safeViewport.height * 0.6
                guard maxDistance >= 36 else {
                    trace.append("drag skipped safeViewportTooSmall originalViewport=\(viewport) safeViewport=\(safeViewport)")
                    return
                }
                let startY: CGFloat = deltaY < 0 ? 0.8 : 0.2
                let startAbsoluteY = safeViewport.minY + safeViewport.height * startY
                let startNormalizedY = (startAbsoluteY - viewport.minY) / viewport.height
                let start = placesList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startNormalizedY))
                let bounded = min(max(abs(deltaY), 36), maxDistance)
                let signed = deltaY < 0 ? -bounded : bounded
                start.press(forDuration: 0.05,
                            thenDragTo: start.withOffset(CGVector(dx: 0, dy: signed)),
                            withVelocity: .slow,
                            thenHoldForDuration: 0)
                trace.append("drag dy=\(signed) startY=\(startY) startAbsoluteY=\(startAbsoluteY) originalViewport=\(viewport) safeViewport=\(safeViewport)")
            }
            func addScreenshot(_ suffix: String) {
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "Large-Type-\(phase)-\(suffix)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
            addScreenshot("start")
            for attempt in 0..<8 where !qaPlaceDetails.isHittable {
                let viewport = placesList.frame
                let target = qaPlaceDetails.frame
                let overlay = app.descendants(matching: .any).matching(identifier: "AdditionalDimmingOverlay").firstMatch
                let overlayFrame = overlay.exists ? String(describing: overlay.frame) : "absent"
                trace.append("attempt \(attempt): viewport=\(viewport) target=\(target) exists=\(qaPlaceDetails.exists) hittable=\(qaPlaceDetails.isHittable) overlay=\(overlayFrame)")
                if qaPlaceDetails.exists {
                    if target.minY < viewport.minY {
                        dragPlaces(by: viewport.minY - target.minY + 12, viewport: viewport)
                        continue
                    }
                    if target.maxY > viewport.maxY {
                        dragPlaces(by: -(target.maxY - viewport.maxY + 12), viewport: viewport)
                        continue
                    }
                }
                // Ist die heutige Sektion sichtbar, liegt Altstädter Ring davor;
                // andernfalls bringt ein begrenztes Hochscrollen die Lazy-Zeile hervor.
                let todayHeader = app.staticTexts.matching(
                    NSPredicate(format: "label BEGINSWITH 'Dienstag, 6. Oktober'")
                ).firstMatch
                if todayHeader.isHittable {
                    dragPlaces(by: viewport.height * 0.5, viewport: viewport)
                } else {
                    dragPlaces(by: -(viewport.height * 0.5), viewport: viewport)
                }
            }
            let finalViewport = placesList.frame
            let finalTarget = qaPlaceDetails.frame
            trace.append("final: viewport=\(finalViewport) target=\(finalTarget) exists=\(qaPlaceDetails.exists) hittable=\(qaPlaceDetails.isHittable)")
            let traceAttachment = XCTAttachment(string: trace.joined(separator: "\n"))
            traceAttachment.name = "Large-Type-\(phase)-Reveal-Trace"
            traceAttachment.lifetime = .keepAlways
            add(traceAttachment)
            if !qaPlaceDetails.isHittable {
                addScreenshot("failed")
            }
        }
        for (orientation, name) in [
            (UIDeviceOrientation.portrait, "Portrait"),
            (.landscapeLeft, "Landscape links"),
            (.landscapeRight, "Landscape rechts"),
            (.portrait, "Portrait zurück")
        ] {
            rotate(app, orientation)
            let compactMenu = app.buttons["Listenaktionen"]
            if compactMenu.exists {
                XCTAssertTrue(compactMenu.isHittable, "Listenaktionen muss in \(name) hittable sein")
                XCTAssertGreaterThanOrEqual(compactMenu.frame.width, 44, "Listenaktionen muss in \(name) mindestens 44pt breit sein")
                XCTAssertGreaterThanOrEqual(compactMenu.frame.height, 44, "Listenaktionen muss in \(name) mindestens 44pt hoch sein")
                let compactClose = app.buttons["Liste schließen"]
                XCTAssertTrue(compactClose.isHittable, "Liste schließen muss in \(name) hittable sein")
                XCTAssertGreaterThanOrEqual(compactClose.frame.width, 44, "Liste schließen muss in \(name) mindestens 44pt breit sein")
                XCTAssertGreaterThanOrEqual(compactClose.frame.height, 44, "Liste schließen muss in \(name) mindestens 44pt hoch sein")
                XCTAssertGreaterThanOrEqual(placesList.frame.height, 100, "Die Large-Type-Liste muss in \(name) sichtbar nutzbare Höhe haben")
                revealQADetails(name + "-vor-Menue")
                XCTAssertTrue(qaPlaceDetails.waitForExistence(timeout: 8), "Die QA-Detailaktion muss in \(name) im gemeinsamen Listen-ScrollView existieren")
                XCTAssertTrue(qaPlaceDetails.isHittable, "Die QA-Detailaktion muss in \(name) vor dem Menü sichtbar sein")
                compactMenu.tap()
                for label in ["Tage planen", "Ordnen"] {
                    let action = app.buttons[label]
                    XCTAssertTrue(action.waitForExistence(timeout: 5), "\(label) muss im Landscape-Menü vorhanden sein")
                    XCTAssertTrue(action.isHittable, "\(label) muss im Landscape-Menü hittable sein")
                }
                // Ordnen öffnet keinen zusätzlichen Planer; Menü und Editiermodus bleiben testbar.
                app.buttons["Ordnen"].tap()
                XCTAssertTrue(app.buttons["Fertig"].waitForExistence(timeout: 5))
                app.buttons["Fertig"].tap()
            } else {
                for label in headerControls {
                    let control = app.buttons[label]
                    XCTAssertTrue(control.waitForExistence(timeout: 5), "\(label) muss in \(name) vorhanden sein")
                    XCTAssertTrue(control.isHittable, "\(label) muss in \(name) hittable sein")
                    XCTAssertGreaterThanOrEqual(control.frame.width, 44, "\(label) muss in \(name) mindestens 44pt breit sein")
                    XCTAssertGreaterThanOrEqual(control.frame.height, 44, "\(label) muss in \(name) mindestens 44pt hoch sein")
                }
            }
            if orientation != .portrait {
                XCTAssertGreaterThanOrEqual(placesList.frame.height, 100, "Die Large-Type-Liste muss in \(name) sichtbar nutzbare Höhe haben")
                revealQADetails(name + "-nach-Menue")
                XCTAssertTrue(qaPlaceDetails.waitForExistence(timeout: 8), "Die QA-Detailaktion muss in \(name) im gemeinsamen Listen-ScrollView existieren")
                XCTAssertTrue(qaPlaceDetails.isHittable, "Die QA-Detailaktion muss in \(name) nach begrenztem Rückscrollen sichtbar sein")
            }
            attachAX(app, name: "Large-Type-\(name)")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Large-Type-\(name)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }

        revealQADetails("Portrait-Editor")
        XCTAssertTrue(qaPlaceDetails.waitForExistence(timeout: 8), "Die konkrete QA-Detailaktion muss nach dem Listen-Rückscrollen erreichbar sein")
        XCTAssertTrue(qaPlaceDetails.isHittable, "Die konkrete QA-Detailaktion muss sichtbar sein")
        let qaPlaceRow = app.buttons["place-row-qa-oldtown"]
        XCTAssertTrue(qaPlaceRow.waitForExistence(timeout: 8), "Die QA-Zeile muss nach dem gezielten Scrollen exponiert sein")
        XCTAssertTrue(qaPlaceRow.label.contains("Altstädter Ring"), "Der Titel der QA-Zeile muss im AX-Label erreichbar bleiben")
        XCTAssertTrue(qaPlaceRow.label.contains("Sehenswert"), "Die Metadaten der QA-Zeile müssen im AX-Label erreichbar bleiben")
        qaPlaceDetails.tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5))
        app.buttons["Bearbeiten"].tap()
        let title = app.textFields["PlaceEditor-Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(title.isHittable, "Der Editor-Titel muss in Large Type erreichbar bleiben")
        let cancel = app.buttons["PlaceEditor-Cancel"].exists ? app.buttons["PlaceEditor-Cancel"] : app.buttons["Abbrechen"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Der Editor muss einen eindeutigen Abbrechen-Button exponieren")
        XCTAssertTrue(cancel.isHittable, "Abbrechen muss in Large Type hittable sein")
        cancel.tap()
        XCTAssertTrue(app.buttons["Bearbeiten"].waitForExistence(timeout: 5), "Abbrechen muss zum Ortsdetail zurückkehren")
    }
}
