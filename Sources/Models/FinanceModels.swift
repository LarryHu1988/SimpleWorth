import Foundation
import SwiftData
import SwiftUI

enum FlowType: String, CaseIterable, Identifiable, Codable, Sendable {
    case expense = "支出"
    case income = "收入"

    var id: String { storageValue }

    var storageValue: String {
        switch self {
        case .expense: "expense"
        case .income: "income"
        }
    }

    init(storageValue: String) {
        self = storageValue == FlowType.income.storageValue ? .income : .expense
    }

    var tabIcon: String {
        switch self {
        case .expense: "minus.circle.fill"
        case .income: "plus.circle.fill"
        }
    }

    var localizedTitle: String {
        rawValue.appLocalized
    }

    func localizedTitle(in locale: Locale) -> String {
        rawValue.appLocalized(in: locale)
    }

    var accent: Color {
        switch self {
        case .expense: SWTheme.accentOrange
        case .income: SWTheme.accentGreen
        }
    }

    var opposite: FlowType {
        switch self {
        case .expense:
            .income
        case .income:
            .expense
        }
    }
}

struct CategoryItem: Identifiable, Hashable {
    let flow: FlowType
    let name: String
    let symbol: String
    let colorHex: Int

    var id: String {
        "\(flow.storageValue)-\(name)-\(symbol)-\(colorHex)"
    }

    var color: Color {
        Color.sw(UInt(colorHex))
    }

    var localizedName: String {
        name.appLocalized
    }

    func localizedName(in locale: Locale) -> String {
        name.appLocalized(in: locale)
    }
}

struct MonthlyCashflow: Identifiable {
    let monthStart: Date
    let monthLabel: String
    let expense: Double
    let income: Double

    var id: Date { monthStart }
}

struct CategoryStat: Identifiable {
    let key: String
    let name: String
    let symbol: String
    let colorHex: Int
    let amount: Double
    let usesEmoji: Bool

    var id: String { key }

    var color: Color {
        Color.sw(UInt(colorHex))
    }
}

enum TagEmojiLibrary {
    static let defaultEmoji = "🏷️"
    static let tintOptions: [Int] = [
        0x5B8DEF, 0x67C587, 0xF59D5B, 0xE27AB0,
        0x9B8CFF, 0x53C4D1, 0xE4B84A, 0xF06A6A
    ]
    static let defaultTintHex = tintOptions[0]

    static func normalized(_ emoji: String) -> String {
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = trimmed.first else { return defaultEmoji }
        return String(value)
    }

    static func colorHex(for name: String) -> Int {
        let hash = name.unicodeScalars.reduce(0) { partialResult, scalar in
            ((partialResult * 31) + Int(scalar.value)) & 0x7fffffff
        }
        return tintOptions[hash % tintOptions.count]
    }
}

@Model
final class TagRecord {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = TagEmojiLibrary.defaultEmoji
    var tintHex: Int = TagEmojiLibrary.defaultTintHex
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = TagEmojiLibrary.defaultEmoji,
        tintHex: Int = TagEmojiLibrary.defaultTintHex,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.emoji = TagEmojiLibrary.normalized(emoji)
        self.tintHex = tintHex
        self.createdAt = createdAt
    }

    var emojiValue: String {
        TagEmojiLibrary.normalized(emoji)
    }

    var resolvedTintHex: Int {
        tintHex == 0 ? TagEmojiLibrary.colorHex(for: name) : tintHex
    }

    var tintColor: Color {
        Color.sw(UInt(resolvedTintHex))
    }
}

