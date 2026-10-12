import SwiftUI
import UIKit

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

            SWChartEntrance { fraction, animation in
                Circle()
                    .trim(from: 0, to: max(min(progress, 1), 0) * fraction)
                    .stroke(
                        AngularGradient(
                            colors: [tint.opacity(0.6), tint, tint.opacity(0.75)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(0.45), radius: 8)
                    .animation(animation, value: fraction)
            }
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
    @State private var searchText = ""

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 44), spacing: 6),
        count: 5
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: title, subtitle: subtitle)

            CategorySearchField(text: $searchText)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(CategoryLibrary.filtered(categories, matching: searchText, locale: locale)) { item in
                    Button {
                        HapticService.impact(style: .soft)
                        onTapCategory?(item)
                    } label: {
                        CategoryIconCell(item: item)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SWResponsiveButtonStyle(pressedScale: 0.93))
                }
            }
            .id(locale.identifier)
            if CategoryLibrary.filtered(categories, matching: searchText, locale: locale).isEmpty {
                Text("未找到匹配分类".appLocalized(in: locale))
                    .font(.subheadline)
                    .foregroundStyle(SWTheme.textSecondary)
            }
        }
        .fitnessCard()
    }
}

struct CategorySearchField: View {
    @Environment(\.locale) private var locale
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SWTheme.textSecondary)
            TextField("搜索分类或物品".appLocalized(in: locale), text: $text)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { isFocused = false }
                .accessibilityIdentifier("category.search")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(SWTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索".appLocalized(in: locale))
            }
        }
        .padding(12)
        .background(SWTheme.primaryText.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
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
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(height: 28, alignment: .top)
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
    private let snapshot: LedgerRowSnapshot

    init(entry: LedgerEntry, tagTintHexByName: [String: Int] = [:], refundAmount: Double = 0) {
        snapshot = LedgerRowSnapshot(
            id: entry.id,
            note: entry.note,
            createdAt: entry.createdAt,
            signedDisplayAmount: entry.signedDisplayAmount,
            signedCNYAmount: entry.signedAmountInCNY,
            currencyCode: entry.currencyCode,
            flow: entry.flow,
            isRefundEntry: entry.isRefundEntry,
            categorySymbol: entry.categorySymbol,
            categoryColorHex: entry.categoryColorHex,
            tagNames: entry.tagNames,
            tagTintHexByName: tagTintHexByName,
            refundAmount: refundAmount
        )
    }

    var body: some View {
        LedgerRowContent(
            snapshot: snapshot,
            locale: locale,
            detailedTimeEnabled: detailedTimeEnabled
        )
        .equatable()
    }
}

private struct LedgerRowSnapshot: Equatable {
    let id: UUID
    let note: String
    let createdAt: Date
    let signedDisplayAmount: Double
    let signedCNYAmount: Double
    let currencyCode: String
    let flow: FlowType
    let isRefundEntry: Bool
    let categorySymbol: String
    let categoryColorHex: Int
    let tagNames: [String]
    let tagTintHexByName: [String: Int]
    let refundAmount: Double
}

private struct LedgerRowContent: View, Equatable {
    let snapshot: LedgerRowSnapshot
    let locale: Locale
    let detailedTimeEnabled: Bool

    static func == (lhs: LedgerRowContent, rhs: LedgerRowContent) -> Bool {
        lhs.snapshot == rhs.snapshot
            && lhs.detailedTimeEnabled == rhs.detailedTimeEnabled
            && lhs.locale.identifier == rhs.locale.identifier
    }

    private var signedDisplayAmountText: String {
        let code = CurrencyCatalog.normalize(code: snapshot.currencyCode)
        let digits = CurrencyCatalog.fractionDigits(for: code)
        return snapshot.signedDisplayAmount.signedCurrencyText(code: code, fractionDigits: digits, locale: locale)
    }

    private var categoryColor: Color {
        Color.sw(UInt(snapshot.categoryColorHex))
    }

    private var amountTint: Color {
        if snapshot.flow == .income {
            return SWTheme.accentGreen
        }
        return snapshot.isRefundEntry ? SWTheme.accentBlue : SWTheme.accentOrange
    }

    private var refundAmountText: String {
        snapshot.refundAmount.currencyText(code: "CNY", fractionDigits: 2, locale: locale)
    }

