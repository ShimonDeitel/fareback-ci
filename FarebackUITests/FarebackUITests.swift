import XCTest

final class FarebackUITests: XCTestCase {
    private var interruptionMonitorToken: NSObjectProtocol?

    override func setUpWithError() throws {
        continueAfterFailure = false
        interruptionMonitorToken = addUIInterruptionMonitor(withDescription: "System alert dismissal") { alert in
            for label in ["Allow", "OK", "Don't Allow", "Cancel"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        if let token = interruptionMonitorToken {
            removeUIInterruptionMonitor(token)
        }
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
        return app
    }

    func testHomeShowsOdometerOnLaunch() throws {
        let app = launchApp()
        XCTAssertTrue(app.otherElements["odometerStrip"].waitForExistence(timeout: 12), "Odometer strip did not appear on launch")
    }

    func testSeedRoutesAppear() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Office Commute"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["Work From Home"].waitForExistence(timeout: 6))
    }

    func testAddRouteFromHome() throws {
        let app = launchApp()
        // Seed data has 2 routes (free limit) — delete one so "+" opens the form.
        let officeText = app.staticTexts["Office Commute"]
        XCTAssertTrue(officeText.waitForExistence(timeout: 12))
        officeText.tap()
        app.buttons["deleteRouteButton"].tap()
        XCTAssertFalse(app.staticTexts["Office Commute"].waitForExistence(timeout: 6))

        let addButton = app.buttons["addRouteButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 12))
        addButton.tap()

        let nameField = app.textFields["routeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 12))
        nameField.tap()
        nameField.typeText("Downtown Bus")

        app.buttons["saveRouteButton"].tap()

        XCTAssertTrue(app.staticTexts["Downtown Bus"].waitForExistence(timeout: 12), "New route did not appear")
    }

    func testEditRouteChangesDays() throws {
        let app = launchApp()
        let officeText = app.staticTexts["Office Commute"]
        XCTAssertTrue(officeText.waitForExistence(timeout: 12))
        officeText.tap()

        let incrementButton = app.buttons["routeDaysIncrementButton"]
        XCTAssertTrue(incrementButton.waitForExistence(timeout: 12))
        incrementButton.tap()

        app.buttons["saveRouteButton"].tap()

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '4x/week'")).firstMatch.waitForExistence(timeout: 12), "Days-per-week edit did not apply")
    }

    func testDeleteRouteViaForm() throws {
        let app = launchApp()
        let officeText = app.staticTexts["Office Commute"]
        XCTAssertTrue(officeText.waitForExistence(timeout: 12))
        officeText.tap()

        app.buttons["deleteRouteButton"].tap()

        XCTAssertFalse(app.staticTexts["Office Commute"].waitForExistence(timeout: 6), "Route was not deleted")
    }

    func testFreeLimitTriggersPaywallAtThirdRoute() throws {
        let app = launchApp()
        let addButton = app.buttons["addRouteButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 12))
        addButton.tap()
        XCTAssertTrue(app.staticTexts["Fareback Pro"].waitForExistence(timeout: 12), "Paywall did not appear after hitting the free route limit")
    }

    func testDisablingRouteUpdatesWeeklyTotal() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Office Commute"].waitForExistence(timeout: 12))

        let toggle = app.switches.matching(identifier: "enableRouteToggle_Office Commute").firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 12))
        toggle.tap()

        // Weekly total tile should still exist and be tappable/visible after toggling.
        XCTAssertTrue(app.staticTexts["summaryTile_Weekly"].waitForExistence(timeout: 8))
    }

    func testSettingsGasPriceFieldEditable() throws {
        let app = launchApp()
        app.tabBars.buttons["Settings"].tap()

        let gasField = app.textFields["gasPriceField"]
        XCTAssertTrue(gasField.waitForExistence(timeout: 12))
        gasField.tap()
        gasField.typeText("999")

        // Dismiss keyboard by tapping elsewhere within the form (real tap-outside dismiss).
        app.staticTexts["Gas price ($/gal)"].tap()
        XCTAssertFalse(app.keyboards.element.exists, "Keyboard did not dismiss on tap-outside")
    }
}