@Model
final class LedgerEntry {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var recordedAt: Date?
    // Normalized to CNY for unified statistics and chart aggregation.
    var amount: Double = 0
    // Original user input amount in the selected currency.
    var originalAmount: Double = 0
    var currencyCode: String = CurrencyCatalog.defaultBaseCode
    // 1 unit of selected currency equals how many CNY.
    var exchangeRateToCNY: Double = 1
    var note: String = ""
    var flowRaw: String = FlowType.expense.storageValue
    var categoryName: String = ""
    var categorySymbol: String = ""
    var categoryColorHex: Int = 0x9CA3AF
    var tagNamesRaw: String = "[]"
    var refundSourceEntryIDRaw: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        recordedAt: Date? = .now,
        amount: Double,
        originalAmount: Double? = nil,
        currencyCode: String = "CNY",
        exchangeRateToCNY: Double = 1,
        note: String,
        flow: FlowType,
        category: CategoryItem,
        tagNames: [String] = [],
        refundSourceEntryID: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.recordedAt = recordedAt
        self.amount = amount
        self.originalAmount = originalAmount ?? amount
        self.currencyCode = currencyCode
        self.exchangeRateToCNY = exchangeRateToCNY
        self.note = note
        self.flowRaw = flow.storageValue
        self.categoryName = category.name
        self.categorySymbol = category.symbol
        self.categoryColorHex = category.colorHex
        self.tagNames = tagNames
        self.refundSourceEntryID = refundSourceEntryID
    }

    var flow: FlowType {
        get { FlowType(storageValue: flowRaw) }
        set { flowRaw = newValue.storageValue }
    }

    var categoryColor: Color {
        Color.sw(UInt(categoryColorHex))
    }

    var resolvedRecordedAt: Date {
        recordedAt ?? createdAt
    }

    var refundSourceEntryID: UUID? {
        get {
            guard let rawValue = refundSourceEntryIDRaw else { return nil }
            return UUID(uuidString: rawValue)
        }
        set {
            refundSourceEntryIDRaw = newValue?.uuidString
        }
    }

    var displayAmount: Double {
        originalAmount > 0 ? originalAmount : amount
    }

    var tagNames: [String] {
        get {
            guard let data = tagNamesRaw.data(using: .utf8) else { return [] }
            if let decoded = try? JSONDecoder().decode([String].self, from: data) {
                return decoded
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }

            return tagNamesRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            var seen = Set<String>()
            let normalized = newValue.compactMap { rawName -> String? in
                let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                let lookup = name.lowercased()
                guard seen.insert(lookup).inserted else { return nil }
                return name
            }

            if
                let encoded = try? JSONEncoder().encode(normalized),
                let rawValue = String(data: encoded, encoding: .utf8)
            {
                tagNamesRaw = rawValue
            } else {
                tagNamesRaw = "[]"
            }
        }
    }

    var isRefundEntry: Bool {
        categoryName == CategoryLibrary.refundCategoryName
    }

    var signedDisplayAmount: Double {
        switch flow {
        case .expense:
            return isRefundEntry ? displayAmount : -displayAmount
        case .income:
            return displayAmount
        }
    }

    var signedAmountInCNY: Double {
        switch flow {
        case .expense:
            return isRefundEntry ? amount : -amount
        case .income:
            return amount
        }
    }

    var amountTint: Color {
        if flow == .income {
            return SWTheme.accentGreen
        }
        return isRefundEntry ? SWTheme.accentBlue : SWTheme.accentOrange
    }

    var expenseContribution: Double {
        guard flow == .expense else { return 0 }
        return isRefundEntry ? -amount : amount
    }

    var incomeContribution: Double {
        guard flow == .income else { return 0 }
        return amount
    }

    var flowPageContribution: Double {
        switch flow {
        case .expense:
            return isRefundEntry ? -amount : amount
        case .income:
            return amount
        }
    }
}

@Model
final class SavingsGoalRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var name: String = ""
    var symbol: String = "target"
    var currentAmount: Double = 0
    var targetAmount: Double = 0
    var deadline: Date?
    var tintHex: Int = 0x38BDF8
    @Relationship(deleteRule: .cascade, inverse: \VaultDepositRecord.goal) var deposits: [VaultDepositRecord]?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        name: String,
        symbol: String,
        currentAmount: Double,
        targetAmount: Double,
        deadline: Date? = nil,
        tintHex: Int
    ) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.symbol = symbol
        self.currentAmount = currentAmount
        self.targetAmount = targetAmount
        self.deadline = deadline
        self.tintHex = tintHex
        self.deposits = []
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(max(currentAmount / targetAmount, 0), 1)
    }

    var tintColor: Color {
        Color.sw(UInt(tintHex))
    }

    var deadlineText: String {
        guard let deadline else { return "长期".appLocalized }
        return deadline.formatted(
            .dateTime
                .year()
                .month(.defaultDigits)
                .locale(L10n.locale)
        )
    }

    func deadlineText(in locale: Locale) -> String {
        guard let deadline else { return "长期".appLocalized(in: locale) }
        return deadline.formatted(
            .dateTime
                .year()
                .month(.defaultDigits)
                .locale(locale)
        )
    }
}

