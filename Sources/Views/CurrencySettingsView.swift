import SwiftUI

private struct CurrencyRateItem: Identifiable {
    let descriptor: CurrencyDescriptor
    let rateAgainstBase: Double

    var id: String { descriptor.code }
}

@MainActor
struct CurrencySettingsView: View {
    @ObservedObject private var currencyStore = CurrencyStore.shared
    @State private var searchText = ""

    private var baseCurrency: CurrencyDescriptor {
        CurrencyCatalog.descriptor(for: currencyStore.baseCurrencyCode)
    }

    private var lastUpdatedText: String {
        guard let lastUpdated = currencyStore.lastUpdated else { return "未更新" }
        return lastUpdated.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
                .locale(Locale(identifier: "zh_CN"))
        )
    }

    private var rateItems: [CurrencyRateItem] {
        let baseCode = currencyStore.baseCurrencyCode
        let items = currencyStore.descriptors.compactMap { descriptor -> CurrencyRateItem? in
            guard descriptor.code != baseCode else { return nil }
            guard let rate = currencyStore.rate(from: baseCode, to: descriptor.code) else { return nil }
            return CurrencyRateItem(descriptor: descriptor, rateAgainstBase: rate)
        }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return items }

        return items
            .filter {
                $0.descriptor.code.localizedCaseInsensitiveContains(keyword) ||
                    $0.descriptor.name.localizedCaseInsensitiveContains(keyword)
            }
    }

    var body: some View {
        List {
            Section {
                baseCurrencyCard
            }

            Section("其他币种实时汇率") {
                ForEach(rateItems) { item in
                    Button {
                        currencyStore.setBaseCurrency(code: item.descriptor.code)
                        HapticService.selection()
                    } label: {
                        HStack(spacing: 10) {
                            Text(item.descriptor.flag)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.descriptor.code) · \(item.descriptor.name)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("1 \(currencyStore.baseCurrencyCode) ≈ \(rateText(item.rateAgainstBase, code: item.descriptor.code))")
                                    .font(.caption)
                                    .foregroundStyle(SWTheme.textSecondary)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("货币选择")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜索币种代码或名称")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("刷新") {
                    Task {
                        await currencyStore.refreshRates(force: true)
                    }
                }
                .fontWeight(.semibold)
                .disabled(currencyStore.isLoading)
            }
        }
        .task {
            await currencyStore.refreshRates(force: false)
        }
    }

    private var baseCurrencyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("本位币")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SWTheme.textSecondary)

            HStack(spacing: 10) {
                Text(baseCurrency.flag)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(baseCurrency.code) · \(baseCurrency.name)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("默认本位币为人民币，可在下方点选切换")
                        .font(.caption)
                        .foregroundStyle(SWTheme.textSecondary)
                }
                Spacer()
            }

            Text("汇率更新时间：\(lastUpdatedText)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SWTheme.textSecondary)

            if let errorMessage = currencyStore.errorMessage {
                Text(errorMessage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SWTheme.accentOrange)
            }
        }
        .padding(.vertical, 4)
    }

    private func rateText(_ rate: Double, code: String) -> String {
        let digits = CurrencyCatalog.fractionDigits(for: code) == 0 ? 4 : 4
        return rate.formatted(.number.precision(.fractionLength(digits)))
    }
}
