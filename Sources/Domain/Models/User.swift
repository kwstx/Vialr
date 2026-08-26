import Foundation

/// Represents the core User model in Vialr, encompassing account details, preferences,
/// localized timezones, notification settings, privacy controls, and measurement unit system.
public struct User: SyncableRecord, Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var accountInfo: AccountInfo
    public var preferences: UserPreferences
    public var timezone: String
    public var notificationPreferences: NotificationPreferences
    public var privacyPreferences: PrivacyPreferences
    public var units: UnitPreferences
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var syncState: SyncState

    public init(
        id: UUID = UUID(),
        accountInfo: AccountInfo,
        preferences: UserPreferences = UserPreferences(),
        timezone: String = TimeZone.current.identifier,
        notificationPreferences: NotificationPreferences = NotificationPreferences(),
        privacyPreferences: PrivacyPreferences = PrivacyPreferences(),
        units: UnitPreferences = UnitPreferences(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        syncState: SyncState = .synced
    ) {
        self.id = id
        self.accountInfo = accountInfo
        self.preferences = preferences
        self.timezone = timezone
        self.notificationPreferences = notificationPreferences
        self.privacyPreferences = privacyPreferences
        self.units = units
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.syncState = syncState
    }

    /// Convenience access to the Foundation `TimeZone` instance.
    public var timeZone: TimeZone {
        TimeZone(identifier: timezone) ?? .current
    }
}

// MARK: - Account Information
public struct AccountInfo: Codable, Sendable, Hashable {
    public var email: String
    public var displayName: String
    public var avatarUrl: String?
    public var phoneNumber: String?
    public var tier: AccountTier
    public var status: AccountStatus
    public var isEmailVerified: Bool

    public init(
        email: String,
        displayName: String,
        avatarUrl: String? = nil,
        phoneNumber: String? = nil,
        tier: AccountTier = .free,
        status: AccountStatus = .active,
        isEmailVerified: Bool = false
    ) {
        self.email = email
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.phoneNumber = phoneNumber
        self.tier = tier
        self.status = status
        self.isEmailVerified = isEmailVerified
    }
}

public enum AccountTier: String, Codable, Sendable, CaseIterable, Identifiable {
    case free = "Free / Community"
    case pro = "Vialr Pro"
    case clinical = "Physician Supervised"

    public var id: String { rawValue }

    public var isProOrHigher: Bool {
        self == .pro || self == .clinical
    }
}

public enum AccountStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case active = "Active"
    case pendingVerification = "Pending Verification"
    case paused = "Paused"
    case suspended = "Suspended"

    public var id: String { rawValue }
}

// MARK: - General User Preferences
public struct UserPreferences: Codable, Sendable, Hashable {
    public var appearanceMode: AppearanceMode
    public var enableHapticFeedback: Bool
    public var enableSoundEffects: Bool
    public var weekStartsOn: Weekday
    public var defaultDoseTimeOfDay: TimeOfDay
    public var autoRotateInjectionSites: Bool
    public var siteRotationStrategy: SiteRotationStrategy
    public var syncWithAppleHealth: Bool
    public var showSafetyWarnings: Bool

    public init(
        appearanceMode: AppearanceMode = .dark,
        enableHapticFeedback: Bool = true,
        enableSoundEffects: Bool = true,
        weekStartsOn: Weekday = .monday,
        defaultDoseTimeOfDay: TimeOfDay = .morning,
        autoRotateInjectionSites: Bool = true,
        siteRotationStrategy: SiteRotationStrategy = .bilateralAlternating,
        syncWithAppleHealth: Bool = true,
        showSafetyWarnings: Bool = true
    ) {
        self.appearanceMode = appearanceMode
        self.enableHapticFeedback = enableHapticFeedback
        self.enableSoundEffects = enableSoundEffects
        self.weekStartsOn = weekStartsOn
        self.defaultDoseTimeOfDay = defaultDoseTimeOfDay
        self.autoRotateInjectionSites = autoRotateInjectionSites
        self.siteRotationStrategy = siteRotationStrategy
        self.syncWithAppleHealth = syncWithAppleHealth
        self.showSafetyWarnings = showSafetyWarnings
    }
}

public enum AppearanceMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case system = "System Default"
    case dark = "Dark Mode"
    case light = "Light Mode"

    public var id: String { rawValue }
}

public enum Weekday: String, Codable, Sendable, CaseIterable, Identifiable {
    case sunday = "Sunday"
    case monday = "Monday"

    public var id: String { rawValue }
}

// MARK: - Notification Preferences
public struct NotificationPreferences: Codable, Sendable, Hashable {
    public var enableDoseReminders: Bool
    public var doseReminderLeadTimeMinutes: Int
    public var enableRestockAlerts: Bool
    public var enableStreakCelebrations: Bool
    public var enableDailyMorningSummary: Bool
    public var morningSummaryTime: String // "08:00" format
    public var enableQuietHours: Bool
    public var quietHoursStart: String? // "22:00" format
    public var quietHoursEnd: String?   // "07:00" format
    public var criticalAlertsEnabled: Bool

