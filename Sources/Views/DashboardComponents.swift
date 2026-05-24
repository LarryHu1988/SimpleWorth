import SwiftUI

struct SectionTitle: View {
    @Environment(\.locale) private var locale
    let title: String
    let subtitle: String

    var body: some View {
        Text(title.appLocalized(in: locale))
            .font(.title3.weight(.bold))
            .foregroundStyle(SWTheme.primaryText)
    }
}

struct ProgressRing: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0))
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.6), tint, tint.opacity(0.75)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.45), radius: 8)
        }
    }
}

struct FlowSummaryCard: View {
    @Environment(\.locale) private var locale
    let flow: FlowType
    let periodTitle: String
    let amount: Double
    let compareText: String
    let ringProgress: Double

    private var signedAmount: Double {
        flow == .expense ? -amount : amount
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(periodTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(SWTheme.primaryText)
                Text(signedAmount.signedCNYText(in: locale))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(SWTheme.primaryText)
                    .minimumScaleFactor(0.75)
                Text(compareText)
                    .font(.footnote)
                    .foregroundStyle(SWTheme.textSecondary)
            }

            Spacer(minLength: 8)

            ZStack {
                ProgressRing(progress: ringProgress, tint: flow.accent, lineWidth: 12)
                    .frame(width: 94, height: 94)
                Image(systemName: flow.tabIcon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(flow.accent)
            }
        }
        .fitnessCard()
    }
}

struct CategoryGridSection: View {
    @Environment(\.locale) private var locale
    let title: String
    let subtitle: String
    let categories: [CategoryItem]
    var onTapCategory: ((CategoryItem) -> Void)? = nil

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 44), spacing: 6),
        count: 5
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: title, subtitle: subtitle)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(categories) { item in
                    CategoryIconCell(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTapCategory?(item)
                        }
                }
            }
            .id(locale.identifier)
        }
        .fitnessCard()
    }
}

struct CategoryIconCell: View {
    @Environment(\.locale) private var locale
    let item: CategoryItem

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.2))
                    .frame(width: 38, height: 38)
                Circle()
                    .stroke(item.color.opacity(0.55), lineWidth: 1)
                    .frame(width: 38, height: 38)
                Image(systemName: item.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(item.color)
            }

            Text(item.localizedName(in: locale))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SWTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct LedgerRow: View {
    @Environment(\.locale) private var locale
    @AppStorage("settings.detailedTimeEnabled") private var detailedTimeEnabled = false
    let entry: LedgerEntry
    var tagTintHexByName: [String: Int] = [:]
    var refundAmount: Double = 0

    private var signedDisplayAmount: Double {
        entry.signedDisplayAmount
    }

    private var signedCNYAmount: Double {
        entry.signedAmountInCNY
    }

    private var signedDisplayAmountText: String {
        let code = CurrencyCatalog.normalize(code: entry.currencyCode)
        let digits = CurrencyCatalog.fractionDigits(for: code)
        return signedDisplayAmount.signedCurrencyText(code: code, fractionDigits: digits, locale: locale)
    }

    private var refundAmountText: String {
        refundAmount.currencyText(code: "CNY", fractionDigits: 2, locale: locale)
    }

    private var allTagNames: [String] {
        entry.tagNames
    }

    private var visibleTags: [String] {
        Array(allTagNames.prefix(2))
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(entry.categoryColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: entry.categorySymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(entry.categoryColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.note)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SWTheme.primaryText)

                HStack(spacing: 6) {
                    Text(entry.createdAt.ledgerDateText(showTime: detailedTimeEnabled, locale: locale))
                        .font(.caption)
                        .foregroundStyle(SWTheme.textSecondary)

                    if CurrencyCatalog.normalize(code: entry.currencyCode) != "CNY" {
                        Text(L10n.string("entry.convertedInline", locale: locale, signedCNYAmount.signedCNYText(in: locale)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(SWTheme.textSecondary)
                    }
                }

                if !visibleTags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(visibleTags, id: \.self) { tagName in
                            HStack(spacing: 4) {
                                Image(systemName: "tag.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(tagTint(for: tagName))
                                Text(tagName)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(SWTheme.primaryText.opacity(0.92))
                            }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }

                        if allTagNames.count > visibleTags.count {
                            Text("+\(allTagNames.count - visibleTags.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(SWTheme.textSecondary)
                        }
                    }
                }

                if refundAmount > 0.001 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.caption2.weight(.bold))
                        Text(L10n.string("ledger.refundApplied", locale: locale, refundAmountText))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(SWTheme.accentBlue)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(SWTheme.accentBlue.opacity(0.14))
                    )
                }
            }

            Spacer(minLength: 8)

            Text(signedDisplayAmountText)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(entry.amountTint)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func tagTint(for tagName: String) -> Color {
        let tintHex = tagTintHexByName[tagName] ?? TagEmojiLibrary.colorHex(for: tagName)
        return Color.sw(UInt(tintHex))
    }
}

