import UIKit
import SwiftUI

enum ThemeMode: String, CaseIterable, Identifiable {
    case system
    case daylight
    case moonlight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            "系统".appLocalized
        case .daylight:
            "日光".appLocalized
        case .moonlight:
            "月光".appLocalized
        }
    }

    var symbol: String {
        switch self {
        case .system:
            "circle.lefthalf.filled"
        case .daylight:
            "sun.max.fill"
        case .moonlight:
            "moon.stars.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .daylight:
            .light
        case .moonlight:
            .dark
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system:
            .unspecified
        case .daylight:
            .light
        case .moonlight:
            .dark
        }
    }

    static func resolved(from defaults: UserDefaults = .standard) -> ThemeMode {
        if
            let rawValue = defaults.string(forKey: SettingsKeys.themeMode),
            let mode = ThemeMode(rawValue: rawValue)
        {
            return mode
        }

        if defaults.object(forKey: SettingsKeys.legacyDarkModeEnabled) != nil {
            return defaults.bool(forKey: SettingsKeys.legacyDarkModeEnabled) ? .moonlight : .daylight
        }

        return .system
    }
}

enum AppAppearanceController {
    @MainActor
    static func apply(themeMode: ThemeMode) {
        let interfaceStyle = themeMode.interfaceStyle
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { window in
                window.overrideUserInterfaceStyle = interfaceStyle
            }
    }
}

enum SWTheme {
    static let accentGreen = Color.dynamic(light: 0x62B889, dark: 0x74F380)
    static let accentBlue = Color.dynamic(light: 0x6A9FD2, dark: 0x4FA8FF)
    static let accentOrange = Color.dynamic(light: 0xD99364, dark: 0xFF9F5A)
    static let accentPink = Color.dynamic(light: 0xD686A8, dark: 0xFF67B2)
    static let primaryText = Color.dynamic(light: 0x122338, dark: 0xFFFFFF)
    static let textSecondary = Color.dynamic(light: 0x5F6F7E, dark: 0xBAC7DC)

    static let toolbarPillText = Color.dynamic(light: 0x445363, dark: 0xEEF4FF)
    static let toolbarPillFill = Color.dynamic(
        light: 0xFFFFFF,
        dark: 0xFFFFFF,
        lightAlpha: 0.56,
        darkAlpha: 0.14
    )
    static let toolbarPickerTextFont: Font = .caption.weight(.semibold)
    static let toolbarPickerChevronFont: Font = .caption2.weight(.semibold)
    static let toolbarControlSpacing: CGFloat = 6
    static let toolbarPickerHorizontalPadding: CGFloat = 8
    static let toolbarPickerVerticalPadding: CGFloat = 4

    static let appBackground = LinearGradient(
        colors: [
            Color.dynamic(light: 0xF8FBFF, dark: 0x0A0F1E),
            Color.dynamic(light: 0xEEF5FF, dark: 0x121A2F),
            Color.dynamic(light: 0xE3ECFB, dark: 0x080B16)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum SWMotion {
    static let quick = Animation.spring(response: 0.22, dampingFraction: 0.86, blendDuration: 0.04)
    static let fluid = Animation.spring(response: 0.42, dampingFraction: 0.72, blendDuration: 0.08)
    static let settle = Animation.spring(response: 0.30, dampingFraction: 0.82, blendDuration: 0.05)
}

private struct SWChartPageActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var swChartPageIsActive: Bool {
        get { self[SWChartPageActiveKey.self] }
        set { self[SWChartPageActiveKey.self] = newValue }
    }
}

enum SWChartEntranceStyle {
    case radial
    case horizontal
    case vertical
}

private struct SWChartEntranceRequest: Equatable {
    let isActive: Bool
    let isMotionLimited: Bool
    let replay: AnyHashable
}

struct SWChartEntrance<Content: View>: View {
    @Environment(\.swChartPageIsActive) private var isActive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    var replay: AnyHashable = 0
    let content: (Double, Animation?) -> Content

    var body: some View {
        let motionLimited = reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
        let request = SWChartEntranceRequest(
            isActive: isActive,
            isMotionLimited: motionLimited,
            replay: replay
        )

        content(
            !isActive || motionLimited || isRevealed ? 1 : 0,
            !isActive || motionLimited || !isRevealed ? nil : .easeOut(duration: 1.0)
        )
            .task(id: request) {
                setRevealed(false)
                guard isActive, !motionLimited else { return }
                do {
                    try await Task.sleep(for: .milliseconds(35))
                    try Task.checkCancellation()
                } catch {
                    return
                }
                isRevealed = true
            }
            .onDisappear {
                setRevealed(false)
            }
    }

    private func setRevealed(_ value: Bool) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isRevealed = value
        }
    }
}

