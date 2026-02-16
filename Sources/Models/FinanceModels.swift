import Foundation
import SwiftUI

enum FlowType: String, CaseIterable, Identifiable {
    case expense = "支出"
    case income = "收入"

    var id: String { rawValue }

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

struct CategoryItem: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let color: Color
}

struct TransactionItem: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let color: Color
    let dateText: String
    let amount: Double
    let flow: FlowType
}

struct MonthlyCashflow: Identifiable {
    let id = UUID()
    let month: String
    let expense: Double
    let income: Double
}

struct CategoryStat: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let color: Color
    let amount: Double
}

struct SavingsGoal: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let current: Double
    let target: Double
    let deadline: String
    let tint: Color

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }
}

struct VaultRecord: Identifiable {
    let id = UUID()
    let date: String
    let amount: Double
    let note: String
}

enum PreviewData {
    static let expenseCategories: [CategoryItem] = [
        .init(name: "餐饮", symbol: "fork.knife", color: .sw(0xF87171)),
        .init(name: "咖啡", symbol: "cup.and.saucer.fill", color: .sw(0xFB923C)),
        .init(name: "买菜", symbol: "cart.fill", color: .sw(0x34D399)),
        .init(name: "超市", symbol: "basket.fill", color: .sw(0xA78BFA)),
        .init(name: "服饰", symbol: "tshirt.fill", color: .sw(0xF472B6)),
        .init(name: "住房", symbol: "house.fill", color: .sw(0x60A5FA)),
        .init(name: "水电", symbol: "bolt.fill", color: .sw(0xFACC15)),
        .init(name: "通讯", symbol: "wifi", color: .sw(0x22D3EE)),
        .init(name: "交通", symbol: "car.fill", color: .sw(0x818CF8)),
        .init(name: "公交", symbol: "bus.fill", color: .sw(0x2DD4BF)),
        .init(name: "加油", symbol: "fuelpump.fill", color: .sw(0xFB7185)),
        .init(name: "旅行", symbol: "airplane", color: .sw(0x38BDF8)),
        .init(name: "电影", symbol: "film.fill", color: .sw(0xC084FC)),
        .init(name: "游戏", symbol: "gamecontroller.fill", color: .sw(0xA3E635)),
        .init(name: "阅读", symbol: "book.fill", color: .sw(0xF59E0B)),
        .init(name: "医疗", symbol: "stethoscope", color: .sw(0x10B981)),
        .init(name: "保险", symbol: "shield.fill", color: .sw(0x0EA5E9)),
        .init(name: "宠物", symbol: "pawprint.fill", color: .sw(0xF97316)),
        .init(name: "礼物", symbol: "gift.fill", color: .sw(0xE879F9)),
        .init(name: "健身", symbol: "dumbbell.fill", color: .sw(0x84CC16)),
        .init(name: "数码", symbol: "laptopcomputer", color: .sw(0x06B6D4)),
        .init(name: "摄影", symbol: "camera.fill", color: .sw(0x3B82F6)),
        .init(name: "音乐", symbol: "music.note", color: .sw(0xEC4899)),
        .init(name: "教育", symbol: "graduationcap.fill", color: .sw(0x14B8A6))
    ]

    static let incomeCategories: [CategoryItem] = [
        .init(name: "工资", symbol: "banknote.fill", color: .sw(0x34D399)),
        .init(name: "奖金", symbol: "star.circle.fill", color: .sw(0xFBBF24)),
        .init(name: "兼职", symbol: "briefcase.fill", color: .sw(0x60A5FA)),
        .init(name: "副业", symbol: "laptopcomputer", color: .sw(0x22D3EE)),
        .init(name: "理财", symbol: "chart.line.uptrend.xyaxis", color: .sw(0xA78BFA)),
        .init(name: "股票", symbol: "building.columns.fill", color: .sw(0x818CF8)),
        .init(name: "基金", symbol: "chart.pie.fill", color: .sw(0x4ADE80)),
        .init(name: "红包", symbol: "gift.fill", color: .sw(0xFB7185)),
        .init(name: "退款", symbol: "arrow.uturn.backward.circle.fill", color: .sw(0x38BDF8)),
        .init(name: "报销", symbol: "doc.text.fill", color: .sw(0xF59E0B)),
        .init(name: "租金", symbol: "house.fill", color: .sw(0x2DD4BF)),
        .init(name: "二手", symbol: "repeat.circle.fill", color: .sw(0xF472B6)),
        .init(name: "创作", symbol: "paintbrush.fill", color: .sw(0xE879F9)),
        .init(name: "咨询", symbol: "person.crop.circle.badge.checkmark", color: .sw(0x84CC16)),
        .init(name: "提成", symbol: "chart.bar.fill", color: .sw(0x06B6D4)),
        .init(name: "稿费", symbol: "signature", color: .sw(0xA3E635)),
        .init(name: "销售", symbol: "cart.badge.plus", color: .sw(0x14B8A6)),
        .init(name: "利息", symbol: "percent", color: .sw(0x10B981)),
        .init(name: "分红", symbol: "sparkles", color: .sw(0x67E8F9)),
        .init(name: "奖学金", symbol: "graduationcap.fill", color: .sw(0x93C5FD)),
        .init(name: "津贴", symbol: "wallet.pass.fill", color: .sw(0xFB923C)),
        .init(name: "物流", symbol: "shippingbox.fill", color: .sw(0xD946EF)),
        .init(name: "差旅补贴", symbol: "suitcase.fill", color: .sw(0x0EA5E9)),
        .init(name: "现金存入", symbol: "creditcard.fill", color: .sw(0x16A34A))
    ]

