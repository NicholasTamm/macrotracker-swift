import XCTest

final class FoodPasteUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSingleFoodAndHourBlockPasteIntoSelectedDay() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-mf.hasCompletedOnboarding", "YES",
            "-issue2FoodPasteFixture",
        ]
        app.launch()
        assertDashboardTodayIsUnchanged(in: app)
        openFoodLog(in: app)

        let egg = tile(named: "QA2 Egg", in: app)
        let oats = tile(named: "QA2 Oats", in: app)
        XCTAssertTrue(egg.waitForExistence(timeout: 15))
        XCTAssertTrue(oats.waitForExistence(timeout: 15))
        XCTAssertEqual(tileCount(named: "QA2 Egg", in: app), 1)
        XCTAssertEqual(tileCount(named: "QA2 Oats", in: app), 1)
        attachScreenshot(from: app, named: "Today source before paste")

        egg.press(forDuration: 1)
        let copyFood = app.buttons["Copy food"]
        XCTAssertTrue(copyFood.waitForExistence(timeout: 5))
        copyFood.tap()
        app.buttons["Previous day"].tap()
        XCTAssertTrue(app.staticTexts["Yesterday"].waitForExistence(timeout: 5))
        XCTAssertEqual(tileCount(named: "QA2 Egg", in: app), 0)
        paste(menuItem: "Paste food", in: app)
        XCTAssertTrue(tile(named: "QA2 Egg", in: app).waitForExistence(timeout: 10))
        XCTAssertEqual(tileCount(named: "QA2 Egg", in: app), 1)
        XCTAssertEqual(tileCount(named: "QA2 Oats", in: app), 0)
        attachScreenshot(from: app, named: "Yesterday after single food paste")

        app.terminate()
        app.launch()
        openFoodLog(in: app)
        app.buttons["Previous day"].tap()
        XCTAssertEqual(tileCount(named: "QA2 Egg", in: app), 1)
        XCTAssertEqual(tileCount(named: "QA2 Oats", in: app), 0)
        // In-memory clipboard is empty after a new app process.
        app.buttons["Day menu"].tap()
        XCTAssertFalse(app.buttons["Paste food"].exists)
        app.tap()
        attachScreenshot(from: app, named: "Yesterday after relaunch")

        app.buttons["Next day"].tap()
        XCTAssertEqual(tileCount(named: "QA2 Egg", in: app), 1)
        XCTAssertEqual(tileCount(named: "QA2 Oats", in: app), 1)
        assertDashboardTodayIsUnchanged(in: app)
        openFoodLog(in: app)
        let block = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "11 AM, 240")
        ).firstMatch
        XCTAssertTrue(block.waitForExistence(timeout: 5), "Source hour block should retain 240 kcal")
        block.press(forDuration: 1)
        let copyBlock = app.buttons["Copy 2 foods"]
        XCTAssertTrue(copyBlock.waitForExistence(timeout: 5))
        copyBlock.tap()
        app.buttons["Previous day"].tap()
        paste(menuItem: "Paste 2 foods", in: app)
        XCTAssertEqual(tileCount(named: "QA2 Egg", in: app), 2)
        XCTAssertEqual(tileCount(named: "QA2 Oats", in: app), 1)
        attachScreenshot(from: app, named: "Yesterday after hour block paste")

        // Paste leaves the clipboard available; repeating it makes new rows.
        paste(menuItem: "Paste 2 foods", in: app)
        XCTAssertEqual(tileCount(named: "QA2 Egg", in: app), 3)
        XCTAssertEqual(tileCount(named: "QA2 Oats", in: app), 2)
        app.terminate()
        app.launch()
        openFoodLog(in: app)
        app.buttons["Previous day"].tap()
        XCTAssertEqual(tileCount(named: "QA2 Egg", in: app), 3)
        XCTAssertEqual(tileCount(named: "QA2 Oats", in: app), 2)
        app.buttons["Next day"].tap()
        XCTAssertEqual(tileCount(named: "QA2 Egg", in: app), 1)
        XCTAssertEqual(tileCount(named: "QA2 Oats", in: app), 1)
        assertDashboardTodayIsUnchanged(in: app)
    }

    private func openFoodLog(in app: XCUIApplication) {
        let tab = app.tabBars.buttons["Food Log"]
        XCTAssertTrue(tab.waitForExistence(timeout: 30))
        tab.tap()
    }

    private func assertDashboardTodayIsUnchanged(in app: XCUIApplication) {
        let tab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(tab.waitForExistence(timeout: 30))
        tab.tap()
        let calorieSummary = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Today: 240")
        ).firstMatch
        XCTAssertTrue(calorieSummary.waitForExistence(timeout: 10),
                      "Dashboard should keep Today's 240 kcal source total")
    }

    private func tile(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    private func tileCount(named name: String, in app: XCUIApplication) -> Int {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).count
    }

    private func paste(menuItem: String, in app: XCUIApplication) {
        app.buttons["Day menu"].tap()
        let item = app.buttons[menuItem]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Missing \(menuItem) menu item")
        item.tap()
    }

    private func attachScreenshot(from app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
