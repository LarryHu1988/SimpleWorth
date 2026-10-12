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
    var sortOrder: Int = 0

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = TagEmojiLibrary.defaultEmoji,
        tintHex: Int = TagEmojiLibrary.defaultTintHex,
        createdAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.emoji = TagEmojiLibrary.normalized(emoji)
        self.tintHex = tintHex
        self.createdAt = createdAt
        self.sortOrder = sortOrder
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

enum TagOrdering {
    static func sorted(_ tags: [TagRecord]) -> [TagRecord] {
        tags.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    static func visible(_ tags: [TagRecord]) -> [TagRecord] {
        var seen = Set<String>()
        return sorted(tags).filter {
            let name = $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return !name.isEmpty && seen.insert(name.lowercased()).inserted
        }
    }

    static func nextOrder(in tags: [TagRecord]) -> Int {
        (tags.map(\.sortOrder).max() ?? -1) + 1
    }

    static func move(_ tags: [TagRecord], from offsets: IndexSet, to destination: Int, context: ModelContext) throws {
        var reordered = visible(tags)
        guard !offsets.isEmpty, offsets.allSatisfy({ reordered.indices.contains($0) }),
              (0...reordered.count).contains(destination) else { return }
        reordered.move(fromOffsets: offsets, toOffset: destination)
        let visibleIDs = Set(reordered.map(\.id))
        reordered += sorted(tags).filter { !visibleIDs.contains($0.id) }
        let previous = reordered.map(\.sortOrder)
        for (index, tag) in reordered.enumerated() { tag.sortOrder = index }
        do {
            try context.save()
        } catch {
            for (index, tag) in reordered.enumerated() { tag.sortOrder = previous[index] }
            throw error
        }
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
        .init(flow: .expense, name: "饮品", symbol: "waterbottle.fill", colorHex: 0x2DD4BF),
        .init(flow: .expense, name: "水果", symbol: "leaf.fill", colorHex: 0x84CC16),
        .init(flow: .expense, name: "买菜", symbol: "cart.fill", colorHex: 0x34D399),
        .init(flow: .expense, name: "超市", symbol: "basket.fill", colorHex: 0xA78BFA),
        .init(flow: .expense, name: "日用品", symbol: "bag.fill", colorHex: 0x38BDF8),
        .init(flow: .expense, name: "快递", symbol: "shippingbox.fill", colorHex: 0x60A5FA),
        .init(flow: .expense, name: "服饰", symbol: "tshirt.fill", colorHex: 0xF472B6),
        .init(flow: .expense, name: "鞋靴", symbol: "shoe.fill", colorHex: 0xF59E0B),
        .init(flow: .expense, name: "箱包", symbol: "bag.fill", colorHex: 0xC084FC),
        .init(flow: .expense, name: "配饰珠宝", symbol: "crown.fill", colorHex: 0xE4B84A),
        .init(flow: .expense, name: "洗衣清洁", symbol: "washer.fill", colorHex: 0x53C4D1),
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
        .init(flow: .expense, name: "家居家纺", symbol: "bed.double.fill", colorHex: 0x67C587),
        .init(flow: .expense, name: "装修建材", symbol: "paintbrush.fill", colorHex: 0xF59E0B),
        .init(flow: .expense, name: "交通", symbol: "car.fill", colorHex: 0x818CF8),
        .init(flow: .expense, name: "打车", symbol: "location.fill", colorHex: 0x6366F1),
        .init(flow: .expense, name: "公交", symbol: "bus.fill", colorHex: 0x2DD4BF),
        .init(flow: .expense, name: "加油", symbol: "fuelpump.fill", colorHex: 0xFB7185),
        .init(flow: .expense, name: "车辆充电", symbol: "bolt.car.fill", colorHex: 0x34D399),
        .init(flow: .expense, name: "通行费", symbol: "road.lanes", colorHex: 0x64748B),
        .init(flow: .expense, name: "停车", symbol: "parkingsign.circle.fill", colorHex: 0x0EA5E9),
        .init(flow: .expense, name: "车辆保养", symbol: "wrench.fill", colorHex: 0x64748B),
        .init(flow: .expense, name: "车辆购置", symbol: "car.side.fill", colorHex: 0x3B82F6),
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
        .init(flow: .expense, name: "体检保健", symbol: "heart.text.clipboard.fill", colorHex: 0x67C587),
        .init(flow: .expense, name: "保险", symbol: "shield.fill", colorHex: 0x0EA5E9),
        .init(flow: .expense, name: "宠物", symbol: "pawprint.fill", colorHex: 0xF97316),
        .init(flow: .expense, name: "礼物", symbol: "gift.fill", colorHex: 0xE879F9),
        .init(flow: .expense, name: "人情红包", symbol: "envelope.fill", colorHex: 0xF06A6A),
        .init(flow: .expense, name: "赡养", symbol: "person.2.fill", colorHex: 0xE4B84A),
        .init(flow: .expense, name: "公益捐赠", symbol: "heart.fill", colorHex: 0xE27AB0),
        .init(flow: .expense, name: "社交", symbol: "person.2.fill", colorHex: 0xEC4899),
        .init(flow: .expense, name: "健身", symbol: "figure.run", colorHex: 0x84CC16),
        .init(flow: .expense, name: "运动户外", symbol: "figure.hiking", colorHex: 0x22C55E),
        .init(flow: .expense, name: "数码", symbol: "laptopcomputer", colorHex: 0x06B6D4),
        .init(flow: .expense, name: "数码配件", symbol: "headphones", colorHex: 0x53C4D1),
        .init(flow: .expense, name: "软件应用", symbol: "app.badge.fill", colorHex: 0x5B8DEF),
        .init(flow: .expense, name: "摄影", symbol: "camera.fill", colorHex: 0x3B82F6),
        .init(flow: .expense, name: "音乐", symbol: "music.note", colorHex: 0xEC4899),
        .init(flow: .expense, name: "教育", symbol: "graduationcap.fill", colorHex: 0x14B8A6),
        .init(flow: .expense, name: "办公", symbol: "briefcase.fill", colorHex: 0x64748B),
        .init(flow: .expense, name: "育儿", symbol: "figure.2.and.child.holdinghands", colorHex: 0xF59E0B),
        .init(flow: .expense, name: "税费", symbol: "doc.text.fill", colorHex: 0xEF4444),
        .init(flow: .expense, name: "手续费", symbol: "creditcard.fill", colorHex: 0x94A3B8),
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
        .init(flow: .income, name: "服务收入", symbol: "person.crop.circle.badge.checkmark", colorHex: 0x53C4D1),
        .init(flow: .income, name: "创作", symbol: "paintbrush.fill", colorHex: 0xE879F9),
        .init(flow: .income, name: "稿费", symbol: "signature", colorHex: 0xA3E635),
        .init(flow: .income, name: "咨询", symbol: "person.crop.circle.badge.checkmark", colorHex: 0x84CC16),
        .init(flow: .income, name: "红包", symbol: "gift.fill", colorHex: 0xFB7185),
        .init(flow: .income, name: "礼金", symbol: "envelope.fill", colorHex: 0xE27AB0),
        .init(flow: .income, name: "养老金", symbol: "person.fill", colorHex: 0x67C587),
        .init(flow: .income, name: "退税", symbol: "doc.text.fill", colorHex: 0xF59E0B),
        .init(flow: .income, name: "赔偿", symbol: "shield.fill", colorHex: 0x5B8DEF),
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

    private static let searchKeywords: [String: String] = [
        "餐饮": "吃饭 吃飯 早餐 午餐 晚餐 dining meal restaurant 食事 レストラン",
        "服饰": "衣服 服裝 服装 衬衫 襯衫 裤子 褲子 外套 clothing shirt pants coat 衣類 シャツ",
        "鞋靴": "买鞋 買鞋 运动鞋 運動鞋 球鞋 皮鞋 凉鞋 涼鞋 拖鞋 靴子 shoes sneakers boots sandals 靴 スニーカー",
        "箱包": "背包 手提包 旅行箱 行李箱 bags backpack luggage suitcase バッグ リュック",
        "配饰珠宝": "首饰 首飾 项链 項鏈 戒指 手表 手錶 眼镜 眼鏡 jewelry accessories watch glasses アクセサリー 眼鏡",
        "饮品": "奶茶 果汁 饮料 飲料 矿泉水 礦泉水 drinks tea juice water 飲料 ジュース",
        "水果": "苹果 蘋果 香蕉 橙子 草莓 fruits apple banana 果物 フルーツ",
        "日用品": "纸巾 紙巾 牙膏 洗发水 洗髮水 household essentials tissues toothpaste 日用品",
        "家居家纺": "床单 床單 被子 枕头 枕頭 窗帘 窗簾 bedding linens pillow curtains 寝具 カーテン",
        "装修建材": "装修 裝修 建材 油漆 地板 renovation paint flooring リフォーム 建材",
        "洗衣清洁": "洗衣 洗鞋 干洗 乾洗 清洁 清潔 laundry dry cleaning クリーニング 洗濯",
        "车辆充电": "电车 電車 充电 充電 ev charging 電気自動車 充電",
        "通行费": "过路费 過路費 高速 路桥 路橋 toll highway 通行料金 高速道路",
        "车辆购置": "买车 買車 汽车 汽車 自行车 自行車 电动车 電動車 vehicle bicycle car purchase 車購入 自転車",
        "体检保健": "体检 體檢 保健 营养 營養 health checkup supplements 健康診断 サプリ",
        "运动户外": "露营 露營 户外 戶外 体育 體育 球拍 健身器材 sports camping outdoor アウトドア スポーツ",
        "数码": "手机 手機 电脑 電腦 平板 phone computer tablet スマホ パソコン",
        "数码配件": "耳机 耳機 充电器 充電器 数据线 數據線 键盘 鍵盤 headphones charger cable keyboard イヤホン 充電器",
        "软件应用": "软件 軟體 应用 應用 app software license ソフト アプリ",
        "教育": "学费 學費 培训 培訓 课程 課程 tuition course training 学費 講座",
        "育儿": "奶粉 尿布 玩具 育兒 baby diapers toys 育児 おもちゃ",
        "人情红包": "婚礼 婚禮 随礼 隨禮 红包 紅包 礼金 禮金 wedding cash gifts ご祝儀 贈答",
        "赡养": "赡养 贍養 父母 老人 家庭支持 parents family support 親 扶養",
        "公益捐赠": "捐款 捐贈 慈善 donation charity 寄付",
        "手续费": "银行 銀行 服务费 服務費 fees commission 手数料",
        "二手": "卖鞋 賣鞋 卖衣服 賣衣服 闲置 閒置 出售 resale secondhand used 二手 中古 フリマ",
        "销售": "卖东西 賣東西 商品 店铺 店鋪 生意 sales goods shop business 売上 販売",
        "服务收入": "服务 服務 接单 接單 劳务 勞務 service freelance labor サービス 報酬",
        "礼金": "赠与 贈與 结婚 結婚 gifts wedding gift money ご祝儀 贈与",
        "养老金": "退休 退休金 pension retirement 年金",
        "退税": "税款 稅款 tax refund 還付金",
        "赔偿": "理赔 理賠 賠償 compensation insurance claim 補償 保険金"
    ]

    static func filtered(_ categories: [CategoryItem], matching query: String, locale: Locale) -> [CategoryItem] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return categories }
        return categories.filter {
            let text = "\($0.name) \($0.localizedName(in: locale)) \(searchKeywords[$0.name] ?? "")"
            return text.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive], locale: locale) != nil
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
