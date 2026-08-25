import SwiftUI

public enum VialrIconType: String, Sendable {
    case syringe = "syringe.fill"
    case vial = "cross.vial.fill"
    case calendar = "calendar.badge.clock"
    case protocols = "list.clipboard.fill"
    case analytics = "chart.xyaxis.line"
    case health = "heart.text.square.fill"
    case inventory = "archivebox.fill"
    case biomarker = "drop.fill"
    case symptom = "waveform.path.ecg"
    case warning = "exclamationmark.triangle.fill"
    case checkmark = "checkmark.circle.fill"
    case clock = "clock.fill"
    case plus = "plus"
    case settings = "gearshape.fill"
    case report = "doc.text.fill"
    case siteRotation = "person.fill.viewfinder"
    case trendUp = "arrow.up.right"
    case trendDown = "arrow.down.right"
}

/// VialrIcon: Standardized icon renderer with optional circular soft backdrop.
public struct VialrIcon: View {
    public let type: VialrIconType
    public let tintColor: Color
    public let backgroundColor: Color?
    public let size: CGFloat

    public init(
        _ type: VialrIconType,
        tintColor: Color = VialrColors.accentVitality,
        backgroundColor: Color? = nil,
        size: CGFloat = 20
    ) {
        self.type = type
        self.tintColor = tintColor
        self.backgroundColor = backgroundColor
        self.size = size
    }

    public var body: some View {
        if let bg = backgroundColor {
            Image(systemName: type.rawValue)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(tintColor)
                .frame(width: size * 2.0, height: size * 2.0)
                .background(bg)
                .clipShape(Circle())
        } else {
            Image(systemName: type.rawValue)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(tintColor)
        }
    }
}
