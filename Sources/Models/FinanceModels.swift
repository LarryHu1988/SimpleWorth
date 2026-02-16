import Foundation
import SwiftData
import SwiftUI

enum FlowType: String, CaseIterable, Identifiable, Codable {
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

    var accent: Color {
        switch self {
        case .expense: SWTheme.accentOrange
        case .income: SWTheme.accentGreen
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

    var id: String { key }

    var color: Color {
        Color.sw(UInt(colorHex))
    }
}

@Model
final class LedgerEntry {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var amount: Double
    var note: String
    var flowRaw: String
    var categoryName: String
    var categorySymbol: String
    var categoryColorHex: Int

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        amount: Double,
        note: String,
        flow: FlowType,
        category: CategoryItem
    ) {
        self.id = id
        self.createdAt = createdAt
        self.amount = amount
        self.note = note
        self.flowRaw = flow.storageValue
        self.categoryName = category.name
        self.categorySymbol = category.symbol
        self.categoryColorHex = category.colorHex
    }

    var flow: FlowType {
        get { FlowType(storageValue: flowRaw) }
        set { flowRaw = newValue.storageValue }
    }

    var categoryColor: Color {
        Color.sw(UInt(categoryColorHex))
    }
}

@Model
final class SavingsGoalRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var name: String
    var symbol: String
    var currentAmount: Double
    var targetAmount: Double
    var deadline: Date?
    var tintHex: Int
    @Relationship(deleteRule: .cascade, inverse: \VaultDepositRecord.goal) var deposits: [VaultDepositRecord]

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
        guard let deadline else { return "长期" }
        return deadline.formatted(
            .dateTime
                .year()
                .month(.defaultDigits)
                .locale(Locale(identifier: "zh_CN"))
        )
    }
}

@Model
final class VaultDepositRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var amount: Double
    var note: String
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
    static let expenseCategories: [CategoryItem] = [
        .init(flow: .expense, name: "餐饮", symbol: "fork.knife", colorHex: 0xF87171),
        .init(flow: .expense, name: "咖啡", symbol: "cup.and.saucer.fill", colorHex: 0xFB923C),
        .init(flow: .expense, name: "买菜", symbol: "cart.fill", colorHex: 0x34D399),
        .init(flow: .expense, name: "超市", symbol: "basket.fill", colorHex: 0xA78BFA),
        .init(flow: .expense, name: "服饰", symbol: "tshirt.fill", colorHex: 0xF472B6),
        .init(flow: .expense, name: "住房", symbol: "house.fill", colorHex: 0x60A5FA),
        .init(flow: .expense, name: "水电", symbol: "bolt.fill", colorHex: 0xFACC15),
        .init(flow: .expense, name: "通讯", symbol: "wifi", colorHex: 0x22D3EE),
        .init(flow: .expense, name: "交通", symbol: "car.fill", colorHex: 0x818CF8),
        .init(flow: .expense, name: "公交", symbol: "bus.fill", colorHex: 0x2DD4BF),
        .init(flow: .expense, name: "加油", symbol: "fuelpump.fill", colorHex: 0xFB7185),
        .init(flow: .expense, name: "旅行", symbol: "airplane", colorHex: 0x38BDF8),
        .init(flow: .expense, name: "电影", symbol: "film.fill", colorHex: 0xC084FC),
        .init(flow: .expense, name: "游戏", symbol: "gamecontroller.fill", colorHex: 0xA3E635),
        .init(flow: .expense, name: "阅读", symbol: "book.fill", colorHex: 0xF59E0B),
        .init(flow: .expense, name: "医疗", symbol: "stethoscope", colorHex: 0x10B981),
        .init(flow: .expense, name: "保险", symbol: "shield.fill", colorHex: 0x0EA5E9),
        .init(flow: .expense, name: "宠物", symbol: "pawprint.fill", colorHex: 0xF97316),
        .init(flow: .expense, name: "礼物", symbol: "gift.fill", colorHex: 0xE879F9),
        .init(flow: .expense, name: "健身", symbol: "figure.run", colorHex: 0x84CC16),
        .init(flow: .expense, name: "数码", symbol: "laptopcomputer", colorHex: 0x06B6D4),
        .init(flow: .expense, name: "摄影", symbol: "camera.fill", colorHex: 0x3B82F6),
        .init(flow: .expense, name: "音乐", symbol: "music.note", colorHex: 0xEC4899),
        .init(flow: .expense, name: "教育", symbol: "graduationcap.fill", colorHex: 0x14B8A6)
    ]

    static let incomeCategories: [CategoryItem] = [
        .init(flow: .income, name: "工资", symbol: "banknote.fill", colorHex: 0x34D399),
        .init(flow: .income, name: "奖金", symbol: "star.circle.fill", colorHex: 0xFBBF24),
        .init(flow: .income, name: "兼职", symbol: "briefcase.fill", colorHex: 0x60A5FA),
        .init(flow: .income, name: "副业", symbol: "laptopcomputer", colorHex: 0x22D3EE),
        .init(flow: .income, name: "理财", symbol: "chart.line.uptrend.xyaxis", colorHex: 0xA78BFA),
        .init(flow: .income, name: "股票", symbol: "building.columns.fill", colorHex: 0x818CF8),
        .init(flow: .income, name: "基金", symbol: "chart.pie.fill", colorHex: 0x4ADE80),
        .init(flow: .income, name: "红包", symbol: "gift.fill", colorHex: 0xFB7185),
        .init(flow: .income, name: "退款", symbol: "arrow.uturn.backward.circle.fill", colorHex: 0x38BDF8),
        .init(flow: .income, name: "报销", symbol: "doc.text.fill", colorHex: 0xF59E0B),
        .init(flow: .income, name: "租金", symbol: "house.fill", colorHex: 0x2DD4BF),
        .init(flow: .income, name: "二手", symbol: "repeat.circle.fill", colorHex: 0xF472B6),
        .init(flow: .income, name: "创作", symbol: "paintbrush.fill", colorHex: 0xE879F9),
        .init(flow: .income, name: "咨询", symbol: "person.crop.circle.badge.checkmark", colorHex: 0x84CC16),
        .init(flow: .income, name: "提成", symbol: "chart.bar.fill", colorHex: 0x06B6D4),
        .init(flow: .income, name: "稿费", symbol: "signature", colorHex: 0xA3E635),
        .init(flow: .income, name: "销售", symbol: "cart.badge.plus", colorHex: 0x14B8A6),
        .init(flow: .income, name: "利息", symbol: "percent", colorHex: 0x10B981),
        .init(flow: .income, name: "分红", symbol: "sparkles", colorHex: 0x67E8F9),
        .init(flow: .income, name: "奖学金", symbol: "graduationcap.fill", colorHex: 0x93C5FD),
        .init(flow: .income, name: "津贴", symbol: "wallet.pass.fill", colorHex: 0xFB923C),
        .init(flow: .income, name: "物流", symbol: "shippingbox.fill", colorHex: 0xD946EF),
        .init(flow: .income, name: "差旅补贴", symbol: "suitcase.fill", colorHex: 0x0EA5E9),
        .init(flow: .income, name: "现金存入", symbol: "creditcard.fill", colorHex: 0x16A34A)
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
        categories(for: flow).first { $0.name == name }
    }
}