    private var allTagNames: [String] {
        snapshot.tagNames
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: snapshot.categorySymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(categoryColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.note)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SWTheme.primaryText)

                HStack(spacing: 6) {
                    Text(snapshot.createdAt.ledgerDateText(showTime: detailedTimeEnabled, locale: locale))
                        .font(.caption)
                        .foregroundStyle(SWTheme.textSecondary)

                    if CurrencyCatalog.normalize(code: snapshot.currencyCode) != "CNY" {
                        Text(L10n.string("entry.convertedInline", locale: locale, snapshot.signedCNYAmount.signedCNYText(in: locale)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(SWTheme.textSecondary)
                    }
                }

                if !allTagNames.isEmpty {
                    LedgerTagWrapLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(allTagNames, id: \.self) { tagName in
                            tagChip(for: tagName)
                        }
                    }
                }

                if snapshot.refundAmount > 0.001 {
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
                .foregroundStyle(amountTint)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func tagTint(for tagName: String) -> Color {
        let tintHex = snapshot.tagTintHexByName[tagName] ?? TagEmojiLibrary.colorHex(for: tagName)
        return Color.sw(UInt(tintHex))
    }

    private func tagChip(for tagName: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "tag.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(tagTint(for: tagName))
            Text(tagName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SWTheme.primaryText.opacity(0.92))
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct LedgerTagWrapLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        arrangedSubviews(in: proposal.width, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let arrangement = arrangedSubviews(in: bounds.width, subviews: subviews)

        for item in arrangement.items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
                proposal: ProposedViewSize(item.size)
            )
        }
    }

    private func arrangedSubviews(
        in proposedWidth: CGFloat?,
        subviews: Subviews
    ) -> (items: [ArrangedTag], size: CGSize) {
        let maxWidth = max(proposedWidth ?? .greatestFiniteMagnitude, 1)
        var items: [ArrangedTag] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(
                ProposedViewSize(width: maxWidth, height: nil)
            )
            let shouldWrap = currentX > 0 && currentX + size.width > maxWidth

            if shouldWrap {
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            items.append(
                ArrangedTag(
                    index: index,
                    origin: CGPoint(x: currentX, y: currentY),
                    size: size
                )
            )

            usedWidth = max(usedWidth, currentX + size.width)
            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }

        let height = items.isEmpty ? 0 : currentY + rowHeight
        return (items, CGSize(width: min(usedWidth, maxWidth), height: height))
    }

    private struct ArrangedTag {
        let index: Int
        let origin: CGPoint
        let size: CGSize
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
    @State private var dragStartedOpen = false
    @State private var dragStartedOffsetX: CGFloat = 0
    @State private var tapSuppressedUntil = Date.distantPast

    private let tapSuppressionInterval: TimeInterval = 0.22
    @State private var measuredRowWidth: CGFloat = 0
    private let openDragActivationDistance: CGFloat = 4
    private let closedDragActivationDistance: CGFloat = 8
    private let closingTravelDistance: CGFloat = 6
    private let velocityProjectionDuration: CGFloat = 0.16
    private let overscrollResistance: CGFloat = 0.4
    private let returnAnimation = Animation.spring(response: 0.28, dampingFraction: 0.76, blendDuration: 0.04)
    private let revealAnimation = Animation.spring(response: 0.34, dampingFraction: 0.68, blendDuration: 0.05)

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
            if isOpen || isHorizontalDragging {
                actionBackground
            }

            LedgerRow(entry: entry, tagTintHexByName: tagTintHexByName, refundAmount: refundAmount)
                .offset(x: offsetX)
                .contentShape(Rectangle())
                .allowsHitTesting(!isOpen && !isHorizontalDragging)
        }
        .contentShape(Rectangle())
        .background {
            HorizontalPanGestureBridge(
                shouldBegin: shouldBeginHorizontalPan,
                onBegan: handleHorizontalPanBegan,
                onChanged: handleHorizontalPanChanged,
                onEnded: handleHorizontalPanEnded
            )
        }
        .onDisappear {
            resetImmediately()
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            if measuredRowWidth > 0, abs(width - measuredRowWidth) > 1 {
                resetImmediately()
                suppressTap()
            }
            measuredRowWidth = width
        }
        .onTapGesture {
            handleContainerTap()
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
        .accessibilityHidden(!isOpen)
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
            return leadingWidth + extra * overscrollResistance
        }
        if value < -trailingWidth {
            let extra = value + trailingWidth
            return -trailingWidth + extra * overscrollResistance
        }

        return min(max(value, -trailingWidth), leadingWidth)
    }

