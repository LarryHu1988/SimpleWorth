import AuthenticationServices
import StoreKit
import SwiftData
import SwiftUI
import UIKit

private enum SettingsRoute: Hashable {
    case currency
    case tags
    case importBills
    case feedback
    case privacy
    case about
    case otherApps
}

struct StatsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appRuntimeController: AppRuntimeController

    @Query(sort: [SortDescriptor(\LedgerEntry.createdAt, order: .reverse)]) private var entries: [LedgerEntry]
    @Query(sort: [SortDescriptor(\TagRecord.createdAt, order: .forward)]) private var tags: [TagRecord]
    @Query(sort: [SortDescriptor(\SavingsGoalRecord.createdAt, order: .reverse)]) private var goals: [SavingsGoalRecord]
    @Query(sort: [SortDescriptor(\VaultDepositRecord.date, order: .reverse)]) private var deposits: [VaultDepositRecord]

    @AppStorage("settings.hapticsEnabled") private var hapticsEnabled = true
    @AppStorage(SettingsKeys.iCloudSyncEnabled) private var iCloudSyncEnabled = false
    @AppStorage(SettingsKeys.themeMode) private var themeModeRaw = ThemeMode.system.rawValue
    @AppStorage(SettingsKeys.appLanguage) private var appLanguageRaw = AppLanguage.simplifiedChinese.rawValue
    @AppStorage("settings.detailedTimeEnabled") private var detailedTimeEnabled = false
    @State private var showShareSheet = false
    @State private var showDetailedTimeInfo = false
    @State private var navigationPath = NavigationPath()

    @State private var exportDocument: LedgerBackupDocument?
    @State private var showFileExporter = false

    @State private var noticeMessage = ""
    @State private var showNotice = false
    @State private var suppressNextICloudSyncHandling = false
    @StateObject private var appleAccountStore = AppleAccountStore.shared
    @StateObject private var appleSignInController = AppleSignInController()

    private let repoURL = URL(string: "https://github.com/LarryHu1988/SimpleWorth")
    private let authorWebsiteURL = URL(string: "https://larryhu.com")
    private let supportEmail = "simpleworth@larryhu.com"

    private var selectedThemeMode: ThemeMode {
        ThemeMode(rawValue: themeModeRaw) ?? ThemeMode.resolved()
    }

    private var selectedAppLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .simplifiedChinese
    }

    private var uiLocale: Locale {
        selectedAppLanguage.locale
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.6.2"
        return "V\(version)"
    }

    private var totalEntryCount: Int {
        entries.count
    }

    private var totalLedgerDays: Int {
        Set(entries.map { Calendar.current.startOfDay(for: $0.createdAt) }).count
    }

    private var backupFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "SimpleWorth-backup-\(formatter.string(from: .now))"
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SettingsLayout.pageSectionSpacing) {
                    appleAccountCard
                    statsHeaderCard

                    SettingsSectionCard(title: "个人偏好") {
                        languageInlineRow

                        SettingsRowDivider()

                        themeModeInlineRow

                        SettingsRowDivider()

                        settingToggleRow(
                            title: "震动反馈",
                            symbol: "iphone.radiowaves.left.and.right",
                            iconColor: SWTheme.accentPink,
                            isOn: $hapticsEnabled
                        )
                        .onChange(of: hapticsEnabled) { _, newValue in
                            if newValue { HapticService.impact() }
                        }
                    }

                    SettingsSectionCard(title: "账单设置") {
                        SettingsPressableButton {
                            push(.currency)
                        } label: {
                            settingsNavigationRowLabel(
                                title: "货币选择",
                                symbol: "dollarsign.circle.fill",
                                iconColor: SWTheme.accentGreen
                            )
                        }

                        SettingsRowDivider()

                        SettingsPressableButton {
                            push(.tags)
                        } label: {
                            settingsNavigationRowLabel(
                                title: "标签管理",
                                symbol: "tag.fill",
                                iconColor: SWTheme.accentBlue
                            )
                        }

                        SettingsRowDivider()

                        settingToggleRow(
                            title: "详细时间",
                            symbol: "clock.badge.checkmark.fill",
                            iconColor: SWTheme.accentOrange,
                            isOn: $detailedTimeEnabled,
                            infoText: "开启后，新增/编辑账单可精确到分钟；关闭后仅精确到天。",
                            isInfoPresented: $showDetailedTimeInfo
                        )
                        .onChange(of: detailedTimeEnabled) { _, _ in
                            HapticService.impact()
                        }
                    }

                    SettingsSectionCard(title: "数据安全") {
                        settingToggleRow(
                            title: "iCloud 同步",
                            symbol: "icloud.fill",
                            iconColor: SWTheme.accentBlue,
                            isOn: $iCloudSyncEnabled
                        )
                        .onChange(of: iCloudSyncEnabled) { _, newValue in
                            handleICloudSyncToggleChange(newValue)
                        }

                        SettingsRowDivider()

                        settingsActionRow(
                            title: "账单导出",
                            symbol: "square.and.arrow.up.on.square",
                            iconColor: SWTheme.accentGreen
                        ) {
                            exportBackup()
                        }

                        SettingsRowDivider()

                        settingsActionRow(
                            title: "账单导入",
                            symbol: "square.and.arrow.down.on.square",
                            iconColor: SWTheme.accentOrange
                        ) {
                            push(.importBills)
                        }
                    }

                    SettingsSectionCard(title: "良性互动") {
                        settingsActionRow(
                            title: "意见反馈",
                            symbol: "envelope.fill",
                            iconColor: SWTheme.accentBlue
                        ) {
                            push(.feedback)
                        }

                        SettingsRowDivider()

                        settingsActionRow(
                            title: "好评鼓励",
                            symbol: "hand.thumbsup.fill",
                            iconColor: SWTheme.accentGreen
                        ) {
                            requestReview()
                            HapticService.impact()
                        }

                        SettingsRowDivider()

                        settingsActionRow(
                            title: "分享简值",
                            symbol: "square.and.arrow.up",
                            iconColor: SWTheme.accentPink
                        ) {
                            showShareSheet = true
                            HapticService.impact()
                        }
                    }

                    SettingsSectionCard(title: "了解一下") {
                        settingsActionRow(
                            title: "隐私协议",
                            symbol: "hand.raised.fill",
                            iconColor: SWTheme.accentBlue
                        ) {
                            push(.privacy)
                        }

                        SettingsRowDivider()

                        settingsActionRow(
                            title: "关于简值",
                            symbol: "info.circle.fill",
                            iconColor: SWTheme.accentOrange
                        ) {
                            push(.about)
                        }

                        SettingsRowDivider()

                        settingsActionRow(
                            title: "其他 APP",
                            symbol: "square.grid.2x2.fill",
                            iconColor: SWTheme.accentGreen
                        ) {
                            push(.otherApps)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("操作结果", isPresented: $showNotice) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(noticeMessage)
            }
            .sheet(isPresented: $showShareSheet) {
                if let repoURL {
                    ShareSheet(
                        activityItems: [
                            "我在用这款记账 App：SimpleWorth（简值），推荐你试试。".appLocalized(in: uiLocale),
                            repoURL
                        ],
                        subject: "SimpleWorth 简值".appLocalized(in: uiLocale)
                    )
                }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .currency:
                    CurrencySettingsView()
                case .tags:
                    TagManagementView()
                case .importBills:
                    BillImportGuideView(
                        onImportSelected: importBills(from:),
                        onNotice: presentNotice(message:)
                    )
                case .feedback:
                    FeedbackContactView(
                        supportEmail: supportEmail,
                        onCopyEmail: copyFeedbackAddress,
                        onSendMail: sendFeedback
                    )
                case .privacy:
                    PrivacyAgreementView(supportEmail: supportEmail)
                case .about:
                    AboutSimpleWorthView(
                        email: supportEmail,
                        appVersionText: appVersionText,
                        authorWebsiteURL: authorWebsiteURL,
                        repoURL: repoURL
                    )
                case .otherApps:
                    OtherAppsView(authorWebsiteURL: authorWebsiteURL, repoURL: repoURL)
                }
            }
            .fileExporter(
                isPresented: $showFileExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: backupFileName
            ) { result in
                switch result {
                case .success:
                    HapticService.impact()
                    presentNotice(message: "账单已成功导出。".appLocalized(in: uiLocale))
                case .failure(let error):
                    presentNotice(message: L10n.string("settings.exportFailed", locale: uiLocale, error.localizedDescription))
                }
            }
            .appBackground()
            .task {
                await appleAccountStore.refreshStatus()
            }
            .onChange(of: themeModeRaw) { _, newValue in
                let mode = ThemeMode(rawValue: newValue) ?? .system
                AppAppearanceController.apply(themeMode: mode)
            }
        }
    }

    private var appleAccountCard: some View {
        ViewThatFits(in: .horizontal) {
            appleAccountBalancedRow
            appleAccountCompactRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitnessCard()
    }

    private var appleAccountBalancedRow: some View {
        HStack(alignment: .center, spacing: 12) {
            appleAccountAvatar
            Text("Apple 账号".appLocalized(in: uiLocale))
                .font(SettingsLayout.cardTitleFont)
                .tracking(SettingsLayout.cardTitleTracking)
                .foregroundStyle(SettingsLayout.cardTitleColor)
                .lineLimit(1)

            Text(appleAccountPrimaryStatusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SWTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .layoutPriority(1)

            Spacer(minLength: 8)

            appleAccountActionArea
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appleAccountCompactRow: some View {
        HStack(alignment: .center, spacing: 12) {
            appleAccountAvatar

            VStack(alignment: .leading, spacing: 3) {
                appleAccountIdentityBlock
            }

            Spacer(minLength: 8)

            appleAccountActionArea
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appleAccountIdentityBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Apple 账号".appLocalized(in: uiLocale))
                .font(SettingsLayout.cardTitleFont)
                .tracking(SettingsLayout.cardTitleTracking)
                .foregroundStyle(SettingsLayout.cardTitleColor)

            Text(appleAccountHeadline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SWTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private var appleAccountPrimaryStatusText: String {
        appleAccountHeadline
    }

    @ViewBuilder
    private var appleAccountActionArea: some View {
        if hasLinkedAppleAccount {
            HStack(spacing: 8) {
                Text(appleAccountBadgeText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(appleAccountBadgeTint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(appleAccountBadgeTint.opacity(0.14))
                    )

                Button {
                    Task {
                        await appleAccountStore.refreshStatus()
                        HapticService.selection()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SWTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("重新检测".appLocalized(in: uiLocale))
            }
            .fixedSize(horizontal: true, vertical: false)
        } else {
            Button {
                Task {
                    await startAppleSignIn()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.subheadline.weight(.bold))
                    Text("Apple 登录".appLocalized(in: uiLocale))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                .padding(.horizontal, 14)
                .frame(minHeight: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.9))
                )
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var statsHeaderCard: some View {
        HStack(spacing: 12) {
            SettingsMetricCard(title: "记账总天数", value: "\(totalLedgerDays)", tint: SWTheme.accentBlue)
            SettingsMetricCard(title: "记账总笔数", value: "\(totalEntryCount)", tint: SWTheme.accentGreen)
        }
    }

    private var appleAccountDisplayTitle: String {
        if let displayName = appleAccountResolvedDisplayName {
            return displayName
        }
        return "Apple 用户".appLocalized(in: uiLocale)
    }

    private var appleAccountResolvedDisplayName: String? {
        guard let displayName = appleAccountStore.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !displayName.isEmpty else {
            return nil
        }
        return displayName
    }

    private var hasLinkedAppleAccount: Bool {
        appleAccountStore.userID != nil
    }

    private var appleAccountHeadline: String {
        guard hasLinkedAppleAccount else {
            return "未登录".appLocalized(in: uiLocale)
        }

        if let displayName = appleAccountResolvedDisplayName {
            return displayName
        }

        if let email = appleAccountStore.email, !email.isEmpty {
            return email
        }

        return "Apple 用户".appLocalized(in: uiLocale)
    }

    private var appleAccountSupportingText: String {
        if hasLinkedAppleAccount,
           appleAccountResolvedDisplayName != nil,
           let email = appleAccountStore.email,
           !email.isEmpty {
            return email
        }

        return appleAccountSubtitle
    }

    private var appleAccountSupportingTint: Color {
        if hasLinkedAppleAccount,
           appleAccountResolvedDisplayName != nil,
           let email = appleAccountStore.email,
           !email.isEmpty {
            return SWTheme.textSecondary
        }

        return appleAccountSubtitleTint
    }

    private var appleAccountBadgeText: String {
        switch appleAccountStore.credentialStatus {
        case .authorized, .unavailable:
            return "已登录".appLocalized(in: uiLocale)
        case .checking:
            return "检测中".appLocalized(in: uiLocale)
        case .revoked, .signedOut:
            return "检测中".appLocalized(in: uiLocale)
        }
    }

    private var appleAccountBadgeTint: Color {
        switch appleAccountStore.credentialStatus {
        case .authorized:
            return SWTheme.accentGreen
        case .checking:
            return SWTheme.accentBlue
        case .revoked, .unavailable, .signedOut:
            return SWTheme.accentOrange
        }
    }

    private var appleAccountAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            SWTheme.accentBlue.opacity(hasLinkedAppleAccount ? 0.32 : 0.18),
                            SWTheme.accentGreen.opacity(hasLinkedAppleAccount ? 0.24 : 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if hasLinkedAppleAccount {
                Text(appleAccountAvatarLabel)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(SWTheme.primaryText)
            } else {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SWTheme.primaryText)
            }
        }
        .frame(width: 44, height: 44)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    private var appleAccountAvatarLabel: String {
        let source = (
            appleAccountResolvedDisplayName
            ?? appleAccountStore.email?.split(separator: "@").first.map(String.init)
            ?? appleAccountDisplayTitle
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return "A" }

        let words = source.split { character in
            character == " " || character == "-" || character == "_"
        }

        if words.count >= 2 {
            return String(words.prefix(2).compactMap(\.first)).uppercased()
        }

        return String(source.prefix(2)).uppercased()
    }

    private var appleAccountSubtitle: String {
        switch appleAccountStore.credentialStatus {
        case .authorized:
            switch appleAccountStore.iCloudStatus {
            case .available:
                return "同步已准备就绪".appLocalized(in: uiLocale)
            case .noAccount:
                return "Apple 已登录，但当前设备未登录 iCloud。".appLocalized(in: uiLocale)
            case .restricted:
                return "Apple 已登录，但当前 iCloud 账号受限。".appLocalized(in: uiLocale)
            case .couldNotDetermine:
                return "Apple 已登录，iCloud 状态待检测。".appLocalized(in: uiLocale)
            case .temporarilyUnavailable:
                return "Apple 已登录，iCloud 当前暂时不可用。".appLocalized(in: uiLocale)
            @unknown default:
                return "Apple 已登录，iCloud 状态待检测。".appLocalized(in: uiLocale)
            }
        case .checking:
            return "正在检测 Apple 账号状态...".appLocalized(in: uiLocale)
        case .revoked:
            return "Apple 授权已失效，请重新登录。".appLocalized(in: uiLocale)
        case .unavailable:
            return "当前无法读取 Apple 账号状态。".appLocalized(in: uiLocale)
        case .signedOut:
            return "登录后将账单同步到当前 Apple 账号".appLocalized(in: uiLocale)
        }
    }

    private var appleAccountSubtitleTint: Color {
        switch appleAccountStore.credentialStatus {
        case .authorized:
            return appleAccountStore.iCloudStatus == .available ? SWTheme.accentGreen : SWTheme.accentOrange
        case .checking:
            return SWTheme.accentBlue
        case .revoked, .unavailable:
            return SWTheme.accentOrange
        case .signedOut:
            return SWTheme.textSecondary
        }
    }

    private var themeModeInlineRow: some View {
        HStack(spacing: SettingsLayout.rowSpacing) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(selectedThemeMode == .daylight ? SWTheme.accentOrange : SWTheme.accentBlue)
                .frame(width: SettingsLayout.rowIconWidth)

            Text("主题颜色")
                .font(SettingsLayout.titleFont)
                .foregroundStyle(SWTheme.primaryText)

            Spacer()

            HStack(spacing: 8) {
                ForEach(ThemeMode.allCases) { mode in
                    Button {
                        themeModeRaw = mode.rawValue
                        AppAppearanceController.apply(themeMode: mode)
                        HapticService.selection()
                    } label: {
                        Image(systemName: mode.symbol)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(mode == selectedThemeMode ? SWTheme.primaryText : SWTheme.textSecondary)
                            .frame(
                                width: SettingsLayout.inlineControlSize,
                                height: SettingsLayout.inlineControlSize
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        mode == selectedThemeMode
                                            ? Color.white.opacity(0.22)
                                            : Color.white.opacity(0.08)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(
                                                mode == selectedThemeMode
                                                    ? Color.white.opacity(0.48)
                                                    : Color.white.opacity(0.12),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode.title)
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: SettingsLayout.rowContentMinHeight,
            alignment: .leading
        )
        .contentShape(Rectangle())
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }

    private var languageInlineRow: some View {
        HStack(spacing: SettingsLayout.rowSpacing) {
            Image(systemName: "globe")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SWTheme.accentGreen)
                .frame(width: SettingsLayout.rowIconWidth)

            Text("语言选择")
                .font(SettingsLayout.titleFont)
                .foregroundStyle(SWTheme.primaryText)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        appLanguageRaw = language.rawValue
                        HapticService.selection()
                    } label: {
                        Text(language.shortLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                language == selectedAppLanguage
                                    ? SWTheme.primaryText
                                    : SWTheme.textSecondary
                            )
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .frame(height: SettingsLayout.inlineControlSize)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        language == selectedAppLanguage
                                            ? Color.white.opacity(0.22)
                                            : Color.white.opacity(0.08)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(
                                                language == selectedAppLanguage
                                                    ? Color.white.opacity(0.48)
                                                    : Color.white.opacity(0.12),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(language.displayName)
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: SettingsLayout.rowContentMinHeight,
            alignment: .leading
        )
        .contentShape(Rectangle())
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }

    private func settingsActionRow(
        title: String,
        symbol: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        SettingsPressableButton(action: action) {
            HStack(spacing: SettingsLayout.rowSpacing) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: SettingsLayout.rowIconWidth)

                Text(title.appLocalized(in: uiLocale))
                    .font(SettingsLayout.titleFont)
                    .foregroundStyle(SWTheme.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
            }
            .contentShape(Rectangle())
            .frame(
                maxWidth: .infinity,
                minHeight: SettingsLayout.rowContentMinHeight,
                alignment: .leading
            )
            .padding(.vertical, SettingsLayout.rowVerticalPadding)
        }
    }

    private func settingToggleRow(
        title: String,
        symbol: String,
        iconColor: Color,
        isOn: Binding<Bool>,
        infoText: String? = nil,
        isInfoPresented: Binding<Bool>? = nil
    ) -> some View {
        HStack(spacing: SettingsLayout.rowSpacing) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: SettingsLayout.rowIconWidth)

            Text(title.appLocalized(in: uiLocale))
                .font(SettingsLayout.titleFont)
                .foregroundStyle(SWTheme.primaryText)

            if let infoText, let isInfoPresented {
                Button {
                    isInfoPresented.wrappedValue.toggle()
                    HapticService.selection()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SWTheme.accentBlue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("settings.infoAccessibility", locale: uiLocale, title.appLocalized(in: uiLocale)))
                .popover(isPresented: isInfoPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    Text(infoText.appLocalized(in: uiLocale))
                        .font(.footnote)
                        .foregroundStyle(SWTheme.primaryText)
                        .padding(12)
                        .frame(width: 220, alignment: .leading)
                        .presentationCompactAdaptation(.popover)
                }
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .scaleEffect(SettingsLayout.compactToggleScale)
                .fixedSize()
        }
        .frame(
            maxWidth: .infinity,
            minHeight: SettingsLayout.rowContentMinHeight,
            alignment: .leading
        )
        .contentShape(Rectangle())
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }

    private func settingsNavigationRowLabel(
        title: String,
        symbol: String,
        iconColor: Color
    ) -> some View {
        HStack(spacing: SettingsLayout.rowSpacing) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: SettingsLayout.rowIconWidth)

            Text(title.appLocalized(in: uiLocale))
                .font(SettingsLayout.titleFont)
                .foregroundStyle(SWTheme.primaryText)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SWTheme.textSecondary)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: SettingsLayout.rowContentMinHeight,
            alignment: .leading
        )
        .contentShape(Rectangle())
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }

    private func sendFeedback() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "SimpleWorth 意见反馈".appLocalized(in: uiLocale)),
            URLQueryItem(name: "body", value: "请描述你的建议或问题：".appLocalized(in: uiLocale))
        ]

        guard let url = components.url else {
            fallbackToCopiedFeedbackAddress()
            return
        }

        openURL(url) { accepted in
            if accepted {
                HapticService.impact()
            } else {
                fallbackToCopiedFeedbackAddress()
            }
        }
    }

    private func copyFeedbackAddress() {
        UIPasteboard.general.string = supportEmail
        HapticService.selection()
        presentNotice(message: "已复制反馈邮箱地址。".appLocalized(in: uiLocale))
    }

    private func fallbackToCopiedFeedbackAddress() {
        UIPasteboard.general.string = supportEmail
        HapticService.impact()
        presentNotice(message: L10n.string("settings.feedbackUnavailable", locale: uiLocale, supportEmail))
    }

    private func exportBackup() {
        let payload = LedgerBackupPayload(
            exportedAt: .now,
            appVersion: appVersionText,
            entries: entries.map {
                LedgerEntrySnapshot(
                    id: $0.id,
                    createdAt: $0.createdAt,
                    amount: $0.amount,
                    originalAmount: $0.originalAmount,
                    currencyCode: $0.currencyCode,
                    exchangeRateToCNY: $0.exchangeRateToCNY,
                    note: $0.note,
                    tagNames: $0.tagNames,
                    flow: $0.flow,
                    categoryName: $0.categoryName,
                    categorySymbol: $0.categorySymbol,
                    categoryColorHex: $0.categoryColorHex
                )
            },
            tags: tags.map {
                TagSnapshot(
                    id: $0.id,
                    name: $0.name,
                    emoji: $0.emojiValue,
                    tintHex: $0.resolvedTintHex,
                    createdAt: $0.createdAt
                )
            },
            goals: goals.map {
                SavingsGoalSnapshot(
                    id: $0.id,
                    createdAt: $0.createdAt,
                    name: $0.name,
                    symbol: $0.symbol,
                    currentAmount: $0.currentAmount,
                    targetAmount: $0.targetAmount,
                    deadline: $0.deadline,
                    tintHex: $0.tintHex
                )
            },
            deposits: deposits.map {
                VaultDepositSnapshot(
                    id: $0.id,
                    date: $0.date,
                    amount: $0.amount,
                    note: $0.note,
                    goalID: $0.goal?.id
                )
            }
        )

        exportDocument = LedgerBackupDocument(payload: payload)
        showFileExporter = true
        HapticService.impact()
    }

    private func importBills(from url: URL) {
        let needsSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let importedEntries = try LedgerSpreadsheetImporter.parseEntries(from: data)
            let summary = try appendImportedBills(importedEntries)
            HapticService.impact()
            presentNotice(message: summary)
        } catch {
            presentNotice(message: L10n.string("settings.importFailed", locale: uiLocale, error.localizedDescription))
        }
    }

    private func appendImportedBills(_ importedEntries: [LedgerSpreadsheetImportEntry]) throws -> String {
        var knownTagsByKey = Dictionary(uniqueKeysWithValues: tags.map { ($0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), $0) })
        var existingEntrySignatures = Set(entries.map(entryImportSignature(for:)))
        var importedEntrySignatures = Set<String>()

        var importedCount = 0
        var skippedCount = 0
        var createdTagCount = 0

        for importedEntry in importedEntries {
            let category = resolvedImportCategory(named: importedEntry.categoryName, flow: importedEntry.flow)
            let signature = entryImportSignature(
                createdAt: importedEntry.createdAt,
                flow: importedEntry.flow,
                categoryName: category.name,
                originalAmount: importedEntry.originalAmount,
                currencyCode: importedEntry.currencyCode,
                note: importedEntry.note,
                tagNames: importedEntry.tagNames
            )

            guard !existingEntrySignatures.contains(signature), importedEntrySignatures.insert(signature).inserted else {
                skippedCount += 1
                continue
            }

            let normalizedTagNames = importedEntry.tagNames.compactMap { rawTagName -> String? in
                let trimmed = rawTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                let lookupKey = trimmed.lowercased()
                if let existingTag = knownTagsByKey[lookupKey] {
                    return existingTag.name
                }

                let newTag = TagRecord(
                    name: trimmed,
                    tintHex: TagEmojiLibrary.colorHex(for: trimmed)
                )
                modelContext.insert(newTag)
                knownTagsByKey[lookupKey] = newTag
                createdTagCount += 1
                return newTag.name
            }

            let rateToCNY = try resolvedRateToCNY(for: importedEntry.currencyCode)
            let normalizedAmount = importedEntry.originalAmount * rateToCNY

            let entry = LedgerEntry(
                createdAt: importedEntry.createdAt,
                amount: normalizedAmount,
                originalAmount: importedEntry.originalAmount,
                currencyCode: importedEntry.currencyCode,
                exchangeRateToCNY: rateToCNY,
                note: importedEntry.note,
                flow: importedEntry.flow,
                category: category,
                tagNames: normalizedTagNames
            )

            modelContext.insert(entry)
            importedCount += 1
            existingEntrySignatures.insert(signature)
        }

        guard importedCount > 0 else {
            return L10n.string("settings.importNoNewItems", locale: uiLocale)
        }

        try modelContext.save()

        if skippedCount > 0 {
            return L10n.string(
                "settings.importSummaryWithSkipped",
                locale: uiLocale,
                Int64(importedCount),
                Int64(createdTagCount),
                Int64(skippedCount)
            )
        }

        return L10n.string(
            "settings.importSummary",
            locale: uiLocale,
            Int64(importedCount),
            Int64(createdTagCount)
        )
    }

    private func resolvedRateToCNY(for currencyCode: String) throws -> Double {
        let normalizedCode = CurrencyCatalog.normalize(code: currencyCode)
        if normalizedCode == CurrencyCatalog.defaultBaseCode {
            return 1
        }

        if let rate = CurrencyStore.shared.rateToCNY(for: normalizedCode) {
            return rate
        }

        throw BillImportRuntimeError.unsupportedCurrency(normalizedCode)
    }

    private func resolvedImportCategory(named rawName: String, flow: FlowType) -> CategoryItem {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CategoryLibrary.defaultCategory(for: flow)
        }

        if let exactCategory = CategoryLibrary.category(named: trimmed, flow: flow) {
            return exactCategory
        }

        let lookup = normalizedImportLookup(trimmed)
        let supportedLocales = AppLanguage.allCases.map(\.locale)

        if let localizedMatch = CategoryLibrary.categories(for: flow).first(where: { category in
            if normalizedImportLookup(category.name) == lookup {
                return true
            }

            return supportedLocales.contains { locale in
                normalizedImportLookup(category.localizedName(in: locale)) == lookup
            }
        }) {
            return localizedMatch
        }

        return CategoryLibrary.defaultCategory(for: flow)
    }

    private func entryImportSignature(for entry: LedgerEntry) -> String {
        entryImportSignature(
            createdAt: entry.createdAt,
            flow: entry.flow,
            categoryName: entry.categoryName,
            originalAmount: entry.originalAmount,
            currencyCode: entry.currencyCode,
            note: entry.note,
            tagNames: entry.tagNames
        )
    }

    private func entryImportSignature(
        createdAt: Date,
        flow: FlowType,
        categoryName: String,
        originalAmount: Double,
        currencyCode: String,
        note: String,
        tagNames: [String]
    ) -> String {
        let timestamp = Int(createdAt.timeIntervalSince1970.rounded())
        let normalizedTags = tagNames
            .map(normalizedImportLookup)
            .sorted()
            .joined(separator: "|")

        return [
            String(timestamp),
            flow.storageValue,
            normalizedImportLookup(categoryName),
            CurrencyCatalog.normalize(code: currencyCode),
            String(format: "%.4f", originalAmount),
            normalizedImportLookup(note),
            normalizedTags
        ].joined(separator: "#")
    }

    private func normalizedImportLookup(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }

    private func replaceLocalData(with payload: LedgerBackupPayload) throws {
        deposits.forEach { modelContext.delete($0) }
        goals.forEach { modelContext.delete($0) }
        entries.forEach { modelContext.delete($0) }
        tags.forEach { modelContext.delete($0) }

        for snapshot in payload.tags ?? [] {
            modelContext.insert(
                TagRecord(
                    id: snapshot.id,
                    name: snapshot.name,
                    emoji: snapshot.emoji ?? TagEmojiLibrary.defaultEmoji,
                    tintHex: snapshot.tintHex ?? TagEmojiLibrary.colorHex(for: snapshot.name),
                    createdAt: snapshot.createdAt
                )
            )
        }

        var goalMap: [UUID: SavingsGoalRecord] = [:]
        for snapshot in payload.goals {
            let goal = SavingsGoalRecord(
                id: snapshot.id,
                createdAt: snapshot.createdAt,
                name: snapshot.name,
                symbol: snapshot.symbol,
                currentAmount: snapshot.currentAmount,
                targetAmount: snapshot.targetAmount,
                deadline: snapshot.deadline,
                tintHex: snapshot.tintHex
            )
            modelContext.insert(goal)
            goalMap[snapshot.id] = goal
        }

        for snapshot in payload.entries {
            let category = CategoryItem(
                flow: snapshot.flow,
                name: snapshot.categoryName,
                symbol: snapshot.categorySymbol,
                colorHex: snapshot.categoryColorHex
            )
            let entry = LedgerEntry(
                id: snapshot.id,
                createdAt: snapshot.createdAt,
                amount: snapshot.amount,
                originalAmount: snapshot.originalAmount ?? snapshot.amount,
                currencyCode: snapshot.currencyCode ?? "CNY",
                exchangeRateToCNY: snapshot.exchangeRateToCNY ?? 1,
                note: snapshot.note,
                flow: snapshot.flow,
                category: category,
                tagNames: snapshot.tagNames ?? []
            )
            modelContext.insert(entry)
        }

        for snapshot in payload.deposits {
            let deposit = VaultDepositRecord(
                id: snapshot.id,
                date: snapshot.date,
                amount: snapshot.amount,
                note: snapshot.note,
                goal: snapshot.goalID.flatMap { goalMap[$0] }
            )
            modelContext.insert(deposit)
        }

        try modelContext.save()
    }

    private func presentNotice(message: String) {
        noticeMessage = message
        showNotice = true
    }

    private func handleICloudSyncToggleChange(_ isEnabled: Bool) {
        guard !suppressNextICloudSyncHandling else {
            suppressNextICloudSyncHandling = false
            return
        }

        let effectiveEnabled = appRuntimeController.updateICloudSync(enabled: isEnabled)
        if effectiveEnabled != isEnabled {
            suppressNextICloudSyncHandling = true
            iCloudSyncEnabled = effectiveEnabled
        }

        HapticService.impact()
        Task {
            await appleAccountStore.refreshStatus()
        }

        if isEnabled && !effectiveEnabled {
            presentNotice(message: "当前无法启用 iCloud 同步，已继续使用本地存储。".appLocalized(in: uiLocale))
            return
        }

        presentNotice(
            message: effectiveEnabled
                ? "iCloud 同步已开启，当前会话已立即生效。".appLocalized(in: uiLocale)
                : "iCloud 同步已关闭，当前会话已切换为本地存储。".appLocalized(in: uiLocale)
        )
    }

    private func startAppleSignIn() async {
        let result = await appleSignInController.signIn { request in
            appleAccountStore.configure(request)
        }

        let outcome = await appleAccountStore.handleAuthorizationResult(result)
        switch outcome {
        case .signedIn:
            HapticService.impact()
            presentNotice(message: "Apple 账号已连接，可在下方开启 iCloud 同步。".appLocalized(in: uiLocale))
        case .cancelled:
            break
        case .failed(let message):
            presentNotice(message: message)
        }
    }

    private func push(_ route: SettingsRoute) {
        navigationPath.append(route)
        HapticService.selection()
    }

}

@MainActor
private final class AppleSignInController: NSObject, ObservableObject {
    private var continuation: CheckedContinuation<Result<ASAuthorization, Error>, Never>?
    private var authorizationController: ASAuthorizationController?

    func signIn(configure: (ASAuthorizationAppleIDRequest) -> Void) async -> Result<ASAuthorization, Error> {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        configure(request)

        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.authorizationController = controller
            controller.performRequests()
        }
    }
}

