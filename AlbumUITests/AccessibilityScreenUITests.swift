import XCTest

extension AlbumUITests {
    private func launchAccessibilityStore(startTab: String, extra: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = "slot-accessibility-\(startTab)-\(UUID().uuidString)"
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = startTab
        app.launchEnvironment["ALBUM_EMPTY_TEST_STORE"] = "1"
        for (key, value) in extra { app.launchEnvironment[key] = value }
        app.launch()
        return app
    }

    private func attachAccessibilityScreen(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Accessibility screen — \(name)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let ax = XCTAttachment(string: app.debugDescription)
        ax.name = "Accessibility AX — \(name)"
        ax.lifetime = .keepAlways
        add(ax)
    }

    func testAccessibilityAuditReiseScreen() throws {
        let app = launchAccessibilityStore(startTab: "Reise")
        XCTAssertTrue(app.tabBars.buttons["Reise"].waitForExistence(timeout: 15))
        attachAccessibilityScreen(app, name: "Reise")
        try auditAccessibility(app, screen: "Reise")
    }

    func testAccessibilityAuditPlaceEditorScreen() throws {
        let app = launchAccessibilityStore(startTab: "Ideen")
        let addIdea = app.navigationBars["Ideen"].buttons["Idee einwerfen"]
        XCTAssertTrue(addIdea.waitForExistence(timeout: 15))
        addIdea.tap()
        XCTAssertTrue(app.textFields["Name der Idee"].waitForExistence(timeout: 5))
        attachAccessibilityScreen(app, name: "Idee bearbeiten")
        try auditAccessibility(app, screen: "Idee bearbeiten")
    }

    func testAccessibilityAuditIdeasScreen() throws {
        let app = launchAccessibilityStore(startTab: "Ideen", extra: ["ALBUM_DEMO_INBOX": "1"])
        XCTAssertTrue(app.otherElements["Inbox-Ticket"].waitForExistence(timeout: 15))
        attachAccessibilityScreen(app, name: "Ideen")
        try auditAccessibility(app, screen: "Ideen")
    }

