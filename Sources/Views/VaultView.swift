import SwiftData
import SwiftUI

private struct GoalEditTarget: Identifiable {
    let id: UUID
    let goal: SavingsGoalRecord
}

struct VaultView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @State private var overviewState = StatsPanelState()

    @Query(sort: [SortDescriptor(\SavingsGoalRecord.createdAt, order: .forward)])
    private var goals: [SavingsGoalRecord]

    @Query(sort: [SortDescriptor(\VaultDepositRecord.date, order: .reverse)])
    private var deposits: [VaultDepositRecord]
    @Query(sort: [SortDescriptor(\LedgerEntry.createdAt, order: .reverse)])
    private var ledgerEntries: [LedgerEntry]

    @State private var showCreateGoalSheet = false
    @State private var showDepositSheet = false
    @State private var editingGoal: GoalEditTarget?
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    @State private var selectedMonth = Calendar.current.component(.month, from: .now)
    @State private var hasInitializedPeriod = false
    private var totalCurrent: Double {
        goals.reduce(0) { $0 + $1.currentAmount }
    }

    private var totalTarget: Double {
        goals.reduce(0) { $0 + $1.targetAmount }
    }

    private var totalProgress: Double {
        guard totalTarget > 0 else { return 0 }
        return min(max(totalCurrent / totalTarget, 0), 1)
    }

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: .now)
        let years = Set(deposits.map { Calendar.current.component(.year, from: $0.date) }
                        + ledgerEntries.map { Calendar.current.component(.year, from: $0.createdAt) } + [currentYear])
        return years.sorted(by: >)
    }

    private var selectedPeriodDeposits: [VaultDepositRecord] {
        deposits.filter {
            let year = Calendar.current.component(.year, from: $0.date)
            let month = Calendar.current.component(.month, from: $0.date)
            return year == selectedYear && month == selectedMonth
        }
    }

    private var selectedPeriodLabel: String {
        L10n.yearMonth(year: selectedYear, month: selectedMonth, locale: locale)
    }

    var body: some View {
        SWWorkspacePage {
            VStack(spacing: 18) {
                vaultOverview
                goalsCard
                depositsCard
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        } secondary: {
            StatsView(section: .overview, year: $selectedYear, month: $selectedMonth, state: overviewState)
        }
        .fixedMainPageTitle("金库".appLocalized(in: locale))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                yearMenu
                monthMenu

                Menu {
                    Button {
                        showCreateGoalSheet = true
                    } label: {
                        Label("新增目标", systemImage: "target")
                    }

                    Button {
                        showDepositSheet = true
                    } label: {
                        Label("记录存入", systemImage: "arrow.down.circle")
                    }
                    .disabled(goals.isEmpty)
                } label: {
                    Label("新增".appLocalized(in: locale), systemImage: "plus.circle.fill")
                        .foregroundStyle(SWTheme.accentBlue)
                }
                .accessibilityLabel("新增")
            }
        }
        .sheet(isPresented: $showCreateGoalSheet) {
            GoalEditorSheet()
        }
        .sheet(isPresented: $showDepositSheet) {
            DepositEditorSheet(goals: goals)
        }
        .sheet(item: $editingGoal) { target in
            GoalEditorSheet(goal: target.goal)
        }
        .onChange(of: availableYears) { _, _ in
            normalizeSelectionIfNeeded()
        }
        .onAppear {
            if !hasInitializedPeriod {
                hasInitializedPeriod = true
                resetToCurrentPeriod()
            }
        }
        .appBackground()
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

    private var vaultOverview: some View {
        SWOverviewLayout(preferredRingSize: 104) {
            Text("当前小金库")
                .font(.headline.weight(.semibold))
                .foregroundStyle(SWTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .accessibilityIdentifier("vault.overview.title")

            Text(totalCurrent.cnyText(in: locale))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(SWTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .monospacedDigit()
                .accessibilityIdentifier("vault.overview.amount")

            Text(L10n.string("vault.totalTarget", locale: locale, totalTarget.cnyText(in: locale)))
                .font(.footnote)
                .foregroundStyle(SWTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ZStack {
                ProgressRing(progress: totalProgress, tint: SWTheme.accentBlue, lineWidth: 12)

                VStack(spacing: 2) {
                    Text("进度")
                        .font(.caption2)
                        .foregroundStyle(SWTheme.textSecondary)
                    Text("\((totalProgress * 100).formatted(.number.precision(.fractionLength(0))))%")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(SWTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .accessibilityIdentifier("vault.overview.ring")
        }
        .fitnessCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("vault.overview")
    }

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "小目标", subtitle: "点按可编辑，左滑可删除")

            if goals.isEmpty {
                EmptyStateCard(
                    title: "还没有小目标",
                    subtitle: "右上角 + 新增目标，再开始记录存入",
                    symbol: "target"
                )
            } else {
                ForEach(goals) { goal in
                    GoalProgressCard(goal: goal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingGoal = GoalEditTarget(id: goal.id, goal: goal)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(goal)
                            } label: {
                                Label("删除", systemImage: "trash.fill")
                            }

                            Button {
                                editingGoal = GoalEditTarget(id: goal.id, goal: goal)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(SWTheme.accentBlue)
                        }
                }
            }
        }
        .fitnessCard()
    }

    private var depositsCard: some View {
        let recentDeposits = Array(selectedPeriodDeposits.prefix(20))
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "最近存入", subtitle: "记录会同步更新目标进度")

            if recentDeposits.isEmpty {
                EmptyStateCard(
                    title: "暂无存入记录",
                    subtitle: L10n.string("vault.emptyDeposits", locale: locale, selectedPeriodLabel),
                    symbol: "tray.fill"
                )
            } else {
                ForEach(recentDeposits) { item in
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.note)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SWTheme.primaryText)

                            HStack(spacing: 6) {
                                Text(item.date.depositDateText(in: locale))
                                    .font(.caption)
                                    .foregroundStyle(SWTheme.textSecondary)

                                if let goal = item.goal {
                                    Text(goal.name)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(goal.tintColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(goal.tintColor.opacity(0.2))
                                        )
                                }
                            }
                        }

                        Spacer(minLength: 8)

                        Text(item.amount.cnyText(in: locale))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(SWTheme.accentGreen)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("vault.deposit.\(item.id)")
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(item)
                        } label: {
                            Label("删除", systemImage: "trash.fill")
                        }
                    }
                }
            }
        }
        .fitnessCard()
    }

    private func delete(_ goal: SavingsGoalRecord) {
        withAnimation {
            modelContext.delete(goal)
            try? modelContext.save()
        }
    }

    private func delete(_ deposit: VaultDepositRecord) {
        withAnimation {
            if let goal = deposit.goal {
                goal.currentAmount = max(0, goal.currentAmount - deposit.amount)
            }
            modelContext.delete(deposit)
            try? modelContext.save()
        }
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
}

private struct GoalProgressCard: View {
    @Environment(\.locale) private var locale
    let goal: SavingsGoalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(goal.tintColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: goal.symbol)
                        .foregroundStyle(goal.tintColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SWTheme.primaryText)
                    Text(L10n.string("vault.deadline", locale: locale, goal.deadlineText(in: locale)))
                        .font(.caption)
                        .foregroundStyle(SWTheme.textSecondary)
                }

                Spacer(minLength: 8)

                Text("\((goal.progress * 100).formatted(.number.precision(.fractionLength(0))))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(goal.tintColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(goal.tintColor.opacity(0.2))
                    )
            }

            VStack(spacing: 6) {
                HStack {
                    Text(goal.currentAmount.cnyText(in: locale))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SWTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer()
                    Text(goal.targetAmount.cnyText(in: locale))
                        .font(.caption)
                        .foregroundStyle(SWTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.12))
                        Capsule(style: .continuous)
                            .fill(goal.tintColor.gradient)
                            .frame(width: proxy.size.width * goal.progress)
                            .chartEntrance(.horizontal)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}
