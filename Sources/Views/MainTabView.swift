import SwiftUI

struct MainTabView: View {
    @Environment(\.locale) private var locale
    var body: some View {
        TabView {
            NavigationStack {
                ExpenseView()
            }
            .tabItem {
                Label("支出", systemImage: "minus.circle.fill")
            }

            NavigationStack {
                IncomeView()
            }
            .tabItem {
                Label("收入", systemImage: "plus.circle.fill")
            }

            NavigationStack {
                VaultView()
            }
            .tabItem {
                Label("金库", systemImage: "lock.shield.fill")
            }

            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("统计", systemImage: "chart.bar.xaxis")
            }
        }
        .tint(SWTheme.accentGreen)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(
            Color.dynamic(
                light: 0xF2F8FF,
                dark: 0x09111E,
                lightAlpha: 0.78,
                darkAlpha: 0.72
            ),
            for: .tabBar
        )
    }
}
