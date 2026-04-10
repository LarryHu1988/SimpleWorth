import SwiftUI
import UIKit

enum SettingsLayout {
    static let pageSectionSpacing: CGFloat = 14
    static let sectionSpacing: CGFloat = 10
    static let rowSpacing: CGFloat = 12
    static let rowIconWidth: CGFloat = 22
    static let rowVerticalPadding: CGFloat = 8
    static let rowContentMinHeight: CGFloat = 30
    static let inlineControlSize: CGFloat = 30
    static let dividerLeadingInset: CGFloat = rowIconWidth + rowSpacing
    static let dividerVerticalPadding: CGFloat = 4
    static let titleFont: Font = .subheadline.weight(.medium)
    static let sectionHeaderFont: Font = .system(.footnote, design: .rounded).weight(.semibold)
    static let sectionHeaderTracking: CGFloat = 0.2
    static let sectionHeaderColor = Color.dynamic(
        light: 0x495D72,
        dark: 0xD8E5F9,
        lightAlpha: 0.9,
        darkAlpha: 0.84
    )
    static let cardTitleFont: Font = .system(.subheadline, design: .rounded).weight(.semibold)
    static let cardTitleTracking: CGFloat = 0.16
    static let cardTitleColor = Color.dynamic(
        light: 0x24384E,
        dark: 0xF3F8FF,
        lightAlpha: 0.96,
        darkAlpha: 0.94
    )
    static let cardLabelFont: Font = .system(.caption, design: .rounded).weight(.semibold)
    static let cardLabelTracking: CGFloat = 0.16
    static let cardSecondaryFont: Font = .system(.caption, design: .rounded).weight(.medium)
    static let cardValueFont: Font = .system(.title3, design: .rounded).weight(.bold)
    static let tapCancellationDistance: CGFloat = 10
    static let compactToggleScale: CGFloat = 0.82
}

struct SettingsSectionCard<Content: View>: View {
    @Environment(\.locale) private var locale
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsLayout.sectionSpacing) {
            Text(title.appLocalized(in: locale))
                .font(SettingsLayout.sectionHeaderFont)
                .tracking(SettingsLayout.sectionHeaderTracking)
                .foregroundStyle(SettingsLayout.sectionHeaderColor)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitnessCard()
    }
}

struct SettingsRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, SettingsLayout.dividerLeadingInset)
            .padding(.vertical, SettingsLayout.dividerVerticalPadding)
    }
}

struct SettingsPressableButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRowButtonStyle())
    }
}

private struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SettingsDetailContainer<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 16) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .appBackground()
    }
}

struct SettingsKeyValueRow: View {
    @Environment(\.locale) private var locale

    let title: String
    let value: String

    var body: some View {
        HStack(spacing: SettingsLayout.rowSpacing) {
            Text(title.appLocalized(in: locale))
                .font(SettingsLayout.titleFont)
                .foregroundStyle(SWTheme.primaryText)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SWTheme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: SettingsLayout.rowContentMinHeight,
            alignment: .leading
        )
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }
}

struct SettingsWideActionButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button {
            HapticService.selection()
            action()
        } label: {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsDetailActionRow: View {
    @Environment(\.locale) private var locale

    let title: String
    let symbol: String
    let iconColor: Color
    var trailingSymbol: String? = "arrow.up.right"
    let action: () -> Void

    var body: some View {
        SettingsPressableButton {
            HapticService.selection()
            action()
        } label: {
            HStack(spacing: SettingsLayout.rowSpacing) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: SettingsLayout.rowIconWidth)

                Text(title.appLocalized(in: locale))
                    .font(SettingsLayout.titleFont)
                    .foregroundStyle(SWTheme.primaryText)

                Spacer()

                if let trailingSymbol, !trailingSymbol.isEmpty {
                    Image(systemName: trailingSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SWTheme.textSecondary)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: SettingsLayout.rowContentMinHeight,
                alignment: .leading
            )
            .padding(.vertical, SettingsLayout.rowVerticalPadding)
        }
    }
}

enum SettingsSheetLayout {
    static let horizontalPadding: CGFloat = 16
    static let topPadding: CGFloat = 6
    static let bottomPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 18
    static let bodySpacing: CGFloat = 12
    static let buttonSpacing: CGFloat = 10
    static let handleTopPadding: CGFloat = 14
    static let cornerRadius: CGFloat = 28
    static let maxHeightRatio: CGFloat = 0.82
}

private struct SettingsSheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct AdaptiveSettingsSheetModifier: ViewModifier {
    let minHeight: CGFloat
    let maxHeightRatio: CGFloat

