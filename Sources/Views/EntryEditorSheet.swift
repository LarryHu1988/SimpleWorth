import SwiftUI

enum EntryEditorOperation {
    case create
    case edit
    case copy
    case refund
}

@MainActor
struct EntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("settings.detailedTimeEnabled") private var detailedTimeEnabled = false
    @ObservedObject private var currencyStore = CurrencyStore.shared

    let flow: FlowType
    let entry: LedgerEntry?
    let presetCategoryID: String?
    let operation: EntryEditorOperation

    @State private var note: String
    @State private var amountText: String
    @State private var date: Date
    @State private var selectedCategoryID: String
    @State private var selectedCurrencyCode: String
    @State private var showCurrencyPicker = false

    init(
        flow: FlowType,
        entry: LedgerEntry? = nil,
        presetCategoryID: String? = nil,
        operation: EntryEditorOperation = .create
    ) {
        self.flow = flow
        self.entry = entry
        self.presetCategoryID = presetCategoryID
        self.operation = operation

        let fallback = CategoryLibrary.defaultCategory(for: flow)
        let editingCategory = entry.map {
            CategoryItem(
                flow: $0.flow,
                name: $0.categoryName,
                symbol: $0.categorySymbol,
                colorHex: $0.categoryColorHex
            )
        }
        let refundCategory = CategoryLibrary.category(named: CategoryLibrary.refundCategoryName, flow: flow)
        let preferredCategory: CategoryItem
        if operation == .refund {
            preferredCategory = refundCategory ?? fallback
        } else {
            preferredCategory = editingCategory ?? fallback
        }

        let initialNote: String
        switch operation {
        case .create:
            initialNote = ""
        case .edit, .copy:
            initialNote = entry?.note ?? ""
        case .refund:
            let source = entry?.note.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            initialNote = source.isEmpty ? "退款" : "退款：\(source)"
        }

        let initialDate: Date
        switch operation {
        case .create:
            initialDate = .now
        case .edit:
            initialDate = entry?.createdAt ?? .now
        case .copy, .refund:
            initialDate = .now
        }

        let initialCurrencyCode = CurrencyCatalog.normalize(
            code: entry?.currencyCode ?? CurrencyCatalog.defaultBaseCode
        )

        _note = State(initialValue: initialNote)
        _amountText = State(initialValue: entry.map { Self.amountString($0.displayAmount) } ?? "")
        _date = State(initialValue: initialDate)
        _selectedCategoryID = State(initialValue: presetCategoryID ?? preferredCategory.id)
        _selectedCurrencyCode = State(initialValue: initialCurrencyCode)
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

    private var normalizedCurrencyCode: String {
        CurrencyCatalog.normalize(code: selectedCurrencyCode)
    }

    private var rateToCNY: Double? {
        if let liveRate = currencyStore.rateToCNY(for: normalizedCurrencyCode) {
            return liveRate
        }

        if
            let entry,
            CurrencyCatalog.normalize(code: entry.currencyCode) == normalizedCurrencyCode,
            entry.exchangeRateToCNY > 0
        {
            return entry.exchangeRateToCNY
        }

        return nil
    }

    private var convertedAmountCNY: Double? {
        guard let normalizedAmount, let rateToCNY else { return nil }
        return normalizedAmount * rateToCNY
    }

    private var selectedCurrencyDescriptor: CurrencyDescriptor {
        CurrencyCatalog.descriptor(for: normalizedCurrencyCode)
    }

    private var selectedCurrencySymbol: String {
        selectedCurrencyDescriptor.symbol
    }

    private var currencyRateText: String {
        guard let rateToCNY else { return "汇率加载中..." }
        return "1 \(normalizedCurrencyCode) ≈ \(rateToCNY.currencyText(code: "CNY", fractionDigits: 4))"
    }

    private var convertedPreviewText: String {
        guard let convertedAmountCNY, convertedAmountCNY > 0 else { return "" }
        return "折合 \(convertedAmountCNY.currencyText(code: "CNY", fractionDigits: 2))"
    }

    private var titleText: String {
        switch operation {
        case .create:
            return "新增\(flow.rawValue)"
        case .edit:
            return "编辑\(flow.rawValue)"
        case .copy:
            return "复制\(flow.rawValue)"
        case .refund:
            return "退款录入"
        }
    }

    private var saveButtonTitle: String {
        switch operation {
        case .create:
            return "保存"
        case .edit:
            return "更新"
        case .copy:
            return "复制"
        case .refund:
            return "退款"
        }
    }

    private var isRefundOperation: Bool {
        operation == .refund
    }

    private var sourceEntryAmountTitle: String {
        guard let sourceFlow = entry?.flow else { return "原账单金额" }
        return "\(sourceFlow.rawValue)金额"
    }

    private var sourceEntryAmountValueText: String {
        guard let entry else { return "--" }
        let code = CurrencyCatalog.normalize(code: entry.currencyCode)
        let digits = CurrencyCatalog.fractionDigits(for: code)
        return entry.displayAmount.formatted(.number.precision(.fractionLength(digits)))
    }

    private var sourceAmountSign: String {
        (entry?.flow ?? flow) == .expense ? "-" : "+"
    }

    private var sourceAmountSignTint: Color {
        (entry?.flow ?? flow).accent
    }

    private var refundAmountSignTint: Color {
        SWTheme.accentBlue
    }

    private var canSave: Bool {
        guard let normalizedAmount, normalizedAmount > 0 else { return false }
        guard convertedAmountCNY != nil, rateToCNY != nil else { return false }
        if isRefundOperation, let sourceAmount = entry?.displayAmount, normalizedAmount > sourceAmount {
            return false
        }
        return true
    }

    private var datePickerComponents: DatePickerComponents {
        detailedTimeEnabled ? [.date, .hourAndMinute] : [.date]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if isRefundOperation {
                        sourceAmountCard
                        refundAmountCard
                    } else {
                        amountCard
                    }
                    noteCard
                    dateCard
                    if !isRefundOperation {
                        categoryCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 26)
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(SWTheme.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(saveButtonTitle) {
                        save()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSave)
                }
            }
            .appBackground()
            .task {
                await currencyStore.refreshRates(force: false)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showCurrencyPicker) {
            CurrencyPickerSheet(selectedCode: $selectedCurrencyCode)
        }
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "金额", subtitle: "输入本次\(flow.rawValue)金额")

            HStack(spacing: 12) {
                Text(sourceAmountSign)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(sourceAmountSignTint)

                Text(selectedCurrencySymbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.84))

                TextField("0", text: $amountText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: .infinity, alignment: .leading)

                currencySelectorButton(allowsSelection: true)
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

            HStack(spacing: 8) {
                Spacer()

                Text(currencyRateText)
                    .font(.caption)
                    .foregroundStyle(SWTheme.textSecondary)

                if !convertedPreviewText.isEmpty {
                    Text("· \(convertedPreviewText)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SWTheme.accentBlue)
                }
            }
        }
        .fitnessCard()
    }

    private var sourceAmountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: sourceEntryAmountTitle, subtitle: "原账单金额，仅用于参考")

            HStack(spacing: 12) {
                Text(sourceAmountSign)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(sourceAmountSignTint)

                Text(selectedCurrencySymbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.84))

                Text(sourceEntryAmountValueText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)

                currencySelectorButton(allowsSelection: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(SWTheme.textSecondary.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .fitnessCard()
    }

    private var refundAmountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "退款金额", subtitle: "输入本次退款金额")

            HStack(spacing: 12) {
                Text("+")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(refundAmountSignTint)

                Text(selectedCurrencySymbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.84))

                TextField("0", text: $amountText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: .infinity, alignment: .leading)

                currencySelectorButton(allowsSelection: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(refundAmountSignTint.opacity(0.42), lineWidth: 1)
                    )
            )

            HStack(spacing: 8) {
                Spacer()

                Text(currencyRateText)
                    .font(.caption)
                    .foregroundStyle(SWTheme.textSecondary)

                if !convertedPreviewText.isEmpty {
                    Text("· \(convertedPreviewText)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SWTheme.accentBlue)
                }
            }
        }
        .fitnessCard()
    }

    @ViewBuilder
    private func currencySelectorButton(allowsSelection: Bool) -> some View {
        if allowsSelection {
            Button {
                showCurrencyPicker = true
            } label: {
                currencyBadge(showChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            currencyBadge(showChevron: false)
        }
    }

    private func currencyBadge(showChevron: Bool) -> some View {
        HStack(spacing: 4) {
            Text(selectedCurrencyDescriptor.flag)
                .font(.title3)

            if showChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .accessibilityLabel("币种：\(selectedCurrencyDescriptor.code)")
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

            DatePicker("", selection: $date, displayedComponents: datePickerComponents)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tint(flow.accent)
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
        guard
            let originalAmount = normalizedAmount, originalAmount > 0,
            let amountInCNY = convertedAmountCNY,
            let exchangeRateToCNY = rateToCNY
        else {
            return
        }

        let finalNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryToSave: CategoryItem = {
            if isRefundOperation, let refundCategory = CategoryLibrary.category(
                named: CategoryLibrary.refundCategoryName,
                flow: flow
            ) {
                return refundCategory
            }
            return selectedCategory
        }()
        let noteFallback = isRefundOperation ? CategoryLibrary.refundCategoryName : categoryToSave.name
        let noteToSave = finalNote.isEmpty ? noteFallback : finalNote
        let finalDate = detailedTimeEnabled ? date : Calendar.current.startOfDay(for: date)
        let currencyCode = normalizedCurrencyCode

        if operation == .edit, let entry {
            entry.amount = amountInCNY
            entry.originalAmount = originalAmount
            entry.currencyCode = currencyCode
            entry.exchangeRateToCNY = exchangeRateToCNY
            entry.note = noteToSave
            entry.createdAt = finalDate
            entry.flow = flow
            entry.categoryName = categoryToSave.name
            entry.categorySymbol = categoryToSave.symbol
            entry.categoryColorHex = categoryToSave.colorHex
        } else {
            let newEntry = LedgerEntry(
                createdAt: finalDate,
                amount: amountInCNY,
                originalAmount: originalAmount,
                currencyCode: currencyCode,
                exchangeRateToCNY: exchangeRateToCNY,
                note: noteToSave,
                flow: flow,
                category: categoryToSave
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

@MainActor
private struct CurrencyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyStore = CurrencyStore.shared

    @Binding var selectedCode: String
    @State private var searchText = ""

    private var filteredDescriptors: [CurrencyDescriptor] {
        let list = currencyStore.descriptors
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return list }

        return list.filter { descriptor in
            descriptor.code.localizedCaseInsensitiveContains(keyword) ||
                descriptor.name.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("币种列表") {
                    ForEach(filteredDescriptors) { descriptor in
                        Button {
                            selectedCode = descriptor.code
                            HapticService.selection()
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Text(descriptor.flag)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(descriptor.code)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(descriptor.name)
                                        .font(.caption)
                                        .foregroundStyle(SWTheme.textSecondary)
                                }

                                Spacer()

                                if descriptor.code == CurrencyCatalog.normalize(code: selectedCode) {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(SWTheme.accentGreen)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("选择币种")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜索币种代码或名称")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(SWTheme.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("刷新") {
                        Task {
                            await currencyStore.refreshRates(force: true)
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(currencyStore.isLoading)
                }
            }
            .task {
                await currencyStore.refreshRates(force: false)
            }
        }
    }
}