private struct SWChartEntranceModifier: ViewModifier {
    let style: SWChartEntranceStyle
    let replay: AnyHashable

    func body(content: Content) -> some View {
        SWChartEntrance(replay: replay) { progress, animation in
            content.mask {
                // Keep chart data, axes and hit testing unchanged.
                SWChartRevealShape(style: style, progress: progress)
                    .animation(animation, value: progress)
            }
        }
    }
}

struct SWChartRevealShape: Shape {
    let style: SWChartEntranceStyle
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let fraction = min(max(progress, 0), 1)
        guard fraction > 0 else { return Path() }
        // Preserve round stroke caps and shadows beyond the plot's bounds.
        let bounds = rect.insetBy(dx: -24, dy: -24)
        guard fraction < 1 else { return Path(bounds) }

        switch style {
        case .horizontal:
            return Path(CGRect(
                x: bounds.minX, y: bounds.minY,
                width: rect.width * fraction + 24, height: bounds.height
            ))
        case .vertical:
            return Path(CGRect(
                x: bounds.minX, y: rect.maxY - rect.height * fraction,
                width: bounds.width, height: rect.height * fraction + 24
            ))
        case .radial:
            let center = CGPoint(x: rect.midX, y: rect.midY)
            var path = Path()
            path.move(to: center)
            path.addArc(
                center: center,
                radius: hypot(rect.width / 2, rect.height / 2) + 24,
                startAngle: .degrees(-90),
                endAngle: .degrees(-90 + 360 * fraction),
                clockwise: false
            )
            path.closeSubpath()
            return path
        }
    }
}

extension View {
    func chartEntrance(_ style: SWChartEntranceStyle, replay: AnyHashable = 0) -> some View {
        modifier(SWChartEntranceModifier(style: style, replay: replay))
    }
}

extension Color {
    static func dynamic(
        light: UInt,
        dark: UInt,
        lightAlpha: Double = 1.0,
        darkAlpha: Double = 1.0
    ) -> Color {
        Color(
            uiColor: UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor.sw(dark, alpha: darkAlpha)
                }
                return UIColor.sw(light, alpha: lightAlpha)
            }
        )
    }

    static func sw(_ hex: UInt, alpha: Double = 1.0) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

extension UIColor {
    static func sw(_ hex: UInt, alpha: Double = 1.0) -> UIColor {
        UIColor(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}

private struct MainPageTitleModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(PersistentMainNavigationBarModifier())
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) { titleLabel }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { titleLabel }
                }
            }
    }

    private var titleLabel: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .foregroundStyle(SWTheme.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("mainPageTitle")
    }
}

private struct PersistentMainNavigationBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        // The 27.0 runtime cannot resolve this modifier built with the 27.1 SDK.
        if #available(iOS 27.1, *) {
            content.toolbarMinimizationBehavior(.never, for: .navigationBar)
        } else {
            content
        }
    }
}

private struct SWSystemNavigationKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SWWideLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SWWorkspaceKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SWWorkspaceOverrideKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

private struct SWMainPageBottomClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var swUsesSystemNavigation: Bool {
        get { self[SWSystemNavigationKey.self] }
        set { self[SWSystemNavigationKey.self] = newValue }
    }

    var swWideLayout: Bool {
        get { self[SWWideLayoutKey.self] }
        set { self[SWWideLayoutKey.self] = newValue }
    }

    var swUsesWorkspace: Bool {
        get { self[SWWorkspaceKey.self] }
        set { self[SWWorkspaceKey.self] = newValue }
    }

    var swWorkspaceOverride: Bool? {
        get { self[SWWorkspaceOverrideKey.self] }
        set { self[SWWorkspaceOverrideKey.self] = newValue }
    }

    var swMainPageBottomClearance: CGFloat {
        get { self[SWMainPageBottomClearanceKey.self] }
        set { self[SWMainPageBottomClearanceKey.self] = newValue }
    }
}

