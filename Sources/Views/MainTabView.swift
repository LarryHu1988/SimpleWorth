import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var appRuntimeController: AppRuntimeController
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.swWorkspaceOverride) private var workspaceOverride
    @State private var hasDeviceHinge = false
    @State private var floatingTabBarHeight: CGFloat = 73

    var body: some View {
        GeometryReader { geometry in
            let usesSystemNavigation = prefersSystemNavigation(in: geometry)
            let usesWorkspace = workspaceOverride ?? SWAdaptiveLayout.usesWorkspace(
                size: geometry.size, isInnerDisplay: hasInnerDivision(in: geometry), dynamicTypeSize: dynamicTypeSize
            )
            TabView(selection: selectedTabBinding) {
                NavigationStack {
                    ExpenseView()
                        .environment(\.swChartPageIsActive, appRuntimeController.selectedMainTab == .expense)
                        .toolbar(usesSystemNavigation ? .visible : .hidden, for: .tabBar)
                }
                .tabItem { Label("支出".appLocalized(in: locale), systemImage: "minus.circle.fill") }
                .tag(AppRuntimeController.MainTab.expense)

                NavigationStack {
                    IncomeView()
                        .environment(\.swChartPageIsActive, appRuntimeController.selectedMainTab == .income)
                        .toolbar(usesSystemNavigation ? .visible : .hidden, for: .tabBar)
                }
                .tabItem { Label("收入".appLocalized(in: locale), systemImage: "plus.circle.fill") }
                .tag(AppRuntimeController.MainTab.income)

                NavigationStack {
                    VaultView()
                        .environment(\.swChartPageIsActive, appRuntimeController.selectedMainTab == .vault)
                        .toolbar(usesSystemNavigation ? .visible : .hidden, for: .tabBar)
                }
                .tabItem { Label("金库".appLocalized(in: locale), systemImage: "lock.shield.fill") }
                .tag(AppRuntimeController.MainTab.vault)

                StatsView()
                    .environment(\.swChartPageIsActive, appRuntimeController.selectedMainTab == .stats)
                    .toolbar(usesSystemNavigation ? .visible : .hidden, for: .tabBar)
                .tabItem { Label("统计".appLocalized(in: locale), systemImage: "chart.bar.xaxis") }
                .tag(AppRuntimeController.MainTab.stats)
            }
            .tint(SWTheme.accentGreen)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !usesSystemNavigation {
                    LiquidGooeyTabBar(selection: selectedTabBinding)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { floatingTabBarHeight = $0 }
                }
            }
            .environment(\.swUsesSystemNavigation, usesSystemNavigation)
            .environment(\.swUsesWorkspace, usesWorkspace)
            .environment(\.swMainPageBottomClearance, usesSystemNavigation ? 0 : floatingTabBarHeight)
            .onChange(of: usesWorkspace, initial: true) { _, value in
                appRuntimeController.usesWorkspace = value
            }
        }
        .modifier(SWFoldableObserver { hasDeviceHinge = $0 })
    }

    private func hasInnerDivision(in geometry: GeometryProxy) -> Bool {
        if #available(iOS 27.1, *) {
            return !geometry.reservedRegions(kind: .division, options: .includeInactive).isEmpty
        }
        return false
    }

    private func prefersSystemNavigation(in geometry: GeometryProxy) -> Bool {
        if hasDeviceHinge || hasInnerDivision(in: geometry) {
            return true
        }
        return (horizontalSizeClass == .regular && geometry.size.width >= 600)
            || geometry.safeAreaInsets.leading >= 32 || geometry.safeAreaInsets.trailing >= 32
    }

    private var selectedTabBinding: Binding<AppRuntimeController.MainTab> {
        Binding(
            get: { appRuntimeController.selectedMainTab },
            set: { appRuntimeController.selectedMainTab = $0 }
        )
    }
}

private struct SWFoldableObserver: ViewModifier {
    let onChange: (Bool) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, context in onChange(context.hinge != nil) }
        } else {
            content
        }
    }
}

