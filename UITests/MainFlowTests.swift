import XCTest

/// The main flows on the demo data, in English, so the assertions do not depend on the device language.
@MainActor
final class MainFlowTests: XCTestCase {
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments =
            ["-PottDemo", "full", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        return app
    }

    func testOverviewShowsWhatIsLeft() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["left for you"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["$987"].exists || app.staticTexts["€987"].exists)
    }

    func testAddFixedCost() {
        let app = launch()
        app.buttons["Add fixed cost"].tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Newspaper")
        let amount = app.textFields["Amount (€)"]
        amount.tap()
        amount.typeText("12.50")
        app.buttons["Subscriptions & contracts"].tap()
        app.buttons["Save"].tap()
        // The new row may sit below the fold of the lazy list; the confirmation is always on screen.
        let saved = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Newspaper"))
        XCTAssertTrue(saved.firstMatch.waitForExistence(timeout: 5))
    }

    func testTogetherViewShowsThePot() {
        let app = launch()
        app.buttons["Together"].tap()
        XCTAssertTrue(app.staticTexts["left in the pot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["How do you pay in?"].exists)
    }

    func testCalculatorComputesNetPay() {
        let app = launch(["-PottCalculator"])
        XCTAssertTrue(app.staticTexts["Your net pay"].waitForExistence(timeout: 5))
        let field = app.textFields["Gross per month (€)"]
        field.tap()
        field.press(forDuration: 1)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        field.typeText("3000")
        XCTAssertTrue(app.staticTexts["Wage tax"].exists)
    }

    func testCompanyCarAddsTaxedBenefit() {
        let app = launch(["-PottCalculator"])
        XCTAssertTrue(app.staticTexts["Your net pay"].waitForExistence(timeout: 5))
        let field = app.textFields["Gross per month (€)"]
        field.tap()
        field.press(forDuration: 1)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        field.typeText("4500")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Special cases")).firstMatch.tap()
        let car = app.switches["Company car"]
        XCTAssertTrue(car.waitForExistence(timeout: 5))
        let knob = car.switches.firstMatch
        if knob.exists {
            knob.tap()
        } else {
            car.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        let price = app.textFields["List price"]
        XCTAssertTrue(price.waitForExistence(timeout: 5))
        price.tap()
        price.typeText("45678")
        let benefit = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Includes"))
        XCTAssertTrue(benefit.firstMatch.waitForExistence(timeout: 5))
    }

    func testOneOffPaymentShowsItsOwnResult() {
        let app = launch(["-PottCalculator", "-PottSpecialCases"])
        XCTAssertTrue(app.staticTexts["Your net pay"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["One-off payment"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["of €3,000.00"].exists || app.staticTexts["of €3,000"].exists)
    }

    /// Opens the picker at the top of the calculator, turns the wheels to the given rows, closes it.
    private func pick(_ app: XCUIApplication, _ rows: [String]) {
        let header = app.buttons["calculatorPicker"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        header.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        for row in rows {
            app.buttons[row].firstMatch.tap()
            // Let the wheel come to rest.
            _ = app.staticTexts["__never__"].waitForExistence(timeout: 0.8)
        }
        app.buttons["Done"].tap()
    }

    func testPickerSwitchesToMiniJob() {
        let app = launch(["-PottCalculator"])
        pick(app, ["Mini job"])
        XCTAssertTrue(app.switches["Exempt from pension insurance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Gross per month (€)"].exists)
    }

    func testChoosingHealthInsurer() {
        let app = launch(["-PottCalculator"])
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "More details")).firstMatch.tap()
        let row = app.buttons["healthInsurerRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let search = app.textFields["Name, e.g. TK or AOK"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.typeText("Barmer")
        let barmer = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "BARMER")).firstMatch
        XCTAssertTrue(barmer.waitForExistence(timeout: 5))
        barmer.tap()
        let chosen = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "BARMER, 3.29"))
        XCTAssertTrue(chosen.firstMatch.waitForExistence(timeout: 5))
    }

    func testSelfEmployedTakeOutMatchesHandCalculation() {
        let app = launch(["-PottCalculator"])
        pick(app, ["Self-employed"])
        let field = app.textFields["Profit per month (€)"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.press(forDuration: 1)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        field.typeText("5000")
        // 5,000 − 802.83 income tax − 875 health − 210 care (see SelfEmployedTests.freelancer).
        XCTAssertTrue(app.staticTexts["€3,112.17"].waitForExistence(timeout: 5))
        app.swipeUp()
        let reserve = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Put aside each quarter"))
        XCTAssertTrue(reserve.firstMatch.waitForExistence(timeout: 5))
    }

    func testSelfEmployedDayRate() {
        let app = launch(["-PottCalculator"])
        pick(app, ["Self-employed", "Day rate"])
        let field = app.textFields["Day rate (€)"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.press(forDuration: 1)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        field.typeText("800")
        // 800 × 220 days / 12 = 14,666.67 a month (no costs in the demo).
        let days = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "€14,666.67"))
        XCTAssertTrue(days.firstMatch.waitForExistence(timeout: 5))
    }

    func testShortTimeWorkAddsAllowance() {
        let app = launch(["-PottCalculator"])
        XCTAssertTrue(app.staticTexts["Your net pay"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Special cases")).firstMatch.tap()
        let toggle = app.switches["Short-time work this month"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let knob = toggle.switches.firstMatch
        if knob.exists {
            knob.tap()
        } else {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        let actual = app.textFields["Gross actually earned"]
        XCTAssertTrue(actual.waitForExistence(timeout: 5))
        actual.tap()
        actual.typeText("1500")
        XCTAssertTrue(app.staticTexts["Short-time allowance"].waitForExistence(timeout: 5))
    }

    func testSettingsOpenAndModulesListed() {
        let app = launch()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Modules"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches.count >= 6)
    }
}