    private func settledOffset(_ value: CGFloat) -> CGFloat {
        min(max(value, -trailingWidth), leadingWidth)
    }

    private func closeActions() {
        suppressTap()
        withAnimation(returnAnimation) {
            offsetX = 0
            baseOffsetX = 0
        }
    }

    private func resetImmediately() {
        offsetX = 0
        baseOffsetX = 0
        isHorizontalDragging = false
        dragStartedOpen = false
        dragStartedOffsetX = 0
        tapSuppressedUntil = .distantPast
    }

    private func handleContainerTap() {
        if isOpen {
            closeActions()
            return
        }

        guard !isHorizontalDragging else { return }
        guard Date() >= tapSuppressedUntil else { return }
        onTap()
    }

    private func suppressTap() {
        tapSuppressedUntil = Date().addingTimeInterval(tapSuppressionInterval)
    }

    private func shouldBeginHorizontalPan(translation: CGSize, velocity: CGSize) -> Bool {
        let startedOpen = abs(baseOffsetX) > 0.5
        if startedOpen {
            return isOpenRowHorizontalIntent(translation)
                || isHorizontalVelocityIntent(velocity, minimumVelocity: 28, axisBias: 1.0)
        }

        return isClosedRowHorizontalIntent(translation)
            || isHorizontalVelocityIntent(velocity, minimumVelocity: 36, axisBias: 1.35)
    }

    private func handleHorizontalPanBegan() {
        let startingOffset = baseOffsetX
        isHorizontalDragging = true
        dragStartedOpen = abs(startingOffset) > 0.5
        dragStartedOffsetX = startingOffset
        suppressTap()
    }

    private func handleHorizontalPanChanged(_ horizontalTranslation: CGFloat) {
        guard isHorizontalDragging else { return }

        offsetX = interactiveOffset(
            from: dragStartedOffsetX,
            startedOpen: dragStartedOpen,
            horizontalTranslation: horizontalTranslation
        )
    }

    private func handleHorizontalPanEnded(horizontalTranslation: CGFloat, horizontalVelocity: CGFloat) {
        defer {
            isHorizontalDragging = false
            dragStartedOpen = false
            dragStartedOffsetX = 0
        }

        guard isHorizontalDragging else { return }

        suppressTap()
        let targetOffset = targetOffset(
            horizontalTranslation: horizontalTranslation,
            horizontalVelocity: horizontalVelocity,
            startingOffset: dragStartedOffsetX,
            startedOpen: dragStartedOpen
        )
        let animation = targetOffset == 0 ? returnAnimation : revealAnimation

        if abs(dragStartedOffsetX - targetOffset) > 0.5 {
            HapticService.impact(style: .soft)
        }

        withAnimation(animation) {
            offsetX = targetOffset
            baseOffsetX = targetOffset
        }
    }

    private func isOpenRowHorizontalIntent(_ translation: CGSize) -> Bool {
        let horizontalDistance = abs(translation.width)
        return horizontalDistance > openDragActivationDistance
            && horizontalDistance > abs(translation.height)
    }

    private func isClosedRowHorizontalIntent(_ translation: CGSize) -> Bool {
        let horizontalDistance = abs(translation.width)
        return horizontalDistance > closedDragActivationDistance
            && horizontalDistance > abs(translation.height) * 1.35
    }

    private func isHorizontalVelocityIntent(
        _ velocity: CGSize,
        minimumVelocity: CGFloat,
        axisBias: CGFloat
    ) -> Bool {
        let horizontalVelocity = abs(velocity.width)
        return horizontalVelocity > minimumVelocity
            && horizontalVelocity > abs(velocity.height) * axisBias
    }

    private func interactiveOffset(
        from startingOffset: CGFloat,
        startedOpen: Bool,
        horizontalTranslation: CGFloat
    ) -> CGFloat {
        let proposedOffset = startingOffset + horizontalTranslation

        if startedOpen, startingOffset > 0.5, horizontalTranslation < 0 {
            return max(proposedOffset, 0)
        }

        if startedOpen, startingOffset < -0.5, horizontalTranslation > 0 {
            return min(proposedOffset, 0)
        }

        return clampedOffset(proposedOffset)
    }

