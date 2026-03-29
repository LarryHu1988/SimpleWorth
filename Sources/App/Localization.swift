import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var displayName: String {
        switch self {
        case .simplifiedChinese:
            "简体中文"
        case .traditionalChinese:
            "繁體中文"
        case .english:
            "English"
        case .japanese:
            "日本語"
        }
    }

    var shortLabel: String {
        switch self {
        case .simplifiedChinese:
            "简中"
        case .traditionalChinese:
            "繁中"
        case .english:
            "EN"
        case .japanese:
            "日本語"
        }
    }

    static func resolved(from defaults: UserDefaults = .standard) -> AppLanguage {
        let rawValue = defaults.string(forKey: SettingsKeys.appLanguage) ?? AppLanguage.simplifiedChinese.rawValue
        return AppLanguage(rawValue: rawValue) ?? .simplifiedChinese
    }

    static func resolved(from locale: Locale) -> AppLanguage {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-").lowercased()

        if identifier.hasPrefix("zh-hant") || identifier.hasPrefix("zh-tw") || identifier.hasPrefix("zh-hk") {
            return .traditionalChinese
        }
        if identifier.hasPrefix("zh-hans") || identifier.hasPrefix("zh-cn") || identifier.hasPrefix("zh-sg") || identifier == "zh" {
            return .simplifiedChinese
        }
        if identifier.hasPrefix("ja") {
            return .japanese
        }
        if identifier.hasPrefix("en") {
            return .english
        }

        return resolved()
    }
}

enum L10n {
    static var language: AppLanguage {
        AppLanguage.resolved()
    }

    static var locale: Locale {
        language.locale
    }

    static func string(_ key: String) -> String {
        string(key, locale: locale)
    }

    static func string(_ key: String, locale: Locale) -> String {
        localizedBundle(for: locale).localizedString(forKey: key, value: key, table: nil)
    }

    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        string(key, locale: locale, arguments)
    }

    static func string(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        string(key, locale: locale, arguments)
    }

    private static func string(_ key: String, locale: Locale, _ arguments: [CVarArg]) -> String {
        let format = string(key, locale: locale)
        return String(format: format, locale: locale, arguments: arguments)
    }

    static func year(_ value: Int) -> String {
        year(value, locale: locale)
    }

    static func year(_ value: Int, locale: Locale) -> String {
        string("format.year", locale: locale, Int64(value))
    }

    static func month(_ value: Int) -> String {
        month(value, locale: locale)
    }

    static func month(_ value: Int, locale: Locale) -> String {
        string("format.month", locale: locale, Int64(value))
    }

    static func yearMonth(year: Int, month: Int) -> String {
        yearMonth(year: year, month: month, locale: locale)
    }

    static func yearMonth(year: Int, month: Int, locale: Locale) -> String {
        string("format.yearMonth", locale: locale, Int64(year), Int64(month))
    }

    static func currentLocaleCurrencyLabel(_ code: String) -> String {
        string("currency.codeEqualsSymbol", code)
    }

    private static func localizedBundle(for locale: Locale) -> Bundle {
        let language = AppLanguage.resolved(from: locale)
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        return Bundle.main
    }
}

extension String {
    var appLocalized: String {
        L10n.string(self)
    }

    func appLocalized(in locale: Locale) -> String {
        L10n.string(self, locale: locale)
    }
}