enum SeedService {
    private static let seedKey = "simpleworth.seed.v0.1.0"

    static func seedIfNeeded(context: ModelContext) {
        if UserDefaults.standard.bool(forKey: seedKey) {
            return
        }

        let hasEntries = (try? context.fetchCount(FetchDescriptor<LedgerEntry>())) ?? 0
        if hasEntries > 0 {
            UserDefaults.standard.set(true, forKey: seedKey)
            return
        }

        seedLedgerEntries(context: context)
        seedGoalsAndDeposits(context: context)

        try? context.save()
        UserDefaults.standard.set(true, forKey: seedKey)
    }

    private static func seedLedgerEntries(context: ModelContext) {
        struct SeedEntry {
            let note: String
            let flow: FlowType
            let category: String
            let amount: Double
            let daysAgo: Int
        }

        let entries: [SeedEntry] = [
            .init(note: "午餐简餐", flow: .expense, category: "餐饮", amount: 48, daysAgo: 0),
            .init(note: "地铁通勤", flow: .expense, category: "交通", amount: 6, daysAgo: 0),
            .init(note: "咖啡", flow: .expense, category: "咖啡", amount: 26, daysAgo: 1),
            .init(note: "家庭买菜", flow: .expense, category: "买菜", amount: 128, daysAgo: 1),
            .init(note: "健身月卡", flow: .expense, category: "健身", amount: 299, daysAgo: 6),
            .init(note: "电影", flow: .expense, category: "电影", amount: 59, daysAgo: 7),
            .init(note: "宠物洗护", flow: .expense, category: "宠物", amount: 120, daysAgo: 8),
            .init(note: "手机配件", flow: .expense, category: "数码", amount: 189, daysAgo: 9),
            .init(note: "房租", flow: .expense, category: "住房", amount: 3200, daysAgo: 33),
            .init(note: "家庭聚餐", flow: .expense, category: "餐饮", amount: 280, daysAgo: 36),
            .init(note: "周末短途", flow: .expense, category: "旅行", amount: 760, daysAgo: 62),

            .init(note: "月度工资", flow: .income, category: "工资", amount: 9800, daysAgo: 1),
            .init(note: "项目奖金", flow: .income, category: "奖金", amount: 2200, daysAgo: 2),
            .init(note: "副业设计稿", flow: .income, category: "创作", amount: 860, daysAgo: 4),
            .init(note: "报销到账", flow: .income, category: "报销", amount: 320, daysAgo: 5),
            .init(note: "基金分红", flow: .income, category: "分红", amount: 280, daysAgo: 7),
            .init(note: "退款", flow: .income, category: "退款", amount: 139, daysAgo: 8),
            .init(note: "租金收入", flow: .income, category: "租金", amount: 3500, daysAgo: 11),
            .init(note: "利息", flow: .income, category: "利息", amount: 112, daysAgo: 15),
            .init(note: "上月工资", flow: .income, category: "工资", amount: 9600, daysAgo: 33),
            .init(note: "兼职收入", flow: .income, category: "兼职", amount: 1180, daysAgo: 47),
            .init(note: "副业结算", flow: .income, category: "副业", amount: 1660, daysAgo: 74)
        ]

        for seed in entries {
            let category = CategoryLibrary.category(named: seed.category, flow: seed.flow)
                ?? CategoryLibrary.defaultCategory(for: seed.flow)

            context.insert(
                LedgerEntry(
                    createdAt: .daysAgo(seed.daysAgo),
                    amount: seed.amount,
                    note: seed.note,
                    flow: seed.flow,
                    category: category
                )
            )
        }
    }

