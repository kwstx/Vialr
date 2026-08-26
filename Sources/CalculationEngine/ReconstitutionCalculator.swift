import Foundation
import Domain

/// Mathematical computation and dimensional validation engine for peptide reconstitution,
/// unit normalization, syringe unit calibration, and clinical derivation audit trails.
///
/// Designed as a standalone, thread-safe, pure Swift module compatible with both iOS client and Vapor backend.
public struct ReconstitutionCalculator: Sendable {

    public typealias CalculationResult = ReconstitutionResult

    public init() {}

    // MARK: - 1. Dimensional Validation

    /// Validates all physical parameters before executing mathematical formulas.
    /// Rejects invalid, non-positive, non-finite, or dimensionally incompatible inputs.
    public func validate(_ input: ReconstitutionInput) throws {
        // Dry Mass Validation
        guard input.dryMass.value.isFinite && !input.dryMass.value.isNaN else {
            throw ReconstitutionCalculationError.nonFiniteValue(field: "Dry Mass")
        }
        guard input.dryMass.value > 0 else {
            throw ReconstitutionCalculationError.nonPositiveDryMass(received: input.dryMass.value)
        }

        // Diluent Volume Validation
        guard input.diluentVolume.value.isFinite && !input.diluentVolume.value.isNaN else {
            throw ReconstitutionCalculationError.nonFiniteValue(field: "Diluent Volume")
        }
        guard input.diluentVolume.value > 0 else {
            throw ReconstitutionCalculationError.nonPositiveDiluentVolume(received: input.diluentVolume.value)
        }
        let diluentMl = input.diluentVolume.ml
        guard diluentMl <= 100.0 else {
            throw ReconstitutionCalculationError.unrealisticVialCapacity(receivedMl: diluentMl, maxMl: 100.0)
        }

        // Target Dose Validation
        switch input.targetDose {
        case .mass(let m):
            guard m.value.isFinite && !m.value.isNaN else {
                throw ReconstitutionCalculationError.nonFiniteValue(field: "Target Dose Mass")
            }
            guard m.value > 0 else {
                throw ReconstitutionCalculationError.nonPositiveTargetDose(received: m.value)
            }
        case .volume(let v):
            guard v.value.isFinite && !v.value.isNaN else {
                throw ReconstitutionCalculationError.nonFiniteValue(field: "Target Dose Volume")
            }
            guard v.value > 0 else {
                throw ReconstitutionCalculationError.nonPositiveTargetDose(received: v.value)
            }
        case .syringeUnits(let units, _):
            guard units.isFinite && !units.isNaN else {
                throw ReconstitutionCalculationError.nonFiniteValue(field: "Syringe Units")
            }
            guard units > 0 else {
                throw ReconstitutionCalculationError.nonPositiveSyringeUnits(received: units)
            }
        case .biologicalActivity(let iu):
            guard iu.isFinite && !iu.isNaN else {
                throw ReconstitutionCalculationError.nonFiniteValue(field: "Biological Activity (IU)")
            }
            guard iu > 0 else {
                throw ReconstitutionCalculationError.nonPositiveTargetDose(received: iu)
            }
            guard input.compoundActivity != nil else {
                throw ReconstitutionCalculationError.missingBiologicalConversionRatio(compoundName: input.compoundName)
            }
        }
    }

    // MARK: - 2. Forward Reconstitution Calculation

