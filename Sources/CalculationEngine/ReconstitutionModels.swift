import Foundation
import Domain

// MARK: - Reconstitution Calculation Errors

/// Strongly-typed calculation and dimensional validation errors.
public enum ReconstitutionCalculationError: Error, LocalizedError, Sendable, Codable, Equatable {
    case nonPositiveDryMass(received: Double)
    case nonPositiveDiluentVolume(received: Double)
    case nonPositiveTargetDose(received: Double)
    case nonPositiveSyringeUnits(received: Double)
    case nonFiniteValue(field: String)
    case dimensionalMismatch(field: String, expected: PhysicalDimension, received: PhysicalDimension)
    case missingBiologicalConversionRatio(compoundName: String?)
    case unrealisticVialCapacity(receivedMl: Double, maxMl: Double)
    case doseExceedsVialContent(doseMg: Double, totalDryMassMg: Double)
    case divisionByZero(formula: String)
    case unsupportedConversion(from: String, to: String)

    public var errorDescription: String? {
        switch self {
        case .nonPositiveDryMass(let received):
            return "Dry mass must be greater than 0 (received: \(received))."
        case .nonPositiveDiluentVolume(let received):
            return "Diluent volume must be greater than 0 mL (received: \(received))."
        case .nonPositiveTargetDose(let received):
            return "Target dose amount must be greater than 0 (received: \(received))."
        case .nonPositiveSyringeUnits(let received):
            return "Syringe units must be greater than 0 (received: \(received))."
        case .nonFiniteValue(let field):
            return "Numeric input for '\(field)' is not a valid finite number (received NaN or Infinity)."
        case .dimensionalMismatch(let field, let expected, let received):
            return "Dimensional mismatch for '\(field)': Expected \(expected.rawValue), but received \(received.rawValue)."
        case .missingBiologicalConversionRatio(let compoundName):
            let name = compoundName ?? "the specified compound"
            return "Biological activity conversion ratio (IU to mg) is required to calculate doses in IU for \(name)."
        case .unrealisticVialCapacity(let receivedMl, let maxMl):
            return "Diluent volume (\(String(format: "%.1f", receivedMl)) mL) exceeds standard physiological vial capacity (\(String(format: "%.1f", maxMl)) mL)."
        case .doseExceedsVialContent(let doseMg, let totalDryMassMg):
            return "Target dose (\(String(format: "%.2f", doseMg)) mg) exceeds total mass available in vial (\(String(format: "%.2f", totalDryMassMg)) mg)."
        case .divisionByZero(let formula):
            return "Cannot perform calculation: Division by zero encountered in formula '\(formula)'."
        case .unsupportedConversion(let from, let to):
            return "Cannot convert from '\(from)' to '\(to)': Incompatible dimensional units."
        }
    }
}

// MARK: - Calculation Warnings & Severity

public enum WarningSeverity: String, Codable, Sendable {
    case info
    case warning
    case critical
}

/// Clinical or physical advisory generated during calculation.
public struct CalculationWarning: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let message: String
    public let severity: WarningSeverity

    public init(id: String, title: String, message: String, severity: WarningSeverity = .warning) {
        self.id = id
        self.title = title
        self.message = message
        self.severity = severity
    }
}

// MARK: - Derivation Audit Step

/// Immutable step-by-step mathematical explanation for calculation transparency.
public struct DerivationStep: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let stepIndex: Int
    public let title: String
    public let formula: String
    public let substitution: String
    public let evaluatedResult: String
    public let clinicalNote: String?

    public init(
        stepIndex: Int,
        title: String,
        formula: String,
        substitution: String,
        evaluatedResult: String,
        clinicalNote: String? = nil
    ) {
        self.id = "step_\(stepIndex)"
        self.stepIndex = stepIndex
        self.title = title
        self.formula = formula
        self.substitution = substitution
        self.evaluatedResult = evaluatedResult
        self.clinicalNote = clinicalNote
    }
}

// MARK: - Structured Inputs

/// Structured input parameters for forward reconstitution and dose calculation.
public struct ReconstitutionInput: Codable, Sendable, Hashable {
    public var dryMass: MassQuantity
    public var diluentVolume: VolumeQuantity
    public var targetDose: DoseQuantity
    public var syringeSpecification: SyringeSpecification
    public var diluentType: DiluentType
    public var vialCostUsd: Double?
    public var compoundActivity: CompoundActivityRatio?
    public var compoundName: String?

