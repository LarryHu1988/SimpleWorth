import SwiftUI

enum SettingsLayout {
    static let sectionSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 12
    static let rowIconWidth: CGFloat = 22
    static let rowVerticalPadding: CGFloat = 8
    static let titleFont: Font = .subheadline.weight(.medium)
    static let sectionHeaderFont: Font = .caption.weight(.semibold)
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
                .foregroundStyle(SWTheme.textSecondary)

            VStack(spacing: 0) {
                content
            }
        }
        .fitnessCard()
    }
}

struct SettingsRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 36)
            .padding(.vertical, 6)
    }
}