    @State private var measuredHeight: CGFloat = 0

    private var resolvedHeight: CGFloat {
        let maxHeight = currentWindowHeight * maxHeightRatio
        return min(max(measuredHeight, minHeight), maxHeight)
    }

    private var currentWindowHeight: CGFloat {
        let windowHeight = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .bounds.height

        return windowHeight ?? UIScreen.main.bounds.height
    }

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: SettingsSheetHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(SettingsSheetHeightKey.self) { newValue in
                guard abs(newValue - measuredHeight) > 1 else { return }
                measuredHeight = newValue
            }
            .presentationDetents([.height(resolvedHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(SettingsSheetLayout.cornerRadius)
    }
}

struct SettingsSheetHandle: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.16))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, SettingsSheetLayout.handleTopPadding)
    }
}

extension View {
    func settingsAdaptiveSheet(minHeight: CGFloat, maxHeightRatio: CGFloat = SettingsSheetLayout.maxHeightRatio) -> some View {
        modifier(AdaptiveSettingsSheetModifier(minHeight: minHeight, maxHeightRatio: maxHeightRatio))
    }
}

struct SettingsNoticePayload: Identifiable {
    let id = UUID()
    let message: String
    let locale: Locale
}

struct SettingsNoticeSheet: View {
    let payload: SettingsNoticePayload
    let onClose: () -> Void

    var body: some View {
        SettingsNoticeCard(payload: payload, onClose: onClose)
            .appBackground()
            .settingsAdaptiveSheet(minHeight: 214)
    }
}

struct SettingsNoticeCard: View {
    let payload: SettingsNoticePayload
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsSheetLayout.sectionSpacing) {
            SettingsSheetHandle()

            VStack(spacing: SettingsSheetLayout.bodySpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SWTheme.accentBlue.opacity(0.14))
                        .frame(width: 54, height: 54)

                    Image(systemName: "info.circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(SWTheme.accentBlue)
                }

                Text("操作结果".appLocalized(in: payload.locale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SWTheme.primaryText)

                Text(payload.message)
                    .font(.footnote)
                    .foregroundStyle(SWTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            Button {
                onClose()
            } label: {
                Text("确定".appLocalized(in: payload.locale))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(SWTheme.accentBlue.opacity(0.92))
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

struct SettingsInlineNoticeOverlay: View {
    let payload: SettingsNoticePayload
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            VStack(spacing: 16) {
                Text("操作结果".appLocalized(in: payload.locale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SWTheme.primaryText)

                Text(payload.message)
                    .font(.footnote)
                    .foregroundStyle(SWTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button("确定".appLocalized(in: payload.locale)) {
                    onClose()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(SWTheme.accentBlue.opacity(0.92))
                )
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 320)
            .fitnessCard()
            .padding(.horizontal, 24)
        }
    }
}

struct SettingsBottomSheetOverlay<SheetContent: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let content: SheetContent

    init(onDismiss: @escaping () -> Void, @ViewBuilder content: () -> SheetContent) {
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.18)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onDismiss()
                    }

                content
                    .frame(maxWidth: min(560, proxy.size.width - 24))
                    .padding(.horizontal, 12)
                    .allowsHitTesting(true)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea()
        }
    }
}

private struct SettingsBottomSheetCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let topColor = colorScheme == .light
            ? Color.sw(0x93AFCB, alpha: 0.92)
            : Color.sw(0x1F2B38, alpha: 0.98)
        let bottomColor = colorScheme == .light
            ? Color.sw(0xDCE8F4, alpha: 0.96)
            : Color.sw(0x0E1620, alpha: 0.98)
        let sheenColor = colorScheme == .light
            ? Color.white.opacity(0.30)
            : Color.white.opacity(0.08)
        let borderColor = colorScheme == .light
            ? Color.white.opacity(0.56)
            : Color.white.opacity(0.16)
        let sheetShape = UnevenRoundedRectangle(
            topLeadingRadius: SettingsSheetLayout.cornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: SettingsSheetLayout.cornerRadius,
            style: .continuous
        )

        content
            .background(
                sheetShape
                    .fill(
                        LinearGradient(
                            colors: [topColor, bottomColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        sheetShape
                            .fill(
                                LinearGradient(
                                    colors: [sheenColor, .clear, Color.white.opacity(0.01)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        sheetShape
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
            .clipShape(sheetShape)
            .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
    }
}

extension View {
    func settingsBottomSheetCard() -> some View {
        modifier(SettingsBottomSheetCardModifier())
    }
}