    /// Performs complete forward reconstitution analysis with unit normalization, dimensional validation,
    /// syringe geometry, economics, and step-by-step mathematical derivation.
    public func calculate(_ input: ReconstitutionInput) throws -> ReconstitutionResult {
        // 1. Dimensional Validation
        try validate(input)

        // 2. Unit Normalization to Canonical Units
        let dryMassMg = input.dryMass.mg
        let diluentVolumeMl = input.diluentVolume.ml

        guard diluentVolumeMl > 0 else {
            throw ReconstitutionCalculationError.divisionByZero(formula: "Concentration = Dry Mass / Diluent Volume")
        }

        // 3. Solution Concentration
        let concentrationMgMl = dryMassMg / diluentVolumeMl
        let concentrationMcgMl = concentrationMgMl * 1000.0
        let concentrationIuMl: Double? = input.compoundActivity.map { $0.mgToIu(concentrationMgMl) }

        // 4. Target Dose Normalization
        let targetDoseMg: Double
        let targetDoseMcg: Double
        let targetDoseIu: Double?

        switch input.targetDose {
        case .mass(let m):
            targetDoseMg = m.mg
            targetDoseMcg = m.mcg
            targetDoseIu = input.compoundActivity.map { $0.mgToIu(m.mg) }

        case .biologicalActivity(let iu):
            guard let activity = input.compoundActivity else {
                throw ReconstitutionCalculationError.missingBiologicalConversionRatio(compoundName: input.compoundName)
            }
            targetDoseIu = iu
            targetDoseMg = activity.iuToMg(iu)
            targetDoseMcg = targetDoseMg * 1000.0

        case .volume(let v):
            let volMl = v.ml
            targetDoseMg = volMl * concentrationMgMl
            targetDoseMcg = targetDoseMg * 1000.0
            targetDoseIu = input.compoundActivity.map { $0.mgToIu(targetDoseMg) }

        case .syringeUnits(let units, let syringeType):
            let volMl = syringeType.volumeMl(forUnits: units)
            targetDoseMg = volMl * concentrationMgMl
            targetDoseMcg = targetDoseMg * 1000.0
            targetDoseIu = input.compoundActivity.map { $0.mgToIu(targetDoseMg) }
        }

        guard concentrationMgMl > 0 else {
            throw ReconstitutionCalculationError.divisionByZero(formula: "Draw Volume = Target Dose / Concentration")
        }

        // 5. Draw Volume Calculation
        let drawVolumeMl = targetDoseMg / concentrationMgMl
        let drawVolumeMcl = drawVolumeMl * 1000.0

        // 6. Syringe Geometry & Representation
        let u100Units = drawVolumeMl * 100.0
        let u40Units = drawVolumeMl * 40.0
        let selectedSyringe = input.syringeSpecification
        let selectedUnits = selectedSyringe.type.units(forVolumeMl: drawVolumeMl)
        let fillFraction = selectedSyringe.barrelFillFraction(forVolumeMl: drawVolumeMl)
        let isWithinCapacity = selectedSyringe.isWithinCapacity(volumeMl: drawVolumeMl)

        let visualDescription = String(
            format: "Draw to the %.1f unit mark on a %@ syringe (%.3f mL).",
            selectedUnits,
            selectedSyringe.displayName,
            drawVolumeMl
        )

        // 7. Vial Yield & Economics
        let totalDosesInVial = dryMassMg / targetDoseMg
        let exactDosesCount = Int(floor(totalDosesInVial))
        let remainingResidualDose = totalDosesInVial - Double(exactDosesCount)

        let costPerDoseUsd: Double?
        let costPerMgUsd: Double?
        if let cost = input.vialCostUsd, cost > 0 {
            costPerDoseUsd = totalDosesInVial > 0 ? (cost / totalDosesInVial) : nil
            costPerMgUsd = dryMassMg > 0 ? (cost / dryMassMg) : nil
        } else {
            costPerDoseUsd = nil
            costPerMgUsd = nil
        }

        // 8. Warnings & Clinical Safety Checks
        var warnings: [CalculationWarning] = []

        if targetDoseMg > dryMassMg {
            warnings.append(CalculationWarning(
                id: "dose_exceeds_vial",
                title: "Dose Exceeds Vial Capacity",
                message: "Target dose (\(String(format: "%.2f", targetDoseMg)) mg) is greater than the total dry mass in the vial (\(String(format: "%.2f", dryMassMg)) mg).",
                severity: .critical
            ))
        }

        if !isWithinCapacity {
            warnings.append(CalculationWarning(
                id: "syringe_overflow",
                title: "Exceeds Syringe Barrel Capacity",
                message: "Draw volume (\(String(format: "%.3f", drawVolumeMl)) mL) exceeds the maximum volume of the selected \(selectedSyringe.displayName) syringe (\(String(format: "%.2f", selectedSyringe.barrelCapacityMl)) mL).",
                severity: .critical
            ))
        }

        if drawVolumeMl < 0.005 {
            warnings.append(CalculationWarning(
                id: "imprecise_draw_volume",
                title: "Very Small Draw Volume",
                message: "The calculated draw volume (\(String(format: "%.3f", drawVolumeMl)) mL / \(String(format: "%.1f", u100Units)) units) is below 0.005 mL. Consider adding more diluent (e.g. 2–3 mL) to improve measurement accuracy.",
                severity: .warning
            ))
        }

        if concentrationMgMl > 50.0 {
            warnings.append(CalculationWarning(
                id: "high_concentration",
                title: "High Solution Concentration",
                message: "Concentration is \(String(format: "%.1f", concentrationMgMl)) mg/mL. Highly concentrated peptide solutions may take longer to dissolve or exhibit higher viscosity.",
                severity: .info
            ))
        }

        // 9. Step-by-Step Derivation Audit Trail
        var steps: [DerivationStep] = []

        // Step 1: Unit Normalization
        steps.append(DerivationStep(
            stepIndex: 1,
            title: "Input Parameter Normalization",
            formula: "Mass_{mg} = Mass_{raw} × k_{mass}, Volume_{mL} = Volume_{raw} × k_{vol}",
            substitution: "Dry Mass = \(input.dryMass.formattedDescription) → \(String(format: "%.3g", dryMassMg)) mg; Diluent = \(input.diluentVolume.formattedDescription) → \(String(format: "%.3g", diluentVolumeMl)) mL",
            evaluatedResult: "\(String(format: "%.2f", dryMassMg)) mg powder dissolved in \(String(format: "%.2f", diluentVolumeMl)) mL diluent",
            clinicalNote: "Quantities converted to canonical milligrams (mg) and milliliters (mL)."
        ))

        // Step 2: Concentration
        steps.append(DerivationStep(
            stepIndex: 2,
            title: "Reconstituted Solution Concentration",
            formula: "Concentration (C) = Dry Mass (mg) ÷ Diluent Volume (mL)",
            substitution: "C = \(String(format: "%.3g", dryMassMg)) mg ÷ \(String(format: "%.3g", diluentVolumeMl)) mL",
            evaluatedResult: "\(String(format: "%.3f", concentrationMgMl)) mg/mL (\(String(format: "%.1f", concentrationMcgMl)) mcg/mL)",
            clinicalNote: "Each 1.0 mL of solution contains \(String(format: "%.2f", concentrationMgMl)) mg (\(Int(concentrationMcgMl)) mcg) of active peptide."
        ))

        // Step 3: Dose Normalization
        let doseSubText: String
        if let iu = targetDoseIu {
            doseSubText = "Dose = \(input.targetDose.formattedDescription) → \(String(format: "%.3g", targetDoseMg)) mg (\(String(format: "%.1f", targetDoseMcg)) mcg / \(String(format: "%.2g", iu)) IU)"
        } else {
            doseSubText = "Dose = \(input.targetDose.formattedDescription) → \(String(format: "%.3g", targetDoseMg)) mg (\(String(format: "%.1f", targetDoseMcg)) mcg)"
        }

        steps.append(DerivationStep(
            stepIndex: 3,
            title: "Target Dose Normalization",
            formula: "Target Dose (D) in Milligrams (mg)",
            substitution: doseSubText,
            evaluatedResult: "\(String(format: "%.3g", targetDoseMg)) mg (\(String(format: "%.1f", targetDoseMcg)) mcg)",
            clinicalNote: nil
        ))

        // Step 4: Draw Volume
        steps.append(DerivationStep(
            stepIndex: 4,
            title: "Required Liquid Draw Volume",
            formula: "Draw Volume (V) = Target Dose (mg) ÷ Concentration (mg/mL)",
            substitution: "V = \(String(format: "%.3g", targetDoseMg)) mg ÷ \(String(format: "%.3f", concentrationMgMl)) mg/mL",
            evaluatedResult: "\(String(format: "%.4f", drawVolumeMl)) mL (\(String(format: "%.1f", drawVolumeMcl)) µL)",
            clinicalNote: "Volume of liquid required to deliver the exact prescribed dose."
        ))

        // Step 5: Syringe Calibration
        steps.append(DerivationStep(
            stepIndex: 5,
            title: "Syringe Scale Calibration",
            formula: "Syringe Units = Draw Volume (mL) × Syringe Units Per mL",
            substitution: "Units = \(String(format: "%.4f", drawVolumeMl)) mL × \(Int(selectedSyringe.type.unitsPerMl)) units/mL (\(selectedSyringe.type.rawValue))",
            evaluatedResult: "\(String(format: "%.1f", selectedUnits)) units on \(selectedSyringe.displayName)",
            clinicalNote: "On standard U-100 syringes, 1 unit = 0.01 mL (10 µL). On U-40 syringes, 1 unit = 0.025 mL (25 µL)."
        ))

        // Step 6: Vial Yield & Economics
        let costSubText = costPerDoseUsd.map { String(format: "; Cost/Dose = $%.2f", $0) } ?? ""
        steps.append(DerivationStep(
            stepIndex: 6,
            title: "Vial Yield & Economics",
            formula: "Total Doses = Dry Mass (mg) ÷ Target Dose (mg)",
            substitution: "Total Doses = \(String(format: "%.3g", dryMassMg)) mg ÷ \(String(format: "%.3g", targetDoseMg)) mg\(costSubText)",
            evaluatedResult: "\(String(format: "%.1f", totalDosesInVial)) total doses (\(exactDosesCount) complete administrations)",
            clinicalNote: remainingResidualDose > 0.05 ? "Residual vial volume after \(exactDosesCount) doses: \(String(format: "%.2f", remainingResidualDose * drawVolumeMl)) mL." : nil
        ))

        // 10. Markdown Summary Explanation
        let summary = """
        **Reconstitution Breakdown for \(input.compoundName ?? "Compound")**:
        - **Vial Solution**: \(String(format: "%.1f", dryMassMg)) mg dissolved in \(String(format: "%.1f", diluentVolumeMl)) mL \(input.diluentType.shortName) yields a concentration of **\(String(format: "%.2f", concentrationMgMl)) mg/mL** (\(Int(concentrationMcgMl)) mcg/mL).
        - **Target Dose**: For a **\(String(format: "%.0f", targetDoseMcg)) mcg** (\(String(format: "%.3g", targetDoseMg)) mg) dose, draw **\(String(format: "%.3f", drawVolumeMl)) mL**.
        - **Syringe Mark**: Draw to the **\(String(format: "%.1f", selectedUnits)) unit mark** on a standard \(selectedSyringe.displayName) syringe.
        - **Vial Yield**: Yields approximately **\(Int(totalDosesInVial)) doses** per vial\(costPerDoseUsd.map { String(format: " ($%.2f per dose)", $0) } ?? "").
        """

        // 11. Step-by-Step Clinical Instructions
        var instructions: [String] = []
        instructions.append("Wipe the rubber stopper of the vial with a sterile alcohol prep pad.")
        instructions.append("Using a mixing syringe, draw \(String(format: "%.1f", diluentVolumeMl)) mL of \(input.diluentType.shortName).")
        instructions.append("Insert the needle and aim against the inside glass wall of the vial. Depress the plunger slowly. Do NOT shake.")
        instructions.append("Swirl the vial gently until the lyophilized powder is completely dissolved and the solution is clear.")
        instructions.append("To administer your \(String(format: "%.0f", targetDoseMcg)) mcg dose, draw to the \(String(format: "%.1f", u100Units)) unit mark on a U-100 syringe (\(String(format: "%.3f", drawVolumeMl)) mL).")
        instructions.append("Store the reconstituted vial in the refrigerator at 2–8°C.")

        return ReconstitutionResult(
            concentrationMgMl: concentrationMgMl,
            concentrationMcgMl: concentrationMcgMl,
            concentrationIuMl: concentrationIuMl,
            normalizedDoseMg: targetDoseMg,
            normalizedDoseMcg: targetDoseMcg,
            normalizedDoseIu: targetDoseIu,
            drawVolumeMl: drawVolumeMl,
            drawVolumeMcl: drawVolumeMcl,
            u100Units: u100Units,
            u40Units: u40Units,
            selectedSyringeUnits: selectedUnits,
            selectedSyringe: selectedSyringe,
            syringeBarrelFillFraction: fillFraction,
            isWithinSyringeCapacity: isWithinCapacity,
            syringeVisualDescription: visualDescription,
            totalDosesInVial: totalDosesInVial,
            exactDosesCount: exactDosesCount,
            remainingResidualDose: remainingResidualDose,
            costPerDoseUsd: costPerDoseUsd,
            costPerMgUsd: costPerMgUsd,
            derivationSteps: steps,
            summaryExplanation: summary,
            clinicalInstructions: instructions,
            warnings: warnings
        )
    }

