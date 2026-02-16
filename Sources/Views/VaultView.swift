import SwiftUI

struct VaultView: View {
    private var totalCurrent: Double {
        PreviewData.savingsGoals.reduce(0) { $0 + $1.current }
    }

    private var totalTarget: Double {
        PreviewData.savingsGoals.reduce(0) { $0 + $1.target }
    }

    private var totalProgress: Double {
        guard totalTarget > 0 else { return 0 }
        return min(max(totalCurrent / totalTarget, 0), 1)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                vaultOverview

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "小目标", subtitle: "每一笔都在接近理想生活")

                    ForEach(PreviewData.savingsGoals) { goal in
                        GoalProgressCard(goal: goal)
                    }
                }
                .fitnessCard()

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "最近存入", subtitle: "把碎片现金变成长期安全感")

                    ForEach(PreviewData.vaultRecords) { item in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.note)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(item.date)
                                    .font(.caption)
                                    .foregroundStyle(SWTheme.textSecondary)
                            }

                            Spacer(minLength: 8)

                            Text(item.amount.cnyText)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(SWTheme.accentGreen)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .fitnessCard()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .navigationTitle("小金库")
        .navigationBarTitleDisplayMode(.large)
        .appBackground()
    }

    private var vaultOverview: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("当前小金库")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(totalCurrent.cnyText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.75)

                Text("总目标 \(totalTarget.cnyText)")
                    .font(.footnote)
                    .foregroundStyle(SWTheme.textSecondary)
            }

            Spacer(minLength: 8)

            ZStack {
                ProgressRing(progress: totalProgress, tint: SWTheme.accentBlue, lineWidth: 12)
                    .frame(width: 104, height: 104)

                VStack(spacing: 2) {
                    Text("进度")
                        .font(.caption2)
                        .foregroundStyle(SWTheme.textSecondary)
                    Text("\((totalProgress * 100).formatted(.number.precision(.fractionLength(0))))%")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .fitnessCard()
    }
}

private struct GoalProgressCard: View {
    let goal: SavingsGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(goal.tint.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: goal.symbol)
                        .foregroundStyle(goal.tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("截止: \(goal.deadline)")
                        .font(.caption)
                        .foregroundStyle(SWTheme.textSecondary)
                }

                Spacer(minLength: 8)

                Text("\((goal.progress * 100).formatted(.number.precision(.fractionLength(0))))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(goal.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(goal.tint.opacity(0.2))
                    )
            }

            VStack(spacing: 6) {
                HStack {
                    Text(goal.current.cnyText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(goal.target.cnyText)
                        .font(.caption)
                        .foregroundStyle(SWTheme.textSecondary)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.12))
                        Capsule(style: .continuous)
                            .fill(goal.tint.gradient)
                            .frame(width: proxy.size.width * goal.progress)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}
