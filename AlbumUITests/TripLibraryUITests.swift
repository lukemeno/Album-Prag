import XCTest
import UIKit

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

    /// Ideen starten im Stapel; die Liste gibt es erst nach Tipp auf „Liste“.
    /// Bei leerem Ideen-Bestand (Leerzustand) existiert der Umschalter nicht.
    private func showIdeaListIfAvailable(in app: XCUIApplication) {
        let list = app.buttons["native-ideas-list"]
        if list.waitForExistence(timeout: 3) { list.tap() }
    }

    private func capture(_ name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "trip-library-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Neue Reise: nur „Wohin geht's?“; ohne `withDates` bewusst „Weiß ich noch nicht“.
    private func create(_ title: String, destination: String, withDates: Bool = false, in app: XCUIApplication) {
        let plus = app.buttons["library-create-trip"]
        tap(plus.waitForExistence(timeout: 3) ? "library-create-trip" : "library-create-trip-empty", in: app)
        let destinationField = app.textFields["trip-create-destination"]
        XCTAssertTrue(destinationField.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["trip-create-title"].exists, "Beim Anlegen gibt es nur ein Feld")
        destinationField.tap()
        destinationField.typeText(destination)
        if !withDates { tap("Weiß ich noch nicht", in: app) }
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
        XCTAssertTrue(app.buttons["native-new-place"].waitForExistence(timeout: 8), app.debugDescription)
        showIdeaListIfAvailable(in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Nur in Paris")).firstMatch.waitForExistence(timeout: 8), app.debugDescription)
        capture("paris-idea-retained", from: app)

        tap("trip-back-library", in: app)
        create("Berlin", destination: "Berlin", in: app)
        tap("native-tab-ideas", in: app)
        showIdeaListIfAvailable(in: app)
        XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Nur in Paris")).firstMatch.waitForExistence(timeout: 2))

        tap("trip-back-library", in: app)
        let paris = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "library-trip-", "Paris")).firstMatch
        XCTAssertTrue(paris.waitForExistence(timeout: 8), app.debugDescription)
        paris.tap()
        tap("native-tab-ideas", in: app)
        showIdeaListIfAvailable(in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Nur in Paris")).firstMatch.waitForExistence(timeout: 8), app.debugDescription)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["native-tab-ideas"].waitForExistence(timeout: 8), app.debugDescription)
        tap("native-tab-ideas", in: app)
        showIdeaListIfAvailable(in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Nur in Paris")).firstMatch.waitForExistence(timeout: 8), app.debugDescription)
    }

    /// Paket 3: Eine Reise ohne Zeitraum fragt „Wann fahrt ihr?“; der Zeitraum lässt sich nachträglich
    /// festlegen, danach gibt es den Reiseplan, und die Übersicht zeigt den Zeitraum – auch nach Neustart.
    func testTripDatesCanBeSetAfterCreation() {
        let app = launch()
        create("Lissabon", destination: "Lissabon", in: app)
        XCTAssertTrue(app.staticTexts["Wann fahrt ihr?"].waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertFalse(app.buttons["native-open-dayplan"].exists, "Ohne Zeitraum kein leerer Reiseplan")
        XCTAssertFalse(app.buttons["native-new-place"].exists, "Im Reise-Tab gibt es kein + mehr")

        tap("native-set-dates", in: app)
        XCTAssertTrue(app.navigationBars["Reise bearbeiten"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["trip-create-title"].value as? String, "Lissabon", "Bearbeiten startet mit den Werten der Reise")
        XCTAssertTrue(app.buttons["Mit Daten"].isSelected, "„Zeitraum festlegen“ öffnet mit gewähltem Zeitraum")
        tap("trip-create-save", in: app)

        XCTAssertTrue(app.buttons["native-open-dayplan"].waitForExistence(timeout: 5), "Mit Zeitraum gibt es den Reiseplan")
        XCTAssertFalse(app.staticTexts["Wann fahrt ihr?"].exists)
        capture("dates-set", from: app)

        tap("trip-back-library", in: app)
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "library-trip-", "Lissabon")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertFalse(card.label.contains("Zeitraum offen"), "Die Übersicht übernimmt den Zeitraum: \(card.label)")

        app.terminate()
        let relaunched = launch()
        // Nach dem Neustart öffnet die App die zuletzt benutzte Reise; zurück zur Übersicht.
        tap("trip-back-library", in: relaunched)
        let again = relaunched.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "library-trip-", "Lissabon")).firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 8))
        XCTAssertFalse(again.label.contains("Zeitraum offen"))
    }

    /// Paket 3: Aus der geöffneten Reise heraus löschen – derselbe Ablauf wie in der Übersicht, danach „Deine Reisen“.
    func testDeleteTripFromInsideTheTrip() {
        let app = launch()
        create("Paris", destination: "Paris", in: app)
        tap("trip-back-library", in: app)
        create("Berlin", destination: "Berlin", in: app)
        tap("trip-more-menu", in: app)
        tap("trip-delete", in: app)
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.label.contains("Berlin"), alert.label)
        alert.buttons["Löschen"].tap()

        let card = { (name: String) in
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "library-trip-", name)).firstMatch
        }
        XCTAssertTrue(card("Paris").waitForExistence(timeout: 8), "Nach dem Löschen steht man in „Deine Reisen“")
        XCTAssertFalse(card("Berlin").exists)
        capture("deleted-from-trip", from: app)
    }

    /// Paket 5: Eine neue Reise braucht nur das Ziel; der Zeitraum ist gleich gewählt und steht in der Übersicht.
    func testCreateTripWithOneFieldAndDates() {
        let app = launch()
        XCTAssertFalse(app.buttons["library-create-trip"].exists, "Ohne Reise gibt es nur den großen Knopf")
        create("Rom", destination: "Rom", withDates: true, in: app)
        XCTAssertTrue(app.buttons["native-open-dayplan"].waitForExistence(timeout: 8), "Mit Zeitraum gibt es gleich den Reiseplan")
        tap("trip-back-library", in: app)
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "library-trip-", "Rom")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertFalse(card.label.contains("Zeitraum offen"), card.label)
        XCTAssertTrue(app.buttons["library-create-trip"].exists, "Mit einer Reise kommt das + dazu")
    }

    /// Paket 5: „Einladung öffnen“ mit einem Text, der kein Einladungslink ist, erklärt, was fehlt.
    func testPastingSomethingElseExplainsItIsNoInvitation() {
        let app = launch()
        UIPasteboard.general.string = "Treffen wir uns am Bahnhof?"
        let paste = app.buttons["library-paste-invitation"]
        XCTAssertTrue(paste.waitForExistence(timeout: 8), app.debugDescription)
        paste.tap()
        XCTAssertTrue(app.staticTexts["library-invitation-error"].waitForExistence(timeout: 5))
        capture("paste-no-invitation", from: app)
    }

    func testDeleteTripAsksFirstAndOnlyRemovesThatTrip() {
        let app = launch()
        create("Paris", destination: "Paris", in: app)
        tap("trip-back-library", in: app)
        create("Berlin", destination: "Berlin", in: app)
        tap("trip-back-library", in: app)

        let card = { (name: String) in
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "library-trip-", name)).firstMatch
        }
        XCTAssertTrue(card("Berlin").waitForExistence(timeout: 8), app.debugDescription)

        // Abbrechen lässt alles, wie es war.
        card("Berlin").press(forDuration: 1.2)
        tap("library-trip-delete", in: app)
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(alert.label.contains("Berlin"), "Rückfrage nennt die Reise nicht: \(alert.label)")
        capture("delete-confirm", from: app)
        alert.buttons["Abbrechen"].tap()
        XCTAssertTrue(card("Berlin").waitForExistence(timeout: 4), app.debugDescription)

        // Löschen entfernt nur Berlin, auch nach Neustart.
        card("Berlin").press(forDuration: 1.2)
        tap("library-trip-delete", in: app)
        XCTAssertTrue(alert.waitForExistence(timeout: 4), app.debugDescription)
        alert.buttons["Löschen"].tap()
        XCTAssertFalse(card("Berlin").waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(card("Paris").exists, app.debugDescription)
        capture("after-delete", from: app)

        app.terminate()
        app.launch()
        if app.buttons["trip-back-library"].waitForExistence(timeout: 6) { app.buttons["trip-back-library"].tap() }
        XCTAssertTrue(card("Paris").waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertFalse(card("Berlin").exists, app.debugDescription)
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
