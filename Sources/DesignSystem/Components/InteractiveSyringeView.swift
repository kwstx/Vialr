import SwiftUI

public enum SyringeSize: String, CaseIterable, Identifiable, Sendable {
    case point3ml = "0.3 mL (30 Units)"
    case point5ml = "0.5 mL (50 Units)"
    case oneMl = "1.0 mL (100 Units)"

    public var id: String { rawValue }

    public var maxUnits: Double {
        switch self {
        case .point3ml: return 30.0
        case .point5ml: return 50.0
        case .oneMl: return 100.0
        }
    }

    public var maxVolumeMl: Double {
        switch self {
        case .point3ml: return 0.3
        case .point5ml: return 0.5
        case .oneMl: return 1.0
        }
    }
}

/// InteractiveSyringeView: Precision-engineered syringe visualization designed
/// with Uber's stark clarity and Cal AI's refined vitality signals.
public struct InteractiveSyringeView: View {
    public let units: Double
    public let syringeSize: SyringeSize
    public let doseDescription: String
    
    public init(units: Double, syringeSize: SyringeSize = .oneMl, doseDescription: String = "") {
        self.units = units
        self.syringeSize = syringeSize
        self.doseDescription = doseDescription
    }

    public var body: some View {
        VStack(spacing: VialrSpacing.md) {
            // Header with Eyebrow and Large Numerical Readout
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DRAW MARKING (U-100)")
                        .vialrEyebrow()
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", units))
                            .font(VialrTypography.metricLarge)
                            .foregroundColor(VialrColors.textPrimary)
                        Text("Units")
                            .font(VialrTypography.title3)
                            .foregroundColor(VialrColors.accentVitality)
                    }
                }
                
                Spacer()
                
                if !doseDescription.isEmpty {
                    Text(doseDescription)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VialrColors.cardSurfaceElevated)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(VialrColors.glassBorder, lineWidth: 0.8)
                        )
                }
            }

            // Syringe Canvas
            GeometryReader { geo in
                let width = geo.size.width
                let height: CGFloat = 64
                let maxUnits = syringeSize.maxUnits
                let fillFraction = max(0.0, min(1.0, units / maxUnits))
                let barrelWidth = width - 42 // room for needle tip & plunger

                ZStack(alignment: .leading) {
                    // Needle Tip on the left
                    HStack(spacing: 0) {
                        // Needle metal
                        Rectangle()
                            .fill(LinearGradient(colors: [Color.gray, Color.white, Color.gray], startPoint: .top, endPoint: .bottom))
                            .frame(width: 14, height: 2)
                        
                        // Hub (plastic connection)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(VialrColors.accentVitality.opacity(0.8))
                            .frame(width: 8, height: 16)
                    }
                    .offset(x: 0, y: 0)

                    // Syringe Barrel (Outer clear tube)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.04))
                            .frame(width: barrelWidth, height: 38)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(VialrColors.glassBorder, lineWidth: 1.2)
                            )

                        // Fluid Fill (Vibrant Cal AI Vitality Emerald)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(VialrColors.syringeFluidGradient)
                            .frame(width: max(0, (barrelWidth - 6) * fillFraction), height: 32)
                            .padding(.leading, 3)
                            .animation(.spring(response: 0.4, dampingFraction: 0.72), value: units)

                        // Plunger Seal (Rubber stopper)
                        let plungerPos = max(0, (barrelWidth - 6) * fillFraction)
                        Rectangle()
                            .fill(Color(hex: "2D3748"))
                            .frame(width: 8, height: 34)
                            .cornerRadius(2)
                            .offset(x: 3 + plungerPos)
                            .animation(.spring(response: 0.4, dampingFraction: 0.72), value: units)

                        // Plunger Rod extending out
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 28, height: 8)
                            .offset(x: 3 + plungerPos + 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.72), value: units)

                        // Tick Marks Layer
                        HStack(spacing: 0) {
                            let totalTicks = Int(syringeSize.maxUnits / 5)
                            ForEach(0...totalTicks, id: \.self) { tickIndex in
                                let isMajor = tickIndex % 2 == 0
                                VStack {
                                    Rectangle()
                                        .fill(Color.white.opacity(isMajor ? 0.65 : 0.25))
                                        .frame(width: 1, height: isMajor ? 10 : 5)
                                    Spacer()
                                    Rectangle()
                                        .fill(Color.white.opacity(isMajor ? 0.65 : 0.25))
                                        .frame(width: 1, height: isMajor ? 10 : 5)
                                }
                                .frame(height: 38)
                                if tickIndex < totalTicks {
                                    Spacer()
                                }
                            }
                        }
                        .frame(width: barrelWidth - 10, height: 38)
                        .padding(.leading, 5)
                    }
                    .offset(x: 22)
                }
                .frame(width: width, height: height)
            }
            .frame(height: 64)

            // Syringe Markings Legend
            HStack {
                Text("0")
                    .font(VialrTypography.monoSub)
                    .foregroundColor(VialrColors.textTertiary)
                    .padding(.leading, 24)
                Spacer()
                Text("\(Int(syringeSize.maxUnits / 2))")
                    .font(VialrTypography.monoSub)
                    .foregroundColor(VialrColors.textTertiary)
                Spacer()
                Text("\(Int(syringeSize.maxUnits)) Units")
                    .font(VialrTypography.monoSub)
                    .foregroundColor(VialrColors.textTertiary)
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }
}
