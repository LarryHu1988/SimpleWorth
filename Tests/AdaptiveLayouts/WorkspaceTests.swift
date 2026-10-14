import XCTest

final class WorkspaceTests: XCTestCase {
    func testFourPageCompositionAndRightSettings() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_SYNTHETIC_SIZE"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["qa.wide"].waitForExistence(timeout: 15))
        for key in ["expense", "income", "vault", "stats"] {
            app.buttons["qa.compact"].tap()
            let tab = app.buttons["mainTab.\(key)"]
            let symbols = ["expense": "minus.circle.fill", "income": "plus.circle.fill",
                           "vault": "lock.shield.fill", "stats": "chart.bar.xaxis"]
            let icon = tab.images[symbols[key]!].firstMatch
            (icon.exists ? icon : tab).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in tab.isSelected }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
            app.buttons["qa.wide"].tap()
            let primary = app.scrollViews["adaptive.page"].firstMatch
            let secondary = app.scrollViews["workspace.secondary"].firstMatch
            XCTAssertTrue(primary.exists)
            XCTAssertTrue(secondary.exists)
            XCTAssertLessThanOrEqual(primary.frame.maxX, secondary.frame.minX + 1)
            switch key {
            case "expense", "income":
                XCTAssertTrue(primary.staticTexts[key == "expense" ? "最近支出" : "最近收入"].exists)
                XCTAssertEqual(secondary.otherElements["stats.distribution.panel"].value as? String, key)
                XCTAssertTrue(secondary.buttons["标签"].exists)
            case "vault":
                XCTAssertTrue(primary.staticTexts["当前小金库"].exists)
                XCTAssertTrue(primary.staticTexts["最近存入"].exists)
                XCTAssertTrue(secondary.staticTexts["收支概览"].exists)
                XCTAssertTrue(secondary.staticTexts["月度趋势"].exists)
            default:
                XCTAssertTrue(primary.staticTexts["收支概览"].exists)
                XCTAssertTrue(primary.staticTexts["月度趋势"].exists)
                XCTAssertTrue(secondary.staticTexts["分类占比"].exists)
            }
            attach(app, "workspace-\(key)")
        }
        let primary = app.scrollViews["adaptive.page"].firstMatch
        let previousFrame = primary.frame
        app.buttons["stats.settings"].tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(primary.staticTexts["收支概览"].exists)
        XCTAssertEqual(primary.frame, previousFrame)
        app.buttons["货币选择"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 5))
        XCTAssertTrue(primary.staticTexts["收支概览"].exists)
        attach(app, "workspace-right-currency")
        app.navigationBars["货币选择"].buttons["设置"].firstMatch.tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.scrollViews["workspace.secondary"].staticTexts["分类占比"].waitForExistence(timeout: 5))
    }

    func testIndependentScrollingAndPeriodSharing() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_SYNTHETIC_SIZE"] = "1"
        app.launch()
        app.buttons["qa.wide"].tap()
        let primary = app.scrollViews["adaptive.page"].firstMatch
        let secondary = app.scrollViews["workspace.secondary"].firstMatch
        let chart = secondary.otherElements["stats.distribution.chart"]
        let chartY = chart.frame.minY
        primary.swipeUp()
        XCTAssertEqual(chart.frame.minY, chartY, accuracy: 1)
        XCTAssertFalse(app.textFields["entry.amount"].exists)
        secondary.buttons["period.month"].firstMatch.tap()
        app.buttons["1月"].firstMatch.tap()
        XCTAssertTrue((app.buttons["period.month"].firstMatch.value as? String)?.contains("1") == true)
        XCTAssertFalse(secondary.otherElements["stats.distribution.chart"].exists)
        attach(app, "workspace-shared-january")
        app.buttons["qa.compact"].tap()
        XCTAssertFalse(app.scrollViews["workspace.secondary"].exists)
        XCTAssertTrue((app.buttons["period.month"].firstMatch.value as? String)?.contains("1") == true)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
