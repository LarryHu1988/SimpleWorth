import CloudKit
import SwiftData
import SwiftUI

struct ICloudSettingsView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appRuntimeController: AppRuntimeController

    @Query(sort: [SortDescriptor(\LedgerEntry.createdAt, order: .reverse)]) private var entries: [LedgerEntry]
    @Query(sort: [SortDescriptor(\TagRecord.createdAt, order: .forward)]) private var tags: [TagRecord]
    @Query(sort: [SortDescriptor(\SavingsGoalRecord.createdAt, order: .reverse)]) private var goals: [SavingsGoalRecord]
    @Query(sort: [SortDescriptor(\VaultDepositRecord.date, order: .reverse)]) private var deposits: [VaultDepositRecord]

    @AppStorage(SettingsKeys.iCloudSyncEnabled) private var persistedICloudSyncEnabled = false
    @AppStorage(SettingsKeys.backupRetentionDays) private var backupRetentionDays = BackupRetentionRule.keep15Days.rawValue

    @State private var noticeSheet: SettingsNoticePayload?
    @State private var showRetentionSheet = false
    @State private var showBackupHistory = false
    @State private var suppressNextToggleChange = false
    @State private var backupRecords: [LocalBackupRecord] = []
    @State private var iCloudSyncEnabled = false
    @State private var isApplyingSyncToggle = false
    @State private var syncToggleFailureMessage: String?
    @State private var syncToggleFailureAlertMessage: String?

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.6.6"
        return "V\(version)"
    }

    private var retentionRule: BackupRetentionRule {
        BackupRetentionRule(rawValue: backupRetentionDays) ?? .keep15Days
    }

    private var hasAnyUserData: Bool {
        !entries.isEmpty || !tags.isEmpty || !goals.isEmpty || !deposits.isEmpty
    }

    private var latestBackupRecord: LocalBackupRecord? {
        backupRecords.first
    }

    var body: some View {
        SettingsDetailContainer {
            SettingsSectionCard(title: "同步备份") {
                autoSyncToggleRow

                if let syncToggleFailureMessage {
                    Text(syncToggleFailureMessage)
                        .font(.footnote)
                        .foregroundStyle(SWTheme.accentOrange)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .padding(.bottom, 2)
                }

                SettingsRowDivider()

                autoBackupRuleRow

                SettingsRowDivider()

                backupOverviewRow

                SettingsRowDivider()

                backupActionButtons

                SettingsRowDivider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("开启后会把账单、标签、金库目标和存入记录同步到当前设备的 iCloud 私有数据库，并每天自动保留一份本地备份。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)

                    Text("恢复备份会覆盖当前设备上的账单数据，建议先确认现在的内容已经保存。")
                        .font(.footnote)
                        .foregroundStyle(SWTheme.textSecondary)
                }
                .padding(.vertical, 4)
            }
        }
        .overlay {
            ZStack {
                if let notice = noticeSheet {
                    SettingsInlineNoticeOverlay(payload: notice) {
                        noticeSheet = nil
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(2)
                }

                if showRetentionSheet {
                    SettingsBottomSheetOverlay {
                        withAnimation(.easeOut(duration: 0.18)) {
                            showRetentionSheet = false
                        }
                    } content: {
                        BackupRetentionRuleSheet(
                            selectedRule: retentionRule,
                            locale: locale,
                            onSelect: { newRule in
                                updateRetentionRule(newRule)
                                withAnimation(.easeOut(duration: 0.18)) {
                                    showRetentionSheet = false
                                }
                            },
                            onCancel: {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    showRetentionSheet = false
                                }
                            }
                        )
                    }
                    .zIndex(3)
                }
            }
        }
        .navigationTitle("iCloud 同步")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "iCloud 自动备份".appLocalized(in: locale),
            isPresented: Binding(
                get: { syncToggleFailureAlertMessage != nil },
                set: { if !$0 { syncToggleFailureAlertMessage = nil } }
            ),
            actions: {
                Button("确定".appLocalized(in: locale)) {
                    syncToggleFailureAlertMessage = nil
                }
            },
            message: {
                Text(syncToggleFailureAlertMessage ?? "")
            }
        )
        .navigationDestination(isPresented: $showBackupHistory) {
            ICloudBackupHistoryView(records: backupRecords) {
                reloadBackupRecords()
            }
        }
        .task {
            iCloudSyncEnabled = persistedICloudSyncEnabled
            refreshPageState()
        }
        .onChange(of: persistedICloudSyncEnabled) { _, newValue in
            guard newValue != iCloudSyncEnabled else { return }
            suppressNextToggleChange = true
            iCloudSyncEnabled = newValue
        }
        .onChange(of: iCloudSyncEnabled) { _, newValue in
            handleICloudSyncToggleChange(newValue)
        }
        .animation(.easeOut(duration: 0.18), value: noticeSheet?.id)
    }

    private var autoSyncToggleRow: some View {
        HStack(spacing: SettingsLayout.rowSpacing) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SWTheme.accentBlue)
                .frame(width: SettingsLayout.rowIconWidth)

            Text("iCloud 自动备份".appLocalized(in: locale))
                .font(SettingsLayout.titleFont)
                .foregroundStyle(SWTheme.primaryText)

            Spacer()

            Toggle("", isOn: $iCloudSyncEnabled)
                .labelsHidden()
                .scaleEffect(SettingsLayout.compactToggleScale)
                .fixedSize()
                .disabled(isApplyingSyncToggle)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: SettingsLayout.rowContentMinHeight,
            alignment: .leading
        )
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }

    private var autoBackupRuleRow: some View {
        SettingsPressableButton {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
                showRetentionSheet = true
            }
            HapticService.selection()
        } label: {
            HStack(spacing: SettingsLayout.rowSpacing) {
                Image(systemName: "externaldrive.badge.icloud")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SWTheme.accentBlue)
                    .frame(width: SettingsLayout.rowIconWidth)

                Text("自动备份规则".appLocalized(in: locale))
                    .font(SettingsLayout.titleFont)
                    .foregroundStyle(SWTheme.primaryText)

                Spacer(minLength: 12)

                Text(retentionRule.shortTitle(in: locale))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: SettingsLayout.rowContentMinHeight,
                alignment: .leading
            )
            .padding(.vertical, SettingsLayout.rowVerticalPadding)
        }
    }

    private var backupOverviewRow: some View {
        SettingsPressableButton {
            showBackupHistory = true
            HapticService.selection()
        } label: {
            HStack(spacing: SettingsLayout.rowSpacing) {
                Image(systemName: "externaldrive.fill.badge.checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SWTheme.accentGreen)
                    .frame(width: SettingsLayout.rowIconWidth)

                Text("数据备份文件".appLocalized(in: locale))
                    .font(SettingsLayout.titleFont)
                    .foregroundStyle(SWTheme.primaryText)

                Spacer(minLength: 12)

                Text(latestBackupSummaryText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: SettingsLayout.rowContentMinHeight,
                alignment: .leading
            )
            .padding(.vertical, SettingsLayout.rowVerticalPadding)
        }
    }

    private var backupActionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                backupActionButton(
                    title: "立即备份",
                    symbol: "arrow.clockwise.circle.fill",
                    tint: SWTheme.accentBlue
                ) {
                    createManualBackup()
                }

                backupActionButton(
                    title: "恢复备份",
                    symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    tint: SWTheme.accentGreen
                ) {
                    showBackupHistory = true
                    HapticService.selection()
                }
            }

            VStack(spacing: 10) {
                backupActionButton(
                    title: "立即备份",
                    symbol: "arrow.clockwise.circle.fill",
                    tint: SWTheme.accentBlue
                ) {
                    createManualBackup()
                }

                backupActionButton(
                    title: "恢复备份",
                    symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    tint: SWTheme.accentGreen
                ) {
                    showBackupHistory = true
                    HapticService.selection()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func backupActionButton(
        title: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(title.appLocalized(in: locale))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(SWTheme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(tint.opacity(0.28), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var latestBackupSummaryText: String {
        guard let latestBackupRecord else {
            return "暂无备份".appLocalized(in: locale)
        }

        let timeText = shortTimeText(for: latestBackupRecord.createdAt)
        let title: String
        if Calendar.current.isDateInToday(latestBackupRecord.createdAt) {
            title = L10n.string("settings.backupSummaryToday", locale: locale, timeText)
        } else if Calendar.current.isDateInYesterday(latestBackupRecord.createdAt) {
            title = L10n.string("settings.backupSummaryYesterday", locale: locale, timeText)
        } else {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateFormat = "MM-dd HH:mm"
            title = L10n.string("settings.backupSummaryGeneric", locale: locale, formatter.string(from: latestBackupRecord.createdAt))
        }

        return title
    }

    private func shortTimeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func refreshPageState() {
        reloadBackupRecords()
        applyRetentionRule(retentionRule)
        if hasAnyUserData {
            ensureAutomaticBackupIfNeeded()
        }
    }

    private func reloadBackupRecords() {
        backupRecords = LocalBackupStore.loadRecords()
    }

    private func createManualBackup() {
        guard hasAnyUserData else {
            HapticService.warning()
            presentNotice(message: "当前还没有可备份的数据。".appLocalized(in: locale))
            return
        }

        do {
            let payload = currentBackupPayload()
            _ = try LocalBackupStore.createBackup(payload: payload, source: .manual)
            LocalBackupStore.removeExpiredBackups(keepingLast: retentionRule.days)
            reloadBackupRecords()
            HapticService.success()
        } catch {
            HapticService.warning()
            presentNotice(message: L10n.string("settings.exportFailed", locale: locale, error.localizedDescription))
        }
    }

    private func ensureAutomaticBackupIfNeeded() {
        do {
            try LocalBackupStore.ensureAutomaticBackupIfNeeded(
                payload: currentBackupPayload(),
                shouldCreate: hasAnyUserData
            )
            LocalBackupStore.removeExpiredBackups(keepingLast: retentionRule.days)
            reloadBackupRecords()
        } catch {
            // Keep the page usable even if local backup maintenance fails.
        }
    }

    private func currentBackupPayload() -> LedgerBackupPayload {
        LedgerBackupCoordinator.makePayload(
            appVersion: appVersionText,
            entries: entries,
            tags: tags,
            goals: goals,
            deposits: deposits
        )
    }

    private func handleICloudSyncToggleChange(_ isEnabled: Bool) {
        guard !suppressNextToggleChange else {
            suppressNextToggleChange = false
            return
        }

        Task {
            await applyICloudToggleChange(isEnabled)
        }
    }

    @MainActor
    private func applyICloudToggleChange(_ isEnabled: Bool) async {
        isApplyingSyncToggle = true
        defer { isApplyingSyncToggle = false }

        if isEnabled, let preflightFailure = await iCloudAvailabilityFailureReason() {
            revertICloudToggle(afterFailedEnablementWith: preflightFailure)
            return
        }

        let outcome = appRuntimeController.updateICloudSync(
            enabled: isEnabled,
            seedPayload: hasAnyUserData ? currentBackupPayload() : nil
        )
        let effectiveEnabled = outcome.effectiveEnabled
        persistedICloudSyncEnabled = effectiveEnabled
        if effectiveEnabled != isEnabled {
            suppressNextToggleChange = true
            iCloudSyncEnabled = effectiveEnabled
        }

        if let error = outcome.error {
            let message = isEnabled
                ? iCloudEnableFailureMessage(reason: outcome.fallbackReason ?? error.localizedDescription)
                : L10n.string("settings.iCloudDisableMigrationFailed", locale: locale, error.localizedDescription)
            presentICloudToggleFailure(message)
            return
        }

        if isEnabled && !effectiveEnabled {
            let message = iCloudEnableFailureMessage(reason: outcome.fallbackReason)
            presentICloudToggleFailure(message)
            return
        }

        syncToggleFailureMessage = nil
        syncToggleFailureAlertMessage = nil
        HapticService.success()
    }

    @MainActor
    private func revertICloudToggle(afterFailedEnablementWith message: String) {
        persistedICloudSyncEnabled = false
        suppressNextToggleChange = true
        iCloudSyncEnabled = false
        presentICloudToggleFailure(message)
    }

    @MainActor
    private func presentICloudToggleFailure(_ message: String) {
        syncToggleFailureMessage = message
        syncToggleFailureAlertMessage = message
        HapticService.warning()
    }

    private func iCloudEnableFailureMessage(reason: String?) -> String {
        guard let reason, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "当前无法启用 iCloud 同步，已继续使用本地存储。".appLocalized(in: locale)
        }

        return L10n.string(
            "settings.iCloudEnableFailedWithReason",
            locale: locale,
            humanReadableICloudFailureReason(reason)
        )
    }

    private func humanReadableICloudFailureReason(_ rawReason: String) -> String {
        let trimmed = rawReason.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()

        if lowered.contains("entitlement") || lowered.contains("icloud-container-identifiers") {
            return "当前 App 的 iCloud 能力或签名配置不可用。".appLocalized(in: locale)
        }
        if lowered.contains("account") || lowered.contains("ubiquit") || lowered.contains("cloudkit") {
            return "当前设备未登录 iCloud，或 iCloud / CloudKit 当前不可用。".appLocalized(in: locale)
        }
        if lowered.contains("network") || lowered.contains("internet") {
            return "当前网络不可用，暂时无法连接 iCloud。".appLocalized(in: locale)
        }

        return trimmed
    }

    private func iCloudAvailabilityFailureReason() async -> String? {
        do {
            let status = try await CKContainer(identifier: AppConfig.iCloudContainerIdentifier).accountStatus()
            switch status {
            case .available:
                return nil
            case .noAccount:
                return "当前设备未登录 iCloud 账号。".appLocalized(in: locale)
            case .restricted:
                return "当前设备限制了 iCloud 使用，暂时无法开启自动备份。".appLocalized(in: locale)
            case .couldNotDetermine:
                return "当前暂时无法确认 iCloud 状态，请稍后再试。".appLocalized(in: locale)
            case .temporarilyUnavailable:
                return "iCloud 当前暂时不可用，请稍后再试。".appLocalized(in: locale)
            @unknown default:
                return "当前暂时无法确认 iCloud 状态，请稍后再试。".appLocalized(in: locale)
            }
        } catch {
            return humanReadableICloudFailureReason(error.localizedDescription)
        }
    }

    private func updateRetentionRule(_ newRule: BackupRetentionRule) {
        guard newRule != retentionRule else { return }
        backupRetentionDays = newRule.rawValue
        applyRetentionRule(newRule)
        HapticService.selection()
    }

    private func applyRetentionRule(_ rule: BackupRetentionRule) {
        LocalBackupStore.removeExpiredBackups(keepingLast: rule.days)
        reloadBackupRecords()
    }

    private func presentNotice(message: String) {
        noticeSheet = SettingsNoticePayload(message: message, locale: locale)
    }
}

private struct ICloudBackupHistoryView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\LedgerEntry.createdAt, order: .reverse)]) private var entries: [LedgerEntry]
    @Query(sort: [SortDescriptor(\TagRecord.createdAt, order: .forward)]) private var tags: [TagRecord]
    @Query(sort: [SortDescriptor(\SavingsGoalRecord.createdAt, order: .reverse)]) private var goals: [SavingsGoalRecord]
    @Query(sort: [SortDescriptor(\VaultDepositRecord.date, order: .reverse)]) private var deposits: [VaultDepositRecord]

    @State private var records: [LocalBackupRecord]
    @State private var actionPrompt: BackupRecordActionPrompt?
    @State private var noticeSheet: SettingsNoticePayload?
    let onRecordsChanged: () -> Void

    init(records: [LocalBackupRecord], onRecordsChanged: @escaping () -> Void = {}) {
        _records = State(initialValue: records)
        self.onRecordsChanged = onRecordsChanged
    }

    var body: some View {
        SettingsDetailContainer {
            SettingsSectionCard(title: "恢复说明") {
                Text("使用右侧的恢复按钮可回到对应时刻的数据；删除按钮会移除这份备份文件。恢复后，当前设备上的账单、标签、目标和存入记录会被替换。")
                    .font(.footnote)
                    .foregroundStyle(SWTheme.textSecondary)
                    .padding(.vertical, 4)
            }

            if records.isEmpty {
                SettingsSectionCard(title: "备份记录") {
                    VStack(alignment: .center, spacing: 10) {
                        Image(systemName: "externaldrive.badge.xmark")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(SWTheme.textSecondary)

                        Text("当前还没有备份记录。".appLocalized(in: locale))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(SWTheme.primaryText)

                        Text("先回到上一页点一次“立即备份”，这里就会出现可恢复的记录。".appLocalized(in: locale))
                            .font(.footnote)
                            .foregroundStyle(SWTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            } else {
                SettingsSectionCard(title: "备份记录") {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        backupRecordRow(record)

                        if index != records.count - 1 {
                            SettingsRowDivider()
                        }
                    }
                }
            }
        }
        .navigationTitle("数据备份")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            ZStack {
                if let prompt = actionPrompt {
                    SettingsBottomSheetOverlay {
                        withAnimation(.easeOut(duration: 0.18)) {
                            actionPrompt = nil
                        }
                    } content: {
                        BackupRecordActionSheet(
                            prompt: prompt,
                            locale: locale,
                            onConfirm: {
                                dismissActionPromptThen {
                                    switch prompt.kind {
                                    case .restore:
                                        restore(prompt.record)
                                    case .delete:
                                        delete(prompt.record)
                                    }
                                }
                            },
                            onCancel: {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    actionPrompt = nil
                                }
                            }
                        )
                    }
                    .zIndex(3)
                }

                if let notice = noticeSheet {
                    SettingsBottomSheetOverlay {
                        withAnimation(.easeOut(duration: 0.18)) {
                            noticeSheet = nil
                        }
                    } content: {
                        SettingsNoticeCard(payload: notice) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                noticeSheet = nil
                            }
                        }
                    }
                    .zIndex(4)
                }
            }
        }
    }

    private func dismissActionPromptThen(_ action: @escaping () -> Void) {
        withAnimation(.easeOut(duration: 0.18)) {
            actionPrompt = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            action()
        }
    }

    private func backupRecordRow(_ record: LocalBackupRecord) -> some View {
        HStack(alignment: .top, spacing: SettingsLayout.rowSpacing) {
            ZStack {
                Circle()
                    .fill(record.tintColor.opacity(0.16))
                    .frame(width: 32, height: 32)

                Image(systemName: record.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(record.tintColor)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(record.displayTitle(in: locale))
                    .font(SettingsLayout.titleFont)
                    .foregroundStyle(SWTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(record.detailText(in: locale))
                    .font(.footnote)
                    .foregroundStyle(SWTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(record.metaText(in: locale))
                    .font(.caption)
                    .foregroundStyle(SWTheme.textSecondary.opacity(0.88))
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                miniActionButton(
                    symbol: "arrow.counterclockwise",
                    tint: SWTheme.accentBlue
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
                        actionPrompt = BackupRecordActionPrompt(kind: .restore, record: record)
                    }
                    HapticService.selection()
                }

                miniActionButton(
                    symbol: "trash",
                    tint: SWTheme.accentOrange
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
                        actionPrompt = BackupRecordActionPrompt(kind: .delete, record: record)
                    }
                    HapticService.selection()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }

    private func miniActionButton(symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.12))
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .buttonStyle(.plain)
    }

    private func restore(_ record: LocalBackupRecord) {
        do {
            let data = try Data(contentsOf: record.fileURL)
            let payload = try LedgerBackupCodec.decodePayload(from: data)
            try LedgerBackupCoordinator.replaceLocalData(
                with: payload,
                context: modelContext,
                entries: entries,
                tags: tags,
                goals: goals,
                deposits: deposits
            )
            HapticService.success()
            noticeSheet = SettingsNoticePayload(
                message: "备份恢复完成，当前数据已更新。".appLocalized(in: locale),
                locale: locale
            )
        } catch {
            HapticService.warning()
            noticeSheet = SettingsNoticePayload(
                message: L10n.string("settings.importFailed", locale: locale, error.localizedDescription),
                locale: locale
            )
        }
    }

    private func delete(_ record: LocalBackupRecord) {
        do {
            try LocalBackupStore.deleteBackup(record)
            records.removeAll { $0.id == record.id }
            onRecordsChanged()
            HapticService.success()
        } catch {
            HapticService.warning()
            noticeSheet = SettingsNoticePayload(
                message: L10n.string("settings.exportFailed", locale: locale, error.localizedDescription),
                locale: locale
            )
        }
    }
}

private struct BackupRetentionRuleSheet: View {
    let selectedRule: BackupRetentionRule
    let locale: Locale
    let onSelect: (BackupRetentionRule) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsSheetLayout.sectionSpacing) {
            SettingsSheetHandle()

            VStack(alignment: .leading, spacing: 8) {
                Text("自动备份规则".appLocalized(in: locale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SWTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("系统每天会自动备份一次，超过保留天数的旧文件会自动删除。".appLocalized(in: locale))
                    .font(.footnote)
                    .foregroundStyle(SWTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)

            VStack(spacing: 0) {
                ForEach(BackupRetentionRule.allCases) { rule in
                    Button {
                        onSelect(rule)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(SWTheme.textSecondary)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(rule.title(in: locale))
                                    .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SWTheme.primaryText)

                                Text(rule.subtitle(in: locale))
                                    .font(.footnote)
                                    .foregroundStyle(SWTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 8)

                            if rule == selectedRule {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(SWTheme.accentBlue)
                                    .padding(.top, 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if rule != BackupRetentionRule.allCases.last {
                        SettingsRowDivider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .fitnessCard()

            Button {
                onCancel()
            } label: {
                Text("取消".appLocalized(in: locale))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SWTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, SettingsSheetLayout.horizontalPadding)
        .padding(.top, SettingsSheetLayout.topPadding)
        .padding(.bottom, SettingsSheetLayout.bottomPadding)
        .frame(maxWidth: .infinity, alignment: .top)
        .settingsBottomSheetCard()
    }
}

private enum BackupRetentionRule: Int, CaseIterable, Identifiable {
    case keep7Days = 7
    case keep15Days = 15
    case keep30Days = 30

    var id: Int { rawValue }

    var days: Int { rawValue }

    func shortTitle(in locale: Locale) -> String {
        L10n.string("settings.backupRetentionShortTitle", locale: locale, Int64(days))
    }

    func title(in locale: Locale) -> String {
        L10n.string("settings.backupRetentionTitle", locale: locale, Int64(days))
    }

    func subtitle(in locale: Locale) -> String {
        switch self {
        case .keep7Days:
            return "更省空间".appLocalized(in: locale)
        case .keep15Days:
            return "默认推荐".appLocalized(in: locale)
        case .keep30Days:
            return "保留更久".appLocalized(in: locale)
        }
    }
}

private enum BackupSource: String {
    case automatic
    case manual

    var filePrefix: String {
        switch self {
        case .automatic:
            "auto"
        case .manual:
            "manual"
        }
    }

    init(fileName: String) {
        if fileName.hasPrefix("auto-") {
            self = .automatic
        } else {
            self = .manual
        }
    }

    func title(in locale: Locale) -> String {
        switch self {
        case .automatic:
            return "自动备份".appLocalized(in: locale)
        case .manual:
            return "手动备份".appLocalized(in: locale)
        }
    }
}

private struct LocalBackupRecord: Identifiable {
    let id: String
    let source: BackupSource
    let fileURL: URL
    let createdAt: Date
    let payload: LedgerBackupPayload
    let fileSize: Int64

    var symbolName: String {
        switch source {
        case .automatic:
            "clock.arrow.circlepath"
        case .manual:
            "internaldrive.fill"
        }
    }

    var tintColor: Color {
        switch source {
        case .automatic:
            SWTheme.accentBlue
        case .manual:
            SWTheme.accentGreen
        }
    }

    func displayTitle(in locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        if Calendar.current.isDateInToday(createdAt) {
            formatter.dateFormat = "HH:mm"
            return L10n.string(
                "settings.backupRecordTitleToday",
                locale: locale,
                formatter.string(from: createdAt),
                source.title(in: locale)
            )
        }

        formatter.dateFormat = "MM-dd HH:mm"
        return L10n.string(
            "settings.backupRecordTitleDate",
            locale: locale,
            formatter.string(from: createdAt),
            source.title(in: locale)
        )
    }

    func detailText(in locale: Locale) -> String {
        L10n.string(
            "settings.backupRecordDetail",
            locale: locale,
            Int64(payload.entries.count),
            Int64(payload.tags?.count ?? 0),
            Int64(payload.goals.count),
            Int64(payload.deposits.count)
        )
    }

    func metaText(in locale: Locale) -> String {
        let sizeText = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        return L10n.string("settings.backupRecordMeta", locale: locale, payload.appVersion, sizeText)
    }
}

private enum LocalBackupStore {
    private static let folderName = "ICloudLocalBackups"

    static func loadRecords() -> [LocalBackupRecord] {
        guard let directoryURL = try? backupDirectoryURL() else {
            return []
        }

        let fileManager = FileManager.default
        let urls = (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let records = urls.compactMap { fileURL -> LocalBackupRecord? in
            guard fileURL.pathExtension.lowercased() == "json",
                  let data = try? Data(contentsOf: fileURL),
                  let payload = try? LedgerBackupCodec.decodePayload(from: data) else {
                return nil
            }

            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = Int64(values?.fileSize ?? data.count)
            let source = BackupSource(fileName: fileURL.lastPathComponent)

            return LocalBackupRecord(
                id: fileURL.deletingPathExtension().lastPathComponent,
                source: source,
                fileURL: fileURL,
                createdAt: payload.exportedAt,
                payload: payload,
                fileSize: fileSize
            )
        }

        return records.sorted { $0.createdAt > $1.createdAt }
    }

    static func createBackup(payload: LedgerBackupPayload, source: BackupSource) throws -> LocalBackupRecord {
        let directoryURL = try backupDirectoryURL()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: payload.exportedAt)
        let fileName = "\(source.filePrefix)-backup-\(timestamp)-\(UUID().uuidString.prefix(6)).json"
        let fileURL = directoryURL.appendingPathComponent(fileName)
        let data = try LedgerBackupCodec.encodePayload(payload)
        try data.write(to: fileURL, options: .atomic)

        return LocalBackupRecord(
            id: fileURL.deletingPathExtension().lastPathComponent,
            source: source,
            fileURL: fileURL,
            createdAt: payload.exportedAt,
            payload: payload,
            fileSize: Int64(data.count)
        )
    }

    static func ensureAutomaticBackupIfNeeded(payload: LedgerBackupPayload, shouldCreate: Bool) throws {
        guard shouldCreate else { return }
        let records = loadRecords()
        if records.contains(where: { $0.source == .automatic && Calendar.current.isDate($0.createdAt, inSameDayAs: payload.exportedAt) }) {
            return
        }
        _ = try createBackup(payload: payload, source: .automatic)
    }

    static func deleteBackup(_ record: LocalBackupRecord) throws {
        try FileManager.default.removeItem(at: record.fileURL)
    }

    static func removeExpiredBackups(keepingLast days: Int) {
        guard let directoryURL = try? backupDirectoryURL() else { return }
        let expirationDate = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        let records = loadRecords()
        let expired = records.filter { $0.createdAt < expirationDate }
        for record in expired {
            try? FileManager.default.removeItem(at: record.fileURL)
        }

        if expired.isEmpty {
            let staleFiles = (try? FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)) ?? []
            staleFiles
                .filter { $0.pathExtension.lowercased() != "json" }
                .forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }

    private static func backupDirectoryURL() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = baseURL.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}

private struct BackupRecordActionPrompt: Identifiable {
    enum Kind {
        case restore
        case delete
    }

    let id = UUID()
    let kind: Kind
    let record: LocalBackupRecord

    func promptTitle(in locale: Locale) -> String {
        switch kind {
        case .restore:
            return "恢复这个备份".appLocalized(in: locale)
        case .delete:
            return "删除这个备份".appLocalized(in: locale)
        }
    }

    func confirmTitle(in locale: Locale) -> String {
        switch kind {
        case .restore:
            return "确定恢复".appLocalized(in: locale)
        case .delete:
            return "确定删除".appLocalized(in: locale)
        }
    }

    func message(in locale: Locale) -> String {
        switch kind {
        case .restore:
            return "恢复后会用这份备份覆盖当前设备上的账单、标签、金库目标和存入记录。".appLocalized(in: locale)
        case .delete:
            return "删除后，这份备份文件将无法恢复。".appLocalized(in: locale)
        }
    }
}

private struct BackupRecordActionSheet: View {
    let prompt: BackupRecordActionPrompt
    let locale: Locale
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsSheetLayout.sectionSpacing) {
            SettingsSheetHandle()

            VStack(spacing: SettingsSheetLayout.bodySpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(promptTint.opacity(0.14))
                        .frame(width: 54, height: 54)

                    Image(systemName: promptSymbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(promptTint)
                }

                Text(promptTitle.appLocalized(in: locale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SWTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text(promptMessage)
                    .font(.footnote)
                    .foregroundStyle(SWTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: SettingsSheetLayout.buttonSpacing) {
                Button {
                    onConfirm()
                } label: {
                    Text(confirmTitle.appLocalized(in: locale))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(promptTint.opacity(0.92))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    onCancel()
                } label: {
                    Text("取消".appLocalized(in: locale))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SWTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, SettingsSheetLayout.horizontalPadding)
        .padding(.top, SettingsSheetLayout.topPadding)
        .padding(.bottom, SettingsSheetLayout.bottomPadding)
        .frame(maxWidth: .infinity, alignment: .top)
        .settingsBottomSheetCard()
    }

    private var promptTitle: String {
        switch prompt.kind {
        case .restore:
            return "恢复这个备份"
        case .delete:
            return "删除这个备份"
        }
    }

    private var confirmTitle: String {
        switch prompt.kind {
        case .restore:
            return "确定恢复"
        case .delete:
            return "确定删除"
        }
    }

    private var promptMessage: String {
        switch prompt.kind {
        case .restore:
            return L10n.string("settings.restoreBackupPrompt", locale: locale, prompt.record.displayTitle(in: locale))
        case .delete:
            return L10n.string("settings.deleteBackupPrompt", locale: locale, prompt.record.displayTitle(in: locale))
        }
    }

    private var promptSymbol: String {
        switch prompt.kind {
        case .restore:
            return "arrow.counterclockwise"
        case .delete:
            return "trash"
        }
    }

    private var promptTint: Color {
        switch prompt.kind {
        case .restore:
            return SWTheme.accentBlue
        case .delete:
            return SWTheme.accentOrange
        }
    }
}
