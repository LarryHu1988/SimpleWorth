import SwiftUI
import SwiftData
import UIKit

enum EntryEditorOperation {
    case create
    case edit
    case copy
    case refund
    case editRefund
}

private enum EntryEditorFocusedField: Hashable {
    case amount
    case note
}

@MainActor
struct EntryEditorSheet: View {
    @ScaledMetric(relativeTo: .caption2) private var minimumCategoryCellWidth: CGFloat = 68
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @AppStorage("settings.detailedTimeEnabled") private var detailedTimeEnabled = false
    @ObservedObject private var currencyStore = CurrencyStore.shared
    @Query(sort: [SortDescriptor(\TagRecord.sortOrder), SortDescriptor(\TagRecord.createdAt)]) private var allTags: [TagRecord]
    @FocusState private var focusedField: EntryEditorFocusedField?
    @State private var amountIsFocused = false

    let flow: FlowType
    let entry: LedgerEntry?
    let presetCategoryID: String?
    let operation: EntryEditorOperation
    let linkedRefundEntries: [LedgerEntry]
    let refundLimitAmountCNY: Double?
    let onSaved: (() -> Void)?

    @State private var note: String
    @State private var amountText: String
    @State private var date: Date
    @State private var selectedCategoryID: String
    @State private var selectedCurrencyCode: String
    @State private var selectedTagNames: [String]
    @State private var showCurrencyPicker = false
    @State private var editingRefundEntry: LedgerEntry?
    @State private var refundDetailRefreshID = UUID()
    @State private var editorWidth: CGFloat = 0

    private var usesInlineKeyboardAccessory: Bool {
        editorWidth >= 500
    }

