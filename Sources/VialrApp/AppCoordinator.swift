import SwiftUI
import Observation
import Domain
import Feature
import DesignSystem
import Data

public enum ActiveSheet: Identifiable {
    case quickLog(DoseLog?)
    case reconstitution
    case siteRotation
    case createProtocol
    case protocolDetail(ProtocolModel)
    case protocolReplay(ProtocolModel)
    case protocolComparison
    case addVial
    case logSymptoms
    case logBiomarker
    case clinicianReport
    case bloodworkHub
    case manualBloodworkEntry
    case uploadLabReport
    case confirmLabReportCandidate(ExtractedLabReportCandidate)
    case labPanelDetail(LabPanel)
    case timeline
    case settings
    case analytics

    public var id: String {
        switch self {
        case .quickLog(let d): return "quickLog_\(d?.id.uuidString ?? "new")"
        case .reconstitution: return "reconstitution"
        case .siteRotation: return "siteRotation"
        case .createProtocol: return "createProtocol"
        case .protocolDetail(let p): return "protocolDetail_\(p.id.uuidString)"
        case .protocolReplay(let p): return "protocolReplay_\(p.id.uuidString)"
        case .protocolComparison: return "protocolComparison"
        case .addVial: return "addVial"
        case .logSymptoms: return "logSymptoms"
        case .logBiomarker: return "logBiomarker"
        case .clinicianReport: return "clinicianReport"
        case .bloodworkHub: return "bloodworkHub"
        case .manualBloodworkEntry: return "manualBloodworkEntry"
        case .uploadLabReport: return "uploadLabReport"
        case .confirmLabReportCandidate(let c): return "confirmLabCandidate_\(c.id.uuidString)"
        case .labPanelDetail(let p): return "labPanelDetail_\(p.id.uuidString)"
        case .timeline: return "timeline"
        case .settings: return "settings"
        case .analytics: return "analytics"
        }
    }
}

@Observable
public final class AppCoordinator: @unchecked Sendable {
    // Primary Tab Selection
    public var selectedTab: AppTab = .home

    // Independent Navigation Paths per Tab (Prevents cross-tab bleeding and avoids deep nesting)
    public var homePath: [HomeDestination] = []
    public var protocolsPath: [ProtocolsDestination] = []
    public var logPath: [LogDestination] = []
    public var labsPath: [LabsDestination] = []
    public var inventoryPath: [InventoryDestination] = []

    // Modal Sheet State
    public var activeSheet: ActiveSheet?
    public var currentToast: ToastMessage?
    public var hasCompletedOnboarding: Bool = false
    public var isAuthenticated: Bool = true
    public let securityManager: AppSecurityManager

    public init(securityManager: AppSecurityManager = .shared) {
        self.securityManager = securityManager
        // Check if user has active session in Keychain
        if securityManager.hasActiveSession() {
            self.isAuthenticated = true
        }
    }

    // MARK: - Tab Selection & Pop to Root
    public func selectTab(_ tab: AppTab) {
        if selectedTab == tab {
            // Re-tapping the active tab pops its navigation stack back to root
            popToRoot(for: tab)
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        }
    }

    public func popToRoot(for tab: AppTab) {
        withAnimation(.easeOut(duration: 0.2)) {
            switch tab {
            case .home:
                homePath.removeAll()
            case .protocols:
                protocolsPath.removeAll()
            case .log:
                logPath.removeAll()
            case .labs:
                labsPath.removeAll()
            case .inventory:
                inventoryPath.removeAll()
            }
        }
    }

    // MARK: - Fast Prominent Log Action (Sub-3-second Dose Entry)
    public func triggerProminentLogAction() {
        VialrHaptics.mediumImpact()
        presentSheet(.quickLog(nil))
    }

    public func openQuickLog(dose: DoseLog? = nil) {
        presentSheet(.quickLog(dose))
    }

    // MARK: - Sheet Presentation
    public func presentSheet(_ sheet: ActiveSheet) {
        self.activeSheet = sheet
    }

    public func dismissSheet() {
        self.activeSheet = nil
    }

    // MARK: - Universal Deep Linking
    public func handleDeepLink(_ url: URL) {
        guard let route = AppDeepLinkRoute.parse(from: url) else { return }

        switch route {
        case .tab(let tab):
            selectTab(tab)
        case .quickLog(let doseId):
            if let doseId = doseId {
                // If a specific dose is passed, open with that dose
                presentSheet(.quickLog(nil))
            } else {
                presentSheet(.quickLog(nil))
            }
        case .reconstitution:
            presentSheet(.reconstitution)
        case .siteRotation:
            presentSheet(.siteRotation)
        case .bloodwork:
            selectTab(.labs)
        case .clinicianReport:
            presentSheet(.clinicianReport)
        case .protocolDetail(let protocolId):
            selectTab(.protocols)
            protocolsPath.append(.protocolDetail(protocolId))
        case .inventoryAddVial:
            selectTab(.inventory)
            presentSheet(.addVial)
        }
    }

    // MARK: - Authentication & Sign Out
    public func signOut() {
        try? KeychainService.shared.clearAllAuthCredentials()
        self.isAuthenticated = false
        self.selectedTab = .home
        self.activeSheet = nil
        self.homePath.removeAll()
        self.protocolsPath.removeAll()
        self.logPath.removeAll()
        self.labsPath.removeAll()
        self.inventoryPath.removeAll()
        self.showToast(title: "Signed Out", message: "Keychain credentials cleared securely.", type: .info)
    }

    // MARK: - Toast Alerts
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
