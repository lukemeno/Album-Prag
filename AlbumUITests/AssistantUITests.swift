import XCTest

final class AssistantUITests: XCTestCase {
    private func openTripIfNeeded(_ app: XCUIApplication) {
        let trip = app.buttons["native-trip-prag"]
        if trip.waitForExistence(timeout: 3) { trip.tap() }
    }

    /// Der Assistent öffnet über das Bogen-Menü: FAB → „Reise fragen“ → Untermenü → „Reise fragen“.
    private func openAssistant(_ app: XCUIApplication) {
        let fab = app.buttons["native-fab"]
        XCTAssertTrue(fab.waitForExistence(timeout: 5))
        fab.tap()
        let ai = app.buttons["native-fan-ai"]
        XCTAssertTrue(ai.waitForExistence(timeout: 5))
        ai.tap()
        let direct = app.buttons["native-fan-sub-ai"]
        XCTAssertTrue(direct.waitForExistence(timeout: 5))
        direct.tap()
    }

    func testAssistantFixtureConversation() {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-assistant-ui-\(UUID().uuidString)"
        app.launchEnvironment["ALBUM_MY_NAME"] = "QA"
        app.launchEnvironment["ALBUM_ASSISTANT_FIXTURE"] = #"{"answer":"Morgen passt die Altstadt gut.","sources":[],"places":[],"plan":[],"preferences":[],"usage":{"used_usd":0,"limit_usd":10,"remaining_requests":99}}"#
        app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        openTripIfNeeded(app)

        if app.buttons["Los geht’s"].waitForExistence(timeout: 3) { app.buttons["Los geht’s"].tap() }
        openAssistant(app)
        let input = app.textFields["assistant-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText("Was passt jetzt?")
        app.buttons["assistant-send"].tap()
        XCTAssertTrue(app.staticTexts["Morgen passt die Altstadt gut."].waitForExistence(timeout: 5))
    }

    func testAssistantKeepsPrivateHistoryAfterCloseAndRelaunch() {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-assistant-history-\(UUID().uuidString)"
        app.launchEnvironment["ALBUM_MY_NAME"] = "QA"
        app.launchEnvironment["ALBUM_ASSISTANT_FIXTURE"] = "Antwort aus dem Test"
        app.launch()
        openTripIfNeeded(app)
        XCTAssertFalse(app.buttons["Los geht’s"].waitForExistence(timeout: 3))
        openAssistant(app)
        let input = app.textFields["assistant-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText("Hallo")
        app.buttons["assistant-send"].tap()
        XCTAssertTrue(app.staticTexts["Antwort aus dem Test"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Schließen"].waitForExistence(timeout: 3))
        app.buttons["Schließen"].tap()
        app.terminate(); app.launch()
        openTripIfNeeded(app)
        openAssistant(app)
        XCTAssertTrue(app.staticTexts["Antwort aus dem Test"].waitForExistence(timeout: 5))
    }
}
