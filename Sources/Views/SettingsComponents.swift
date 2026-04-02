import SwiftUI

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
        Button(action: action) {
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
    var trailingSymbol: String = "arrow.up.right"
    let action: () -> Void

    var body: some View {
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

                Image(systemName: trailingSymbol)
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
}
