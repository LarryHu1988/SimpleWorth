import AuthenticationServices
import CloudKit
import Foundation

@MainActor
final class AppleAccountStore: ObservableObject {
    static let shared = AppleAccountStore()

    enum CredentialStatus: Equatable {
        case signedOut
        case checking
        case authorized
        case revoked
        case unavailable
    }

    enum AuthorizationOutcome {
        case signedIn
        case cancelled
        case failed(String)
    }

    @Published private(set) var userID: String?
    @Published private(set) var email: String?
    @Published private(set) var displayName: String?
    @Published private(set) var credentialStatus: CredentialStatus = .signedOut
    @Published private(set) var iCloudStatus: CKAccountStatus = .couldNotDetermine

    private let defaults: UserDefaults
    private let provider = ASAuthorizationAppleIDProvider()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadFromDefaults()

        Task {
            await refreshStatus()
        }
    }

    var isSignedIn: Bool {
        credentialStatus == .authorized && userID != nil
    }

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func handleAuthorizationResult(_ result: Result<ASAuthorization, Error>) async -> AuthorizationOutcome {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return .failed("未获取到 Apple 登录凭证。".appLocalized)
            }

            persist(credential: credential)
            await refreshStatus()
            return .signedIn

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return .cancelled
            }
            return .failed(L10n.string("apple.signInFailed", error.localizedDescription))
        }
    }

    func refreshStatus() async {
        if let userID, !userID.isEmpty {
            credentialStatus = .checking
            let credentialState = await credentialState(for: userID)
            switch credentialState {
            case .authorized:
                credentialStatus = .authorized
            case .revoked:
                clearStoredAccount()
                credentialStatus = .revoked
            case .notFound, .transferred:
                clearStoredAccount()
                credentialStatus = .signedOut
            @unknown default:
                credentialStatus = .unavailable
            }
        } else {
            credentialStatus = .signedOut
        }

        iCloudStatus = await fetchICloudStatus()
    }

    private func loadFromDefaults() {
        userID = defaults.string(forKey: SettingsKeys.appleAccountUserID)
        email = defaults.string(forKey: SettingsKeys.appleAccountEmail)
        displayName = defaults.string(forKey: SettingsKeys.appleAccountDisplayName)
    }

    private func persist(credential: ASAuthorizationAppleIDCredential) {
        let userID = credential.user
        let email = credential.email

        let formattedName: String? = {
            guard let fullName = credential.fullName else { return nil }
            let formatter = PersonNameComponentsFormatter()
            let value = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }()

        defaults.set(userID, forKey: SettingsKeys.appleAccountUserID)
        self.userID = userID

        if let email, !email.isEmpty {
            defaults.set(email, forKey: SettingsKeys.appleAccountEmail)
            self.email = email
        }

        if let formattedName, !formattedName.isEmpty {
            defaults.set(formattedName, forKey: SettingsKeys.appleAccountDisplayName)
            self.displayName = formattedName
        }
    }

    private func clearStoredAccount() {
        defaults.removeObject(forKey: SettingsKeys.appleAccountUserID)
        defaults.removeObject(forKey: SettingsKeys.appleAccountEmail)
        defaults.removeObject(forKey: SettingsKeys.appleAccountDisplayName)
        userID = nil
        email = nil
        displayName = nil
    }

    private func credentialState(for userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            provider.getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    private func fetchICloudStatus() async -> CKAccountStatus {
        let container = CKContainer.default()
        do {
            return try await container.accountStatus()
        } catch {
            return .couldNotDetermine
        }
    }
}