enum SWAdaptiveLayout {
    static let compactMaximumWidth: CGFloat = 760

    static func usesWorkspace(size: CGSize, isInnerDisplay: Bool, dynamicTypeSize: DynamicTypeSize) -> Bool {
        isInnerDisplay && size.width > size.height && size.width >= 760 && !dynamicTypeSize.isAccessibilitySize
    }

    static func usesColumns(width: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Bool {
        width >= 600 && !dynamicTypeSize.isAccessibilitySize
    }
}

struct SWOverviewLayout: Layout {
    var preferredRingSize: CGFloat = 94
    private let spacing: CGFloat = 12
    private let textSpacing: CGFloat = 8

    private struct Measurements {
        let textWidth: CGFloat
        let title: CGSize
        let amount: CGSize
        let detail: CGSize
        let ring: CGFloat
        let fullWidthAmount: Bool

        var textHeight: CGFloat { title.height + amount.height + detail.height + 16 }
        var headerHeight: CGFloat { max(title.height, ring) }
        var height: CGFloat {
            fullWidthAmount ? headerHeight + amount.height + detail.height + 16 : max(textHeight, ring)
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 4 else { return .zero }
        let width: CGFloat
        if let proposedWidth = proposal.width, proposedWidth.isFinite {
            width = max(0, proposedWidth)
        } else {
            width = (subviews.prefix(3).map { $0.sizeThatFits(.unspecified).width }.max() ?? 0) + preferredRingSize + spacing
        }
        let sizes = measuredSizes(width: width, subviews: subviews)
        return CGSize(width: width, height: sizes.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 4 else { return }
        let sizes = measuredSizes(width: bounds.width, subviews: subviews)
        let titleY = sizes.fullWidthAmount
            ? bounds.minY + (sizes.headerHeight - sizes.title.height) / 2
            : bounds.midY - sizes.textHeight / 2
        let amountY = sizes.fullWidthAmount
            ? bounds.minY + sizes.headerHeight + textSpacing
            : titleY + sizes.title.height + textSpacing
        let amountWidth = sizes.fullWidthAmount ? bounds.width : sizes.textWidth
        subviews[0].place(at: CGPoint(x: bounds.minX, y: titleY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: sizes.textWidth, height: sizes.title.height))
        subviews[1].place(at: CGPoint(x: bounds.minX, y: amountY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: amountWidth, height: sizes.amount.height))
        subviews[2].place(at: CGPoint(x: bounds.minX, y: amountY + sizes.amount.height + textSpacing), anchor: .topLeading,
                          proposal: ProposedViewSize(width: amountWidth, height: sizes.detail.height))
        let ringY = sizes.fullWidthAmount
            ? bounds.minY + (sizes.headerHeight - sizes.ring) / 2 : bounds.midY - sizes.ring / 2
        subviews[3].place(at: CGPoint(x: bounds.maxX - sizes.ring, y: ringY),
                          anchor: .topLeading, proposal: ProposedViewSize(width: sizes.ring, height: sizes.ring))
    }

    private func measuredSizes(width: CGFloat, subviews: Subviews) -> Measurements {
        let ring = min(preferredRingSize, max(56, width * 0.28), max(0, width - spacing))
        let textWidth = max(0, width - ring - spacing)
        let fullWidthAmount = subviews[1].sizeThatFits(.unspecified).width * 0.6 > textWidth
        let amountWidth = fullWidthAmount ? width : textWidth
        return Measurements(
            textWidth: textWidth,
            title: subviews[0].sizeThatFits(ProposedViewSize(width: textWidth, height: nil)),
            amount: subviews[1].sizeThatFits(ProposedViewSize(width: amountWidth, height: nil)),
            detail: subviews[2].sizeThatFits(ProposedViewSize(width: amountWidth, height: nil)),
            ring: ring, fullWidthAmount: fullWidthAmount
        )
    }
}

struct SWAdaptivePairLayout: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let idealColumnWidth = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let width = proposal.width.flatMap { $0.isFinite ? max(0, $0) : nil } ?? idealColumnWidth * 2 + spacing
        let horizontal = width >= idealColumnWidth * 2 + spacing
        let sizes = measuredSizes(width: width, horizontal: horizontal, subviews: subviews)
        let height = horizontal ? max(sizes[0].height, sizes[1].height) : sizes[0].height + spacing + sizes[1].height
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let idealColumnWidth = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let horizontal = bounds.width >= idealColumnWidth * 2 + spacing
        let sizes = measuredSizes(width: bounds.width, horizontal: horizontal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let x = horizontal && index == 1 ? bounds.minX + sizes[0].width + spacing : bounds.minX
            let y = !horizontal && index == 1 ? bounds.minY + sizes[0].height + spacing : bounds.minY
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(sizes[index]))
        }
    }

