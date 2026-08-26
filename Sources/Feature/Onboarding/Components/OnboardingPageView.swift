import SwiftUI
import DesignSystem

/// Standardized reusable onboarding page structure conforming to the design spec:
/// 1. Hero Visual (Illustration & Live Badges)
/// 2. Headline (Bold large hero typography)
/// 3. Short Explanation (Informative product copy)
/// 4. Progress Indicator (Step pills)
/// 5. Continue Button (Tactile primary CTA)
public struct OnboardingPageView: View {
    public let item: OnboardingPageItem
    public let currentIndex: Int
    public let totalPages: Int
    public let onContinue: () -> Void

    public init(
        item: OnboardingPageItem,
        currentIndex: Int,
        totalPages: Int,
        onContinue: @escaping () -> Void
    ) {
        self.item = item
        self.currentIndex = currentIndex
        self.totalPages = totalPages
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Upper Content Area (Hero + Headline + Explanation)
            ScrollView(showsIndicators: false) {
                VStack(spacing: VialrSpacing.xl) {
                    // Tag
                    Text(item.tag)
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentVitality)
                        .tracking(1.5)
                        .padding(.top, VialrSpacing.sm)

                    // 1. Hero Visual
                    OnboardingHeroVisual(item: item)
                        .padding(.horizontal, VialrSpacing.md)

                    // 2. Headline & 3. Short Explanation
                    VStack(spacing: VialrSpacing.sm) {
                        Text(item.headline)
                            .font(VialrTypography.largeHero)
                            .foregroundColor(VialrColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(item.explanation)
                            .font(VialrTypography.body)
                            .foregroundColor(VialrColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, VialrSpacing.md)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, VialrSpacing.lg)
                }
                .padding(.bottom, VialrSpacing.xl)
            }

            Spacer(minLength: VialrSpacing.md)

            // Bottom Action Area (4. Progress Indicator + 5. Continue Button)
            VStack(spacing: VialrSpacing.lg) {
                // 4. Progress Indicator
                OnboardingProgressIndicator(
                    currentIndex: currentIndex,
                    totalCount: totalPages
                )

                // 5. Continue Button
                VialrButton(
                    currentIndex == totalPages - 1 ? "Create Secure Vault" : "Continue",
                    icon: currentIndex == totalPages - 1 ? "lock.shield.fill" : "arrow.right",
                    style: .vitality,
                    size: .standard
                ) {
                    onContinue()
                }
            }
            .padding(.horizontal, VialrSpacing.xl)
            .padding(.bottom, VialrSpacing.xl)
        }
    }
}
