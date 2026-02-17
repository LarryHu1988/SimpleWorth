import SwiftUI

struct GoalEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var currencyStore = CurrencyStore.shared

    let goal: SavingsGoalRecord?

    @State private var name: String
    @State private var currentText: String
    @State private var targetText: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var selectedSymbol: String
    @State private var selectedTint: Int

    private let symbolOptions = [
        "airplane", "iphone", "shield.fill", "graduationcap.fill", "house.fill",
        "car.fill", "figure.run", "gift.fill", "camera.fill", "suitcase.fill"
    ]

    private let tintOptions: [Int] = [
        0x38BDF8, 0xA78BFA, 0x34D399, 0xF59E0B, 0xFB7185, 0x84CC16, 0x22D3EE, 0xC084FC
    ]

    init(goal: SavingsGoalRecord? = nil) {
        self.goal = goal
        _name = State(initialValue: goal?.name ?? "")
        _currentText = State(initialValue: goal.map { Self.amountString($0.currentAmount) } ?? "0")
        _targetText = State(initialValue: goal.map { Self.amountString($0.targetAmount) } ?? "")
        _hasDeadline = State(initialValue: goal?.deadline != nil)
        _deadline = State(initialValue: goal?.deadline ?? .now)
        _selectedSymbol = State(initialValue: goal?.symbol ?? "airplane")
        _selectedTint = State(initialValue: goal?.tintHex ?? 0x38BDF8)
    }

    private var parsedCurrent: Double? {
        Self.parseAmount(currentText)
    }

    private var parsedTarget: Double? {
        Self.parseAmount(targetText)
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard let parsedCurrent, parsedCurrent >= 0 else { return false }
        guard let parsedTarget, parsedTarget > 0 else { return false }
        return true
    }

    private var currencySymbol: String {
        let code = CurrencyCatalog.normalize(code: currencyStore.baseCurrencyCode)
        return CurrencyCatalog.symbol(for: code)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    nameCard
                    amountCard
                    deadlineCard
                    symbolCard
                    colorCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 26)
            }
            .navigationTitle(goal == nil ? "新增目标" : "编辑目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(SWTheme.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(goal == nil ? "保存" : "更新") {
                        save()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSave)
                }
            }
            .appBackground()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "目标名称", subtitle: "例如：旅行基金 / 应急金")

            TextField("输入目标名", text: $name)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .foregroundStyle(.white)
        }
        .fitnessCard()
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "金额设置", subtitle: "当前金额与目标金额")

            VStack(spacing: 10) {
                amountInputRow(title: "当前", text: $currentText)
                amountInputRow(title: "目标", text: $targetText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
        }
        .fitnessCard()
    }

    private func amountInputRow(title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(SWTheme.textSecondary)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Text(currencySymbol)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.84))

                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 44, alignment: .leading)
            }
        }
    }

    private var deadlineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "截止日期", subtitle: "可选，长期目标可关闭")

            Toggle("设置截止日期", isOn: $hasDeadline)
                .tint(SWTheme.accentBlue)
                .foregroundStyle(.white)

            if hasDeadline {
                DatePicker("", selection: $deadline, displayedComponents: [.date])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(SWTheme.accentBlue)
            }
        }
        .fitnessCard()
    }

    private var symbolCard: some View {
        let columns = [GridItem(.adaptive(minimum: 62), spacing: 10)]

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "目标图标", subtitle: "选择一个直观标识")

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(symbolOptions, id: \.self) { symbol in
                    Button {
                        selectedSymbol = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(
                                                selectedSymbol == symbol
                                                    ? Color.white.opacity(0.9)
                                                    : Color.white.opacity(0.1),
                                                lineWidth: selectedSymbol == symbol ? 1.5 : 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fitnessCard()
    }

    private var colorCard: some View {
        let columns = [GridItem(.adaptive(minimum: 44), spacing: 10)]

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "主题色", subtitle: "目标卡片颜色")

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(tintOptions, id: \.self) { hex in
                    let color = Color.sw(UInt(hex))
                    Button {
                        selectedTint = hex
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 30, height: 30)
                            .padding(6)
                            .background(
                                Circle()
                                    .stroke(
                                        selectedTint == hex ? Color.white.opacity(0.95) : Color.white.opacity(0.15),
                                        lineWidth: selectedTint == hex ? 1.8 : 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fitnessCard()
    }

    private func save() {
        guard let parsedCurrent, let parsedTarget else { return }

        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDeadline = hasDeadline ? deadline : nil

        if let goal {
            goal.name = finalName
            goal.currentAmount = parsedCurrent
            goal.targetAmount = parsedTarget
            goal.deadline = finalDeadline
            goal.symbol = selectedSymbol
            goal.tintHex = selectedTint
        } else {
            modelContext.insert(
                SavingsGoalRecord(
                    name: finalName,
                    symbol: selectedSymbol,
                    currentAmount: parsedCurrent,
                    targetAmount: parsedTarget,
                    deadline: finalDeadline,
                    tintHex: selectedTint
                )
            )
        }

        try? modelContext.save()
        dismiss()
    }

    private static func parseAmount(_ text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized)
    }

    private static func amountString(_ amount: Double) -> String {
        let raw = amount.formatted(.number.precision(.fractionLength(2)))
        return raw
            .replacingOccurrences(of: ".00", with: "")
            .replacingOccurrences(of: ",", with: "")
    }
}

struct DepositEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var currencyStore = CurrencyStore.shared

    let goals: [SavingsGoalRecord]

    @State private var selectedGoalID: UUID?
    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var date: Date = .now

    init(goals: [SavingsGoalRecord]) {
        self.goals = goals
        _selectedGoalID = State(initialValue: goals.first?.id)
    }

    private var selectedGoal: SavingsGoalRecord? {
        goals.first(where: { $0.id == selectedGoalID })
    }

    private var parsedAmount: Double? {
        let normalized = amountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized)
    }

    private var canSave: Bool {
        guard selectedGoal != nil else { return false }
        guard let parsedAmount, parsedAmount > 0 else { return false }
        return true
    }

    private var currencySymbol: String {
        let code = CurrencyCatalog.normalize(code: currencyStore.baseCurrencyCode)
        return CurrencyCatalog.symbol(for: code)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    goalPickerCard
                    amountCard
                    dateCard
                    noteCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 26)
            }
            .navigationTitle("记录存入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(SWTheme.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        save()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSave)
                }
            }
            .appBackground()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var goalPickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "选择目标", subtitle: "本次存入归属哪个小目标")

            Picker("目标", selection: $selectedGoalID) {
                ForEach(goals) { goal in
                    Text(goal.name).tag(Optional(goal.id))
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
        }
        .fitnessCard()
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "存入金额", subtitle: "将零散现金沉淀到小金库")

            HStack(spacing: 10) {
                Text(currencySymbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.84))

                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(SWTheme.accentGreen.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .fitnessCard()
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "日期", subtitle: "记录到账时间")

            DatePicker("", selection: $date, displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tint(SWTheme.accentGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitnessCard()
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "备注", subtitle: "可选，不填将使用默认文案")

            TextField("例如：工资日固定转入", text: $note)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .foregroundStyle(.white)
        }
        .fitnessCard()
    }

    private func save() {
        guard let goal = selectedGoal else { return }
        guard let parsedAmount, parsedAmount > 0 else { return }

        let finalNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteToSave = finalNote.isEmpty ? "手动存入" : finalNote

        goal.currentAmount += parsedAmount
        modelContext.insert(
            VaultDepositRecord(
                date: date,
                amount: parsedAmount,
                note: noteToSave,
                goal: goal
            )
        )

        try? modelContext.save()
        dismiss()
    }
}
