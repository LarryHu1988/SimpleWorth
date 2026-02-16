import SwiftUI

struct ExpenseView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                FlowSummaryCard(
                    flow: .expense,
                    amount: 4280,
                    compareText: "较上月下降 7.8%",
                    ringProgress: 0.64
                )

                CategoryGridSection(
                    title: "支出分类",
                    subtitle: "常见生活消费图标一键记账",
                    categories: PreviewData.expenseCategories
                )

                TransactionSection(
                    title: "最近支出",
                    subtitle: "高频消费快速回顾",
                    items: PreviewData.recentExpenses
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .navigationTitle("支出")
        .navigationBarTitleDisplayMode(.large)
        .appBackground()
    }
}
