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

private struct StatsDrilldownTarget: Identifiable {
    let id: String
    let mode: DistributionMode
    let flow: FlowType
    let stat: CategoryStat
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
    @State private var selectedDistributionAngle: Double?
    @State private var selectedDistributionStatID: String?
    @State private var chartScrollStartMonth = max(
        1.0,
        Double(Calendar.current.component(.month, from: .now)) + 0.5 - 5.5
    )
    @State private var drilldownTarget: StatsDrilldownTarget?
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

    private var expenseRefundAmountBySourceEntryID: [UUID: Double] {
        var result: [UUID: Double] = [:]

        for entry in entries where entry.flow == .expense && entry.isRefundEntry {
            guard let sourceEntryID = entry.refundSourceEntryID else { continue }
            result[sourceEntryID, default: 0] += entry.amount
        }

        return result
    }

    private var totalExpense: Double {
        selectedMonthEntries
            .filter { $0.flow == .expense && !$0.isRefundEntry }
            .reduce(0) { $0 + adjustedExpenseAmount(for: $1) }
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
                .filter { $0.flow == .expense && !$0.isRefundEntry }
                .reduce(0) { $0 + adjustedExpenseAmount(for: $1) }

            let income = rows
                .reduce(0) { $0 + $1.incomeContribution }

            return MonthlyTrendRow(month: month, expense: expense, income: income)
        }
    }

    private var selectedStats: [CategoryStat] {
        let filtered = selectedMonthEntries.filter { entry in
            entry.flow == selectedFlow && (selectedFlow == .income || !entry.isRefundEntry)
        }
        let stats: [CategoryStat]

        switch selectedDistributionMode {
        case .category:
            let grouped = Dictionary(grouping: filtered) {
                "\($0.categoryName)|\($0.categorySymbol)|\($0.categoryColorHex)"
            }

            stats = grouped.compactMap { key, values -> CategoryStat? in
                guard let first = values.first else { return nil }
                let total = values.reduce(0) { $0 + statisticContribution(for: $1) }
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
                let contribution = statisticContribution(for: entry)

                if tagNames.isEmpty {
                    totals["__untagged__", default: 0] += contribution
                    continue
                }

                let sharedAmount = contribution / Double(tagNames.count)
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
    }

    private var selectedTotal: Double {
        switch selectedFlow {
        case .expense:
            return totalExpense
        case .income:
            return totalIncome
        }
    }

    private var selectedDistributionStat: CategoryStat? {
        guard let selectedDistributionStatID else { return nil }
        return selectedStats.first { $0.id == selectedDistributionStatID }
    }

    private var distributionChartTotal: Double {
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

    private func statisticContribution(for entry: LedgerEntry) -> Double {
        switch selectedFlow {
        case .expense:
            return adjustedExpenseAmount(for: entry)
        case .income:
            return entry.incomeContribution
        }
    }

    private func adjustedExpenseAmount(for entry: LedgerEntry) -> Double {
        guard entry.flow == .expense, !entry.isRefundEntry else { return 0 }
        return max(entry.amount - (expenseRefundAmountBySourceEntryID[entry.id] ?? 0), 0)
    }

    private func percentageText(for amount: Double) -> String {
        guard selectedTotal > 0 else { return "0%" }
        return "\((amount / selectedTotal * 100).formatted(.number.precision(.fractionLength(1))))%"
    }

    @ViewBuilder
    private func distributionCenterLabel(for stat: CategoryStat?) -> some View {
        VStack(spacing: 6) {
            if let stat {
                Text(displayName(for: stat, mode: selectedDistributionMode))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stat.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(stat.amount.cnyText(in: locale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SWTheme.primaryText)
                    .minimumScaleFactor(0.72)

                Text(percentageText(for: stat.amount))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
            } else {
                Text("\(selectedFlow.localizedTitle(in: locale))\(selectedDistributionMode.localizedTitle(in: locale))")
                    .font(.caption)
                    .foregroundStyle(SWTheme.textSecondary)

                Text(selectedTotal.cnyText(in: locale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SWTheme.primaryText)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(width: 116)
        .contentShape(Rectangle())
        .onTapGesture {
            clearDistributionSelection()
        }
    }

    @ViewBuilder
    private func distributionRow(for item: CategoryStat, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(item.color.opacity(isSelected ? 0.22 : 0.12))
                    .frame(width: 28, height: 28)

                if item.usesEmoji {
                    Text(item.symbol)
                        .font(.headline)
                } else {
                    Image(systemName: item.symbol)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(item.color)
                }
            }
            .frame(width: 28, height: 28)

            Text(displayName(for: item, mode: selectedDistributionMode))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SWTheme.primaryText)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.amount.cnyText(in: locale))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSelected ? item.color : SWTheme.primaryText)

                Text(percentageText(for: item.amount))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(isSelected ? item.color.opacity(0.9) : SWTheme.textSecondary.opacity(0.75))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? item.color.opacity(0.13) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? item.color.opacity(0.52) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
    }

    private func updateDistributionSelection(from angle: Double?) {
        guard let angle else {
            selectedDistributionStatID = nil
            return
        }

        guard let statID = distributionStatID(for: angle) else { return }
        guard selectedDistributionStatID != statID else { return }

        selectedDistributionStatID = statID
        HapticService.selection()
    }

    private func distributionStatID(for angle: Double) -> String? {
        guard distributionChartTotal > 0 else { return nil }

        let clampedAngle = min(max(angle, 0), distributionChartTotal)
        var cumulativeAmount = 0.0

        for item in selectedStats {
            cumulativeAmount += item.amount
            if clampedAngle <= cumulativeAmount {
                return item.id
            }
        }

        return selectedStats.last?.id
    }

    private func distributionAngleMidpoint(for stat: CategoryStat) -> Double? {
        var cumulativeAmount = 0.0

        for item in selectedStats {
            let startAmount = cumulativeAmount
            cumulativeAmount += item.amount

            if item.id == stat.id {
                return startAmount + item.amount / 2
            }
        }

        return nil
    }

    private func clearDistributionSelection() {
        selectedDistributionAngle = nil
        selectedDistributionStatID = nil
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
            clearDistributionSelection()
        }
        .onChange(of: selectedMonth) { _, _ in
            syncScrollWithSelection()
            clearDistributionSelection()
        }
        .onChange(of: selectedYear) { _, _ in
            clearDistributionSelection()
        }
        .onChange(of: selectedFlow) { _, _ in
            clearDistributionSelection()
        }
        .onChange(of: selectedDistributionMode) { _, _ in
            clearDistributionSelection()
        }
        .onChange(of: selectedDistributionAngle) { _, newValue in
            updateDistributionSelection(from: newValue)
        }
        .onAppear {
            resetToCurrentPeriod()
            syncScrollWithSelection()
        }
        .sheet(item: $drilldownTarget) { target in
            StatsDrilldownSheet(
                title: target.mode == .category ? "分类明细" : "标签明细",
                item: target.stat,
                itemName: displayName(for: target.stat, mode: target.mode),
                summaryText: L10n.string(
                    "stats.drilldownSummary",
                    locale: locale,
                    Int64(drilldownEntries(for: target).count),
                    percentageText(for: target.stat.amount)
                ),
                amountText: target.stat.amount.cnyText(in: locale),
                entries: drilldownEntries(for: target),
                refundAmountBySourceEntryID: expenseRefundAmountBySourceEntryID,
                tagTintHexByName: tagTintHexByName
            )
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
                let highlightedStat = selectedDistributionStat
                let hasHighlightedStat = highlightedStat != nil

                ZStack {
                    Chart(selectedStats) { item in
                        let isHighlighted = highlightedStat?.id == item.id
                        SectorMark(
                            angle: .value("金额", item.amount),
                            innerRadius: .ratio(0.58),
                            angularInset: 2
                        )
                        .foregroundStyle(item.color.gradient)
                        .opacity(!hasHighlightedStat || isHighlighted ? 1 : 0.26)
                    }
                    .chartAngleSelection(value: $selectedDistributionAngle)
                    .frame(height: 250)

                    distributionCenterLabel(for: highlightedStat)
                }
                .animation(.easeInOut(duration: 0.2), value: selectedFlow)
                .animation(.easeInOut(duration: 0.18), value: selectedDistributionStatID)

                VStack(spacing: 10) {
                    ForEach(selectedStats) { item in
                        Button {
                            selectedDistributionStatID = item.id
                            selectedDistributionAngle = distributionAngleMidpoint(for: item)
                            drilldownTarget = StatsDrilldownTarget(
                                id: "\(selectedFlow.id)-\(selectedDistributionMode.id)-\(item.id)",
                                mode: selectedDistributionMode,
                                flow: selectedFlow,
                                stat: item
                            )
                            HapticService.selection()
                        } label: {
                            distributionRow(for: item, isSelected: selectedDistributionStatID == item.id)
                        }
                        .buttonStyle(.plain)
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

    private func displayName(for stat: CategoryStat, mode: DistributionMode) -> String {
        mode == .category ? stat.name.appLocalized(in: locale) : stat.name
    }

    private func drilldownEntries(for target: StatsDrilldownTarget) -> [LedgerEntry] {
        let baseEntries = selectedMonthEntries.filter { entry in
            entry.flow == target.flow && (target.flow == .income || !entry.isRefundEntry)
        }
        let matchedEntries: [LedgerEntry]

        switch target.mode {
        case .category:
            matchedEntries = baseEntries.filter { entry in
                entry.categoryName == target.stat.name
                    && entry.categorySymbol == target.stat.symbol
                    && entry.categoryColorHex == target.stat.colorHex
            }
        case .tag:
            let tagName = target.stat.key.replacingOccurrences(of: "tag|", with: "")
            if tagName == "__untagged__" {
                matchedEntries = baseEntries.filter { $0.tagNames.isEmpty }
            } else {
                matchedEntries = baseEntries.filter { $0.tagNames.contains(tagName) }
            }
        }

        return matchedEntries.sorted(by: isNewerStatsEntry)
    }

    private func isNewerStatsEntry(_ lhs: LedgerEntry, than rhs: LedgerEntry) -> Bool {
        let calendar = Calendar.current
        let lhsDay = calendar.startOfDay(for: lhs.createdAt)
        let rhsDay = calendar.startOfDay(for: rhs.createdAt)

        if lhsDay != rhsDay {
            return lhsDay > rhsDay
        }

        if lhs.resolvedRecordedAt != rhs.resolvedRecordedAt {
            return lhs.resolvedRecordedAt > rhs.resolvedRecordedAt
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.id.uuidString > rhs.id.uuidString
    }
}

private struct StatsDrilldownSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let title: String
    let item: CategoryStat
    let itemName: String
    let summaryText: String
    let amountText: String
    let entries: [LedgerEntry]
    let refundAmountBySourceEntryID: [UUID: Double]
    let tagTintHexByName: [String: Int]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    summaryCard

                    if entries.isEmpty {
                        EmptyStateCard(
                            title: "该维度下暂无记录",
                            subtitle: "返回统计页后可切换月份或维度查看。",
                            symbol: "list.bullet.rectangle"
                        )
                    } else {
                        ForEach(entries) { entry in
                            LedgerRow(
                                entry: entry,
                                tagTintHexByName: tagTintHexByName,
                                refundAmount: refundAmountBySourceEntryID[entry.id] ?? 0
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .navigationTitle(title.appLocalized(in: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成".appLocalized(in: locale)) {
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            .appBackground()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.18))
                    .frame(width: 48, height: 48)

                if item.usesEmoji {
                    Text(item.symbol)
                        .font(.title3)
                } else {
                    Image(systemName: item.symbol)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(item.color)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(itemName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SWTheme.primaryText)
                    .lineLimit(2)

                Text(summaryText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                Text("统计金额".appLocalized(in: locale))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)

                Text(amountText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(SWTheme.primaryText)
                    .minimumScaleFactor(0.75)
            }
        }
        .fitnessCard()
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
