import XCTest

/// Beta-Checkliste (Soll laut PLAN-BETA-CHECKLISTE.md).
/// Diese Tests definieren das Sollverhalten und sind heute teilweise rot.
/// Jeder Test läuft gegen einen eigenen, isolierten Test-Store.
final class BetaChecklistUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-beta-\(UUID().uuidString)"
        app.launchEnvironment["ALBUM_MY_NAME"] = "QA"
        app.launchEnvironment["ALBUM_TODAY"] = "2026-10-06"
        // Fixture-Store mit Prag-Beispielorten (wie NativePrototypeUITests).
        app.launchEnvironment["ALBUM_LEGACY_HOME_QA"] = "1"
        app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        return app
    }

    private func tap(_ id: String, in app: XCUIApplication, timeout: TimeInterval = 10) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Fehlt: \(id)\n\(app.debugDescription)")
        if button.exists { button.tap() }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIApplication().screenshot())
        attachment.name = "beta-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Ideen starten im Stapel; die Zeilenliste erscheint erst nach Tipp auf „Liste“.
    private func showIdeaList(_ app: XCUIApplication) {
        tap("native-ideas-list", in: app)
    }

    private func reveal(_ id: String, in app: XCUIApplication) {
        let element = app.buttons[id]
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Fehlt: \(id)\n\(app.debugDescription)")
        var tries = 0
        while !element.isHittable && tries < 6 { app.swipeUp(); tries += 1 }
    }

    private func openIdeas(_ app: XCUIApplication) {
        tap("native-trip-prag", in: app)
        tap("native-tab-ideas", in: app)
        showIdeaList(app)
        XCTAssertTrue(app.buttons["native-new-place"].waitForExistence(timeout: 10), app.debugDescription)
    }

    private func hittable(_ element: XCUIElement, timeout: TimeInterval = 6) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func anyElement(_ app: XCUIApplication, labelContains text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func ideaRow(titled title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "native-idea-", title)).firstMatch
    }

    // MARK: 1 Einfügen statt Tippen

    func test1_PasteAmountsAndLinkAreAccepted() {
        continueAfterFailure = true // alle Varianten einzeln berichten
        let app = launch()
        tap("native-trip-prag", in: app)

        // Neue Idee: Link ohne https. Soll laut PLAN-BETA-CHECKLISTE.md: Speichern aktiv.
        tap("native-tab-ideas", in: app)
        tap("native-new-place", in: app)
        let ideaTitle = app.textFields["PlaceEditor-Title"]
        XCTAssertTrue(ideaTitle.waitForExistence(timeout: 8), app.debugDescription)
        ideaTitle.tap(); ideaTitle.typeText("Link Test")
        let source = app.textFields["PlaceEditor-Source"]
        XCTAssertTrue(source.waitForExistence(timeout: 5), app.debugDescription)
        source.tap(); source.typeText("www.prague.eu")
        capture("paste-link")
        XCTAssertTrue(app.buttons["PlaceEditor-Save"].isEnabled, "Speichern bei „www.prague.eu“ nicht aktiv")
        tap("PlaceEditor-Cancel", in: app)
        if app.buttons["Verwerfen"].waitForExistence(timeout: 1) { app.buttons["Verwerfen"].tap() }
        XCTAssertTrue(app.buttons["native-tab-plan"].waitForExistence(timeout: 8), app.debugDescription)

        // Ausgaben: Beträge in vier Schreibweisen.
        tap("native-tab-plan", in: app)
        reveal("native-group-expenses", in: app)
        tap("native-group-expenses", in: app)
        let amounts = ["1.250,50 ", "12,50 €", "€ 12,50", "12.50"]
        for (index, amount) in amounts.enumerated() {
            let title = "Betrag\(index + 1)"
            tap("expenses-add", in: app)
            let titleField = app.textFields["expense-title"]
            XCTAssertTrue(titleField.waitForExistence(timeout: 5), app.debugDescription)
            titleField.tap(); titleField.typeText(title)
            let amountField = app.textFields["expense-amount"]
            amountField.tap(); amountField.typeText(amount)
            let save = app.buttons["expense-save"]
            XCTAssertTrue(save.isEnabled, "Speichern ist bei Betrag „\(amount)“ nicht aktiv")
            save.tap()
            // Soll: Betrag wird erkannt, das Formular schließt und die Ausgabe steht in der Liste.
            let row = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
            if !row.waitForExistence(timeout: 5) {
                capture("paste-amount-\(index + 1)-failed")
                XCTFail("Betrag „\(amount)“ wurde nicht erkannt (Ausgabe „\(title)“ fehlt in der Liste)")
                if app.buttons["Abbrechen"].exists { app.buttons["Abbrechen"].tap() }
                if app.buttons["Verwerfen"].waitForExistence(timeout: 1) { app.buttons["Verwerfen"].tap() }
            }
        }
        capture("paste-amounts")
    }

    // MARK: 2 Versehentlich löschen

    func test2_DeleteIdeaAsksBackOrOffersUndo() {
        let app = launch()
        openIdeas(app)
        let row = app.buttons["native-idea-example-letna"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), app.debugDescription)
        tap("Mehr für Letná Park", in: app)
        tap("Löschen", in: app)

        // Soll laut PLAN-BETA-CHECKLISTE.md: Rückfrage mit „Behalten“ oder „Rückgängig“ für einige Sekunden.
        let undo = app.buttons["Rückgängig"]
        let keep = app.buttons["Behalten"]
        let either = NSPredicate { _, _ in undo.exists || keep.exists }
        let found = XCTNSPredicateExpectation(predicate: either, object: nil)
        let result = XCTWaiter.wait(for: [found], timeout: 3)
        capture("delete-idea")
        XCTAssertEqual(result, .completed, "Weder Rückfrage („Behalten“) noch „Rückgängig“ nach Löschen\n\(app.debugDescription)")

        if undo.exists { undo.tap() } else if keep.exists { keep.tap() }
        XCTAssertTrue(app.buttons["native-idea-example-letna"].waitForExistence(timeout: 5), "Idee ist nach Behalten/Rückgängig nicht mehr da")
    }

    // MARK: 3 Formular aus Versehen schließen

    func test3_DiscardDialogProtectsFilledFormAndEmptyFormClosesFreely() {
        let app = launch()
        openIdeas(app)

        // Gefülltes Formular, Abbrechen.
        tap("native-new-place", in: app)
        let title = app.textFields["PlaceEditor-Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8), app.debugDescription)
        title.tap(); title.typeText("Beta Entwurf")
        tap("PlaceEditor-Cancel", in: app)
        // Soll laut PLAN-BETA-CHECKLISTE.md: „Änderungen verwerfen?“ mit „Weiter bearbeiten“.
        let keepEditing = app.buttons["Weiter bearbeiten"]
        let dialogShown = keepEditing.waitForExistence(timeout: 3)
        capture("discard-dialog-cancel")
        XCTAssertTrue(dialogShown, "Kein Dialog „Änderungen verwerfen?“ mit „Weiter bearbeiten“ nach Abbrechen\n\(app.debugDescription)")
        XCTAssertTrue(anyElement(app, labelContains: "Änderungen verwerfen?").exists, "Titel „Änderungen verwerfen?“ fehlt")
        keepEditing.tap()
        XCTAssertEqual(app.textFields["PlaceEditor-Title"].value as? String, "Beta Entwurf", "Text nach „Weiter bearbeiten“ verloren")

        // Nach unten wischen (Sheet-Geste).
        let bar = app.navigationBars.firstMatch
        let start = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 500)))
        let keepAfterSwipe = app.buttons["Weiter bearbeiten"]
        XCTAssertTrue(keepAfterSwipe.waitForExistence(timeout: 3), "Wischen schließt das gefüllte Formular ohne Rückfrage")
        keepAfterSwipe.tap()
        XCTAssertEqual(app.textFields["PlaceEditor-Title"].value as? String, "Beta Entwurf")

        // Leeres Formular schließt ohne Rückfrage.
        tap("PlaceEditor-Cancel", in: app)
        if app.buttons["Weiter bearbeiten"].waitForExistence(timeout: 2) { app.buttons["Weiter bearbeiten"].tap() }
        // Text entfernen, damit das Formular wieder leer ist.
        let field = app.textFields["PlaceEditor-Title"]
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        tap("PlaceEditor-Cancel", in: app)
        XCTAssertFalse(app.buttons["Weiter bearbeiten"].waitForExistence(timeout: 2), "Leeres Formular fragt trotzdem nach")
        XCTAssertTrue(app.buttons["native-new-place"].waitForExistence(timeout: 5), "Leeres Formular schließt nicht")
        capture("discard-empty-closed")
    }

    // MARK: 4 Öffnen, dann zurück

    func test4_ListKeepsPositionAfterEditorAndTabSwitch() {
        let app = launch()
        openIdeas(app)
        for _ in 0..<3 { app.swipeUp() }
        // Voraussetzung: wirklich gescrollt (Kopfzeile außerhalb).
        XCTAssertFalse(app.buttons["native-new-place"].isHittable, "Test-Voraussetzung: Liste ist nicht gescrollt")

        let screen = app.windows.firstMatch.frame
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "native-idea-"))
        var target: XCUIElement?
        for index in 0..<rows.count {
            let row = rows.element(boundBy: index)
            if row.isHittable, row.frame.midY > screen.height * 0.3, row.frame.midY < screen.height * 0.7 { target = row; break }
        }
        guard let row = target else { return XCTFail("Keine sichtbare Idee nach dem Scrollen\n\(app.debugDescription)") }
        let rowID = row.identifier
        let rowTitle = row.label.components(separatedBy: ", ").first ?? row.label
        capture("scrolled-before-edit")

        tap("Mehr für \(rowTitle)", in: app)
        tap("Bearbeiten", in: app)
        tap("PlaceEditor-Cancel", in: app)
        if app.buttons["Verwerfen"].waitForExistence(timeout: 1) { app.buttons["Verwerfen"].tap() }
        let same = app.buttons[rowID]
        XCTAssertTrue(hittable(same), "Nach Bearbeiten/Abbrechen ist „\(rowTitle)“ nicht mehr sichtbar\n\(app.debugDescription)")
        capture("after-editor")

        tap("native-tab-map", in: app)
        XCTAssertTrue(app.buttons["native-tab-ideas"].waitForExistence(timeout: 8))
        tap("native-tab-ideas", in: app)
        if app.buttons["native-ideas-list"].waitForExistence(timeout: 3) { app.buttons["native-ideas-list"].tap() }
        capture("after-tab-switch")
        XCTAssertTrue(hittable(app.buttons[rowID]), "Nach Tab-Wechsel ist „\(rowTitle)“ nicht mehr sichtbar (Liste springt zurück)")
    }

    // MARK: 5 Finden, was man gerade hinzugefügt hat

    func test5_FindNewIdeaVisibleWithoutScrolling() {
        let app = launch()
        openIdeas(app)
        tap("native-new-place", in: app)
        let title = app.textFields["PlaceEditor-Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8), app.debugDescription)
        title.tap(); title.typeText("Beta Neu Test")
        tap("PlaceEditor-Save", in: app)
        let throwButton = app.buttons["Einwurf-Knopf"]
        if throwButton.waitForExistence(timeout: 4) { throwButton.tap() }
        // Erst weiterprüfen, wenn Editor und Einwurf-Animation wirklich weg sind.
        let editorGone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["PlaceEditor-Save"])
        XCTAssertEqual(XCTWaiter.wait(for: [editorGone], timeout: 20), .completed, "Editor schließt nach Speichern nicht\n\(app.debugDescription)")
        XCTAssertTrue(app.buttons["native-new-place"].waitForExistence(timeout: 10), app.debugDescription)
        if app.buttons["native-ideas-list"].exists { app.buttons["native-ideas-list"].tap() }

        let row = ideaRow(titled: "Beta Neu Test", in: app)
        capture("new-idea")
        if !row.waitForExistence(timeout: 4) {
            // Liste ist lazy: Zeile existiert erst, wenn sie gescrollt wurde. Unterscheidet „unten“ von „fehlt“.
            var swipes = 0
            while !row.exists && swipes < 40 { app.swipeUp(velocity: .fast); swipes += 1 }
            capture("new-idea-after-scrolling")
            XCTAssertTrue(row.exists, "Neue Idee fehlt in der Liste (auch nach \(swipes) Wischern nicht gefunden)")
            XCTFail("Neue Idee landet unten: erst nach \(swipes) Wischern sichtbar, nicht ohne Scrollen")
            return
        }
        // Soll laut PLAN-BETA-CHECKLISTE.md: neue Idee ohne Scrollen sichtbar, mit „Neu“-Marke und „Idee hinzugefügt“.
        XCTAssertTrue(hittable(row, timeout: 3), "Neue Idee ist ohne Scrollen nicht sichtbar")
        let marker = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR label CONTAINS %@", "Neu", "Idee hinzugefügt")).firstMatch
        XCTAssertTrue(marker.exists, "Weder „Neu“-Marke noch „Idee hinzugefügt“ vorhanden")
    }
}
