import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    @Query(sort: [SortDescriptor(\LedgerEntry.createdAt, order: .reverse)]) private var entries: [LedgerEntry]
    @State private var selectedFlow: FlowType = .expense

    private var totalExpense: Double {
        entries
            .filter { $0.flow == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private var totalIncome: Double {
        entries
            .filter { $0.flow == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var netBalance: Double {
        totalIncome - totalExpense
    }

    private var savingRate: Double {
        guard totalIncome > 0 else { return 0 }
        return netBalance / totalIncome
    }

    private var monthlyRows: [MonthlyCashflow] {
        let calendar = Calendar.current
        let currentMonthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: .now)
        ) ?? .now

        let monthStarts: [Date] = (0..<6).compactMap { offset in
            calendar.date(byAdding: .month, value: offset - 5, to: currentMonthStart)
        }

        return monthStarts.map { monthStart in
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            let monthEntries = entries.filter { $0.createdAt >= monthStart && $0.createdAt < monthEnd }

            let expense = monthEntries
                .filter { $0.flow == .expense }
                .reduce(0) { $0 + $1.amount }

            let income = monthEntries
                .filter { $0.flow == .income }
                .reduce(0) { $0 + $1.amount }

            return MonthlyCashflow(
                monthStart: monthStart,
                monthLabel: monthStart.monthLabel,
                expense: expense,
                income: income
            )
        }
    }

    private var selectedStats: [CategoryStat] {
        let filtered = entries.filter { $0.flow == selectedFlow }
        let grouped = Dictionary(grouping: filtered) {
            "\($0.categoryName)|\($0.categorySymbol)|\($0.categoryColorHex)"
        }

        let stats = grouped.compactMap { key, values -> CategoryStat? in
            guard let first = values.first else { return nil }
            let total = values.reduce(0) { $0 + $1.amount }
            return CategoryStat(
                key: key,
                name: first.categoryName,
                symbol: first.categorySymbol,
                colorHex: first.categoryColorHex,
                amount: total
            )
        }

        return stats
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
            .prefix(6)
            .map { $0 }
    }

    private var selectedTotal: Double {
        selectedStats.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                overviewCard
                monthlyChartCard
                distributionCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .navigationTitle("统计")
        .navigationBarTitleDisplayMode(.large)
        .appBackground()
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "收支概览", subtitle: "实时汇总（基于本地账本）")

            HStack(spacing: 12) {
                StatMetric(title: "总收入", valueText: totalIncome.cnyText, tint: SWTheme.accentGreen)
                StatMetric(title: "总支出", valueText: totalExpense.cnyText, tint: SWTheme.accentOrange)
            }

            HStack(spacing: 12) {
                StatMetric(title: "净结余", valueText: netBalance.signedCNYText, tint: SWTheme.accentBlue)
                StatMetric(
                    title: "储蓄率",
                    valueText: "\((savingRate * 100).formatted(.number.precision(.fractionLength(1))))%",
                    tint: SWTheme.accentPink
                )
            }
        }
        .fitnessCard()
    }

    private var monthlyChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "月度趋势", subtitle: "最近 6 个月收入与支出对比")

            if monthlyRows.allSatisfy({ $0.expense == 0 && $0.income == 0 }) {
                EmptyStateCard(
                    title: "暂无可统计数据",
                    subtitle: "先去支出/收入页面添加账单",
                    symbol: "chart.bar.xaxis"
                )
            } else {
                Chart {
                    ForEach(monthlyRows) { row in
                        BarMark(
                            x: .value("月份", row.monthLabel),
                            y: .value("金额", row.expense)
                        )
                        .position(by: .value("类型", "支出"))
                        .foregroundStyle(by: .value("类型", "支出"))

                        BarMark(
                            x: .value("月份", row.monthLabel),
                            y: .value("金额", row.income)
                        )
                        .position(by: .value("类型", "收入"))
                        .foregroundStyle(by: .value("类型", "收入"))
                    }
                }
                .chartForegroundStyleScale([
                    "支出": SWTheme.accentOrange,
                    "收入": SWTheme.accentGreen
                ])
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(Color.white.opacity(0.12))
                        AxisValueLabel()
                            .foregroundStyle(SWTheme.textSecondary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(SWTheme.textSecondary)
                    }
                }
                .frame(height: 230)
            }
        }
        .fitnessCard()
    }

    private var distributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "分类占比", subtitle: "图标 + 圆环分布")

            Picker("类型", selection: $selectedFlow) {
                ForEach(FlowType.allCases) { flow in
                    Text(flow.rawValue).tag(flow)
                }
            }
            .pickerStyle(.segmented)

            if selectedStats.isEmpty {
                EmptyStateCard(
                    title: "暂无\(selectedFlow.rawValue)分类数据",
                    subtitle: "新增账单后自动更新",
                    symbol: selectedFlow == .expense ? "minus.circle" : "plus.circle"
                )
            } else {
                ZStack {
                    Chart(selectedStats) { item in
                        SectorMark(
                            angle: .value("金额", item.amount),
                            innerRadius: .ratio(0.58),
                            angularInset: 2
                        )
                        .foregroundStyle(item.color.gradient)
                    }
                    .frame(height: 250)

                    VStack(spacing: 6) {
                        Text(selectedFlow.rawValue)
                            .font(.caption)
                            .foregroundStyle(SWTheme.textSecondary)
                        Text(selectedTotal.cnyText)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedFlow)

                VStack(spacing: 10) {
                    ForEach(selectedStats) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(item.color)
                                .frame(width: 20)
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(item.amount.cnyText)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .fitnessCard()
    }
}

private struct StatMetric: View {
    let title: String
    let valueText: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(SWTheme.textSecondary)
            Text(valueText)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.42), lineWidth: 1)
                )
        )
    }
}
