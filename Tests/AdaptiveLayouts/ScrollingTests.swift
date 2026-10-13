import XCTest

final class ScrollingTests: XCTestCase {
    func testTaggedRowsReflowAcrossWorkspaceWidths() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_SCROLL_ROWS"] = "300"
        app.launch()
        guard app.frame.width >= 760 else { throw XCTSkip("Run the width-reflow case on a wide iPad.") }
        XCTAssertTrue(app.staticTexts["QA expense 299"].waitForExistence(timeout: 30))
        let firstRow = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ledger.row."))
            .containing(.staticText, identifier: "QA expense 299").firstMatch
        for mode in ["compact", "wide", "compact"] {
            app.buttons["qa.\(mode)"].tap()
            XCTAssertEqual(app.scrollViews["adaptive.page"].firstMatch.value as? String, mode)
            XCTAssertTrue(firstRow.isHittable)
            for name in ["QA tag", "生活", "待核对", "长标签换行验证"] {
                let tag = firstRow.staticTexts[name]
                XCTAssertTrue(tag.exists)
                XCTAssertGreaterThanOrEqual(tag.frame.minX, firstRow.frame.minX)
                XCTAssertLessThanOrEqual(tag.frame.maxX, firstRow.frame.maxX)
                XCTAssertLessThanOrEqual(tag.frame.maxY, firstRow.frame.maxY)
            }
            attach(app, "tagged-row-\(mode)")
        }
    }

    func testLongTaggedLedgerScrollsWithoutEditing() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_REAL_ROOT"] = "1"
        app.launchEnvironment["QA_SCROLL_ROWS"] = "300"
        app.launch()
        XCTAssertTrue(app.staticTexts["QA expense 299"].waitForExistence(timeout: 30))
        let scroll = app.scrollViews["adaptive.page"].firstMatch
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        // Deceleration duration is not a display FPS or hitch-count measurement.
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric], options: options) {
            for _ in 0..<3 { scroll.swipeUp() }
            for _ in 0..<3 { scroll.swipeDown() }
        }
        XCTAssertFalse(app.textFields["entry.amount"].exists)
        for _ in 0..<8 {
            if app.staticTexts["QA expense 299"].isHittable { break }
            scroll.swipeDown()
        }
        XCTAssertTrue(app.staticTexts["QA expense 299"].isHittable)
        let firstRow = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ledger.row."))
            .containing(.staticText, identifier: "QA expense 299").firstMatch
        for name in ["QA tag", "生活", "待核对", "长标签换行验证"] {
            XCTAssertTrue(firstRow.staticTexts[name].exists)
            XCTAssertLessThanOrEqual(firstRow.staticTexts[name].frame.maxY, firstRow.frame.maxY)
        }
        attach(app, "long-tagged-ledger")
    }

    func testAllPhonePageEndsClearTheTabBar() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_REAL_ROOT"] = "1"
        app.launch()
        guard app.buttons["mainTab.expense"].waitForExistence(timeout: 20) else {
            throw XCTSkip("Run the end-clearance case on a phone with the custom bottom tab bar.")
        }
        let tabBar = app.otherElements["mainTab.bar"]
        XCTAssertTrue(tabBar.exists)

        for page in ["expense", "income", "vault", "stats"] {
            app.buttons["mainTab.\(page)"].tap()
            let last: XCUIElement
            if page == "expense" || page == "income" {
                last = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ledger.row."))
                    .containing(.staticText, identifier: "QA \(page) 0").firstMatch
            } else if page == "vault" {
                last = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vault.deposit."))
                    .containing(.staticText, identifier: "QA deposit 0").firstMatch
            } else {
                last = app.buttons["stats.distribution.餐饮"]
            }

            let scroll = app.scrollViews["adaptive.page"].firstMatch
            for _ in 0..<15 {
                if last.exists && last.isHittable && last.frame.maxY < tabBar.frame.minY - 8 { break }
                let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
                start.press(forDuration: 0.01, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0.1)
            }
            attach(app, "phone-end-\(page)")
            XCTAssertTrue(last.exists, "Missing final item on \(page)")
            XCTAssertTrue(last.isHittable, "Final item must be reachable on \(page)")
            XCTAssertLessThanOrEqual(last.frame.maxY, tabBar.frame.minY - 8,
                                     "The complete final item must clear the tab bar on \(page)")
            XCTAssertGreaterThanOrEqual(last.frame.minY, app.navigationBars.firstMatch.frame.maxY)
        }
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "\(name)-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
}
