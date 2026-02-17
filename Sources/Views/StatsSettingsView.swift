import CloudKit
import StoreKit
import SwiftData
import SwiftUI

struct StatsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\LedgerEntry.createdAt, order: .reverse)]) private var entries: [LedgerEntry]
    @Query(sort: [SortDescriptor(\SavingsGoalRecord.createdAt, order: .reverse)]) private var goals: [SavingsGoalRecord]
    @Query(sort: [SortDescriptor(\VaultDepositRecord.date, order: .reverse)]) private var deposits: [VaultDepositRecord]

    @AppStorage("settings.hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("settings.darkModeEnabled") private var darkModeEnabled = true
    @AppStorage("settings.detailedTimeEnabled") private var detailedTimeEnabled = false
    @AppStorage(SettingsKeys.iCloudSyncEnabled) private var iCloudSyncEnabled = false

    @State private var showDeveloperSheet = false
    @State private var showDetailedTimeInfo = false
    @State private var iCloudAccountState: ICloudAccountState = .idle

    @State private var exportDocument: LedgerBackupDocument?
    @State private var showFileExporter = false
    @State private var showFileImporter = false

    @State private var noticeMessage = ""
    @State private var showNotice = false

    private let shareURL = URL(string: "https://github.com/LarryHu1988/SimpleWorth")
    private let supportEmail = "larry_hu@163.com"

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.5.0"
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
        NavigationStack {
            List {
                Section {
                    statsHeaderCard
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                }

                Section("个人偏好") {
                    settingToggleRow(
                        title: "震动反馈",
                        symbol: "iphone.radiowaves.left.and.right",
                        iconColor: SWTheme.accentPink,
                        isOn: $hapticsEnabled
                    )
                    .onChange(of: hapticsEnabled) { _, newValue in
                        if newValue { HapticService.impact() }
                    }

                    settingToggleRow(
                        title: "深色模式",
                        symbol: "moon.stars.fill",
                        iconColor: SWTheme.accentBlue,
                        isOn: $darkModeEnabled
                    )
                    .onChange(of: darkModeEnabled) { _, _ in
                        HapticService.impact()
                    }

                    settingToggleRow(
                        title: "账单详细时间",
                        symbol: "clock.badge.checkmark.fill",
                        iconColor: SWTheme.accentOrange,
                        isOn: $detailedTimeEnabled,
                        infoAction: {
                            showDetailedTimeInfo = true
                        }
                    )
                    .onChange(of: detailedTimeEnabled) { _, _ in
                        HapticService.impact()
                    }

                    NavigationLink {
                        CurrencySettingsView()
                    } label: {
                        settingsNavigationRowLabel(
                            title: "货币选择",
                            symbol: "dollarsign.circle.fill",
                            iconColor: SWTheme.accentGreen
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section("数据安全") {
                    settingToggleRow(
                        title: "iCloud 同步",
                        symbol: "icloud.fill",
                        iconColor: SWTheme.accentBlue,
                        isOn: $iCloudSyncEnabled
                    )
                    .onChange(of: iCloudSyncEnabled) { _, newValue in
                        HapticService.impact()
                        refreshICloudAccountStatus()
                        presentNotice(
                            message: newValue
                                ? "已开启 iCloud 同步，请完全退出并重新打开 App 后生效。"
                                : "已关闭 iCloud 同步，请完全退出并重新打开 App 后生效。"
                        )
                    }

                    iCloudStatusRow

                    settingsActionRow(
                        title: "检测 iCloud 状态",
                        symbol: "arrow.clockwise.icloud",
                        iconColor: SWTheme.accentBlue
                    ) {
                        HapticService.impact()
                        refreshICloudAccountStatus()
                    }

                    settingsActionRow(
                        title: "账单导出",
                        symbol: "square.and.arrow.up.on.square",
                        iconColor: SWTheme.accentGreen
                    ) {
                        exportBackup()
                    }

                    settingsActionRow(
                        title: "账单导入",
                        symbol: "square.and.arrow.down.on.square",
                        iconColor: SWTheme.accentOrange
                    ) {
                        showFileImporter = true
                    }
                }

                Section("良性互动") {
                    settingsActionRow(
                        title: "意见反馈",
                        symbol: "envelope.fill",
                        iconColor: SWTheme.accentBlue
                    ) {
                        sendFeedback()
                    }

                    settingsActionRow(
                        title: "好评鼓励",
                        symbol: "hand.thumbsup.fill",
                        iconColor: SWTheme.accentGreen
                    ) {
                        requestReview()
                        HapticService.impact()
                    }

                    if let shareURL {
                        ShareLink(
                            item: shareURL,
                            subject: Text("SimpleWorth 简值"),
                            message: Text("我在用这款记账 App：SimpleWorth（简值），推荐你试试。")
                        ) {
                            settingsShareLabel(
                                title: "分享给朋友",
                                symbol: "square.and.arrow.up",
                                iconColor: SWTheme.accentPink
                            )
                        }
                    } else {
                        settingsShareLabel(
                            title: "分享给朋友",
                            symbol: "square.and.arrow.up",
                            iconColor: SWTheme.accentPink
                        )
                        .foregroundStyle(SWTheme.textSecondary)
                    }
                }

                Section("开发者信息") {
                    settingsActionRow(
                        title: "开发者信息",
                        symbol: "person.crop.circle",
                        iconColor: SWTheme.accentOrange
                    ) {
                        showDeveloperSheet = true
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                refreshICloudAccountStatus()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("说明", isPresented: $showDetailedTimeInfo) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("开启后，新增/编辑账单可精确到分钟；关闭后仅精确到天。")
            }
            .alert("操作结果", isPresented: $showNotice) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(noticeMessage)
            }
            .sheet(isPresented: $showDeveloperSheet) {
                DeveloperInfoView(email: supportEmail, appVersionText: appVersionText)
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
                    presentNotice(message: "账单已成功导出。")
                case .failure(let error):
                    presentNotice(message: "导出失败：\(error.localizedDescription)")
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    importBackup(from: url)
                case .failure(let error):
                    presentNotice(message: "导入失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private var statsHeaderCard: some View {
        HStack(spacing: 12) {
            SettingsMetricCard(title: "记账总天数", value: "\(totalLedgerDays)", tint: SWTheme.accentBlue)
            SettingsMetricCard(title: "记账总笔数", value: "\(totalEntryCount)", tint: SWTheme.accentGreen)
        }
        .padding(.horizontal, 16)
    }

    private var iCloudStatusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: iCloudAccountState.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iCloudAccountState.tint)
                .frame(width: 22)

            Text("iCloud 状态")
                .foregroundStyle(.white)

            Spacer()

            Text(iCloudAccountState.text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(iCloudAccountState.tint)
        }
    }

    private func settingsActionRow(
        title: String,
        symbol: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 22)

                Text(title)
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingToggleRow(
        title: String,
        symbol: String,
        iconColor: Color,
        isOn: Binding<Bool>,
        infoAction: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22)

            HStack(spacing: 6) {
                Text(title)
                    .foregroundStyle(.white)

                if let infoAction {
                    Button(action: infoAction) {
                        Image(systemName: "info.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SWTheme.accentBlue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title)说明")
                }
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }

    private func settingsShareLabel(
        title: String,
        symbol: String,
        iconColor: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22)

            Text(title)
                .foregroundStyle(.white)

            Spacer()
        }
    }

    private func settingsNavigationRowLabel(
        title: String,
        symbol: String,
        iconColor: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22)

            Text(title)
                .foregroundStyle(.white)

            Spacer()
        }
    }

    private func sendFeedback() {
        let subject = "SimpleWorth 意见反馈".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = "请描述你的建议或问题：".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "mailto:\(supportEmail)?subject=\(subject)&body=\(body)") else {
            return
        }

        openURL(url)
        HapticService.impact()
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
                    flow: $0.flow,
                    categoryName: $0.categoryName,
                    categorySymbol: $0.categorySymbol,
                    categoryColorHex: $0.categoryColorHex
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
            presentNotice(message: "账单已成功导入。")
        } catch {
            presentNotice(message: "导入失败：\(error.localizedDescription)")
        }
    }

    private func replaceLocalData(with payload: LedgerBackupPayload) throws {
        deposits.forEach { modelContext.delete($0) }
        goals.forEach { modelContext.delete($0) }
        entries.forEach { modelContext.delete($0) }

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
                category: category
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

    private func refreshICloudAccountStatus() {
        iCloudAccountState = .checking

        Task {
            let container = CKContainer(identifier: AppConfig.iCloudContainerIdentifier)
            do {
                let status = try await container.accountStatus()
                await MainActor.run {
                    iCloudAccountState = mapICloudStatus(status)
                }
            } catch {
                await MainActor.run {
                    iCloudAccountState = .unavailable("检测失败")
                }
            }
        }
    }

    private func mapICloudStatus(_ status: CKAccountStatus) -> ICloudAccountState {
        switch status {
        case .available:
            .available
        case .noAccount:
            .unavailable("未登录账号")
        case .restricted:
            .unavailable("账号受限")
        case .couldNotDetermine:
            .unavailable("无法确定")
        case .temporarilyUnavailable:
            .unavailable("暂时不可用")
        @unknown default:
            .unavailable("未知状态")
        }
    }
}

private enum ICloudAccountState {
    case idle
    case checking
    case available
    case unavailable(String)

    var text: String {
        switch self {
        case .idle:
            "未检测"
        case .checking:
            "检测中"
        case .available:
            "可用"
        case .unavailable(let message):
            message
        }
    }

    var symbol: String {
        switch self {
        case .idle:
            "icloud"
        case .checking:
            "icloud.and.arrow.down"
        case .available:
            "checkmark.icloud.fill"
        case .unavailable:
            "xmark.icloud.fill"
        }
    }

    var tint: Color {
        switch self {
        case .idle, .checking:
            SWTheme.textSecondary
        case .available:
            SWTheme.accentGreen
        case .unavailable:
            SWTheme.accentOrange
        }
    }
}

private struct SettingsMetricCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(SWTheme.textSecondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
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

private struct DeveloperInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let email: String
    let appVersionText: String

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
                        if let repoURL = URL(string: "https://github.com/LarryHu1988/SimpleWorth") {
                            openURL(repoURL)
                        }
                    } label: {
                        Label("GitHub 仓库", systemImage: "link")
                    }
                }
            }
            .navigationTitle("开发者信息")
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
