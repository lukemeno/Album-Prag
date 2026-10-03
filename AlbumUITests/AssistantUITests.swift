import XCTest

final class AssistantUITests: XCTestCase {
    func testAssistantFixtureConversation() {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-assistant-ui-\(UUID().uuidString)"
        app.launchEnvironment["ALBUM_MY_NAME"] = "QA"
        app.launchEnvironment["ALBUM_ASSISTANT_FIXTURE"] = #"{"answer":"Morgen passt die Altstadt gut.","sources":[],"places":[],"plan":[],"preferences":[],"usage":{"used_usd":0,"limit_usd":10,"remaining_requests":99}}"#
        app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        if app.buttons["Los geht’s"].waitForExistence(timeout: 3) { app.buttons["Los geht’s"].tap() }
        let assistantButton = app.buttons["Reise-Assistent"]
        XCTAssertTrue(assistantButton.waitForExistence(timeout: 5))
        assistantButton.tap()
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
        XCTAssertFalse(app.buttons["Los geht’s"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Reise-Assistent"].waitForExistence(timeout: 5))
        app.buttons["Reise-Assistent"].tap()
        let input = app.textFields["assistant-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText("Hallo")
        app.buttons["assistant-send"].tap()
        XCTAssertTrue(app.staticTexts["Antwort aus dem Test"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Schließen"].waitForExistence(timeout: 3))
        app.buttons["Schließen"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Reise-Assistent"].waitForExistence(timeout: 5))
        app.buttons["Reise-Assistent"].tap()
        XCTAssertTrue(app.staticTexts["Antwort aus dem Test"].waitForExistence(timeout: 5))
    }
}
