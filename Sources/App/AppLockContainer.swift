import LocalAuthentication
import SwiftUI

struct AppLockContainer<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("settings.passcodeLockEnabled") private var passcodeLockEnabled = false

    @State private var isUnlocked = false
    @State private var isAuthenticating = false

    @ViewBuilder var content: Content

    private var shouldShowLock: Bool {
        passcodeLockEnabled && !isUnlocked
    }

    var body: some View {
        ZStack {
            content
                .blur(radius: shouldShowLock ? 8 : 0)
                .disabled(shouldShowLock)

            if shouldShowLock {
                lockOverlay
            }
        }
        .onAppear {
            if passcodeLockEnabled {
                isUnlocked = false
                authenticateIfNeeded()
            } else {
                isUnlocked = true
            }
        }
        .onChange(of: passcodeLockEnabled) { _, enabled in
            if enabled {
                isUnlocked = false
                authenticateIfNeeded()
            } else {
                isUnlocked = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard passcodeLockEnabled else { return }
            if phase == .background || phase == .inactive {
                isUnlocked = false
            }
            if phase == .active {
                authenticateIfNeeded()
            }
        }
    }

    private var lockOverlay: some View {
        ZStack {
            SWTheme.appBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(SWTheme.accentBlue)

                Text("已开启密码锁")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text("请验证身份以继续使用简值")
                    .font(.footnote)
                    .foregroundStyle(SWTheme.textSecondary)

                Button {
                    authenticateIfNeeded(force: true)
                } label: {
                    Text("立即解锁")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(SWTheme.accentGreen)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .fitnessCard()
            .padding(.horizontal, 28)
        }
    }

    private func authenticateIfNeeded(force: Bool = false) {
        guard passcodeLockEnabled else {
            isUnlocked = true
            return
        }
        guard !isUnlocked || force else { return }
        guard !isAuthenticating else { return }

        isAuthenticating = true
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            DispatchQueue.main.async {
                isAuthenticating = false
                isUnlocked = false
            }
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "解锁简值"
        ) { success, _ in
            DispatchQueue.main.async {
                isAuthenticating = false
                isUnlocked = success
            }
        }
    }
}