    public init(
        enableDoseReminders: Bool = true,
        doseReminderLeadTimeMinutes: Int = 15,
        enableRestockAlerts: Bool = true,
        enableStreakCelebrations: Bool = true,
        enableDailyMorningSummary: Bool = true,
        morningSummaryTime: String = "08:00",
        enableQuietHours: Bool = false,
        quietHoursStart: String? = "22:00",
        quietHoursEnd: String? = "07:00",
        criticalAlertsEnabled: Bool = false
    ) {
        self.enableDoseReminders = enableDoseReminders
        self.doseReminderLeadTimeMinutes = doseReminderLeadTimeMinutes
        self.enableRestockAlerts = enableRestockAlerts
        self.enableStreakCelebrations = enableStreakCelebrations
        self.enableDailyMorningSummary = enableDailyMorningSummary
        self.morningSummaryTime = morningSummaryTime
        self.enableQuietHours = enableQuietHours
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.criticalAlertsEnabled = criticalAlertsEnabled
    }
}

// MARK: - Privacy Preferences
public struct PrivacyPreferences: Codable, Sendable, Hashable {
    public var requireBiometricUnlock: Bool
    public var biometricLockTimeoutSeconds: Int
    public var maskSensitiveDosagesOnLockScreen: Bool
    public var allowDiagnosticTelemetry: Bool
    public var enableCloudBackupEncryption: Bool
    public var allowClinicianDataSharing: Bool

    public init(
        requireBiometricUnlock: Bool = true,
        biometricLockTimeoutSeconds: Int = 60,
        maskSensitiveDosagesOnLockScreen: Bool = true,
        allowDiagnosticTelemetry: Bool = false,
        enableCloudBackupEncryption: Bool = true,
        allowClinicianDataSharing: Bool = true
    ) {
        self.requireBiometricUnlock = requireBiometricUnlock
        self.biometricLockTimeoutSeconds = biometricLockTimeoutSeconds
        self.maskSensitiveDosagesOnLockScreen = maskSensitiveDosagesOnLockScreen
        self.allowDiagnosticTelemetry = allowDiagnosticTelemetry
        self.enableCloudBackupEncryption = enableCloudBackupEncryption
        self.allowClinicianDataSharing = allowClinicianDataSharing
    }
}

// MARK: - Unit Preferences
public struct UnitPreferences: Codable, Sendable, Hashable {
    public var massUnit: DoseUnit
    public var weightUnit: WeightUnit
    public var heightUnit: HeightUnit
    public var bloodGlucoseUnit: BloodGlucoseUnit
    public var temperatureUnit: TemperatureUnit
    public var liquidVolumeUnit: LiquidVolumeUnit

    public init(
        massUnit: DoseUnit = .mcg,
        weightUnit: WeightUnit = .lbs,
        heightUnit: HeightUnit = .inches,
        bloodGlucoseUnit: BloodGlucoseUnit = .mgDl,
        temperatureUnit: TemperatureUnit = .fahrenheit,
        liquidVolumeUnit: LiquidVolumeUnit = .milliliters
    ) {
        self.massUnit = massUnit
        self.weightUnit = weightUnit
        self.heightUnit = heightUnit
        self.bloodGlucoseUnit = bloodGlucoseUnit
        self.temperatureUnit = temperatureUnit
        self.liquidVolumeUnit = liquidVolumeUnit
    }
}

public enum WeightUnit: String, Codable, Sendable, CaseIterable, Identifiable {
    case lbs = "Pounds (lbs)"
    case kg = "Kilograms (kg)"
    case stone = "Stone (st)"

    public var id: String { rawValue }
    
    public var symbol: String {
        switch self {
        case .lbs: return "lbs"
        case .kg: return "kg"
        case .stone: return "st"
        }
    }
}

public enum HeightUnit: String, Codable, Sendable, CaseIterable, Identifiable {
    case inches = "Inches (in)"
    case centimeters = "Centimeters (cm)"
    case feetInches = "Feet & Inches (ft/in)"

    public var id: String { rawValue }
    
    public var symbol: String {
        switch self {
        case .inches: return "in"
        case .centimeters: return "cm"
        case .feetInches: return "ft/in"
        }
    }
}

public enum BloodGlucoseUnit: String, Codable, Sendable, CaseIterable, Identifiable {
    case mgDl = "mg/dL"
    case mmolL = "mmol/L"

    public var id: String { rawValue }

    public var symbol: String { rawValue }
}

public enum TemperatureUnit: String, Codable, Sendable, CaseIterable, Identifiable {
    case fahrenheit = "Fahrenheit (°F)"
    case celsius = "Celsius (°C)"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .fahrenheit: return "°F"
        case .celsius: return "°C"
        }
    }
}

public enum LiquidVolumeUnit: String, Codable, Sendable, CaseIterable, Identifiable {
    case milliliters = "Milliliters (mL)"
    case microliters = "Microliters (μL)"
    case units = "Insulin Units (IU / U-100)"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .milliliters: return "mL"
        case .microliters: return "μL"
        case .units: return "IU"
        }
    }
}