extension AppleSignInController: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        continuation?.resume(returning: .success(authorization))
        continuation = nil
        authorizationController = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(returning: .failure(error))
        continuation = nil
        authorizationController = nil
    }
}

extension AppleSignInController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

private struct SettingsMetricCard: View {
    @Environment(\.locale) private var locale
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.appLocalized(in: locale))
                .font(SettingsLayout.cardLabelFont)
                .tracking(SettingsLayout.cardLabelTracking)
                .foregroundStyle(SettingsLayout.sectionHeaderColor)
            Text(value)
                .font(SettingsLayout.cardValueFont)
                .foregroundStyle(SWTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.42), lineWidth: 1)
                )
        )
    }
}

private struct AboutSimpleWorthView: View {
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL

    let email: String
    let appVersionText: String
    let authorWebsiteURL: URL?
    let repoURL: URL?

    var body: some View {
        SettingsDetailContainer {
            SettingsSectionCard(title: "简值是什么") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("简值是一款尽量简单、安静、专注的记账 App，希望把每天的收支、标签、金库目标和统计视图收进一套足够轻盈的体验里。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)

                    Text("它更在意记录时的顺手、回看时的清楚，以及长期使用时的节奏感，所以会尽量减少打扰，让账单、目标和价值增长保持在同一个界面语言里。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)
                }
            }

            SettingsSectionCard(title: "基本信息") {
                SettingsKeyValueRow(title: "应用", value: "SimpleWorth（简值）")
                SettingsRowDivider()
                SettingsKeyValueRow(title: "版本", value: appVersionText)
                SettingsRowDivider()
                SettingsKeyValueRow(title: "开发者", value: "Larry Hu")
                SettingsRowDivider()
                SettingsKeyValueRow(title: "定位", value: "轻量记账与目标管理".appLocalized(in: locale))
            }

            SettingsSectionCard(title: "联系与项目") {
                SettingsDetailActionRow(
                    title: "联系邮箱",
                    symbol: "envelope.fill",
                    iconColor: SWTheme.accentBlue
                ) {
                    guard let mailURL = URL(string: "mailto:\(email)") else { return }
                    openURL(mailURL)
                }

                SettingsRowDivider()

                SettingsDetailActionRow(
                    title: "作者主页",
                    symbol: "safari.fill",
                    iconColor: SWTheme.accentGreen
                ) {
                    guard let authorWebsiteURL else { return }
                    openURL(authorWebsiteURL)
                }

                SettingsRowDivider()

                SettingsDetailActionRow(
                    title: "GitHub 仓库",
                    symbol: "link",
                    iconColor: SWTheme.accentOrange
                ) {
                    guard let repoURL else { return }
                    openURL(repoURL)
                }
            }
        }
        .navigationTitle("关于简值")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyAgreementView: View {
    @Environment(\.openURL) private var openURL

    let supportEmail: String

    var body: some View {
        SettingsDetailContainer {
            SettingsSectionCard(title: "数据与同步") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("账单、标签、目标与存入记录默认仅保存在当前设备。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)
                    Text("开启 iCloud 同步后，相关数据会同步到你当前 Apple 账号的 iCloud 私有数据库。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)
                }
            }

            SettingsSectionCard(title: "联网与系统能力") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("查看或刷新汇率时，App 会请求公开汇率接口以获取最新汇率。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)
                    Text("意见反馈、好评鼓励与分享简值会调用系统邮件、评分与分享能力。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)
                }
            }

            SettingsSectionCard(title: "联系作者") {
                SettingsDetailActionRow(
                    title: "联系邮箱",
                    symbol: "envelope.fill",
                    iconColor: SWTheme.accentBlue
                ) {
                    guard let mailURL = URL(string: "mailto:\(supportEmail)") else { return }
                    openURL(mailURL)
                }
            }
        }
        .navigationTitle("隐私协议")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct OtherAppsView: View {
    @Environment(\.openURL) private var openURL

    let authorWebsiteURL: URL?
    let repoURL: URL?

    var body: some View {
        SettingsDetailContainer {
            SettingsSectionCard(title: "更多作品") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("当前公开作品以 SimpleWorth 为主，后续应用会优先发布在作者主页。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)
                }

                SettingsRowDivider()

                SettingsDetailActionRow(
                    title: "作者主页",
                    symbol: "safari.fill",
                    iconColor: SWTheme.accentGreen
                ) {
                    guard let authorWebsiteURL else { return }
                    openURL(authorWebsiteURL)
                }

                SettingsRowDivider()

                SettingsDetailActionRow(
                    title: "GitHub 仓库",
                    symbol: "link",
                    iconColor: SWTheme.accentBlue
                ) {
                    guard let repoURL else { return }
                    openURL(repoURL)
                }
            }
        }
        .navigationTitle("其他 APP")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum BillImportRuntimeError: LocalizedError {
    case unsupportedCurrency(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedCurrency(let code):
            return L10n.string("settings.importUnsupportedCurrency", locale: L10n.locale, code)
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let subject: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.setValue(subject, forKey: "subject")
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct FeedbackContactView: View {
    @Environment(\.locale) private var locale

    let supportEmail: String
    let onCopyEmail: () -> Void
    let onSendMail: () -> Void

    var body: some View {
        SettingsDetailContainer {
            SettingsSectionCard(title: "反馈邮箱") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(supportEmail)
                        .font(.headline.monospaced())
                        .foregroundStyle(SWTheme.primaryText)
                        .textSelection(.enabled)

                    Text("你可以先复制邮箱，确认后再用系统邮件发送。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)

                    Text("发送邮件时会自动填入反馈主题和正文。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)
                }
                .padding(.vertical, 4)
            }

            SettingsSectionCard(title: "反馈方式") {
                feedbackMethodRow(
                    title: "复制邮箱",
                    subtitle: "先复制邮箱，再决定是否立刻发送邮件。",
                    symbol: "doc.on.doc.fill",
                    iconColor: SWTheme.accentBlue,
                    action: onCopyEmail
                )

                SettingsRowDivider()

                feedbackMethodRow(
                    title: "发送邮件",
                    subtitle: "系统会先打开邮件草稿，再由你确认是否真的发送。",
                    symbol: "paperplane.fill",
                    iconColor: SWTheme.accentGreen,
                    action: onSendMail
                )
            }
        }
        .navigationTitle("意见反馈")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func feedbackMethodRow(
        title: String,
        subtitle: String,
        symbol: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        SettingsPressableButton(action: action) {
            HStack(alignment: .top, spacing: SettingsLayout.rowSpacing) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: SettingsLayout.rowIconWidth)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title.appLocalized(in: locale))
                        .font(SettingsLayout.titleFont)
                        .foregroundStyle(SWTheme.primaryText)

                    Text(subtitle.appLocalized(in: locale))
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.vertical, SettingsLayout.rowVerticalPadding)
        }
    }
}

private struct BillImportGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let onImportSelected: (URL) -> Void
    let onNotice: (String) -> Void

    @State private var templateDocument: PlainTextDocument?
    @State private var showTemplateExporter = false
    @State private var showFileImporter = false

    private var templateFileName: String {
        "SimpleWorth-excel-template"
    }

    private var templateText: String {
        LedgerSpreadsheetImporter.makeTemplateText(locale: locale)
    }

    private var sampleRows: [String] {
        [
            "2026-03-18 08:32 | 支出 | 交通 | 6 | CNY | 早高峰地铁通勤 | 通勤/上班".appLocalized(in: locale),
            "2026-03-25 19:40 | 收入 | 工资 | 9800 | CNY | 3 月工资 | 工资/固定收入".appLocalized(in: locale)
        ]
    }

    var body: some View {
        SettingsDetailContainer {
            SettingsSectionCard(title: "Excel 模板") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("下载后可以直接用 Excel、WPS 或 Numbers 打开，按行填写自己的账单，再把这张表导回简值。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)

                    Text("模板实际保存为通用 CSV 表格，兼容大多数表格软件。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)

                    SettingsWideActionButton {
                        templateDocument = PlainTextDocument(text: templateText)
                        showTemplateExporter = true
                        HapticService.selection()
                    } label: {
                        Label("下载 Excel 模板", systemImage: "tablecells.badge.ellipsis")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SWTheme.primaryText)
                    }
                }
            }

            SettingsSectionCard(title: "真实案例") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("下面这两行就是模板里的真实填写案例，你只需要照着改日期、分类、金额、备注和标签。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(sampleRows, id: \.self) { row in
                            Text(row)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(SWTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.04))
                                )
                        }
                    }
                }
            }

