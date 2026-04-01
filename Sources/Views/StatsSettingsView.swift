import AuthenticationServices
import StoreKit
import SwiftData
import SwiftUI
import UIKit

private enum SettingsRoute: Hashable {
    case currency
    case tags
    case iCloud
    case importBills
}

struct StatsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: [SortDescriptor(\LedgerEntry.createdAt, order: .reverse)]) private var entries: [LedgerEntry]
    @Query(sort: [SortDescriptor(\TagRecord.createdAt, order: .forward)]) private var tags: [TagRecord]
    @Query(sort: [SortDescriptor(\SavingsGoalRecord.createdAt, order: .reverse)]) private var goals: [SavingsGoalRecord]
    @Query(sort: [SortDescriptor(\VaultDepositRecord.date, order: .reverse)]) private var deposits: [VaultDepositRecord]

    @AppStorage("settings.hapticsEnabled") private var hapticsEnabled = true
    @AppStorage(SettingsKeys.iCloudSyncEnabled) private var iCloudSyncEnabled = false
    @AppStorage(SettingsKeys.themeMode) private var themeModeRaw = ThemeMode.resolved().rawValue
    @AppStorage(SettingsKeys.appLanguage) private var appLanguageRaw = AppLanguage.simplifiedChinese.rawValue
    @AppStorage("settings.detailedTimeEnabled") private var detailedTimeEnabled = false
    @State private var showPrivacySheet = false
    @State private var showAuthorSheet = false
    @State private var showOtherAppsSheet = false
    @State private var showFeedbackSheet = false
    @State private var showShareSheet = false
    @State private var showDetailedTimeInfo = false
    @State private var navigationPath = NavigationPath()

    @State private var exportDocument: LedgerBackupDocument?
    @State private var showFileExporter = false

    @State private var noticeMessage = ""
    @State private var showNotice = false
    @StateObject private var appleAccountStore = AppleAccountStore.shared

    private let repoURL = URL(string: "https://github.com/LarryHu1988/SimpleWorth")
    private let authorWebsiteURL = URL(string: "https://larryhu.com")
    private let supportEmail = "simpleworth@larryhu.com"

    private var selectedThemeMode: ThemeMode {
        ThemeMode(rawValue: themeModeRaw) ?? ThemeMode.resolved()
    }

    private var selectedAppLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .simplifiedChinese
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.6.1"
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
                LazyVStack(spacing: SettingsLayout.pageSectionSpacing) {
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
                        SettingsPressableButton {
                            push(.iCloud)
                        } label: {
                            settingsNavigationRowLabel(
                                title: "iCloud 同步",
                                symbol: "icloud.fill",
                                iconColor: SWTheme.accentBlue
                            )
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
                            showFeedbackSheet = true
                            HapticService.selection()
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

                    SettingsSectionCard(title: "关于简值") {
                        settingsActionRow(
                            title: "隐私协议",
                            symbol: "hand.raised.fill",
                            iconColor: SWTheme.accentBlue
                        ) {
                            showPrivacySheet = true
                            HapticService.selection()
                        }

                        SettingsRowDivider()

                        settingsActionRow(
                            title: "作者信息",
                            symbol: "person.crop.rectangle.stack.fill",
                            iconColor: SWTheme.accentOrange
                        ) {
                            showAuthorSheet = true
                            HapticService.selection()
                        }

                        SettingsRowDivider()

                        settingsActionRow(
                            title: "其他 APP",
                            symbol: "square.grid.2x2.fill",
                            iconColor: SWTheme.accentGreen
                        ) {
                            showOtherAppsSheet = true
                            HapticService.selection()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(selectedThemeMode.preferredColorScheme)
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
            .sheet(isPresented: $showPrivacySheet) {
                PrivacyAgreementView(supportEmail: supportEmail)
            }
            .sheet(isPresented: $showAuthorSheet) {
                AuthorInfoView(
                    email: supportEmail,
                    appVersionText: appVersionText,
                    authorWebsiteURL: authorWebsiteURL,
                    repoURL: repoURL
                )
            }
            .sheet(isPresented: $showOtherAppsSheet) {
                OtherAppsView(authorWebsiteURL: authorWebsiteURL, repoURL: repoURL)
            }
            .sheet(isPresented: $showFeedbackSheet) {
                FeedbackContactView(
                    supportEmail: supportEmail,
                    onCopyEmail: copyFeedbackAddress,
                    onSendMail: sendFeedback
                )
            }
            .sheet(isPresented: $showShareSheet) {
                if let repoURL {
                    ShareSheet(
                        activityItems: [
                            "我在用这款记账 App：SimpleWorth（简值），推荐你试试。".appLocalized(in: locale),
                            repoURL
                        ],
                        subject: "SimpleWorth 简值".appLocalized(in: locale)
                    )
                }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .currency:
                    CurrencySettingsView()
                case .tags:
                    TagManagementView()
                case .iCloud:
                    ICloudSettingsView()
                case .importBills:
                    BillImportGuideView(
                        appVersionText: appVersionText,
                        onImportSelected: importBackup(from:),
                        onNotice: presentNotice(message:)
                    )
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
                    presentNotice(message: "账单已成功导出。".appLocalized(in: locale))
                case .failure(let error):
                    presentNotice(message: L10n.string("settings.exportFailed", locale: locale, error.localizedDescription))
                }
            }
            .appBackground()
            .task {
                await appleAccountStore.refreshStatus()
            }
        }
    }

    private var appleAccountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: "apple.logo")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(SWTheme.primaryText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple 账号".appLocalized(in: locale))
                        .font(SettingsLayout.cardTitleFont)
                        .tracking(SettingsLayout.cardTitleTracking)
                        .foregroundStyle(SettingsLayout.cardTitleColor)
                    Text(appleAccountSubtitle)
                        .font(SettingsLayout.cardSecondaryFont)
                        .foregroundStyle(appleAccountSubtitleTint)
                }

                Spacer()
            }

            if appleAccountStore.isSignedIn {
                if !appleAccountDisplayTitle.isEmpty {
                    Text(appleAccountDisplayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SWTheme.primaryText)
                }

                if let email = appleAccountStore.email, !email.isEmpty {
                    Text(email)
                        .font(SettingsLayout.cardSecondaryFont)
                        .foregroundStyle(SWTheme.textSecondary)
                }

                HStack(spacing: 10) {
                    Button {
                        enableAppleSync()
                    } label: {
                        Text("同步到当前账号".appLocalized(in: locale))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(SWTheme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.14))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await appleAccountStore.refreshStatus()
                            HapticService.selection()
                        }
                    } label: {
                        Text("重新检测".appLocalized(in: locale))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SWTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    appleAccountStore.configure(request)
                } onCompletion: { result in
                    Task {
                        let outcome = await appleAccountStore.handleAuthorizationResult(result)
                        switch outcome {
                        case .signedIn:
                            enableAppleSync()
                        case .cancelled:
                            break
                        case .failed(let message):
                            presentNotice(message: message)
                        }
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 46)

                Text("登录后会自动开启 iCloud 同步，请完全退出并重新打开 App 后生效。".appLocalized(in: locale))
                    .font(SettingsLayout.cardSecondaryFont)
                    .foregroundStyle(SWTheme.textSecondary)
            }
        }
        .fitnessCard()
    }

    private var statsHeaderCard: some View {
        HStack(spacing: 12) {
            SettingsMetricCard(title: "记账总天数", value: "\(totalLedgerDays)", tint: SWTheme.accentBlue)
            SettingsMetricCard(title: "记账总笔数", value: "\(totalEntryCount)", tint: SWTheme.accentGreen)
        }
    }

    private var appleAccountDisplayTitle: String {
        if let displayName = appleAccountStore.displayName, !displayName.isEmpty {
            return displayName
        }
        return "Apple 用户".appLocalized(in: locale)
    }

    private var appleAccountSubtitle: String {
        switch appleAccountStore.credentialStatus {
        case .authorized:
            switch appleAccountStore.iCloudStatus {
            case .available:
                return "同步已准备就绪".appLocalized(in: locale)
            case .noAccount:
                return "Apple 已登录，但当前设备未登录 iCloud。".appLocalized(in: locale)
            case .restricted:
                return "Apple 已登录，但当前 iCloud 账号受限。".appLocalized(in: locale)
            case .couldNotDetermine:
                return "Apple 已登录，iCloud 状态待检测。".appLocalized(in: locale)
            case .temporarilyUnavailable:
                return "Apple 已登录，iCloud 当前暂时不可用。".appLocalized(in: locale)
            @unknown default:
                return "Apple 已登录，iCloud 状态待检测。".appLocalized(in: locale)
            }
        case .checking:
            return "正在检测 Apple 账号状态...".appLocalized(in: locale)
        case .revoked:
            return "Apple 授权已失效，请重新登录。".appLocalized(in: locale)
        case .unavailable:
            return "当前无法读取 Apple 账号状态。".appLocalized(in: locale)
        case .signedOut:
            return "登录后将账单同步到当前 Apple 账号".appLocalized(in: locale)
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

                Text(title.appLocalized(in: locale))
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

            Text(title.appLocalized(in: locale))
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
                .accessibilityLabel(L10n.string("settings.infoAccessibility", locale: locale, title.appLocalized(in: locale)))
                .popover(isPresented: isInfoPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    Text(infoText.appLocalized(in: locale))
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

            Text(title.appLocalized(in: locale))
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
            URLQueryItem(name: "subject", value: "SimpleWorth 意见反馈".appLocalized(in: locale)),
            URLQueryItem(name: "body", value: "请描述你的建议或问题：".appLocalized(in: locale))
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
        presentNotice(message: "已复制反馈邮箱地址。".appLocalized(in: locale))
    }

    private func fallbackToCopiedFeedbackAddress() {
        UIPasteboard.general.string = supportEmail
        HapticService.impact()
        presentNotice(message: L10n.string("settings.feedbackUnavailable", locale: locale, supportEmail))
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

    private func importBackup(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(LedgerBackupPayload.self, from: data)

            try replaceLocalData(with: payload)
            HapticService.impact()
            presentNotice(message: "账单已成功导入。".appLocalized(in: locale))
        } catch {
            presentNotice(message: L10n.string("settings.importFailed", locale: locale, error.localizedDescription))
        }
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

    private func enableAppleSync() {
        iCloudSyncEnabled = true
        HapticService.impact()
        presentNotice(message: "登录后会自动开启 iCloud 同步，请完全退出并重新打开 App 后生效。".appLocalized(in: locale))
    }

    private func push(_ route: SettingsRoute) {
        navigationPath.append(route)
        HapticService.selection()
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

private struct AuthorInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL

    let email: String
    let appVersionText: String
    let authorWebsiteURL: URL?
    let repoURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section("基本信息") {
                    HStack {
                        Text("应用")
                        Spacer()
                        Text("SimpleWorth（简值）")
                            .foregroundStyle(SWTheme.textSecondary)
                    }

                    HStack {
                        Text("版本")
                        Spacer()
                        Text(appVersionText)
                            .foregroundStyle(SWTheme.textSecondary)
                    }

                    HStack {
                        Text("开发者")
                        Spacer()
                        Text("Larry Hu")
                            .foregroundStyle(SWTheme.textSecondary)
                    }
                }

                Section("联系与项目") {
                    Button {
                        if let mailURL = URL(string: "mailto:\(email)") {
                            openURL(mailURL)
                        }
                    } label: {
                        Label("联系邮箱", systemImage: "envelope")
                    }

                    Button {
                        guard let authorWebsiteURL else { return }
                        openURL(authorWebsiteURL)
                    } label: {
                        Label("作者主页", systemImage: "safari")
                    }

                    Button {
                        guard let repoURL else { return }
                        openURL(repoURL)
                    } label: {
                        Label("GitHub 仓库", systemImage: "link")
                    }
                }
            }
            .navigationTitle("作者信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct PrivacyAgreementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL

    let supportEmail: String

    var body: some View {
        NavigationStack {
            List {
                Section("数据与同步") {
                    Text("账单、标签、目标与存入记录默认仅保存在当前设备。")
                    Text("开启 iCloud 同步后，相关数据会同步到你当前 Apple 账号的 iCloud 私有数据库。")
                }

                Section("联网与系统能力") {
                    Text("查看或刷新汇率时，App 会请求公开汇率接口以获取最新汇率。")
                    Text("意见反馈、好评鼓励与分享简值会调用系统邮件、评分与分享能力。")
                }

                Section("联系作者") {
                    Button {
                        if let mailURL = URL(string: "mailto:\(supportEmail)") {
                            openURL(mailURL)
                        }
                    } label: {
                        Label("联系邮箱", systemImage: "envelope")
                    }
                }
            }
            .navigationTitle("隐私协议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct OtherAppsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL

    let authorWebsiteURL: URL?
    let repoURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section("更多作品") {
                    Text("当前公开作品以 SimpleWorth 为主，后续应用会优先发布在作者主页。")
                        .foregroundStyle(SWTheme.textSecondary)

                    Button {
                        guard let authorWebsiteURL else { return }
                        openURL(authorWebsiteURL)
                    } label: {
                        Label("作者主页", systemImage: "safari")
                    }

                    Button {
                        guard let repoURL else { return }
                        openURL(repoURL)
                    } label: {
                        Label("GitHub 仓库", systemImage: "link")
                    }
                }
            }
            .navigationTitle("其他 APP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
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
    @Environment(\.dismiss) private var dismiss

    let supportEmail: String
    let onCopyEmail: () -> Void
    let onSendMail: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("反馈邮箱") {
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

                Section {
                    Button {
                        onCopyEmail()
                        dismiss()
                    } label: {
                        Label("复制邮箱", systemImage: "doc.on.doc")
                    }

                    Button {
                        dismiss()
                        DispatchQueue.main.async {
                            onSendMail()
                        }
                    } label: {
                        Label("发送邮件", systemImage: "paperplane.fill")
                    }
                }
            }
            .navigationTitle("意见反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct BillImportGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let appVersionText: String
    let onImportSelected: (URL) -> Void
    let onNotice: (String) -> Void

    @State private var templateDocument: LedgerBackupDocument?
    @State private var showTemplateExporter = false
    @State private var showFileImporter = false
    @State private var pendingImportURL: URL?
    @State private var showImportConfirmation = false

    private static let templateEntryID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let templateTagID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let templateGoalID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private static let templateDepositID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    private static let exportedDate = sampleDate("2026-03-30T12:00:00Z")
    private static let entryDate = sampleDate("2026-03-18T00:32:00Z")
    private static let goalDate = sampleDate("2026-01-05T09:00:00Z")
    private static let depositDate = sampleDate("2026-03-05T13:00:00Z")

    private var templateFileName: String {
        "SimpleWorth-import-template"
    }

    private var templatePayload: LedgerBackupPayload {
        LedgerBackupPayload(
            exportedAt: Self.exportedDate,
            appVersion: appVersionText,
            entries: [
                LedgerEntrySnapshot(
                    id: Self.templateEntryID,
                    createdAt: Self.entryDate,
                    amount: 6,
                    originalAmount: 6,
                    currencyCode: "CNY",
                    exchangeRateToCNY: 1,
                    note: "早高峰地铁通勤",
                    tagNames: ["通勤"],
                    flow: .expense,
                    categoryName: "交通",
                    categorySymbol: "car.fill",
                    categoryColorHex: 0x818CF8
                )
            ],
            tags: [
                TagSnapshot(
                    id: Self.templateTagID,
                    name: "通勤",
                    emoji: "🚇",
                    tintHex: 0x60A5FA,
                    createdAt: Self.entryDate
                )
            ],
            goals: [
                SavingsGoalSnapshot(
                    id: Self.templateGoalID,
                    createdAt: Self.goalDate,
                    name: "东京旅行基金",
                    symbol: "airplane",
                    currentAmount: 1500,
                    targetAmount: 8000,
                    deadline: Self.sampleDate("2026-10-01T00:00:00Z"),
                    tintHex: 0x38BDF8
                )
            ],
            deposits: [
                VaultDepositSnapshot(
                    id: Self.templateDepositID,
                    date: Self.depositDate,
                    amount: 500,
                    note: "3 月工资转入",
                    goalID: Self.templateGoalID
                )
            ]
        )
    }

    private var templatePreview: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard
            let data = try? encoder.encode(templatePayload),
            let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                SettingsSectionCard(title: "导入模板") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("这份模板展示了一个真实导入案例：2026 年 3 月 18 日早高峰地铁通勤支出 6 元，标签为“通勤”，分类为“交通”；同时示例了“东京旅行基金”目标，以及一笔“3 月工资转入”存入记录。")
                            .font(.footnote)
                            .foregroundStyle(SWTheme.textSecondary)

                        Button {
                            templateDocument = LedgerBackupDocument(payload: templatePayload)
                            showTemplateExporter = true
                            HapticService.selection()
                        } label: {
                            Label("下载导入模板", systemImage: "arrow.down.doc.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SWTheme.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                SettingsSectionCard(title: "模板内容") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("真实案例")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SWTheme.primaryText)

                        Text("你可以对照这条案例修改日期、金额、标签、目标名称等字段，再导入自己的数据。")
                            .font(.footnote)
                            .foregroundStyle(SWTheme.textSecondary)

                        Text("解释说明")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SWTheme.primaryText)

                        Text("entries 表示账单明细；tags 对应可复用标签；goals 是金库目标；deposits 用 goalID 关联到对应目标。")
                            .font(.footnote)
                            .foregroundStyle(SWTheme.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(templatePreview)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(SWTheme.primaryText)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.04))
                                )
                        }
                    }
                }

                SettingsSectionCard(title: "导入说明") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("导入文件需保持 JSON 格式，并与模板字段结构一致。")
                            .font(.footnote)
                            .foregroundStyle(SWTheme.textSecondary)

                        Text("时间字段请使用 ISO 8601 格式，例如 2026-03-30T12:00:00Z。")
                            .font(.footnote)
                            .foregroundStyle(SWTheme.textSecondary)

                        Text("deposits 中的 goalID 需要和 goals 里的 id 对应，未关联可填 null。")
                            .font(.footnote)
                            .foregroundStyle(SWTheme.textSecondary)

                        Text("导入会替换当前设备上的账单、标签、目标和存入记录，请先确认已完成备份。")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(SWTheme.accentOrange)

                        Button {
                            showFileImporter = true
                            HapticService.selection()
                        } label: {
                            Label("选择账单导入文件", systemImage: "square.and.arrow.down.on.square")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SWTheme.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .navigationTitle("账单导入")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showTemplateExporter,
            document: templateDocument,
            contentType: .json,
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
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                pendingImportURL = url
                showImportConfirmation = true
            case .failure(let error):
                onNotice(L10n.string("settings.importFailed", locale: locale, error.localizedDescription))
            }
        }
        .alert("确认导入", isPresented: $showImportConfirmation, presenting: pendingImportURL) { url in
            Button("取消", role: .cancel) {
                pendingImportURL = nil
            }
            Button("继续导入", role: .destructive) {
                onImportSelected(url)
                pendingImportURL = nil
                dismiss()
            }
        } message: { _ in
            Text("导入后会覆盖当前本地数据，且无法撤销。")
        }
        .appBackground()
    }

    private static func sampleDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value) ?? .now
    }
}