    private func targetOffset(
        horizontalTranslation: CGFloat,
        horizontalVelocity: CGFloat,
        startingOffset: CGFloat,
        startedOpen: Bool
    ) -> CGFloat {
        if startedOpen, startingOffset > 0.5 {
            return horizontalTranslation < -closingTravelDistance ? 0 : leadingWidth
        }

        if startedOpen, startingOffset < -0.5 {
            return horizontalTranslation > closingTravelDistance ? 0 : -trailingWidth
        }

        let projectedTranslation = horizontalTranslation + horizontalVelocity * velocityProjectionDuration
        let predictedOffset = settledOffset(startingOffset + projectedTranslation)
        if predictedOffset > leadingWidth * 0.36 {
            return leadingWidth
        }

        if predictedOffset < -trailingWidth * 0.36 {
            return -trailingWidth
        }

        return 0
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

private struct HorizontalPanGestureBridge: UIViewRepresentable {
    var shouldBegin: (_ translation: CGSize, _ velocity: CGSize) -> Bool
    var onBegan: () -> Void
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ horizontalTranslation: CGFloat, _ horizontalVelocity: CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.configure(coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {
        context.coordinator.shouldBegin = shouldBegin
        context.coordinator.onBegan = onBegan
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        uiView.installIfNeeded()
    }

    final class InstallerView: UIView {
        private weak var installedView: UIView?
        private var panRecognizer: UIPanGestureRecognizer?
        private var previousWidth: CGFloat = 0

        override func layoutSubviews() {
            super.layoutSubviews()
            if previousWidth > 0, abs(bounds.width - previousWidth) > 1,
               let panRecognizer, panRecognizer.state == .began || panRecognizer.state == .changed {
                panRecognizer.isEnabled = false
                panRecognizer.isEnabled = true
            }
            previousWidth = bounds.width
        }

        func configure(coordinator: Coordinator) {
            guard panRecognizer == nil else { return }

            coordinator.sourceView = self
            let recognizer = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
            recognizer.delegate = coordinator
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.maximumNumberOfTouches = 1
            panRecognizer = recognizer
            isUserInteractionEnabled = false
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            installIfNeeded()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            installIfNeeded()
        }

        func installIfNeeded() {
            guard let panRecognizer else { return }
            let targetView = window ?? superview
            guard installedView !== targetView else { return }

            installedView?.removeGestureRecognizer(panRecognizer)
            targetView?.addGestureRecognizer(panRecognizer)
            installedView = targetView
        }

        deinit {
            if let panRecognizer {
                installedView?.removeGestureRecognizer(panRecognizer)
            }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var sourceView: UIView?
        var shouldBegin: (_ translation: CGSize, _ velocity: CGSize) -> Bool = { _, _ in false }
        var onBegan: () -> Void = {}
        var onChanged: (CGFloat) -> Void = { _ in }
        var onEnded: (_ horizontalTranslation: CGFloat, _ horizontalVelocity: CGFloat) -> Void = { _, _ in }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view)
            let velocity = recognizer.velocity(in: recognizer.view)

            switch recognizer.state {
            case .began:
                onBegan()
                onChanged(translation.x)
            case .changed:
                onChanged(translation.x)
            case .ended, .cancelled, .failed:
                onEnded(translation.x, velocity.x)
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            guard let sourceView, sourceView.window != nil else { return false }
            return sourceView.bounds.insetBy(dx: -4, dy: -4).contains(touch.location(in: sourceView))
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panRecognizer = gestureRecognizer as? UIPanGestureRecognizer else {
                return true
            }

            let translation = panRecognizer.translation(in: panRecognizer.view)
            let velocity = panRecognizer.velocity(in: panRecognizer.view)
            return shouldBegin(
                CGSize(width: translation.x, height: translation.y),
                CGSize(width: velocity.x, height: velocity.y)
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            !isAncestorScrollPan(otherGestureRecognizer)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Let the row reject vertical intent before its scroll view starts moving.
            isAncestorScrollPan(otherGestureRecognizer)
        }

        private func isAncestorScrollPan(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let scrollView = gestureRecognizer.view as? UIScrollView,
                  gestureRecognizer === scrollView.panGestureRecognizer else { return false }

            var ancestor = sourceView?.superview
            while let view = ancestor {
                if view === scrollView { return true }
                ancestor = view.superview
            }
            return false
        }
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
