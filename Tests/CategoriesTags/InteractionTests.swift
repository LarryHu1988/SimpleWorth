import XCTest

final class InteractionTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testFiveColumnDashboardAndLastRowsInFourLanguages() {
        for language in ["zh-Hans", "zh-Hant", "en", "ja"] {
            for flow in ["expense", "income"] {
                let app = XCUIApplication()
                app.launchEnvironment = ["QA_SCREEN": "categories", "QA_FLOW": flow, "QA_LANGUAGE": language]
                app.launch()
                let first = flow == "expense" ? ["餐饮", "外卖", "咖啡", "零食", "饮品"] : ["工资", "奖金", "兼职", "副业", "提成"]
                let last = flow == "expense" ? ["育儿", "税费", "手续费", "鲜花绿植", "其他支出"] : ["退税", "赔偿", "退款", "现金存入", "其他收入"]
                let id = "ledger.category.\(flow)."
                XCTAssertTrue(app.buttons[id + first[0]].waitForExistence(timeout: 15))
                assertFiveColumnRow(first.map { app.buttons[id + $0] }, app: app)
                attach(app, "grid-\(flow)-\(language)-first")
                reveal(app.buttons[id + last.last!], in: app)
                assertFiveColumnRow(last.map { app.buttons[id + $0] }, app: app)
                attach(app, "grid-\(flow)-\(language)-last")
                app.terminate()
            }
        }
    }

    func testSettingsReviewLinkAndShareSheet() {
        let app = XCUIApplication()
        app.launchEnvironment["QA_SCREEN"] = "settings"
        app.launch()
        let review = app.buttons["settings.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 15))
        reveal(review, in: app)
        review.tap()
        let opened = app.staticTexts["qa.openedURL"]
        XCTAssertTrue(opened.waitForExistence(timeout: 5))
        XCTAssertTrue(opened.label.contains("/id6761478113?action=write-review"), opened.label)
        app.buttons["settings.share"].tap()
        let copy = app.cells.matching(NSPredicate(format: "label IN %@", ["Copy", "拷贝", "复制"])).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 8))
        attach(app, "settings-share-correct-app")
        copy.tap()
        XCTAssertTrue(copy.waitForNonExistence(timeout: 5))
    }

    func testSettingsDirectFeedbackAndPrivacy() {
        let app = settingsApp()
        let feedback = app.buttons["settings.feedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 15))
        reveal(feedback, in: app)
        feedback.tap()
        XCTAssertEqual(app.staticTexts["qa.openedURL"].label, "mailto:simpleworth@larryhu.com")
        XCTAssertEqual(app.staticTexts["qa.settingsPathDepth"].label, "0")
        XCTAssertFalse(app.staticTexts["反馈方式"].exists)
        XCTAssertFalse(app.buttons["event.settingsOpen"].exists)
        XCTAssertFalse(app.staticTexts["七日开支观察"].exists)
        let privacy = app.buttons["settings.privacy"]
        reveal(privacy, in: app)
        privacy.tap()
        XCTAssertEqual(app.staticTexts["qa.openedURL"].label, "https://larryhu.com/simpleworth/privacy/")
        XCTAssertEqual(app.staticTexts["qa.settingsPathDepth"].label, "0")
        XCTAssertFalse(app.staticTexts["数据与同步"].exists)
        attach(app, "settings-direct-actions")
    }

    func testFeedbackUnavailableKeepsAddressAndSettings() {
        let app = settingsApp(rejectURL: true)
        let feedback = app.buttons["settings.feedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 15))
        reveal(feedback, in: app)
        feedback.tap()
        let message = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "邮箱地址已复制")).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.label.contains("simpleworth@larryhu.com"))
        app.buttons["确定"].firstMatch.tap()
        XCTAssertTrue(message.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["qa.settingsPathDepth"].label, "0")
        let privacy = app.buttons["settings.privacy"]
        reveal(privacy, in: app)
        privacy.tap()
        XCTAssertTrue(app.staticTexts["暂时无法打开网页，请稍后重试。"].waitForExistence(timeout: 5))
    }

    func testAboutSelectedLanguageOnlyAndLiveVersion() {
        let slogans = ["zh-Hans": "记得简单，心里有数。", "zh-Hant": "記得簡單，心裡有數。",
                       "en": "Less clutter. More clarity.", "ja": "日々のお金を、すっきりと。"]
        for language in ["zh-Hans", "zh-Hant", "en", "ja"] {
            let app = settingsApp(language: language)
            let about = app.buttons["settings.about"]
            XCTAssertTrue(about.waitForExistence(timeout: 15))
            reveal(about, in: app)
            about.tap()
            let localSlogan = app.staticTexts[slogans[language]!]
            XCTAssertTrue(localSlogan.waitForExistence(timeout: 5))
            XCTAssertTrue(app.otherElements["about.introduction.\(language)"].exists)
            for otherLanguage in slogans.keys where otherLanguage != language {
                XCTAssertFalse(app.otherElements["about.introduction.\(otherLanguage)"].exists)
                XCTAssertFalse(app.staticTexts[slogans[otherLanguage]!].exists)
            }
            let window = app.windows.firstMatch.frame
            XCTAssertGreaterThanOrEqual(localSlogan.frame.minX, window.minX)
            XCTAssertLessThanOrEqual(localSlogan.frame.maxX, window.maxX)
            let icon = app.images["about.icon"]
            XCTAssertTrue(icon.exists)
            XCTAssertEqual(icon.frame.width, 64, accuracy: 1)
            XCTAssertEqual(icon.frame.height, 64, accuracy: 1)
            XCTAssertGreaterThanOrEqual(localSlogan.frame.minX, icon.frame.maxX + 10)
            XCTAssertEqual(localSlogan.frame.midY, icon.frame.midY, accuracy: 1)
            for heading in ["简体中文", "繁體中文", "English", "日本語", "基本信息", "基本資訊", "About", "基本情報"] {
                XCTAssertFalse(app.staticTexts[heading].exists, heading)
            }
            attach(app, "about-\(language)-top")
            let version = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label MATCHES %@", "about.version", "V[0-9].*")).firstMatch
            reveal(version, in: app)
            XCTAssertEqual(version.label, "V" + app.staticTexts["qa.bundleVersion"].label)
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "SimpleWorth - 简值")).firstMatch.exists)
            XCTAssertTrue(app.staticTexts["Larry Hu"].exists)
            XCTAssertFalse(app.staticTexts["轻量记账与目标管理"].exists)
            attach(app, "about-\(language)-information")
            let home = app.buttons["about.homepage"]
            reveal(home, in: app)
            home.tap()
            XCTAssertEqual(app.staticTexts["qa.openedURL"].label, "https://larryhu.com/simpleworth/")
            XCTAssertEqual(app.staticTexts["qa.settingsPathDepth"].label, "1")
            app.terminate()
        }
    }

    func testAboutDarkIconAndCompactInfo() {
        let app = settingsApp(dark: true)
        let about = app.buttons["settings.about"]
        XCTAssertTrue(about.waitForExistence(timeout: 15))
        reveal(about, in: app)
        about.tap()
        XCTAssertTrue(app.images["about.icon"].waitForExistence(timeout: 5))
        let home = app.buttons["about.homepage"]
        reveal(home, in: app)
        XCTAssertTrue(app.staticTexts["Larry Hu"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label MATCHES %@", "about.version", "V[0-9].*")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["基本信息"].exists)
        attach(app, "about-icon-and-information-dark")
    }

    func testOtherAppsHasNoSectionHeadings() {
        let titles = ["zh-Hans": "其它 APP", "zh-Hant": "其它 APP", "en": "Other Apps", "ja": "その他のアプリ"]
        for language in ["zh-Hans", "zh-Hant", "en", "ja"] {
            let app = settingsApp(language: language, dark: language == "zh-Hans" || language == "en")
            let otherApps = app.buttons["settings.otherApps"]
            XCTAssertTrue(otherApps.waitForExistence(timeout: 15))
            reveal(otherApps, in: app)
            XCTAssertEqual(otherApps.label, titles[language]!)
            otherApps.tap()
            XCTAssertTrue(app.navigationBars[titles[language]!].waitForExistence(timeout: 5))
            for heading in ["更多作品", "More Works", "その他の作品"] {
                XCTAssertFalse(app.staticTexts[heading].exists)
            }
            let keepFit = app.buttons["settings.otherApp.keepfit"]
            let pdf = app.buttons["settings.otherApp.pdf-librarian"]
            XCTAssertTrue(keepFit.exists)
            reveal(pdf, in: app)
            XCTAssertTrue(pdf.exists)
            XCTAssertFalse(app.staticTexts["联系与支持"].exists)
            XCTAssertFalse(app.buttons["联系邮箱"].exists)
            attach(app, "other-apps-no-heading-\(language)")
            pdf.tap()
            XCTAssertTrue(app.staticTexts["qa.openedURL"].label.contains("id6760351540"))
            keepFit.tap()
            XCTAssertTrue(app.staticTexts["qa.openedURL"].label.contains("id6759662867"))
            app.terminate()
        }
    }

    private func settingsApp(language: String = "zh-Hans", dark: Bool = false, rejectURL: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["QA_SCREEN": "settings", "QA_LANGUAGE": language,
                                 "QA_DARK": dark ? "1" : "0", "QA_REJECT_URL": rejectURL ? "1" : "0"]
        app.launch()
        return app
    }

    func testNativeWideEditorFiveColumns() throws {
        for flow in ["expense", "income"] {
            let app = XCUIApplication()
            app.launchEnvironment = ["QA_SCREEN": "editor", "QA_FLOW": flow, "QA_LANGUAGE": "en"]
            app.launch()
            let first = flow == "expense" ? ["餐饮", "外卖", "咖啡", "零食", "饮品"] : ["工资", "奖金", "兼职", "副业", "提成"]
            XCTAssertTrue(app.buttons["entry.category." + first[0]].waitForExistence(timeout: 15))
            guard app.windows.firstMatch.frame.width >= 600 else {
                throw XCTSkip("Prepare an actual wide iPad window or unfolded Duo display before running this test.")
            }
            let geometry = XCTAttachment(string: "Native editor window: \(app.windows.firstMatch.frame); application: \(app.frame)")
            geometry.lifetime = .keepAlways
            add(geometry)
            reveal(app.buttons["entry.category." + first[0]], in: app)
            assertFiveColumnRow(first.map { app.buttons["entry.category." + $0] }, app: app)
            app.buttons["entry.category." + first[1]].tap()
            XCTAssertTrue(app.buttons["entry.category." + first[1]].isSelected)
            attach(app, "native-wide-editor-\(flow)")
            app.terminate()
        }
    }

    private func assertFiveColumnRow(_ buttons: [XCUIElement], app: XCUIApplication) {
        XCTAssertEqual(buttons.count, 5)
        let frames = buttons.map(\.frame)
        let window = app.windows.firstMatch.frame
        for (button, frame) in zip(buttons, frames) {
            XCTAssertTrue(button.exists)
            XCTAssertGreaterThanOrEqual(frame.width, 38)
            XCTAssertGreaterThanOrEqual(frame.minX, window.minX)
            XCTAssertLessThanOrEqual(frame.maxX, window.maxX)
            XCTAssertEqual(frame.midY, frames[0].midY, accuracy: 1)
            XCTAssertEqual(frame.width, frames[0].width, accuracy: 1)
            let label = button.staticTexts.firstMatch
            if label.exists { XCTAssertEqual(label.frame.midX, frame.midX, accuracy: 1) }
        }
        for pair in zip(frames, frames.dropFirst()) { XCTAssertLessThan(pair.0.maxX, pair.1.minX) }
    }

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
            let window = app.windows.firstMatch
            if element.isHittable, frame.minY > top + 8, frame.maxY < window.frame.maxY - 60 { return }
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            let belowHeader = element.exists && frame.height > 0 && frame.minY <= top + 8
            let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: belowHeader ? 0.88 : 0.40))
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
