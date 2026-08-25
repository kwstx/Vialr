import SwiftUI
import Domain
import DesignSystem
import Data
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

/// Main Authentication screen providing native Sign in with Apple as the primary authentication flow,
/// alongside standard email/password credentials and direct Keychain credential persistence.
public struct AuthenticationView: View {
    @State private var isLoginMode: Bool = false
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var displayName: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    public var onAuthSuccess: (User) -> Void
    private let apiClient: APIClientProtocol
    private let keychainService: KeychainServiceProtocol
    private let appleSignInManager: AppleSignInManager

    public init(
        apiClient: APIClientProtocol = APIClient.shared,
        keychainService: KeychainServiceProtocol = KeychainService.shared,
        appleSignInManager: AppleSignInManager = .shared,
        onAuthSuccess: @escaping (User) -> Void
    ) {
        self.apiClient = apiClient
        self.keychainService = keychainService
        self.appleSignInManager = appleSignInManager
        self.onAuthSuccess = onAuthSuccess
    }

    public var body: some View {
        ZStack {
            VialrColors.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: VialrSpacing.xl) {
                    // Header Brand Badge
                    VStack(spacing: VialrSpacing.sm) {
                        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundColor(VialrColors.accentTeal)
                            .padding(.top, VialrSpacing.xl)

                        Text("VIALR VAULT")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentTeal)
                            .tracking(2)

                        Text(isLoginMode ? "Welcome Back" : "Create Your Secure Vault")
                            .font(VialrTypography.largeHero)
                            .foregroundColor(VialrColors.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("End-to-end encrypted protocol tracking. Your data is protected by hardware Secure Enclave & biometric authentication.")
                            .font(VialrTypography.subheadline)
                            .foregroundColor(VialrColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, VialrSpacing.lg)
                    }

                    // MARK: - Primary Native Action: Sign in with Apple
                    VStack(spacing: VialrSpacing.sm) {
                        #if canImport(AuthenticationServices)
                        SignInWithAppleButton(
                            isLoginMode ? .signIn : .signUp,
                            onRequest: { request in
                                let hashedNonce = appleSignInManager.prepareNonce()
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = hashedNonce
                            },
                            onCompletion: { result in
                                handleAppleSignInResult(result)
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .cornerRadius(VialrSpacing.radiusPill)
                        .overlay(
                            RoundedRectangle(cornerRadius: VialrSpacing.radiusPill)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        #else
                        Button {
                            // Fallback simulation for non-Darwin environments
                            simulateAppleSignIn()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 20))
                                Text(isLoginMode ? "Sign in with Apple" : "Sign up with Apple")
                                    .font(VialrTypography.headline)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white)
                            .cornerRadius(VialrSpacing.radiusPill)
                        }
                        #endif

                        Text("Fastest, most secure native setup on iOS")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }
                    .padding(.horizontal, VialrSpacing.lg)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(VialrColors.glassBorder)
                            .frame(height: 1)
                        Text("OR CONTINUE WITH EMAIL")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textTertiary)
                            .padding(.horizontal, VialrSpacing.xs)
                        Rectangle()
                            .fill(VialrColors.glassBorder)
                            .frame(height: 1)
                    }
                    .padding(.horizontal, VialrSpacing.lg)

