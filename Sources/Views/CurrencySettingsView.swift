import SwiftUI

private struct CurrencyRateItem: Identifiable {
    let descriptor: CurrencyDescriptor
    let rateAgainstBase: Double

    var id: String { descriptor.code }
}

@MainActor
struct CurrencySettingsView: View {
    @Environment(\.swSettingsPageHorizontalPadding) private var pageHorizontalPadding
    @Environment(\.swSettingsIsEmbedded) private var isEmbedded
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @StateObject private var currencyStore: CurrencyStore
    @State private var searchText = ""

    init() {
        _currencyStore = StateObject(wrappedValue: CurrencyStore.shared)
    }

    private var baseCurrency: CurrencyDescriptor {
        CurrencyCatalog.descriptor(for: currencyStore.baseCurrencyCode)
    }

    private var lastUpdatedText: String {
        guard let lastUpdated = currencyStore.lastUpdated else { return "未更新".appLocalized(in: locale) }
        return lastUpdated.formatted(
            .dateTime
                .year()
                .month(.defaultDigits)
                .day()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(locale)
        )
    }

    private var rateItems: [CurrencyRateItem] {
        let baseCode = CurrencyCatalog.normalize(code: currencyStore.baseCurrencyCode)
        let allItems = currencyStore.supportedCurrencyCodes.compactMap { code -> CurrencyRateItem? in
            let normalizedCode = CurrencyCatalog.normalize(code: code)
            guard normalizedCode != baseCode else { return nil }
            guard let rate = currencyStore.rate(from: baseCode, to: normalizedCode) else { return nil }
            return CurrencyRateItem(
                descriptor: CurrencyCatalog.descriptor(for: normalizedCode),
                rateAgainstBase: rate
            )
        }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return allItems }

        return allItems.filter { item in
            item.descriptor.code.localizedCaseInsensitiveContains(keyword) ||
                item.descriptor.name.localizedCaseInsensitiveContains(keyword)
        }
    }

    private var lastUpdatedLabel: some View {
        Text(L10n.string("currency.lastUpdated", locale: locale, lastUpdatedText))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(SWTheme.textSecondary)
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    baseCurrencyCard
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("settings.currency.summary")
                    searchCard
                    rateListCard
                    exchangeRateAttribution
                }
                .frame(width: max(0, geometry.size.width - pageHorizontalPadding * 2))
                .padding(.horizontal, pageHorizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("货币选择")
        .navigationBarTitleDisplayMode(.inline)
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
        .ignoresSafeArea(.container, edges: isEmbedded ? .horizontal : [])
        .appBackground()
    }

    private var baseCurrencyCard: some View {
        SettingsSectionCard(title: "本位币") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text(baseCurrency.flag)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(baseCurrency.code) · \(baseCurrency.name)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(SWTheme.primaryText)

                        Text("当前记账与展示优先使用该币种。")
                            .font(.caption)
                            .foregroundStyle(SWTheme.textSecondary)
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("currency.symbolLabel", locale: locale, baseCurrency.symbol))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SWTheme.textSecondary)

                    HStack {
                        Spacer(minLength: 0)
                        lastUpdatedLabel
                    }
                }

                if let errorMessage = currencyStore.errorMessage {
                    Text(errorMessage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SWTheme.accentOrange)
                }
            }
        }
    }

    private var searchCard: some View {
        SettingsSectionCard(title: "搜索") {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(SWTheme.textSecondary)

                TextField("搜索币种代码或名称", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(SWTheme.primaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
        }
    }

    private var rateListCard: some View {
        SettingsSectionCard(title: "其他币种实时汇率") {
            if rateItems.isEmpty {
                Text(
                    searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "暂无可用汇率。".appLocalized(in: locale)
                        : "没有找到匹配的币种。".appLocalized(in: locale)
                )
                    .font(.subheadline)
                    .foregroundStyle(SWTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(rateItems.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 10) {
                        Text(item.descriptor.flag)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(item.descriptor.code) · \(item.descriptor.name)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SWTheme.primaryText)
                            Text(
                                L10n.string(
                                    "currency.baseToTargetRate",
                                    locale: locale,
                                    currencyStore.baseCurrencyCode,
                                    rateText(item.rateAgainstBase, code: item.descriptor.code),
                                    item.descriptor.symbol
                                )
                            )
                                .font(.caption)
                                .foregroundStyle(SWTheme.textSecondary)
                        }

                        Spacer()

                        Button {
                            applyBaseCurrency(item.descriptor.code)
                        } label: {
                            Text("设为本位币")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(SWTheme.accentBlue.opacity(0.22))
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(SWTheme.accentBlue.opacity(0.4), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)

                    if index < rateItems.count - 1 {
                        SettingsRowDivider()
                    }
                }
            }
        }
    }

    private var exchangeRateAttribution: some View {
        Button {
            openURL(AppConfig.exchangeRateProviderURL)
        } label: {
            HStack(spacing: 5) {
                Text("汇率由 ExchangeRate-API 提供".appLocalized(in: locale))
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
            }
            .font(.caption)
            .foregroundStyle(SWTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("在浏览器中打开服务商网站".appLocalized(in: locale))
    }

    private func applyBaseCurrency(_ code: String) {
        withAnimation(.easeInOut(duration: 0.18)) {
            currencyStore.setBaseCurrency(code: code)
        }
        HapticService.selection()
    }

    private func rateText(_ rate: Double, code: String) -> String {
        let digits = CurrencyCatalog.fractionDigits(for: code) == 0 ? 4 : 4
        return rate.formatted(.number.precision(.fractionLength(digits)))
    }
}
