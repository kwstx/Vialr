import Foundation
import Domain

/// Mathematical computation engine for peptide reconstitution, syringe unit calculations, and dosing geometry.
public struct ReconstitutionCalculator: Sendable {
    
    public struct CalculationResult: Sendable, Hashable {
        public let concentrationMgMl: Double
        public let concentrationMcgMl: Double
        public let drawVolumeMl: Double
        public let u100Units: Double
        public let u40Units: Double
        public let totalDosesInVial: Double
        public let costPerDoseUsd: Double?
        public let stepByStepInstructions: [String]

        public init(
            concentrationMgMl: Double,
            concentrationMcgMl: Double,
            drawVolumeMl: Double,
            u100Units: Double,
            u40Units: Double,
            totalDosesInVial: Double,
            costPerDoseUsd: Double? = nil,
            stepByStepInstructions: [String] = []
        ) {
            self.concentrationMgMl = concentrationMgMl
            self.concentrationMcgMl = concentrationMcgMl
            self.drawVolumeMl = drawVolumeMl
            self.u100Units = u100Units
            self.u40Units = u40Units
            self.totalDosesInVial = totalDosesInVial
            self.costPerDoseUsd = costPerDoseUsd
            self.stepByStepInstructions = stepByStepInstructions
        }
    }

    public init() {}

    /// Computes full reconstitution dynamics given dry mass, added diluent, and target dose.
    public func calculate(
        dryMassMg: Double,
        diluentVolumeMl: Double,
        targetDoseAmount: Double,
        targetDoseUnit: DoseUnit,
        vialCostUsd: Double? = nil
    ) -> CalculationResult {
        guard dryMassMg > 0, diluentVolumeMl > 0, targetDoseAmount > 0 else {
            return CalculationResult(
                concentrationMgMl: 0,
                concentrationMcgMl: 0,
                drawVolumeMl: 0,
                u100Units: 0,
                u40Units: 0,
                totalDosesInVial: 0
            )
        }

        // 1. Concentration (mg/mL and mcg/mL)
        let concentrationMgMl = dryMassMg / diluentVolumeMl
        let concentrationMcgMl = concentrationMgMl * 1000.0

        // 2. Convert Target Dose to Milligrams
        let targetDoseMg: Double
        switch targetDoseUnit {
        case .mg:
            targetDoseMg = targetDoseAmount
        case .mcg:
            targetDoseMg = targetDoseAmount / 1000.0
        case .iu:
            // Generic 1 mg ≈ 3 IU for standard somatropin GH or 1:1 fallback
            targetDoseMg = targetDoseAmount / 3.0
        case .ml:
            targetDoseMg = targetDoseAmount * concentrationMgMl
        }

        // 3. Draw Volume (mL) = Target Dose (mg) / Concentration (mg/mL)
        let drawVolumeMl = targetDoseMg / concentrationMgMl

        // 4. Syringe Markings:
        // U-100 syringe: 1.0 mL = 100 units (0.01 mL per unit)
        let u100Units = drawVolumeMl * 100.0
        // U-40 syringe: 1.0 mL = 40 units (0.025 mL per unit)
        let u40Units = drawVolumeMl * 40.0

        // 5. Total Doses in Vial
        let totalDosesInVial = dryMassMg / targetDoseMg

        // 6. Cost Per Dose
        let costPerDose: Double?
        if let cost = vialCostUsd, cost > 0, totalDosesInVial > 0 {
            costPerDose = cost / totalDosesInVial
        } else {
            costPerDose = nil
        }

        // 7. Clinical step instructions
        var steps: [String] = []
        steps.append("Wipe the top of the vial with an alcohol prep pad.")
        steps.append("Draw \(String(format: "%.1f", diluentVolumeMl)) mL of Bacteriostatic Water into the mixing syringe.")
        steps.append("Gently inject the diluent against the inside glass wall of the vial. Do NOT shake.")
        steps.append("Swirl gently until the lyophilized powder is completely dissolved and clear.")
        steps.append("To administer your \(String(format: "%.0f", targetDoseAmount)) \(targetDoseUnit.rawValue) dose, draw to the \(String(format: "%.1f", u100Units)) unit mark on a standard U-100 insulin syringe (\(String(format: "%.3f", drawVolumeMl)) mL).")
        steps.append("Store the reconstituted vial in the refrigerator at 2–8°C.")

        return CalculationResult(
            concentrationMgMl: concentrationMgMl,
            concentrationMcgMl: concentrationMcgMl,
            drawVolumeMl: drawVolumeMl,
            u100Units: u100Units,
            u40Units: u40Units,
            totalDosesInVial: totalDosesInVial,
            costPerDoseUsd: costPerDose,
            stepByStepInstructions: steps
        )
    }

    /// Converts U-100 units drawn back to actual administered dose amount.
    public func reverseCalculateDose(
        u100Units: Double,
        concentrationMgMl: Double,
        desiredUnit: DoseUnit = .mcg
    ) -> Double {
        let volumeMl = u100Units / 100.0
        let doseMg = volumeMl * concentrationMgMl
        switch desiredUnit {
        case .mg: return doseMg
        case .mcg: return doseMg * 1000.0
        case .iu: return doseMg * 3.0
        case .ml: return volumeMl
        }
    }
}
