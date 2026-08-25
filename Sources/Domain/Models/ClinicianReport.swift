import Foundation

/// Defines a structured medical report exportable for physicians, endocrinologists, or wellness clinicians.
public struct ClinicianReport: Identifiable, Codable, Sendable {
    public let id: UUID
    public var patientIdentifier: String
    public var generatedDate: Date
    public var dateRangeStart: Date
    public var dateRangeEnd: Date
    public var activeProtocols: [ProtocolModel]
    public var doseSummary: [CompoundDoseSummary]
    public var adherencePercentage: Double
    public var totalDosesAdministered: Int
    public var latestBiomarkers: [Biomarker]
    public var subjectiveTrendsSummary: String
    public var clinicalNotes: String

    public init(
        id: UUID = UUID(),
        patientIdentifier: String = "Patient / Self",
        generatedDate: Date = Date(),
        dateRangeStart: Date,
        dateRangeEnd: Date,
        activeProtocols: [ProtocolModel] = [],
        doseSummary: [CompoundDoseSummary] = [],
        adherencePercentage: Double = 0.0,
        totalDosesAdministered: Int = 0,
        latestBiomarkers: [Biomarker] = [],
        subjectiveTrendsSummary: String = "",
        clinicalNotes: String = ""
    ) {
        self.id = id
        self.patientIdentifier = patientIdentifier
        self.generatedDate = generatedDate
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.activeProtocols = activeProtocols
        self.doseSummary = doseSummary
        self.adherencePercentage = adherencePercentage
        self.totalDosesAdministered = totalDosesAdministered
        self.latestBiomarkers = latestBiomarkers
        self.subjectiveTrendsSummary = subjectiveTrendsSummary
        self.clinicalNotes = clinicalNotes
    }
}

public struct CompoundDoseSummary: Identifiable, Codable, Sendable {
    public var id: UUID
    public var compoundName: String
    public var totalDoseDelivered: Double
    public var unit: DoseUnit
    public var averageDose: Double
    public var numberOfInjections: Int
    public var mostFrequentSite: String

    public init(
        id: UUID = UUID(),
        compoundName: String,
        totalDoseDelivered: Double,
        unit: DoseUnit,
        averageDose: Double,
        numberOfInjections: Int,
        mostFrequentSite: String
    ) {
        self.id = id
        self.compoundName = compoundName
        self.totalDoseDelivered = totalDoseDelivered
        self.unit = unit
        self.averageDose = averageDose
        self.numberOfInjections = numberOfInjections
        self.mostFrequentSite = mostFrequentSite
    }
}
