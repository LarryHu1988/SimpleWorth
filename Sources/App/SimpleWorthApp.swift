import SwiftData
import SwiftUI

@main
struct SimpleWorthApp: App {
    @AppStorage(SettingsKeys.themeMode) private var themeModeRaw = ThemeMode.system.rawValue
    @AppStorage(SettingsKeys.appLanguage) private var appLanguageRaw = AppLanguage.simplifiedChinese.rawValue
    @StateObject private var appRuntimeController: AppRuntimeController

    init() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: SettingsKeys.themeMode) == nil {
            defaults.set(ThemeMode.resolved(from: defaults).rawValue, forKey: SettingsKeys.themeMode)
        }
        if defaults.string(forKey: SettingsKeys.appLanguage) == nil {
            defaults.set(AppLanguage.simplifiedChinese.rawValue, forKey: SettingsKeys.appLanguage)
        }
        _appRuntimeController = StateObject(wrappedValue: AppRuntimeController(defaults: defaults))
    }

    private var themeMode: ThemeMode {
        ThemeMode(rawValue: themeModeRaw) ?? ThemeMode.resolved()
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .simplifiedChinese
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                appRuntimeController: appRuntimeController,
                appLanguage: appLanguage,
                themeMode: themeMode
            )
        }
    }
}

private struct AppRootView: View {
    @ObservedObject var appRuntimeController: AppRuntimeController
    let appLanguage: AppLanguage
    let themeMode: ThemeMode

    var body: some View {
        SeededRootView()
            .environmentObject(appRuntimeController)
            .environment(\.locale, appLanguage.locale)
            .modelContainer(appRuntimeController.modelContainer)
            .task(id: themeMode.rawValue) {
                await MainActor.run {
                    AppAppearanceController.apply(themeMode: themeMode)
                }
            }
    }
}

@MainActor
final class AppRuntimeController: ObservableObject {
    @Published private(set) var modelContainer: ModelContainer

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.modelContainer = AppModelContainerFactory.make(
            iCloudSyncEnabled: defaults.bool(forKey: SettingsKeys.iCloudSyncEnabled),
            defaults: defaults
        ).container
    }

    @discardableResult
    func updateICloudSync(enabled: Bool) -> Bool {
        let result = AppModelContainerFactory.make(iCloudSyncEnabled: enabled, defaults: defaults)
        modelContainer = result.container
        return result.isICloudSyncEnabled
    }
}

private enum AppModelContainerFactory {
    static func make(
        iCloudSyncEnabled: Bool,
        defaults: UserDefaults = .standard
    ) -> (container: ModelContainer, isICloudSyncEnabled: Bool) {
        let schema = Schema([
            TagRecord.self,
            LedgerEntry.self,
            SavingsGoalRecord.self,
            VaultDepositRecord.self
        ])

        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = iCloudSyncEnabled
            ? .private(AppConfig.iCloudContainerIdentifier)
            : .none

        let primaryConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKitDatabase
        )

        if let container = try? ModelContainer(for: schema, configurations: [primaryConfiguration]) {
            defaults.set(iCloudSyncEnabled, forKey: SettingsKeys.iCloudSyncEnabled)
            return (container, iCloudSyncEnabled)
        }

        let localConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        if let localContainer = try? ModelContainer(for: schema, configurations: [localConfiguration]) {
            defaults.set(false, forKey: SettingsKeys.iCloudSyncEnabled)
            return (localContainer, false)
        }

        let inMemoryConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        if let inMemoryContainer = try? ModelContainer(for: schema, configurations: [inMemoryConfiguration]) {
            defaults.set(false, forKey: SettingsKeys.iCloudSyncEnabled)
            return (inMemoryContainer, false)
        }

        fatalError("Could not create ModelContainer in any mode")
    }
}

private struct SeededRootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKeys.themeMode) private var themeModeRaw = ThemeMode.system.rawValue
    @State private var hasSeeded = false

    private var themeMode: ThemeMode {
        ThemeMode(rawValue: themeModeRaw) ?? .system
    }

    var body: some View {
        MainTabView()
            .task {
                guard !hasSeeded else { return }
                hasSeeded = true
                SeedService.seedIfNeeded(context: modelContext)
            }
            .task(id: themeModeRaw) {
                await MainActor.run {
                    AppAppearanceController.apply(themeMode: themeMode)
                }
            }
    }
}