    public init(
        dryMass: MassQuantity,
        diluentVolume: VolumeQuantity,
        targetDose: DoseQuantity,
        syringeSpecification: SyringeSpecification = .u100_100unit,
        diluentType: DiluentType = .bacteriostaticWater,
        vialCostUsd: Double? = nil,
        compoundActivity: CompoundActivityRatio? = nil,
        compoundName: String? = nil
    ) {
        self.dryMass = dryMass
        self.diluentVolume = diluentVolume
        self.targetDose = targetDose
        self.syringeSpecification = syringeSpecification
        self.diluentType = diluentType
        self.vialCostUsd = vialCostUsd
        self.compoundActivity = compoundActivity
        self.compoundName = compoundName
    }

    /// Convenience initializer using primitive numbers and domain DoseUnit.
    public init(
        dryMassMg: Double,
        diluentVolumeMl: Double,
        targetDoseAmount: Double,
        targetDoseUnit: DoseUnit,
        syringeSpecification: SyringeSpecification = .u100_100unit,
        diluentType: DiluentType = .bacteriostaticWater,
        vialCostUsd: Double? = nil,
        compoundActivity: CompoundActivityRatio? = nil,
        compoundName: String? = nil
    ) {
        self.init(
            dryMass: MassQuantity(dryMassMg, .mg),
            diluentVolume: VolumeQuantity(diluentVolumeMl, .ml),
            targetDose: DoseQuantity(amount: targetDoseAmount, unit: targetDoseUnit),
            syringeSpecification: syringeSpecification,
            diluentType: diluentType,
            vialCostUsd: vialCostUsd,
            compoundActivity: compoundActivity,
            compoundName: compoundName
        )
    }
}

// MARK: - Structured Results

/// Structured result of a reconstitution calculation containing normalized concentrations,
/// draw volumes, syringe calibration, yield metrics, derivation breakdown, and clinical safety warnings.
public struct ReconstitutionResult: Codable, Sendable, Hashable {
    // 1. Normalized Concentrations
    public let concentrationMgMl: Double
    public let concentrationMcgMl: Double
    public let concentrationIuMl: Double?

    // 2. Normalized Target Dose
    public let normalizedDoseMg: Double
    public let normalizedDoseMcg: Double
    public let normalizedDoseIu: Double?

    // 3. Calculated Draw Volume
    public let drawVolumeMl: Double
    public let drawVolumeMcl: Double

    // 4. Syringe Markings & Geometry
    public let u100Units: Double
    public let u40Units: Double
    public let selectedSyringeUnits: Double
    public let selectedSyringe: SyringeSpecification
    public let syringeBarrelFillFraction: Double
    public let isWithinSyringeCapacity: Bool
    public let syringeVisualDescription: String

    // 5. Vial Yield & Economics
    public let totalDosesInVial: Double
    public let exactDosesCount: Int
    public let remainingResidualDose: Double
    public let costPerDoseUsd: Double?
    public let costPerMgUsd: Double?

    // 6. Derivation Breakdown & Audit Trail
    public let derivationSteps: [DerivationStep]
    public let summaryExplanation: String
    public let clinicalInstructions: [String]

    // 7. Safety Advisories & Warnings
    public let warnings: [CalculationWarning]

    public init(
        concentrationMgMl: Double,
        concentrationMcgMl: Double,
        concentrationIuMl: Double? = nil,
        normalizedDoseMg: Double,
        normalizedDoseMcg: Double,
        normalizedDoseIu: Double? = nil,
        drawVolumeMl: Double,
        drawVolumeMcl: Double,
        u100Units: Double,
        u40Units: Double,
        selectedSyringeUnits: Double,
        selectedSyringe: SyringeSpecification,
        syringeBarrelFillFraction: Double,
        isWithinSyringeCapacity: Bool,
        syringeVisualDescription: String,
        totalDosesInVial: Double,
        exactDosesCount: Int,
        remainingResidualDose: Double,
        costPerDoseUsd: Double? = nil,
        costPerMgUsd: Double? = nil,
        derivationSteps: [DerivationStep] = [],
        summaryExplanation: String = "",
        clinicalInstructions: [String] = [],
        warnings: [CalculationWarning] = []
    ) {
        self.concentrationMgMl = concentrationMgMl
        self.concentrationMcgMl = concentrationMcgMl
        self.concentrationIuMl = concentrationIuMl
        self.normalizedDoseMg = normalizedDoseMg
        self.normalizedDoseMcg = normalizedDoseMcg
        self.normalizedDoseIu = normalizedDoseIu
        self.drawVolumeMl = drawVolumeMl
        self.drawVolumeMcl = drawVolumeMcl
        self.u100Units = u100Units
        self.u40Units = u40Units
        self.selectedSyringeUnits = selectedSyringeUnits
        self.selectedSyringe = selectedSyringe
        self.syringeBarrelFillFraction = syringeBarrelFillFraction
        self.isWithinSyringeCapacity = isWithinSyringeCapacity
        self.syringeVisualDescription = syringeVisualDescription
        self.totalDosesInVial = totalDosesInVial
        self.exactDosesCount = exactDosesCount
        self.remainingResidualDose = remainingResidualDose
        self.costPerDoseUsd = costPerDoseUsd
        self.costPerMgUsd = costPerMgUsd
        self.derivationSteps = derivationSteps
        self.summaryExplanation = summaryExplanation
        self.clinicalInstructions = clinicalInstructions
        self.warnings = warnings
    }
}

