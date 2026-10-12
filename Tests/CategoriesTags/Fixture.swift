import SwiftData
import SwiftUI

@main
struct CategoriesTagsCheckApp: App {
    @StateObject private var controller = AppRuntimeController()

    var body: some Scene {
        WindowGroup {
            FixtureRoot()
                .modelContainer(controller.container)
                .environmentObject(controller)
                .environment(\.locale, Locale(identifier: ProcessInfo.processInfo.environment["QA_LANGUAGE"] ?? "zh-Hans"))
                .preferredColorScheme(.light)
        }
    }
}

private struct EditorTarget: Identifiable {
    let id: String
    let flow: FlowType
    var entry: LedgerEntry? = nil
}

private struct FixtureRoot: View {
    @Environment(\.modelContext) private var context
    @State private var editor: EditorTarget?
    @State private var storeStatus = "loading"

    var body: some View {
        NavigationStack {
            TagManagementView()
                .safeAreaInset(edge: .bottom) {
                    Text(storeStatus).accessibilityIdentifier("qa.store-status")
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack {
                            Button { editor = EditorTarget(id: "expense", flow: .expense) } label: {
                                Image(systemName: "minus.circle")
                            }
                                .accessibilityIdentifier("qa.expense")
                            Button { editor = EditorTarget(id: "income", flow: .income) } label: {
                                Image(systemName: "plus.circle")
                            }
                                .accessibilityIdentifier("qa.income")
                            Button {
                                let entry = try? context.fetch(FetchDescriptor<LedgerEntry>()).first
                                editor = EditorTarget(id: "legacy", flow: .expense, entry: entry)
                            } label: {
                                Image(systemName: "clock")
                            }
                            .accessibilityIdentifier("qa.legacy")
                        }
                    }
                }
                .task {
                    if (try? context.fetchCount(FetchDescriptor<TagRecord>())) == 0 {
                        for (index, name) in ["家庭", "通勤", "旅行"].enumerated() {
                            context.insert(TagRecord(name: name, createdAt: Date(timeIntervalSince1970: 1000 + Double(index))))
                        }
                        let category = CategoryItem(flow: .expense, name: "旧分类", symbol: "star.fill", colorHex: 0x123456)
                        context.insert(LedgerEntry(amount: 88, note: "QA legacy entry", flow: .expense, category: category, tagNames: ["家庭", "通勤"]))
                        try? context.save()
                    }
                    let ids = ((try? context.fetch(FetchDescriptor<TagRecord>())) ?? []).map { $0.id.uuidString }.sorted()
                    let defaults = UserDefaults.standard
                    if defaults.stringArray(forKey: "qa.originalTagIDs") == nil {
                        defaults.set(ids, forKey: "qa.originalTagIDs")
                    }
                    storeStatus = defaults.stringArray(forKey: "qa.originalTagIDs") == ids ? "preserved" : "changed"
                }
        }
        .sheet(item: $editor) { target in
            EntryEditorSheet(flow: target.flow, entry: target.entry, operation: target.entry == nil ? .create : .edit)
        }
    }
}
