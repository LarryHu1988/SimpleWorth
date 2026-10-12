import Charts
import SwiftData
import SwiftUI

private struct MonthlyTrendRow: Identifiable {
    let month: Int
    let expense: Double
    let income: Double

    var id: Int { month }
}

enum DistributionMode: String, CaseIterable, Identifiable {
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

fileprivate struct StatsDrilldownTarget: Identifiable {
    let id: String
    let mode: DistributionMode
    let flow: FlowType
    let stat: CategoryStat
}

enum StatsSection {
    case full
    case overview
    case distribution
}

@MainActor
final class StatsPanelState: ObservableObject {
    @Published var selectedFlow: FlowType = .expense
    @Published var selectedDistributionMode: DistributionMode = .category
    @Published var selectedYear = Calendar.current.component(.year, from: .now)
    @Published var selectedMonth = Calendar.current.component(.month, from: .now)
    @Published var chartScrollStartMonth = max(1.0, Double(Calendar.current.component(.month, from: .now)) - 5)
    let selection = StatsSelectionState()
    @Published fileprivate var drilldownTarget: StatsDrilldownTarget?
    var hasInitializedPeriod = false
}

@MainActor
final class StatsSelectionState: ObservableObject {
    @Published var selectedStatID: String?
}

struct StatsView: View {
    @Environment(\.locale) private var locale
    @EnvironmentObject private var appRuntimeController: AppRuntimeController
    @Environment(\.swUsesWorkspace) private var usesWorkspace
    @Query(sort: [SortDescriptor(\LedgerEntry.createdAt, order: .reverse)]) private var entries: [LedgerEntry]
    @Query(sort: [SortDescriptor(\TagRecord.sortOrder), SortDescriptor(\TagRecord.createdAt)]) private var tags: [TagRecord]

    @StateObject private var panelState: StatsPanelState
    private let section: StatsSection
    private let fixedFlow: FlowType?
    private let periodYear: Binding<Int>?
    private let periodMonth: Binding<Int>?

    init(section: StatsSection = .full, flow: FlowType? = nil,
         year: Binding<Int>? = nil, month: Binding<Int>? = nil, state: StatsPanelState? = nil) {
        self.section = section
        fixedFlow = flow
        periodYear = year
        periodMonth = month
        _panelState = StateObject(wrappedValue: state ?? StatsPanelState())
    }

