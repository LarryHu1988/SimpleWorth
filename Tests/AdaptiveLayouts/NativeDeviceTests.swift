import XCTest

final class NativeDeviceTests: XCTestCase {
    func testCompactSettingsRoutesAndReturn() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_REAL_ROOT"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["period.year"].waitForExistence(timeout: 20))
        tapTab(in: app, key: "stats", symbol: "chart.bar.xaxis")
        guard app.scrollViews["adaptive.page"].firstMatch.value as? String == "compact" else {
            throw XCTSkip("Run on a phone or in the Duo portrait/outer display.")
        }
        app.buttons["stats.settings"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        app.buttons["货币选择"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 5))
        returnFromCurrency(in: app)
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.buttons["stats.settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["stats.settings"].isHittable)
        attach(app, "compact-settings-return")
    }

    func testNativeWideInteractions() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_NATIVE_SIZE"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["period.year"].waitForExistence(timeout: 20))
        guard app.scrollViews["adaptive.page"].firstMatch.value as? String == "wide" else {
            throw XCTSkip("Run in the opened Duo inner display in landscape.")
        }
        XCTAssertEqual(app.scrollViews["adaptive.page"].firstMatch.value as? String, "wide")
        let division = activeDivision(in: app)
        if let division {
            XCTAssertLessThanOrEqual(app.staticTexts["最近支出"].firstMatch.frame.maxX, division.minX)
        }

