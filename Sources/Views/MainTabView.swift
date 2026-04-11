import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appRuntimeController: AppRuntimeController

    var body: some View {
        TabView(selection: selectedTabBinding) {
            NavigationStack {
                ExpenseView()
            }
            .tag(AppRuntimeController.MainTab.expense)
            .tabItem {
                Label("支出", systemImage: "minus.circle.fill")
            }

            NavigationStack {
                IncomeView()
            }
            .tag(AppRuntimeController.MainTab.income)
            .tabItem {
                Label("收入", systemImage: "plus.circle.fill")
            }

            NavigationStack {
                VaultView()
            }
            .tag(AppRuntimeController.MainTab.vault)
            .tabItem {
                Label("金库", systemImage: "lock.shield.fill")
            }

            NavigationStack {
                StatsView()
            }
            .tag(AppRuntimeController.MainTab.stats)
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

    private var selectedTabBinding: Binding<AppRuntimeController.MainTab> {
        Binding(
            get: { appRuntimeController.selectedMainTab },
            set: { appRuntimeController.selectedMainTab = $0 }
        )
    }
}
