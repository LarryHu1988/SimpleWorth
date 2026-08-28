import UIKit
import SwiftUI

enum ThemeMode: String, CaseIterable, Identifiable {
    case system
    case daylight
    case moonlight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            "系统".appLocalized
        case .daylight:
            "日光".appLocalized
        case .moonlight:
            "月光".appLocalized
        }
    }

    var symbol: String {
        switch self {
        case .system:
            "circle.lefthalf.filled"
        case .daylight:
            "sun.max.fill"
        case .moonlight:
            "moon.stars.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .daylight:
            .light
        case .moonlight:
            .dark
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system:
            .unspecified
        case .daylight:
            .light
        case .moonlight:
            .dark
        }
    }

    static func resolved(from defaults: UserDefaults = .standard) -> ThemeMode {
        if
            let rawValue = defaults.string(forKey: SettingsKeys.themeMode),
            let mode = ThemeMode(rawValue: rawValue)
        {
            return mode
        }

        if defaults.object(forKey: SettingsKeys.legacyDarkModeEnabled) != nil {
            return defaults.bool(forKey: SettingsKeys.legacyDarkModeEnabled) ? .moonlight : .daylight
        }

        return .system
    }
}

enum AppAppearanceController {
    @MainActor
    static func apply(themeMode: ThemeMode) {
        let interfaceStyle = themeMode.interfaceStyle
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { window in
                window.overrideUserInterfaceStyle = interfaceStyle
            }
    }
}

enum SWTheme {
    static let accentGreen = Color.dynamic(light: 0x62B889, dark: 0x74F380)
    static let accentBlue = Color.dynamic(light: 0x6A9FD2, dark: 0x4FA8FF)
    static let accentOrange = Color.dynamic(light: 0xD99364, dark: 0xFF9F5A)
    static let accentPink = Color.dynamic(light: 0xD686A8, dark: 0xFF67B2)
    static let primaryText = Color.dynamic(light: 0x122338, dark: 0xFFFFFF)
    static let textSecondary = Color.dynamic(light: 0x5F6F7E, dark: 0xBAC7DC)

    static let toolbarPillText = Color.dynamic(light: 0x445363, dark: 0xEEF4FF)
    static let toolbarPillFill = Color.dynamic(
        light: 0xFFFFFF,
        dark: 0xFFFFFF,
        lightAlpha: 0.56,
        darkAlpha: 0.14
    )
    static let toolbarPickerTextFont: Font = .caption.weight(.semibold)
    static let toolbarPickerChevronFont: Font = .caption2.weight(.semibold)
    static let toolbarControlSpacing: CGFloat = 6
    static let toolbarPickerHorizontalPadding: CGFloat = 8
    static let toolbarPickerVerticalPadding: CGFloat = 4

    static let appBackground = LinearGradient(
        colors: [
            Color.dynamic(light: 0xF8FBFF, dark: 0x0A0F1E),
            Color.dynamic(light: 0xEEF5FF, dark: 0x121A2F),
            Color.dynamic(light: 0xE3ECFB, dark: 0x080B16)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum SWMotion {
    static let quick = Animation.spring(response: 0.22, dampingFraction: 0.86, blendDuration: 0.04)
    static let fluid = Animation.spring(response: 0.46, dampingFraction: 0.68, blendDuration: 0.07)
    static let settle = Animation.spring(response: 0.30, dampingFraction: 0.82, blendDuration: 0.05)
}

extension Color {
    static func dynamic(
        light: UInt,
        dark: UInt,
        lightAlpha: Double = 1.0,
        darkAlpha: Double = 1.0
    ) -> Color {
        Color(
            uiColor: UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor.sw(dark, alpha: darkAlpha)
                }
                return UIColor.sw(light, alpha: lightAlpha)
            }
        )
    }

    static func sw(_ hex: UInt, alpha: Double = 1.0) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

extension UIColor {
    static func sw(_ hex: UInt, alpha: Double = 1.0) -> UIColor {
        UIColor(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}

private struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            FlowingGlassBackground()
            content
        }
    }
}

private struct FlowingGlassBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            SWTheme.appBackground
                .ignoresSafeArea()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            SWTheme.accentBlue.opacity(colorScheme == .light ? 0.10 : 0.12),
                            Color.clear,
                            SWTheme.accentGreen.opacity(colorScheme == .light ? 0.08 : 0.09)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .ignoresSafeArea()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            SWTheme.accentOrange.opacity(colorScheme == .light ? 0.055 : 0.065),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .ignoresSafeArea()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .light ? 0.18 : 0.045),
                            Color.white.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .ignoresSafeArea()
        }
    }
}

struct SWResponsiveButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var pressedScale: CGFloat = 0.965

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(reduceMotion ? nil : SWMotion.quick, value: configuration.isPressed)
    }
}

private struct FitnessCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let topColor = colorScheme == .light
            ? Color.sw(0x8FA9C6, alpha: 0.34)
            : Color.white.opacity(0.12)
        let bottomColor = colorScheme == .light
            ? Color.sw(0x5C7391, alpha: 0.18)
            : Color.white.opacity(0.04)
        let borderColor = colorScheme == .light
            ? Color.white.opacity(0.54)
            : Color.white.opacity(0.18)
        let shadowColor = colorScheme == .light
            ? Color.sw(0x95B4D5, alpha: 0.12)
            : Color.black.opacity(0.22)
        let sheenColor = colorScheme == .light
            ? Color.white.opacity(0.28)
            : Color.white.opacity(0.08)

        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                topColor,
                                bottomColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .light ? 0.04 : 0.01))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [sheenColor, .clear, Color.white.opacity(0.01)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(color: shadowColor, radius: 12, x: 0, y: 8)
            )
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }

    func fitnessCard() -> some View {
        modifier(FitnessCardModifier())
    }
}
