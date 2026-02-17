import SwiftData
import SwiftUI

@main
struct SimpleWorthApp: App {
    @AppStorage("settings.darkModeEnabled") private var darkModeEnabled = true

    private let sharedModelContainer: ModelContainer

    init() {
        let iCloudSyncEnabled = UserDefaults.standard.bool(forKey: SettingsKeys.iCloudSyncEnabled)
        sharedModelContainer = Self.makeModelContainer(iCloudSyncEnabled: iCloudSyncEnabled)
    }

    var body: some Scene {
        WindowGroup {
            SeededRootView()
                .preferredColorScheme(darkModeEnabled ? .dark : .light)
        }
        .modelContainer(sharedModelContainer)
    }

    private static func makeModelContainer(iCloudSyncEnabled: Bool) -> ModelContainer {
        let schema = Schema([
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
            return container
        }

        let localConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        if let localContainer = try? ModelContainer(for: schema, configurations: [localConfiguration]) {
            UserDefaults.standard.set(false, forKey: SettingsKeys.iCloudSyncEnabled)
            return localContainer
        }

        let inMemoryConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        if let inMemoryContainer = try? ModelContainer(for: schema, configurations: [inMemoryConfiguration]) {
            UserDefaults.standard.set(false, forKey: SettingsKeys.iCloudSyncEnabled)
            return inMemoryContainer
        }

        fatalError("Could not create ModelContainer in any mode")
    }
}

private struct SeededRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hasSeeded = false

    var body: some View {
        MainTabView()
            .task {
                guard !hasSeeded else { return }
                hasSeeded = true
                SeedService.seedIfNeeded(context: modelContext)
            }
    }
}
