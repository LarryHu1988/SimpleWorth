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
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, SettingsLayout.dividerLeadingInset)
            .padding(.vertical, SettingsLayout.dividerVerticalPadding)
    }
}

struct SettingsPressableButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label

    @GestureState private var isPressing = false
    @State private var shouldSuppressTap = false

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button {
            guard !shouldSuppressTap else {
                shouldSuppressTap = false
                return
            }
            action()
        } label: {
            label
                .opacity(isPressing && !shouldSuppressTap ? 0.82 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressing) { value, state, _ in
                    if !hasExceededTapTolerance(for: value.translation) {
                        state = true
                    }
                }
                .onChanged { value in
                    if hasExceededTapTolerance(for: value.translation) {
                        shouldSuppressTap = true
                    }
                }
                .onEnded { _ in
                    guard shouldSuppressTap else { return }
                    DispatchQueue.main.async {
                        shouldSuppressTap = false
                    }
                }
        )
    }

    private func hasExceededTapTolerance(for translation: CGSize) -> Bool {
        max(abs(translation.width), abs(translation.height)) > SettingsLayout.tapCancellationDistance
    }
}
