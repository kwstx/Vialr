import Foundation
import Domain

/// Stages of the end-to-end onboarding lifecycle.
public enum OnboardingStage: String, Codable, Sendable, CaseIterable {
    case marketingPager       // 10-12 product marketing swipe pages
    case authentication       // Apple Sign In / Email Vault
    case initializingDatabase // SwiftData / local SQLite & initial account setup
    case postAuthSetup        // First-run post-signup wizard (Protocol, Compound, Schedule, Vial, Reminders, HealthKit, Ready)
    case completed            // Ready for Main App Dashboard
}

/// Steps within the post-authentication first-run setup wizard.
public enum PostAuthSetupStep: Int, CaseIterable, Sendable, Identifiable {
    case firstProtocolPrompt = 0 // 1. Ask whether they want to create their first protocol
    case compound = 1            // 2. Add a compound (select from library or custom + planned dose)
    case schedule = 2            // 3. Configure dosing schedule (frequency, routine, start date)
    case vial = 3                // 4. Optionally add a physical vial (mass, diluent, concentration)
    case reminders = 4           // 5. Configure smart reminders (lead times, restock alerts)
    case healthKit = 5           // 6. Optionally connect Apple Health (biometrics permissions)
    case ready = 6               // 7. "You're ready." completion summary with live data preview

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .firstProtocolPrompt: return "First Protocol"
        case .compound: return "Choose Compound"
        case .schedule: return "Dosing Schedule"
        case .vial: return "Inventory Vial"
        case .reminders: return "Smart Reminders"
        case .healthKit: return "Apple Health"
        case .ready: return "You’re Ready"
        }
    }

    public var subtitle: String {
        switch self {
        case .firstProtocolPrompt: return "Would you like to set up your first protocol now?"
        case .compound: return "Select from your library or configure a custom compound and target dose."
        case .schedule: return "Define your dosing cadence, start date, and administration routine."
        case .vial: return "Optionally link an inventory vial to track solution volume and draw calculations."
        case .reminders: return "Discreet scheduled alerts and low-stock restock notifications."
        case .healthKit: return "Sync resting heart rate, HRV, weight, and blood glucose automatically."
        case .ready: return "Your protocol vault is prepared and scheduled with real data."
        }
    }

    public var stepTag: String {
        "STEP \(rawValue + 1) OF \(PostAuthSetupStep.allCases.count)"
    }

    // MARK: - Backwards Compatibility Aliases
    public static var units: PostAuthSetupStep { .firstProtocolPrompt }
    public static var timezone: PostAuthSetupStep { .schedule }
    public static var notifications: PostAuthSetupStep { .reminders }
    public static var privacy: PostAuthSetupStep { .ready }
}

/// User's initial intent regarding protocol creation on signup.
public enum FirstProtocolChoice: String, CaseIterable, Sendable, Identifiable {
    case createCustom = "createCustom"
    case useTemplate = "useTemplate"
    case sampleData = "sampleData"
    case skipForNow = "skipForNow"

    public var id: String { rawValue }
}

