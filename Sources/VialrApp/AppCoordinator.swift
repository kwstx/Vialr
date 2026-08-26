import SwiftUI
import Observation
import Domain
import Feature
import DesignSystem
import Data

// MARK: - Quick Action Bottom Sheets (Interactive Detents)
public enum ActiveBottomSheet: Identifiable, Sendable {
    case quickLog(DoseLog?)
    case logSymptoms
    case logBiomarker
    case siteRotation
    case addVial
    case explainability(title: String, explanation: String)

    public var id: String {
        switch self {
        case .quickLog(let d): return "quickLog_\(d?.id.uuidString ?? "new")"
        case .logSymptoms: return "logSymptoms"
        case .logBiomarker: return "logBiomarker"
        case .siteRotation: return "siteRotation"
        case .addVial: return "addVial"
        case .explainability(let t, _): return "explainability_\(t)"
        }
    }
}

// MARK: - Important Full-Screen Setup Tasks & Deep Workflows
public enum ActiveFullScreenFlow: Identifiable, Sendable {
    case createProtocol
    case clinicianReport
    case protocolReplay(ProtocolModel)
    case protocolComparison
    case reconstitution
    case uploadLabReport
    case confirmLabReportCandidate(ExtractedLabReportCandidate)
    case manualBloodworkEntry
    case protocolDetail(ProtocolModel)
    case labPanelDetail(LabPanel)
    case timeline
    case settings
    case analytics

    public var id: String {
        switch self {
        case .createProtocol: return "createProtocol"
        case .clinicianReport: return "clinicianReport"
        case .protocolReplay(let p): return "protocolReplay_\(p.id.uuidString)"
        case .protocolComparison: return "protocolComparison"
        case .reconstitution: return "reconstitution"
        case .uploadLabReport: return "uploadLabReport"
        case .confirmLabReportCandidate(let c): return "confirmLabCandidate_\(c.id.uuidString)"
        case .manualBloodworkEntry: return "manualBloodworkEntry"
        case .protocolDetail(let p): return "protocolDetail_\(p.id.uuidString)"
        case .labPanelDetail(let p): return "labPanelDetail_\(p.id.uuidString)"
        case .timeline: return "timeline"
        case .settings: return "settings"
        case .analytics: return "analytics"
        }
    }
}

// MARK: - Unified ActiveSheet Type for Full Backward Compatibility
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

    /// Whether this presentation represents a quick action (bottom sheet) or a setup flow (full screen)
    public var isQuickActionBottomSheet: Bool {
        switch self {
        case .quickLog, .logSymptoms, .logBiomarker, .siteRotation, .addVial:
            return true
        default:
            return false
        }
    }
}

@Observable
public final class AppCoordinator: @unchecked Sendable {
    // Primary Tab Selection
    public var selectedTab: AppTab = .home

    // Independent Navigation Paths per Tab
    public var homePath: [HomeDestination] = []
    public var protocolsPath: [ProtocolsDestination] = []
    public var logPath: [LogDestination] = []
    public var labsPath: [LabsDestination] = []
    public var inventoryPath: [InventoryDestination] = []

    // Modal Presentation States
    public var activeBottomSheet: ActiveBottomSheet?
    public var activeFullScreenFlow: ActiveFullScreenFlow?
    public var activeSheet: ActiveSheet?

    public var currentToast: ToastMessage?
    public var hasCompletedOnboarding: Bool = false
    public var isAuthenticated: Bool = true
    public let securityManager: AppSecurityManager

    public init(securityManager: AppSecurityManager = .shared, userDefaults: UserDefaults = .standard) {
        self.securityManager = securityManager
        let completed = userDefaults.bool(forKey: OnboardingPagerViewModel.onboardingCompletedStorageKey)
        if securityManager.hasActiveSession() {
            self.isAuthenticated = true
            self.hasCompletedOnboarding = true
        } else {
            self.isAuthenticated = false
            self.hasCompletedOnboarding = completed
        }
    }

