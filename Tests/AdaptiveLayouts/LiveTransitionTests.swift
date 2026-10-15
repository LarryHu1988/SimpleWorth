import Darwin
import XCTest

// These opt-in tests require real Device Hub pose/window changes, without relaunching the app.
final class LiveTransitionTests: XCTestCase {
    func testDuoPhoneNavigationAcrossPoses() throws {
        guard ProcessInfo.processInfo.environment["QA_LIVE_TRANSITIONS"] == "1" else {
            throw XCTSkip("Opt in and operate Device Hub when QA_LIVE_STAGE is printed.")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        // Default/manual launch must use the native root, with no width override.
        app.launchEnvironment["QA_WIDTH_STRESS"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["period.year"].waitForExistence(timeout: 20))
        let initial = try pose(in: app)
        XCTAssertTrue(initial.isClosedOuterDisplay && initial.sceneHeight > initial.sceneWidth)
        checkResponsivePages(in: app, pose: initial, name: "six-fixes-outer-portrait")

        stage("SIX_FIXES_OPEN_LANDSCAPE")
        try waitForPose(in: app, initial: initial, timeout: 180) { $0.isOpenedWorkspace }
        checkResponsivePages(in: app, pose: try currentPose(initial), name: "six-fixes-inner-landscape")
        app.buttons["stats.settings"].tap()
        let summary = app.otherElements["settings.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        let pane = app.otherElements["settings.pane"].firstMatch
        XCTAssertTrue(pane.exists)
        attach(app, "six-fixes-inner-settings-margins")
        XCTAssertGreaterThanOrEqual(summary.frame.minX - pane.frame.minX, 16)
        XCTAssertGreaterThanOrEqual(pane.frame.maxX - summary.frame.maxX, 16)
        let languageTitle = app.staticTexts["settings.language.title"]
        for language in ["zh-Hans", "zh-Hant", "en", "ja"] {
            let option = app.buttons["settings.language.\(language)"]
            XCTAssertTrue(option.isHittable)
            XCTAssertEqual(option.frame.midY, languageTitle.frame.midY, accuracy: 1)
        }
        XCTAssertTrue(app.buttons["settings.done"].isHittable)
        app.buttons["settings.done"].tap()

        stage("SIX_FIXES_INNER_PORTRAIT")
        try waitForPose(in: app, initial: initial, timeout: 180) {
            $0.status == "fullyOpen" && ($0.angle ?? 0) >= 179 && $0.sceneHeight > $0.sceneWidth
        }
        checkResponsivePages(in: app, pose: try currentPose(initial), name: "six-fixes-inner-portrait")

        stage("SIX_FIXES_OUTER_LANDSCAPE")
        try waitForPose(in: app, initial: initial, timeout: 180) {
            $0.isClosedOuterDisplay && $0.sceneWidth > $0.sceneHeight
        }
        checkResponsivePages(in: app, pose: try currentPose(initial), name: "six-fixes-outer-landscape")

        stage("SIX_FIXES_OUTER_PORTRAIT")
        try waitForPose(in: app, initial: initial, timeout: 180) {
            $0.isClosedOuterDisplay && $0.sceneHeight > $0.sceneWidth
        }
        checkResponsivePages(in: app, pose: try currentPose(initial), name: "six-fixes-restored-outer")
        stage("SIX_FIXES_COMPLETE")
    }

    func testActualResponsiveWidthContinuity() throws {
        guard ProcessInfo.processInfo.environment["QA_LIVE_TRANSITIONS"] == "1" else {
            throw XCTSkip("Opt in and operate Device Hub when QA_LIVE_STAGE is printed.")
        }
        continueAfterFailure = false
        executionTimeAllowance = 3600
        let app = XCUIApplication()
        app.launchEnvironment["QA_REAL_ROOT"] = "1"
        app.launchEnvironment["QA_WIDTH_STRESS"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["period.year"].waitForExistence(timeout: 20))
        let initial = try pose(in: app)
        XCTAssertTrue(initial.isClosedOuterDisplay || initial.isOpenedWorkspace)
        checkResponsivePages(in: app, pose: initial,
                             name: initial.isClosedOuterDisplay ? "initial-outer" : "initial-landscape")
        if !initial.isOpenedWorkspace {
            stage("WIDTH_OPEN")
            try waitForPose(in: app, initial: initial) { $0.isOpenedWorkspace }
            checkResponsivePages(in: app, pose: try currentPose(initial), name: "opened-landscape")
        }
        stage("WIDTH_PORTRAIT")
        try waitForPose(in: app, initial: initial) {
            $0.status == "fullyOpen" && ($0.angle ?? 0) >= 179 && $0.height > $0.width && $0.sceneWidth < 760
        }
        checkResponsivePages(in: app, pose: try currentPose(initial), name: "opened-portrait")
        stage("WIDTH_CLOSE")
        try waitForPose(in: app, initial: initial) {
            $0.isClosedOuterDisplay && (!initial.isClosedOuterDisplay ||
                (abs($0.sceneWidth - initial.sceneWidth) < 1 && abs($0.sceneHeight - initial.sceneHeight) < 1
                    && $0.interfaceOrientation == initial.interfaceOrientation))
        }
        checkResponsivePages(in: app, pose: try currentPose(initial), name: "restored-outer")
        stage("WIDTH_COMPLETE")
    }

    func testActualResponsiveOuterRoundTrip() throws {
        guard ProcessInfo.processInfo.environment["QA_LIVE_TRANSITIONS"] == "1" else {
            throw XCTSkip("Opt in and operate Device Hub when QA_LIVE_STAGE is printed.")
        }
        continueAfterFailure = false
        executionTimeAllowance = 3600
        let app = XCUIApplication()
        app.launchEnvironment["QA_REAL_ROOT"] = "1"
        app.launchEnvironment["QA_WIDTH_STRESS"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["period.year"].waitForExistence(timeout: 20))
        let initial = try pose(in: app)
        XCTAssertTrue(initial.isClosedOuterDisplay)
        XCTAssertTrue(initial.sceneIsActive)
        checkResponsivePages(in: app, pose: initial, name: "roundtrip-initial-outer")
        stage("WIDTH_ROUNDTRIP_OPEN")
        try waitForPose(in: app, initial: initial) { $0.isOpenedWorkspace }
        checkResponsivePages(in: app, pose: try currentPose(initial), name: "roundtrip-landscape")
        stage("WIDTH_ROUNDTRIP_CLOSE")
        try waitForPose(in: app, initial: initial) {
            $0.isClosedOuterDisplay && abs($0.sceneWidth - initial.sceneWidth) < 1
                && abs($0.sceneHeight - initial.sceneHeight) < 1 && $0.interfaceOrientation == initial.interfaceOrientation
        }
        let restored = try currentPose(initial)
        XCTAssertEqual(restored.sceneWidth, initial.sceneWidth, accuracy: 1)
        XCTAssertEqual(restored.width, initial.width, accuracy: 1)
        checkResponsivePages(in: app, pose: restored, name: "roundtrip-restored-outer")
        stage("WIDTH_ROUNDTRIP_COMPLETE")
    }

    private func checkResponsivePages(in app: XCUIApplication, pose: Pose, name: String) {
        XCTAssertFalse(app.buttons["qa.compact"].exists)
        XCTAssertFalse(app.buttons["qa.wide"].exists)
        for (key, symbol) in [("expense", "minus.circle.fill"), ("income", "plus.circle.fill"),
                              ("vault", "lock.shield.fill"), ("stats", "chart.bar.xaxis")] {
            tapTab(in: app, key: key, symbol: symbol)
            XCTAssertEqual(app.scrollViews["adaptive.page"].firstMatch.value as? String,
                           pose.isOpenedWorkspace ? "wide" : "compact")
            if !pose.isOpenedWorkspace {
                let bar = app.otherElements["mainTab.bar"]
                XCTAssertFalse(app.scrollViews["workspace.secondary"].exists)
                let card = app.otherElements[key == "stats" ? "stats.overview" :
                    (key == "vault" ? "vault.overview" : "flow.summary")]
                if pose.isClosedOuterDisplay {
                    XCTAssertFalse(bar.exists)
                    let tab = app.buttons.containing(.image, identifier: symbol).firstMatch
                    XCTAssertTrue(tab.isHittable)
                    XCTAssertGreaterThanOrEqual(tab.frame.minX, card.frame.maxX)
                } else {
                    XCTAssertTrue(bar.exists && app.buttons["mainTab.\(key)"].isHittable)
                    XCTAssertGreaterThan(bar.frame.minY, app.windows.firstMatch.frame.midY)
                }
                XCTAssertEqual(card.frame.width, min(760, pose.width - 32), accuracy: 2,
                               "Every phone page must fill the current usable width")
            }
            if key == "vault" {
                XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vault.select.")).firstMatch.exists)
                XCTAssertFalse(app.otherElements["vault.selectedGoal"].exists)
            }
            if key == "stats" {
                for title in ["收入", "支出", "净结余", "储蓄率"] {
                    let amount = app.staticTexts["stats.metric.\(title)"]
                    XCTAssertTrue(amount.exists)
                    XCTAssertLessThanOrEqual(amount.frame.height, 28)
                }
            } else {
                let card = app.otherElements[key == "vault" ? "vault.overview" : "flow.summary"]
                let amount = app.staticTexts[key == "vault" ? "vault.overview.amount" : "flow.summary.amount"]
                XCTAssertTrue(card.exists && amount.exists)
                XCTAssertLessThanOrEqual(amount.frame.height, 44)
                XCTAssertTrue(card.frame.contains(amount.frame))
                if !pose.isOpenedWorkspace {
                    XCTAssertEqual(card.frame.width, min(760, pose.width - 32), accuracy: 2,
                                   "The compact card must fill the current usable width")
                }
            }
            attach(app, "live-width-\(name)-\(key)")
        }
    }

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
        XCTAssertFalse(app.textFields["category.search"].exists)
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
        XCTAssertFalse(app.textFields["category.search"].exists)
        attach(app, "live-closed-editor")
        stage("FOLD_EDITOR_OPEN")
        try waitForPose(in: app, initial: initial) { $0.isOpenedWorkspace }
        XCTAssertEqual(amount.value as? String, "120+30")
        XCTAssertEqual(note.value as? String, "QA live fold draft")
        XCTAssertEqual(app.scrollViews.containing(.textField, identifier: "entry.amount").firstMatch.value as? String, "wide")
        XCTAssertFalse(app.textFields["category.search"].exists)
        attach(app, "live-opened-editor")
        app.buttons["取消"].firstMatch.tap()

        openSelectedChartSettings(in: app)
        try checkSettingsFold(in: app, initial: initial)
    }

    func testActualSettingsFoldContinuity() throws {
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
        openSelectedChartSettings(in: app)
        if !initial.isOpenedWorkspace {
            stage("SETTINGS_LANDSCAPE")
            try waitForPose(in: app, initial: initial) { $0.isOpenedWorkspace }
            XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 8))
            XCTAssertTrue(app.scrollViews["adaptive.page"].firstMatch.staticTexts["收支概览"].exists)
            attach(app, "live-portrait-to-landscape-settings")
        }
        try checkSettingsFold(in: app, initial: initial)
    }

    private func openSelectedChartSettings(in app: XCUIApplication) {
        tapStats(in: app)
        let chart = app.otherElements["stats.distribution.chart"].firstMatch
        reveal(chart, in: app)
        chart.coordinate(withNormalizedOffset: CGVector(
            dx: 0.5 + chart.frame.height * 0.34 / chart.frame.width, dy: 0.25
        )).tap()
        XCTAssertTrue(app.buttons["stats.distribution.鞋靴"].isSelected)
        app.buttons["stats.settings"].tap()
        app.buttons["货币选择"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 5))
    }

    private func checkSettingsFold(in app: XCUIApplication, initial: Pose) throws {
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
        let sceneHeight: Double
        let interfaceOrientation: Int?
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

    private func waitForPose(in app: XCUIApplication, initial: Pose, timeout: TimeInterval = 900,
                             condition: @escaping (Pose) -> Bool) throws {
        var previousGeometry: [Double] = []
        var matchingSince: Date?
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: initial.telemetryPath)),
                  let current = try? JSONDecoder().decode(Pose.self, from: data),
                  current.processID == initial.processID, current.sceneIsActive, condition(current) else {
                matchingSince = nil
                return false
            }
            // Hinge state and viewport geometry arrive in separate native updates.
            let geometry = [current.width, current.height, current.sceneWidth, current.sceneHeight,
                            current.sceneX, current.angle ?? -1, Double(current.interfaceOrientation ?? -1)]
                + current.divisions.map(\.x)
            if matchingSince == nil || previousGeometry.count != geometry.count ||
                !zip(previousGeometry, geometry).allSatisfy({ abs($0.0 - $0.1) < 0.5 }) {
                previousGeometry = geometry
                matchingSince = Date()
                return false
            }
            return Date().timeIntervalSince(matchingSince!) >= 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: timeout), .completed)
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
        let custom = app.buttons["mainTab.\(key)"]
        let control = custom.exists ? custom : (button.exists ? button : app.buttons[symbol].firstMatch)
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        let icon = control.images[symbol].firstMatch
        (icon.exists ? icon : control).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            control.isSelected && app.staticTexts["mainPageTitle"].firstMatch.label == titles[key]!
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<20 {
            if element.exists, app.windows.firstMatch.frame.contains(element.frame), element.frame.minY > 100,
               element.frame.maxY < app.windows.firstMatch.frame.maxY - 60 { return }
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
