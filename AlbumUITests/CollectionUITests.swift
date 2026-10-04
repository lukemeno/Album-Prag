import XCTest

final class CollectionUITests: XCTestCase {
    private func launchIsolated(store: String = "slot-collection-\(UUID().uuidString)", preview: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_EMPTY_TEST_STORE"] = "1"
        app.launchEnvironment["ALBUM_MY_NAME"] = "Test"
        if preview {
            app.launchEnvironment["ALBUM_LINK_PREVIEW_TITLE"] = "Café Savoy"
            app.launchEnvironment["ALBUM_LINK_PREVIEW_DESCRIPTION"] = "Frühstück im Café Savoy in Prag"
        }
        app.launch()
        return app
    }

    private func openCollection(_ app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.buttons["Ideen"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Ideen"].tap()
        XCTAssertTrue(app.buttons["Sammlung"].waitForExistence(timeout: 5))
        app.buttons["Sammlung"].tap()
        XCTAssertTrue(app.navigationBars["Sammlung"].waitForExistence(timeout: 5))
    }

    func testLinkPreviewRefreshPreservesSharedNoteAndPersists() {
        let slot = "slot-collection-preview-\(UUID().uuidString)"
        let app = launchIsolated(store: slot, preview: true)
        openCollection(app)
        app.buttons["Sammeln"].tap()
        app.textFields["Collection-URL"].tap()
        app.textFields["Collection-URL"].typeText("https://www.tiktok.com/@creator/video/123")
        app.textFields["Collection-Message"].tap()
        app.textFields["Collection-Message"].typeText("Unsere gemeinsame Notiz")
        app.buttons["Collection-Save"].tap()
        XCTAssertTrue(app.staticTexts["Café Savoy"].waitForExistence(timeout: 10))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Collection-Post-'" )).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Frühstück im Café Savoy in Prag"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Unsere gemeinsame Notiz"].exists)
        app.buttons["Collection-Refresh-Preview"].tap()
        XCTAssertTrue(app.buttons["Vorschau aktualisieren"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Unsere gemeinsame Notiz"].exists)
        XCTAssertTrue(app.buttons["Orte erkennen"].exists)
        XCTAssertFalse(app.textFields["PlaceEditor-Title"].exists, "Die Vorschau darf keinen Ort automatisch speichern oder den Editor öffnen")
        app.terminate()
        let restarted = launchIsolated(store: slot, preview: true)
        openCollection(restarted)
        XCTAssertTrue(restarted.staticTexts["Café Savoy"].waitForExistence(timeout: 5))
    }

    func testOfflineMessageCommentHeartAndRestart() {
        let store = "slot-collection-\(UUID().uuidString)"
        let app = launchIsolated(store: store)
        openCollection(app)
        app.buttons["Sammeln"].tap()
        XCTAssertTrue(app.textFields["Collection-Message"].waitForExistence(timeout: 5))
        app.textFields["Collection-Message"].tap()
        app.textFields["Collection-Message"].typeText("Offline Nachricht")
        app.buttons["Collection-Save"].tap()
        let post = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Collection-Post-'" )).firstMatch
        XCTAssertTrue(post.waitForExistence(timeout: 5))
        post.tap()
        XCTAssertTrue(app.buttons["Collection-Heart"].waitForExistence(timeout: 5))
        app.textFields["Collection-Comment"].tap()
        app.textFields["Collection-Comment"].typeText("Ein Kommentar")
        app.buttons["Collection-Comment-Send"].tap()
        XCTAssertTrue(app.staticTexts["Ein Kommentar"].waitForExistence(timeout: 5))
        app.buttons["Collection-Heart"].tap()
        XCTAssertTrue(app.buttons["Collection-Heart"].label.contains("Herz entfernen"))
        app.buttons["Fertig"].tap()
        app.terminate()
        let restarted = launchIsolated(store: store)
        openCollection(restarted)
        XCTAssertTrue(restarted.staticTexts["Offline Nachricht"].waitForExistence(timeout: 5))
        let restoredPost = restarted.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Collection-Post-'" )).firstMatch
        XCTAssertTrue(restoredPost.waitForExistence(timeout: 5))
        restoredPost.tap()
        XCTAssertTrue(restarted.staticTexts["Ein Kommentar"].waitForExistence(timeout: 5))
        XCTAssertTrue(restarted.buttons["Collection-Heart"].waitForExistence(timeout: 5))
        XCTAssertTrue(restarted.buttons["Collection-Heart"].label.contains("Herz entfernen"), "Das aktive Herz muss den Neustart überstehen")
    }

    func testDuplicateURLAddsOnePostAndKeepsBothNotes() {
        let app = launchIsolated(store: "slot-collection-duplicate-\(UUID().uuidString)")
        openCollection(app)
        let url = "https://example.com/cafe"
        for note in ["Erste Notiz", "Zweite Notiz"] {
            app.buttons["Sammeln"].tap()
            XCTAssertTrue(app.textFields["Collection-URL"].waitForExistence(timeout: 5))
            app.textFields["Collection-URL"].tap(); app.textFields["Collection-URL"].typeText(url)
            app.textFields["Collection-Message"].tap(); app.textFields["Collection-Message"].typeText(note)
            app.buttons["Collection-Save"].tap()
            XCTAssertTrue(app.navigationBars["Sammlung"].waitForExistence(timeout: 5))
        }
        let posts = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Collection-Post-'"))
        XCTAssertEqual(posts.count, 1, "Dieselbe kanonische URL darf nur einen Beitrag erzeugen")
        posts.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Erste Notiz"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Zweite Notiz"].waitForExistence(timeout: 5))
    }

    func testCollectionPostDeleteRemovesPostFromList() {
        let app = launchIsolated(store: "slot-collection-delete-\(UUID().uuidString)")
        openCollection(app)
        app.buttons["Sammeln"].tap()
        app.textFields["Collection-Message"].tap(); app.textFields["Collection-Message"].typeText("Löschbarer Beitrag")
        app.buttons["Collection-Save"].tap()
        let post = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Collection-Post-'" )).firstMatch
        XCTAssertTrue(post.waitForExistence(timeout: 5)); post.tap()
        XCTAssertTrue(app.buttons["Beitrag löschen"].waitForExistence(timeout: 5))
        app.buttons["Beitrag löschen"].tap()
        XCTAssertTrue(app.buttons["Löschen"].waitForExistence(timeout: 5))
        app.buttons["Löschen"].tap()
        XCTAssertTrue(app.navigationBars["Sammlung"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Löschbarer Beitrag"].waitForExistence(timeout: 2))
    }

    func testManualPlaceCancelLeavesNoLinkAndSaveCreatesOne() {
        let app = launchIsolated()
        openCollection(app)
        app.buttons["Sammeln"].tap()
        app.textFields["Collection-Message"].tap()
        app.textFields["Collection-Message"].typeText("Ort testen")
        app.buttons["Collection-Save"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Collection-Post-'" )).firstMatch.tap()
        app.buttons["Collection-Add-Place"].tap()
        XCTAssertTrue(app.textFields["PlaceEditor-Title"].waitForExistence(timeout: 5))
        app.buttons["PlaceEditor-Cancel"].tap()
        XCTAssertFalse(app.staticTexts["Manueller Testort"].exists)
        app.buttons["Collection-Add-Place"].tap()
        app.textFields["PlaceEditor-Title"].tap()
        app.textFields["PlaceEditor-Title"].typeText("Manueller Testort")
        app.buttons["PlaceEditor-Save"].tap()
        XCTAssertTrue(app.staticTexts["Manueller Testort"].waitForExistence(timeout: 5))
    }
}
