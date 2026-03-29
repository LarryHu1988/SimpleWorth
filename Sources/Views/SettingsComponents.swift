import SwiftUI

enum SettingsLayout {
    static let sectionSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 12
    static let rowIconWidth: CGFloat = 22
    static let rowVerticalPadding: CGFloat = 8
    static let titleFont: Font = .subheadline.weight(.medium)
    static let sectionHeaderFont: Font = .caption.weight(.semibold)
    static let tapCancellationDistance: CGFloat = 10
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