            SettingsSectionCard(title: "填写说明") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("日期支持“2026-03-18 08:32”或“2026-03-18”这类写法；如果只写日期，系统会按当天默认时间导入。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)

                    Text("类型填写“支出”或“收入”；分类建议直接使用简值里已有的分类名称。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)

                    Text("标签可用“/”分隔，例如“通勤/上班”；模板里没有的标签会自动帮你创建。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)

                    Text("如果币种不是 CNY，系统会按当前已缓存的汇率自动折算成人民币。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)
                }
            }

            SettingsSectionCard(title: "开始导入") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("导入只会追加新的账单，不会清空你当前已有的数据；如果模板里有完全相同的账单行，会自动跳过。")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(SWTheme.accentGreen)

                    SettingsWideActionButton {
                        showFileImporter = true
                        HapticService.selection()
                    } label: {
                        Label("选择 Excel 导入文件", systemImage: "square.and.arrow.down.on.square")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SWTheme.primaryText)
                    }
                }
            }
        }
        .navigationTitle("账单导入")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showTemplateExporter,
            document: templateDocument,
            contentType: .commaSeparatedText,
            defaultFilename: templateFileName
        ) { result in
            switch result {
            case .success:
                HapticService.impact()
                onNotice("导入模板已成功导出。".appLocalized(in: locale))
            case .failure(let error):
                onNotice(L10n.string("settings.exportFailed", locale: locale, error.localizedDescription))
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: LedgerSpreadsheetImporter.importContentTypes) { result in
            switch result {
            case .success(let url):
                onImportSelected(url)
                dismiss()
            case .failure(let error):
                onNotice(L10n.string("settings.importFailed", locale: locale, error.localizedDescription))
            }
        }
    }
}
