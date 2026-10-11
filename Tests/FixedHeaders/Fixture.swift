import SwiftData
import SwiftUI

@main
struct FixedHeaderCheckApp: App {
    @StateObject private var controller: AppRuntimeController
    private let language: AppLanguage

    init() {
        let language = AppLanguage(rawValue: ProcessInfo.processInfo.environment["HEADER_LANGUAGE"] ?? "zh-Hans")
            ?? .simplifiedChinese
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: SettingsKeys.appLanguage)
        let controller = AppRuntimeController()
        let context = controller.container.mainContext
        if (try? context.fetchCount(FetchDescriptor<LedgerEntry>())) == 0 {
            for flow in FlowType.allCases {
                let category = CategoryItem(flow: flow, name: "QA", symbol: "cart", colorHex: 0x308BDD)
                for index in 0..<40 {
                    context.insert(LedgerEntry(
                        amount: Double(index + 1), note: "QA entry \(index)", flow: flow, category: category
                    ))
                }
            }
            for index in 0..<12 {
                let goal = SavingsGoalRecord(
                    name: "QA goal \(index)", symbol: "target", currentAmount: 50,
                    targetAmount: 100, tintHex: 0x308BDD
                )
                context.insert(goal)
                context.insert(VaultDepositRecord(amount: 50, note: "QA deposit", goal: goal))
            }
            try? context.save()
        }
        _controller = StateObject(wrappedValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(controller)
                .environment(\.locale, language.locale)
                .modelContainer(controller.container)
                .preferredColorScheme(.light)
                .sheet(isPresented: $controller.isStatsSettingsPresented) {
                    SettingsNavigationHost(path: $controller.statsSettingsPath)
                        .environmentObject(controller)
                        .environment(\.locale, language.locale)
                        .modelContainer(controller.container)
                }
        }
    }
}
