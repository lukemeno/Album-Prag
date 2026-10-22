import XCTest

final class NativePrototypeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(reduced: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-native-port-\(UUID().uuidString)"
        app.launchEnvironment["ALBUM_MY_NAME"] = "QA"
        app.launchEnvironment["ALBUM_TODAY"] = "2026-10-06"
        app.launchEnvironment["ALBUM_ASSISTANT_FIXTURE"] = "Antwort aus dem Testalbum."
        if reduced { app.launchEnvironment["ALBUM_QA_REDUCE_MOTION"] = "1" }
        app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        return app
    }

    private func tap(_ id: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Fehlt: \(id)", file: file, line: line)
        XCTAssertEqual(app.buttons.matching(identifier: id).count, 1, app.debugDescription, file: file, line: line)
        if button.exists { button.tap() }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIApplication().screenshot())
        attachment.name = "native-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testHomeAndTripTabs() {
        let app = launch()
        XCTAssertTrue(app.buttons["native-trip-prag"].waitForExistence(timeout: 10))
        capture("home")
        tap("native-trip-prag", in: app)
        XCTAssertTrue(app.buttons["native-tab-plan"].waitForExistence(timeout: 8))
        capture("plan")
        tap("native-tab-ideas", in: app)
        capture("ideas")
        tap("native-tab-map", in: app)
        capture("map")
        tap("native-tab-group", in: app)
        XCTAssertTrue(app.buttons["native-group-expenses"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["native-group-documents"].exists)
        XCTAssertTrue(app.buttons["native-group-memories"].exists)
        capture("group")
        tap("native-group-documents", in: app)
        XCTAssertTrue(app.navigationBars["Unterlagen"].exists || app.staticTexts["Unterlagen"].waitForExistence(timeout: 5))
        capture("documents")
    }

    func testFanOpensDocumentsAndCanReturn() {
        let app = launch(reduced: true)
        tap("native-trip-prag", in: app)
        tap("native-fab", in: app)
        capture("fan")
        tap("native-fan-doc", in: app)
        XCTAssertTrue(app.buttons["Schließen"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Schließen"].tap()
        XCTAssertTrue(app.buttons["native-fab"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["native-fan-doc"].exists)
    }

    func testHoldAndDragFromFabToDocuments() {
        let app = launch()
        tap("native-trip-prag", in: app)
        let fab = app.buttons["native-fab"]
        XCTAssertTrue(fab.waitForExistence(timeout: 5))
        let center = fab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.45, thenDragTo: center.withOffset(CGVector(dx: -170, dy: 0)))
        XCTAssertTrue(app.buttons["Schließen"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.navigationBars["Unterlagen"].exists || app.staticTexts["Unterlagen"].exists)
        capture("fan-drag-documents")
    }

    func testFanSuggestionUsesRealAssistantSessionWithFixture() {
        let app = launch()
        tap("native-trip-prag", in: app)
        tap("native-fab", in: app)
        tap("native-fan-ai", in: app)
        XCTAssertTrue(app.buttons["native-fan-sub-food"].waitForExistence(timeout: 5))
        capture("fan-submenu")
        tap("native-fan-sub-food", in: app)
        XCTAssertTrue(app.staticTexts["Antwort aus dem Testalbum."].waitForExistence(timeout: 12))
        capture("assistant")
    }

    func testExpensePersistsAcrossRelaunch() {
        let app = launch()
        tap("native-trip-prag", in: app)
        tap("native-tab-group", in: app)
        tap("native-group-expenses", in: app)
        tap("expenses-add", in: app)
        let title = app.textFields["expense-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Testrechnung")
        let amount = app.textFields["expense-amount"]
        amount.tap(); amount.typeText("1.234,56")
        tap("expense-save", in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Testrechnung")).firstMatch.waitForExistence(timeout: 5))
        capture("expenses")
        app.terminate(); app.launch()
        tap("native-trip-prag", in: app)
        tap("native-tab-group", in: app)
        tap("native-group-expenses", in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Testrechnung")).firstMatch.waitForExistence(timeout: 5))
    }

    func testApprovalDoesNotPlanUntilDayIsChosen() {
        let app = launch()
        tap("native-trip-prag", in: app)
        tap("native-tab-ideas", in: app)
        tap("Mehr für Letná Park", in: app)
        tap("Für mich", in: app)
        XCTAssertTrue(app.buttons["native-idea-example-letna"].exists)
        tap("native-tab-plan", in: app)
        XCTAssertFalse(app.staticTexts["Letná Park"].exists)
        tap("native-tab-ideas", in: app)
        tap("Mehr für Letná Park", in: app)
        tap("Auf Tag legen", in: app)
        tap("native-day-2026-10-06", in: app)
        tap("native-tab-plan", in: app)
        XCTAssertTrue(app.staticTexts["Letná Park"].waitForExistence(timeout: 5))
        capture("explicit-day-plan")
        app.terminate(); app.launch()
        tap("native-trip-prag", in: app)
        XCTAssertTrue(app.staticTexts["Letná Park"].waitForExistence(timeout: 5))
    }

    func testExpenseEditDeleteAndRelaunch() {
        let app = launch()
        func openExpenses() {
            tap("native-trip-prag", in: app)
            tap("native-tab-group", in: app)
            tap("native-group-expenses", in: app)
        }
        func replace(_ field: XCUIElement, with value: String) {
            field.tap()
            let old = field.value as? String ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
            field.typeText(value)
        }
        openExpenses()
        tap("expenses-add", in: app)
        app.textFields["expense-title"].tap()
        app.textFields["expense-title"].typeText("Korrekturtest")
        app.textFields["expense-amount"].tap()
        app.textFields["expense-amount"].typeText("12,50")
        tap("expense-save", in: app)
        tap("Aktionen für Korrekturtest", in: app)
        tap("Ausgabe Korrekturtest bearbeiten", in: app)
        XCTAssertEqual(app.textFields["expense-title"].value as? String, "Korrekturtest")
        replace(app.textFields["expense-title"], with: "Korrigiert")
        replace(app.textFields["expense-amount"], with: "20,00")
        tap("expense-save", in: app)
        capture("expense-edited")
        app.terminate(); app.launch()
        openExpenses()
        tap("Aktionen für Korrigiert", in: app)
        tap("Ausgabe Korrigiert bearbeiten", in: app)
        XCTAssertEqual(app.textFields["expense-amount"].value as? String, "20,00")
        tap("Abbrechen", in: app)
        tap("Aktionen für Korrigiert", in: app)
        tap("Ausgabe Korrigiert löschen", in: app)
        let confirmation = app.buttons.matching(identifier: "expense-delete-confirm").firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
        XCTAssertTrue(app.staticTexts["Noch keine Ausgabe eingetragen"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        openExpenses()
        XCTAssertTrue(app.staticTexts["Noch keine Ausgabe eingetragen"].waitForExistence(timeout: 5))
        capture("expense-deleted")
    }

    func testMemoriesHasSeparateCameraAndLibraryActions() {
        let app = launch()
        tap("native-trip-prag", in: app)
        tap("native-tab-group", in: app)
        tap("native-group-memories", in: app)
        XCTAssertTrue(app.buttons["memories-camera"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["memories-library"].exists)
        capture("memories")
    }
}
