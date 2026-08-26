import SwiftUI
import Observation
import Domain
import CalculationEngine
import DesignSystem

/// Modes supported by the reconstitution calculator interface.
public enum ReconstitutionMode: String, CaseIterable, Identifiable, Sendable {
    case forward = "Reconstitute Vial"
    case solveDiluent = "Solve Diluent"
    case reverseDose = "Syringe to Dose"

    public var id: String { rawValue }
}

@Observable
public final class ReconstitutionViewModel: @unchecked Sendable {
    // MARK: - Mode
    public var mode: ReconstitutionMode = .forward

    // MARK: - Inputs (Forward Mode)
    public var selectedCompoundName: String = "BPC-157"
    public var dryMassAmount: Double = 5.0
    public var dryMassUnit: MassUnit = .mg
    public var diluentVolumeAmount: Double = 2.0
    public var diluentVolumeUnit: VolumeUnit = .ml
    public var diluentType: DiluentType = .bacteriostaticWater
    public var targetDoseAmount: Double = 250.0
    public var targetDoseUnit: DoseUnit = .mcg
    public var vialCostUsd: Double = 45.0
    public var selectedSyringeSpec: SyringeSpecification = .u100_50unit
    public var compoundActivityRatio: Double = 3.0 // default IU to mg ratio if needed

    // MARK: - Inputs (Solver Modes)
    public var desiredSyringeUnits: Double = 10.0
    public var drawnSyringeUnits: Double = 10.0
    public var currentConcentrationMgMl: Double = 2.5

    // MARK: - Outputs & State
    public var result: ReconstitutionResult?
    public var diluentSolverResult: DiluentSolverResult?
    public var reverseDoseResult: ReverseDoseResult?
    public var calculationError: String?
    public var isCalculating: Bool = false

    // Backward-compatibility properties for existing views
    public var dryMassMg: Double {
        get { dryMassUnit.toCanonicalMg(value: dryMassAmount) }
        set { dryMassAmount = newValue; dryMassUnit = .mg }
    }
    public var diluentVolumeMl: Double {
        get { diluentVolumeUnit.toCanonicalMl(value: diluentVolumeAmount) }
        set { diluentVolumeAmount = newValue; diluentVolumeUnit = .ml }
    }
    public var selectedSyringeSize: SyringeSize {
        get {
            if selectedSyringeSpec.barrelCapacityMl <= 0.35 { return .point3ml }
            if selectedSyringeSpec.barrelCapacityMl <= 0.6 { return .point5ml }
            return .oneMl
        }
        set {
            switch newValue {
            case .point3ml: selectedSyringeSpec = .u100_30unit
            case .point5ml: selectedSyringeSpec = .u100_50unit
            case .oneMl: selectedSyringeSpec = .u100_100unit
            }
        }
    }

    private let engine = ReconstitutionCalculator()

    public init() {
        recalculate()
    }

    // MARK: - Central Recalculation
    public func recalculate() {
        calculationError = nil

        switch mode {
        case .forward:
            calculateForward()
        case .solveDiluent:
            calculateDiluentSolver()
        case .reverseDose:
            calculateReverseDose()
        }
    }

    private func calculateForward() {
        let doseQuantity: DoseQuantity
        switch targetDoseUnit {
        case .mcg:
            doseQuantity = .mass(MassQuantity(targetDoseAmount, .mcg))
        case .mg:
            doseQuantity = .mass(MassQuantity(targetDoseAmount, .mg))
        case .iu:
            doseQuantity = .biologicalActivity(iu: targetDoseAmount)
        case .ml:
            doseQuantity = .volume(VolumeQuantity(targetDoseAmount, .ml))
        }

        let activity: CompoundActivityRatio? = (targetDoseUnit == .iu) ? CompoundActivityRatio(iuPerMg: compoundActivityRatio) : nil

        let input = ReconstitutionInput(
            dryMass: MassQuantity(dryMassAmount, dryMassUnit),
            diluentVolume: VolumeQuantity(diluentVolumeAmount, diluentVolumeUnit),
            targetDose: doseQuantity,
            syringeSpecification: selectedSyringeSpec,
            diluentType: diluentType,
            vialCostUsd: vialCostUsd > 0 ? vialCostUsd : nil,
            compoundActivity: activity,
            compoundName: selectedCompoundName
        )

        do {
            let res = try engine.calculate(input)
            self.result = res
            self.calculationError = nil
        } catch let err as ReconstitutionCalculationError {
            self.calculationError = err.localizedDescription
            self.result = nil
        } catch {
            self.calculationError = error.localizedDescription
            self.result = nil
        }
    }

    private func calculateDiluentSolver() {
        let doseQuantity: DoseQuantity = (targetDoseUnit == .mg) ? .mass(MassQuantity(targetDoseAmount, .mg)) : .mass(MassQuantity(targetDoseAmount, .mcg))
        let input = DiluentSolverInput(
            dryMass: MassQuantity(dryMassAmount, dryMassUnit),
            targetDose: doseQuantity,
            desiredSyringeUnits: desiredSyringeUnits,
            syringeType: selectedSyringeSpec.type,
            compoundActivity: targetDoseUnit == .iu ? CompoundActivityRatio(iuPerMg: compoundActivityRatio) : nil,
            vialCostUsd: vialCostUsd > 0 ? vialCostUsd : nil
        )

        do {
            let res = try engine.solveRequiredDiluentVolume(input)
            self.diluentSolverResult = res
            self.calculationError = nil
        } catch {
            self.calculationError = error.localizedDescription
            self.diluentSolverResult = nil
        }
    }

    private func calculateReverseDose() {
        let input = ReverseDoseInput(
            drawnSyringeUnits: drawnSyringeUnits,
            syringeType: selectedSyringeSpec.type,
            concentrationMgMl: currentConcentrationMgMl,
            compoundActivity: CompoundActivityRatio(iuPerMg: compoundActivityRatio)
        )

        do {
            let res = try engine.reverseCalculateDoseFromSyringe(input)
            self.reverseDoseResult = res
            self.calculationError = nil
        } catch {
            self.calculationError = error.localizedDescription
            self.reverseDoseResult = nil
        }
    }
}