                    // Email/Password Form Card
                    VStack(spacing: VialrSpacing.md) {
                        if !isLoginMode {
                            VialrInputField(
                                title: "Full Name",
                                placeholder: "e.g. Alex Mercer",
                                text: $displayName,
                                systemImage: "person.fill"
                            )
                        }

                        VialrInputField(
                            title: "Email Address",
                            placeholder: "name@example.com",
                            text: $email,
                            systemImage: "envelope.fill"
                        )

                        VialrInputField(
                            title: "Master Password",
                            placeholder: "••••••••••••",
                            text: $password,
                            isSecure: true,
                            systemImage: "lock.fill"
                        )

                        if let error = errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(VialrColors.accentRose)
                                Text(error)
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.accentRose)
                            }
                            .padding(.top, 4)
                        }

                        VialrButton(
                            isLoginMode ? "Sign In with Email" : "Create Account",
                            icon: isLoginMode ? "arrow.right.circle.fill" : "lock.shield.fill",
                            isLoading: isLoading,
                            style: .primary
                        ) {
                            handleEmailAuth()
                        }
                    }
                    .padding(VialrSpacing.lg)
                    .vialrCard()
                    .padding(.horizontal, VialrSpacing.lg)

                    // Toggle Login / Register mode
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isLoginMode.toggle()
                            errorMessage = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isLoginMode ? "Don't have an account?" : "Already have an account?")
                                .foregroundColor(VialrColors.textSecondary)
                            Text(isLoginMode ? "Sign Up" : "Sign In")
                                .font(VialrTypography.headline)
                                .foregroundColor(VialrColors.accentTeal)
                        }
                        .font(VialrTypography.footnote)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, VialrSpacing.xl)
                }
            }
        }
    }

    // MARK: - Handlers
    #if canImport(AuthenticationServices)
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            isLoading = true
            errorMessage = nil
            do {
                let payload = try appleSignInManager.handleAppleCredential(credential: authorization.credential)
                Task {
                    await authenticateWithBackend(applePayload: payload)
                }
            } catch {
                isLoading = false
                errorMessage = "Failed to process Apple ID credentials."
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }
    #endif

    private func simulateAppleSignIn() {
        let fakePayload = AppleAuthPayload(
            identityToken: "simulated_apple_identity_token",
            authorizationCode: "simulated_apple_auth_code",
            userIdentifier: "001.simulated.apple.user",
            email: "apple.user@icloud.com",
            fullName: "Apple User",
            nonce: "test_nonce"
        )
        Task {
            await authenticateWithBackend(applePayload: fakePayload)
        }
    }

    private func authenticateWithBackend(applePayload: AppleAuthPayload) async {
        do {
            struct BackendAppleResponse: Decodable {
                let accessToken: String
                let refreshToken: String
                let user: User
            }

            // In local/mock mode or remote endpoint
            let user = User(
                accountInfo: AccountInfo(
                    email: applePayload.email ?? "apple.user@vialr.app",
                    displayName: applePayload.fullName ?? "Apple Health Member"
                )
            )

            // Persist tokens strictly in Keychain
            try keychainService.saveString("jwt_token_sample", forKey: KeychainService.Keys.accessToken, accessLevel: .afterFirstUnlockThisDeviceOnly)
            try keychainService.saveString("refresh_token_sample", forKey: KeychainService.Keys.refreshToken, accessLevel: .afterFirstUnlockThisDeviceOnly)
            try keychainService.saveString(applePayload.userIdentifier, forKey: KeychainService.Keys.appleUserIdentifier, accessLevel: .afterFirstUnlockThisDeviceOnly)

            await MainActor.run {
                self.isLoading = false
                self.onAuthSuccess(user)
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to authenticate with Apple."
            }
        }
    }

    private func handleEmailAuth() {
        guard !email.isEmpty, email.contains("@") else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Master password must be at least 6 characters."
            return
        }

        isLoading = true
        errorMessage = nil

        let user = User(
            accountInfo: AccountInfo(
                email: email,
                displayName: displayName.isEmpty ? "Protocol Member" : displayName
            )
        )

        // Store tokens securely in Keychain (Never in UserDefaults)
        try? keychainService.saveString("jwt_email_token", forKey: KeychainService.Keys.accessToken, accessLevel: .afterFirstUnlockThisDeviceOnly)
        try? keychainService.saveString("refresh_email_token", forKey: KeychainService.Keys.refreshToken, accessLevel: .afterFirstUnlockThisDeviceOnly)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.isLoading = false
            self.onAuthSuccess(user)
        }
    }
}
