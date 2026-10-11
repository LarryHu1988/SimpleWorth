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
        contentHost
            .environmentObject(appRuntimeController)
            .environment(\.locale, appLanguage.locale)
            .modelContainer(appRuntimeController.container)
        .sheet(isPresented: settingsSheetPresentedBinding) {
            SettingsSheetPresentationHost(
                appRuntimeController: appRuntimeController,
                appLanguage: appLanguage,
                path: settingsNavigationPathBinding
            )
        }
        .task(id: themeMode.rawValue) {
            await MainActor.run {
                AppAppearanceController.apply(themeMode: themeMode)
            }
        }
    }

    private var contentHost: some View {
        debugRootView
    }

    private var settingsSheetPresentedBinding: Binding<Bool> {
        Binding(
            get: { appRuntimeController.isStatsSettingsPresented },
            set: { newValue in
                appRuntimeController.isStatsSettingsPresented = newValue
                if !newValue {
                    appRuntimeController.statsSettingsPath.removeAll()
                }
            }
        )
    }

    private var settingsNavigationPathBinding: Binding<[SettingsRoute]> {
        Binding(
            get: { appRuntimeController.statsSettingsPath },
            set: { appRuntimeController.statsSettingsPath = $0 }
        )
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

private struct SettingsSheetPresentationHost: View {
    @ObservedObject var appRuntimeController: AppRuntimeController
    let appLanguage: AppLanguage
    @Binding var path: [SettingsRoute]

    var body: some View {
        SettingsNavigationHost(path: $path)
            .environmentObject(appRuntimeController)
            .environment(\.locale, appLanguage.locale)
            .modelContainer(appRuntimeController.container)
        .presentationBackground(.clear)
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
    enum MainTab: Hashable {
        case expense
        case income
        case vault
        case stats
    }

    let container: ModelContainer
    @Published var selectedMainTab: MainTab = .expense
    @Published var isStatsSettingsPresented = false
    @Published var statsSettingsPath: [SettingsRoute] = []

    init(defaults: UserDefaults = .standard) {
        self.container = AppModelContainerFactory.make(defaults: defaults)
    }
}

private enum AppModelContainerFactory {
    @MainActor
    static func make(defaults: UserDefaults = .standard) -> ModelContainer {
        let schema = Schema([
            TagRecord.self,
            LedgerEntry.self,
            SavingsGoalRecord.self,
            VaultDepositRecord.self
        ])

        do {
            let storeURL = try persistentStoreURL(kind: .local)
            let primaryConfiguration = ModelConfiguration(
                "SimpleWorthLocalStore",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )

            let container = try ModelContainer(for: schema, configurations: [primaryConfiguration])
            try? migrateLegacyICloudStoreIfNeeded(into: container, schema: schema, defaults: defaults)
            return container
        } catch {
            return makeFallbackLocalContainer(schema: schema)
        }
    }

    @MainActor
    private static func makeFallbackLocalContainer(schema: Schema) -> ModelContainer {
        let localConfiguration: ModelConfiguration? = {
            guard let url = try? persistentStoreURL(kind: .local) else { return nil }
            return ModelConfiguration(
                "SimpleWorthLocalStore",
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
        }()
        if let localConfiguration,
           let localContainer = try? ModelContainer(for: schema, configurations: [localConfiguration]) {
            return localContainer
        }

        let inMemoryConfiguration = ModelConfiguration(
            "SimpleWorthInMemoryStore",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        if let inMemoryContainer = try? ModelContainer(for: schema, configurations: [inMemoryConfiguration]) {
            return inMemoryContainer
        }

        fatalError("Could not create ModelContainer in any mode")
    }

    private enum StoreKind {
        case local
        case legacyICloud
    }

    private static func persistentStoreURL(kind: StoreKind) throws -> URL {
        let supportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let storesDirectory = supportDirectory.appendingPathComponent("Stores", isDirectory: true)
        try FileManager.default.createDirectory(at: storesDirectory, withIntermediateDirectories: true)
        let fileName: String
        switch kind {
        case .local:
            fileName = "SimpleWorth-local.store"
        case .legacyICloud:
            fileName = "SimpleWorth-iCloud.store"
        }
        return storesDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    @MainActor
    private static func migrateLegacyICloudStoreIfNeeded(
        into localContainer: ModelContainer,
        schema: Schema,
        defaults: UserDefaults
    ) throws {
        guard !defaults.bool(forKey: SettingsKeys.didMigrateLegacyICloudStoreToLocal) else { return }

        let localContext = localContainer.mainContext
        let localEntries = try localContext.fetch(FetchDescriptor<LedgerEntry>())
        let localTags = try localContext.fetch(FetchDescriptor<TagRecord>())
        let localGoals = try localContext.fetch(FetchDescriptor<SavingsGoalRecord>())
        let localDeposits = try localContext.fetch(FetchDescriptor<VaultDepositRecord>())
        let localHasData =
            !localEntries.isEmpty ||
            !localTags.isEmpty ||
            !localGoals.isEmpty ||
            !localDeposits.isEmpty

        guard !localHasData else {
            defaults.set(true, forKey: SettingsKeys.didMigrateLegacyICloudStoreToLocal)
            return
        }

        let legacyStoreURL = try persistentStoreURL(kind: .legacyICloud)
        guard FileManager.default.fileExists(atPath: legacyStoreURL.path) else {
            defaults.set(true, forKey: SettingsKeys.didMigrateLegacyICloudStoreToLocal)
            return
        }

        guard let legacyContainer = makeLegacyICloudContainer(schema: schema, storeURL: legacyStoreURL) else {
            return
        }

        let legacyContext = legacyContainer.mainContext
        let legacyEntries = try legacyContext.fetch(FetchDescriptor<LedgerEntry>())
        let legacyTags = try legacyContext.fetch(FetchDescriptor<TagRecord>())
        let legacyGoals = try legacyContext.fetch(FetchDescriptor<SavingsGoalRecord>())
        let legacyDeposits = try legacyContext.fetch(FetchDescriptor<VaultDepositRecord>())

        let legacyHasData =
            !legacyEntries.isEmpty ||
            !legacyTags.isEmpty ||
            !legacyGoals.isEmpty ||
            !legacyDeposits.isEmpty

        guard legacyHasData else {
            defaults.set(true, forKey: SettingsKeys.didMigrateLegacyICloudStoreToLocal)
            return
        }

        let payload = LedgerBackupCoordinator.makePayload(
            appVersion: "legacy-iCloud-store",
            entries: legacyEntries,
            tags: legacyTags,
            goals: legacyGoals,
            deposits: legacyDeposits
        )
        try LedgerBackupCoordinator.replaceLocalData(
            with: payload,
            context: localContext,
            entries: localEntries,
            tags: localTags,
            goals: localGoals,
            deposits: localDeposits
        )
        defaults.set(true, forKey: SettingsKeys.didMigrateLegacyICloudStoreToLocal)
    }

    @MainActor
    private static func makeLegacyICloudContainer(schema: Schema, storeURL: URL) -> ModelContainer? {
        let cloudKitConfiguration = ModelConfiguration(
            "SimpleWorthLegacyICloudStore",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private(AppConfig.iCloudContainerIdentifier)
        )

        if let container = try? ModelContainer(for: schema, configurations: [cloudKitConfiguration]) {
            return container
        }

        let localReadConfiguration = ModelConfiguration(
            "SimpleWorthLegacyICloudStoreFallback",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: schema, configurations: [localReadConfiguration])
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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.themeMode) private var themeModeRaw = ThemeMode.system.rawValue
    @AppStorage(SettingsKeys.iCloudSyncEnabled) private var iCloudSyncEnabled = false
    @AppStorage(SettingsKeys.backupRetentionDays) private var backupRetentionDays = 15
    @State private var hasSeeded = false

    private var themeMode: ThemeMode {
        ThemeMode(rawValue: themeModeRaw) ?? .system
    }

    var body: some View {
        MainTabView()
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                if !hasSeeded {
                    hasSeeded = true
                    SeedService.seedIfNeeded(context: modelContext)
                }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, scenePhase == .active else { return }
                await performAutomaticBackupIfNeeded()
            }
            .task(id: themeModeRaw) {
                await MainActor.run {
                    AppAppearanceController.apply(themeMode: themeMode)
                }
            }
    }

    private func performAutomaticBackupIfNeeded() async {
        do {
            let entries = try modelContext.fetch(FetchDescriptor<LedgerEntry>())
            let tags = try modelContext.fetch(FetchDescriptor<TagRecord>())
            let goals = try modelContext.fetch(FetchDescriptor<SavingsGoalRecord>())
            let deposits = try modelContext.fetch(FetchDescriptor<VaultDepositRecord>())
            let hasAnyUserData =
                !entries.isEmpty ||
                !tags.isEmpty ||
                !goals.isEmpty ||
                !deposits.isEmpty

            guard hasAnyUserData else { return }

            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.7.16"
            let payload = LedgerBackupCoordinator.makePayload(
                appVersion: "V\(version)",
                entries: entries,
                tags: tags,
                goals: goals,
                deposits: deposits
            )
            await AppAutomaticBackupCoordinator.runIfNeeded(
                payload: payload,
                mirrorToICloud: iCloudSyncEnabled,
                retentionDays: backupRetentionDays
            )
        } catch {
            // Backup maintenance should never interrupt the primary ledger flow.
        }
    }
}