    // MARK: - 3. Diluent Volume Solver

    /// Solves for the exact diluent volume required to achieve a desired syringe tick mark for a given target dose.
    public func solveRequiredDiluentVolume(_ input: DiluentSolverInput) throws -> DiluentSolverResult {
        guard input.dryMass.value > 0 else {
            throw ReconstitutionCalculationError.nonPositiveDryMass(received: input.dryMass.value)
        }
        guard input.desiredSyringeUnits > 0 else {
            throw ReconstitutionCalculationError.nonPositiveSyringeUnits(received: input.desiredSyringeUnits)
        }

        let dryMassMg = input.dryMass.mg
        let targetDoseMg: Double
        let targetDoseMcg: Double

        switch input.targetDose {
        case .mass(let m):
            targetDoseMg = m.mg
            targetDoseMcg = m.mcg
        case .biologicalActivity(let iu):
            guard let activity = input.compoundActivity else {
                throw ReconstitutionCalculationError.missingBiologicalConversionRatio(compoundName: nil)
            }
            targetDoseMg = activity.iuToMg(iu)
            targetDoseMcg = targetDoseMg * 1000.0
        case .volume(let v):
            targetDoseMg = v.ml
            targetDoseMcg = targetDoseMg * 1000.0
        case .syringeUnits(let u, let sType):
            targetDoseMg = sType.volumeMl(forUnits: u)
            targetDoseMcg = targetDoseMg * 1000.0
        }

        guard targetDoseMg > 0 else {
            throw ReconstitutionCalculationError.nonPositiveTargetDose(received: targetDoseMg)
        }

        // Draw Volume in mL for the desired syringe units
        let drawVolumeMl = input.syringeType.volumeMl(forUnits: input.desiredSyringeUnits)

        guard drawVolumeMl > 0 else {
            throw ReconstitutionCalculationError.divisionByZero(formula: "Required Concentration = Target Dose / Draw Volume")
        }

        // Target Concentration
        let targetConcentrationMgMl = targetDoseMg / drawVolumeMl
        let targetConcentrationMcgMl = targetConcentrationMgMl * 1000.0

        // Required Diluent Volume = Dry Mass / Target Concentration
        let recommendedDiluentVolumeMl = dryMassMg / targetConcentrationMgMl
        let totalDosesInVial = dryMassMg / targetDoseMg

        let costPerDoseUsd: Double?
        if let cost = input.vialCostUsd, cost > 0, totalDosesInVial > 0 {
            costPerDoseUsd = cost / totalDosesInVial
        } else {
            costPerDoseUsd = nil
        }

        var warnings: [CalculationWarning] = []
        if recommendedDiluentVolumeMl > 10.0 {
            warnings.append(CalculationWarning(
                id: "large_diluent_volume",
                title: "Large Diluent Volume",
                message: "Calculated diluent volume (\(String(format: "%.1f", recommendedDiluentVolumeMl)) mL) may exceed standard 2–10 mL vial capacities.",
                severity: .warning
            ))
        }
        if recommendedDiluentVolumeMl < 0.5 {
            warnings.append(CalculationWarning(
                id: "small_diluent_volume",
                title: "Small Diluent Volume",
                message: "Calculated diluent volume (\(String(format: "%.2f", recommendedDiluentVolumeMl)) mL) is very small and may lead to high solution viscosity.",
                severity: .warning
            ))
        }

        let steps: [DerivationStep] = [
            DerivationStep(
                stepIndex: 1,
                title: "Syringe Volume Conversion",
                formula: "Desired Draw Volume (V) = Syringe Units ÷ Syringe Units/mL",
                substitution: "V = \(String(format: "%.1f", input.desiredSyringeUnits)) units ÷ \(Int(input.syringeType.unitsPerMl)) units/mL",
                evaluatedResult: "\(String(format: "%.3f", drawVolumeMl)) mL",
                clinicalNote: "Target liquid draw volume for desired syringe mark."
            ),
            DerivationStep(
                stepIndex: 2,
                title: "Required Solution Concentration",
                formula: "Target Concentration (C) = Target Dose (mg) ÷ Draw Volume (mL)",
                substitution: "C = \(String(format: "%.3g", targetDoseMg)) mg ÷ \(String(format: "%.3f", drawVolumeMl)) mL",
                evaluatedResult: "\(String(format: "%.3f", targetConcentrationMgMl)) mg/mL (\(String(format: "%.1f", targetConcentrationMcgMl)) mcg/mL)",
                clinicalNote: "Concentration needed to deliver prescribed dose in \(String(format: "%.3f", drawVolumeMl)) mL."
            ),
            DerivationStep(
                stepIndex: 3,
                title: "Required Diluent Volume Solver",
                formula: "Diluent Volume = Total Dry Mass (mg) ÷ Target Concentration (mg/mL)",
                substitution: "Volume = \(String(format: "%.3g", dryMassMg)) mg ÷ \(String(format: "%.3f", targetConcentrationMgMl)) mg/mL",
                evaluatedResult: "\(String(format: "%.2f", recommendedDiluentVolumeMl)) mL diluent",
                clinicalNote: "Add exactly this amount of diluent to the vial."
            )
        ]

        let summary = "To draw exactly \(String(format: "%.1f", input.desiredSyringeUnits)) units for a \(String(format: "%.0f", targetDoseMcg)) mcg dose, add **\(String(format: "%.2f", recommendedDiluentVolumeMl)) mL** of diluent to your \(String(format: "%.1f", dryMassMg)) mg vial."

        return DiluentSolverResult(
            recommendedDiluentVolumeMl: recommendedDiluentVolumeMl,
            resultingConcentrationMgMl: targetConcentrationMgMl,
            resultingConcentrationMcgMl: targetConcentrationMcgMl,
            targetDoseMg: targetDoseMg,
            targetDoseMcg: targetDoseMcg,
            drawVolumeMl: drawVolumeMl,
            syringeUnits: input.desiredSyringeUnits,
            totalDosesInVial: totalDosesInVial,
            costPerDoseUsd: costPerDoseUsd,
            derivationSteps: steps,
            summaryExplanation: summary,
            warnings: warnings
        )
    }

