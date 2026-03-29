import CloudKit
import SwiftUI

struct ICloudSettingsView: View {
    @Environment(\.locale) private var locale
    @AppStorage(SettingsKeys.iCloudSyncEnabled) private var iCloudSyncEnabled = false
    @State private var iCloudAccountState: ICloudAccountState = .idle
    @State private var noticeMessage = ""
    @State private var showNotice = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                SettingsSectionCard(title: "同步设置") {
                    settingToggleRow(
                        title: "开启 iCloud 同步",
                        symbol: "icloud.fill",
                        iconColor: SWTheme.accentBlue,
                        isOn: $iCloudSyncEnabled
                    )
                    .onChange(of: iCloudSyncEnabled) { _, newValue in
                        HapticService.impact()
                        refreshICloudAccountStatus()
                        presentNotice(
                            message: newValue
                                ? "已开启 iCloud 同步，请完全退出并重新打开 App 后生效。".appLocalized
                                : "已关闭 iCloud 同步，请完全退出并重新打开 App 后生效。".appLocalized
                        )
                    }

                    SettingsRowDivider()

                    iCloudStatusRow

                    SettingsRowDivider()

                    settingsActionRow(
                        title: "检测 iCloud 状态",
                        symbol: "arrow.clockwise.icloud",
                        iconColor: SWTheme.accentGreen
                    ) {
                        HapticService.impact()
                        refreshICloudAccountStatus()
                    }
                }

                SettingsSectionCard(title: "说明") {
                    Text("开启后会优先使用 iCloud 私有数据库同步数据；如果当前设备或账号不可用，App 会自动回退到本地存储。")
                        .font(.subheadline)
                        .foregroundStyle(SWTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .navigationTitle("iCloud 同步")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            refreshICloudAccountStatus()
        }
        .alert("操作结果", isPresented: $showNotice) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(noticeMessage)
        }
        .appBackground()
    }

    private var iCloudStatusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: iCloudAccountState.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iCloudAccountState.tint)
                .frame(width: 22)

            Text("当前状态")
                .foregroundStyle(SWTheme.primaryText)

            Spacer()

            Text(iCloudAccountState.text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(iCloudAccountState.tint)
        }
        .padding(.vertical, 4)
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

                Text(title.appLocalized)
                    .foregroundStyle(SWTheme.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SWTheme.textSecondary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func settingToggleRow(
        title: String,
        symbol: String,
        iconColor: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22)

            Text(title.appLocalized)
                .foregroundStyle(SWTheme.primaryText)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.vertical, 4)
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
            "未检测".appLocalized
        case .checking:
            "检测中".appLocalized
        case .available:
            "可用".appLocalized
        case .unavailable(let message):
            message.appLocalized
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
