import Foundation
import SwiftUI

struct CurrencyDescriptor: Identifiable, Hashable {
    let code: String
    let name: String
    let flag: String
    let symbol: String

    var id: String { code }
}

enum CurrencyCatalog {
    static let defaultBaseCode = "CNY"
    static let topCurrencyCodes: [String] = [
        "USD", "EUR", "JPY", "GBP", "CNY", "AUD", "CAD", "CHF", "HKD", "SGD",
        "INR", "KRW", "AED", "MXN", "BRL", "ZAR", "RUB", "SEK", "NOK", "NZD"
    ]

    private static let explicitRegionMap: [String: String] = [
        "EUR": "EU",
        "XAF": "CM",
        "XCD": "AG",
        "XOF": "SN",
        "XPF": "PF",
        "ANG": "CW",
        "XDR": "IM"
    ]

    private static let zeroFractionCurrencies: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG",
        "RWF", "UGX", "UYI", "VND", "VUV", "XAF", "XOF", "XPF"
    ]

    static func descriptor(for code: String) -> CurrencyDescriptor {
        let normalized = normalize(code: code)
        return CurrencyDescriptor(
            code: normalized,
            name: localizedName(for: normalized),
            flag: flag(for: normalized),
            symbol: symbol(for: normalized)
        )
    }

    static func descriptors(for codes: [String]) -> [CurrencyDescriptor] {
        var seen = Set<String>()
        var result: [CurrencyDescriptor] = []

        for code in codes {
            let normalized = normalize(code: code)
            guard seen.insert(normalized).inserted else { continue }
            result.append(descriptor(for: normalized))
        }

        return result
    }

    static func fractionDigits(for code: String) -> Int {
        zeroFractionCurrencies.contains(normalize(code: code)) ? 0 : 2
    }

    static func localizedName(for code: String) -> String {
        let normalized = normalize(code: code)
        let locale = Locale(identifier: "zh_CN")
        return locale.localizedString(forCurrencyCode: normalized) ?? normalized
    }

    static func symbol(for code: String) -> String {
        let normalized = normalize(code: code)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = normalized
        formatter.locale = Locale(identifier: "zh_CN")
        let resolved = formatter.currencySymbol?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return resolved.isEmpty ? normalized : resolved
    }

    static func flag(for code: String) -> String {
        let normalized = normalize(code: code)
        let region = explicitRegionMap[normalized] ?? String(normalized.prefix(2))
        return emojiFlag(for: region)
    }

    static func normalize(code: String) -> String {
        let uppercase = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if uppercase.count == 3 { return uppercase }
        return defaultBaseCode
    }

    private static func emojiFlag(for regionCode: String) -> String {
        let uppercase = regionCode.uppercased()
        guard uppercase.count == 2 else { return "🏳️" }

        let scalars = uppercase.unicodeScalars.compactMap { scalar -> UnicodeScalar? in
            let value = scalar.value
            guard (65...90).contains(value) else { return nil }
            let flagBase: UInt32 = 127397
            return UnicodeScalar(flagBase + value)
        }

        guard scalars.count == 2 else { return "🏳️" }
        return String(String.UnicodeScalarView(scalars))
    }
}

private struct ExchangeRateAPIResponse: Decodable {
    let result: String
    let baseCode: String
    let rates: [String: Double]
    let timeLastUpdateUnix: TimeInterval

    enum CodingKeys: String, CodingKey {
        case result
        case baseCode = "base_code"
        case rates
        case timeLastUpdateUnix = "time_last_update_unix"
    }
}

private actor ExchangeRateClient {
    func fetchLatestRatesFromCNY() async throws -> (rates: [String: Double], updatedAt: Date) {
        let url = URL(string: "https://open.er-api.com/v6/latest/CNY")!
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(ExchangeRateAPIResponse.self, from: data)
        guard payload.result == "success" else {
            throw URLError(.cannotParseResponse)
        }

        var rates = payload.rates
        rates[CurrencyCatalog.defaultBaseCode] = 1

        return (rates, Date(timeIntervalSince1970: payload.timeLastUpdateUnix))
    }
}

@MainActor
final class CurrencyStore: ObservableObject {
    static let shared = CurrencyStore()

    @Published private(set) var ratesFromCNY: [String: Double]
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var baseCurrencyCode: String {
        didSet {
            UserDefaults.standard.set(baseCurrencyCode, forKey: SettingsKeys.baseCurrencyCode)
        }
    }

    private let client = ExchangeRateClient()
    private static let ratesCacheKey = "currency.rates.cache"
    private static let updatedAtCacheKey = "currency.rates.updatedAt"