    private static func seedGoalsAndDeposits(context: ModelContext) {
        let travelGoal = SavingsGoalRecord(
            name: "欧洲旅行",
            symbol: "airplane",
            currentAmount: 7900,
            targetAmount: 20000,
            deadline: .date(year: 2026, month: 9, day: 30),
            tintHex: 0x38BDF8
        )
        let phoneGoal = SavingsGoalRecord(
            name: "新手机",
            symbol: "iphone",
            currentAmount: 3080,
            targetAmount: 8000,
            deadline: .date(year: 2026, month: 6, day: 30),
            tintHex: 0xA78BFA
        )
        let emergencyGoal = SavingsGoalRecord(
            name: "应急金",
            symbol: "shield.fill",
            currentAmount: 14850,
            targetAmount: 30000,
            deadline: nil,
            tintHex: 0x34D399
        )
        let learnGoal = SavingsGoalRecord(
            name: "学习基金",
            symbol: "graduationcap.fill",
            currentAmount: 4520,
            targetAmount: 12000,
            deadline: .date(year: 2026, month: 12, day: 31),
            tintHex: 0xF59E0B
        )

        let goals = [travelGoal, phoneGoal, emergencyGoal, learnGoal]
        goals.forEach { context.insert($0) }

        let deposits: [(SavingsGoalRecord, Double, String, Int)] = [
            (travelGoal, 300, "工资日固定转入", 1),
            (phoneGoal, 120, "副业收入转入", 4),
            (learnGoal, 80, "减少外卖奖励", 7),
            (emergencyGoal, 150, "退款到账转入", 10)
        ]

        for (goal, amount, note, daysAgo) in deposits {
            goal.currentAmount += amount
            context.insert(
                VaultDepositRecord(
                    date: .daysAgo(daysAgo),
                    amount: amount,
                    note: note,
                    goal: goal
                )
            )
        }
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
        formatted(
            .dateTime
                .month(.defaultDigits)
                .locale(Locale(identifier: "zh_CN"))
        )
    }

    var ledgerDateText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            let timeText = formatted(
                .dateTime
                    .hour(.twoDigits(amPM: .omitted))
                    .minute(.twoDigits)
                    .locale(Locale(identifier: "zh_CN"))
            )
            return "今天 \(timeText)"
        }
        if calendar.isDateInYesterday(self) {
            return "昨天"
        }

        return formatted(
            .dateTime
                .month(.defaultDigits)
                .day()
                .locale(Locale(identifier: "zh_CN"))
        )
    }

    var depositDateText: String {
        formatted(
            .dateTime
                .month(.defaultDigits)
                .day()
                .locale(Locale(identifier: "zh_CN"))
        )
    }
}

extension Double {
    var cnyText: String {
        formatted(
            .currency(code: "CNY")
                .locale(Locale(identifier: "zh_CN"))
                .precision(.fractionLength(0))
        )
    }

    var signedCNYText: String {
        let sign = self >= 0 ? "+" : "-"
        return "\(sign)\(abs(self).cnyText)"
    }
}