/// Curated starter templates for rapid 1-tap protocol configuration during setup wizard.
public struct StarterProtocolTemplate: Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let compoundName: String
    public let category: CompoundCategory
    public let doseAmount: Double
    public let doseUnit: DoseUnit
    public let frequencyType: FrequencyType
    public let frequencyDescription: String
    public let route: AdministrationRoute
    public let iconName: String
    public let badgeText: String
    public let defaultVialDryMassMg: Double
    public let defaultVialBacWaterMl: Double
    public let goalSummary: String

    public init(
        id: String,
        title: String,
        subtitle: String,
        compoundName: String,
        category: CompoundCategory = .recovery,
        doseAmount: Double,
        doseUnit: DoseUnit,
        frequencyType: FrequencyType,
        frequencyDescription: String,
        route: AdministrationRoute = .subcutaneous,
        iconName: String,
        badgeText: String,
        defaultVialDryMassMg: Double = 5.0,
        defaultVialBacWaterMl: Double = 2.0,
        goalSummary: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.compoundName = compoundName
        self.category = category
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.frequencyType = frequencyType
        self.frequencyDescription = frequencyDescription
        self.route = route
        self.iconName = iconName
        self.badgeText = badgeText
        self.defaultVialDryMassMg = defaultVialDryMassMg
        self.defaultVialBacWaterMl = defaultVialBacWaterMl
        self.goalSummary = goalSummary
    }

    /// Curated starter templates matching standard protocol best practices.
    public static let standardTemplates: [StarterProtocolTemplate] = [
        StarterProtocolTemplate(
            id: "bpc157_recovery",
            title: "Tissue Repair & Healing",
            subtitle: "BPC-157 daily morning administration for tendon & mucosal recovery",
            compoundName: "BPC-157",
            category: .recovery,
            doseAmount: 250,
            doseUnit: .mcg,
            frequencyType: .daily,
            frequencyDescription: "Daily • Morning Fasted",
            route: .subcutaneous,
            iconName: "cross.case.fill",
            badgeText: "Recovery",
            defaultVialDryMassMg: 5.0,
            defaultVialBacWaterMl: 2.0,
            goalSummary: "Targeted musculoskeletal tissue repair and gut barrier optimization."
        ),
        StarterProtocolTemplate(
            id: "tirzepatide_metabolic",
            title: "Metabolic & Glycemic Protocol",
            subtitle: "Tirzepatide weekly initiation dose for metabolic modulation",
            compoundName: "Tirzepatide",
            category: .glp1Metabolic,
            doseAmount: 2.5,
            doseUnit: .mg,
            frequencyType: .everyNDays,
            frequencyDescription: "Weekly • Sunday Morning",
            route: .subcutaneous,
            iconName: "flame.fill",
            badgeText: "Metabolic",
            defaultVialDryMassMg: 10.0,
            defaultVialBacWaterMl: 2.0,
            goalSummary: "Dual GLP-1/GIP glycemic control and body composition support."
        ),
        StarterProtocolTemplate(
            id: "cjc_ipam_gh",
            title: "Nocturnal GH Secretagogue Stack",
            subtitle: "CJC-1295 / Ipamorelin 5-days-on / 2-days-off bedtime pulse",
            compoundName: "CJC-1295 / Ipamorelin",
            category: .growthHormoneSecretagogue,
            doseAmount: 200,
            doseUnit: .mcg,
            frequencyType: .cycle,
            frequencyDescription: "5 Days On / 2 Days Off • Bedtime",
            route: .subcutaneous,
            iconName: "moon.stars.fill",
            badgeText: "GH Pulse",
            defaultVialDryMassMg: 10.0,
            defaultVialBacWaterMl: 3.0,
            goalSummary: "Support natural slow-wave nocturnal growth hormone release and deep sleep."
        ),
        StarterProtocolTemplate(
            id: "nad_longevity",
            title: "Mitochondrial Vitality & NAD+",
            subtitle: "NAD+ bi-weekly subcutaneous replenishment",
            compoundName: "NAD+",
            category: .longevityNootropic,
            doseAmount: 100,
            doseUnit: .mg,
            frequencyType: .daysOfWeek,
            frequencyDescription: "Mon & Thu • Morning",
            route: .subcutaneous,
            iconName: "bolt.fill",
            badgeText: "Vitality",
            defaultVialDryMassMg: 500.0,
            defaultVialBacWaterMl: 5.0,
            goalSummary: "Cellular energy coenzyme replenishment and mitochondrial health."
        ),
        StarterProtocolTemplate(
            id: "trt_optimization",
            title: "Hormone Replacement (TRT)",
            subtitle: "Testosterone Cypionate split twice-weekly schedule",
            compoundName: "Testosterone Cypionate",
            category: .recovery,
            doseAmount: 50,
            doseUnit: .mg,
            frequencyType: .daysOfWeek,
            frequencyDescription: "Mon & Thu • Morning",
            route: .subcutaneous,
            iconName: "bolt.shield.fill",
            badgeText: "Hormone",
            defaultVialDryMassMg: 2000.0,
            defaultVialBacWaterMl: 10.0,
            goalSummary: "Stable physiological androgen replacement and biomarker balance."
        )
    ]
}

/// Configurable options during the first-run setup wizard.
public struct InitialSetupConfiguration: Sendable, Codable {
    public var units: UnitPreferences
    public var timezoneIdentifier: String
    public var notificationPreferences: NotificationPreferences
    public var enableAppleHealth: Bool
    public var enabledHealthMetrics: Set<String>
    public var privacyPreferences: PrivacyPreferences

    public init(
        units: UnitPreferences = UnitPreferences(),
        timezoneIdentifier: String = TimeZone.current.identifier,
        notificationPreferences: NotificationPreferences = NotificationPreferences(),
        enableAppleHealth: Bool = true,
        enabledHealthMetrics: Set<String> = [
            "weight",
            "restingHeartRate",
            "heartRateVariability",
            "bloodGlucose",
            "sleepAnalysis"
        ],
        privacyPreferences: PrivacyPreferences = PrivacyPreferences()
    ) {
        self.units = units
        self.timezoneIdentifier = timezoneIdentifier
        self.notificationPreferences = notificationPreferences
        self.enableAppleHealth = enableAppleHealth
        self.enabledHealthMetrics = enabledHealthMetrics
        self.privacyPreferences = privacyPreferences
    }
}
