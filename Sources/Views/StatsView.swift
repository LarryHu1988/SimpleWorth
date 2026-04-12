import Charts
import SwiftData
import SwiftUI

private struct MonthlyTrendRow: Identifiable {
    let month: Int
    let expense: Double
    let income: Double

    var id: Int { month }
}

private enum DistributionMode: String, CaseIterable, Identifiable {
    case category = "分类"
    case tag = "标签"

    var id: String { rawValue }

    var localizedTitle: String {
        rawValue.appLocalized
    }

    func localizedTitle(in locale: Locale) -> String {
        rawValue.appLocalized(in: locale)
    }
}

struct StatsView: View {
    @Environment(\.locale) private var locale
    @EnvironmentObject private var appRuntimeController: AppRuntimeController
    @Query(sort: [SortDescriptor(\LedgerEntry.createdAt, order: .reverse)]) private var entries: [LedgerEntry]
    @Query(sort: [SortDescriptor(\TagRecord.createdAt, order: .forward)]) private var tags: [TagRecord]

    @State private var selectedFlow: FlowType = .expense
    @State private var selectedDistributionMode: DistributionMode = .category
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    @State private var selectedMonth = Calendar.current.component(.month, from: .now)
    @State private var chartScrollStartMonth = max(
        1.0,
        Double(Calendar.current.component(.month, from: .now)) + 0.5 - 5.5
    )
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: .now)
        let years = Set(entries.map { Calendar.current.component(.year, from: $0.createdAt) } + [currentYear])
        return years.sorted(by: >)
    }

    private var selectedMonthEntries: [LedgerEntry] {
        entries.filter {
            let year = Calendar.current.component(.year, from: $0.createdAt)
            let month = Calendar.current.component(.month, from: $0.createdAt)
            return year == selectedYear && month == selectedMonth
        }
    }

    private var totalExpense: Double {
        selectedMonthEntries
            .reduce(0) { $0 + $1.expenseContribution }
    }

    private var totalIncome: Double {
        selectedMonthEntries
            .reduce(0) { $0 + $1.incomeContribution }
    }

    private var tagTintHexByName: [String: Int] {
        var result: [String: Int] = [:]

        for tag in tags {
            let normalizedName = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedName.isEmpty else { continue }
            if result[normalizedName] == nil {
                result[normalizedName] = tag.resolvedTintHex
            }
        }

        return result
    }

    private var netBalance: Double {
        totalIncome - totalExpense
    }

    private var savingRate: Double {
        guard totalIncome > 0 else { return 0 }
        return netBalance / totalIncome
    }

    private var monthlyRows: [MonthlyTrendRow] {
        let monthEntries = entries.filter {
            Calendar.current.component(.year, from: $0.createdAt) == selectedYear
        }

        return (1...12).map { month in
            let rows = monthEntries.filter {
                Calendar.current.component(.month, from: $0.createdAt) == month
            }

            let expense = rows
                .reduce(0) { $0 + $1.expenseContribution }

            let income = rows
                .reduce(0) { $0 + $1.incomeContribution }

            return MonthlyTrendRow(month: month, expense: expense, income: income)
        }
    }

    private var selectedStats: [CategoryStat] {
        let filtered = selectedMonthEntries.filter { $0.flow == selectedFlow }
        let stats: [CategoryStat]

        switch selectedDistributionMode {
        case .category:
            let grouped = Dictionary(grouping: filtered) {
                "\($0.categoryName)|\($0.categorySymbol)|\($0.categoryColorHex)"
            }

            stats = grouped.compactMap { key, values -> CategoryStat? in
                guard let first = values.first else { return nil }
                let total = values.reduce(0) { $0 + $1.amount }
                return CategoryStat(
                    key: key,
                    name: first.categoryName,
                    symbol: first.categorySymbol,
                    colorHex: first.categoryColorHex,
                    amount: total,
                    usesEmoji: false
                )
            }

        case .tag:
            var totals: [String: Double] = [:]

            for entry in filtered {
                let tagNames = entry.tagNames

                if tagNames.isEmpty {
                    totals["__untagged__", default: 0] += entry.amount
                    continue
                }

                let sharedAmount = entry.amount / Double(tagNames.count)
                for tagName in tagNames {
                    totals[tagName, default: 0] += sharedAmount
                }
            }

            stats = totals.map { tagName, total in
                CategoryStat(
                    key: "tag|\(tagName)",
                    name: tagName == "__untagged__" ? "未标记".appLocalized(in: locale) : tagName,
                    symbol: "tag.fill",
                    colorHex: tagTintHexByName[tagName] ?? TagEmojiLibrary.colorHex(for: tagName),
                    amount: total,
                    usesEmoji: false
                )
            }
        }

        return stats
            .filter { $0.amount > 0.001 }
            .sorted { $0.amount > $1.amount }
            .prefix(6)
            .map { $0 }
    }

    private var selectedTotal: Double {
        selectedStats.reduce(0) { $0 + $1.amount }
    }

    private var distributionEmptyTitle: String {
        L10n.string(
            "stats.emptyDistribution",
            locale: locale,
            selectedFlow.localizedTitle(in: locale),
            selectedDistributionMode.localizedTitle(in: locale)
        )
    }

    private var distributionEmptySubtitle: String {
        selectedDistributionMode == .tag
            ? "先为账单补充标签，或点击趋势图中的月份切换统计范围".appLocalized(in: locale)
            : "点击趋势图中的月份可以切换统计范围".appLocalized(in: locale)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 18) {
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: SWTheme.toolbarControlSpacing) {
                    yearMenu

                    Button {
                        appRuntimeController.selectedMainTab = .stats
                        appRuntimeController.isStatsSettingsPresented = true
                        HapticService.impact()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(SWTheme.accentBlue)
                    }
                    .accessibilityLabel("设置")
                }
            }
        }
        .onChange(of: availableYears) { _, _ in
            normalizeSelectionIfNeeded()
            syncScrollWithSelection()
        }
        .onChange(of: selectedMonth) { _, _ in
            syncScrollWithSelection()
        }
        .onAppear {
            resetToCurrentPeriod()
            syncScrollWithSelection()
        }
        .appBackground()
    }

    private var yearMenu: some View {
        Menu {
            ForEach(availableYears, id: \.self) { year in
                Button {
                    selectedYear = year
                    syncScrollWithSelection()
                    HapticService.selection()
                } label: {
                    if year == selectedYear {
                        Label(L10n.year(year, locale: locale), systemImage: "checkmark")
                    } else {
                        Text(L10n.year(year, locale: locale))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(L10n.year(selectedYear, locale: locale))
                    .font(SWTheme.toolbarPickerTextFont)
                Image(systemName: "chevron.down")
                    .font(SWTheme.toolbarPickerChevronFont)
            }
            .foregroundStyle(SWTheme.toolbarPillText)
            .padding(.horizontal, SWTheme.toolbarPickerHorizontalPadding)
            .padding(.vertical, SWTheme.toolbarPickerVerticalPadding)
            .background(
                Capsule(style: .continuous)
                    .fill(SWTheme.toolbarPillFill)
            )
        }
        .accessibilityLabel("选择年度")
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(title: "收支概览", subtitle: "")
                Spacer()
                monthMenu
            }

            HStack(spacing: 12) {
                StatMetric(title: "收入", valueText: totalIncome.cnyText(in: locale), tint: SWTheme.accentGreen)
                StatMetric(title: "支出", valueText: totalExpense.cnyText(in: locale), tint: SWTheme.accentOrange)
            }

            HStack(spacing: 12) {
                StatMetric(title: "净结余", valueText: netBalance.signedCNYText(in: locale), tint: SWTheme.accentBlue)
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
            SectionTitle(title: "月度趋势", subtitle: "")

            if monthlyRows.allSatisfy({ $0.expense == 0 && $0.income == 0 }) {
                EmptyStateCard(
                    title: "暂无可统计数据",
                    subtitle: "先去支出/收入页面添加账单",
                    symbol: "chart.bar.xaxis"
                )
            } else {
                HStack(spacing: 14) {
                    TrendLegendItem(name: "支出", color: SWTheme.accentOrange)
                    TrendLegendItem(name: "收入", color: SWTheme.accentGreen)
                    Spacer()
                }

                Chart {
                    ForEach(monthlyRows) { row in
                        expenseBar(for: row)
                        incomeBar(for: row)
                    }
                }
                .chartLegend(.hidden)
                .chartXScale(
                    domain: 1.0...13.0,
                    range: .plotDimension(startPadding: 10, endPadding: 10)
                )
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: 6)
                .chartScrollPosition(x: $chartScrollStartMonth)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(Color.white.opacity(0.12))
                        AxisValueLabel()
                            .foregroundStyle(SWTheme.textSecondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: Array(1...12).map { monthAnchor(for: $0) }) { value in
                        AxisValueLabel {
                            if let x = value.as(Double.self) {
                                let month = monthFromChartX(x)
                                Text(L10n.month(month, locale: locale))
                                    .foregroundStyle(SWTheme.textSecondary)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                SpatialTapGesture()
                                    .onEnded { value in
                                        selectMonth(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                            )
                    }
                }
                .frame(height: 238)
            }
        }
        .fitnessCard()
    }

    private var distributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(title: "分类占比", subtitle: "")
                Spacer()
                monthMenu
            }

            Picker("类型", selection: $selectedFlow) {
                ForEach(FlowType.allCases) { flow in
                    Text(flow.localizedTitle(in: locale)).tag(flow)
                }
            }
            .pickerStyle(.segmented)

            Picker("维度", selection: $selectedDistributionMode) {
                ForEach(DistributionMode.allCases) { mode in
                    Text(mode.localizedTitle(in: locale)).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if selectedStats.isEmpty {
                EmptyStateCard(
                    title: distributionEmptyTitle,
                    subtitle: distributionEmptySubtitle,
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
                        Text("\(selectedFlow.localizedTitle(in: locale))\(selectedDistributionMode.localizedTitle(in: locale))")
                            .font(.caption)
                            .foregroundStyle(SWTheme.textSecondary)
                        Text(selectedTotal.cnyText(in: locale))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(SWTheme.primaryText)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedFlow)

                VStack(spacing: 10) {
                    ForEach(selectedStats) { item in
                        HStack(spacing: 10) {
                            if item.usesEmoji {
                                Text(item.symbol)
                                    .font(.headline)
                                    .frame(width: 20)
                            } else {
                                Image(systemName: item.symbol)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(item.color)
                                    .frame(width: 20)
                            }
                            Text(selectedDistributionMode == .category ? item.name.appLocalized(in: locale) : item.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SWTheme.primaryText)
                            Spacer()
                            Text(item.amount.cnyText(in: locale))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(SWTheme.primaryText)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .fitnessCard()
    }

    private var monthMenu: some View {
        Menu {
            ForEach(1...12, id: \.self) { month in
                Button {
                    selectedMonth = month
                    syncScrollWithSelection()
                    HapticService.selection()
                } label: {
                    if month == selectedMonth {
                        Label(L10n.month(month, locale: locale), systemImage: "checkmark")
                    } else {
                        Text(L10n.month(month, locale: locale))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(L10n.month(selectedMonth, locale: locale))
                    .font(SWTheme.toolbarPickerTextFont)
                Image(systemName: "chevron.down")
                    .font(SWTheme.toolbarPickerChevronFont)
            }
            .foregroundStyle(SWTheme.toolbarPillText)
            .padding(.horizontal, SWTheme.toolbarPickerHorizontalPadding)
            .padding(.vertical, SWTheme.toolbarPickerVerticalPadding)
            .background(
                Capsule(style: .continuous)
                    .fill(SWTheme.toolbarPillFill)
            )
        }
        .accessibilityLabel("选择月份")
    }

    private func normalizeSelectionIfNeeded() {
        if !availableYears.contains(selectedYear), let fallbackYear = availableYears.first {
            selectedYear = fallbackYear
        }

        if !(1...12).contains(selectedMonth) {
            selectedMonth = Calendar.current.component(.month, from: .now)
        }
    }

    private func resetToCurrentPeriod() {
        let now = Date()
        selectedYear = Calendar.current.component(.year, from: now)
        selectedMonth = Calendar.current.component(.month, from: now)
        normalizeSelectionIfNeeded()
    }

    @ChartContentBuilder
    private func expenseBar(for row: MonthlyTrendRow) -> some ChartContent {
        let center = monthAnchor(for: row.month)
        RectangleMark(
            xStart: .value("支出起点", center - 0.24),
            xEnd: .value("支出终点", center - 0.03),
            yStart: .value("基线", 0),
            yEnd: .value("支出", row.expense)
        )
        .foregroundStyle(SWTheme.accentOrange.gradient)
        .opacity(row.month == selectedMonth ? 1 : 0.38)
    }

    @ChartContentBuilder
    private func incomeBar(for row: MonthlyTrendRow) -> some ChartContent {
        let center = monthAnchor(for: row.month)
        RectangleMark(
            xStart: .value("收入起点", center + 0.03),
            xEnd: .value("收入终点", center + 0.24),
            yStart: .value("基线", 0),
            yEnd: .value("收入", row.income)
        )
        .foregroundStyle(SWTheme.accentGreen.gradient)
        .opacity(row.month == selectedMonth ? 1 : 0.38)
    }

    private func syncScrollWithSelection() {
        let minStart = 1.0
        let maxStart = 7.0
        let monthValue = monthAnchor(for: selectedMonth)

        if monthValue < chartScrollStartMonth + 0.5 {
            chartScrollStartMonth = max(minStart, monthValue - 0.5)
        } else if monthValue > chartScrollStartMonth + 5.5 {
            chartScrollStartMonth = min(maxStart, monthValue - 5.5)
        }
    }

    private func monthAnchor(for month: Int) -> Double {
        Double(month) + 0.5
    }

    private func monthFromChartX(_ x: Double) -> Int {
        max(1, min(12, Int((x - 0.5).rounded())))
    }

    private func selectMonth(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        guard plotFrame.contains(location) else { return }

        let relativeX = location.x - plotFrame.origin.x
        guard let rawXValue = proxy.value(atX: relativeX, as: Double.self) else { return }

        let tappedMonth = monthFromChartX(rawXValue)
        guard tappedMonth != selectedMonth else { return }

        selectedMonth = tappedMonth
        syncScrollWithSelection()
        HapticService.selection()
    }
}

private struct TrendLegendItem: View {
    @Environment(\.locale) private var locale
    let name: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(name.appLocalized(in: locale))
                .font(.caption.weight(.semibold))
                .foregroundStyle(SWTheme.textSecondary)
        }
    }
}

private struct StatMetric: View {
    @Environment(\.locale) private var locale
    let title: String
    let valueText: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.appLocalized(in: locale))
                .font(.caption)
                .foregroundStyle(SWTheme.textSecondary)
            Text(valueText)
                .font(.headline.weight(.bold))
                .foregroundStyle(SWTheme.primaryText)
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