    private var selectedFlow: FlowType { fixedFlow ?? panelState.selectedFlow }
    private var selectedDistributionMode: DistributionMode { panelState.selectedDistributionMode }
    private var selectedYear: Int {
        get { periodYear?.wrappedValue ?? panelState.selectedYear }
        nonmutating set {
            if let periodYear { periodYear.wrappedValue = newValue } else { panelState.selectedYear = newValue }
        }
    }
    private var selectedMonth: Int {
        get { periodMonth?.wrappedValue ?? panelState.selectedMonth }
        nonmutating set {
            if let periodMonth { periodMonth.wrappedValue = newValue } else { panelState.selectedMonth = newValue }
        }
    }
    private var chartScrollStartMonth: Double {
        get { panelState.chartScrollStartMonth }
        nonmutating set { panelState.chartScrollStartMonth = newValue }
    }
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: .now)
        let years = Set(entries.map { Calendar.current.component(.year, from: $0.createdAt) } + [currentYear])
        return years.sorted(by: >)
    }

    private var selectedMonthEntries: [LedgerEntry] {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) ?? .now
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        let range = DateInterval(start: start, end: end)

        return entries.filter {
            range.containsHalfOpen($0.createdAt)
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
        let refundAmounts = expenseRefundAmountBySourceEntryID
        return selectedMonthEntries
            .filter { $0.flow == .expense && !$0.isRefundEntry }
            .reduce(0) { $0 + adjustedExpenseAmount(for: $1, refundAmounts: refundAmounts) }
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

    private var monthlyRows: [MonthlyTrendRow] {
        let calendar = Calendar.current
        let refundAmounts = expenseRefundAmountBySourceEntryID
        var expenses: [Int: Double] = [:]
        var incomes: [Int: Double] = [:]

        for entry in entries where calendar.component(.year, from: entry.createdAt) == selectedYear {
            let month = calendar.component(.month, from: entry.createdAt)
            if entry.flow == .expense, !entry.isRefundEntry {
                expenses[month, default: 0] += adjustedExpenseAmount(for: entry, refundAmounts: refundAmounts)
            }
            incomes[month, default: 0] += entry.incomeContribution
        }

        return (1...12).map { month in
            MonthlyTrendRow(
                month: month,
                expense: expenses[month, default: 0],
                income: incomes[month, default: 0]
            )
        }
    }

    private var selectedStats: [CategoryStat] {
        let refundAmounts = expenseRefundAmountBySourceEntryID
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
                let total = values.reduce(0) { $0 + statisticContribution(for: $1, refundAmounts: refundAmounts) }
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
                let contribution = statisticContribution(for: entry, refundAmounts: refundAmounts)

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

    private func statisticContribution(for entry: LedgerEntry, refundAmounts: [UUID: Double]) -> Double {
        switch selectedFlow {
        case .expense:
            return adjustedExpenseAmount(for: entry, refundAmounts: refundAmounts)
        case .income:
            return entry.incomeContribution
        }
    }

    private func adjustedExpenseAmount(for entry: LedgerEntry, refundAmounts: [UUID: Double]) -> Double {
        guard entry.flow == .expense, !entry.isRefundEntry else { return 0 }
        return max(entry.amount - (refundAmounts[entry.id] ?? 0), 0)
    }

    private func percentageText(for amount: Double) -> String {
        guard selectedTotal > 0 else { return "0%" }
        return "\((amount / selectedTotal * 100).formatted(.number.precision(.fractionLength(1))))%"
    }

    var body: some View {
        pageContent
        .onChange(of: availableYears) { _, _ in
            normalizeSelectionIfNeeded()
            syncScrollWithSelection()
        }
        .onChange(of: selectedMonth) { _, _ in
            syncScrollWithSelection()
        }
        .onAppear {
            if !panelState.hasInitializedPeriod {
                panelState.hasInitializedPeriod = true
                if periodYear == nil { resetToCurrentPeriod() }
            }
            syncScrollWithSelection()
        }
        .onChange(of: distributionSelectionKey) { _, _ in panelState.selection.selectedStatID = nil }
        .sheet(item: $panelState.drilldownTarget) { target in
            let targetEntries = drilldownEntries(for: target)
            StatsDrilldownSheet(
                title: target.mode == .category ? "分类明细" : "标签明细",
                item: target.stat,
                itemName: displayName(for: target.stat, mode: target.mode),
                summaryText: L10n.string(
                    "stats.drilldownSummary",
                    locale: locale,
                    Int64(targetEntries.count),
                    percentageText(for: target.stat.amount)
                ),
                amountText: target.stat.amount.cnyText(in: locale),
                entries: targetEntries,
                refundAmountBySourceEntryID: expenseRefundAmountBySourceEntryID,
                tagTintHexByName: tagTintHexByName
            )
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch section {
        case .overview:
            overviewContent
        case .distribution:
            distributionCard
        case .full:
            if usesWorkspace {
                fullWorkspacePage
                    .safeAreaInset(edge: .top, spacing: 0) { workspaceHeader }
                    .appBackground()
            } else {
                NavigationStack {
                    fullWorkspacePage
                        .fixedMainPageTitle("统计".appLocalized(in: locale))
                        .toolbar {
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                yearMenu
                                settingsButton
                            }
                        }
                        .appBackground()
                }
            }
        }
    }

    private var fullWorkspacePage: some View {
        SWWorkspacePage(showSecondaryInCompact: true,
                            secondaryScrolls: !appRuntimeController.isStatsSettingsPresented) {
                overviewContent
            } secondary: {
                if usesWorkspace, appRuntimeController.isStatsSettingsPresented {
                    SettingsPaneHost(path: settingsPath) {
                        appRuntimeController.isStatsSettingsPresented = false
                        appRuntimeController.statsSettingsPath.removeAll()
                    }
                } else {
                    distributionCard
                }
            }
    }

    private var workspaceHeader: some View {
        HStack(spacing: 16) {
            Text("统计".appLocalized(in: locale))
                .font(.title2.weight(.bold))
                .foregroundStyle(SWTheme.primaryText)
                .accessibilityIdentifier("mainPageTitle")
            Spacer()
            yearMenu
            settingsButton.labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
    }

    private var settingsButton: some View {
        Button {
            appRuntimeController.selectedMainTab = .stats
            appRuntimeController.isStatsSettingsPresented = true
            HapticService.impact()
        } label: {
            Label("设置".appLocalized(in: locale), systemImage: "gearshape.fill")
                .foregroundStyle(SWTheme.accentBlue)
        }
        .accessibilityLabel("设置")
        .accessibilityIdentifier("stats.settings")
    }

    private var overviewContent: some View {
        VStack(spacing: 18) {
            overviewCard
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("stats.overview")
            monthlyChartCard
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("stats.trend")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stats.overview.panel")
    }

    private var settingsPath: Binding<[SettingsRoute]> {
        Binding(get: { appRuntimeController.statsSettingsPath },
                set: { appRuntimeController.statsSettingsPath = $0 })
    }

    private var distributionSelectionKey: String {
        "\(selectedYear)-\(selectedMonth)-\(selectedFlow.id)-\(selectedDistributionMode.id)"
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
        .accessibilityIdentifier("period.year")
    }

    private var overviewCard: some View {
        let expense = totalExpense
        let income = totalIncome
        let balance = income - expense
        let rate = income > 0 ? balance / income : 0

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(title: "收支概览", subtitle: "")
                Spacer()
                monthMenu
            }

            HStack(spacing: 12) {
                StatMetric(title: "收入", valueText: income.cnyText(in: locale), tint: SWTheme.accentGreen)
                StatMetric(title: "支出", valueText: expense.cnyText(in: locale), tint: SWTheme.accentOrange)
            }

            HStack(spacing: 12) {
                StatMetric(title: "净结余", valueText: balance.signedCNYText(in: locale), tint: SWTheme.accentBlue)
                StatMetric(
                    title: "储蓄率",
                    valueText: "\((rate * 100).formatted(.number.precision(.fractionLength(1))))%",
                    tint: SWTheme.accentPink
                )
            }
        }
        .fitnessCard()
    }

    private var monthlyChartCard: some View {
        let rows = monthlyRows

        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "月度趋势", subtitle: "")

            if rows.allSatisfy({ $0.expense == 0 && $0.income == 0 }) {
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
                    ForEach(rows) { row in
                        expenseBar(for: row)
                        incomeBar(for: row)
                    }
                }
                .chartLegend(.hidden)
                .chartPlotStyle { plot in
                    plot.chartEntrance(.vertical, replay: selectedYear)
                }
                .chartXScale(
                    domain: 1.0...13.0,
                    range: .plotDimension(startPadding: 10, endPadding: 10)
                )
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: 6)
                .chartScrollPosition(x: $panelState.chartScrollStartMonth)
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
        let stats = selectedStats
        let total = selectedTotal

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(title: "分类占比", subtitle: "")
                Spacer()
                monthMenu
            }

            if fixedFlow == nil {
                Picker("类型", selection: $panelState.selectedFlow) {
                    ForEach(FlowType.allCases) { flow in
                        Text(flow.localizedTitle(in: locale)).tag(flow)
                    }
                }
                .pickerStyle(.segmented)
            }

            Picker("维度", selection: $panelState.selectedDistributionMode) {
                ForEach(DistributionMode.allCases) { mode in
                    Text(mode.localizedTitle(in: locale)).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if stats.isEmpty {
                EmptyStateCard(
                    title: distributionEmptyTitle,
                    subtitle: distributionEmptySubtitle,
                    symbol: selectedFlow == .expense ? "minus.circle" : "plus.circle"
                )
            } else {
                StatsDistributionContent(
                    stats: stats,
                    total: total,
                    flow: selectedFlow,
                    mode: selectedDistributionMode,
                    locale: locale,
                    selection: panelState.selection
                ) { item in
                    panelState.drilldownTarget = StatsDrilldownTarget(
                        id: "\(selectedFlow.id)-\(selectedDistributionMode.id)-\(item.id)",
                        mode: selectedDistributionMode,
                        flow: selectedFlow,
                        stat: item
                    )
                }
            }
        }
        .fitnessCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stats.distribution.panel")
        .accessibilityValue(selectedFlow.storageValue)
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
        .accessibilityValue(L10n.month(selectedMonth, locale: locale))
        .accessibilityIdentifier("period.month")
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

private struct StatsDistributionContent: View {
    @Environment(\.swWideLayout) private var isWide
    let stats: [CategoryStat]
    let total: Double
    let flow: FlowType
    let mode: DistributionMode
    let locale: Locale
    @ObservedObject var selection: StatsSelectionState
    let onDrilldown: (CategoryStat) -> Void

    private var selectedStatID: String? {
        get { selection.selectedStatID }
        nonmutating set { selection.selectedStatID = newValue }
    }

    private var effectiveSelectedStatID: String? {
        guard let selectedStatID, stats.contains(where: { $0.id == selectedStatID }) else { return nil }
        return selectedStatID
    }

    private var selectedStat: CategoryStat? {
        guard let effectiveSelectedStatID else { return nil }
        return stats.first { $0.id == effectiveSelectedStatID }
    }

    private var chartTotal: Double {
        stats.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        SWAdaptiveColumns(isWide: isWide) {
            ZStack {
                Chart(stats) { item in
                    let isHighlighted = effectiveSelectedStatID == item.id
                    let hasSelection = effectiveSelectedStatID != nil

                    SectorMark(
                        angle: .value("金额", item.amount),
                        innerRadius: .ratio(0.58),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color.gradient)
                    .opacity(!hasSelection || isHighlighted ? 1 : 0.28)
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
                .chartPlotStyle { plot in
                    plot.chartEntrance(.radial)
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture()
                                    .onEnded { value in
                                        selectSlice(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                            )
                    }
                }
                .frame(height: 250)

                centerLabel
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("stats.distribution.chart")

            VStack(spacing: 10) {
                ForEach(stats) { item in
                    Button {
                        selectStat(item.id)
                        onDrilldown(item)
                    } label: {
                        row(for: item, isSelected: effectiveSelectedStatID == item.id)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("stats.distribution.\(item.name)")
                    .accessibilityAddTraits(effectiveSelectedStatID == item.id ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("stats.distribution.rows")
        }
    }

    private var centerLabel: some View {
        VStack(spacing: 6) {
            if let selectedStat {
                Text(displayName(for: selectedStat))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selectedStat.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(selectedStat.amount.cnyText(in: locale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SWTheme.primaryText)
                    .minimumScaleFactor(0.72)

                Text(percentageText(for: selectedStat.amount))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
            } else {
                Text("\(flow.localizedTitle(in: locale))\(mode.localizedTitle(in: locale))")
                    .font(.caption)
                    .foregroundStyle(SWTheme.textSecondary)

                Text(total.cnyText(in: locale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SWTheme.primaryText)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(width: 116)
        .contentShape(Rectangle())
        .onTapGesture {
            clearSelection()
        }
    }

    private func row(for item: CategoryStat, isSelected: Bool) -> some View {
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

            Text(displayName(for: item))
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
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private func selectSlice(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }

        let plotFrame = geometry[plotFrameAnchor]
        guard plotFrame.contains(location) else { return }

        let plotLocation = CGPoint(
            x: location.x - plotFrame.origin.x,
            y: location.y - plotFrame.origin.y
        )
        let center = CGPoint(x: plotFrame.width / 2, y: plotFrame.height / 2)
        let distanceFromCenter = hypot(plotLocation.x - center.x, plotLocation.y - center.y)
        let outerRadius = min(plotFrame.width, plotFrame.height) / 2
        let innerRadius = outerRadius * 0.58

        guard distanceFromCenter >= innerRadius * 0.86, distanceFromCenter <= outerRadius * 1.06 else {
            clearSelection()
            return
        }

        let angle = proxy.angle(at: plotLocation)
        guard
            let value = proxy.value(atAngle: angle, as: Double.self),
            let statID = statID(forAngleValue: value)
        else { return }

        selectStat(statID)
    }

    private func selectStat(_ statID: String) {
        guard selectedStatID != statID else { return }
        selectedStatID = statID
        HapticService.selection()
    }

    private func clearSelection() {
        guard selectedStatID != nil else { return }
        selectedStatID = nil
        HapticService.selection()
    }

    private func statID(forAngleValue value: Double) -> String? {
        guard chartTotal > 0 else { return nil }

        let clampedValue = min(max(value, 0), chartTotal)
        var cumulativeAmount = 0.0

        for item in stats {
            cumulativeAmount += item.amount
            if clampedValue <= cumulativeAmount {
                return item.id
            }
        }

        return stats.last?.id
    }

    private func displayName(for stat: CategoryStat) -> String {
        mode == .category ? stat.name.appLocalized(in: locale) : stat.name
    }

    private func percentageText(for amount: Double) -> String {
        guard total > 0 else { return "0%" }
        return "\((amount / total * 100).formatted(.number.precision(.fractionLength(1))))%"
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
