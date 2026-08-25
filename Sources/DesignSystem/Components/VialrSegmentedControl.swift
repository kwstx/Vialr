import SwiftUI

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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selection = item
                    }
                    #if os(iOS)
                    UISelectionFeedbackGenerator().selectionChanged()
                    #endif
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
                                            .stroke(VialrColors.subtleBorder, lineWidth: 1)
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous)
                .fill(VialrColors.cardSurface)
        )
    }
}