    // MARK: - Tab Selection & Pop to Root
    public func selectTab(_ tab: AppTab) {
        if selectedTab == tab {
            popToRoot(for: tab)
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
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
        presentBottomSheet(.quickLog(nil))
    }

    public func openQuickLog(dose: DoseLog? = nil) {
        presentBottomSheet(.quickLog(dose))
    }

    // MARK: - Bottom Sheet Presentation (Quick Actions)
    public func presentBottomSheet(_ sheet: ActiveBottomSheet) {
        VialrHaptics.lightImpact()
        self.activeBottomSheet = sheet
    }

    public func dismissBottomSheet() {
        self.activeBottomSheet = nil
    }

    // MARK: - Full-Screen Flow Presentation (Important Setup Tasks)
    public func presentFullScreenFlow(_ flow: ActiveFullScreenFlow) {
        VialrHaptics.lightImpact()
        self.activeFullScreenFlow = flow
    }

    public func dismissFullScreenFlow() {
        self.activeFullScreenFlow = nil
    }

    // MARK: - Unified Presentation (Handles both quick actions & setup flows)
    public func presentSheet(_ sheet: ActiveSheet) {
        // Intelligently route based on whether it is a quick action or full-screen setup task
        switch sheet {
        case .quickLog(let d):
            presentBottomSheet(.quickLog(d))
        case .logSymptoms:
            presentBottomSheet(.logSymptoms)
        case .logBiomarker:
            presentBottomSheet(.logBiomarker)
        case .siteRotation:
            presentBottomSheet(.siteRotation)
        case .addVial:
            presentBottomSheet(.addVial)
        case .createProtocol:
            presentFullScreenFlow(.createProtocol)
        case .clinicianReport:
            presentFullScreenFlow(.clinicianReport)
        case .protocolReplay(let p):
            presentFullScreenFlow(.protocolReplay(p))
        case .protocolComparison:
            presentFullScreenFlow(.protocolComparison)
        case .reconstitution:
            presentFullScreenFlow(.reconstitution)
        case .uploadLabReport:
            presentFullScreenFlow(.uploadLabReport)
        case .confirmLabReportCandidate(let c):
            presentFullScreenFlow(.confirmLabReportCandidate(c))
        case .manualBloodworkEntry:
            presentFullScreenFlow(.manualBloodworkEntry)
        case .protocolDetail(let p):
            presentFullScreenFlow(.protocolDetail(p))
        case .labPanelDetail(let p):
            presentFullScreenFlow(.labPanelDetail(p))
        case .timeline:
            presentFullScreenFlow(.timeline)
        case .settings:
            presentFullScreenFlow(.settings)
        case .analytics:
            presentFullScreenFlow(.analytics)
        case .bloodworkHub:
            selectTab(.labs)
        }
    }

    public func dismissSheet() {
        self.activeBottomSheet = nil
        self.activeFullScreenFlow = nil
        self.activeSheet = nil
    }

    // MARK: - Universal Deep Linking
    public func handleDeepLink(_ url: URL) {
        guard let route = AppDeepLinkRoute.parse(from: url) else { return }

        switch route {
        case .tab(let tab):
            selectTab(tab)
        case .quickLog(let doseId):
            presentBottomSheet(.quickLog(nil))
        case .reconstitution:
            presentFullScreenFlow(.reconstitution)
        case .siteRotation:
            presentBottomSheet(.siteRotation)
        case .bloodwork:
            selectTab(.labs)
        case .clinicianReport:
            presentFullScreenFlow(.clinicianReport)
        case .protocolDetail(let protocolId):
            selectTab(.protocols)
            protocolsPath.append(.protocolDetail(protocolId))
        case .inventoryAddVial:
            selectTab(.inventory)
            presentBottomSheet(.addVial)
        }
    }

    // MARK: - Authentication & Sign Out
    public func signOut() {
        try? KeychainService.shared.clearAllAuthCredentials()
        self.isAuthenticated = false
        self.selectedTab = .home
        self.activeBottomSheet = nil
        self.activeFullScreenFlow = nil
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
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            if self.currentToast?.id == toast.id {
                withAnimation(.easeOut(duration: 0.25)) {
                    self.currentToast = nil
                }
            }
        }
    }
}
