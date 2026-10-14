import XCTest

final class InteractionTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testDragOrderPersistsAndEditorUsesIt() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["家庭"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["preserved"].waitForExistence(timeout: 5))
        let names = ["家庭", "通勤", "旅行"].sorted {
            app.staticTexts[$0].firstMatch.frame.midY < app.staticTexts[$1].firstMatch.frame.midY
        }
        let first = app.staticTexts[names[0]].firstMatch
        let last = app.staticTexts[names[2]].firstMatch
        let expectedOrder = [names[2]] + Array(names.prefix(2))
        XCTAssertTrue(last.exists)
        let table = app.collectionViews.firstMatch
        let from = table.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0))
            .withOffset(CGVector(dx: 0, dy: last.frame.midY - table.frame.minY))
        let to = table.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0))
            .withOffset(CGVector(dx: 0, dy: first.frame.minY - table.frame.minY - 3))
        from.press(forDuration: 0.4, thenDragTo: to)
        XCTAssertLessThan(last.frame.midY, first.frame.midY)
        attach(app, "tags-reordered")
        app.terminate()
        app.launch()
        XCTAssertTrue(last.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["preserved"].exists)
        XCTAssertLessThan(last.frame.midY, first.frame.midY)
        app.buttons["qa.expense"].tap()
        reveal(app.buttons["entry.tag.旅行"], in: app)
        let ordered = expectedOrder.map { app.buttons["entry.tag.\($0)"].frame }
        for pair in zip(ordered, ordered.dropFirst()) {
            XCTAssertTrue(pair.0.minY < pair.1.minY || (pair.0.minY == pair.1.minY && pair.0.minX < pair.1.minX))
        }
        attach(app, "editor-tag-order")
    }

    func testEnglishCategoriesAndTagActionsRemainAvailable() {
        let app = XCUIApplication()
        app.launchEnvironment["QA_LANGUAGE"] = "en"
        app.launch()
        XCTAssertTrue(app.buttons["Edit Tag"].firstMatch.waitForExistence(timeout: 15))
        app.buttons["Edit Tag"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Edit Tag"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["View Tagged Entries"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Close"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Close"].firstMatch.tap()
        app.buttons["qa.expense"].tap()
        XCTAssertFalse(app.textFields["category.search"].exists)
        let shoes = app.buttons["entry.category.鞋靴"]
        reveal(shoes, in: app)
        shoes.tap()
        XCTAssertTrue(shoes.isSelected)
        attach(app, "english-shoes-category")
    }

    func testExpenseIncomeCategoriesAndLegacyCategory() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["qa.expense"].tap()
        XCTAssertFalse(app.textFields["category.search"].exists)
        let shoes = app.buttons["entry.category.鞋靴"]
        reveal(shoes, in: app)
        shoes.tap()
        XCTAssertTrue(shoes.isSelected)
        attach(app, "shoes-category")
        app.buttons["取消"].firstMatch.tap()
        app.buttons["qa.income"].tap()
        XCTAssertFalse(app.textFields["category.search"].exists)
        let resale = app.buttons["entry.category.二手"]
        reveal(resale, in: app)
        resale.tap()
        XCTAssertTrue(resale.isSelected)
        attach(app, "resale-category")
        app.buttons["取消"].firstMatch.tap()
        app.buttons["qa.legacy"].tap()
        reveal(app.buttons["entry.category.旧分类"], in: app)
        XCTAssertTrue(app.buttons["entry.category.旧分类"].isSelected)
        attach(app, "legacy-category-kept")
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<24 {
            let top = app.navigationBars.allElementsBoundByIndex.last?.frame.maxY ?? 90
            let frame = element.exists ? element.frame : .zero
            if element.isHittable, frame.minY > top + 8, frame.maxY < app.frame.maxY - 40 { return }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            let belowHeader = element.exists && frame.height > 0 && frame.minY <= top + 8
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: belowHeader ? 0.88 : 0.40))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
