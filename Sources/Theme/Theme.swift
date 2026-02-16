import SwiftUI

enum SWTheme {
    static let accentGreen = Color.sw(0x74F380)
    static let accentBlue = Color.sw(0x4FA8FF)
    static let accentOrange = Color.sw(0xFF9F5A)
    static let accentPink = Color.sw(0xFF67B2)
    static let textSecondary = Color.white.opacity(0.68)

    static let appBackground = LinearGradient(
        colors: [Color.sw(0x0A0F1E), Color.sw(0x121A2F), Color.sw(0x080B16)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
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

private struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            SWTheme.appBackground
                .ignoresSafeArea()

            Circle()
                .fill(Color.sw(0x4FA8FF, alpha: 0.18))
                .frame(width: 320)
                .blur(radius: 60)
                .offset(x: 150, y: -260)

            Circle()
                .fill(Color.sw(0x74F380, alpha: 0.16))
                .frame(width: 260)
                .blur(radius: 54)
                .offset(x: -130, y: 310)

            content
        }
    }
}

private struct FitnessCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
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
