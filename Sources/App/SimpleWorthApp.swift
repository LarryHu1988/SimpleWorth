import SwiftData
import SwiftUI
import UIKit

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
        ZStack {
            if appRuntimeController.isDisplayingLiveContent {
                contentHost
                    .id(appRuntimeController.containerSession.id)
                    .environmentObject(appRuntimeController)
                    .environment(\.locale, appLanguage.locale)
                    .modelContainer(appRuntimeController.containerSession.container)
                    .transition(.identity)
            }

            if appRuntimeController.isSwitchingContainer {
                ContainerSwitchingView(snapshotImage: appRuntimeController.containerTransitionSnapshot)
                    .transition(.identity)
                    .allowsHitTesting(false)
            }
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

private struct ContainerSwitchingView: View {
    let snapshotImage: UIImage?

    var body: some View {
        ZStack {
            if let snapshotImage {
                Image(uiImage: snapshotImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                SWTheme.appBackground
                    .ignoresSafeArea()
            }
        }
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

    struct ContainerSession {
        let id = UUID()
        let container: ModelContainer
    }

    struct PreparedICloudSyncUpdate {
        let outcome: ICloudSyncUpdateOutcome
        fileprivate let container: ModelContainer?
    }

    struct ICloudSyncUpdateOutcome {
        let effectiveEnabled: Bool
        let error: Error?
        let fallbackReason: String?
    }

    @Published private(set) var containerSession: ContainerSession
    @Published private(set) var isSwitchingContainer = false
    @Published private(set) var isDisplayingLiveContent = true
    @Published private(set) var containerTransitionSnapshot: UIImage?
    @Published var selectedMainTab: MainTab = .expense
    @Published var isStatsSettingsPresented = false
    @Published var statsSettingsPath: [SettingsRoute] = []

    private let defaults: UserDefaults
    private var containerSwitchTask: Task<Void, Never>?
    private var containerSwitchCleanupTask: Task<Void, Never>?
    private var isAwaitingContainerPresentationRestore = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let initialResult = AppModelContainerFactory.make(
            iCloudSyncEnabled: defaults.bool(forKey: SettingsKeys.iCloudSyncEnabled),
            defaults: defaults
        )
        self.containerSession = ContainerSession(container: initialResult.container)
    }

    func prepareICloudSyncUpdate(
        enabled: Bool,
        seedPayload: LedgerBackupPayload? = nil
    ) -> PreparedICloudSyncUpdate {
        let previousEnabled = defaults.bool(forKey: SettingsKeys.iCloudSyncEnabled)
        let result = AppModelContainerFactory.make(iCloudSyncEnabled: enabled, defaults: defaults)
        if enabled && !result.isICloudSyncEnabled {
            defaults.set(false, forKey: SettingsKeys.iCloudSyncEnabled)
            return PreparedICloudSyncUpdate(
                outcome: ICloudSyncUpdateOutcome(
                    effectiveEnabled: false,
                    error: result.error,
                    fallbackReason: result.error?.localizedDescription
                ),
                container: nil
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
                return PreparedICloudSyncUpdate(
                    outcome: ICloudSyncUpdateOutcome(
                        effectiveEnabled: previousEnabled,
                        error: error,
                        fallbackReason: error.localizedDescription
                    ),
                    container: nil
                )
            }
        }

        return PreparedICloudSyncUpdate(
            outcome: ICloudSyncUpdateOutcome(
                effectiveEnabled: result.isICloudSyncEnabled,
                error: nil,
                fallbackReason: nil
            ),
            container: result.container
        )
    }

    func commitPreparedICloudSyncUpdate(_ preparedUpdate: PreparedICloudSyncUpdate) {
        guard let container = preparedUpdate.container else { return }
        containerSwitchTask?.cancel()
        containerSwitchCleanupTask?.cancel()
        isAwaitingContainerPresentationRestore = false
        containerTransitionSnapshot = AppWindowSnapshotFactory.capture()
        isSwitchingContainer = true

        containerSwitchTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Let the frozen snapshot reach the screen first, then drop the live
            // SwiftData view tree before swapping the underlying container.
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }

            self.isDisplayingLiveContent = false

            // Give the old SwiftData-backed view tree a brief moment to fully leave
            // the hierarchy before publishing a brand-new container session.
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }

            self.containerSession = ContainerSession(container: container)

            self.isDisplayingLiveContent = true
            self.isAwaitingContainerPresentationRestore = true

            self.containerSwitchTask = nil
            self.scheduleContainerSwitchCleanupFallback()
        }
    }

    func notifyICloudSettingsDidAppearAfterContainerSwitch() {
        guard isAwaitingContainerPresentationRestore else { return }
        containerSwitchCleanupTask?.cancel()
        containerSwitchCleanupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            self.finishContainerSwitchTransition()
        }
    }

    private func scheduleContainerSwitchCleanupFallback() {
        containerSwitchCleanupTask?.cancel()
        containerSwitchCleanupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            self.finishContainerSwitchTransition()
        }
    }

    private func finishContainerSwitchTransition() {
        guard isSwitchingContainer else { return }
        isAwaitingContainerPresentationRestore = false
        isSwitchingContainer = false
        containerTransitionSnapshot = nil
        containerSwitchCleanupTask = nil
    }
}

private enum AppWindowSnapshotFactory {
    @MainActor
    static func capture() -> UIImage? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        let window = windows.first(where: \.isKeyWindow) ?? windows.last

        guard let window else { return nil }

        let format = UIGraphicsImageRendererFormat(for: window.traitCollection)
        format.scale = window.screen.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
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
