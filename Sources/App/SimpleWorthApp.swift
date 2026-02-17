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

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKitDatabase
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            if iCloudSyncEnabled {
                let localConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .none
                )
                if let fallbackContainer = try? ModelContainer(for: schema, configurations: [localConfiguration]) {
                    return fallbackContainer
                }
            }

            fatalError("Could not create ModelContainer: \(error)")
        }
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
