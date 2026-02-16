import SwiftUI

struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(SWTheme.textSecondary)
        }
    }
}

struct ProgressRing: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0))
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.6), tint, tint.opacity(0.75)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.45), radius: 8)
        }
    }
}

struct FlowSummaryCard: View {
    let flow: FlowType
    let amount: Double
    let compareText: String
    let ringProgress: Double

    private var signedAmount: Double {
        flow == .expense ? -amount : amount
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("本月\(flow.rawValue)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(signedAmount.signedCNYText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.75)
                Text(compareText)
                    .font(.footnote)
                    .foregroundStyle(SWTheme.textSecondary)
            }

            Spacer(minLength: 8)

            ZStack {
                ProgressRing(progress: ringProgress, tint: flow.accent, lineWidth: 12)
                    .frame(width: 94, height: 94)
                Image(systemName: flow.tabIcon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(flow.accent)
            }
        }
        .fitnessCard()
    }
}

struct CategoryGridSection: View {
    let title: String
    let subtitle: String
    let categories: [CategoryItem]

    private let columns = [
        GridItem(.adaptive(minimum: 70), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: title, subtitle: subtitle)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(categories) { item in
                    CategoryIconCell(item: item)
                }
            }
        }
        .fitnessCard()
    }
}

struct CategoryIconCell: View {
    let item: CategoryItem

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.2))
                    .frame(width: 52, height: 52)
                Circle()
                    .stroke(item.color.opacity(0.55), lineWidth: 1)
                    .frame(width: 52, height: 52)
                Image(systemName: item.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(item.color)
            }

            Text(item.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct TransactionSection: View {
    let title: String
    let subtitle: String
    let items: [TransactionItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: title, subtitle: subtitle)

            VStack(spacing: 10) {
                ForEach(items) { item in
                    TransactionRow(item: item)
                }
            }
        }
        .fitnessCard()
    }
}

struct TransactionRow: View {
    let item: TransactionItem

    private var signedAmount: Double {
        item.flow == .expense ? -item.amount : item.amount
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: item.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(item.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(item.dateText)
                    .font(.caption)
                    .foregroundStyle(SWTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text(signedAmount.signedCNYText)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(item.flow == .expense ? SWTheme.accentOrange : SWTheme.accentGreen)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}
