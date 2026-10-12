import XCTest

final class ResizeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testSettingsRouteAndChartSelectionSurvivePresentationMigration() throws {
        let app = XCUIApplication()
        app.launchEnvironment["QA_WORKSPACE_COMMANDS"] = "1"
        app.launch()
        let recorder = app.otherElements["qa.commandDirectory"]
        XCTAssertTrue(recorder.waitForExistence(timeout: 5))
        let command = URL(fileURLWithPath: recorder.value as? String ?? "")
            .appendingPathComponent("qa-workspace-command.json")
        defer { try? FileManager.default.removeItem(at: command) }
        let nativeTab = app.buttons.matching(NSPredicate(format: "label == %@", "统计"))
            .containing(.image, identifier: "chart.bar.xaxis").firstMatch
        (nativeTab.exists ? nativeTab : app.buttons["chart.bar.xaxis"].firstMatch).tap()
        let chart = app.otherElements["stats.distribution.chart"].firstMatch
        reveal(chart, in: app)
        chart.coordinate(withNormalizedOffset: CGVector(
            dx: 0.5 + chart.frame.height * 0.34 / chart.frame.width, dy: 0.25
        )).tap()
        XCTAssertTrue(app.buttons["stats.distribution.鞋靴"].isSelected)
        app.buttons["stats.settings"].tap()
        app.buttons["货币选择"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 5))
        try JSONEncoder().encode(true).write(to: command, options: .atomic)
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.scrollViews["adaptive.page"].firstMatch.value as? String == "wide"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 8), .completed)
        XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 8))
        let primary = app.scrollViews["adaptive.page"].firstMatch
        XCTAssertEqual(primary.value as? String, "wide")
        XCTAssertGreaterThanOrEqual(app.navigationBars["货币选择"].frame.minX, primary.frame.maxX)
        attach(app, "settings-migrated-to-pane")
        try JSONEncoder().encode(false).write(to: command, options: .atomic)
        let portrait = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.scrollViews["adaptive.page"].firstMatch.value as? String == "compact"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [portrait], timeout: 8), .completed)
        XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 8))
        attach(app, "settings-migrated-to-sheet")
        app.navigationBars["货币选择"].buttons["设置"].firstMatch.tap()
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.buttons["stats.settings"].isHittable)
        reveal(chart, in: app)
        XCTAssertTrue(app.buttons["stats.distribution.鞋靴"].isSelected)
    }

    func testFourPagesKeepPeriodAcrossLiveResize() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["mainTab.expense"].waitForExistence(timeout: 15))
        for name in ["expense", "income", "vault", "stats"] {
            app.buttons["qa.compact"].tap()
            app.buttons["mainTab.\(name)"].tap()
            let month = app.buttons["period.month"].firstMatch
            XCTAssertTrue(month.waitForExistence(timeout: 5))
            month.tap()
            app.buttons["1月"].firstMatch.tap()
            XCTAssertTrue((month.value as? String)?.contains("1") == true)
            app.buttons["qa.wide"].tap()
            XCTAssertTrue((month.value as? String)?.contains("1") == true)
            XCTAssertEqual(app.scrollViews["adaptive.page"].firstMatch.value as? String, "wide")
            attach(app, "\(name)-wide")
            app.buttons["qa.compact"].tap()
            XCTAssertTrue((month.value as? String)?.contains("1") == true)
            XCTAssertEqual(app.scrollViews["adaptive.page"].firstMatch.value as? String, "compact")
        }
    }

    func testChartSelectionSurvivesResize() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["mainTab.stats"].tap()
        let chart = app.otherElements["stats.distribution.chart"].firstMatch
        reveal(chart, in: app)
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.30)).tap()
        let shoes = app.buttons["stats.distribution.鞋靴"]
        XCTAssertTrue(shoes.isSelected)
        app.buttons["qa.wide"].tap()
        XCTAssertTrue(shoes.isSelected)
        let rows = app.otherElements["stats.distribution.rows"].firstMatch
        XCTAssertLessThanOrEqual(chart.frame.maxY, rows.frame.minY + 1)
        attach(app, "stats-selection-wide")
        app.buttons["qa.compact"].tap()
        XCTAssertTrue(shoes.isSelected)
    }

    func testEditorDraftSurvivesRotation() {
        let app = XCUIApplication()
        app.launchEnvironment["QA_NATIVE_SIZE"] = "1"
        app.launch()
        app.buttons["新增支出"].firstMatch.tap()
        let amount = app.textFields["entry.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        XCTAssertTrue(app.buttons["amount.operator.+"].waitForExistence(timeout: 5))
        amount.typeText("123.45+2")
        let note = app.textFields["entry.note"]
        dismissKeyboardPreview(in: app)
        reveal(note, in: app)
        note.tap()
        note.typeText("QA fold draft")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(note.value as? String, "QA fold draft")
        XCTAssertEqual(amount.value as? String, "123.45+2")
        attach(app, "draft-landscape")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(note.value as? String, "QA fold draft")
        XCTAssertEqual(amount.value as? String, "123.45+2")
        app.buttons["取消"].firstMatch.tap()
    }

    func testWideAmountOperator() {
        let app = XCUIApplication()
        app.launchEnvironment["QA_NATIVE_SIZE"] = "1"
        app.launch()
        app.buttons["新增支出"].firstMatch.tap()
        let amount = app.textFields["entry.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("120")
        dismissKeyboardPreview(in: app)
        for (symbol, digit, expected) in [("+", "30", "120+30"), ("-", "10", "120+30-10"),
                                           ("×", "2", "120+30-10×2"), ("÷", "5", "120+30-10×2÷5")] {
            let control = app.buttons["amount.operator.\(symbol)"]
            XCTAssertTrue(control.waitForExistence(timeout: 5))
            control.tap()
            let inserted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (amount.value as? String)?.hasSuffix(symbol) == true
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [inserted], timeout: 3), .completed)
            amount.typeText(digit)
            XCTAssertEqual(amount.value as? String, expected)
        }
        app.buttons["amount.equals"].tap()
        let calculated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            amount.value as? String == "146"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [calculated], timeout: 3), .completed)
        attach(app, "ipad-calculated-amount")
        app.buttons["amount.done"].tap()
        XCTAssertFalse(app.buttons["amount.operator.+"].exists)
        app.buttons["取消"].firstMatch.tap()
    }

    func testOpenRowClosesAfterResizeWithoutEditing() {
        let app = XCUIApplication()
        app.launch()
        let row = app.staticTexts["QA expense 24"]
        reveal(row, in: app)
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.01, thenDragTo: start.withOffset(CGVector(dx: 110, dy: 10)),
                    withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.buttons.matching(identifier: "复制").allElementsBoundByIndex.contains { $0.isHittable })
        app.buttons["qa.wide"].tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.buttons.matching(identifier: "复制").count == 0
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        XCTAssertFalse(app.textFields["entry.amount"].exists)
        app.buttons["qa.compact"].tap()
        XCTAssertFalse(app.textFields["entry.amount"].exists)
        reveal(row, in: app)
        row.tap()
        XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 5))
        app.buttons["取消"].firstMatch.tap()
    }

    func testSelectedVaultGoalSurvivesResize() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["mainTab.vault"].tap()
        app.buttons["qa.wide"].tap()
        let goal = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vault.select.")).firstMatch
        reveal(goal, in: app)
        goal.tap()
        XCTAssertTrue(app.otherElements["vault.selectedGoal"].waitForExistence(timeout: 5))
        app.buttons["qa.compact"].tap()
        app.buttons["qa.wide"].tap()
        XCTAssertTrue(app.otherElements["vault.selectedGoal"].exists)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<24 {
            let top = app.navigationBars.allElementsBoundByIndex.last?.frame.maxY ?? 90
            if element.exists, element.isHittable, element.frame.minY > top + 5,
               element.frame.maxY < app.frame.maxY - 50 { return }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
            let moveDown = element.exists && element.frame.minY <= top + 5
            start.press(forDuration: 0.01, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: moveDown ? 0.9 : 0.40)))
        }
        XCTAssertTrue(element.isHittable)
    }

    private func dismissKeyboardPreview(in app: XCUIApplication) {
        guard app.popovers.descendants(matching: .key).count > 0 else { return }
        let control = app.buttons["amount.operator.+"]
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: control.frame.midX, dy: control.frame.midY)).tap()
        XCTAssertEqual(app.popovers.descendants(matching: .key).count, 0)
        // Allow the system keyboard preview dismissal to settle.
        Thread.sleep(forTimeInterval: 1)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
