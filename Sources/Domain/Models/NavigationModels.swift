import Foundation

// MARK: - Primary Application Tabs
/// The primary top-level tabs of the Vialr application.
/// Provides a clear, flat 5-tab structure with a prominent center Log action for ultra-fast dose entry.
public enum AppTab: String, CaseIterable, Identifiable, Sendable, Hashable {
    case home = "Home"
    case protocols = "Protocols"
    case log = "Log"
    case labs = "Labs"
    case inventory = "Inventory"

    public var id: String { rawValue }

    /// SF Symbol icon name representing each tab.
    public var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .protocols: return "list.bullet.rectangle.portrait.fill"
        case .log: return "plus.circle.fill"
        case .labs: return "waveform.path.ecg"
        case .inventory: return "cylinder.split.1x2.fill"
        }
    }

    /// High-contrast secondary icon used when selected or highlighted.
    public var selectedIconName: String {
        switch self {
        case .home: return "house.fill"
        case .protocols: return "list.bullet.rectangle.portrait.fill"
        case .log: return "plus.circle.fill"
        case .labs: return "waveform.path.ecg.rectangle.fill"
        case .inventory: return "cylinder.split.1x2.fill"
        }
    }

    /// Accessibility description for VoiceOver.
    public var accessibilityLabel: String {
        switch self {
        case .home: return "Home Dashboard"
        case .protocols: return "Protocols and Stacks"
        case .log: return "Fast Dose Logger and History"
        case .labs: return "Labs and Bloodwork"
        case .inventory: return "Vial and Supply Inventory"
        }
    }

    /// Indicates whether this tab acts as a prominent floating action button in the tab bar.
    public var isProminentAction: Bool {
        return self == .log
    }

    // MARK: - Backward Compatibility Aliases
    public static var dashboard: AppTab { .home }
    public static var analytics: AppTab { .labs }
    public static var settings: AppTab { .home }
}

// MARK: - Navigation Destinations (Per-Tab Typed Stacks)

/// Typed destinations pushed onto the Home navigation stack.
public enum HomeDestination: Hashable, Sendable {
    case protocolDetail(UUID)
    case siteRotation
    case reconstitution
    case timeline
    case settings
    case clinicianReport
    case analytics
}

/// Typed destinations pushed onto the Protocols navigation stack.
public enum ProtocolsDestination: Hashable, Sendable {
    case protocolDetail(UUID)
    case createProtocol
    case compareProtocols
    case protocolReplay(UUID)
}

/// Typed destinations pushed onto the Log navigation stack.
public enum LogDestination: Hashable, Sendable {
    case doseConfirmation(UUID?)
    case siteRotation
    case logSymptoms
    case logBiomarker
    case reconstitution
    case doseHistory
}

/// Typed destinations pushed onto the Labs navigation stack.
public enum LabsDestination: Hashable, Sendable {
    case timeline
    case manualEntry
    case uploadDocument
    case panelDetail(UUID)
    case biomarkerSelector
    case clinicianReport
}

/// Typed destinations pushed onto the Inventory navigation stack.
public enum InventoryDestination: Hashable, Sendable {
    case addVial
    case reconstitution
    case vialDetail(UUID)
    case vialReconciliation(UUID)
    case vialDisposal(UUID)
}

// MARK: - Universal Deep Linking Route
/// Represents supported deep link URL destinations for push notifications, shortcuts, and external schemes.
public enum AppDeepLinkRoute: Equatable, Sendable {
    case tab(AppTab)
    case quickLog(doseId: UUID?)
    case reconstitution
    case siteRotation
    case bloodwork
    case clinicianReport
    case protocolDetail(protocolId: UUID)
    case inventoryAddVial

    /// Parses an incoming URL scheme into a typed deep link route.
    /// Supports `vialr://...` and standard universal links.
    public static func parse(from url: URL) -> AppDeepLinkRoute? {
        guard let host = url.host?.lowercased() else {
            // Check path component if host is empty
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
            return parseRoute(from: path, queryItems: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        }

        return parseRoute(from: host, queryItems: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    }

    private static func parseRoute(from routeName: String, queryItems: [URLQueryItem]?) -> AppDeepLinkRoute? {
        switch routeName {
        case "home", "dashboard", "today":
            return .tab(.home)
        case "protocols", "stacks":
            if let idString = queryItems?.first(where: { $0.name == "id" })?.value,
               let uuid = UUID(uuidString: idString) {
                return .protocolDetail(protocolId: uuid)
            }
            return .tab(.protocols)
        case "log", "quicklog", "dosing":
            let doseIdString = queryItems?.first(where: { $0.name == "doseId" })?.value
            let doseUuid = doseIdString != nil ? UUID(uuidString: doseIdString!) : nil
            return .quickLog(doseId: doseUuid)
        case "labs", "bloodwork", "biomarkers":
            return .tab(.labs)
        case "inventory", "supplies", "vials":
            return .tab(.inventory)
        case "reconstitution", "calculator":
            return .reconstitution
        case "siterotation", "site-rotation", "sites":
            return .siteRotation
        case "report", "clinician", "clinician-report":
            return .clinicianReport
        case "addvial", "add-vial":
            return .inventoryAddVial
        default:
            return nil
        }
    }
}
