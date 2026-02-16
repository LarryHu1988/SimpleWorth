import SwiftData
import SwiftUI

@main
struct SimpleWorthApp: App {
    @AppStorage("settings.darkModeEnabled") private var darkModeEnabled = true

    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LedgerEntry.self,
            SavingsGoalRecord.self,
            VaultDepositRecord.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            SeededRootView()
                .preferredColorScheme(darkModeEnabled ? .dark : .light)
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct SeededRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hasSeeded = false

    var body: some View {
        AppLockContainer {
            MainTabView()
        }
            .task {
                guard !hasSeeded else { return }
                hasSeeded = true
                SeedService.seedIfNeeded(context: modelContext)
            }
    }
}
