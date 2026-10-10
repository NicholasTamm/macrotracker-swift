import XCTest

final class NamedServingUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testSeededEggLegacySizeFractionAndStepperCancel() {
        let app = XCUIApplication()
        app.launchArguments = servingFixtureArguments
        app.launch()
        openFoodLog(app)
        openFood(named: "Egg, whole, boiled", app: app)
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 10))
        let amount = app.textFields["servingAmountField"]
        amount.tap()
        amount.clearAndType("1.5")
        dismissKeyboard(app)
        XCTAssertTrue(app.staticTexts["75 g"].waitForExistence(timeout: 5))
        let calories = app.staticTexts["116.2 kcal"]
        scrollUntilHittable(calories, in: app)
        XCTAssertTrue(calories.exists)
        scrollUntilHittable(app.buttons["Increase amount"], in: app, direction: "down")
        app.buttons["Increase amount"].tap()
        XCTAssertEqual(amount.value as? String, "2")
        XCTAssertTrue(app.staticTexts["100 g"].exists)
        app.buttons["Decrease amount"].tap()
        XCTAssertEqual(amount.value as? String, "1.5")
        scrollUntilHittable(calories, in: app)
        attachScreenshot(app, name: "Seeded egg fractional preview")
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Egg, whole, boiled")).firstMatch.exists)
    }

    func testNarrowCustomServingCatalogLayoutAndCancel() {
        let app = XCUIApplication()
        app.launchArguments = servingFixtureArguments
        app.launch()
        openFoodLog(app)
        app.buttons["Search for a food"].tap()
        app.swipeUp()
        let createFood = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Create custom food")).firstMatch
        scrollUntilHittable(createFood, in: app)
        createFood.tap()
        XCTAssertTrue(app.navigationBars["Custom food"].waitForExistence(timeout: 10))

        app.buttons["Add serving size"].tap()
        dismissKeyboard(app)
        let namedFields = app.textFields.matching(NSPredicate(format: "label == %@", "Serving size name"))
        XCTAssertGreaterThanOrEqual(namedFields.count, 2, "Both serving rows should be present in the narrow editor")
        attachScreenshot(app, name: "Narrow custom catalog two serving rows")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.tabBars.buttons["Food Log"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Search for a food"].exists)
    }

    func testCustomNamedSizeTypedAmountEditAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = servingFixtureArguments
        app.launch()
        let dashboard = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 10))
        dashboard.tap()
        let baselineToday = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Today:"))
            .firstMatch
        XCTAssertTrue(baselineToday.waitForExistence(timeout: 10))
        let baselineCalories = Self.todayCalories(from: baselineToday.label)
        openFoodLog(app)
        openFood(named: "QA3 Oats", app: app)

        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 10))
        let amount = app.textFields["servingAmountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.clearAndType("0")
        XCTAssertEqual(amount.value as? String, "0")
        XCTAssertTrue(app.staticTexts["Amount must be greater than zero."].waitForExistence(timeout: 5))
        dismissKeyboard(app)
        let disabledLogButton = app.buttons["logFoodButton"]
        scrollUntilHittable(disabledLogButton, in: app)
        XCTAssertFalse(disabledLogButton.isEnabled)
        scrollUntilHittable(amount, in: app, direction: "down")
        amount.clearAndType("1.5")
        dismissKeyboard(app)
        let sizePicker = app.buttons["servingSizePicker"]
        scrollUntilHittable(sizePicker, in: app, direction: "down")
        sizePicker.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "scoop")).firstMatch.tap()
        dismissKeyboard(app)
        XCTAssertTrue(app.staticTexts["37.5 g"].waitForExistence(timeout: 5))
        scrollUntilHittable(app.staticTexts["45 kcal"], in: app)
        XCTAssertTrue(app.staticTexts["45 kcal"].exists)
        scrollUntilHittable(amount, in: app, direction: "down")
        let logButton = app.buttons["logFoodButton"]
        scrollUntilHittable(logButton, in: app)
        XCTAssertTrue(logButton.exists)
        logButton.tap()

        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "QA3 Oats")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap()
        XCTAssertTrue(app.navigationBars["Edit entry"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["servingAmountField"].value as? String, "1.5")
        XCTAssertTrue(app.staticTexts["37.5 g"].exists)
        scrollUntilHittable(app.datePickers.firstMatch, in: app)
        let datePicker = app.datePickers.firstMatch
        let originalTimestamp = accessibleTimestamp(datePicker)
        XCTAssertNotNil(originalTimestamp, "Date picker should expose its logged date and time through accessibility")
        print("QA-3 original timestamp accessibility value: \(originalTimestamp ?? "<nil>")")
        let reopenedAmount = app.textFields["servingAmountField"]
        scrollUntilHittable(reopenedAmount, in: app, direction: "down")
        reopenedAmount.tap()
        reopenedAmount.clearAndType("2")
        XCTAssertTrue(app.staticTexts["50 g"].exists)
        dismissKeyboard(app)
        let saveButton = app.buttons["saveFoodChangesButton"]
        scrollUntilHittable(saveButton, in: app)
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()

        app.terminate()
        app.launchArguments = ["-mf.hasCompletedOnboarding", "YES", "-issue3ServingFixture"]
        app.launch()
        openFoodLog(app)
        let reopenedTile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "QA3 Oats")).firstMatch
        XCTAssertTrue(reopenedTile.waitForExistence(timeout: 10))
        XCTAssertTrue(reopenedTile.label.contains("60 calories"))
        app.tabBars.buttons["Dashboard"].tap()
        let today = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Today:"))
            .firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        XCTAssertEqual(Self.todayCalories(from: today.label), baselineCalories + 60,
                       "Dashboard should include the edited 60 kcal entry")
        app.tabBars.buttons["Food Log"].tap()
        XCTAssertTrue(app.buttons["Search for a food"].waitForExistence(timeout: 10))
        reopenedTile.tap()
        XCTAssertEqual(app.textFields["servingAmountField"].value as? String, "2")
        XCTAssertTrue(app.staticTexts["50 g"].exists)
        let reopenedDatePicker = app.datePickers.firstMatch
        scrollUntilHittable(reopenedDatePicker, in: app)
        XCTAssertEqual(accessibleTimestamp(reopenedDatePicker), originalTimestamp,
                       "Editing the amount should preserve the original log timestamp")
        print("QA-3 reopened timestamp accessibility value: \(accessibleTimestamp(reopenedDatePicker) ?? "<nil>")")
        attachScreenshot(app, name: "Named serving after relaunch")
    }

    func testServingAmountInvalidMatrixAndDirectGramBoundaries() {
        let app = XCUIApplication()
        app.launchArguments = servingFixtureArguments
        app.launch()
        openFoodLog(app)
        openFood(named: "Egg, whole, boiled", app: app)
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 10))
        let amount = app.textFields["servingAmountField"]
        let logButton = app.buttons["logFoodButton"]
        let invalidCases: [(String, String)] = [
            ("", "Enter a numeric amount."),
            ("abc", "Enter a numeric amount."),
            ("-1", "Amount must be greater than zero."),
            ("0", "Amount must be greater than zero."),
            ("1.234", "Use at most two decimal places."),
            ("1000.01", "Maximum is 1,000 units or 100,000 g."),
        ]
        for (raw, expectedError) in invalidCases {
            amount.tap()
            amount.clearAndType(raw)
            dismissKeyboard(app)
            let error = app.staticTexts[expectedError]
            XCTAssertTrue(error.waitForExistence(timeout: 5), "Expected feedback for amount `\(raw)`")
            scrollUntilExists(logButton, in: app)
            XCTAssertFalse(logButton.isEnabled, "Invalid amount `\(raw)` must disable logging")
        }

        app.buttons["servingSizePicker"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Gram (1 g)")).firstMatch.tap()
        amount.tap()
        amount.clearAndType("0.01")
        dismissKeyboard(app)
        XCTAssertFalse(app.staticTexts["Use at most two decimal places."].exists)
        scrollUntilExists(logButton, in: app)
        XCTAssertTrue(logButton.isEnabled, "0.01 g must be accepted")

        amount.tap()
        amount.clearAndType("1000")
        dismissKeyboard(app)
        scrollUntilExists(logButton, in: app)
        XCTAssertTrue(logButton.isEnabled, "1,000 direct grams is the inclusive unit limit")
        amount.tap()
        amount.clearAndType("1000.01")
        XCTAssertTrue(app.staticTexts["Maximum is 1,000 units or 100,000 g."].waitForExistence(timeout: 5))
        dismissKeyboard(app)
        scrollUntilExists(logButton, in: app)
        XCTAssertFalse(logButton.isEnabled, "Amounts above the direct-Gram unit limit must be rejected")
        app.buttons["Cancel"].tap()

        openFoodLog(app)
        openFood(named: "QA3 Oats", app: app)
        let oatsAmount = app.textFields["servingAmountField"]
        let oatsLogButton = app.buttons["logFoodButton"]
        oatsAmount.tap()
        oatsAmount.clearAndType("1000")
        dismissKeyboard(app)
        scrollUntilExists(oatsLogButton, in: app)
        XCTAssertTrue(oatsLogButton.isEnabled, "1,000 bowl units at 100 g each is the inclusive 100,000 g limit")
        oatsAmount.tap()
        oatsAmount.clearAndType("1000.01")
        XCTAssertTrue(app.staticTexts["Maximum is 1,000 units or 100,000 g."].waitForExistence(timeout: 5))
        dismissKeyboard(app)
        scrollUntilExists(oatsLogButton, in: app)
        XCTAssertFalse(oatsLogButton.isEnabled, "More than 100,000 g must be rejected")
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "QA3 Oats")).firstMatch.exists)
    }

    func testCustomFoodRejectsInvalidNamedSizeCatalogAndCanBeCancelled() {
        let app = XCUIApplication()
        app.launchArguments = servingFixtureArguments
        app.launch()
        openFoodLog(app)
        app.buttons["Search for a food"].tap()
        app.swipeUp()
        let createFood = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Create custom food")).firstMatch
        XCTAssertTrue(createFood.waitForExistence(timeout: 10))
        createFood.tap()
        XCTAssertTrue(app.navigationBars["Custom food"].waitForExistence(timeout: 10))

        app.buttons["Add serving size"].tap()
        let names = app.textFields.matching(identifier: "Serving size name")
        let weights = app.textFields.matching(identifier: "Serving size weight in grams")
        let secondName = names.element(boundBy: 1)
        let secondWeight = weights.element(boundBy: 1)
        scrollUntilHittable(secondName, in: app)
        scrollUntilHittable(secondWeight, in: app)
        let foodName = app.textFields["Name"]
        foodName.tap()
        foodName.clearAndType("QA3 Cancel Food")
        names.element(boundBy: 0).tap()
        names.element(boundBy: 0).clearAndType("bowl")
        weights.element(boundBy: 0).tap()
        weights.element(boundBy: 0).clearAndType("100")
        secondName.tap()
        secondName.clearAndType("bowl")
        secondWeight.tap()
        secondWeight.clearAndType("25")
        let save = app.buttons["Save custom food"]
        dismissKeyboard(app)
        scrollUntilExists(save, in: app)
        XCTAssertTrue(save.exists)
        XCTAssertFalse(save.isEnabled, "Duplicate serving names must disable save")
        scrollUntilHittable(secondName, in: app)
        secondName.tap()
        secondName.clearAndType("scoop")
        secondWeight.tap()
        secondWeight.clearAndType("0")
        dismissKeyboard(app)
        scrollUntilExists(save, in: app)
        XCTAssertFalse(save.isEnabled, "A zero gram weight must disable save")

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.tabBars.buttons["Food Log"].waitForExistence(timeout: 10))
        app.buttons["Search for a food"].tap()
        let search = app.searchFields["Search for a food"]
        search.tap()
        search.typeText("QA3 Cancel Food")
        XCTAssertTrue(app.staticTexts["No matches. Try a different search, or create a custom food below."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "QA3 Cancel Food")).firstMatch.exists)
    }

    func testCustomFoodCanBeCreatedWithTwoNamedSizes() {
        let app = XCUIApplication()
        app.launchArguments = servingFixtureArguments
        app.launch()
        openFoodLog(app)
        app.buttons["Search for a food"].tap()
        app.swipeUp()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Create custom food")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Custom food"].waitForExistence(timeout: 10))

        let foodName = app.textFields["Name"]
        foodName.tap()
        foodName.clearAndType("QA3 Created Food")
        app.buttons["Add serving size"].tap()
        let names = app.textFields.matching(identifier: "Serving size name")
        let weights = app.textFields.matching(identifier: "Serving size weight in grams")
        let secondName = names.element(boundBy: 1)
        let secondWeight = weights.element(boundBy: 1)
        scrollUntilHittable(secondName, in: app)
        scrollUntilHittable(secondWeight, in: app)
        names.element(boundBy: 0).tap()
        names.element(boundBy: 0).clearAndType("bowl")
        weights.element(boundBy: 0).tap()
        weights.element(boundBy: 0).clearAndType("100")
        secondName.tap()
        secondName.clearAndType("scoop")
        secondWeight.tap()
        secondWeight.clearAndType("25")

        app.swipeUp()
        let calories = app.textFields["Calories per serving in kcal"]
        calories.tap()
        calories.clearAndType("120")
        let protein = app.textFields["Protein per serving in g"]
        protein.tap()
        protein.clearAndType("10")
        let fat = app.textFields["Fat per serving in g"]
        fat.tap()
        fat.clearAndType("4")
        let carbs = app.textFields["Carbs per serving in g"]
        carbs.tap()
        carbs.clearAndType("18")
        print("QA-3 carbs before keyboard dismissal: value=\(carbs.value ?? "<nil>"), placeholder=\(carbs.placeholderValue ?? "<nil>")")
        dismissKeyboard(app)
        print("QA-3 carbs after keyboard dismissal: value=\(carbs.value ?? "<nil>"), placeholder=\(carbs.placeholderValue ?? "<nil>")")
        XCTAssertEqual(Double(calories.value as? String ?? "NaN") ?? -1, 120, accuracy: 0.01)
        XCTAssertEqual(Double(protein.value as? String ?? "NaN") ?? -1, 10, accuracy: 0.01)
        XCTAssertEqual(Double(fat.value as? String ?? "NaN") ?? -1, 4, accuracy: 0.01)
        XCTAssertEqual(Double(carbs.value as? String ?? "NaN") ?? -1, 18, accuracy: 0.01)
        let saveFood = app.buttons["Save custom food"]
        scrollUntilExists(saveFood, in: app)
        XCTAssertTrue(saveFood.exists)
        XCTAssertTrue(saveFood.isEnabled)
        saveFood.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 10))
        app.buttons["servingSizePicker"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "scoop (25 g)")).firstMatch.tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["25 g"].exists)
        XCTAssertTrue(app.staticTexts["Calories: 30 kcal"].exists)
        XCTAssertTrue(app.staticTexts["Protein: 2.5 g"].exists)
        let fatPreview = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Fat: 1 g")).firstMatch
        let carbsPreview = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Carbs: 4.5 g")).firstMatch
        print("QA-3 custom preview carbohydrate accessibility labels: \(app.descendants(matching: .any).allElementsBoundByIndex.map(\.label).filter { $0.localizedCaseInsensitiveContains("carb") })")
        scrollUntilHittable(fatPreview, in: app)
        XCTAssertTrue(fatPreview.exists)
        scrollUntilHittable(carbsPreview, in: app)
        XCTAssertTrue(carbsPreview.exists)
        attachScreenshot(app, name: "Custom food with bowl and scoop sizes")
    }

    func testRemovingFirstCustomSizeRescalesNutritionBasis() {
        let app = XCUIApplication()
        app.launchArguments = servingFixtureArguments
        app.launch()
        openFoodLog(app)
        app.buttons["Search for a food"].tap()
        app.swipeUp()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Create custom food")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Custom food"].waitForExistence(timeout: 10))

        let foodName = app.textFields["Name"]
        foodName.tap()
        foodName.clearAndType("QA3 Basis Food")
        app.buttons["Add serving size"].tap()
        let names = app.textFields.matching(NSPredicate(format: "label == %@", "Serving size name"))
        let weights = app.textFields.matching(NSPredicate(format: "label == %@", "Serving size weight in grams"))
        names.element(boundBy: 0).tap()
        names.element(boundBy: 0).clearAndType("bowl")
        weights.element(boundBy: 0).tap()
        weights.element(boundBy: 0).clearAndType("100")
        XCTAssertEqual(weights.element(boundBy: 0).value as? String, "100")
        names.element(boundBy: 1).tap()
        names.element(boundBy: 1).clearAndType("scoop")
        weights.element(boundBy: 1).tap()
        weights.element(boundBy: 1).clearAndType("25")
        let calories = app.textFields["Calories per serving in kcal"]
        calories.tap()
        calories.clearAndType("120")
        print("QA-3 basis calories before keyboard dismissal: value=\(calories.value ?? "<nil>"), placeholder=\(calories.placeholderValue ?? "<nil>")")
        dismissKeyboard(app)
        print("QA-3 basis calories after keyboard dismissal: value=\(calories.value ?? "<nil>"), placeholder=\(calories.placeholderValue ?? "<nil>")")
        let removeBowl = app.buttons.matching(NSPredicate(format: "label == %@", "Remove bowl serving size")).firstMatch
        scrollUntilHittable(removeBowl, in: app, direction: "down")
        let visibleNameFields = names.allElementsBoundByIndex.sorted { $0.frame.midY < $1.frame.midY }
        let visibleWeightFields = weights.allElementsBoundByIndex.sorted { $0.frame.midY < $1.frame.midY }
        XCTAssertEqual(zip(visibleNameFields, visibleWeightFields).map { "\($0.value as? String ?? "")=\($1.value as? String ?? "")" },
                       ["bowl=100", "scoop=25"], "Serving rows must pair bowl with 100 g and scoop with 25 g")
        XCTAssertEqual(Double(calories.value as? String ?? "NaN") ?? -1, 120, accuracy: 0.01)
        let firstWeight = visibleWeightFields[0]
        firstWeight.tap()
        firstWeight.clearAndType("")
        XCTAssertEqual(Double(calories.value as? String ?? "NaN") ?? -1, 120, accuracy: 0.01,
                       "A temporarily blank serving weight must not discard the nutrient basis")
        firstWeight.clearAndType("200")
        XCTAssertEqual(Double(calories.value as? String ?? "NaN") ?? -1, 240, accuracy: 0.01)
        firstWeight.clearAndType("100")
        XCTAssertEqual(Double(calories.value as? String ?? "NaN") ?? -1, 120, accuracy: 0.01)
        dismissKeyboard(app)
        scrollUntilHittable(removeBowl, in: app, direction: "down")
        attachScreenshot(app, name: "Custom nutrient basis before first-size removal")
        XCTAssertTrue(removeBowl.exists)
        removeBowl.tap()
        XCTAssertEqual(Double(calories.value as? String ?? "NaN") ?? -1, 30, accuracy: 0.01)
        dismissKeyboard(app)
        let save = app.buttons["Save custom food"]
        scrollUntilExists(save, in: app)
        XCTAssertTrue(save.exists && save.isEnabled)
        save.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["25 g"].exists)
        XCTAssertTrue(app.staticTexts["30 kcal"].exists)
        attachScreenshot(app, name: "First serving removed with nutrition basis preserved")
    }

    func testLegacyPrecisionSurvivesUnchangedDetailSaveAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-mf.hasCompletedOnboarding", "YES", "-issue3ServingFixture", "-issue3ResetLog", "-issue3LegacyFixture"]
        app.launch()
        openFoodLog(app)
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "QA3 Legacy")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap()
        XCTAssertTrue(app.navigationBars["Edit entry"].waitForExistence(timeout: 10))
        let amount = app.textFields["servingAmountField"]
        XCTAssertEqual(amount.value as? String, "37.555")
        XCTAssertTrue(app.staticTexts["37.6 g"].exists)
        dismissKeyboard(app)
        let save = app.buttons["saveFoodChangesButton"]
        scrollUntilExists(save, in: app)
        XCTAssertTrue(save.exists)
        save.tap()

        app.terminate()
        app.launchArguments = ["-mf.hasCompletedOnboarding", "YES", "-issue3ServingFixture", "-issue3LegacyFixture"]
        app.launch()
        openFoodLog(app)
        let reopened = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "QA3 Legacy")).firstMatch
        XCTAssertTrue(reopened.waitForExistence(timeout: 10))
        reopened.tap()
        XCTAssertEqual(app.textFields["servingAmountField"].value as? String, "37.555")
        attachScreenshot(app, name: "Legacy exact grams retained after save and relaunch")
    }

    private static func todayCalories(from label: String) -> Double {
        let tail = label.dropFirst("Today: ".count)
        let digits = tail.prefix { $0.isNumber || $0 == "." }
        return Double(digits) ?? .nan
    }

    private func dismissKeyboard(_ app: XCUIApplication) {
        let done = app.buttons["Done"]
        if done.exists && done.isHittable { done.tap() }
        else if app.keyboards.firstMatch.exists {
            let navigationBar = app.navigationBars.firstMatch
            if navigationBar.isHittable { navigationBar.tap() }
        }
    }

    private func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication, direction: String = "up", maxSwipes: Int = 8) {
        for _ in 0..<maxSwipes where !element.exists {
            if direction == "up" { app.swipeUp() } else { app.swipeDown() }
        }
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, direction: String = "up", maxSwipes: Int = 8) {
        for _ in 0..<maxSwipes where !element.isHittable {
            if direction == "up" { app.swipeUp() } else { app.swipeDown() }
        }
    }

    private func accessibleTimestamp(_ datePicker: XCUIElement) -> String? {
        if let value = datePicker.value as? String, !value.isEmpty { return value }
        let labels = datePicker.descendants(matching: .any).allElementsBoundByIndex
            .map(\.label)
            .filter { !$0.isEmpty }
        guard labels.count >= 2 else { return nil }
        return labels.sorted().joined(separator: " | ")
    }

    private func openFoodLog(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons["Food Log"]
        XCTAssertTrue(tab.waitForExistence(timeout: 30))
        tab.tap()
    }

    private func openFood(named name: String, app: XCUIApplication) {
        app.buttons["Search for a food"].tap()
        let food = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(food.waitForExistence(timeout: 10))
        food.tap()
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var servingFixtureArguments: [String] {
        ["-mf.hasCompletedOnboarding", "YES", "-issue3ServingFixture", "-issue3ResetLog"]
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        tap()
        let current = value as? String ?? ""
        let placeholder = placeholderValue ?? ""
        if !current.isEmpty {
            press(forDuration: 1)
            let selectAll = XCUIApplication().descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", "Select All")).firstMatch
            if selectAll.waitForExistence(timeout: 1) {
                selectAll.tap()
                typeText(XCUIKeyboardKey.delete.rawValue)
                let cleared = value as? String ?? ""
                XCTAssertTrue(cleared.isEmpty || cleared == placeholder,
                              "Field must be empty before entering `\(text)`; found `\(cleared)`")
            } else if current != placeholder {
                coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).tap()
                typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
                let cleared = value as? String ?? ""
                XCTAssertTrue(cleared.isEmpty || cleared == placeholder,
                              "Field must be empty before entering `\(text)`; found `\(cleared)`")
            }
        }
        if text.isEmpty {
            let cleared = value as? String ?? ""
            XCTAssertTrue(cleared.isEmpty || cleared == placeholder, "Field must remain empty after clearing")
            return
        }
        typeText(text)
        XCTAssertEqual(value as? String ?? "", text, "Field must contain exactly the requested text after replacement")
    }
}
