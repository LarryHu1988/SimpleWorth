import XCTest

final class GestureTests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Entry 8"].waitForExistence(timeout: 10))
    }

    private func drag(_ row: XCUIElement, dx: CGFloat, dy: CGFloat) {
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.01, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)),
                    withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    private func assertEvents(_ expected: String = "edit=0,copy=0,refund=0,delete=0") {
        XCTAssertEqual(app.staticTexts["events"].label, expected)
    }

    private func button(_ title: String, in row: XCUIElement) throws -> XCUIElement {
        let y = row.frame.midY
        return try XCTUnwrap(app.buttons.matching(identifier: title).allElementsBoundByIndex.first {
            abs($0.frame.midY - y) < 2 && $0.isHittable
        }, "No visible \(title) button in the swiped row")
    }

    func testDiagonalHorizontalSwipesDoNotScrollOrEdit() throws {
        let row = app.staticTexts["Entry 8"]
        let originalY = row.frame.midY
        for i in 0..<6 {
            let drift: CGFloat = i.isMultiple(of: 2) ? 25 : -25
            drag(row, dx: 110, dy: drift)
            _ = try button("复制", in: row)
            XCTAssertEqual(row.frame.midY, originalY, accuracy: 2)
            drag(row, dx: -130, dy: -drift)
            XCTAssertEqual(row.frame.midY, originalY, accuracy: 2)
            assertEvents()
            drag(row, dx: -190, dy: drift)
            _ = try button("退款", in: row)
            _ = try button("删除", in: row)
            XCTAssertEqual(row.frame.midY, originalY, accuracy: 2)
            // Start on the visible foreground, not in the exposed buttons.
            let start = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: 70, dy: row.frame.midY))
            start.press(forDuration: 0.01, thenDragTo: start.withOffset(CGVector(dx: 190, dy: -drift)),
                        withVelocity: .slow, thenHoldForDuration: 0.1)
            XCTAssertEqual(row.frame.midY, originalY, accuracy: 2)
            assertEvents()
        }
    }

    func testVerticalScrollingOnClosedAndOpenRows() throws {
        let row = app.staticTexts["Entry 8"]
        let originalY = row.frame.midY
        drag(row, dx: 15, dy: -160)
        XCTAssertLessThan(row.frame.midY, originalY - 80)
        let movedY = row.frame.midY
        drag(row, dx: -15, dy: 160)
        XCTAssertGreaterThan(row.frame.midY, movedY + 80)
        drag(row, dx: 110, dy: 10)
        _ = try button("复制", in: row)
        let openY = row.frame.midY
        drag(row, dx: 10, dy: -150)
        XCTAssertLessThan(row.frame.midY, openY - 80)
        assertEvents()
    }

    func testActionsAndOrdinaryTapStillWork() throws {
        let row = app.staticTexts["Entry 8"]
        drag(row, dx: 110, dy: 15)
        try button("复制", in: row).tap()
        assertEvents("edit=0,copy=1,refund=0,delete=0")
        drag(row, dx: -190, dy: -15)
        try button("退款", in: row).tap()
        assertEvents("edit=0,copy=1,refund=1,delete=0")
        drag(row, dx: -190, dy: 15)
        try button("删除", in: row).tap()
        assertEvents("edit=0,copy=1,refund=1,delete=1")
        row.tap()
        assertEvents("edit=1,copy=1,refund=1,delete=1")
    }
}
