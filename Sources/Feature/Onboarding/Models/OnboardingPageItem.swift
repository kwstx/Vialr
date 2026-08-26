import SwiftUI
import Domain
import DesignSystem

/// Model representing an individual marketing/product onboarding slide.
public struct OnboardingPageItem: Identifiable, Sendable, Equatable {
    public let id: Int
    public let stepIndex: Int
    public let tag: String
    public let headline: String
    public let explanation: String
    public let heroIcon: String
    public let heroBadgeText: String
    public let secondaryBadgeText: String?
    public let keyMetricValue: String?
    public let keyMetricLabel: String?
    public let visualType: HeroVisualType

    public enum HeroVisualType: Sendable, Equatable {
        case compounds
        case scheduling
        case reconstitution
        case siteRotation
        case quickLogging
        case inventoryDepletion
        case bloodwork
        case healthSync
        case protocolReplay
        case clinicianExport
        case privacyVault
        case personalizedPlan
    }

    public init(
        id: Int,
        stepIndex: Int,
        tag: String,
        headline: String,
        explanation: String,
        heroIcon: String,
        heroBadgeText: String,
        secondaryBadgeText: String? = nil,
        keyMetricValue: String? = nil,
        keyMetricLabel: String? = nil,
        visualType: HeroVisualType
    ) {
        self.id = id
        self.stepIndex = stepIndex
        self.tag = tag
        self.headline = headline
        self.explanation = explanation
        self.heroIcon = heroIcon
        self.heroBadgeText = heroBadgeText
        self.secondaryBadgeText = secondaryBadgeText
        self.keyMetricValue = keyMetricValue
        self.keyMetricLabel = keyMetricLabel
        self.visualType = visualType
    }