    init(
        flow: FlowType,
        entry: LedgerEntry? = nil,
        presetCategoryID: String? = nil,
        operation: EntryEditorOperation = .create,
        linkedRefundEntries: [LedgerEntry] = [],
        refundLimitAmountCNY: Double? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        self.flow = flow
        self.entry = entry
        self.presetCategoryID = presetCategoryID
        self.operation = operation
        self.linkedRefundEntries = linkedRefundEntries
        self.refundLimitAmountCNY = refundLimitAmountCNY
        self.onSaved = onSaved

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
        if operation == .refund || operation == .editRefund {
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
            initialNote = source.isEmpty ? "退款".appLocalized : L10n.string("entry.refundNotePrefix", source)
        case .editRefund:
            initialNote = entry?.note ?? ""
        }

        let initialDate: Date
        switch operation {
        case .create:
            initialDate = .now
        case .edit, .editRefund:
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
        _selectedTagNames = State(initialValue: entry?.tagNames ?? [])
    }

    private var categories: [CategoryItem] {
        var result = CategoryLibrary.categories(for: flow)
        if let entry, entry.flow == flow {
            let savedCategory = CategoryItem(
                flow: flow, name: entry.categoryName,
                symbol: entry.categorySymbol, colorHex: entry.categoryColorHex
            )
            if !result.contains(where: { $0.id == savedCategory.id }) {
                result.insert(savedCategory, at: 0)
            }
        }
        return result
    }

    private var selectedCategory: CategoryItem {
        categories.first(where: { $0.id == selectedCategoryID })
            ?? CategoryLibrary.defaultCategory(for: flow)
    }

    private var managedTags: [TagRecord] {
        TagOrdering.visible(allTags)
    }

    private var normalizedAmount: Double? {
        AmountExpressionEvaluator.evaluate(amountText)
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

    private var amountSubtitle: String {
        L10n.string("entry.amountSubtitle", locale: locale, flow.localizedTitle(in: locale))
    }

    private var currencyRateText: String {
        guard let rateToCNY else { return "汇率加载中...".appLocalized(in: locale) }
        return L10n.string(
            "entry.currencyRate",
            locale: locale,
            normalizedCurrencyCode,
            rateToCNY.currencyText(code: "CNY", fractionDigits: 4, locale: locale)
        )
    }

    private var convertedPreviewText: String {
        guard let convertedAmountCNY, convertedAmountCNY > 0 else { return "" }
        return L10n.string(
            "entry.convertedAmount",
            locale: locale,
            convertedAmountCNY.currencyText(code: "CNY", fractionDigits: 2, locale: locale)
        )
    }

    private var titleText: String {
        switch operation {
        case .create:
            return L10n.string("entry.createFlow", locale: locale, flow.localizedTitle(in: locale))
        case .edit:
            return L10n.string("entry.editFlow", locale: locale, flow.localizedTitle(in: locale))
        case .copy:
            return L10n.string("entry.copyFlow", locale: locale, flow.localizedTitle(in: locale))
        case .refund:
            return "退款录入".appLocalized(in: locale)
        case .editRefund:
            return "编辑退款".appLocalized(in: locale)
        }
    }

    private var saveButtonTitle: String {
        switch operation {
        case .create:
            return "保存".appLocalized(in: locale)
        case .edit:
            return "更新".appLocalized(in: locale)
        case .copy:
            return "复制".appLocalized(in: locale)
        case .refund:
            return "退款".appLocalized(in: locale)
        case .editRefund:
            return "更新".appLocalized(in: locale)
        }
    }

    private var isCreatingRefundOperation: Bool {
        operation == .refund
    }

    private var isEditingRefundOperation: Bool {
        operation == .editRefund
    }

    private var isRefundForm: Bool {
        isCreatingRefundOperation || isEditingRefundOperation
    }

    private var sourceEntryAmountTitle: String {
        guard let sourceFlow = entry?.flow else { return "原账单金额".appLocalized(in: locale) }
        return L10n.string("entry.sourceAmountTitle", locale: locale, sourceFlow.localizedTitle(in: locale))
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
        guard let convertedAmountCNY, rateToCNY != nil else { return false }

        if isRefundForm, let refundLimitAmountCNY, convertedAmountCNY > refundLimitAmountCNY + 0.005 {
            return false
        }

        if operation == .edit, entry?.isRefundEntry == false, convertedAmountCNY + 0.005 < linkedRefundTotalCNY {
            return false
        }

        return true
    }

    private var sortedLinkedRefundEntries: [LedgerEntry] {
        linkedRefundEntries.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }

            if lhs.resolvedRecordedAt != rhs.resolvedRecordedAt {
                return lhs.resolvedRecordedAt > rhs.resolvedRecordedAt
            }

            return lhs.id.uuidString > rhs.id.uuidString
        }
    }

    private var shouldShowRefundDetail: Bool {
        !isRefundForm && !sortedLinkedRefundEntries.isEmpty
    }

    private var linkedRefundTotalCNY: Double {
        sortedLinkedRefundEntries.reduce(0) { $0 + $1.amount }
    }

    private var linkedRefundTotalText: String {
        linkedRefundTotalCNY.currencyText(code: "CNY", fractionDigits: 2, locale: locale)
    }

    private var linkedRefundNetText: String? {
        guard let entry else { return nil }
        return max(entry.amount - linkedRefundTotalCNY, 0)
            .currencyText(code: "CNY", fractionDigits: 2, locale: locale)
    }

    private var datePickerComponents: DatePickerComponents {
        detailedTimeEnabled ? [.date, .hourAndMinute] : [.date]
    }

