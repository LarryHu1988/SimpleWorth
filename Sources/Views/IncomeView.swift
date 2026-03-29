import SwiftUI

struct IncomeView: View {
    @Environment(\.locale) private var locale

    var body: some View {
        LedgerFlowView(flow: .income)
            .id("income-\(locale.identifier)")
    }
}
