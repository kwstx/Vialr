import SwiftUI

/// VialrSegmentedControl: Tactile, sliding pill segmented control inspired by Uber & Cal AI.
public struct VialrSegmentedControl<T: Hashable & CustomStringConvertible>: View {
    public let items: [T]
    @Binding public var selection: T
    @Namespace private var segmentAnimation

    public init(items: [T], selection: Binding<T>) {
        self.items = items
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection == item
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        selection = item
                    }
                    VialrHaptics.selection()
                } label: {
                    Text(item.description)
                        .font(VialrTypography.footnote)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(isSelected ? VialrColors.textPrimary : VialrColors.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: VialrSpacing.radiusSm, style: .continuous)
                                    .fill(VialrColors.cardSurfaceElevated)
                                    .matchedGeometryEffect(id: "SEGMENT_HIGHLIGHT", in: segmentAnimation)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                                            .stroke(VialrColors.subtleBorder, lineWidth: 0.8)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous)
                .fill(VialrColors.cardSurfaceSubtle)
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                        .stroke(VialrColors.glassBorder, lineWidth: 0.8)
                )
        )
    }
}