    func testAccessibilityAuditMapScreen() throws {
        let app = launchAccessibilityStore(startTab: "Karte", extra: ["ALBUM_DEMO_MOTION": "1"])
        XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: 15))
        attachAccessibilityScreen(app, name: "Karte")
        try auditAccessibility(app, screen: "Karte")
    }

    func testAccessibilityAuditSelectedMapScreen() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let store = environment["ALBUM_PLAN_STORE"], store.hasPrefix("slot-") else {
            throw XCTSkip("Keine vorbereitete Karten-Accessibility-Fixture")
        }
        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_MY_NAME"] = "Luke"
        app.launchEnvironment["ALBUM_START_TAB"] = "Karte"
        app.launch()
        XCTAssertTrue(app.textFields["map-search"].waitForExistence(timeout: 15))
        let clusterQuery = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'map-cluster-'"))
        XCTAssertTrue(clusterQuery.firstMatch.waitForExistence(timeout: 10))
        let firstCluster = clusterQuery.firstMatch
        let memberIDs = String(firstCluster.identifier.dropFirst("map-cluster-".count)).split(separator: "|").map(String.init)
        let expectedPlaceID = try XCTUnwrap(memberIDs.first, "Der Cluster braucht mindestens ein Mitglied")
        firstCluster.tap()
        let containingPlace = clusterQuery.matching(NSPredicate(format: "identifier CONTAINS %@", expectedPlaceID)).firstMatch
        let memberChoice = app.buttons["map-cluster-choice-\(expectedPlaceID)"]
        let pin = app.buttons["map-pin-\(expectedPlaceID)"]
        for _ in 0..<8 {
            if pin.waitForExistence(timeout: 1) { break }
            if memberChoice.waitForExistence(timeout: 1) {
                memberChoice.tap()
                break
            }
            XCTAssertTrue(containingPlace.waitForExistence(timeout: 4), "Der Cluster muss beim Hineinzoomen erreichbar bleiben")
            containingPlace.tap()
        }
        XCTAssertTrue(pin.waitForExistence(timeout: 5), "Ein Cluster-Mitglied muss als einzelner Pin erreichbar sein")
        pin.tap()
        XCTAssertTrue(app.buttons["Liste schließen"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["place-row-\(expectedPlaceID)"].waitForExistence(timeout: 8), "Pin und Kartenzeile müssen dieselbe Place-ID verwenden")
        attachAccessibilityScreen(app, name: "Karte mit ausgewähltem Ort")
        try auditAccessibility(app, screen: "Karte mit ausgewähltem Ort")
    }

    /// Snapshot-Gate für große Schrift: belegt sichtbare Reise-/Ideen-Texte und
    /// die erreichbare primäre Aktion, ohne den Accessibility-Audit-Throw als
    /// Screen-Navigation zu verwenden.
    func testAccessibilityLargeTypeTravelAndIdeasLayoutSnapshots() throws {
        let travel = launchAccessibilityStore(startTab: "Reise")
        XCTAssertTrue(travel.tabBars.buttons["Reise"].waitForExistence(timeout: 15))
        XCTAssertTrue(travel.staticTexts["Prag"].waitForExistence(timeout: 8))
        let travelSubtitle = travel.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Oktober'")
        ).firstMatch
        XCTAssertTrue(travelSubtitle.waitForExistence(timeout: 8), "Der Reisezeitraum muss bei großer Schrift sichtbar bleiben")
        attachAccessibilityScreen(travel, name: "Reise Large Type")

        let ideas = launchAccessibilityStore(startTab: "Ideen", extra: ["ALBUM_DEMO_INBOX": "1"])
        XCTAssertTrue(ideas.otherElements["Inbox-Ticket"].waitForExistence(timeout: 15))
        let addIdea = ideas.navigationBars["Ideen"].buttons["Idee einwerfen"]
        XCTAssertTrue(addIdea.waitForExistence(timeout: 8))
        XCTAssertTrue(addIdea.isHittable, "Die primäre Idee-Aktion muss erreichbar bleiben")
        XCTAssertTrue(ideas.staticTexts["Sehenswert"].waitForExistence(timeout: 8), "Die Kartenkategorie muss sichtbar bleiben")
        attachAccessibilityScreen(ideas, name: "Ideen Large Type")

        // Prüfe die tatsächliche 44-Punkt-Touchfläche an allen vier Randpunkten.
        // Die Probe darf deshalb außerhalb des nativen AX-Frames liegen.
        let edgeOffsets: [CGVector] = [
            CGVector(dx: -21, dy: 0), CGVector(dx: 21, dy: 0),
            CGVector(dx: 0, dy: -21), CGVector(dx: 0, dy: 21)
        ]
        for (index, offset) in edgeOffsets.enumerated() {
            let freshButton = ideas.navigationBars["Ideen"].buttons["Idee einwerfen"]
            XCTAssertTrue(freshButton.waitForExistence(timeout: 8), "Idee-Aktion muss vor Touchprobe \(index + 1) sichtbar sein")
            XCTAssertTrue(freshButton.isHittable, "Idee-Aktion muss vor Touchprobe \(index + 1) hittable sein")
            let edgePoint = freshButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .withOffset(offset)
            edgePoint.tap()

            let editorTitle = ideas.textFields["PlaceEditor-Title"]
            XCTAssertTrue(editorTitle.waitForExistence(timeout: 8), "Touchprobe \(index + 1) muss den Editor öffnen")
            let cancel = ideas.buttons["Abbrechen"]
            XCTAssertTrue(cancel.waitForExistence(timeout: 8), "Editor muss nach Touchprobe \(index + 1) abbrechbar sein")
            XCTAssertTrue(cancel.isHittable, "Editor-Abbrechen muss nach Touchprobe \(index + 1) hittable sein")
            cancel.tap()
        }

        let reject = ideas.buttons["Nein"]
        let approve = ideas.buttons["Ja"]
        let scroll = ideas.scrollViews.firstMatch
        if scroll.exists {
            for _ in 0..<3 {
                if reject.isHittable && approve.isHittable { break }
                scroll.swipeUp()
            }
        }
        XCTAssertTrue(reject.isHittable, "Nein muss bei maximaler Schrift erreichbar sein")
        XCTAssertTrue(approve.isHittable, "Ja muss bei maximaler Schrift erreichbar sein")
        let sameCard = ideas.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Karlsbrücke'")).firstMatch
        XCTAssertTrue(sameCard.exists, "Scrollen darf die Idee nicht als Offen weglegen")
        attachAccessibilityScreen(ideas, name: "Ideen Large Type nach Scrollen")
    }
}
