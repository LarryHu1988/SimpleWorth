import UIKit
import SwiftUI

enum SWTheme {
    static let accentGreen = Color.dynamic(light: 0x62B889, dark: 0x74F380)
    static let accentBlue = Color.dynamic(light: 0x6A9FD2, dark: 0x4FA8FF)
    static let accentOrange = Color.dynamic(light: 0xD99364, dark: 0xFF9F5A)
    static let accentPink = Color.dynamic(light: 0xD686A8, dark: 0xFF67B2)
    static let textSecondary = Color.dynamic(light: 0x5F6F7E, dark: 0xBAC7DC)

    static let toolbarPillText = Color.dynamic(light: 0x445363, dark: 0xEEF4FF)
    static let toolbarPillFill = Color.dynamic(
        light: 0xDCE5EE,
        dark: 0xFFFFFF,
        lightAlpha: 0.86,
        darkAlpha: 0.14
    )
    static let toolbarPickerTextFont: Font = .caption.weight(.semibold)
    static let toolbarPickerChevronFont: Font = .caption2.weight(.semibold)
    static let toolbarControlSpacing: CGFloat = 6
    static let toolbarPickerHorizontalPadding: CGFloat = 8
    static let toolbarPickerVerticalPadding: CGFloat = 4

    static let appBackground = LinearGradient(
        colors: [
            Color.dynamic(light: 0x1C2736, dark: 0x0A0F1E),
            Color.dynamic(light: 0x253247, dark: 0x121A2F),
            Color.dynamic(light: 0x171F2C, dark: 0x080B16)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let blueOpacity = colorScheme == .light ? 0.11 : 0.18
        let greenOpacity = colorScheme == .light ? 0.10 : 0.16

        ZStack {
            SWTheme.appBackground
                .ignoresSafeArea()

            Circle()
                .fill(SWTheme.accentBlue.opacity(blueOpacity))
                .frame(width: 320)
                .blur(radius: 60)
                .offset(x: 150, y: -260)

            Circle()
                .fill(SWTheme.accentGreen.opacity(greenOpacity))
                .frame(width: 260)
                .blur(radius: 54)
                .offset(x: -130, y: 310)

            content
        }
    }
}

private struct FitnessCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let topColor = colorScheme == .light
            ? Color.sw(0xDCE5EF, alpha: 0.24)
            : Color.white.opacity(0.12)
        let bottomColor = colorScheme == .light
            ? Color.sw(0xA5B7CA, alpha: 0.08)
            : Color.white.opacity(0.04)
        let borderColor = colorScheme == .light
            ? Color.sw(0xBCC7D4, alpha: 0.36)
            : Color.white.opacity(0.18)

        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [topColor, bottomColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
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
