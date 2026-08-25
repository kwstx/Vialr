import SwiftUI
import Observation
import Domain
import CalculationEngine
import DesignSystem

@Observable
public final class ReconstitutionViewModel: @unchecked Sendable {
    // Inputs
    public var selectedCompoundName: String = "BPC-157"
    public var dryMassMg: Double = 5.0
    public var diluentVolumeMl: Double = 2.0
    public var targetDoseAmount: Double = 250.0
    public var targetDoseUnit: DoseUnit = .mcg
    public var vialCostUsd: Double = 45.0
    public var selectedSyringeSize: SyringeSize = .point5ml

    // Output Result
    public var result: ReconstitutionCalculator.CalculationResult = ReconstitutionCalculator.CalculationResult(
        concentrationMgMl: 2.5,
        concentrationMcgMl: 2500,
        drawVolumeMl: 0.1,
        u100Units: 10.0,
        u40Units: 4.0,
        totalDosesInVial: 20.0,
        costPerDoseUsd: 2.25,
        stepByStepInstructions: []
    )

    private let calculator = ReconstitutionCalculator()

    public init() {
        recalculate()
    }

    public func recalculate() {
        result = calculator.calculate(
            dryMassMg: dryMassMg,
            diluentVolumeMl: diluentVolumeMl,
            targetDoseAmount: targetDoseAmount,
            targetDoseUnit: targetDoseUnit,
            vialCostUsd: vialCostUsd > 0 ? vialCostUsd : nil
        )
    }
}
