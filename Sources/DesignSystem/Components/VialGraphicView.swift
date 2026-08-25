import SwiftUI

/// VialGraphicView: Clean, modern 2D vial visualization with reconstitution state.
public struct VialGraphicView: View {
    public let compoundName: String
    public let concentrationText: String
    public let fillPercentage: Double // 0.0 to 1.0
    public let isReconstituted: Bool
    public let badgeColor: Color

    public init(
        compoundName: String,
        concentrationText: String,
        fillPercentage: Double = 0.75,
        isReconstituted: Bool = true,
        badgeColor: Color = VialrColors.accentVitality
    ) {
        self.compoundName = compoundName
        self.concentrationText = concentrationText
        self.fillPercentage = fillPercentage
        self.isReconstituted = isReconstituted
        self.badgeColor = badgeColor
    }

    public var body: some View {
        HStack(spacing: VialrSpacing.md) {
            // Vial 2D Illustration
            ZStack(alignment: .bottom) {
                // Outer Vial Glass Body
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 42, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(VialrColors.glassBorder, lineWidth: 1.2)
                    )

                // Liquid fill inside glass
                if isReconstituted {
                    let clampedFill = max(0.05, min(1.0, fillPercentage))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [badgeColor.opacity(0.65), badgeColor.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 36, height: 56 * clampedFill)
                        .padding(.bottom, 3)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: fillPercentage)
                } else {
                    // Lyophilized powder puck at the bottom
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 36, height: 14)
                        .padding(.bottom, 3)
                }

                // Vial Aluminum Crimp Cap & Rubber Stopper
                VStack(spacing: 1) {
                    // Rubber septa circle
                    Capsule()
                        .fill(Color(hex: "334155"))
                        .frame(width: 14, height: 4)

                    // Aluminum collar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [Color.gray.opacity(0.8), Color.white.opacity(0.9), Color.gray.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 22, height: 7)
                }
                .offset(y: -62)
            }
            .frame(width: 44, height: 76)

            // Info Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(compoundName)
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                    Spacer()
                    MetricBadge(isReconstituted ? .success("\(Int(fillPercentage * 100))% Vol") : .neutral("Dry Powder"), showDot: true)
                }

                Text(concentrationText)
                    .font(VialrTypography.monoSub)
                    .foregroundColor(VialrColors.accentVitality)

                Text(isReconstituted ? "Reconstituted Solution" : "Lyophilized Powder")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }
}
