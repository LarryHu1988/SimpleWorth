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
        debugRootView
            .environmentObject(appRuntimeController)
            .environment(\.locale, appLanguage.locale)
            .modelContainer(appRuntimeController.modelContainer)
            .task(id: themeMode.rawValue) {
                await MainActor.run {
                    AppAppearanceController.apply(themeMode: themeMode)
                }
            }
    }

    @ViewBuilder
    private var debugRootView: some View {
#if DEBUG
        switch ProcessInfo.processInfo.environment["SIMPLEWORTH_DEBUG_SCREEN"] {
        case "settings":
            DebugSettingsNavigationHost()
        case "currency":
            NavigationStack {
                CurrencySettingsView()
            }
        case "icloud":
            NavigationStack {
                ICloudSettingsView()
            }
        default:
            SeededRootView()
        }
#else
        SeededRootView()
#endif
    }
}

private struct DebugSettingsNavigationHost: View {
    @State private var path: [SettingsRoute] = []

    var body: some View {
        SettingsNavigationHost(path: $path)
    }
}

@MainActor
final class AppRuntimeController: ObservableObject {
    struct ICloudSyncUpdateOutcome {
        let effectiveEnabled: Bool
        let error: Error?
        let fallbackReason: String?
    }

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
    func updateICloudSync(
        enabled: Bool,
        seedPayload: LedgerBackupPayload? = nil
    ) -> ICloudSyncUpdateOutcome {
        let previousEnabled = defaults.bool(forKey: SettingsKeys.iCloudSyncEnabled)
        let result = AppModelContainerFactory.make(iCloudSyncEnabled: enabled, defaults: defaults)
        if enabled && !result.isICloudSyncEnabled {
            defaults.set(false, forKey: SettingsKeys.iCloudSyncEnabled)
            return ICloudSyncUpdateOutcome(
                effectiveEnabled: false,
                error: result.error,
                fallbackReason: result.error?.localizedDescription
            )
        }

        if let seedPayload {
            do {
                try AppModelContainerFactory.seedContainerIfNeeded(
                    result.container,
                    with: seedPayload,
                    overwriteExistingData: !enabled
                )
            } catch {
                defaults.set(previousEnabled, forKey: SettingsKeys.iCloudSyncEnabled)
                return ICloudSyncUpdateOutcome(
                    effectiveEnabled: previousEnabled,
                    error: error,
                    fallbackReason: error.localizedDescription
                )
            }
        }

        modelContainer = result.container
        return ICloudSyncUpdateOutcome(
            effectiveEnabled: result.isICloudSyncEnabled,
            error: nil,
            fallbackReason: nil
        )
    }
}

private enum AppModelContainerFactory {
    static func make(
        iCloudSyncEnabled: Bool,
        defaults: UserDefaults = .standard
    ) -> (container: ModelContainer, isICloudSyncEnabled: Bool, error: Error?) {
        let schema = Schema([
            TagRecord.self,
            LedgerEntry.self,
            SavingsGoalRecord.self,
            VaultDepositRecord.self
        ])

        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = iCloudSyncEnabled
            ? .private(AppConfig.iCloudContainerIdentifier)
            : .none

        let configurationName = iCloudSyncEnabled ? "SimpleWorthICloudStore" : "SimpleWorthLocalStore"

        do {
            let storeURL = try persistentStoreURL(iCloudSyncEnabled: iCloudSyncEnabled)
            let primaryConfiguration = ModelConfiguration(
                configurationName,
                schema: schema,
                url: storeURL,
                cloudKitDatabase: cloudKitDatabase
            )

            let container = try ModelContainer(for: schema, configurations: [primaryConfiguration])
            defaults.set(iCloudSyncEnabled, forKey: SettingsKeys.iCloudSyncEnabled)
            return (container, iCloudSyncEnabled, nil)
        } catch {
            if !iCloudSyncEnabled {
                return makeFallbackLocalContainer(schema: schema, defaults: defaults, fallbackError: error)
            }

            return makeFallbackLocalContainer(schema: schema, defaults: defaults, fallbackError: error)
        }
    }

    private static func makeFallbackLocalContainer(
        schema: Schema,
        defaults: UserDefaults,
        fallbackError: Error?
    ) -> (container: ModelContainer, isICloudSyncEnabled: Bool, error: Error?) {
        let localConfiguration: ModelConfiguration? = {
            guard let url = try? persistentStoreURL(iCloudSyncEnabled: false) else { return nil }
            return ModelConfiguration(
                "SimpleWorthLocalStore",
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
        }()
        if let localConfiguration,
           let localContainer = try? ModelContainer(for: schema, configurations: [localConfiguration]) {
            defaults.set(false, forKey: SettingsKeys.iCloudSyncEnabled)
            return (localContainer, false, fallbackError)
        }

        let inMemoryConfiguration = ModelConfiguration(
            "SimpleWorthInMemoryStore",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        if let inMemoryContainer = try? ModelContainer(for: schema, configurations: [inMemoryConfiguration]) {
            defaults.set(false, forKey: SettingsKeys.iCloudSyncEnabled)
            return (inMemoryContainer, false, fallbackError)
        }

        fatalError("Could not create ModelContainer in any mode")
    }

    private static func persistentStoreURL(iCloudSyncEnabled: Bool) throws -> URL {
        let supportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let storesDirectory = supportDirectory.appendingPathComponent("Stores", isDirectory: true)
        try FileManager.default.createDirectory(at: storesDirectory, withIntermediateDirectories: true)
        let fileName = iCloudSyncEnabled ? "SimpleWorth-iCloud.store" : "SimpleWorth-local.store"
        return storesDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    @MainActor
    static func seedContainerIfNeeded(
        _ container: ModelContainer,
        with payload: LedgerBackupPayload,
        overwriteExistingData: Bool
    ) throws {
        let context = container.mainContext
        let existingEntries = try context.fetch(FetchDescriptor<LedgerEntry>())
        let existingTags = try context.fetch(FetchDescriptor<TagRecord>())
        let existingGoals = try context.fetch(FetchDescriptor<SavingsGoalRecord>())
        let existingDeposits = try context.fetch(FetchDescriptor<VaultDepositRecord>())

        let destinationHasData =
            !existingEntries.isEmpty ||
            !existingTags.isEmpty ||
            !existingGoals.isEmpty ||
            !existingDeposits.isEmpty

        guard overwriteExistingData || !destinationHasData else {
            return
        }

        try LedgerBackupCoordinator.replaceLocalData(
            with: payload,
            context: context,
            entries: existingEntries,
            tags: existingTags,
            goals: existingGoals,
            deposits: existingDeposits
        )
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
