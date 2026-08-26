import SwiftUI
import Domain
import DesignSystem
import Data

/// Master coordinator managing the entire end-to-end Onboarding flow:
/// 1. Marketing / Product Pager (12 swipeable cards with local state persistence)
/// 2. Native Authentication (Sign in with Apple / Email Vault)
/// 3. Account & Local Database Initialization
/// 4. Minimal Post-Auth Setup (Units, Timezone, Notifications, HealthKit, Privacy)
/// 5. Transition to Main Application Dashboard
public struct OnboardingCoordinatorView: View {
    @State private var stage: OnboardingStage = .marketingPager
    @State private var pagerViewModel = OnboardingPagerViewModel()
    @State private var postAuthViewModel = PostAuthSetupViewModel()
    @State private var authenticatedUser: User?
    @State private var initializationError: String?

    public var onFinishedOnboarding: (User) -> Void
    private let accountInitializer: UserAccountInitializing

    public init(
        accountInitializer: UserAccountInitializing = UserAccountInitializer.shared,
        onFinishedOnboarding: @escaping (User) -> Void
    ) {
        self.accountInitializer = accountInitializer
        self.onFinishedOnboarding = onFinishedOnboarding
    }

    public var body: some View {
        ZStack {
            VialrColors.backgroundPrimary
                .ignoresSafeArea()

            switch stage {
            case .marketingPager:
                OnboardingContainerView(viewModel: pagerViewModel) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        stage = .authentication
                    }
                }
                .transition(.asymmetric(insertion: .identity, removal: .move(edge: .leading).combined(with: .opacity)))

            case .authentication:
                AuthenticationView { user in
                    self.authenticatedUser = user
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        stage = .initializingDatabase
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))

            case .initializingDatabase:
                databaseInitializationView
                    .transition(.opacity)
                    .task {
                        await runAccountAndDatabaseInitialization()
                    }

            case .postAuthSetup:
                if let user = authenticatedUser {
                    PostAuthSetupView(
                        viewModel: postAuthViewModel,
                        authenticatedUser: user
                    ) { finalUser in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            stage = .completed
                            onFinishedOnboarding(finalUser)
                        }
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                }

            case .completed:
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Initializing Database Screen
    private var databaseInitializationView: some View {
        VStack(spacing: VialrSpacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(VialrColors.accentVitality.opacity(0.12))
                    .frame(width: 100, height: 100)

                ProgressView()
                    .tint(VialrColors.accentVitality)
                    .scaleEffect(1.6)
            }

            VStack(spacing: 8) {
                Text("Initializing Protocol Vault")
                    .font(VialrTypography.largeHero)
                    .foregroundColor(VialrColors.textPrimary)

                Text("Creating local hardware-encrypted database, bootstrapping reference compounds, and securing cryptographic keys...")
                    .font(VialrTypography.subheadline)
                    .foregroundColor(VialrColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VialrSpacing.xl)
            }

            if let err = initializationError {
                Text(err)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.accentRose)
                    .padding(.top, VialrSpacing.xs)
            }

            Spacer()
        }
    }

    // MARK: - Database & Account Initialization Worker
    private func runAccountAndDatabaseInitialization() async {
        guard let user = authenticatedUser else { return }
        do {
            let initialized = try await accountInitializer.initializeAccountAndDatabase(for: user)
            await MainActor.run {
                self.authenticatedUser = initialized
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    self.stage = .postAuthSetup
                }
            }
        } catch {
            await MainActor.run {
                self.initializationError = "Failed to initialize database: \(error.localizedDescription)"
                // Fallback progression to post-auth setup
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    self.stage = .postAuthSetup
                }
            }
        }
    }
}
