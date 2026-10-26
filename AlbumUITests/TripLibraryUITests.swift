import XCTest

/// Focused UI coverage for the empty-library and multi-trip entry points.
/// The normal product launch intentionally has no starter album; all data in
/// this test is created through the visible library UI.
final class TripLibraryUITests: XCTestCase {
    private let slot = "library-ui-\(UUID().uuidString)"

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(withName: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = slot
        app.launchEnvironment["ALBUM_EMPTY_TEST_STORE"] = "1"
        app.launchEnvironment["ALBUM_LIBRARY_QA"] = "1"
        if withName { app.launchEnvironment["ALBUM_MY_NAME"] = "QA" }
        app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        return app
    }

    private func tap(_ id: String, in app: XCUIApplication, timeout: TimeInterval = 8) {
        let element = app.buttons[id]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Fehlt: \(id)\n\(app.debugDescription)")
        element.tap()
    }

    private func capture(_ name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "trip-library-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func create(_ title: String, destination: String, in app: XCUIApplication) {
        tap("library-create-trip", in: app)
        let titleField = app.textFields["trip-create-title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        let destinationField = app.textFields["trip-create-destination"]
        destinationField.tap()
        destinationField.typeText(destination)
        tap("trip-create-save", in: app)
    }

    func testEmptyLibraryCreateCancelAndSwitchTrips() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Noch keine Reise"].waitForExistence(timeout: 8), app.debugDescription)
        capture("empty-library", from: app)

        tap("library-create-trip-empty", in: app)
        XCTAssertTrue(app.buttons["trip-create-cancel"].waitForExistence(timeout: 4))
        capture("create-form", from: app)
        tap("trip-create-cancel", in: app)
        XCTAssertTrue(app.staticTexts["Noch keine Reise"].exists)

        create("Paris im Frühling", destination: "Paris", in: app)
        tap("trip-back-library", in: app)
        create("Berlin im Herbst", destination: "Berlin", in: app)

        tap("trip-back-library", in: app)
        let paris = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "library-trip-", "Paris")).firstMatch
        let berlin = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "library-trip-", "Berlin")).firstMatch
        XCTAssertTrue(paris.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(berlin.exists, app.debugDescription)
        capture("two-trip-cards", from: app)
        berlin.tap()
        XCTAssertTrue(app.buttons["native-tab-plan"].waitForExistence(timeout: 8), app.debugDescription)

        tap("trip-back-library", in: app)
        XCTAssertTrue(paris.waitForExistence(timeout: 8), app.debugDescription)
        paris.tap()
        XCTAssertTrue(app.buttons["native-tab-plan"].waitForExistence(timeout: 8), app.debugDescription)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["native-tab-plan"].waitForExistence(timeout: 8), app.debugDescription)
    }

    func testTripIdeasRemainIsolatedWhenSwitchingAndRelaunching() {
        let app = launch()
        create("Paris", destination: "Paris", in: app)
        tap("native-tab-ideas", in: app)
        tap("native-new-place", in: app)
        let title = app.textFields["PlaceEditor-Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), app.debugDescription)
        title.tap()
        title.typeText("Nur in Paris")
        tap("PlaceEditor-Save", in: app)
        let throwButton = app.buttons["Einwurf-Knopf"]
        if throwButton.waitForExistence(timeout: 4) { throwButton.tap() }
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Nur in Paris")).firstMatch.waitForExistence(timeout: 8), app.debugDescription)
        capture("paris-idea-retained", from: app)

        tap("trip-back-library", in: app)
        create("Berlin", destination: "Berlin", in: app)
        tap("native-tab-ideas", in: app)
        XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Nur in Paris")).firstMatch.waitForExistence(timeout: 2))

        tap("trip-back-library", in: app)
        let paris = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "library-trip-", "Paris")).firstMatch
        XCTAssertTrue(paris.waitForExistence(timeout: 8), app.debugDescription)
        paris.tap()
        tap("native-tab-ideas", in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Nur in Paris")).firstMatch.waitForExistence(timeout: 8), app.debugDescription)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["native-tab-ideas"].waitForExistence(timeout: 8), app.debugDescription)
        tap("native-tab-ideas", in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Nur in Paris")).firstMatch.waitForExistence(timeout: 8), app.debugDescription)
    }

    func testFreshTripPromptsForNameBeforePlanIsUsable() {
        let app = launch(withName: false)
        create("Name-Test", destination: "Wien", in: app)
        XCTAssertTrue(app.staticTexts["Wie heißt du?"].waitForExistence(timeout: 8), app.debugDescription)
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
        field.tap()
        field.typeText("Alex")
        tap("Los geht’s", in: app)
        XCTAssertTrue(app.buttons["native-tab-plan"].waitForExistence(timeout: 8), app.debugDescription)
    }
}
