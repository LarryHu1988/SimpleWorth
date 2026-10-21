import XCTest
import SwiftData
import UIKit
@testable import CategoriesTagsCheck

@MainActor
final class ModelTests: XCTestCase {
    func testAboutIconHasLightAndDarkAssets() throws {
        let light = try XCTUnwrap(UIImage(named: "SimpleWorthIcon", in: .main,
                                          compatibleWith: UITraitCollection(userInterfaceStyle: .light)))
        let dark = try XCTUnwrap(UIImage(named: "SimpleWorthIcon", in: .main,
                                         compatibleWith: UITraitCollection(userInterfaceStyle: .dark)))
        XCTAssertGreaterThanOrEqual(light.size.width * light.scale, 1024)
        XCTAssertGreaterThanOrEqual(dark.size.width * dark.scale, 1024)
        XCTAssertNotEqual(light.pngData(), dark.pngData())
    }

    private func container() throws -> ModelContainer {
        let schema = Schema([TagRecord.self, LedgerEntry.self, SavingsGoalRecord.self, VaultDepositRecord.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    func testCategoriesSearchAndSymbols() {
        for flow in FlowType.allCases {
            let categories = CategoryLibrary.categories(for: flow)
            XCTAssertEqual(Set(categories.map(\.id)).count, categories.count)
            for item in categories { XCTAssertNotNil(UIImage(systemName: item.symbol), item.name) }
        }
        let cases: [(FlowType, String, String)] = [
            (.expense, "运动鞋", "鞋靴"), (.expense, "sneakers", "鞋靴"),
            (.expense, "靴", "鞋靴"), (.expense, "耳機", "数码配件"),
            (.expense, "奶茶", "饮品"), (.expense, "窗帘", "家居家纺"),
            (.income, "闲置", "二手"), (.income, "卖东西", "销售"),
            (.income, "tax refund", "退税")
        ]
        for (flow, query, expected) in cases {
            XCTAssertTrue(CategoryLibrary.filtered(CategoryLibrary.categories(for: flow), matching: query, locale: Locale(identifier: "en")).contains { $0.name == expected }, query)
        }
        XCTAssertEqual(CategoryLibrary.category(named: "服饰", flow: .expense)?.symbol, "tshirt.fill")
        XCTAssertTrue(CategoryLibrary.category(named: "退款", flow: .expense) == CategoryLibrary.expenseRefundCategory)
    }

    func testFiveColumnCatalogsAndHistoricalCategoryRowsStayComplete() {
        XCTAssertEqual(CategoryLibrary.expenseCategories.count, 70)
        XCTAssertEqual(CategoryLibrary.incomeCategories.count, 30)
        XCTAssertEqual(CategoryLibrary.columnCount, 5)
        for flow in FlowType.allCases {
            let catalog = CategoryLibrary.categories(for: flow)
            XCTAssertEqual(catalog.count % CategoryLibrary.columnCount, 0)
            XCTAssertEqual(CategoryLibrary.editorCategories(for: flow, including: nil), catalog)
            XCTAssertEqual(CategoryLibrary.editorCategories(for: flow, including: catalog.first), catalog)
            for name in ["旧分类", "搬家仓储", "返现", CategoryLibrary.refundCategoryName] {
                let saved = CategoryItem(flow: flow, name: name, symbol: "star.fill", colorHex: 0x123456)
                let choices = CategoryLibrary.editorCategories(for: flow, including: saved)
                XCTAssertEqual(choices.first, saved)
                XCTAssertEqual(choices.count % CategoryLibrary.columnCount, 0, name)
                XCTAssertEqual(Set(choices.map(\.id)).count, choices.count)
                XCTAssertTrue(Set(catalog).isSubset(of: Set(choices)))
                for item in choices {
                    XCTAssertNotNil(UIImage(systemName: item.symbol), item.name)
                    for language in AppLanguage.allCases {
                        let text = item.localizedName(in: language.locale)
                        XCTAssertFalse(text.isEmpty)
                        if name != item.name && language == .english {
                            XCTAssertNotEqual(text, item.name)
                        }
                    }
                }
            }
        }
    }

    func testReviewAndSharePointToTheSameAppStoreProduct() throws {
        XCTAssertEqual(AppConfig.appStoreURL.host, "apps.apple.com")
        XCTAssertTrue(AppConfig.appStoreURL.path.hasSuffix("/id6761478113"))
        let review = try XCTUnwrap(URLComponents(url: AppConfig.appStoreReviewURL, resolvingAgainstBaseURL: false))
        XCTAssertEqual(review.path, AppConfig.appStoreURL.path)
        XCTAssertEqual(review.queryItems, [URLQueryItem(name: "action", value: "write-review")])
    }

    func testOrderMovesAndNewTagsAppendWithoutChangingNamesOrDates() throws {
        let store = try container()
        let context = store.mainContext
        let tags = (0..<3).map { TagRecord(name: "Tag\($0)", createdAt: Date(timeIntervalSince1970: Double($0))) }
        tags.forEach { context.insert($0) }
        try context.save()
        try TagOrdering.move(tags, from: IndexSet(integer: 2), to: 0, context: context)
        XCTAssertEqual(TagOrdering.visible(tags).map(\.name), ["Tag2", "Tag0", "Tag1"])
        try TagOrdering.move(tags, from: IndexSet([0, 1]), to: 3, context: context)
        XCTAssertEqual(TagOrdering.visible(tags).map(\.name), ["Tag1", "Tag2", "Tag0"])
        XCTAssertEqual(tags.map(\.createdAt), (0..<3).map { Date(timeIntervalSince1970: Double($0)) })
        let new = TagRecord(name: "New", sortOrder: TagOrdering.nextOrder(in: tags))
        XCTAssertEqual(TagOrdering.sorted(tags + [new]).last?.name, "New")
        let reader = ModelContext(store)
        XCTAssertEqual(TagOrdering.sorted(try reader.fetch(FetchDescriptor<TagRecord>())).map(\.name), ["Tag1", "Tag2", "Tag0"])
    }

    func testDuplicateTagsStayBehindVisibleTagsAfterMove() throws {
        let store = try container()
        let context = store.mainContext
        let tags = [TagRecord(name: "A"), TagRecord(name: "B"), TagRecord(name: "a"), TagRecord(name: " ")]
        tags.forEach { context.insert($0) }
        try TagOrdering.move(tags, from: IndexSet(integer: 0), to: 2, context: context)
        XCTAssertEqual(TagOrdering.visible(tags).map(\.name), ["B", "A"])
        XCTAssertEqual(Set(tags.map(\.sortOrder)).count, tags.count)
    }

    func testBackupOrderRoundTripAndOldBackupCompatibility() throws {
        let store = try container()
        let context = store.mainContext
        let a = TagRecord(name: "A", createdAt: Date(timeIntervalSince1970: 1), sortOrder: 1)
        let b = TagRecord(name: "B", createdAt: Date(timeIntervalSince1970: 2), sortOrder: 0)
        let payload = LedgerBackupCoordinator.makePayload(appVersion: "QA", entries: [], tags: [a, b], goals: [], deposits: [])
        let data = try LedgerBackupCodec.encodePayload(payload)
        try LedgerBackupCoordinator.replaceLocalData(with: LedgerBackupCodec.decodePayload(from: data), context: context, entries: [], tags: [], goals: [], deposits: [])
        var tags = try context.fetch(FetchDescriptor<TagRecord>())
        XCTAssertEqual(TagOrdering.sorted(tags).map(\.name), ["B", "A"])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["tags"] = (json["tags"] as! [[String: Any]]).map { value in
            var old = value
            old.removeValue(forKey: "sortOrder")
            return old
        }
        let oldPayload = try LedgerBackupCodec.decodePayload(from: JSONSerialization.data(withJSONObject: json))
        try LedgerBackupCoordinator.replaceLocalData(with: oldPayload, context: context, entries: [], tags: tags, goals: [], deposits: [])
        tags = try context.fetch(FetchDescriptor<TagRecord>())
        XCTAssertEqual(TagOrdering.sorted(tags).map(\.name), ["A", "B"])
    }

    func testLegacySameSecondTagOrderSurvivesBackup() throws {
        let store = try container()
        let first = TagRecord(
            id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!, name: "First",
            createdAt: Date(timeIntervalSince1970: 1.1)
        )
        let second = TagRecord(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, name: "Second",
            createdAt: Date(timeIntervalSince1970: 1.2)
        )
        let payload = LedgerBackupCoordinator.makePayload(
            appVersion: "QA", entries: [], tags: [second, first], goals: [], deposits: []
        )
        let restored = try LedgerBackupCodec.decodePayload(from: LedgerBackupCodec.encodePayload(payload))
        try LedgerBackupCoordinator.replaceLocalData(
            with: restored, context: store.mainContext, entries: [], tags: [], goals: [], deposits: []
        )
        let tags = try store.mainContext.fetch(FetchDescriptor<TagRecord>())
        XCTAssertEqual(TagOrdering.sorted(tags).map(\.name), ["First", "Second"])
    }

    func testLocalizedCategoryNames() {
        for language in AppLanguage.allCases {
            for name in ["鞋靴", "数码配件", "退税"] {
                let translation = name.appLocalized(in: language.locale)
                XCTAssertFalse(translation.isEmpty)
                if language == .english || language == .japanese { XCTAssertNotEqual(translation, name) }
            }
        }
    }
}
