import SwiftUI

/// VialrProgressBar: Minimalist linear progress indicator with Electric Emerald or semantic tones.
public struct VialrProgressBar: View {
    public let value: Double // 0.0 to 1.0
    public let height: CGFloat
    public let tintColor: Color
    public let trackColor: Color

    public init(
        value: Double,
        height: CGFloat = 6,
        tintColor: Color = VialrColors.accentVitality,
        trackColor: Color = VialrColors.cardSurfaceElevated
    ) {
        self.value = max(0.0, min(1.0, value))
        self.height = height
        self.tintColor = tintColor
        self.trackColor = trackColor
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(trackColor)
                    .frame(height: height)

                // Fill Bar
                Capsule()
                    .fill(tintColor)
                    .frame(width: max(height, geo.size.width * CGFloat(value)), height: height)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: value)
            }
        }
        .frame(height: height)
    }
}

/// VialrProgressRing: Sleek circular metric ring for adherence or protocol completion.
public struct VialrProgressRing: View {
    public let progress: Double // 0.0 to 1.0
    public let lineWidth: CGFloat
    public let tintColor: Color
    public let size: CGFloat

    public init(
        progress: Double,
        lineWidth: CGFloat = 8,
        tintColor: Color = VialrColors.accentVitality,
        size: CGFloat = 72
    ) {
        self.progress = max(0.0, min(1.0, progress))
        self.lineWidth = lineWidth
        self.tintColor = tintColor
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(VialrColors.cardSurfaceElevated, lineWidth: lineWidth)

            // Fill
            Circle()
                .trim(from: 0.0, to: CGFloat(progress))
                .stroke(
                    tintColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
        }
        .frame(width: size, height: size)
    }
}
