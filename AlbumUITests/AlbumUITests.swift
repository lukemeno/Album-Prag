import XCTest

final class AlbumUITests: XCTestCase {
    func testCreateIdeaAndPersistence() {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "ui-" + UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["Idee hinzufügen"].waitForExistence(timeout: 15))
        app.buttons["Idee hinzufügen"].tap()
        let title = app.textFields["Name der Idee"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Unser Testcafe")
        app.buttons["Speichern"].tap()
        app.terminate(); app.launch()
        app.buttons["Inbox"].tap()
        XCTAssertTrue(app.buttons["ZURÜCKLEGEN"].waitForExistence(timeout: 5))
        let ticket = app.otherElements["Inbox-Ticket"]
        XCTAssertTrue(ticket.waitForExistence(timeout: 5))
        ticket.swipeLeft()
        XCTAssertTrue(app.buttons["Letzte Entscheidung rückgängig"].waitForExistence(timeout: 5))
        for _ in 0..<2 { app.buttons["ZURÜCKLEGEN"].tap() }
        XCTAssertTrue(app.buttons["Idee bearbeiten"].waitForExistence(timeout: 5))
        app.terminate(); app.launch(); app.buttons["Inbox"].tap()
        XCTAssertTrue(app.buttons["Idee bearbeiten"].waitForExistence(timeout: 5))
        app.buttons["ZURÜCKLEGEN"].tap()
        XCTAssertTrue(app.buttons["Letzte Entscheidung rückgängig"].exists)
        app.buttons["Letzte Entscheidung rückgängig"].tap()
        app.buttons["Karte"].tap()
        XCTAssertTrue(app.staticTexts["Prag auf der Karte"].waitForExistence(timeout: 5))
    }
}
