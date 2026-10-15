import XCTest

final class NativeDeviceTests: XCTestCase {
    func testNativeResponsiveChineseWidths() {
        checkResponsiveWidths(language: "zh-Hans")
    }

    func testNativeResponsiveEnglishWidths() {
        checkResponsiveWidths(language: "en")
    }

    func testNativeMainHeadersStayFixedWhileScrolling() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_REAL_ROOT"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["period.year"].waitForExistence(timeout: 20))
        for (key, symbol) in [("expense", "minus.circle.fill"), ("income", "plus.circle.fill"),
                              ("vault", "lock.shield.fill"), ("stats", "chart.bar.xaxis")] {
            tapTab(in: app, key: key, symbol: symbol)
            let title = app.staticTexts["mainPageTitle"].firstMatch
            let year = app.buttons["period.year"].firstMatch
            let initialTitle = title.frame
            let initialYear = year.frame
            let page = app.scrollViews["adaptive.page"].firstMatch
            for direction in [true, false] {
                let start = page.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: direction ? 0.75 : 0.3))
                let end = page.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: direction ? 0.3 : 0.75))
                start.press(forDuration: 0.01, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
                attach(app, "fixed-header-\(key)-\(direction ? "up" : "down")")
                XCTAssertTrue(title.isHittable && year.isHittable)
                XCTAssertEqual(title.frame.minY, initialTitle.minY, accuracy: 1)
                XCTAssertEqual(title.frame.height, initialTitle.height, accuracy: 1)
                XCTAssertEqual(year.frame.minY, initialYear.minY, accuracy: 1)
                XCTAssertEqual(year.frame.height, initialYear.height, accuracy: 1)
            }
        }
    }

    func testDuoOuterTabsUseRightRail() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_REAL_ROOT"] = "1"
        app.launch()
        let recorder = app.otherElements["qa.pose"]
        XCTAssertTrue(recorder.waitForExistence(timeout: 20))
        let value = recorder.value as? String ?? ""
        guard let pose = try? JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any],
              pose["status"] as? String == "closed" else {
            throw XCTSkip("Run on the actual closed Duo outer display.")
        }
        let native = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !app.otherElements["mainTab.bar"].exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [native], timeout: 5), .completed)
        var frames: [CGRect] = []
        for (key, title, symbol) in [("expense", "支出", "minus.circle.fill"),
                                      ("income", "收入", "plus.circle.fill"),
                                      ("vault", "金库", "lock.shield.fill"),
                                      ("stats", "统计", "chart.bar.xaxis")] {
            tapTab(in: app, key: key, symbol: symbol)
            let tab = app.buttons.matching(NSPredicate(format: "label == %@", title))
                .containing(.image, identifier: symbol).firstMatch
            let card = app.otherElements[key == "stats" ? "stats.overview" :
                (key == "vault" ? "vault.overview" : "flow.summary")]
            XCTAssertTrue(tab.isHittable)
            XCTAssertGreaterThanOrEqual(tab.frame.minX, card.frame.maxX)
            XCTAssertTrue(app.windows.firstMatch.frame.contains(tab.frame))
            frames.append(tab.frame)
            attach(app, "outer-right-rail-\(key)")
        }
        for index in 1..<frames.count {
            XCTAssertEqual(frames[index].midX, frames[0].midX, accuracy: 1)
            XCTAssertGreaterThanOrEqual(frames[index].midY - frames[index - 1].midY, 24)
        }
    }

    func testResponsiveWidthMatrix() {
        for width in [320, 360, 390, 430, 600, 669, 760] {
            checkResponsiveWidths(language: "zh-Hans", width: width)
        }
        checkResponsiveWidths(language: "en", width: 320)
        checkResponsiveWidths(language: "en", width: 669)
    }

    private func checkResponsiveWidths(language: String, width: Int? = nil) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_REAL_ROOT"] = "1"
        app.launchEnvironment["QA_WIDTH_STRESS"] = "1"
        app.launchEnvironment["QA_LANGUAGE"] = language
        if let width { app.launchEnvironment["QA_CONTAINER_WIDTH"] = "\(width)" }
        app.launch()
        XCTAssertTrue(app.staticTexts["flow.summary.amount"].waitForExistence(timeout: 20))
        let recorder = app.otherElements["qa.pose"]
        var nativeContentWidth: CGFloat?
        if recorder.exists, let value = recorder.value as? String {
            print("QA_RESPONSIVE_POSE: \(value)")
            let evidence = XCTAttachment(string: value)
            evidence.name = "responsive-\(language)-native-pose"
            evidence.lifetime = .keepAlways
            add(evidence)
            if width == nil,
               app.scrollViews["adaptive.page"].firstMatch.value as? String == "compact",
               let pose = try? JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any],
               let rootWidth = pose["width"] as? Double {
                nativeContentWidth = min(760, rootWidth - 32)
            }
        }
        for (key, symbol) in [("expense", "minus.circle.fill"), ("income", "plus.circle.fill")] {
            tapTab(in: app, key: key, symbol: symbol, language: language)
            let card = app.otherElements["flow.summary"]
            let amount = app.staticTexts["flow.summary.amount"]
            let title = app.staticTexts["flow.summary.title"]
            XCTAssertTrue(card.exists && amount.exists && title.exists)
            if let nativeContentWidth { XCTAssertEqual(card.frame.width, nativeContentWidth, accuracy: 2) }
            attach(app, "responsive-\(language)-\(width ?? 0)-\(key)")
            XCTAssertGreaterThanOrEqual(card.frame.width, 280)
            XCTAssertLessThanOrEqual(amount.frame.height, 44, "Summary money must stay on one line")
            XCTAssertLessThanOrEqual(title.frame.height, 26, "Summary heading must not be squeezed into multiple lines")
            XCTAssertTrue(card.frame.contains(amount.frame))
            if language == "en", width == 320 {
                XCTAssertGreaterThan(amount.frame.width, card.frame.width * 0.75,
                                     "Large localized money needs the full row rather than an ellipsis")
            }
            let note = app.staticTexts["ledger.note"].firstMatch
            reveal(note, in: app)
            let rowAmount = app.staticTexts["ledger.amount"].firstMatch
            XCTAssertTrue(rowAmount.exists)
            XCTAssertLessThanOrEqual(rowAmount.frame.height, 26, "A ledger amount must not wrap")
            XCTAssertGreaterThanOrEqual(rowAmount.frame.minX, card.frame.minX)
            XCTAssertLessThanOrEqual(rowAmount.frame.maxX, card.frame.maxX)
            attach(app, "responsive-\(language)-\(width ?? 0)-\(key)-row")
        }
        tapTab(in: app, key: "vault", symbol: "lock.shield.fill", language: language)
        let vault = app.otherElements["vault.overview"]
        let vaultAmount = app.staticTexts["vault.overview.amount"]
        XCTAssertTrue(vault.exists && vaultAmount.exists)
        if let nativeContentWidth { XCTAssertEqual(vault.frame.width, nativeContentWidth, accuracy: 2) }
        XCTAssertLessThanOrEqual(vaultAmount.frame.height, 44)
        XCTAssertTrue(vault.frame.contains(vaultAmount.frame))
        attach(app, "responsive-\(language)-\(width ?? 0)-vault")
        tapTab(in: app, key: "stats", symbol: "chart.bar.xaxis", language: language)
        if let nativeContentWidth {
            XCTAssertEqual(app.otherElements["stats.overview"].frame.width, nativeContentWidth, accuracy: 2)
        }
        for name in ["收入", "支出", "净结余", "储蓄率"] {
            let metric = app.staticTexts["stats.metric.\(name)"]
            XCTAssertTrue(metric.exists)
            XCTAssertLessThanOrEqual(metric.frame.height, 28, "Stat money must stay on one line")
            XCTAssertTrue(app.windows.firstMatch.frame.contains(metric.frame))
            if language == "en", width == 320, name == "收入" || name == "支出" {
                XCTAssertGreaterThan(metric.frame.width, 120, "Long money must not be squeezed into a small metric column")
            }
        }
        let centerAmount = app.staticTexts["stats.distribution.centerAmount"].firstMatch
        reveal(centerAmount, in: app)
        XCTAssertLessThanOrEqual(centerAmount.frame.height, 28)
        XCTAssertGreaterThanOrEqual(centerAmount.frame.width, 80)
        attach(app, "responsive-\(language)-\(width ?? 0)-stats")
    }

    func testNativeWideLedgerEditorOperations() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_NATIVE_SIZE"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["period.year"].waitForExistence(timeout: 20))
        guard app.scrollViews["adaptive.page"].firstMatch.value as? String == "wide" else {
            throw XCTSkip("Run ledger editor operations in the opened Duo workspace.")
        }
        let row = app.staticTexts["QA expense 24"]
        XCTAssertTrue(row.isHittable)
        row.tap()
        XCTAssertTrue(app.navigationBars["编辑支出"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["category.search"].exists)
        app.buttons["取消"].firstMatch.tap()
        let copyStart = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        copyStart.press(forDuration: 0.01, thenDragTo: copyStart.withOffset(CGVector(dx: 110, dy: 0)),
                        withVelocity: .slow, thenHoldForDuration: 0.1)
        app.buttons["复制"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["复制支出"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["entry.amount"].exists)
        app.buttons["取消"].firstMatch.tap()
        let refundStart = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        refundStart.press(forDuration: 0.01, thenDragTo: refundStart.withOffset(CGVector(dx: -160, dy: 0)),
                          withVelocity: .slow, thenHoldForDuration: 0.1)
        app.buttons["退款"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["退款录入"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["entry.amount"].exists)
        attach(app, "native-refund-editor")
        app.buttons["取消"].firstMatch.tap()
        XCTAssertFalse(app.textFields["entry.amount"].exists)
    }

    func testNativeCategoryExpansionAndMainTitles() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_REAL_ROOT"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["period.year"].waitForExistence(timeout: 20))
        let expectedTitleFrame = app.staticTexts["mainPageTitle"].firstMatch.frame
        for (key, symbol) in [("expense", "minus.circle.fill"), ("income", "plus.circle.fill"),
                              ("vault", "lock.shield.fill"), ("stats", "chart.bar.xaxis")] {
            tapTab(in: app, key: key, symbol: symbol)
            let title = app.staticTexts["mainPageTitle"].firstMatch
            XCTAssertTrue(title.exists)
            attach(app, "native-title-\(key)")
            XCTAssertEqual(title.frame.minX, expectedTitleFrame.minX, accuracy: 2)
            XCTAssertEqual(title.frame.minY, expectedTitleFrame.minY, accuracy: 2)
            guard key == "expense" || key == "income" else { continue }
            let toggle = app.buttons["ledger.categoryToggle.\(key)"]
            for attempt in 0..<2 {
                if attempt == 1 {
                    let pane = app.scrollViews["adaptive.page"].firstMatch
                    let start = pane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                    let end = pane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
                    start.press(forDuration: 0.01, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
                }
                XCTAssertTrue(app.windows.firstMatch.frame.contains(toggle.frame))
                let originalY = toggle.frame.minY
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                attach(app, "native-categories-\(key)-\(attempt)")
                XCTAssertTrue(app.windows.firstMatch.frame.contains(toggle.frame))
                XCTAssertEqual(toggle.frame.minY, originalY, accuracy: 4)
                XCTAssertFalse(app.textFields["category.search"].exists)
                let firstName = key == "expense" ? "餐饮" : "工资"
                let firstCategory = app.buttons["ledger.category.\(key).\(firstName)"]
                XCTAssertTrue(firstCategory.exists)
                XCTAssertTrue(app.windows.firstMatch.frame.contains(firstCategory.frame))
                if attempt == 1 {
                    firstCategory.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 5))
                    let preset = app.buttons["entry.category.\(firstName)"]
                    reveal(preset, in: app)
                    XCTAssertTrue(preset.isSelected)
                    XCTAssertFalse(app.textFields["category.search"].exists)
                    reveal(app.textFields["entry.amount"], in: app)
                    let cancel = app.buttons["取消"].firstMatch
                    XCTAssertTrue(cancel.waitForExistence(timeout: 5))
                    cancel.tap()
                }
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                XCTAssertEqual(toggle.frame.minY, originalY, accuracy: 4)
            }
        }
    }

    func testNativeWideEditorColumnPlacement() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_NATIVE_SIZE"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["period.year"].waitForExistence(timeout: 20))
        guard app.scrollViews["adaptive.page"].firstMatch.value as? String == "wide" else {
            throw XCTSkip("Run editor columns in the opened Duo landscape workspace.")
        }
        for (key, symbol, addLabel) in [("expense", "minus.circle.fill", "新增支出"),
                                        ("income", "plus.circle.fill", "新增收入")] {
            tapTab(in: app, key: key, symbol: symbol)
            app.buttons[addLabel].firstMatch.tap()
            XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 5))
            let editorScroll = app.scrollViews.containing(.textField, identifier: "entry.amount").firstMatch
            XCTAssertEqual(editorScroll.value as? String, "wide")
            let amount = app.otherElements["entry.section.amount"]
            let date = app.otherElements["entry.section.date"]
            let tags = app.otherElements["entry.section.tags"]
            let category = app.otherElements["entry.section.category"]
            XCTAssertTrue(amount.exists && date.exists && tags.exists && category.exists)
            attach(app, "native-editor-columns-\(key)")
            continueAfterFailure = true
            XCTAssertFalse(app.textFields["category.search"].exists)
            XCTAssertEqual(tags.frame.minX, amount.frame.minX, accuracy: 2)
            XCTAssertEqual(tags.frame.maxX, amount.frame.maxX, accuracy: 2)
            XCTAssertGreaterThanOrEqual(tags.frame.minY, date.frame.maxY - 1)
            XCTAssertGreaterThanOrEqual(category.frame.minX, amount.frame.maxX)
            continueAfterFailure = false
            app.buttons["取消"].firstMatch.tap()
        }
    }

    func testNativeWideSettingsContentWidth() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["QA_NATIVE_SIZE"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["period.year"].waitForExistence(timeout: 20))
        guard app.scrollViews["adaptive.page"].firstMatch.value as? String == "wide" else {
            throw XCTSkip("Run settings width in the opened Duo landscape workspace.")
        }
        tapTab(in: app, key: "stats", symbol: "chart.bar.xaxis")
        let panel = app.otherElements["stats.distribution.panel"].firstMatch
        if let division = activeDivision(in: app) {
            let positioned = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                panel.frame.minX >= division.maxX
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [positioned], timeout: 3), .completed)
        }
        let primary = app.scrollViews["adaptive.page"].firstMatch
        let originalPrimary = primary.frame
        app.buttons["stats.settings"].tap()
        let summary = app.otherElements["settings.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        attach(app, "native-settings-width")
        let pane = app.otherElements["settings.pane"].firstMatch
        XCTAssertTrue(pane.exists)
        XCTAssertGreaterThanOrEqual(summary.frame.minX - pane.frame.minX, 16)
        XCTAssertGreaterThanOrEqual(pane.frame.maxX - summary.frame.maxX, 16)
        let done = app.buttons["settings.done"]
        XCTAssertTrue(done.isHittable)
        XCTAssertGreaterThanOrEqual(done.frame.width, 44)
        XCTAssertGreaterThanOrEqual(done.frame.height, 44)
        XCTAssertGreaterThanOrEqual(pane.frame.maxX - done.frame.maxX, 16)
        let languageTitle = app.staticTexts["settings.language.title"]
        for language in ["zh-Hans", "zh-Hant", "en", "ja"] {
            let option = app.buttons["settings.language.\(language)"]
            XCTAssertTrue(option.isHittable)
            XCTAssertEqual(option.frame.midY, languageTitle.frame.midY, accuracy: 1)
            XCTAssertGreaterThanOrEqual(option.frame.minX, languageTitle.frame.maxX)
            XCTAssertLessThanOrEqual(option.frame.maxX, summary.frame.maxX - 16)
        }
        XCTAssertTrue(primary.staticTexts["收支概览"].exists)
        XCTAssertEqual(primary.frame.minX, originalPrimary.minX, accuracy: 2)
        XCTAssertEqual(primary.frame.maxX, originalPrimary.maxX, accuracy: 2)
        app.buttons["货币选择"].firstMatch.tap()
        let currencySummary = app.otherElements["settings.currency.summary"]
        XCTAssertTrue(currencySummary.waitForExistence(timeout: 5))
        attach(app, "native-currency-width")
        XCTAssertGreaterThanOrEqual(currencySummary.frame.minX - pane.frame.minX, 16)
        XCTAssertGreaterThanOrEqual(pane.frame.maxX - currencySummary.frame.maxX, 16)
        returnFromCurrency(in: app)
        app.buttons["settings.done"].tap()
    }

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
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        app.buttons["货币选择"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["货币选择"].waitForExistence(timeout: 5))
        attach(app, "inner-right-settings")
        XCTAssertTrue(app.scrollViews["adaptive.page"].firstMatch.staticTexts["收支概览"].exists)
        returnFromCurrency(in: app)
        app.buttons["settings.done"].tap()

        tapTab(in: app, key: "vault", symbol: "lock.shield.fill")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vault.select.")).firstMatch.exists)
        XCTAssertFalse(app.otherElements["vault.selectedGoal"].exists)
        let deposit = app.staticTexts["QA deposit 0"]
        reveal(deposit, in: app)
        XCTAssertTrue(deposit.isHittable)
        attach(app, "inner-plain-goals-and-deposits")

        tapTab(in: app, key: "expense", symbol: "minus.circle.fill")
        app.buttons["新增支出"].firstMatch.tap()
        let amount = app.textFields["entry.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("120")
        for (symbol, digit, expected) in [("+", "30", "120+30"), ("-", "10", "120+30-10"),
                                           ("×", "2", "120+30-10×2"), ("÷", "5", "120+30-10×2÷5")] {
            let control = app.buttons["amount.operator.\(symbol)"]
            XCTAssertTrue(control.isHittable)
            control.tap()
            let prefix = String(expected.dropLast(digit.count))
            let inserted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                amount.value as? String == prefix
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [inserted], timeout: 3), .completed)
            amount.typeText(digit)
            XCTAssertEqual(amount.value as? String, expected)
        }
        attach(app, "inner-before-calculated-amount")
        app.buttons["amount.equals"].tap()
        let calculated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            amount.value as? String == "146"
        }, object: nil)
        let calculationResult = XCTWaiter.wait(for: [calculated], timeout: 3)
        attach(app, "inner-calculated-amount")
        XCTAssertEqual(calculationResult, .completed, "Amount after Equals: \(amount.value as? String ?? "nil")")
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

    private func tapTab(in app: XCUIApplication, key: String, symbol: String, language: String = "zh-Hans") {
        let titles = language == "en"
            ? ["expense": "Expense", "income": "Income", "vault": "Vault", "stats": "Stats"]
            : ["expense": "支出", "income": "收入", "vault": "金库", "stats": "统计"]
        func tab() -> XCUIElement {
            let custom = app.buttons["mainTab.\(key)"]
            if custom.exists { return custom }
            let native = app.buttons.matching(NSPredicate(format: "label == %@", titles[key]!))
                .containing(.image, identifier: symbol).firstMatch
            return native.exists ? native : app.buttons[symbol].firstMatch
        }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let control = tab()
            return control.exists && app.windows.firstMatch.frame.contains(control.frame)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        let control = tab()
        let icon = control.images[symbol].firstMatch
        (icon.exists ? icon : control).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            tab().isSelected && app.staticTexts["mainPageTitle"].firstMatch.label == titles[key]!
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
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
            let viewport = app.windows.firstMatch.frame
            if element.exists, element.isHittable,
               element.frame.minY > viewport.minY + 100,
               element.frame.maxY < viewport.maxY - 60 { return }
            let primary = app.scrollViews["adaptive.page"].firstMatch
            let secondary = app.scrollViews["workspace.secondary"].firstMatch
            let editor = app.scrollViews.containing(.textField, identifier: "entry.amount").firstMatch
            let targetFrame = element.exists ? element.frame : .zero
            let pane = editor.exists ? editor : (secondary.exists && targetFrame.minX >= secondary.frame.minX ? secondary : primary)
            let towardTop = element.exists && targetFrame.minY <= viewport.minY + 100
            let start = pane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: towardTop ? 0.35 : 0.75))
            let end = pane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: towardTop ? 0.75 : 0.35))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable)
    }
}