    var body: some View {
        NavigationStack {
            SWAdaptivePage(maximumWidth: 980) { isWide in
                SWAdaptiveColumns(isWide: isWide) {
                    VStack(spacing: 16) {
                        if isCreatingRefundOperation {
                            sourceAmountCard
                            refundAmountCard
                        } else if isEditingRefundOperation {
                            refundAmountCard
                        } else {
                            amountCard
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("entry.section.amount")
                        }
                        if shouldShowRefundDetail {
                            refundDetailCard
                                .id(refundDetailRefreshID)
                        }
                        noteCard
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("entry.section.note")
                        dateCard
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("entry.section.date")
                        tagCard
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("entry.section.tags")
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    VStack(spacing: 16) {
                        if !isRefundForm {
                            categoryCard
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("entry.section.category")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(.bottom, focusedField != .note || usesInlineKeyboardAccessory ? 0 : 56)
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
                        commitAmountCalculationIfPossible()
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
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { editorWidth = $0 }
        .onChange(of: amountIsFocused) { _, value in
            if value { focusedField = nil }
        }
        .onChange(of: focusedField) { _, value in
            if value == .note { amountIsFocused = false }
        }
        .overlay(alignment: .bottom) {
            if focusedField == .note, !usesInlineKeyboardAccessory {
                keyboardAccessory
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showCurrencyPicker) {
            CurrencyPickerSheet(selectedCode: $selectedCurrencyCode)
        }
        .sheet(item: $editingRefundEntry) { refundEntry in
            EntryEditorSheet(
                flow: refundEntry.flow,
                entry: refundEntry,
                operation: .editRefund,
                refundLimitAmountCNY: refundEditLimitAmountCNY(for: refundEntry),
                onSaved: {
                    refundDetailRefreshID = UUID()
                    onSaved?()
                }
            )
        }
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "金额", subtitle: amountSubtitle)

            HStack(spacing: 12) {
                Text(sourceAmountSign)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(sourceAmountSignTint)

                Text(selectedCurrencySymbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SWTheme.primaryText.opacity(0.84))

                amountInput

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

    private var refundDetailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.string("ledger.refundDetailTitle", locale: locale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SWTheme.primaryText)

                Text(L10n.string("ledger.refundDetailSubtitle", locale: locale))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
            }

            HStack(spacing: 10) {
                refundSummaryPill(
                    title: "累计退款",
                    value: linkedRefundTotalText,
                    tint: SWTheme.accentBlue,
                    symbol: "arrow.uturn.backward.circle.fill"
                )

                if let linkedRefundNetText {
                    refundSummaryPill(
                        title: "退款后净额",
                        value: linkedRefundNetText,
                        tint: SWTheme.accentGreen,
                        symbol: "equal.circle.fill"
                    )
                }
            }

            VStack(spacing: 8) {
                ForEach(sortedLinkedRefundEntries) { refundEntry in
                    Button {
                        HapticService.selection()
                        editingRefundEntry = refundEntry
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(SWTheme.accentBlue.opacity(0.16))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(SWTheme.accentBlue)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(refundEntry.note)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(SWTheme.primaryText)
                                    .lineLimit(2)

                                Text(refundEntry.createdAt.ledgerDateText(showTime: detailedTimeEnabled, locale: locale))
                                    .font(.caption2)
                                    .foregroundStyle(SWTheme.textSecondary)
                            }

                            Spacer(minLength: 8)

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("+\(refundDisplayAmountText(for: refundEntry))")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(SWTheme.accentBlue)

                                if CurrencyCatalog.normalize(code: refundEntry.currencyCode) != "CNY" {
                                    Text(refundEntry.amount.currencyText(code: "CNY", fractionDigits: 2, locale: locale))
                                        .font(.caption2)
                                        .foregroundStyle(SWTheme.textSecondary)
                                }
                            }

                            Image(systemName: "pencil.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SWTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
            }
        }
        .fitnessCard()
    }

    private func refundSummaryPill(title: String, value: String, tint: Color, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.appLocalized(in: locale))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SWTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func refundDisplayAmountText(for refundEntry: LedgerEntry) -> String {
        let code = CurrencyCatalog.normalize(code: refundEntry.currencyCode)
        let digits = CurrencyCatalog.fractionDigits(for: code)
        return refundEntry.displayAmount.currencyText(code: code, fractionDigits: digits, locale: locale)
    }

    private func refundEditLimitAmountCNY(for refundEntry: LedgerEntry) -> Double? {
        guard let entry else { return nil }
        return max(entry.amount - linkedRefundTotalCNY + refundEntry.amount, 0)
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
                    .foregroundStyle(SWTheme.primaryText.opacity(0.84))

                Text(sourceEntryAmountValueText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(SWTheme.primaryText)
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
                    .foregroundStyle(SWTheme.primaryText.opacity(0.84))

                amountInput

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
        .accessibilityLabel(L10n.string("entry.currencyAccessibility", locale: locale, selectedCurrencyDescriptor.code))
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "备注", subtitle: "账单描述")

            TextField("例如：午餐简餐 / 月度工资", text: $note)
                .accessibilityIdentifier("entry.note")
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: .note)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .foregroundStyle(SWTheme.primaryText)
            inlineKeyboardAccessory(for: .note)
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
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "分类", subtitle: "快速选择图标分类")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumCategoryCellWidth), spacing: 8)], spacing: 8) {
                ForEach(categories) { category in
                    Button {
                        selectedCategoryID = category.id
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(category.color.opacity(0.18))
                                    .frame(width: 38, height: 38)

                                Image(systemName: category.symbol)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(category.color)
                            }

                            Text(category.localizedName(in: locale))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(SWTheme.primaryText)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                                .frame(height: 28, alignment: .top)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
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
                    .accessibilityIdentifier("entry.category.\(category.name)")
                    .accessibilityAddTraits(selectedCategoryID == category.id ? .isSelected : [])
                }
            }
            .id(locale.identifier)
        }
        .fitnessCard()
    }

    private var tagCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "标签", subtitle: "可选，为账单补充标签")

            if managedTags.isEmpty {
                Text("还没有可选标签，请先到设置中的“标签管理”添加。".appLocalized(in: locale))
                    .font(.caption)
                    .foregroundStyle(SWTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
            } else {
                TagCloudLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(managedTags) { tag in
                        let isSelected = selectedTagNames.contains(tag.name)

                        Button {
                            toggleTag(named: tag.name)
                        } label: {
                            HStack(alignment: .top, spacing: 7) {
                                Image(systemName: "tag.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(tag.tintColor)
                                    .padding(.top, 1)
                                Text(tag.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .layoutPriority(1)
                            }
                            .foregroundStyle(isSelected ? Color.white : SWTheme.textSecondary)
                            .frame(minWidth: tagChipMinimumWidth(for: tag.name), alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? flow.accent.opacity(0.24) : Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(
                                                isSelected ? flow.accent.opacity(0.72) : Color.white.opacity(0.08),
                                                lineWidth: isSelected ? 1.4 : 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("entry.tag.\(tag.name)")
                    }
                }
            }
        }
        .fitnessCard()
    }

    private func tagChipMinimumWidth(for name: String) -> CGFloat {
        switch name.count {
        case 0...2:
            return 70
        case 3...4:
            return 86
        case 5...6:
            return 108
        case 7...9:
            return 132
        default:
            return 156
        }
    }

    @ViewBuilder
    private func inlineKeyboardAccessory(for field: EntryEditorFocusedField) -> some View {
        if usesInlineKeyboardAccessory, focusedField == field {
            keyboardAccessory
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var keyboardAccessory: some View {
        if focusedField == .note {
            HStack {
                Spacer()
                Button {
                    focusedField = nil
                } label: {
                    Text("完成".appLocalized(in: locale))
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    private var amountInput: some View {
        AmountInputField(
            text: $amountText,
            isFocused: $amountIsFocused,
            doneTitle: "完成".appLocalized(in: locale),
            onOperator: appendAmountOperator,
            onEquals: { resolveAmountExpression(feedbackOnFailure: true) },
            onDone: { commitAmountCalculationIfPossible(); amountIsFocused = false }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 44)
    }

    private func appendAmountOperator(_ symbol: String) {
        var text = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if let last = text.last, AmountExpressionEvaluator.isOperator(last) {
            text.removeLast()
        }

        amountText = text + symbol
        HapticService.selection()
    }

    private func commitAmountCalculationIfPossible() {
        guard AmountExpressionEvaluator.containsOperator(amountText) else { return }
        resolveAmountExpression(feedbackOnFailure: false)
    }

    private func resolveAmountExpression(feedbackOnFailure: Bool) {
        guard let amount = AmountExpressionEvaluator.evaluate(amountText), amount > 0 else {
            if feedbackOnFailure {
                HapticService.warning()
            }
            return
        }

        amountText = Self.amountString(amount)
        HapticService.selection()
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
            if isRefundForm, let refundCategory = CategoryLibrary.category(
                named: CategoryLibrary.refundCategoryName,
                flow: flow
            ) {
                return refundCategory
            }
            return selectedCategory
        }()
        let noteFallback = isRefundForm ? CategoryLibrary.refundCategoryName : categoryToSave.name
        let noteToSave = finalNote.isEmpty ? noteFallback : finalNote
        let finalDate = detailedTimeEnabled ? date : Calendar.current.startOfDay(for: date)
        let currencyCode = normalizedCurrencyCode

        if (operation == .edit || operation == .editRefund), let entry {
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
            entry.tagNames = selectedTagNames
        } else {
            let newEntry = LedgerEntry(
                createdAt: finalDate,
                amount: amountInCNY,
                originalAmount: originalAmount,
                currencyCode: currencyCode,
                exchangeRateToCNY: exchangeRateToCNY,
                note: noteToSave,
                flow: flow,
                category: categoryToSave,
                tagNames: selectedTagNames,
                refundSourceEntryID: isCreatingRefundOperation ? entry?.id : nil
            )
            modelContext.insert(newEntry)
        }

        try? modelContext.save()
        onSaved?()
        dismiss()
    }

    private static func amountString(_ amount: Double) -> String {
        let raw = amount.formatted(.number.precision(.fractionLength(2)))
        return raw
            .replacingOccurrences(of: ".00", with: "")
            .replacingOccurrences(of: ",", with: "")
    }

    private func toggleTag(named name: String) {
        if let index = selectedTagNames.firstIndex(of: name) {
            selectedTagNames.remove(at: index)
        } else {
            selectedTagNames.append(name)
        }
    }

}

// Keep calculation controls attached to the keyboard, including iPad floating keyboards.
private struct AmountInputField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let doneTitle: String
    let onOperator: (String) -> Void
    let onEquals: () -> Void
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = "0"
        field.keyboardType = .decimalPad
        field.font = UIFont.systemFont(ofSize: 34, weight: .bold)
            .withRoundedDesign()
        field.accessibilityIdentifier = "entry.amount"
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        // A single accessory layout keeps Done visible in narrow scenes, without toolbar overflow.
        let accessory = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 50))
        accessory.autoresizingMask = [.flexibleWidth]
        let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        accessory.addSubview(backdrop)
        let operators = ["+", "-", "×", "÷"].map { symbol in
            let button = UIButton(type: .system)
            button.setTitle(symbol, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 22, weight: .medium)
            button.addTarget(context.coordinator, action: #selector(Coordinator.insertOperator(_:)), for: .touchUpInside)
            button.accessibilityIdentifier = "amount.operator.\(symbol)"
            return button
        }
        let equals = UIButton(type: .system)
        equals.setTitle("=", for: .normal)
        equals.titleLabel?.font = .systemFont(ofSize: 22, weight: .medium)
        equals.addTarget(context.coordinator, action: #selector(Coordinator.calculate), for: .touchUpInside)
        equals.accessibilityIdentifier = "amount.equals"
        let done = UIButton(type: .system)
        done.setTitle(doneTitle, for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        done.titleLabel?.adjustsFontSizeToFitWidth = true
        done.titleLabel?.minimumScaleFactor = 0.8
        done.addTarget(context.coordinator, action: #selector(Coordinator.finish), for: .touchUpInside)
        done.accessibilityIdentifier = "amount.done"
        context.coordinator.doneButton = done
        let controls = UIStackView(arrangedSubviews: operators + [equals, done])
        controls.axis = .horizontal
        controls.distribution = .fillEqually
        controls.translatesAutoresizingMaskIntoConstraints = false
        accessory.addSubview(controls)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: accessory.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: accessory.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: accessory.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: accessory.bottomAnchor),
            controls.leadingAnchor.constraint(equalTo: accessory.leadingAnchor, constant: 8),
            controls.trailingAnchor.constraint(equalTo: accessory.trailingAnchor, constant: -8),
            controls.topAnchor.constraint(equalTo: accessory.topAnchor, constant: 3),
            controls.bottomAnchor.constraint(equalTo: accessory.bottomAnchor, constant: -3)
        ])
        field.inputAccessoryView = accessory
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.textColor = UIColor(SWTheme.primaryText)
        field.tintColor = UIColor(SWTheme.accentGreen)
        field.inputAccessoryView?.tintColor = field.tintColor
        context.coordinator.doneButton?.setTitle(doneTitle, for: .normal)
        if !isFocused, field.isFirstResponder {
            DispatchQueue.main.async { [weak field, weak coordinator = context.coordinator] in
                guard coordinator?.parent.isFocused == false, field?.isFirstResponder == true else { return }
                field?.resignFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AmountInputField
        weak var doneButton: UIButton?
        init(_ parent: AmountInputField) { self.parent = parent }
        @objc func textChanged(_ field: UITextField) { parent.text = field.text ?? "" }
        func textFieldDidBeginEditing(_ field: UITextField) { parent.isFocused = true }
        func textFieldDidEndEditing(_ field: UITextField) { parent.isFocused = false }
        @objc func insertOperator(_ button: UIButton) {
            if let symbol = button.currentTitle { parent.onOperator(symbol) }
        }
        @objc func calculate() { parent.onEquals() }
        @objc func finish() { parent.onDone() }
    }
}

private extension UIFont {
    func withRoundedDesign() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

private enum AmountExpressionEvaluator {
    private static let operators: Set<Character> = ["+", "-", "*", "/", "×", "÷"]

    static func containsOperator(_ text: String) -> Bool {
        text.contains { isOperator($0) }
    }

    static func isOperator(_ character: Character) -> Bool {
        operators.contains(character)
    }

    static func evaluate(_ text: String) -> Double? {
        let normalizedText = text
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .filter { !$0.isWhitespace }

        guard !normalizedText.isEmpty else { return nil }

        var parser = Parser(normalizedText)
        guard let value = parser.parseExpression(), parser.isAtEnd, value.isFinite else {
            return nil
        }
        return value
    }

    private struct Parser {
        private let characters: [Character]
        private var index = 0

        init(_ text: String) {
            characters = Array(text)
        }

        var isAtEnd: Bool {
            index >= characters.count
        }

        mutating func parseExpression() -> Double? {
            guard var value = parseTerm() else { return nil }

            while let operation = peek(), operation == "+" || operation == "-" {
                advance()
                guard let rhs = parseTerm() else { return nil }
                value = operation == "+" ? value + rhs : value - rhs
            }

            return value
        }

        private mutating func parseTerm() -> Double? {
            guard var value = parseFactor() else { return nil }

            while let operation = peek(), operation == "*" || operation == "/" {
                advance()
                guard let rhs = parseFactor() else { return nil }

                if operation == "/" {
                    guard rhs != 0 else { return nil }
                    value /= rhs
                } else {
                    value *= rhs
                }
            }

            return value
        }

        private mutating func parseFactor() -> Double? {
            if match("+") {
                return parseFactor()
            }

            if match("-") {
                guard let value = parseFactor() else { return nil }
                return -value
            }

            return parseNumber()
        }

        private mutating func parseNumber() -> Double? {
            let start = index
            var hasDigit = false
            var hasDecimalSeparator = false

            while let character = peek() {
                if character.isWholeNumber {
                    hasDigit = true
                    advance()
                } else if character == ".", !hasDecimalSeparator {
                    hasDecimalSeparator = true
                    advance()
                } else {
                    break
                }
            }

            guard hasDigit else { return nil }
            return Double(String(characters[start..<index]))
        }

        private mutating func match(_ expected: Character) -> Bool {
            guard peek() == expected else { return false }
            advance()
            return true
        }

        private func peek() -> Character? {
            isAtEnd ? nil : characters[index]
        }

        private mutating func advance() {
            index += 1
        }
    }
}

private struct TagCloudLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    private struct Item {
        let index: Int
        let size: CGSize
    }

    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = resolvedWidth(from: proposal.width)
        let rows = makeRows(subviews: subviews, maxWidth: maxWidth)
        let height = rows.reduce(CGFloat.zero) { partialResult, row in
            partialResult + row.height
        } + CGFloat(max(rows.count - 1, 0)) * verticalSpacing

        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = makeRows(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
                )
                x += item.size.width + horizontalSpacing
            }

            y += row.height + verticalSpacing
        }
    }

    private func makeRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        guard !subviews.isEmpty else { return [] }

        var rows: [Row] = []
        var currentRow = Row()
        let availableWidth = resolvedWidth(from: maxWidth)

        for index in subviews.indices {
            let proposedSize = subviews[index].sizeThatFits(
                ProposedViewSize(width: availableWidth, height: nil)
            )
            let itemSize = CGSize(
                width: min(proposedSize.width, availableWidth),
                height: proposedSize.height
            )
            let nextWidth = currentRow.items.isEmpty
                ? itemSize.width
                : currentRow.width + horizontalSpacing + itemSize.width

            if nextWidth > availableWidth, !currentRow.items.isEmpty {
                rows.append(currentRow)
                currentRow = Row(items: [Item(index: index, size: itemSize)], width: itemSize.width, height: itemSize.height)
            } else {
                currentRow.items.append(Item(index: index, size: itemSize))
                currentRow.width = nextWidth
                currentRow.height = max(currentRow.height, itemSize.height)
            }
        }

        if !currentRow.items.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    private func resolvedWidth(from width: CGFloat?) -> CGFloat {
        max(width ?? 320, 1)
    }
}

@MainActor
private struct CurrencyPickerSheet: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyStore = CurrencyStore.shared

    @Binding var selectedCode: String
    @State private var searchText = ""

    private var normalizedSelectedCode: String {
        CurrencyCatalog.normalize(code: selectedCode)
    }

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
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    SettingsSectionCard(title: "搜索") {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(SWTheme.textSecondary)

                            TextField("搜索币种代码或名称", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .foregroundStyle(SWTheme.primaryText)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                    }

                    SettingsSectionCard(title: "币种列表") {
                        if filteredDescriptors.isEmpty {
                            Text("没有找到匹配的币种。")
                                .font(.subheadline)
                                .foregroundStyle(SWTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(Array(filteredDescriptors.enumerated()), id: \.element.id) { index, descriptor in
                                HStack(spacing: 10) {
                                    Text(descriptor.flag)
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(descriptor.code)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(SWTheme.primaryText)
                                        Text(descriptor.name)
                                            .font(.caption)
                                            .foregroundStyle(SWTheme.textSecondary)
                                    }

                                    Spacer()

                                    if descriptor.code == normalizedSelectedCode {
                                        HStack(spacing: 5) {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                            Text("已选")
                                                .font(.caption2.weight(.bold))
                                        }
                                        .foregroundStyle(SWTheme.accentGreen)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(SWTheme.accentGreen.opacity(0.18))
                                        )
                                    } else {
                                        Button {
                                            selectedCode = descriptor.code
                                            HapticService.selection()
                                            dismiss()
                                        } label: {
                                            Text("选择")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    Capsule(style: .continuous)
                                                        .fill(SWTheme.accentBlue.opacity(0.22))
                                                        .overlay(
                                                            Capsule(style: .continuous)
                                                                .stroke(SWTheme.accentBlue.opacity(0.4), lineWidth: 1)
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)

                                if index < filteredDescriptors.count - 1 {
                                    SettingsRowDivider()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 26)
            }
            .navigationTitle("选择币种")
            .navigationBarTitleDisplayMode(.inline)
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
            .appBackground()
        }
    }
}
