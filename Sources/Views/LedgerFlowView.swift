import SwiftData
import SwiftUI

private struct LedgerEditorTarget: Identifiable {
    let id = UUID()
    let entry: LedgerEntry?
    let categoryID: String?
    let operation: EntryEditorOperation
    let usesFullScreen: Bool
}

struct LedgerFlowView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.swUsesWorkspace) private var usesWorkspace
    @Query(sort: [SortDescriptor(\LedgerEntry.createdAt, order: .reverse)]) private var allEntries: [LedgerEntry]
    @Query(sort: [SortDescriptor(\TagRecord.sortOrder), SortDescriptor(\TagRecord.createdAt)]) private var allTags: [TagRecord]
    @State private var distributionState = StatsPanelState()

    let flow: FlowType

    @State private var editorTarget: LedgerEditorTarget?
    @State private var pendingDeleteEntry: LedgerEntry?
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    @State private var selectedMonth = Calendar.current.component(.month, from: .now)
    @State private var showCategoryGrid = false
    @State private var showRecentEntries = true
    @State private var hasInitializedPeriod = false
    @State private var summaryScrollID = UUID()
    @State private var categoryToggleScrollID = UUID()
    @State private var categoryGridScrollID = UUID()

    private var categories: [CategoryItem] {
        CategoryLibrary.categories(for: flow)
    }

    private var entries: [LedgerEntry] {
        allEntries.filter { $0.flow == flow }
    }

    private var tagTintHexByName: [String: Int] {
        var result: [String: Int] = [:]

        for tag in allTags {
            let normalizedName = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedName.isEmpty else { continue }
            if result[normalizedName] == nil {
                result[normalizedName] = tag.resolvedTintHex
            }
        }

        return result
    }

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: .now)
        let years = Set(entries.map { Calendar.current.component(.year, from: $0.createdAt) } + [currentYear])
        return years.sorted(by: >)
    }

    private var selectedPeriodDate: Date {
        let components = DateComponents(year: selectedYear, month: selectedMonth, day: 1)
        return Calendar.current.date(from: components) ?? .now
    }

    private var selectedPeriodEntries: [LedgerEntry] {
        let range = monthRange(for: selectedPeriodDate)
        return entries
            .filter { entry in
                range.containsHalfOpen(entry.createdAt) && !(flow == .expense && entry.isRefundEntry)
            }
            .sorted(by: isNewerLedgerEntry)
    }

    private var refundAmountBySourceEntryID: [UUID: Double] {
        var result: [UUID: Double] = [:]

        for entry in entries where entry.flow == .expense && entry.isRefundEntry {
            guard let sourceEntryID = entry.refundSourceEntryID else { continue }
            result[sourceEntryID, default: 0] += entry.amount
        }

        return result
    }

    private var refundEntriesBySourceEntryID: [UUID: [LedgerEntry]] {
        var result: [UUID: [LedgerEntry]] = [:]

        for entry in entries where entry.flow == .expense && entry.isRefundEntry {
            guard let sourceEntryID = entry.refundSourceEntryID else { continue }
            result[sourceEntryID, default: []].append(entry)
        }

        return result.mapValues { entries in
            entries.sorted(by: isNewerLedgerEntry)
        }
    }

    private var selectedPeriodLabel: String {
        L10n.yearMonth(year: selectedYear, month: selectedMonth, locale: locale)
    }

    private var summaryCard: some View {
        let refundAmounts = refundAmountBySourceEntryID
        let selectedPeriodTotal = totalAmount(inMonthOf: selectedPeriodDate, refundAmounts: refundAmounts)
        let previousMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedPeriodDate) ?? selectedPeriodDate
        let previousPeriodTotal = totalAmount(inMonthOf: previousMonthDate, refundAmounts: refundAmounts)

        return FlowSummaryCard(
            flow: flow,
            periodTitle: L10n.string("ledger.periodFlow", locale: locale, selectedPeriodLabel, flow.localizedTitle(in: locale)),
            amount: selectedPeriodTotal,
            compareText: compareText(selectedPeriodTotal: selectedPeriodTotal, previousPeriodTotal: previousPeriodTotal),
            ringProgress: ringProgress(selectedPeriodTotal: selectedPeriodTotal, previousPeriodTotal: previousPeriodTotal)
        )
    }

    private func compareText(selectedPeriodTotal: Double, previousPeriodTotal: Double) -> String {
        guard previousPeriodTotal > 0 else {
            return selectedPeriodTotal > 0
                ? L10n.string("ledger.compare.new", locale: locale, selectedPeriodLabel, selectedPeriodTotal.cnyText(in: locale))
                : L10n.string("ledger.compare.empty", locale: locale, selectedPeriodLabel)
        }

        let delta = (selectedPeriodTotal - previousPeriodTotal) / previousPeriodTotal
        if abs(delta) < 0.001 {
            return L10n.string("ledger.compare.equal", locale: locale)
        }

        let ratioText = (abs(delta) * 100).formatted(.number.precision(.fractionLength(1)))
        if flow == .expense {
            return delta > 0
                ? L10n.string("ledger.compare.expenseUp", locale: locale, ratioText)
                : L10n.string("ledger.compare.expenseDown", locale: locale, ratioText)
        }
        return delta > 0
            ? L10n.string("ledger.compare.incomeUp", locale: locale, ratioText)
            : L10n.string("ledger.compare.incomeDown", locale: locale, ratioText)
    }

    private func ringProgress(selectedPeriodTotal: Double, previousPeriodTotal: Double) -> Double {
        guard previousPeriodTotal > 0 else {
            return selectedPeriodTotal > 0 ? 1 : 0
        }

        return min(max(selectedPeriodTotal / previousPeriodTotal, 0), 1)
    }

    private var categoryTitle: String {
        flow == .expense ? "支出分类".appLocalized(in: locale) : "收入分类".appLocalized(in: locale)
    }

    private var categorySubtitle: String {
        flow == .expense
            ? "常见生活消费图标一键记账".appLocalized(in: locale)
            : "工资、副业、理财等来源一屏管理".appLocalized(in: locale)
    }

    private var recentTitle: String {
        flow == .expense ? "最近支出".appLocalized(in: locale) : "最近收入".appLocalized(in: locale)
    }

    private func recentSubtitle(count: Int) -> String {
        flow == .expense
            ? L10n.string("ledger.recentSubtitle.expense", locale: locale, Int64(count))
            : L10n.string("ledger.recentSubtitle.income", locale: locale, Int64(count))
    }

    private var emptyTitle: String {
        flow == .expense ? "还没有支出记录".appLocalized(in: locale) : "还没有收入记录".appLocalized(in: locale)
    }

    private var emptySubtitle: String {
        flow == .expense
            ? L10n.string("ledger.empty.expense", locale: locale, selectedPeriodLabel)
            : L10n.string("ledger.empty.income", locale: locale, selectedPeriodLabel)
    }

    var body: some View {
        SWWorkspacePage {
            VStack(spacing: 18) {
                // Anchor the visible header instead of a ledger row pushed down by expansion.
                VStack(spacing: 18) {
                    summaryCard.id(summaryScrollID)
                    categoryToggleCard.id(categoryToggleScrollID)
                    if showCategoryGrid {
                        CategoryGridSection(
                            title: categoryTitle,
                            subtitle: categorySubtitle,
                            categories: categories,
                            onTapCategory: { category in
                                presentCreateSheet(categoryID: category.id)
                            }
                        )
                        .id(categoryGridScrollID)
                    }
                }
                .scrollTargetLayout()
                transactionCard
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        } secondary: {
            StatsView(section: .distribution, flow: flow, year: $selectedYear, month: $selectedMonth,
                      state: distributionState)
        }
        .fixedMainPageTitle(flow.localizedTitle(in: locale))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                yearMenu
                monthMenu

                Button {
                    presentCreateSheet(categoryID: nil)
                } label: {
                    Label(L10n.string("ledger.addFlow", locale: locale, flow.localizedTitle(in: locale)), systemImage: "plus.circle.fill")
                        .foregroundStyle(flow.accent)
                }
                .accessibilityLabel(L10n.string("ledger.addFlow", locale: locale, flow.localizedTitle(in: locale)))
            }
        }
        .sheet(item: editorBinding(fullScreen: false)) { target in
            editor(for: target)
        }
        .fullScreenCover(item: editorBinding(fullScreen: true)) { target in
            editor(for: target)
        }
        .onChange(of: availableYears) { _, _ in
            normalizeSelectionIfNeeded()
        }
        .onAppear {
            if !hasInitializedPeriod {
                hasInitializedPeriod = true
                resetToCurrentPeriod()
                showCategoryGrid = false
            }
        }
        .alert(
            "确认删除账单",
            isPresented: Binding(
                get: { pendingDeleteEntry != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeleteEntry = nil
                    }
                }
            ),
            presenting: pendingDeleteEntry
        ) { entry in
            Button("删除", role: .destructive) {
                delete(entry)
                pendingDeleteEntry = nil
            }
            Button("取消", role: .cancel) {
                pendingDeleteEntry = nil
            }
        } message: { _ in
            Text("删除后将同步更新统计数据，且无法撤销。")
        }
        .appBackground()
    }

    private var categoryToggleCard: some View {
        Button {
            withAnimation(SWMotion.settle) {
                showCategoryGrid.toggle()
            }
            HapticService.selection()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: showCategoryGrid ? "square.grid.2x2.fill" : "square.grid.2x2")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(flow.accent)

                Text(
                    showCategoryGrid
                        ? L10n.string("ledger.hideCategory", locale: locale, categoryTitle)
                        : L10n.string("ledger.showCategory", locale: locale, categoryTitle)
                )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SWTheme.primaryText)

                Spacer()

                Image(systemName: showCategoryGrid ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(SWResponsiveButtonStyle())
        .fitnessCard()
        .accessibilityIdentifier("ledger.categoryToggle.\(flow.storageValue)")
    }

    private var yearMenu: some View {
        Menu {
            ForEach(availableYears, id: \.self) { year in
                Button {
                    selectedYear = year
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

    private var monthMenu: some View {
        Menu {
            ForEach(1...12, id: \.self) { month in
                Button {
                    selectedMonth = month
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

    private var transactionCard: some View {
        let refundAmounts = refundAmountBySourceEntryID
        let periodEntries = selectedPeriodEntries
        let tagTints = tagTintHexByName

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                SectionTitle(title: recentTitle, subtitle: recentSubtitle(count: periodEntries.count))

                Spacer(minLength: 8)

                if !periodEntries.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showRecentEntries.toggle()
                        }
                        HapticService.selection()
                    } label: {
                        HStack(spacing: 4) {
                            Text(showRecentEntries ? "收起".appLocalized(in: locale) : "展开".appLocalized(in: locale))
                                .font(.caption.weight(.semibold))
                            Image(systemName: showRecentEntries ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(SWTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showRecentEntries ? "收起本月记录".appLocalized(in: locale) : "展开本月记录".appLocalized(in: locale))
                }
            }

            if periodEntries.isEmpty {
                EmptyStateCard(
                    title: emptyTitle,
                    subtitle: emptySubtitle,
                    symbol: flow == .expense ? "tray.fill" : "banknote.fill"
                )
            } else if !showRecentEntries {
                Text(L10n.string("ledger.recentCollapsed", locale: locale, Int64(periodEntries.count)))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(periodEntries) { entry in
                        SwipeableLedgerRow(
                            entry: entry,
                            tagTintHexByName: tagTints,
                            refundAmount: refundAmounts[entry.id] ?? 0,
                            showCopyAction: !entry.isRefundEntry,
                            showRefundAction: flow == .expense,
                            onTap: {
                                presentEditor(operation: .edit, entry: entry)
                            },
                            onCopy: {
                                presentEditor(operation: .copy, entry: entry)
                            },
                            onRefund: {
                                guard flow == .expense else { return }
                                presentEditor(operation: .refund, entry: entry)
                            },
                            onDelete: {
                                pendingDeleteEntry = entry
                            }
                        )
                        .id(entry.id)
                    }
                }
                .scrollTargetLayout()
            }
        }
        .fitnessCard()
    }

    private func presentCreateSheet(categoryID: String?) {
        presentEditor(operation: .create, categoryID: categoryID)
    }

    private func presentEditor(operation: EntryEditorOperation, entry: LedgerEntry? = nil, categoryID: String? = nil) {
        editorTarget = LedgerEditorTarget(entry: entry, categoryID: categoryID,
                                          operation: operation, usesFullScreen: usesWorkspace)
    }

    private func editorBinding(fullScreen: Bool) -> Binding<LedgerEditorTarget?> {
        Binding(get: { editorTarget?.usesFullScreen == fullScreen ? editorTarget : nil },
                set: { value in
                    if value != nil || editorTarget?.usesFullScreen == fullScreen { editorTarget = value }
                })
    }

    private func editor(for target: LedgerEditorTarget) -> some View {
        let linkedRefunds: [LedgerEntry]
        switch target.operation {
        case .edit, .refund:
            linkedRefunds = target.entry.map { refundEntries(for: $0) } ?? []
        default:
            linkedRefunds = []
        }
        let refundLimit: Double?
        if case .refund = target.operation {
            refundLimit = target.entry.map { remainingRefundAmountCNY(for: $0) }
        } else {
            refundLimit = nil
        }
        return EntryEditorSheet(flow: flow, entry: target.entry, presetCategoryID: target.categoryID,
                                operation: target.operation, linkedRefundEntries: linkedRefunds,
                                refundLimitAmountCNY: refundLimit)
    }

    private func refundEntries(for entry: LedgerEntry) -> [LedgerEntry] {
        refundEntriesBySourceEntryID[entry.id] ?? []
    }

    private func remainingRefundAmountCNY(for entry: LedgerEntry) -> Double {
        max(entry.amount - (refundAmountBySourceEntryID[entry.id] ?? 0), 0)
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

    private func totalAmount(inMonthOf date: Date, refundAmounts: [UUID: Double]) -> Double {
        let range = monthRange(for: date)
        switch flow {
        case .expense:
            return entries
                .filter { range.containsHalfOpen($0.createdAt) && !$0.isRefundEntry }
                .reduce(0) { $0 + adjustedExpenseAmount(for: $1, refundAmounts: refundAmounts) }
        case .income:
            return entries
                .filter { range.containsHalfOpen($0.createdAt) }
                .reduce(0) { $0 + $1.incomeContribution }
        }
    }

    private func monthRange(for date: Date) -> DateInterval {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private func delete(_ entry: LedgerEntry) {
        withAnimation {
            if flow == .expense {
                for refundEntry in entries where refundEntry.refundSourceEntryID == entry.id {
                    modelContext.delete(refundEntry)
                }
            }
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    private func adjustedExpenseAmount(for entry: LedgerEntry, refundAmounts: [UUID: Double]) -> Double {
        guard entry.flow == .expense, !entry.isRefundEntry else { return 0 }
        return max(entry.amount - (refundAmounts[entry.id] ?? 0), 0)
    }

    private func isNewerLedgerEntry(_ lhs: LedgerEntry, than rhs: LedgerEntry) -> Bool {
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