    private init() {
        let savedBase = UserDefaults.standard.string(forKey: SettingsKeys.baseCurrencyCode) ?? CurrencyCatalog.defaultBaseCode
        let normalizedSavedBase = CurrencyCatalog.normalize(code: savedBase)
        if CurrencyCatalog.topCurrencyCodes.contains(normalizedSavedBase) {
            baseCurrencyCode = normalizedSavedBase
        } else {
            baseCurrencyCode = CurrencyCatalog.defaultBaseCode
        }

        if
            let data = UserDefaults.standard.data(forKey: Self.ratesCacheKey),
            let cachedRates = try? JSONDecoder().decode([String: Double].self, from: data),
            !cachedRates.isEmpty
        {
            ratesFromCNY = cachedRates
        } else {
            ratesFromCNY = [CurrencyCatalog.defaultBaseCode: 1]
        }

        if let updatedAt = UserDefaults.standard.object(forKey: Self.updatedAtCacheKey) as? Date {
            lastUpdated = updatedAt
        }

        Task {
            await refreshRates(force: ratesFromCNY.count <= 1)
        }
    }

    var supportedCurrencyCodes: [String] {
        let available = Set(ratesFromCNY.keys)
        var ordered = CurrencyCatalog.topCurrencyCodes.filter { available.contains($0) }

        if !ordered.contains(CurrencyCatalog.defaultBaseCode) {
            ordered.append(CurrencyCatalog.defaultBaseCode)
        }

        let base = CurrencyCatalog.normalize(code: baseCurrencyCode)
        if !ordered.contains(base) {
            ordered.append(base)
        }
        if let index = ordered.firstIndex(of: base) {
            ordered.remove(at: index)
            ordered.insert(base, at: 0)
        }

        return ordered
    }

    var descriptors: [CurrencyDescriptor] {
        CurrencyCatalog.descriptors(for: supportedCurrencyCodes)
    }

    func setBaseCurrency(code: String) {
        let normalized = CurrencyCatalog.normalize(code: code)
        if supportedCurrencyCodes.contains(normalized) {
            baseCurrencyCode = normalized
        } else {
            baseCurrencyCode = CurrencyCatalog.defaultBaseCode
        }
    }

    func refreshRates(force: Bool = true) async {
        if isLoading { return }
        if !force, let lastUpdated, abs(lastUpdated.timeIntervalSinceNow) < 15 * 60 {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let payload = try await client.fetchLatestRatesFromCNY()
            ratesFromCNY = payload.rates
            lastUpdated = payload.updatedAt
            persistCache()
        } catch {
            errorMessage = "汇率更新失败，已使用本地缓存"
        }

        isLoading = false
    }

    func rate(from sourceCode: String, to targetCode: String) -> Double? {
        let source = CurrencyCatalog.normalize(code: sourceCode)
        let target = CurrencyCatalog.normalize(code: targetCode)

        if source == target { return 1 }

        guard
            let cnyToSource = ratesFromCNY[source], cnyToSource > 0,
            let cnyToTarget = ratesFromCNY[target]
        else {
            return nil
        }

        return cnyToTarget / cnyToSource
    }

    func rateToCNY(for sourceCode: String) -> Double? {
        let source = CurrencyCatalog.normalize(code: sourceCode)
        if source == CurrencyCatalog.defaultBaseCode { return 1 }

        guard let cnyToSource = ratesFromCNY[source], cnyToSource > 0 else {
            return nil
        }

        return 1 / cnyToSource
    }

    func convertToCNY(amount: Double, sourceCode: String) -> Double? {
        guard let rateToCNY = rateToCNY(for: sourceCode) else { return nil }
        return amount * rateToCNY
    }

    func convertFromCNY(amount: Double, targetCode: String) -> Double? {
        guard let cnyToTarget = rate(from: CurrencyCatalog.defaultBaseCode, to: targetCode) else {
            return nil
        }
        return amount * cnyToTarget
    }

    func formattedAmountFromCNY(_ amount: Double, targetCode: String, signed: Bool = false) -> String {
        let code = CurrencyCatalog.normalize(code: targetCode)
        let digits = CurrencyCatalog.fractionDigits(for: code)
        let converted = convertFromCNY(amount: amount, targetCode: code) ?? amount
        return signed
            ? converted.signedCurrencyText(code: code, fractionDigits: digits)
            : converted.currencyText(code: code, fractionDigits: digits)
    }

    func formattedAmount(_ amount: Double, code: String, signed: Bool = false) -> String {
        let normalizedCode = CurrencyCatalog.normalize(code: code)
        let digits = CurrencyCatalog.fractionDigits(for: normalizedCode)
        return signed
            ? amount.signedCurrencyText(code: normalizedCode, fractionDigits: digits)
            : amount.currencyText(code: normalizedCode, fractionDigits: digits)
    }

    private func persistCache() {
        if let encoded = try? JSONEncoder().encode(ratesFromCNY) {
            UserDefaults.standard.set(encoded, forKey: Self.ratesCacheKey)
        }
        UserDefaults.standard.set(lastUpdated, forKey: Self.updatedAtCacheKey)
    }
}
