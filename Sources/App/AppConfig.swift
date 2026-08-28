import Foundation

enum AppConfig {
    static let iCloudContainerIdentifier = "iCloud.com.larry.SimpleWorth"
    static let privacyPolicyURL = URL(string: "https://larryhu.com/simpleworth/privacy/")!
    static let supportWebsiteURL = URL(string: "https://larryhu.com/simpleworth/support/")!
    static let exchangeRateProviderURL = URL(string: "https://www.exchangerate-api.com")!
}

enum SettingsKeys {
    static let iCloudSyncEnabled = "settings.iCloudSyncEnabled"
    static let didMigrateLegacyICloudStoreToLocal = "settings.didMigrateLegacyICloudStoreToLocal"
    static let backupRetentionDays = "settings.backupRetentionDays"
    static let baseCurrencyCode = "settings.baseCurrencyCode"
    static let themeMode = "settings.themeMode"
    static let appLanguage = "settings.appLanguage"
    static let legacyDarkModeEnabled = "settings.darkModeEnabled"
    static let appleAccountUserID = "settings.appleAccountUserID"
    static let appleAccountEmail = "settings.appleAccountEmail"
    static let appleAccountDisplayName = "settings.appleAccountDisplayName"
}