private struct LiquidGooeyTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    @Binding var selection: AppRuntimeController.MainTab
    @State private var leadX: CGFloat = 0
    @State private var trailX: CGFloat = 0

    private let tabs: [(tab: AppRuntimeController.MainTab, title: String, symbol: String)] = [
        (.expense, "支出", "minus.circle.fill"),
        (.income, "收入", "plus.circle.fill"),
        (.vault, "金库", "lock.shield.fill"),
        (.stats, "统计", "chart.bar.xaxis")
    ]

    var body: some View {
        GeometryReader { proxy in
            let itemWidth = proxy.size.width / CGFloat(tabs.count)
            let targetX = itemWidth * (CGFloat(selectedIndex) + 0.5)
            let usesGooeyEffect = !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .light ? 0.62 : 0.16), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(colorScheme == .light ? 0.10 : 0.28),
                        radius: 12,
                        x: 0,
                        y: 7
                    )

                if usesGooeyEffect {
                    GooeySelectionLayer(
                        leadX: leadX,
                        trailX: trailX,
                        tint: selectedTint
                    )
                    .allowsHitTesting(false)
                } else {
                    Circle()
                        .fill(selectedTint.opacity(0.92))
                        .frame(width: 46, height: 46)
                        .position(x: targetX, y: 25)
                        .allowsHitTesting(false)
                }

                HStack(spacing: 0) {
                    ForEach(tabs, id: \.tab) { item in
                        tabButton(item)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .onAppear {
                leadX = targetX
                trailX = targetX
            }
            .onChange(of: proxy.size.width) { _, _ in
                leadX = targetX
                trailX = targetX
            }
            .onChange(of: selection) { _, _ in
                guard usesGooeyEffect else {
                    leadX = targetX
                    trailX = targetX
                    return
                }

                withAnimation(.spring(response: 0.34, dampingFraction: 0.74, blendDuration: 0.05)) {
                    leadX = targetX
                }
                withAnimation(SWMotion.fluid.delay(0.025)) {
                    trailX = targetX
                }
            }
        }
        .frame(height: 62)
        .padding(.horizontal, 12)
        .padding(.top, 5)
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mainTab.bar")
    }

    private func tabButton(
        _ item: (tab: AppRuntimeController.MainTab, title: String, symbol: String)
    ) -> some View {
        let isSelected = selection == item.tab

        return Button {
            guard selection != item.tab else {
                HapticService.selection()
                return
            }
            HapticService.impact(style: .soft)
            selection = item.tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolEffect(.bounce, value: isSelected)
                    .frame(height: 24)

                Text(item.title.appLocalized(in: locale))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(isSelected ? Color.white : SWTheme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(SWResponsiveButtonStyle(pressedScale: 0.92))
        .accessibilityLabel(item.title.appLocalized(in: locale))
        .accessibilityIdentifier("mainTab.\(item.tab)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedIndex: Int {
        tabs.firstIndex(where: { $0.tab == selection }) ?? 0
    }

    private var selectedTint: Color {
        switch selection {
        case .expense:
            SWTheme.accentOrange
        case .income:
            SWTheme.accentGreen
        case .vault:
            SWTheme.accentBlue
        case .stats:
            SWTheme.accentPink
        }
    }
}

private struct GooeySelectionLayer: View, Animatable {
    var leadX: CGFloat
    var trailX: CGFloat
    let tint: Color

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(leadX, trailX) }
        set {
            leadX = newValue.first
            trailX = newValue.second
        }
    }

    var body: some View {
        Canvas { context, _ in
            context.addFilter(.blur(radius: 8))
            context.addFilter(.alphaThreshold(min: 0.46, color: tint.opacity(0.94)))

            context.drawLayer { layer in
                layer.fill(
                    Path(ellipseIn: CGRect(x: trailX - 19, y: 7, width: 38, height: 38)),
                    with: .color(.white)
                )
                layer.fill(
                    Path(ellipseIn: CGRect(x: leadX - 24, y: 2, width: 48, height: 48)),
                    with: .color(.white)
                )
            }
        }
    }
}
