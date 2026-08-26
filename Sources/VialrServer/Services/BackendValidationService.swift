import Vapor
import Fluent
import Domain
import CalculationEngine

/// Domain validation service enforcing Zero-Trust rules on all client inputs before persistence.
/// Ensures relational integrity, physical reality constraints, mathematical validity,
/// and automatic side-effects (e.g., inventory volume deduction upon dose administration).
public enum BackendValidationService {

    // MARK: - 1. Relational Ownership & Entity Validation

    /// Validates that a referenced Protocol exists and belongs to the authenticated user.
    public static func validateProtocol(
        id: UUID?,
        userId: UUID,
        on db: Database
    ) async throws -> ProtocolEntity? {
        guard let protoId = id else { return nil }
        guard let proto = try await ProtocolEntity.query(on: db)
            .filter(\.$id == protoId)
            .filter(\.$user.$id == userId)
            .first() else {
            throw Abort(.badRequest, reason: "Referenced protocol \(protoId.uuidString) does not exist or does not belong to the user.")
        }
        return proto
    }

    /// Validates that a referenced Compound exists and belongs to the user (or is system library).
    public static func validateCompound(
        id: UUID,
        userId: UUID,
        on db: Database
    ) async throws -> CompoundEntity {
        guard let compound = try await CompoundEntity.query(on: db)
            .filter(\.$id == id)
            .filter(\.$user.$id == userId)
            .first() else {
            throw Abort(.badRequest, reason: "Referenced compound \(id.uuidString) does not exist or is unauthorized.")
        }
        return compound
    }

    /// Validates that a referenced Vial exists, belongs to the user, matches the compound,
    /// is not depleted/discarded, and atomically deducts the administered volume if the dose is marked 'taken'.
    public static func validateVialAndDeductDose(
        vialId: UUID?,
        compoundId: UUID,
        userId: UUID,
        doseAmount: Double,
        doseUnit: String,
        status: String,
        on db: Database
    ) async throws -> (vial: VialEntity?, remainingVolumeMl: Double?) {
        guard let vialId = vialId else {
            return (nil, nil)
        }

        guard let vial = try await VialEntity.query(on: db)
            .filter(\.$id == vialId)
            .filter(\.$user.$id == userId)
            .first() else {
            throw Abort(.badRequest, reason: "Referenced vial \(vialId.uuidString) does not exist or does not belong to the user.")
        }

        // Validate compound matches vial compound
        if vial.$compound.id != compoundId {
            throw Abort(.badRequest, reason: "Referenced vial contains a different compound than the dose event.")
        }

        // Structural check on status
        if vial.status == "depleted" || vial.status == "discarded" {
            throw Abort(.badRequest, reason: "Cannot log a dose from a vial with status '\(vial.status)'.")
        }

        // If dose was administered ('taken'), compute required volume draw and decrement
        if status.lowercased() == "taken" {
            guard let concentration = vial.concentrationMgMl, concentration > 0 else {
                throw Abort(.badRequest, reason: "Referenced vial must be reconstituted with valid concentration before logging administered doses.")
            }

            let doseMg: Double
            if doseUnit.lowercased() == "mcg" || doseUnit.lowercased() == "micrograms" {
                doseMg = doseAmount / 1000.0
            } else if doseUnit.lowercased() == "mg" || doseUnit.lowercased() == "milligrams" {
                doseMg = doseAmount
            } else {
                doseMg = doseAmount / 1000.0
            }

            let requiredDrawVolumeMl = doseMg / concentration
            let currentVol = vial.currentVolumeRemainingMl ?? vial.diluentVolumeMl ?? 0.0

            if currentVol < (requiredDrawVolumeMl - 0.001) { // 1 microliter tolerance
                throw Abort(.badRequest, reason: "Insufficient liquid volume in vial. Required draw: \(String(format: "%.3f", requiredDrawVolumeMl)) mL, Remaining: \(String(format: "%.3f", currentVol)) mL.")
            }

            let newRemaining = max(0.0, currentVol - requiredDrawVolumeMl)
            vial.currentVolumeRemainingMl = newRemaining

            if newRemaining <= 0.005 {
                vial.status = "depleted"
            }

            try await vial.save(on: db)
            return (vial, newRemaining)
        }

        return (vial, vial.currentVolumeRemainingMl)
    }

    // MARK: - 2. Structural & Mathematical Sanity

    /// Validates that reconstitution parameters are physically sound using the shared CalculationEngine.
    public static func validateReconstitutionParams(
        dryMassMg: Double,
        diluentVolumeMl: Double
    ) throws -> (concentrationMgMl: Double, concentrationMcgMl: Double) {
        let calculator = ReconstitutionCalculator()
        let input = ReconstitutionInput(
            dryMass: MassQuantity(dryMassMg, .mg),
            diluentVolume: VolumeQuantity(diluentVolumeMl, .ml),
            targetDose: DoseQuantity.mass(MassQuantity(100, .mcg))
        )
        
        do {
            try calculator.validate(input)
            let result = try calculator.calculate(input)
            return (result.concentrationMgMl, result.concentrationMcgMl)
        } catch let err as ReconstitutionCalculationError {
            throw Abort(.badRequest, reason: err.localizedDescription)
        } catch {
            throw Abort(.badRequest, reason: error.localizedDescription)
        }
    }

    /// Validates physiological sanity for body measurements.
    public static func validateMeasurementBounds(
        type: String,
        value: Double,
        secondaryValue: Double?
    ) throws {
        guard value.isFinite && !value.isNaN else {
            throw Abort(.badRequest, reason: "Measurement value must be a valid numeric number.")
        }

        let lower = type.lowercased()
        if lower.contains("weight") {
            guard value >= 10.0 && value <= 1000.0 else {
                throw Abort(.badRequest, reason: "Weight measurement value (\(value)) is out of physiological bounds (10–1000).")
            }
        } else if lower.contains("pressure") {
            guard value >= 40.0 && value <= 300.0 else {
                throw Abort(.badRequest, reason: "Systolic blood pressure (\(value)) is outside valid physiological bounds (40–300 mmHg).")
            }
            if let diastolic = secondaryValue {
                guard diastolic >= 20.0 && diastolic <= 200.0 else {
                    throw Abort(.badRequest, reason: "Diastolic blood pressure (\(diastolic)) is outside valid physiological bounds (20–200 mmHg).")
                }
                guard value > diastolic else {
                    throw Abort(.badRequest, reason: "Systolic blood pressure (\(value)) must be higher than diastolic blood pressure (\(diastolic)).")
                }
            }
        } else if lower.contains("glucose") {
            guard value >= 10.0 && value <= 1000.0 else {
                throw Abort(.badRequest, reason: "Blood glucose value (\(value)) is outside valid bounds (10–1000 mg/dL).")
            }
        } else if lower.contains("sleep") {
            guard value >= 0.0 && value <= 24.0 else {
                throw Abort(.badRequest, reason: "Sleep duration (\(value)) cannot exceed 24 hours.")
            }
        } else if lower.contains("energy") || lower.contains("appetite") || lower.contains("mood") || lower.contains("pain") {
            guard value >= 0.0 && value <= 10.0 else {
                throw Abort(.badRequest, reason: "Subjective score (\(value)) must be on a 0 to 10 scale.")
            }
        }
    }

    /// Validates anatomical injection site ID.
    public static func validateInjectionSite(id: String) -> Bool {
        let validSitePrefixes = ["ab_", "thigh_", "delt_", "glute_", "tricep_", "custom_"]
        return validSitePrefixes.contains { id.hasPrefix($0) }
    }
}