    static let recentExpenses: [TransactionItem] = [
        .init(title: "午餐简餐", symbol: "fork.knife", color: .sw(0xF87171), dateText: "今天 12:40", amount: 48, flow: .expense),
        .init(title: "地铁通勤", symbol: "tram.fill", color: .sw(0x22D3EE), dateText: "今天 09:10", amount: 6, flow: .expense),
        .init(title: "咖啡", symbol: "cup.and.saucer.fill", color: .sw(0xFB923C), dateText: "昨天", amount: 26, flow: .expense),
        .init(title: "家庭买菜", symbol: "cart.fill", color: .sw(0x34D399), dateText: "昨天", amount: 128, flow: .expense),
        .init(title: "健身月卡", symbol: "dumbbell.fill", color: .sw(0x84CC16), dateText: "2月10日", amount: 299, flow: .expense),
        .init(title: "电影", symbol: "film.fill", color: .sw(0xC084FC), dateText: "2月9日", amount: 59, flow: .expense),
        .init(title: "宠物洗护", symbol: "pawprint.fill", color: .sw(0xF97316), dateText: "2月8日", amount: 120, flow: .expense),
        .init(title: "手机配件", symbol: "laptopcomputer", color: .sw(0x06B6D4), dateText: "2月7日", amount: 189, flow: .expense)
    ]

    static let recentIncomes: [TransactionItem] = [
        .init(title: "月度工资", symbol: "banknote.fill", color: .sw(0x34D399), dateText: "2月15日", amount: 9800, flow: .income),
        .init(title: "项目奖金", symbol: "star.circle.fill", color: .sw(0xFBBF24), dateText: "2月14日", amount: 2200, flow: .income),
        .init(title: "副业设计稿", symbol: "paintbrush.fill", color: .sw(0xE879F9), dateText: "2月12日", amount: 860, flow: .income),
        .init(title: "报销到账", symbol: "doc.text.fill", color: .sw(0xF59E0B), dateText: "2月11日", amount: 320, flow: .income),
        .init(title: "基金分红", symbol: "sparkles", color: .sw(0x67E8F9), dateText: "2月9日", amount: 280, flow: .income),
        .init(title: "退款", symbol: "arrow.uturn.backward.circle.fill", color: .sw(0x38BDF8), dateText: "2月8日", amount: 139, flow: .income),
        .init(title: "租金收入", symbol: "house.fill", color: .sw(0x2DD4BF), dateText: "2月5日", amount: 3500, flow: .income),
        .init(title: "利息", symbol: "percent", color: .sw(0x10B981), dateText: "2月1日", amount: 112, flow: .income)
    ]

    static let monthlyCashflow: [MonthlyCashflow] = [
        .init(month: "9月", expense: 4860, income: 7600),
        .init(month: "10月", expense: 5120, income: 7900),
        .init(month: "11月", expense: 4650, income: 8050),
        .init(month: "12月", expense: 5380, income: 8820),
        .init(month: "1月", expense: 5020, income: 8300),
        .init(month: "2月", expense: 4280, income: 9150)
    ]

    static let expenseStats: [CategoryStat] = [
        .init(name: "餐饮", symbol: "fork.knife", color: .sw(0xF87171), amount: 1180),
        .init(name: "交通", symbol: "car.fill", color: .sw(0x818CF8), amount: 720),
        .init(name: "住房", symbol: "house.fill", color: .sw(0x60A5FA), amount: 1460),
        .init(name: "购物", symbol: "bag.fill", color: .sw(0xF472B6), amount: 980),
        .init(name: "娱乐", symbol: "gamecontroller.fill", color: .sw(0xA3E635), amount: 460),
        .init(name: "医疗", symbol: "stethoscope", color: .sw(0x10B981), amount: 390)
    ]

    static let incomeStats: [CategoryStat] = [
        .init(name: "工资", symbol: "banknote.fill", color: .sw(0x34D399), amount: 9800),
        .init(name: "奖金", symbol: "star.circle.fill", color: .sw(0xFBBF24), amount: 2200),
        .init(name: "租金", symbol: "house.fill", color: .sw(0x2DD4BF), amount: 3500),
        .init(name: "副业", symbol: "laptopcomputer", color: .sw(0x22D3EE), amount: 1480),
        .init(name: "理财", symbol: "chart.line.uptrend.xyaxis", color: .sw(0xA78BFA), amount: 980),
        .init(name: "退款报销", symbol: "arrow.uturn.backward.circle.fill", color: .sw(0x38BDF8), amount: 459)
    ]

    static let savingsGoals: [SavingsGoal] = [
        .init(name: "欧洲旅行", symbol: "airplane", current: 8200, target: 20000, deadline: "2026-09", tint: .sw(0x38BDF8)),
        .init(name: "新手机", symbol: "iphone", current: 3200, target: 8000, deadline: "2026-06", tint: .sw(0xA78BFA)),
        .init(name: "应急金", symbol: "shield.fill", current: 15000, target: 30000, deadline: "长期", tint: .sw(0x34D399)),
        .init(name: "学习基金", symbol: "graduationcap.fill", current: 4600, target: 12000, deadline: "2026-12", tint: .sw(0xF59E0B))
    ]

    static let vaultRecords: [VaultRecord] = [
        .init(date: "2月15日", amount: 300, note: "工资日固定转入"),
        .init(date: "2月12日", amount: 120, note: "副业收入转入"),
        .init(date: "2月9日", amount: 80, note: "减少外卖奖励"),
        .init(date: "2月6日", amount: 150, note: "退款到账转入")
    ]
}

extension Double {
    var cnyText: String {
        self.formatted(
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