@Model
final class VaultDepositRecord {
    var id: UUID = UUID()
    var date: Date = Date.now
    var amount: Double = 0
    var note: String = ""
    var goal: SavingsGoalRecord?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        amount: Double,
        note: String,
        goal: SavingsGoalRecord? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.note = note
        self.goal = goal
    }
}

enum CategoryLibrary {
    static let refundCategoryName = "退款"
    static let expenseRefundCategory = CategoryItem(
        flow: .expense,
        name: refundCategoryName,
        symbol: "arrow.uturn.backward.circle.fill",
        colorHex: 0x5AACE8
    )

    static let expenseCategories: [CategoryItem] = [
        .init(flow: .expense, name: "餐饮", symbol: "fork.knife", colorHex: 0xF87171),
        .init(flow: .expense, name: "外卖", symbol: "takeoutbag.and.cup.and.straw.fill", colorHex: 0xFB7185),
        .init(flow: .expense, name: "咖啡", symbol: "cup.and.saucer.fill", colorHex: 0xFB923C),
        .init(flow: .expense, name: "零食", symbol: "birthday.cake.fill", colorHex: 0xFBBF24),
        .init(flow: .expense, name: "买菜", symbol: "cart.fill", colorHex: 0x34D399),
        .init(flow: .expense, name: "超市", symbol: "basket.fill", colorHex: 0xA78BFA),
        .init(flow: .expense, name: "日用品", symbol: "bag.fill", colorHex: 0x38BDF8),
        .init(flow: .expense, name: "快递", symbol: "shippingbox.fill", colorHex: 0x60A5FA),
        .init(flow: .expense, name: "服饰", symbol: "tshirt.fill", colorHex: 0xF472B6),
        .init(flow: .expense, name: "美容理发", symbol: "scissors", colorHex: 0xE879F9),
        .init(flow: .expense, name: "化妆护肤", symbol: "sparkles", colorHex: 0xF0ABFC),
        .init(flow: .expense, name: "住房", symbol: "house.fill", colorHex: 0x60A5FA),
        .init(flow: .expense, name: "房租", symbol: "key.fill", colorHex: 0x93C5FD),
        .init(flow: .expense, name: "房贷", symbol: "building.columns.fill", colorHex: 0x2563EB),
        .init(flow: .expense, name: "物业", symbol: "building.2.fill", colorHex: 0x7DD3FC),
        .init(flow: .expense, name: "水电", symbol: "bolt.fill", colorHex: 0xFACC15),
        .init(flow: .expense, name: "燃气", symbol: "flame.fill", colorHex: 0xF97316),
        .init(flow: .expense, name: "通讯", symbol: "wifi", colorHex: 0x22D3EE),
        .init(flow: .expense, name: "家政维修", symbol: "wrench.and.screwdriver.fill", colorHex: 0x94A3B8),
        .init(flow: .expense, name: "家具家电", symbol: "sofa.fill", colorHex: 0xA16207),
        .init(flow: .expense, name: "交通", symbol: "car.fill", colorHex: 0x818CF8),
        .init(flow: .expense, name: "打车", symbol: "location.fill", colorHex: 0x6366F1),
        .init(flow: .expense, name: "公交", symbol: "bus.fill", colorHex: 0x2DD4BF),
        .init(flow: .expense, name: "加油", symbol: "fuelpump.fill", colorHex: 0xFB7185),
        .init(flow: .expense, name: "停车", symbol: "parkingsign.circle.fill", colorHex: 0x0EA5E9),
        .init(flow: .expense, name: "车辆保养", symbol: "wrench.fill", colorHex: 0x64748B),
        .init(flow: .expense, name: "旅行", symbol: "airplane", colorHex: 0x38BDF8),
        .init(flow: .expense, name: "酒店住宿", symbol: "bed.double.fill", colorHex: 0x0F766E),
        .init(flow: .expense, name: "机票火车", symbol: "train.side.front.car", colorHex: 0x0284C7),
        .init(flow: .expense, name: "景点门票", symbol: "ticket.fill", colorHex: 0xF59E0B),
        .init(flow: .expense, name: "电影", symbol: "film.fill", colorHex: 0xC084FC),
        .init(flow: .expense, name: "游戏", symbol: "gamecontroller.fill", colorHex: 0xA3E635),
        .init(flow: .expense, name: "阅读", symbol: "book.fill", colorHex: 0xF59E0B),
        .init(flow: .expense, name: "订阅", symbol: "repeat.circle.fill", colorHex: 0x8B5CF6),
        .init(flow: .expense, name: "娱乐", symbol: "sparkles", colorHex: 0xC084FC),
        .init(flow: .expense, name: "医疗", symbol: "stethoscope", colorHex: 0x10B981),
        .init(flow: .expense, name: "药品", symbol: "pills.fill", colorHex: 0x14B8A6),
        .init(flow: .expense, name: "保险", symbol: "shield.fill", colorHex: 0x0EA5E9),
        .init(flow: .expense, name: "宠物", symbol: "pawprint.fill", colorHex: 0xF97316),
        .init(flow: .expense, name: "礼物", symbol: "gift.fill", colorHex: 0xE879F9),
        .init(flow: .expense, name: "社交", symbol: "person.2.fill", colorHex: 0xEC4899),
        .init(flow: .expense, name: "健身", symbol: "figure.run", colorHex: 0x84CC16),
        .init(flow: .expense, name: "数码", symbol: "laptopcomputer", colorHex: 0x06B6D4),
        .init(flow: .expense, name: "摄影", symbol: "camera.fill", colorHex: 0x3B82F6),
        .init(flow: .expense, name: "音乐", symbol: "music.note", colorHex: 0xEC4899),
        .init(flow: .expense, name: "教育", symbol: "graduationcap.fill", colorHex: 0x14B8A6),
        .init(flow: .expense, name: "办公", symbol: "briefcase.fill", colorHex: 0x64748B),
        .init(flow: .expense, name: "育儿", symbol: "figure.2.and.child.holdinghands", colorHex: 0xF59E0B),
        .init(flow: .expense, name: "税费", symbol: "doc.text.fill", colorHex: 0xEF4444),
        .init(flow: .expense, name: "其他支出", symbol: "ellipsis.circle.fill", colorHex: 0x9CA3AF)
    ]

