import XCTest
import UIKit

final class HeaderTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func checkPages(language: String) throws {
        let app = XCUIApplication()
        app.launchEnvironment["HEADER_LANGUAGE"] = language
        app.launch()
        let title = app.staticTexts["mainPageTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        var visited = Set<String>()

        for index in 0..<4 {
            let tabs = ["expense", "income", "vault", "stats"].map {
                app.buttons["mainTab.\($0)"]
            }
            for tab in tabs { XCTAssertTrue(tab.isHittable) }
            let expectedTitle = tabs[index].label
            tabs[index].tap()
            let changed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", expectedTitle), object: title
            )
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
            visited.insert(title.label)

            let navBar = app.navigationBars.firstMatch
            let controls = navBar.buttons.allElementsBoundByIndex.filter { $0.isHittable }
            XCTAssertFalse(controls.isEmpty)
            let controlFrame = try XCTUnwrap(controls.first).frame
            let initialFrame = title.frame
            let minimumTitleWidth = (expectedTitle as NSString).size(withAttributes: [
                .font: UIFont.systemFont(ofSize: 22 * 0.75, weight: .bold)
            ]).width
            XCTAssertGreaterThanOrEqual(initialFrame.width, minimumTitleWidth - 1)
            XCTAssertLessThan(initialFrame.maxX, controlFrame.minX)
            XCTAssertEqual(initialFrame.midY, controlFrame.midY, accuracy: 4)
            XCTAssertTrue(title.isHittable)
            attach(app, name: "\(language)-page\(index)-top")

            let scroll = app.scrollViews.firstMatch
            XCTAssertTrue(scroll.exists)
            for _ in 0..<3 {
                scroll.swipeUp()
                XCTAssertTrue(title.isHittable)
                XCTAssertEqual(title.frame.minY, initialFrame.minY, accuracy: 1)
                XCTAssertEqual(title.frame.minX, initialFrame.minX, accuracy: 1)
                XCTAssertEqual(controls[0].frame.midY, controlFrame.midY, accuracy: 1)
            }
            attach(app, name: "\(language)-page\(index)-scrolled")

            for _ in 0..<3 { scroll.swipeDown() }
            XCTAssertEqual(title.frame.minY, initialFrame.minY, accuracy: 1)
            XCTAssertEqual(title.frame.midY, controls[0].frame.midY, accuracy: 4)
            let yearPicker = app.buttons["period.year"]
            XCTAssertTrue(yearPicker.isHittable)
            yearPicker.tap()
            attach(app, name: "\(language)-page\(index)-date-menu")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)).tap()
        }
        XCTAssertEqual(visited.count, 4)
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testChineseHeadersStayAlignedAndFixed() throws {
        try checkPages(language: "zh-Hans")
    }

    func testEnglishHeadersStayAlignedAndFixed() throws {
        try checkPages(language: "en")
    }
}
