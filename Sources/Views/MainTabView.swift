import SwiftUI

struct MainTabView: View {
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
        .toolbarBackground(Color.black.opacity(0.72), for: .tabBar)
    }
}