    private func measuredSizes(width: CGFloat, horizontal: Bool, subviews: Subviews) -> [CGSize] {
        let columnWidth = horizontal ? max(0, (width - spacing) / 2) : width
        return subviews.map { subview in
            let measured = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            return CGSize(width: columnWidth, height: measured.height)
        }
    }
}

struct SWWorkspacePage<Primary: View, Secondary: View>: View {
    @Environment(\.swUsesWorkspace) private var usesWorkspace
    @Environment(\.swMainPageBottomClearance) private var bottomClearance
    @State private var primaryPosition = SWScrollPosition()
    @State private var secondaryPosition = SWScrollPosition()
    var showSecondaryInCompact = false
    var secondaryScrolls = true
    @ViewBuilder var primary: () -> Primary
    @ViewBuilder var secondary: () -> Secondary

    var body: some View {
        GeometryReader { geometry in
            if usesWorkspace {
                SWAdaptiveColumns(isWide: true, fillsHeight: true) {
                    SWAnchoredScrollView(position: primaryPosition) {
                        primary().padding(.vertical, 10).padding(.bottom, bottomClearance)
                    }
                    .accessibilityIdentifier("adaptive.page")
                    .accessibilityValue("wide")
                    secondaryPane
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
            } else {
                SWAnchoredScrollView(position: primaryPosition) {
                    VStack(spacing: 18) {
                        primary()
                        if showSecondaryInCompact { secondary() }
                    }
                    .frame(width: min(SWAdaptiveLayout.compactMaximumWidth, max(0, geometry.size.width - 32)),
                           alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 28 + bottomClearance)
                }
                .accessibilityIdentifier("adaptive.page")
                .accessibilityValue("compact")
            }
        }
        .environment(\.swWideLayout, false)
    }

    @ViewBuilder
    private var secondaryPane: some View {
        if secondaryScrolls {
            SWAnchoredScrollView(position: secondaryPosition) {
                secondary().padding(.vertical, 10).padding(.bottom, 28 + bottomClearance)
            }
            .accessibilityIdentifier("workspace.secondary")
        } else {
            secondary()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .accessibilityIdentifier("workspace.secondary")
        }
    }
}

private final class SWScrollPosition: ObservableObject {
    @Published var id: UUID?
}

private struct SWAnchoredScrollView<Content: View>: View {
    @ObservedObject var position: SWScrollPosition
    let content: Content

    init(position: SWScrollPosition, @ViewBuilder content: () -> Content) {
        self.position = position
        self.content = content()
    }

    var body: some View {
        // Updating the visible row must not rebuild the page's data or every row.
        ScrollView(showsIndicators: false) { content }
            .scrollPosition(id: $position.id)
    }
}

struct SWAdaptiveColumns<Content: View>: View {
    @State private var divisionGap: CGRect?
    let isWide: Bool
    var fillsHeight = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        layout { content() }
            .onGeometryChange(for: CGRect?.self) { geometry in
                guard isWide else { return nil }
                if #available(iOS 27.1, *) {
                    for region in geometry.reservedRegions(kind: .division, options: .includeInactive) {
                        guard region.frame.height > region.frame.width else { continue }
                        let start = region.frame.minX - region.margins.leading - 10
                        let end = region.frame.maxX + region.margins.trailing + 10
                        guard start >= 160, geometry.size.width - end >= 160 else { continue }
                        // Only the horizontal gap affects this layout; scrolling must not relayout it.
                        return CGRect(x: start, y: 0, width: end - start, height: 1)
                    }
                }
                return nil
            } action: { divisionGap = $0 }
    }

    private var layout: AnyLayout {
        if isWide, let divisionGap {
            return AnyLayout(SWDivisionColumnsLayout(gap: divisionGap, fillsHeight: fillsHeight))
        }
        return isWide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 20))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
    }
}

