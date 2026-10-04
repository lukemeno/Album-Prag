import XCTest

final class AssistantUITests: XCTestCase {
    func testPlaceProposalNeedsExplicitSaveAndPersistsAfterRestart() {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-assistant-save-\(UUID().uuidString)"
        app.launchEnvironment["ALBUM_EMPTY_TEST_STORE"] = "1"
        app.launchEnvironment["ALBUM_MY_NAME"] = "QA"
        app.launchEnvironment["ALBUM_ASSISTANT_FIXTURE"] = #"{"answer":"QA Ortsvorschlag.","sources":[],"places":[{"title":"QA Café manuell","address":"Prag","query":"QA Café manuell Prag"}],"plan":[],"preferences":[]}"#
        app.launch()
        let launcher = app.buttons["Reise-Assistent"]
        XCTAssertTrue(launcher.waitForExistence(timeout: 8))
        launcher.tap()
        let input = app.textFields["assistant-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText("Schlage einen Ort vor")
        app.buttons["assistant-send"].tap()
        XCTAssertTrue(app.staticTexts["QA Ortsvorschlag."].waitForExistence(timeout: 5))
        app.buttons["Schließen"].tap()
        app.tabBars.buttons["Ideen"].tap()
        XCTAssertTrue(app.staticTexts["Alles entschieden"].waitForExistence(timeout: 5), "Ein Vorschlag allein darf keine Idee speichern")
        launcher.tap()
        let save = app.buttons["Alle als Ideen speichern"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        if !save.isHittable { app.scrollViews.firstMatch.swipeUp() }
        save.tap()
        XCTAssertTrue(app.staticTexts["1 hinzugefügt"].waitForExistence(timeout: 5))
        app.buttons["Schließen"].tap()
        app.terminate()
        app.launchEnvironment["ALBUM_START_TAB"] = "Ideen"
        app.launch()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "QA Café manuell")).firstMatch.waitForExistence(timeout: 8))
    }

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
