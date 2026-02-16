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

    private var categories: [CategoryItem] {
        CategoryLibrary.categories(for: flow)
    }

    private var entries: [LedgerEntry] {
        allEntries.filter { $0.flow == flow }
    }

    private var recentEntries: [LedgerEntry] {
        Array(entries.prefix(20))
    }

    private var currentMonthTotal: Double {
        totalAmount(inMonthOf: .now)
    }

    private var previousMonthTotal: Double {
        let previousMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
        return totalAmount(inMonthOf: previousMonthDate)
    }

    private var compareText: String {
        guard previousMonthTotal > 0 else {
            return currentMonthTotal > 0 ? "本月新增 \(currentMonthTotal.cnyText)" : "本月暂无记录"
        }

        let delta = (currentMonthTotal - previousMonthTotal) / previousMonthTotal
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
        guard previousMonthTotal > 0 else {
            return currentMonthTotal > 0 ? 1 : 0
        }

        return min(max(currentMonthTotal / previousMonthTotal, 0), 1)
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
        flow == .expense ? "点按可编辑，左滑可删除" : "点按可编辑，左滑可删除"
    }

    private var emptyTitle: String {
        flow == .expense ? "还没有支出记录" : "还没有收入记录"
    }

    private var emptySubtitle: String {
        flow == .expense ? "右上角 + 添加第一笔支出" : "右上角 + 添加第一笔收入"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                FlowSummaryCard(
                    flow: flow,
                    amount: currentMonthTotal,
                    compareText: compareText,
                    ringProgress: ringProgress
                )

                CategoryGridSection(
                    title: categoryTitle,
                    subtitle: categorySubtitle,
                    categories: categories,
                    onTapCategory: { category in
                        presentCreateSheet(categoryID: category.id)
                    }
                )

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
                Button {
                    presentCreateSheet(categoryID: nil)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(flow.accent)
                }
                .accessibilityLabel("新增\(flow.rawValue)")
            }
        }
        .sheet(isPresented: $showCreateSheet, onDismiss: {
            presetCategoryID = nil
        }) {
            EntryEditorSheet(flow: flow, presetCategoryID: presetCategoryID)
        }
        .sheet(item: $editingTarget) { target in
            EntryEditorSheet(flow: flow, entry: target.entry)
        }
        .appBackground()
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
                        LedgerRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingTarget = EntryEditTarget(id: entry.id, entry: entry)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(entry)
                                } label: {
                                    Label("删除", systemImage: "trash.fill")
                                }

                                Button {
                                    editingTarget = EntryEditTarget(id: entry.id, entry: entry)
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(SWTheme.accentBlue)
                            }
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

    private func totalAmount(inMonthOf date: Date) -> Double {
        let calendar = Calendar.current
        return entries
            .filter { calendar.isDate($0.createdAt, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    private func delete(_ entry: LedgerEntry) {
        withAnimation {
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }
}
