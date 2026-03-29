import SwiftUI

struct ExpenseView: View {
    @Environment(\.locale) private var locale

    var body: some View {
        LedgerFlowView(flow: .expense)
            .id("expense-\(locale.identifier)")
    }
}