struct SwipeableLedgerRow: View {
    @Environment(\.locale) private var locale
    let entry: LedgerEntry
    var tagTintHexByName: [String: Int] = [:]
    var refundAmount: Double = 0
    var showCopyAction: Bool = true
    var showRefundAction: Bool = true
    let onTap: () -> Void
    let onCopy: () -> Void
    let onRefund: () -> Void
    let onDelete: () -> Void

    @State private var offsetX: CGFloat = 0
    @State private var baseOffsetX: CGFloat = 0
    @State private var isHorizontalDragging = false
    @State private var tapSuppressedUntil = Date.distantPast

    private let tapSuppressionInterval: TimeInterval = 0.5

    private var leadingWidth: CGFloat {
        showCopyAction ? 84 : 0
    }
    private var trailingWidth: CGFloat {
        showRefundAction ? 168 : 84
    }

    private var revealedLeadingWidth: CGFloat {
        max(offsetX, 0)
    }

    private var revealedTrailingWidth: CGFloat {
        max(-offsetX, 0)
    }

    private var isOpen: Bool {
        abs(baseOffsetX) > 0.5 || abs(offsetX) > 0.5
    }

    var body: some View {
        ZStack {
            actionBackground

            LedgerRow(entry: entry, tagTintHexByName: tagTintHexByName, refundAmount: refundAmount)
                .offset(x: offsetX)
                .contentShape(Rectangle())
                .allowsHitTesting(!isOpen && !isHorizontalDragging)
                .onTapGesture {
                    handleRowTap()
                }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(dragGesture)
        .onDisappear {
            resetImmediately()
        }
        .onTapGesture {
            if isOpen {
                suppressTap()
                closeActions()
            }
        }
        .clipped()
    }

    private var actionBackground: some View {
        ZStack {
            HStack {
                if showCopyAction {
                    leadingActionPane
                        .frame(width: revealedLeadingWidth, alignment: .leading)
                        .clipped()
                }
                Spacer(minLength: 0)
            }

            HStack {
                Spacer(minLength: 0)
                trailingActionPane
                    .frame(width: revealedTrailingWidth, alignment: .trailing)
                    .clipped()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .allowsHitTesting(abs(offsetX) > 0.5)
    }

    private var leadingActionPane: some View {
        Button {
            closeActions()
            onCopy()
        } label: {
            actionLabel(
                title: "复制",
                symbol: "doc.on.doc.fill",
                tint: SWTheme.accentGreen.opacity(0.38),
                width: leadingWidth
            )
        }
        .buttonStyle(.plain)
        .frame(width: leadingWidth)
        .padding(.leading, 2)
        .padding(.vertical, 2)
    }

    private var trailingActionPane: some View {
        HStack(spacing: 0) {
            if showRefundAction {
                Button {
                    closeActions()
                    onRefund()
                } label: {
                    actionLabel(
                        title: "退款",
                        symbol: "arrow.uturn.backward.circle.fill",
                        tint: SWTheme.accentBlue.opacity(0.4),
                        width: 84
                    )
                }
                .buttonStyle(.plain)
            }

            Button(role: .destructive) {
                closeActions()
                onDelete()
            } label: {
                actionLabel(
                    title: "删除",
                    symbol: "trash.fill",
                    tint: Color.red.opacity(0.46),
                    width: 84
                )
            }
            .buttonStyle(.plain)
        }
        .frame(width: trailingWidth)
        .padding(.trailing, 2)
        .padding(.vertical, 2)
    }

    private func clampedOffset(_ value: CGFloat) -> CGFloat {
        if value > leadingWidth {
            let extra = value - leadingWidth
            return leadingWidth + extra * 0.24
        }
        if value < -trailingWidth {
            let extra = value + trailingWidth
            return -trailingWidth + extra * 0.24
        }

        return min(max(value, -trailingWidth), leadingWidth)
    }

    private func settledOffset(_ value: CGFloat) -> CGFloat {
        min(max(value, -trailingWidth), leadingWidth)
    }

    private func closeActions() {
        suppressTap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.74, blendDuration: 0.08)) {
            offsetX = 0
            baseOffsetX = 0
        }
    }

    private func resetImmediately() {
        offsetX = 0
        baseOffsetX = 0
        isHorizontalDragging = false
        tapSuppressedUntil = .distantPast
    }

    private func handleRowTap() {
        guard !isOpen, !isHorizontalDragging else { return }
        guard Date() >= tapSuppressedUntil else { return }
        onTap()
    }

    private func suppressTap() {
        tapSuppressedUntil = Date().addingTimeInterval(tapSuppressionInterval)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: abs(baseOffsetX) > 0.5 ? 10 : 24)
            .onChanged { value in
                let translation = value.translation
                if !isHorizontalDragging {
                    let intentThreshold = abs(baseOffsetX) > 0.5 ? 10.0 : 24.0
                    let directionRatio = abs(baseOffsetX) > 0.5 ? 1.2 : 2.4
                    let isStrongHorizontalIntent =
                        abs(translation.width) > max(intentThreshold, abs(translation.height) * directionRatio)

                    if !isStrongHorizontalIntent {
                        return
                    }
                    isHorizontalDragging = true
                    suppressTap()
                }

                offsetX = clampedOffset(baseOffsetX + translation.width)
            }
            .onEnded { value in
                guard isHorizontalDragging else { return }
                defer {
                    suppressTap()
                    isHorizontalDragging = false
                }

                let predictedOffset = settledOffset(baseOffsetX + value.predictedEndTranslation.width)
                let leadingThreshold = leadingWidth * 0.42
                let trailingThreshold = -trailingWidth * 0.38

                withAnimation(.spring(response: 0.34, dampingFraction: 0.74, blendDuration: 0.08)) {
                    if predictedOffset > leadingThreshold {
                        offsetX = leadingWidth
                        baseOffsetX = leadingWidth
                    } else if predictedOffset < trailingThreshold {
                        offsetX = -trailingWidth
                        baseOffsetX = -trailingWidth
                    } else {
                        offsetX = 0
                        baseOffsetX = 0
                    }
                }
            }
    }

    private func actionLabel(title: String, symbol: String, tint: Color, width: CGFloat) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
            Text(title.appLocalized(in: locale))
                .font(.caption2.weight(.semibold))
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .foregroundStyle(Color.white.opacity(0.96))
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
    }
}

struct EmptyStateCard: View {
    @Environment(\.locale) private var locale
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
            Text(title.appLocalized(in: locale))
                .font(.headline.weight(.bold))
                .foregroundStyle(SWTheme.primaryText)
            Text(subtitle.appLocalized(in: locale))
                .font(.footnote)
                .foregroundStyle(SWTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}