// MARK: - Multi-Way Solver Inputs & Results

/// Parameters for solving the required diluent volume to achieve specific syringe markings.
public struct DiluentSolverInput: Codable, Sendable, Hashable {
    public var dryMass: MassQuantity
    public var targetDose: DoseQuantity
    public var desiredSyringeUnits: Double
    public var syringeType: SyringeType
    public var compoundActivity: CompoundActivityRatio?
    public var vialCostUsd: Double?

    public init(
        dryMass: MassQuantity,
        targetDose: DoseQuantity,
        desiredSyringeUnits: Double,
        syringeType: SyringeType = .u100,
        compoundActivity: CompoundActivityRatio? = nil,
        vialCostUsd: Double? = nil
    ) {
        self.dryMass = dryMass
        self.targetDose = targetDose
        self.desiredSyringeUnits = desiredSyringeUnits
        self.syringeType = syringeType
        self.compoundActivity = compoundActivity
        self.vialCostUsd = vialCostUsd
    }
}

/// Result of diluent volume solver.
public struct DiluentSolverResult: Codable, Sendable, Hashable {
    public let recommendedDiluentVolumeMl: Double
    public let resultingConcentrationMgMl: Double
    public let resultingConcentrationMcgMl: Double
    public let targetDoseMg: Double
    public let targetDoseMcg: Double
    public let drawVolumeMl: Double
    public let syringeUnits: Double
    public let totalDosesInVial: Double
    public let costPerDoseUsd: Double?
    public let derivationSteps: [DerivationStep]
    public let summaryExplanation: String
    public let warnings: [CalculationWarning]

    public init(
        recommendedDiluentVolumeMl: Double,
        resultingConcentrationMgMl: Double,
        resultingConcentrationMcgMl: Double,
        targetDoseMg: Double,
        targetDoseMcg: Double,
        drawVolumeMl: Double,
        syringeUnits: Double,
        totalDosesInVial: Double,
        costPerDoseUsd: Double? = nil,
        derivationSteps: [DerivationStep] = [],
        summaryExplanation: String = "",
        warnings: [CalculationWarning] = []
    ) {
        self.recommendedDiluentVolumeMl = recommendedDiluentVolumeMl
        self.resultingConcentrationMgMl = resultingConcentrationMgMl
        self.resultingConcentrationMcgMl = resultingConcentrationMcgMl
        self.targetDoseMg = targetDoseMg
        self.targetDoseMcg = targetDoseMcg
        self.drawVolumeMl = drawVolumeMl
        self.syringeUnits = syringeUnits
        self.totalDosesInVial = totalDosesInVial
        self.costPerDoseUsd = costPerDoseUsd
        self.derivationSteps = derivationSteps
        self.summaryExplanation = summaryExplanation
        self.warnings = warnings
    }
}

/// Parameters for reverse-calculating administered dose from syringe markings.
public struct ReverseDoseInput: Codable, Sendable, Hashable {
    public var drawnSyringeUnits: Double
    public var syringeType: SyringeType
    public var concentrationMgMl: Double
    public var compoundActivity: CompoundActivityRatio?

    public init(
        drawnSyringeUnits: Double,
        syringeType: SyringeType = .u100,
        concentrationMgMl: Double,
        compoundActivity: CompoundActivityRatio? = nil
    ) {
        self.drawnSyringeUnits = drawnSyringeUnits
        self.syringeType = syringeType
        self.concentrationMgMl = concentrationMgMl
        self.compoundActivity = compoundActivity
    }
}

/// Result of reverse dose calculation.
public struct ReverseDoseResult: Codable, Sendable, Hashable {
    public let drawnVolumeMl: Double
    public let administeredDoseMg: Double
    public let administeredDoseMcg: Double
    public let administeredDoseIu: Double?
    public let derivationSteps: [DerivationStep]
    public let summaryExplanation: String

    public init(
        drawnVolumeMl: Double,
        administeredDoseMg: Double,
        administeredDoseMcg: Double,
        administeredDoseIu: Double? = nil,
        derivationSteps: [DerivationStep] = [],
        summaryExplanation: String = ""
    ) {
        self.drawnVolumeMl = drawnVolumeMl
        self.administeredDoseMg = administeredDoseMg
        self.administeredDoseMcg = administeredDoseMcg
        self.administeredDoseIu = administeredDoseIu
        self.derivationSteps = derivationSteps
        self.summaryExplanation = summaryExplanation
    }
}
