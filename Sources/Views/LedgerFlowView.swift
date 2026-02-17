import SwiftData
import SwiftUI

private struct EntryEditTarget: Identifiable {
    let id: UUID
    let entry: LedgerEntry
}

struct LedgerFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\LedgerEntry.createdAt, order: .reverse)]) private var allEntries: [LedgerEntry]

    let flow: FlowType

    @State private var showCreateSheet = false
    @State private var presetCategoryID: String?
    @State private var editingTarget: EntryEditTarget?
    @State private var copyTarget: EntryEditTarget?
    @State private var refundTarget: EntryEditTarget?
    @State private var pendingDeleteEntry: LedgerEntry?
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    @State private var selectedMonth = Calendar.current.component(.month, from: .now)
    @State private var showCategoryGrid = false

    private var categories: [CategoryItem] {
        CategoryLibrary.categories(for: flow)
    }

    private var entries: [LedgerEntry] {
        allEntries.filter { $0.flow == flow }
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
        return entries.filter { range.contains($0.createdAt) }
    }

    private var recentEntries: [LedgerEntry] {
        Array(selectedPeriodEntries.prefix(20))
    }

    private var selectedPeriodTotal: Double {
        totalAmount(inMonthOf: selectedPeriodDate)
    }

    private var previousPeriodTotal: Double {
        let previousMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedPeriodDate) ?? selectedPeriodDate
        return totalAmount(inMonthOf: previousMonthDate)
    }

    private var selectedPeriodLabel: String {
        "\(selectedYear)年\(selectedMonth)月"
    }

    private var compareText: String {
        guard previousPeriodTotal > 0 else {
            return selectedPeriodTotal > 0 ? "\(selectedPeriodLabel)新增 \(selectedPeriodTotal.cnyText)" : "\(selectedPeriodLabel)暂无记录"
        }

        let delta = (selectedPeriodTotal - previousPeriodTotal) / previousPeriodTotal
        if abs(delta) < 0.001 {
            return "较上月持平"
        }

        let ratioText = (abs(delta) * 100).formatted(.number.precision(.fractionLength(1)))
        if flow == .expense {
            return delta > 0 ? "较上月上升 \(ratioText)%" : "较上月下降 \(ratioText)%"
        }
        return delta > 0 ? "较上月增长 \(ratioText)%" : "较上月下降 \(ratioText)%"
    }

    private var ringProgress: Double {
        guard previousPeriodTotal > 0 else {
            return selectedPeriodTotal > 0 ? 1 : 0
        }

        return min(max(selectedPeriodTotal / previousPeriodTotal, 0), 1)
    }

    private var categoryTitle: String {
        flow == .expense ? "支出分类" : "收入分类"
    }

    private var categorySubtitle: String {
        flow == .expense ? "常见生活消费图标一键记账" : "工资、副业、理财等来源一屏管理"
    }

    private var recentTitle: String {
        flow == .expense ? "最近支出" : "最近收入"
    }

    private var recentSubtitle: String {
        flow == .expense ? "点按可编辑，左滑退款或删除，右滑复制（退款账单除外）" : "点按可编辑，左滑删除，右滑复制"
    }

    private var emptyTitle: String {
        flow == .expense ? "还没有支出记录" : "还没有收入记录"
    }

    private var emptySubtitle: String {
        flow == .expense
            ? "\(selectedPeriodLabel)暂无记录，右上角 + 添加第一笔支出"
            : "\(selectedPeriodLabel)暂无记录，右上角 + 添加第一笔收入"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                FlowSummaryCard(
                    flow: flow,
                    periodTitle: "\(selectedPeriodLabel)\(flow.rawValue)",
                    amount: selectedPeriodTotal,
                    compareText: compareText,
                    ringProgress: ringProgress
                )

                categoryToggleCard

                if showCategoryGrid {
                    CategoryGridSection(
                        title: categoryTitle,
                        subtitle: categorySubtitle,
                        categories: categories,
                        onTapCategory: { category in
                            presentCreateSheet(categoryID: category.id)
                        }
                    )
                }

                transactionCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .navigationTitle(flow.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: SWTheme.toolbarControlSpacing) {
                    yearMenu
                    monthMenu

                    Button {
                        presentCreateSheet(categoryID: nil)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(flow.accent)
                    }
                    .accessibilityLabel("新增\(flow.rawValue)")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet, onDismiss: {
            presetCategoryID = nil
        }) {
            EntryEditorSheet(flow: flow, presetCategoryID: presetCategoryID, operation: .create)
        }
        .sheet(item: $editingTarget) { target in
            EntryEditorSheet(flow: flow, entry: target.entry, operation: .edit)
        }
        .sheet(item: $copyTarget) { target in
            EntryEditorSheet(flow: flow, entry: target.entry, operation: .copy)
        }
        .sheet(item: $refundTarget) { target in
            EntryEditorSheet(flow: target.entry.flow, entry: target.entry, operation: .refund)
        }
        .onChange(of: availableYears) { _, _ in
            normalizeSelectionIfNeeded()
        }
        .onAppear {
            resetToCurrentPeriod()
            showCategoryGrid = false
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
            withAnimation(.easeInOut(duration: 0.18)) {
                showCategoryGrid.toggle()
            }
            HapticService.selection()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: showCategoryGrid ? "square.grid.2x2.fill" : "square.grid.2x2")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(flow.accent)

                Text(showCategoryGrid ? "隐藏\(categoryTitle)" : "显示\(categoryTitle)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: showCategoryGrid ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .fitnessCard()
    }

    private var yearMenu: some View {
        Menu {
            ForEach(availableYears, id: \.self) { year in
                Button {
                    selectedYear = year
                    HapticService.selection()
                } label: {
                    if year == selectedYear {
                        Label("\(year)年", systemImage: "checkmark")
                    } else {
                        Text("\(year)年")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(selectedYear)年")
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

    private var monthMenu: some View {
        Menu {
            ForEach(1...12, id: \.self) { month in
                Button {
                    selectedMonth = month
                    HapticService.selection()
                } label: {
                    if month == selectedMonth {
                        Label("\(month)月", systemImage: "checkmark")
                    } else {
                        Text("\(month)月")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(selectedMonth)月")
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

    private var transactionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: recentTitle, subtitle: recentSubtitle)

            if recentEntries.isEmpty {
                EmptyStateCard(
                    title: emptyTitle,
                    subtitle: emptySubtitle,
                    symbol: flow == .expense ? "tray.fill" : "banknote.fill"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(recentEntries) { entry in
                        SwipeableLedgerRow(
                            entry: entry,
                            showCopyAction: !entry.isRefundEntry,
                            showRefundAction: flow == .expense,
                            onTap: {
                                editingTarget = EntryEditTarget(id: entry.id, entry: entry)
                            },
                            onCopy: {
                                copyTarget = EntryEditTarget(id: entry.id, entry: entry)
                            },
                            onRefund: {
                                guard flow == .expense else { return }
                                refundTarget = EntryEditTarget(id: entry.id, entry: entry)
                            },
                            onDelete: {
                                pendingDeleteEntry = entry
                            }
                        )
                    }
                }
            }
        }
        .fitnessCard()
    }

    private func presentCreateSheet(categoryID: String?) {
        presetCategoryID = categoryID
        showCreateSheet = true
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

    private func totalAmount(inMonthOf date: Date) -> Double {
        let range = monthRange(for: date)
        return entries
            .filter { range.contains($0.createdAt) }
            .reduce(0) { $0 + $1.flowPageContribution }
    }

    private func monthRange(for date: Date) -> DateInterval {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private func delete(_ entry: LedgerEntry) {
        withAnimation {
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }
}
