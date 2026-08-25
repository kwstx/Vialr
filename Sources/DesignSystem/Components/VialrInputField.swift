import SwiftUI

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
                .font(VialrTypography.subheadline)
                .foregroundColor(VialrColors.textSecondary)

            HStack(spacing: VialrSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(VialrColors.textTertiary)
                        .frame(width: 20)
                }

                TextField(placeholder, text: $value)
                    .font(isNumeric ? VialrTypography.monoDose : VialrTypography.body)
                    .foregroundColor(VialrColors.textPrimary)
                    #if os(iOS)
                    .keyboardType(isNumeric ? .decimalPad : .default)
                    #endif

                if let unit = unit {
                    Text(unit)
                        .font(VialrTypography.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(VialrColors.accentTeal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(VialrColors.accentTeal.opacity(0.12))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, VialrSpacing.md)
            .frame(height: 50)
            .background(VialrColors.cardSurfaceElevated)
            .cornerRadius(VialrSpacing.radiusMd)
            .overlay(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                    .stroke(VialrColors.glassBorder, lineWidth: 1)
            )
        }
    }
}

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
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VialrTypography.subheadline)
                    .foregroundColor(VialrColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: format, value))
                        .font(VialrTypography.metricMedium)
                        .foregroundColor(VialrColors.textPrimary)
                    Text(unit)
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.accentTeal)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    decrement()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(value > range.lowerBound ? VialrColors.textPrimary : VialrColors.textMuted)
                        .frame(width: 38, height: 38)
                        .background(VialrColors.cardSurfaceSelected)
                        .clipShape(Circle())
                }
                .disabled(value <= range.lowerBound)

                Button {
                    increment()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(value < range.upperBound ? VialrColors.textPrimary : VialrColors.textMuted)
                        .frame(width: 38, height: 38)
                        .background(VialrColors.accentTeal.opacity(0.2))
                        .clipShape(Circle())
                }
                .disabled(value >= range.upperBound)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func decrement() {
        let newVal = max(range.lowerBound, value - step)
        value = newVal
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func increment() {
        let newVal = min(range.upperBound, value + step)
        value = newVal
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
