import SwiftUI

struct EntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let flow: FlowType
    let entry: LedgerEntry?
    let presetCategoryID: String?

    @State private var note: String
    @State private var amountText: String
    @State private var date: Date
    @State private var selectedCategoryID: String

    init(flow: FlowType, entry: LedgerEntry? = nil, presetCategoryID: String? = nil) {
        self.flow = flow
        self.entry = entry
        self.presetCategoryID = presetCategoryID

        let fallback = CategoryLibrary.defaultCategory(for: flow)
        let editingCategory = entry.map {
            CategoryItem(
                flow: flow,
                name: $0.categoryName,
                symbol: $0.categorySymbol,
                colorHex: $0.categoryColorHex
            )
        }

        _note = State(initialValue: entry?.note ?? "")
        _amountText = State(initialValue: entry.map { Self.amountString($0.amount) } ?? "")
        _date = State(initialValue: entry?.createdAt ?? .now)
        _selectedCategoryID = State(initialValue: presetCategoryID ?? editingCategory?.id ?? fallback.id)
    }

    private var categories: [CategoryItem] {
        CategoryLibrary.categories(for: flow)
    }

    private var selectedCategory: CategoryItem {
        categories.first(where: { $0.id == selectedCategoryID })
            ?? CategoryLibrary.defaultCategory(for: flow)
    }

    private var normalizedAmount: Double? {
        let normalizedText = amountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalizedText)
    }

    private var canSave: Bool {
        guard let normalizedAmount, normalizedAmount > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    amountCard
                    noteCard
                    dateCard
                    categoryCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 26)
            }
            .navigationTitle(entry == nil ? "新增\(flow.rawValue)" : "编辑\(flow.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(SWTheme.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(entry == nil ? "保存" : "更新") {
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

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "金额", subtitle: "输入本次\(flow.rawValue)金额")

            HStack(spacing: 12) {
                Text(flow == .expense ? "-" : "+")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(flow.accent)

                TextField("0", text: $amountText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .keyboardType(.decimalPad)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(flow.accent.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .fitnessCard()
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "备注", subtitle: "账单描述")

            TextField("例如：午餐简餐 / 月度工资", text: $note)
                .textInputAutocapitalization(.never)
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

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "日期", subtitle: "选择入账日期")

            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(flow.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
        }
        .fitnessCard()
    }

    private var categoryCard: some View {
        let columns = [GridItem(.adaptive(minimum: 70), spacing: 10)]

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "分类", subtitle: "快速选择图标分类")

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(categories) { category in
                    Button {
                        selectedCategoryID = category.id
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(category.color.opacity(0.18))
                                    .frame(width: 44, height: 44)

                                Image(systemName: category.symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(category.color)
                            }

                            Text(category.name)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            selectedCategoryID == category.id
                                                ? category.color.opacity(0.92)
                                                : Color.white.opacity(0.08),
                                            lineWidth: selectedCategoryID == category.id ? 1.6 : 1
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

    private func save() {
        guard let amount = normalizedAmount, amount > 0 else {
            return
        }

        let finalNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteToSave = finalNote.isEmpty ? selectedCategory.name : finalNote

        if let entry {
            entry.amount = amount
            entry.note = noteToSave
            entry.createdAt = date
            entry.flow = flow
            entry.categoryName = selectedCategory.name
            entry.categorySymbol = selectedCategory.symbol
            entry.categoryColorHex = selectedCategory.colorHex
        } else {
            let newEntry = LedgerEntry(
                createdAt: date,
                amount: amount,
                note: noteToSave,
                flow: flow,
                category: selectedCategory
            )
            modelContext.insert(newEntry)
        }

        try? modelContext.save()
        dismiss()
    }

    private static func amountString(_ amount: Double) -> String {
        let raw = amount.formatted(.number.precision(.fractionLength(2)))
        return raw
            .replacingOccurrences(of: ".00", with: "")
            .replacingOccurrences(of: ",", with: "")
    }
}