        let row = app.staticTexts["QA expense 24"]
        XCTAssertTrue(row.isHittable)
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.01, thenDragTo: start.withOffset(CGVector(dx: 110, dy: 4)),
                    withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.buttons["复制"].firstMatch.isHittable)
        let exposed = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        exposed.press(forDuration: 0.01, thenDragTo: exposed.withOffset(CGVector(dx: -110, dy: -4)),
                      withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertFalse(app.textFields["entry.amount"].exists)

        tapTab(in: app, key: "stats", symbol: "chart.bar.xaxis")
        let chart = app.otherElements["stats.distribution.chart"].firstMatch
        reveal(chart, in: app)
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.30)).tap()
        XCTAssertTrue(app.buttons["stats.distribution.鞋靴"].isSelected)
        let rows = app.otherElements["stats.distribution.rows"].firstMatch
        XCTAssertLessThanOrEqual(chart.frame.maxY, rows.frame.minY + 1)
        if let division {
            XCTAssertGreaterThanOrEqual(chart.frame.minX, division.maxX)
            XCTAssertGreaterThanOrEqual(rows.frame.minX, division.maxX)
        }
        attach(app, "inner-selected-chart")
        app.buttons["stats.settings"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        app.buttons["货币选择"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["adaptive.page"].firstMatch.staticTexts["收支概览"].exists)
        attach(app, "inner-right-settings")
        returnFromCurrency(in: app)
        app.buttons["settings.done"].tap()

        tapTab(in: app, key: "vault", symbol: "lock.shield.fill")
        let goal = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vault.select.")).firstMatch
        reveal(goal, in: app)
        goal.tap()
        XCTAssertTrue(app.otherElements["vault.selectedGoal"].waitForExistence(timeout: 5))
        attach(app, "inner-selected-goal")

        tapTab(in: app, key: "expense", symbol: "minus.circle.fill")
        app.buttons["新增支出"].firstMatch.tap()
        let amount = app.textFields["entry.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("120")
        for (symbol, digit, expected) in [("+", "30", "120+30"), ("-", "10", "120+30-10"),
                                           ("×", "2", "120+30-10×2"), ("÷", "5", "120+30-10×2÷5")] {
            app.buttons["amount.operator.\(symbol)"].tap()
            amount.typeText(digit)
            XCTAssertEqual(amount.value as? String, expected)
        }
        app.buttons["amount.equals"].tap()
        let calculated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            amount.value as? String == "146"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [calculated], timeout: 3), .completed)
        attach(app, "inner-calculated-amount")
        app.buttons["取消"].firstMatch.tap()
    }

    func testNativeNavigationAndEntryDraft() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_NATIVE_SIZE"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["period.year"].waitForExistence(timeout: 20))
        for (key, symbol) in [("expense", "minus.circle.fill"), ("income", "plus.circle.fill"), ("vault", "lock.shield.fill"), ("stats", "chart.bar.xaxis")] {
            tapTab(in: app, key: key, symbol: symbol)
            XCTAssertTrue(app.buttons["period.year"].isHittable)
            attach(app, "native-\(key)")
        }
        tapTab(in: app, key: "expense", symbol: "minus.circle.fill")
        app.buttons["新增支出"].firstMatch.tap()
        let amount = app.textFields["entry.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        XCTAssertTrue(app.buttons["amount.done"].waitForExistence(timeout: 5))
        amount.typeText("123.45")
        for (symbol, digit) in [("+", "2"), ("-", "1"), ("×", "2"), ("÷", "2")] {
            let control = app.buttons["amount.operator.\(symbol)"]
            XCTAssertTrue(control.isHittable)
            XCTAssertGreaterThanOrEqual(control.frame.width, 44)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
            control.tap()
            amount.typeText(digit)
        }
        XCTAssertEqual(amount.value as? String, "123.45+2-1×2÷2")
        app.buttons["amount.equals"].tap()
        let calculated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            amount.value as? String == "124.45"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [calculated], timeout: 3), .completed)
        XCTAssertTrue(app.buttons["amount.done"].isHittable)
        attach(app, "native-editor")
        app.buttons["amount.done"].tap()
        XCTAssertFalse(app.buttons["amount.operator.+"].exists)
        app.buttons["取消"].firstMatch.tap()
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "\(name)-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    private func returnFromCurrency(in app: XCUIApplication) {
        let headerBack = app.navigationBars["货币选择"].buttons["设置"].firstMatch
        if headerBack.exists {
            headerBack.tap()
        } else {
            app.buttons["BackButton"].firstMatch.tap()
        }
    }

    private func tapTab(in app: XCUIApplication, key: String, symbol: String) {
        func tab() -> XCUIElement {
            let custom = app.buttons["mainTab.\(key)"]
            if custom.exists { return custom }
            let titles = ["expense": "支出", "income": "收入", "vault": "金库", "stats": "统计"]
            let native = app.buttons.matching(NSPredicate(format: "label == %@", titles[key]!))
                .containing(.image, identifier: symbol).firstMatch
            return native.exists ? native : app.buttons[symbol].firstMatch
        }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let control = tab()
            return control.exists && control.isHittable
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        tab().tap()
    }

    private func activeDivision(in app: XCUIApplication) -> CGRect? {
        let recorder = app.otherElements["qa.pose"]
        guard recorder.exists else { return nil }
        guard let value = recorder.value as? String,
              let data = value.data(using: .utf8),
              let pose = try? JSONDecoder().decode(Pose.self, from: data) else {
            XCTFail("The pose recorder must provide valid geometry before checking fold avoidance.")
            return nil
        }
        return pose.divisions.first(where: { $0.active && $0.height > $0.width }).map {
            CGRect(x: $0.x + pose.originX, y: $0.y + pose.originY, width: $0.width, height: $0.height)
        }
    }

    private struct Pose: Decodable {
        let originX: Double
        let originY: Double
        let divisions: [Region]
        struct Region: Decodable {
            let x: Double
            let y: Double
            let width: Double
            let height: Double
            let active: Bool
        }
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<20 {
            if element.exists, element.isHittable,
               element.frame.minY > 100, element.frame.maxY < app.frame.maxY - 60 { return }
            let primary = app.scrollViews["adaptive.page"].firstMatch
            let secondary = app.scrollViews["workspace.secondary"].firstMatch
            let pane = secondary.exists && element.frame.minX >= secondary.frame.minX ? secondary : primary
            let start = pane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            start.press(forDuration: 0.01, thenDragTo: pane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        }
        XCTAssertTrue(element.isHittable)
    }
}
