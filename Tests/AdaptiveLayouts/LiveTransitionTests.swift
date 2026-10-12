import Darwin
import XCTest

// These opt-in tests require real Device Hub pose/window changes, without relaunching the app.
final class LiveTransitionTests: XCTestCase {
    func testActualSplitViewContinuity() throws {
        guard ProcessInfo.processInfo.environment["QA_LIVE_TRANSITIONS"] == "1" else {
            throw XCTSkip("Opt in and operate Device Hub when QA_LIVE_STAGE is printed.")
        }
        continueAfterFailure = false
        executionTimeAllowance = 3600
        let app = XCUIApplication()
        app.launchEnvironment["QA_REAL_ROOT"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["period.year"].waitForExistence(timeout: 20))
        let initial = try pose(in: app)
        XCTAssertEqual(initial.status, "fullyOpen")
        XCTAssertGreaterThan(initial.width, initial.height)
        XCTAssertGreaterThan(initial.sceneWidth, 760)
        stage("SPLIT_LEFT")
        try waitForPose(in: app, initial: initial) {
            $0.status == "fullyOpen" && $0.width < 760 && $0.sceneWidth < initial.sceneWidth - 100
                && $0.divisions.contains { $0.x > 40 }
        }
        checkCompactPages(in: app, settingMonth: true)
        attach(app, "actual-split-left")
        tapTab(in: app, key: "expense", symbol: "minus.circle.fill")
        app.buttons["新增支出"].firstMatch.tap()
        let amount = app.textFields["entry.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        XCTAssertTrue(app.buttons["amount.done"].waitForExistence(timeout: 5))
        for symbol in ["+", "-", "×", "÷"] {
            XCTAssertTrue(app.buttons["amount.operator.\(symbol)"].isHittable)
        }
        XCTAssertTrue(app.buttons["amount.equals"].isHittable)
        amount.typeText("17.25")
        app.buttons["amount.done"].tap()
        let note = app.textFields["entry.note"]
        reveal(note, in: app)
        note.tap()
        note.typeText("QA split draft")
        app.buttons["完成"].firstMatch.tap()
        XCTAssertTrue(try currentPose(initial).divisions.contains { $0.x > 40 })
        stage("SPLIT_RIGHT")
        try waitForPose(in: app, initial: initial) {
            $0.status == "fullyOpen" && $0.width < 760 && $0.sceneWidth < initial.sceneWidth - 100
                && $0.divisions.contains { $0.x <= 40 }
        }
        XCTAssertEqual(amount.value as? String, "17.25")
        XCTAssertEqual(note.value as? String, "QA split draft")
        attach(app, "actual-split-right-draft")
        app.buttons["取消"].firstMatch.tap()
        checkCompactPages(in: app, settingMonth: false)
        tapStats(in: app)
        app.buttons["stats.settings"].tap()
        app.buttons["货币选择"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 5))
        attach(app, "actual-split-right-settings")
        stage("SPLIT_FULL")
        try waitForPose(in: app, initial: initial) {
            $0.status == "fullyOpen" && $0.width >= 760 && $0.width > $0.height
                && $0.sceneWidth >= initial.sceneWidth - 1
        }
        XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 8))
        let primary = app.scrollViews["adaptive.page"].firstMatch
        XCTAssertTrue(primary.staticTexts["收支概览"].exists)
        XCTAssertGreaterThanOrEqual(app.navigationBars["货币选择"].frame.minX, primary.frame.maxX)
        XCTAssertLessThanOrEqual(app.navigationBars["货币选择"].frame.maxX, initial.sceneWidth)
        attach(app, "actual-split-restored-settings")
        let back = app.navigationBars["货币选择"].buttons["设置"].firstMatch
        (back.exists ? back : app.buttons["BackButton"].firstMatch).tap()
        app.buttons["settings.done"].tap()
        XCTAssertTrue((app.buttons["period.month"].firstMatch.value as? String)?.contains("1") == true)
        stage("SPLIT_COMPLETE")
    }

    func testActualFoldContinuity() throws {
        guard ProcessInfo.processInfo.environment["QA_LIVE_TRANSITIONS"] == "1" else {
            throw XCTSkip("Opt in and operate Device Hub when QA_LIVE_STAGE is printed.")
        }
        continueAfterFailure = false
        executionTimeAllowance = 3600
        let app = XCUIApplication()
        app.launchEnvironment["QA_REAL_ROOT"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["period.year"].waitForExistence(timeout: 20))
        let initial = try pose(in: app)
        XCTAssertTrue(initial.status == "fullyOpen" || initial.status == "closed")
        XCTAssertNoThrow(try Data(contentsOf: URL(fileURLWithPath: initial.telemetryPath)))

        app.buttons["新增支出"].firstMatch.tap()
        let amount = app.textFields["entry.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("120+30")
        let note = app.textFields["entry.note"]
        reveal(note, in: app)
        note.tap()
        note.typeText("QA live fold draft")
        app.buttons["完成"].firstMatch.tap()
        if initial.status == "closed" {
            stage("FOLD_EDITOR_OPEN")
            try waitForPose(in: app, initial: initial) { $0.isOpenedWorkspace }
            XCTAssertEqual(amount.value as? String, "120+30")
            XCTAssertEqual(note.value as? String, "QA live fold draft")
        }
        stage("FOLD_EDITOR_CLOSE")
        try waitForPose(in: app, initial: initial) { $0.isClosedOuterDisplay }
        XCTAssertEqual(amount.value as? String, "120+30")
        XCTAssertEqual(note.value as? String, "QA live fold draft")
        attach(app, "live-closed-editor")
        stage("FOLD_EDITOR_OPEN")
        try waitForPose(in: app, initial: initial) { $0.isOpenedWorkspace }
        XCTAssertEqual(amount.value as? String, "120+30")
        XCTAssertEqual(note.value as? String, "QA live fold draft")
        attach(app, "live-opened-editor")
        app.buttons["取消"].firstMatch.tap()

        tapStats(in: app)
        let chart = app.otherElements["stats.distribution.chart"].firstMatch
        reveal(chart, in: app)
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.30)).tap()
        XCTAssertTrue(app.buttons["stats.distribution.鞋靴"].isSelected)
        app.buttons["stats.settings"].tap()
        app.buttons["货币选择"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 5))
        stage("FOLD_SETTINGS_CLOSE")
        try waitForPose(in: app, initial: initial) { $0.isClosedOuterDisplay }
        XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 8))
        attach(app, "live-closed-settings-currency")
        stage("FOLD_SETTINGS_OPEN")
        try waitForPose(in: app, initial: initial) { $0.isOpenedWorkspace }
        XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.scrollViews["adaptive.page"].firstMatch.staticTexts["收支概览"].exists)
        attach(app, "live-opened-settings-currency")
        let back = app.navigationBars["货币选择"].buttons["设置"].firstMatch
        (back.exists ? back : app.buttons["BackButton"].firstMatch).tap()
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.buttons["stats.distribution.鞋靴"].isSelected)
        app.buttons["period.month"].firstMatch.tap()
        app.buttons["1月"].firstMatch.tap()
        stage("FOLD_COMPLETE")
    }

    private struct Pose: Decodable {
        let processID: Int32
        let telemetryPath: String
        let width: Double
        let height: Double
        let status: String?
        let angle: Double?
        let sceneX: Double
        let sceneWidth: Double
        let sceneIsActive: Bool
        let divisions: [Division]

        var isClosedOuterDisplay: Bool {
            status == "closed" && (angle ?? 180) <= 1 && width < 760 && sceneWidth < 760
        }

        var isOpenedWorkspace: Bool {
            status == "fullyOpen" && (angle ?? 0) >= 179 && width > height && width >= 760 && sceneWidth >= 760
        }
    }

    private struct Division: Decodable {
        let x: Double
    }

    private func pose(in app: XCUIApplication) throws -> Pose {
        let recorder = app.otherElements["qa.pose"]
        XCTAssertTrue(recorder.waitForExistence(timeout: 5))
        let value = recorder.value as? String ?? ""
        print("QA_LIVE_POSE: \(value)")
        return try JSONDecoder().decode(Pose.self, from: Data(value.utf8))
    }

    private func waitForPose(in app: XCUIApplication, initial: Pose, condition: @escaping (Pose) -> Bool) throws {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: initial.telemetryPath)),
                  let current = try? JSONDecoder().decode(Pose.self, from: data) else { return false }
            return current.processID == initial.processID && current.sceneIsActive && condition(current)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 900), .completed)
        let current = try currentPose(initial)
        let evidence = try Data(contentsOf: URL(fileURLWithPath: initial.telemetryPath))
        print("QA_LIVE_POSE: \(String(decoding: evidence, as: UTF8.self))")
        let attachment = XCTAttachment(data: evidence, uniformTypeIdentifier: "public.json")
        attachment.name = "live-scene-\(current.sceneWidth)-division-\(current.divisions.first?.x ?? -1)"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(current.processID, initial.processID)
        XCTAssertTrue(current.sceneIsActive)
        XCTAssertTrue(condition(current))
    }

    private func currentPose(_ initial: Pose) throws -> Pose {
        try JSONDecoder().decode(Pose.self, from: Data(contentsOf: URL(fileURLWithPath: initial.telemetryPath)))
    }

    private func checkCompactPages(in app: XCUIApplication, settingMonth: Bool) {
        for (key, symbol) in [("expense", "minus.circle.fill"), ("income", "plus.circle.fill"),
                              ("vault", "lock.shield.fill"), ("stats", "chart.bar.xaxis")] {
            tapTab(in: app, key: key, symbol: symbol)
            XCTAssertEqual(app.scrollViews["adaptive.page"].firstMatch.value as? String, "compact")
            XCTAssertFalse(app.scrollViews["workspace.secondary"].exists)
            let month = key == "stats"
                ? app.otherElements["stats.overview"].buttons["period.month"].firstMatch
                : app.buttons["period.month"].firstMatch
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                month.exists && month.isHittable
            }, object: nil)
            attach(app, "actual-split-\(settingMonth ? "left" : "right")-\(key)-ready")
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 3), .completed)
            if settingMonth {
                month.tap()
                app.buttons["1月"].firstMatch.tap()
            }
            XCTAssertTrue((month.value as? String)?.contains("1") == true)
            XCTAssertTrue(app.buttons["period.year"].isHittable)
            attach(app, "actual-split-\(settingMonth ? "left" : "right")-\(key)")
        }
    }

    private func tapStats(in app: XCUIApplication) {
        tapTab(in: app, key: "stats", symbol: "chart.bar.xaxis")
    }

    private func tapTab(in app: XCUIApplication, key: String, symbol: String) {
        let titles = ["expense": "支出", "income": "收入", "vault": "金库", "stats": "统计"]
        let button = app.buttons.matching(NSPredicate(format: "label == %@", titles[key]!))
            .containing(.image, identifier: symbol).firstMatch
        let control = button.exists ? button : app.buttons[symbol].firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        control.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            control.isSelected && app.staticTexts["mainPageTitle"].firstMatch.label == titles[key]!
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<20 {
            if element.exists, element.isHittable, element.frame.minY > 100,
               element.frame.maxY < app.frame.maxY - 60 { return }
            let primary = app.scrollViews["adaptive.page"].firstMatch
            let secondary = app.scrollViews["workspace.secondary"].firstMatch
            let pane = secondary.exists && element.frame.minX >= secondary.frame.minX ? secondary : primary
            let start = pane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            start.press(forDuration: 0.01, thenDragTo: pane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        }
        XCTAssertTrue(element.isHittable)
    }

    private func stage(_ value: String) {
        print("QA_LIVE_STAGE: \(value)")
        fflush(stdout)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "\(name)-hierarchy"
        tree.lifetime = .keepAlways
        add(tree)
    }
}