    static let incomeCategories: [CategoryItem] = [
        .init(flow: .income, name: "工资", symbol: "banknote.fill", colorHex: 0x34D399),
        .init(flow: .income, name: "奖金", symbol: "star.circle.fill", colorHex: 0xFBBF24),
        .init(flow: .income, name: "兼职", symbol: "briefcase.fill", colorHex: 0x60A5FA),
        .init(flow: .income, name: "副业", symbol: "laptopcomputer", colorHex: 0x22D3EE),
        .init(flow: .income, name: "提成", symbol: "chart.bar.fill", colorHex: 0x06B6D4),
        .init(flow: .income, name: "报销", symbol: "doc.text.fill", colorHex: 0xF59E0B),
        .init(flow: .income, name: "差旅补贴", symbol: "suitcase.fill", colorHex: 0x0EA5E9),
        .init(flow: .income, name: "津贴", symbol: "wallet.pass.fill", colorHex: 0xFB923C),
        .init(flow: .income, name: "补助", symbol: "hands.sparkles.fill", colorHex: 0x84CC16),
        .init(flow: .income, name: "奖学金", symbol: "graduationcap.fill", colorHex: 0x93C5FD),
        .init(flow: .income, name: "理财", symbol: "chart.line.uptrend.xyaxis", colorHex: 0xA78BFA),
        .init(flow: .income, name: "股票", symbol: "building.columns.fill", colorHex: 0x818CF8),
        .init(flow: .income, name: "基金", symbol: "chart.pie.fill", colorHex: 0x4ADE80),
        .init(flow: .income, name: "利息", symbol: "percent", colorHex: 0x10B981),
        .init(flow: .income, name: "分红", symbol: "sparkles", colorHex: 0x67E8F9),
        .init(flow: .income, name: "租金", symbol: "house.fill", colorHex: 0x2DD4BF),
        .init(flow: .income, name: "二手", symbol: "repeat.circle.fill", colorHex: 0xF472B6),
        .init(flow: .income, name: "销售", symbol: "cart.badge.plus", colorHex: 0x14B8A6),
        .init(flow: .income, name: "创作", symbol: "paintbrush.fill", colorHex: 0xE879F9),
        .init(flow: .income, name: "稿费", symbol: "signature", colorHex: 0xA3E635),
        .init(flow: .income, name: "咨询", symbol: "person.crop.circle.badge.checkmark", colorHex: 0x84CC16),
        .init(flow: .income, name: "红包", symbol: "gift.fill", colorHex: 0xFB7185),
        .init(flow: .income, name: refundCategoryName, symbol: "arrow.uturn.backward.circle.fill", colorHex: 0x38BDF8),
        .init(flow: .income, name: "现金存入", symbol: "creditcard.fill", colorHex: 0x16A34A),
        .init(flow: .income, name: "其他收入", symbol: "ellipsis.circle.fill", colorHex: 0x9CA3AF)
    ]

