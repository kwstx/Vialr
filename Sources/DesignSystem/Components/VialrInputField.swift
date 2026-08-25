import SwiftUI

/// VialrInputField: Clean, distraction-free input field with generous hit target and subtle focus border.
public struct VialrInputField: View {
    public let label: String
    public let placeholder: String
    @Binding public var value: String
    public var unit: String?
    public var isNumeric: Bool
    public var icon: String?

    public init(
        _ label: String,
        placeholder: String = "",
        value: Binding<String>,
        unit: String? = nil,
        isNumeric: Bool = false,
        icon: String? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self._value = value
        self.unit = unit
        self.isNumeric = isNumeric
        self.icon = icon
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .vialrEyebrow()

            HStack(spacing: VialrSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(VialrColors.textTertiary)
                        .font(.system(size: 15))
                        .frame(width: 20)
                }

                TextField(placeholder, text: $value)
                    .font(isNumeric ? VialrTypography.monoDose : VialrTypography.body)
                    .foregroundColor(VialrColors.textPrimary)
                    #if os(iOS)
                    .keyboardType(isNumeric ? .decimalPad : .default)
                    #endif

                if !value.isEmpty {
                    Button {
                        value = ""
                        VialrHaptics.lightImpact()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(VialrColors.textMuted)
                    }
                }

                if let unit = unit {
                    Text(unit)
                        .font(VialrTypography.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(VialrColors.accentVitality)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(VialrColors.accentVitality.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, VialrSpacing.md)
            .frame(height: 52)
            .background(VialrColors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous)
                    .stroke(VialrColors.glassBorder, lineWidth: 1)
            )
        }
    }
}

/// VialrStepper: Cal AI inspired tactile numeric adjuster with circular plus/minus steppers.
public struct VialrStepper: View {
    public let title: String
    @Binding public var value: Double
    public let step: Double
    public let range: ClosedRange<Double>
    public let unit: String
    public let format: String

    public init(
        title: String,
        value: Binding<Double>,
        step: Double = 50.0,
        range: ClosedRange<Double> = 0...5000,
        unit: String = "mcg",
        format: String = "%.0f"
    ) {
        self.title = title
        self._value = value
        self.step = step
        self.range = range
        self.unit = unit
        self.format = format
    }

    public var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .vialrEyebrow()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: format, value))
                        .font(VialrTypography.metricMedium)
                        .foregroundColor(VialrColors.textPrimary)
                    Text(unit)
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.accentVitality)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    decrement()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(value > range.lowerBound ? VialrColors.textPrimary : VialrColors.textMuted)
                        .frame(width: 40, height: 40)
                        .background(VialrColors.cardSurfaceElevated)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(VialrColors.glassBorder, lineWidth: 0.8)
                        )
                }
                .disabled(value <= range.lowerBound)

                Button {
                    increment()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(value < range.upperBound ? Color.black : VialrColors.textMuted)
                        .frame(width: 40, height: 40)
                        .background(value < range.upperBound ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                        .clipShape(Circle())
                }
                .disabled(value >= range.upperBound)
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    private func decrement() {
        let newVal = max(range.lowerBound, value - step)
        value = newVal
        VialrHaptics.lightImpact()
    }

    private func increment() {
        let newVal = min(range.upperBound, value + step)
        value = newVal
        VialrHaptics.lightImpact()
    }
}