    // MARK: - 4. Reverse Syringe Dose Calculator

    /// Calculates the exact administered dose in mcg, mg, and IU given syringe units drawn and vial concentration.
    public func reverseCalculateDoseFromSyringe(_ input: ReverseDoseInput) throws -> ReverseDoseResult {
        guard input.drawnSyringeUnits > 0 else {
            throw ReconstitutionCalculationError.nonPositiveSyringeUnits(received: input.drawnSyringeUnits)
        }
        guard input.concentrationMgMl > 0 else {
            throw ReconstitutionCalculationError.divisionByZero(formula: "Dose = Volume × Concentration")
        }

        let volumeMl = input.syringeType.volumeMl(forUnits: input.drawnSyringeUnits)
        let doseMg = volumeMl * input.concentrationMgMl
        let doseMcg = doseMg * 1000.0
        let doseIu = input.compoundActivity.map { $0.mgToIu(doseMg) }

        let steps: [DerivationStep] = [
            DerivationStep(
                stepIndex: 1,
                title: "Drawn Volume Conversion",
                formula: "Liquid Volume (V) = Syringe Units ÷ Syringe Calibration (Units/mL)",
                substitution: "V = \(String(format: "%.1f", input.drawnSyringeUnits)) units ÷ \(Int(input.syringeType.unitsPerMl)) units/mL",
                evaluatedResult: "\(String(format: "%.4f", volumeMl)) mL (\(String(format: "%.1f", volumeMl * 1000.0)) µL)"
            ),
            DerivationStep(
                stepIndex: 2,
                title: "Administered Dose Calculation",
                formula: "Dose (mg) = Liquid Volume (mL) × Concentration (mg/mL)",
                substitution: "Dose = \(String(format: "%.4f", volumeMl)) mL × \(String(format: "%.3f", input.concentrationMgMl)) mg/mL",
                evaluatedResult: "\(String(format: "%.4g", doseMg)) mg (\(String(format: "%.1f", doseMcg)) mcg)"
            )
        ]

        let summary = "Drawing \(String(format: "%.1f", input.drawnSyringeUnits)) units on a \(input.syringeType.rawValue) syringe from a \(String(format: "%.2f", input.concentrationMgMl)) mg/mL vial delivers **\(String(format: "%.1f", doseMcg)) mcg** (\(String(format: "%.3g", doseMg)) mg)."

        return ReverseDoseResult(
            drawnVolumeMl: volumeMl,
            administeredDoseMg: doseMg,
            administeredDoseMcg: doseMcg,
            administeredDoseIu: doseIu,
            derivationSteps: steps,
            summaryExplanation: summary
        )
    }

