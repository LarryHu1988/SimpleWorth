import SwiftUI

struct IncomeView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                FlowSummaryCard(
                    flow: .income,
                    amount: 9150,
                    compareText: "较上月增长 10.2%",
                    ringProgress: 0.82
                )

                CategoryGridSection(
                    title: "收入分类",
                    subtitle: "工资、副业、理财等来源一屏管理",
                    categories: PreviewData.incomeCategories
                )

                TransactionSection(
                    title: "最近收入",
                    subtitle: "入账趋势一目了然",
                    items: PreviewData.recentIncomes
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .navigationTitle("收入")
        .navigationBarTitleDisplayMode(.large)
        .appBackground()
    }
}
