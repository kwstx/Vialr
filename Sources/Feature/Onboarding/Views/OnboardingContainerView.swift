import SwiftUI
import DesignSystem

/// Horizontally paging SwiftUI container for the 10-12 product marketing onboarding cards.
/// Supports interactive swipe gestures, persistent local page tracking, and top back/skip controls.
public struct OnboardingContainerView: View {
    @Bindable public var viewModel: OnboardingPagerViewModel
    public var onTransitionToAuth: () -> Void

    public init(
        viewModel: OnboardingPagerViewModel,
        onTransitionToAuth: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onTransitionToAuth = onTransitionToAuth
    }

    public var body: some View {
        ZStack {
            // True OLED pitch black background
            VialrColors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Navigation Bar (Back & Skip)
                topNavBar
                    .padding(.horizontal, VialrSpacing.lg)
                    .padding(.top, VialrSpacing.xs)

                // Horizontally Paging SwiftUI TabView
                TabView(selection: $viewModel.currentPageIndex) {
                    ForEach(viewModel.pages) { page in
                        OnboardingPageView(
                            item: page,
                            currentIndex: viewModel.currentPageIndex,
                            totalPages: viewModel.totalPages,
                            onContinue: {
                                viewModel.nextPage(onReachedEnd: onTransitionToAuth)
                            }
                        )
                        .tag(page.stepIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: viewModel.currentPageIndex)
            }
        }
    }

    // MARK: - Top Navigation Bar
    private var topNavBar: some View {
        HStack {
            // Back Button (hidden on first page)
            if viewModel.currentPageIndex > 0 {
                Button {
                    viewModel.previousPage()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(VialrTypography.subheadline)
                    }
                    .foregroundColor(VialrColors.textSecondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(VialrColors.cardSurfaceElevated)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous page")
            } else {
                Spacer().frame(width: 60)
            }

            Spacer()

            // Skip to Auth Button (hidden on last page)
            if !viewModel.isLastPage {
                Button {
                    viewModel.skipToAuth(onTransition: onTransitionToAuth)
                } label: {
                    Text("Skip")
                        .font(VialrTypography.subheadline)
                        .foregroundColor(VialrColors.textTertiary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip onboarding and create account")
            } else {
                Spacer().frame(width: 60)
            }
        }
        .frame(height: 44)
    }
}