    static func categories(for flow: FlowType) -> [CategoryItem] {
        switch flow {
        case .expense: expenseCategories
        case .income: incomeCategories
        }
    }

    static func defaultCategory(for flow: FlowType) -> CategoryItem {
        categories(for: flow).first ?? .init(
            flow: flow,
            name: flow == .expense ? "其他支出" : "其他收入",
            symbol: "square.grid.2x2.fill",
            colorHex: 0x9CA3AF
        )
    }

    static func category(named name: String, flow: FlowType) -> CategoryItem? {
        if flow == .expense, name == refundCategoryName {
            return expenseRefundCategory
        }
        return categories(for: flow).first { $0.name == name }
    }
}

enum SeedService {
    private static let seedKey = "simpleworth.seed.v0.1.0"

    static func seedIfNeeded(context _: ModelContext) {
        if UserDefaults.standard.bool(forKey: seedKey) {
            return
        }

        // Keep the one-time launch marker, but stop injecting demo data for new installs.
        UserDefaults.standard.set(true, forKey: seedKey)
    }
}

extension Date {
    static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
    }

    static func date(year: Int, month: Int, day: Int) -> Date? {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }

    var monthLabel: String {
        monthLabel(in: L10n.locale)
    }

    func monthLabel(in locale: Locale) -> String {
        formatted(
            .dateTime
                .month(.defaultDigits)
                .locale(locale)
        )
    }

    func ledgerDateText(showTime: Bool) -> String {
        ledgerDateText(showTime: showTime, locale: L10n.locale)
    }

    func ledgerDateText(showTime: Bool, locale: Locale) -> String {
        let calendar = Calendar.current
        if showTime, calendar.isDateInToday(self) {
            let timeText = formatted(
                .dateTime
                    .hour(.twoDigits(amPM: .omitted))
                    .minute(.twoDigits)
                    .locale(locale)
            )
            return L10n.string("date.todayWithTime", locale: locale, timeText)
        }
        if calendar.isDateInYesterday(self) {
            return L10n.string("昨天", locale: locale)
        }

        return formatted(
            .dateTime
                .month(.defaultDigits)
                .day()
                .locale(locale)
        )
    }

    var ledgerDateText: String {
        ledgerDateText(showTime: true)
    }

    var depositDateText: String {
        depositDateText(in: L10n.locale)
    }

    func depositDateText(in locale: Locale) -> String {
        formatted(
            .dateTime
                .month(.defaultDigits)
                .day()
                .locale(locale)
        )
    }
}

extension DateInterval {
    func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

extension Double {
    func currencyText(code: String, fractionDigits: Int = 0) -> String {
        currencyText(code: code, fractionDigits: fractionDigits, locale: L10n.locale)
    }

    func currencyText(code: String, fractionDigits: Int = 0, locale: Locale) -> String {
        formatted(
            .currency(code: code)
                .locale(locale)
                .precision(.fractionLength(fractionDigits))
        )
    }

    func signedCurrencyText(code: String, fractionDigits: Int = 0) -> String {
        signedCurrencyText(code: code, fractionDigits: fractionDigits, locale: L10n.locale)
    }

    func signedCurrencyText(code: String, fractionDigits: Int = 0, locale: Locale) -> String {
        let sign = self >= 0 ? "+" : "-"
        return "\(sign)\(abs(self).currencyText(code: code, fractionDigits: fractionDigits, locale: locale))"
    }

    var cnyText: String {
        currencyText(code: "CNY", fractionDigits: 0)
    }

    func cnyText(in locale: Locale) -> String {
        currencyText(code: "CNY", fractionDigits: 0, locale: locale)
    }

    var signedCNYText: String {
        signedCurrencyText(code: "CNY", fractionDigits: 0)
    }

    func signedCNYText(in locale: Locale) -> String {
        signedCurrencyText(code: "CNY", fractionDigits: 0, locale: locale)
    }
}
