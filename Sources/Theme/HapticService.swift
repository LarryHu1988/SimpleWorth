import UIKit

@MainActor
enum HapticService {
    static let enabledKey = "settings.hapticsEnabled"
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let softImpactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidImpactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    private static var isEnabled: Bool {
        (UserDefaults.standard.object(forKey: enabledKey) as? Bool) ?? true
    }

    static func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isEnabled else { return }
        let generator = impactGenerator(for: style)
        generator.impactOccurred()
        generator.prepare()
    }

    static func success() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    static func warning() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    private static func impactGenerator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        switch style {
        case .light:
            lightImpactGenerator
        case .medium:
            mediumImpactGenerator
        case .heavy:
            heavyImpactGenerator
        case .soft:
            softImpactGenerator
        case .rigid:
            rigidImpactGenerator
        @unknown default:
            lightImpactGenerator
        }
    }
}
