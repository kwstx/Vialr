import SwiftUI
import Observation
import Domain
import Feature
import DesignSystem

public enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case dashboard = "Today"
    case protocols = "Protocols"
    case inventory = "Inventory"
    case analytics = "Analytics"
    case settings = "Settings"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .dashboard: return "calendar.badge.clock"
        case .protocols: return "list.bullet.rectangle.portrait.fill"
        case .inventory: return "cylinder.split.1x2.fill"
        case .analytics: return "chart.xyaxis.line"
        case .settings: return "gearshape.fill"
        }
    }
}

public enum ActiveSheet: Identifiable {
    case quickLog(DoseLog?)
    case reconstitution
    case siteRotation
    case createProtocol
    case protocolDetail(ProtocolModel)
    case protocolComparison
    case addVial
    case logSymptoms
    case logBiomarker
    case clinicianReport

    public var id: String {
        switch self {
        case .quickLog(let d): return "quickLog_\(d?.id.uuidString ?? "new")"
        case .reconstitution: return "reconstitution"
        case .siteRotation: return "siteRotation"
        case .createProtocol: return "createProtocol"
        case .protocolDetail(let p): return "protocolDetail_\(p.id.uuidString)"
        case .protocolComparison: return "protocolComparison"
        case .addVial: return "addVial"
        case .logSymptoms: return "logSymptoms"
        case .logBiomarker: return "logBiomarker"
        case .clinicianReport: return "clinicianReport"
        }
    }
}

@Observable
public final class AppCoordinator: @unchecked Sendable {
    public var selectedTab: AppTab = .dashboard
    public var activeSheet: ActiveSheet?
    public var currentToast: ToastMessage?
    public var hasCompletedOnboarding: Bool = false

    public init() {}

    public func presentSheet(_ sheet: ActiveSheet) {
        self.activeSheet = sheet
    }

    public func dismissSheet() {
        self.activeSheet = nil
    }

    public func showToast(title: String, message: String? = nil, type: ToastType = .success) {
        let toast = ToastMessage(title: title, message: message, type: type)
        self.currentToast = toast
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.currentToast?.id == toast.id {
                withAnimation {
                    self.currentToast = nil
                }
            }
        }
    }
}
