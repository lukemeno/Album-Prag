import XCTest

#if targetEnvironment(simulator)
final class NativeShareUITests: XCTestCase {
    private let sharedURL = "https://example.com/album-qa-share"

    func testNativeShareCancelSaveAndReactivationAreExactlyOnce() throws {
        let store = "slot-native-share-\(UUID().uuidString)"
        let marker = XCTAttachment(string: "native-share-v6-host-dismiss; ALBUM_TEST_STORE=\(store); URL=\(sharedURL)")
        marker.name = "Native share test revision"
        marker.lifetime = .keepAlways
        add(marker)

        let app = XCUIApplication()
        app.launchEnvironment["ALBUM_TEST_STORE"] = store
        app.launchEnvironment["ALBUM_EMPTY_TEST_STORE"] = "1"
        app.launchEnvironment["ALBUM_QA_NATIVE_SHARE"] = "1"
        app.launchEnvironment["ALBUM_MY_NAME"] = "QA"
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Reise"].waitForExistence(timeout: 15))
        let groupError = app.alerts["Album"].staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'App-Group'"))
            .firstMatch
        if groupError.waitForExistence(timeout: 5) {
            XCTFail("Native-Share-QA App-Group fehlt; kein Fallback auf den isolierten Store")
            return
        }

        func shareButton() -> XCUIElement {
            let button = app.buttons["qa-native-share"]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "Der Native-Share-QA-Button muss nur im expliziten Simulator-QA-Modus erscheinen")
            XCTAssertTrue(button.isHittable)
            return button
        }

        func openCollection() {
            XCTAssertTrue(app.tabBars.buttons["Ideen"].waitForExistence(timeout: 8))
            app.tabBars.buttons["Ideen"].tap()
            XCTAssertTrue(app.buttons["Sammlung"].waitForExistence(timeout: 8))
            app.buttons["Sammlung"].tap()
            XCTAssertTrue(app.navigationBars["Sammlung"].waitForExistence(timeout: 8))
        }

        func returnToTravel() {
            if app.tabBars.buttons["Reise"].exists { app.tabBars.buttons["Reise"].tap() }
        }

        func closeNativeShareSheetIfPresent() {
            let hosts = [XCUIApplication(bundleIdentifier: "com.apple.springboard"), app]
            let deadline = Date().addingTimeInterval(5)
            let predicate = NSPredicate(format: "identifier == %@ AND label == %@", "header.closeButton", "Schließen")
            while Date() < deadline {
                for host in hosts {
                    let close = host.buttons.matching(predicate).firstMatch
                    guard close.exists, close.isHittable else { continue }
                    let frame = close.frame
                    guard
                          frame.width.isFinite, frame.height.isFinite,
                          frame.width > 0, frame.height > 0 else { continue }
                    close.tap()
                    while Date() < deadline && hosts.contains(where: { $0.buttons.matching(predicate).firstMatch.exists }) {
                        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
                    }
                    return
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
        }

        func selectAlbumExtension() -> XCUIApplication {
            shareButton().tap()
            let hosts = [XCUIApplication(bundleIdentifier: "com.apple.springboard"), app]
            var albumAction: XCUIElement?
            for host in hosts {
                let exactCandidates = [
                    host.buttons.matching(NSPredicate(format: "label == %@", "Album")),
                    host.cells.matching(NSPredicate(format: "label == %@", "Album"))
                ]
                let deadline = Date().addingTimeInterval(6)
                while Date() < deadline && albumAction == nil {
                    let windowFrame = host.windows.firstMatch.frame
                    for query in exactCandidates {
                        for candidate in query.allElementsBoundByIndex where candidate.label == "Album" {
                            let frame = candidate.frame
                            guard candidate.isHittable,
                                  frame.width.isFinite, frame.height.isFinite,
                                  frame.width > 0, frame.height > 0,
                                  windowFrame.contains(frame) else { continue }
                            albumAction = candidate
                            break
                        }
                        if albumAction != nil { break }
                    }
                    if albumAction == nil { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
                }
                if albumAction != nil { break }
            }
            guard let albumAction else {
                let attachment = XCTAttachment(string: hosts.map(\.debugDescription).joined(separator: "\n\n--- host ---\n\n"))
                attachment.name = "Native share sheet without Album extension"
                attachment.lifetime = .keepAlways
                add(attachment)
                XCTFail("Das echte iOS-Share-Sheet exponiert die eingebettete Album-Share-Extension nicht")
                return XCUIApplication(bundleIdentifier: "de.privatealbum.prague.share")
            }
            albumAction.tap()
            return XCUIApplication(bundleIdentifier: "de.privatealbum.prague.share")
        }

        let extensionApp = selectAlbumExtension()
        let cancel = extensionApp.buttons["Abbrechen"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 12), "Die echte Share-Extension muss ihren Abbrechen-Button exponieren")
        cancel.tap()
        closeNativeShareSheetIfPresent()
        XCTAssertTrue(shareButton().waitForExistence(timeout: 8))

        openCollection()
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Collection-Post-'" )).count,
            0,
            "Abbrechen darf keinen Sammlungspost erzeugen"
        )
        returnToTravel()

        let secondExtension = selectAlbumExtension()
        let missingContext = secondExtension.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Album einmal öffnen'"))
            .firstMatch
        if missingContext.waitForExistence(timeout: 3) {
            XCTFail("Die Share-Extension konnte den gemeinsamen QA-ShareContext nicht lesen")
            return
        }
        let save = secondExtension.buttons["In Album sammeln"]
        XCTAssertTrue(save.waitForExistence(timeout: 12), "Die echte Share-Extension muss den Save-Button exponieren")
        save.tap()
        closeNativeShareSheetIfPresent()
        XCTAssertTrue(shareButton().waitForExistence(timeout: 12), "Nach dem Speichern muss die Haupt-App wieder aktiv sein")

        openCollection()
        let posts = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Collection-Post-'"))
        XCTAssertEqual(posts.count, 1, "Ein erfolgreicher Native-Share darf genau einen lokalen Sammlungspost erzeugen")
        XCTAssertTrue(app.staticTexts["example.com"].waitForExistence(timeout: 5), "Der synthetische QA-Link muss im importierten Post sichtbar sein")

        app.terminate()
        app.launch()
        openCollection()
        let postsAfterReactivation = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Collection-Post-'"))
        XCTAssertEqual(postsAfterReactivation.count, 1, "Reaktivierung darf den bereits entfernten ShareQueue-Eintrag nicht doppelt importieren")
    }
}
#else
final class NativeShareUITests: XCTestCase {
    func testNativeShareRequiresSimulator() throws {
        throw XCTSkip("Native Share UI ist ausschließlich für den Simulator-QA-Pfad vorgesehen")
    }
}
#endif