    /// The 12 standard marketing/product discovery pages shown before authentication.
    public static let standardPages: [OnboardingPageItem] = [
        OnboardingPageItem(
            id: 0,
            stepIndex: 0,
            tag: "UNIVERSAL PROTOCOL TRACKING",
            headline: "Track Any Peptide, GLP-1, or Compound",
            explanation: "One unified, privacy-first vault for all your research compounds, peptides, TRT regimens, and longevity protocols.",
            heroIcon: "cross.case.fill",
            heroBadgeText: "Universal Catalog",
            secondaryBadgeText: "Multi-Stack Support",
            keyMetricValue: "100%",
            keyMetricLabel: "Compound Agnostic",
            visualType: .compounds
        ),
        OnboardingPageItem(
            id: 1,
            stepIndex: 1,
            tag: "SMART PROTOCOL MANAGEMENT",
            headline: "Intelligent Schedules & Cycle Tracking",
            explanation: "Build multi-compound protocols with custom daily, weekly, or complex titration cadences and track active cycles longitudinally.",
            heroIcon: "calendar.badge.clock",
            heroBadgeText: "Titration Cycles",
            secondaryBadgeText: "Automated Cadence",
            keyMetricValue: "40+",
            keyMetricLabel: "Schedule Types",
            visualType: .scheduling
        ),
        OnboardingPageItem(
            id: 2,
            stepIndex: 2,
            tag: "PRECISION CALCULATORS",
            headline: "Zero-Math Reconstitution & Syringe Ticks",
            explanation: "Enter diluent volume and dry mass to generate interactive syringe markings with exact unit-to-mcg tick calculations.",
            heroIcon: "function",
            heroBadgeText: "Error Prevention",
            secondaryBadgeText: "U-100 / U-40",
            keyMetricValue: "0.01 mL",
            keyMetricLabel: "Precision Accuracy",
            visualType: .reconstitution
        ),
        OnboardingPageItem(
            id: 3,
            stepIndex: 3,
            tag: "TISSUE HEALTH & RECOVERY",
            headline: "Automated 4-Quadrant Injection Site Rotation",
            explanation: "Prevent scar tissue and lipohypertrophy. Smart spatial mapping rotates through abdomen, deltoids, glutes, and thighs automatically.",
            heroIcon: "arrow.triangle.2.circlepath",
            heroBadgeText: "Tissue Fatigue Shield",
            secondaryBadgeText: "4 Anatomical Zones",
            keyMetricValue: "0 Scar",
            keyMetricLabel: "Rotation Balance",
            visualType: .siteRotation
        ),
        OnboardingPageItem(
            id: 4,
            stepIndex: 4,
            tag: "ULTRA-FAST LOGGING",
            headline: "Sub-3-Second Rapid Dose Logging",
            explanation: "Log doses with a single tap directly from interactive widgets, lock screen notifications, or the fast prominent log button.",
            heroIcon: "bolt.fill",
            heroBadgeText: "Instant Haptics",
            secondaryBadgeText: "Offline First",
            keyMetricValue: "< 3 sec",
            keyMetricLabel: "Dose Entry Time",
            visualType: .quickLogging
        ),
        OnboardingPageItem(
            id: 5,
            stepIndex: 5,
            tag: "INVENTORY INTELLIGENCE",
            headline: "Live Vial Volume & Supply Depletion Engine",
            explanation: "Track remaining liquid volume, expiration timestamps, BAC water levels, and receive predictive low-stock restock alerts.",
            heroIcon: "cylinder.split.1x2.fill",
            heroBadgeText: "Volume Accounting",
            secondaryBadgeText: "Depletion Forecast",
            keyMetricValue: "Real-Time",
            keyMetricLabel: "Vial Ledger",
            visualType: .inventoryDepletion
        ),
        OnboardingPageItem(
            id: 6,
            stepIndex: 6,
            tag: "BIOMARKER CORRELATION",
            headline: "Bloodwork & Lab Panel Tracking",
            explanation: "Import PDF lab reports and OCR candidates. Correlate biomarker shifts directly with your active dosing timelines.",
            heroIcon: "waveform.path.ecg",
            heroBadgeText: "Lab OCR Engine",
            secondaryBadgeText: "Trend Analysis",
            keyMetricValue: "100+",
            keyMetricLabel: "Biomarker Panels",
            visualType: .bloodwork
        ),
        OnboardingPageItem(
            id: 7,
            stepIndex: 7,
            tag: "BIOMETRIC SYNC",
            headline: "Seamless Apple Health Integration",
            explanation: "Automatically correlate compound administration with resting heart rate, HRV, body weight, sleep stages, and blood glucose.",
            heroIcon: "heart.fill",
            heroBadgeText: "Apple HealthKit",
            secondaryBadgeText: "Auto Sync",
            keyMetricValue: "Continuous",
            keyMetricLabel: "Vitals Sync",
            visualType: .healthSync
        ),
        OnboardingPageItem(
            id: 8,
            stepIndex: 8,
            tag: "LONGITUDINAL REPLAY",
            headline: "Timeline & Protocol History Replay",
            explanation: "Replay your complete protocol journey day by day to see which stacks delivered peak performance, recovery, and body composition.",
            heroIcon: "clock.arrow.circlepath",
            heroBadgeText: "Protocol Replay",
            secondaryBadgeText: "Audit History",
            keyMetricValue: "Full",
            keyMetricLabel: "Longitudinal Trail",
            visualType: .protocolReplay
        ),
        OnboardingPageItem(
            id: 9,
            stepIndex: 9,
            tag: "CLINICAL EXPORT",
            headline: "Clinician-Ready Summary Reports",
            explanation: "Generate beautifully structured PDF clinical reports with dosage logs, adherence rates, and lab trends for your physician.",
            heroIcon: "doc.plaintext.fill",
            heroBadgeText: "Physician Ready",
            secondaryBadgeText: "PDF & CSV Export",
            keyMetricValue: "1-Tap",
            keyMetricLabel: "Export Format",
            visualType: .clinicianExport
        ),
        OnboardingPageItem(
            id: 10,
            stepIndex: 10,
            tag: "SECURITY & PRIVACY",
            headline: "Hardware-Encrypted Secure Vault",
            explanation: "Local-first architecture protected by Apple Secure Enclave, biometric Face ID, and zero third-party diagnostic tracking.",
            heroIcon: "lock.shield.fill",
            heroBadgeText: "Secure Enclave",
            secondaryBadgeText: "Face ID / Touch ID",
            keyMetricValue: "E2E",
            keyMetricLabel: "AES-256 GCM",
            visualType: .privacyVault
        ),
        OnboardingPageItem(
            id: 11,
            stepIndex: 11,
            tag: "PERSONALIZED EXPERIENCE",
            headline: "Ready to Build Your Protocol Vault?",
            explanation: "Join thousands of researchers and protocol followers optimizing their health outcomes with precision tracking.",
            heroIcon: "sparkles",
            heroBadgeText: "Instant Access",
            secondaryBadgeText: "Private Vault",
            keyMetricValue: "Ready",
            keyMetricLabel: "Setup Next",
            visualType: .personalizedPlan
        )
    ]
}
