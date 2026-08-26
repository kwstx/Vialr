import SwiftUI
import DesignSystem

/// Progress indicator component for onboarding slides with animated pill segments and step counter.
public struct OnboardingProgressIndicator: View {
    public let currentIndex: Int
    public let totalCount: Int

    public init(currentIndex: Int, totalCount: Int) {
        self.currentIndex = currentIndex
        self.totalCount = totalCount
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalCount, id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                    .frame(
                        width: index == currentIndex ? 24 : 6,
                        height: 5
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding step \(currentIndex + 1) of \(totalCount)")
        .accessibilityValue("\(Int(Double(currentIndex + 1) / Double(totalCount) * 100)) percent")
    }
}