    // MARK: - 5. Backwards Compatibility Convenience Method

    /// Legacy convenience calculation matching the original signature with safe fallback.
    public func calculate(
        dryMassMg: Double,
        diluentVolumeMl: Double,
        targetDoseAmount: Double,
        targetDoseUnit: DoseUnit,
        vialCostUsd: Double? = nil
    ) -> ReconstitutionResult {
        let input = ReconstitutionInput(
            dryMassMg: dryMassMg,
            diluentVolumeMl: diluentVolumeMl,
            targetDoseAmount: targetDoseAmount,
            targetDoseUnit: targetDoseUnit,
            vialCostUsd: vialCostUsd
        )

        do {
            return try calculate(input)
        } catch {
            // Safe fallback for UI rendering when user is actively typing partial values
            let concMg = diluentVolumeMl > 0 ? (dryMassMg / diluentVolumeMl) : 0
            let concMcg = concMg * 1000.0
            let doseMg = targetDoseUnit == .mg ? targetDoseAmount : (targetDoseUnit == .mcg ? targetDoseAmount / 1000.0 : targetDoseAmount / 3.0)
            let drawMl = concMg > 0 ? (doseMg / concMg) : 0

            return ReconstitutionResult(
                concentrationMgMl: concMg,
                concentrationMcgMl: concMcg,
                normalizedDoseMg: doseMg,
                normalizedDoseMcg: doseMg * 1000.0,
                drawVolumeMl: drawMl,
                drawVolumeMcl: drawMl * 1000.0,
                u100Units: drawMl * 100.0,
                u40Units: drawMl * 40.0,
                selectedSyringeUnits: drawMl * 100.0,
                selectedSyringe: .u100_100unit,
                syringeBarrelFillFraction: drawMl / 1.0,
                isWithinSyringeCapacity: drawMl <= 1.0,
                syringeVisualDescription: "Draw to the \(String(format: "%.1f", drawMl * 100.0)) unit mark.",
                totalDosesInVial: doseMg > 0 ? (dryMassMg / doseMg) : 0,
                exactDosesCount: Int(floor(doseMg > 0 ? (dryMassMg / doseMg) : 0)),
                remainingResidualDose: 0,
                costPerDoseUsd: nil,
                costPerMgUsd: nil,
                derivationSteps: [],
                summaryExplanation: error.localizedDescription,
                clinicalInstructions: [],
                warnings: [CalculationWarning(id: "calc_err", title: "Calculation Warning", message: error.localizedDescription, severity: .warning)]
            )
        }
    }

    /// Converts U-100 units drawn back to actual administered dose amount in desired DoseUnit.
    public func reverseCalculateDose(
        u100Units: Double,
        concentrationMgMl: Double,
        desiredUnit: DoseUnit = .mcg
    ) -> Double {
        let input = ReverseDoseInput(
            drawnSyringeUnits: u100Units,
            syringeType: .u100,
            concentrationMgMl: concentrationMgMl
        )
        guard let result = try? reverseCalculateDoseFromSyringe(input) else { return 0 }
        switch desiredUnit {
        case .mg: return result.administeredDoseMg
        case .mcg: return result.administeredDoseMcg
        case .iu: return result.administeredDoseIu ?? (result.administeredDoseMg * 3.0)
        case .ml: return result.drawnVolumeMl
        }
    }
}
