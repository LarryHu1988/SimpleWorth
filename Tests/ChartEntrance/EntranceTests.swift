import XCTest

final class EntranceTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Replay"].waitForExistence(timeout: 10))
    }

    private func samples(after button: String) throws -> [[Int]] {
        app.buttons[button].tap()
        let label = app.staticTexts["samples"]
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS ';'"), object: label
        )
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        let values = label.label.split(separator: ";").map {
            $0.split(separator: ",").compactMap { Int($0) }
        }
        XCTAssertEqual(values.count, 3)
        for stage in values {
            XCTAssertEqual(stage.count, 5)
        }
        for count in (values.last ?? []).prefix(4) {
            XCTAssertGreaterThan(count, 1000)
        }
        return values
    }

    func testEntranceAndReplayActuallyDrawProgressiveFrames() throws {
        for _ in 0..<2 {
            let values = try samples(after: "Replay")
            for chart in 0..<4 {
                XCTAssertLessThan(Double(values[0][chart]), Double(values[2][chart]) * 0.95)
                XCTAssertGreaterThan(values[1][chart], values[0][chart])
                XCTAssertGreaterThanOrEqual(values[2][chart], values[1][chart])
            }
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRapidSwitchingDoesNotLeaveChartsBlank() throws {
        let values = try samples(after: "Rapid")
        for chart in 0..<4 {
            XCTAssertGreaterThan(values[2][chart], values[0][chart])
        }
        app.otherElements["bars"].tap()
        app.otherElements["donut"].tap()
        XCTAssertEqual(app.staticTexts["taps"].label, "taps=2")
    }

    func testRoundCapIsVisibleThroughoutEntrance() throws {
        let values = try samples(after: "Replay")
        let finalCap = Double(values[2][4])
        XCTAssertGreaterThan(finalCap, 30)
        XCTAssertEqual(Double(values[0][4]), finalCap, accuracy: finalCap * 0.15)
        XCTAssertEqual(Double(values[1][4]), finalCap, accuracy: finalCap * 0.15)
    }

    private func motionSwitch(in settings: XCUIApplication) -> XCUIElement {
        settings.terminate()
        settings.launch()
        let accessibility = settings.buttons.matching(NSPredicate(
            format: "identifier == %@ OR label IN %@",
            "com.apple.settings.accessibility", ["Accessibility", "辅助功能"]
        )).firstMatch
        for _ in 0..<4 where !accessibility.isHittable {
            settings.swipeDown()
        }
        for _ in 0..<6 where !accessibility.isHittable {
            settings.swipeUp()
        }
        XCTAssertTrue(accessibility.waitForExistence(timeout: 5))
        accessibility.tap()
        let motion = settings.staticTexts.matching(NSPredicate(
            format: "label IN %@", ["Motion", "动态效果"]
        )).firstMatch
        XCTAssertTrue(motion.waitForExistence(timeout: 5))
        motion.tap()
        let toggle = settings.switches.matching(NSPredicate(
            format: "label CONTAINS %@ OR label CONTAINS %@", "Reduce Motion", "减弱动态效果"
        )).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        return toggle
    }

    func testReduceMotionDisplaysCompleteChartsImmediately() throws {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        let toggle = motionSwitch(in: settings)
        let wasEnabled = toggle.value as? String == "1"
        addTeardownBlock {
            let restoredToggle = self.motionSwitch(in: settings)
            if (restoredToggle.value as? String == "1") != wasEnabled {
                restoredToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            }
            let restored = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", wasEnabled ? "1" : "0"), object: restoredToggle
            )
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed)
        }
        if !wasEnabled {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Replay"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["motion"].label, "reduce=true,system=true")
        let values = try samples(after: "Replay")
        for chart in 0..<4 {
            XCTAssertEqual(Double(values[0][chart]), Double(values[2][chart]), accuracy: 30)
            XCTAssertEqual(Double(values[1][chart]), Double(values[2][chart]), accuracy: 30)
        }
    }
}