private struct SWDivisionColumnsLayout: Layout {
    let gap: CGRect
    let fillsHeight: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? gap.maxX + 160
        let sizes = measuredSizes(width: width, height: fillsHeight ? proposal.height : nil, subviews: subviews)
        return CGSize(width: width, height: (fillsHeight ? proposal.height : nil) ?? sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = measuredSizes(width: bounds.width, height: fillsHeight ? bounds.height : nil, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let x = index == 0 ? bounds.minX : bounds.minX + gap.maxX
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: sizes[index].width, height: fillsHeight ? bounds.height : nil))
        }
    }

    private func measuredSizes(width: CGFloat, height: CGFloat?, subviews: Subviews) -> [CGSize] {
        subviews.enumerated().map { index, subview in
            let columnWidth = index == 0 ? gap.minX : max(0, width - gap.maxX)
            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: height))
            return CGSize(width: columnWidth, height: size.height)
        }
    }
}

struct SWAdaptivePage<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var scrollAnchor: UUID?
    var maximumWidth: CGFloat = 1120
    @ViewBuilder var content: (Bool) -> Content

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = min(maximumWidth, max(0, geometry.size.width - 32))
            let isWide = SWAdaptiveLayout.usesColumns(width: contentWidth, dynamicTypeSize: dynamicTypeSize)
            ScrollView(showsIndicators: false) {
                content(isWide)
                    .frame(width: contentWidth, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
            }
            .scrollPosition(id: $scrollAnchor)
            .environment(\.swWideLayout, isWide)
            .accessibilityIdentifier("adaptive.page")
            .accessibilityValue(isWide ? "wide" : "compact")
        }
    }
}

private struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            FlowingGlassBackground()
            content
        }
    }
}

private struct FlowingGlassBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            SWTheme.appBackground
                .ignoresSafeArea()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            SWTheme.accentBlue.opacity(colorScheme == .light ? 0.10 : 0.12),
                            Color.clear,
                            SWTheme.accentGreen.opacity(colorScheme == .light ? 0.08 : 0.09)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .ignoresSafeArea()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            SWTheme.accentOrange.opacity(colorScheme == .light ? 0.055 : 0.065),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .ignoresSafeArea()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .light ? 0.18 : 0.045),
                            Color.white.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .ignoresSafeArea()
        }
    }
}

struct SWResponsiveButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var pressedScale: CGFloat = 0.965

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(reduceMotion ? nil : SWMotion.quick, value: configuration.isPressed)
    }
}

private struct FitnessCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let topColor = colorScheme == .light
            ? Color.sw(0x8FA9C6, alpha: 0.34)
            : Color.white.opacity(0.12)
        let bottomColor = colorScheme == .light
            ? Color.sw(0x5C7391, alpha: 0.18)
            : Color.white.opacity(0.04)
        let borderColor = colorScheme == .light
            ? Color.white.opacity(0.54)
            : Color.white.opacity(0.18)
        let shadowColor = colorScheme == .light
            ? Color.sw(0x95B4D5, alpha: 0.12)
            : Color.black.opacity(0.22)
        let sheenColor = colorScheme == .light
            ? Color.white.opacity(0.28)
            : Color.white.opacity(0.08)

        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                topColor,
                                bottomColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .light ? 0.04 : 0.01))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [sheenColor, .clear, Color.white.opacity(0.01)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(color: shadowColor, radius: 12, x: 0, y: 8)
            )
    }
}

extension View {
    func fixedMainPageTitle(_ title: String) -> some View {
        modifier(MainPageTitleModifier(title: title))
    }

    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }

    func fitnessCard() -> some View {
        modifier(FitnessCardModifier())
    }
}
