import Vapor
import Fluent
import Domain
import CalculationEngine

public struct CalculationController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let calcGroup = routes.grouped("calculations")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        calcGroup.post("reconstitute", use: calculateReconstitution)
        calcGroup.post("solve-diluent", use: solveDiluentVolume)
        calcGroup.post("reverse-dose", use: reverseCalculateDose)
    }

    // MARK: - 1. Forward Reconstitution Calculation
    public func calculateReconstitution(req: Request) async throws -> CalculationResultResponseDTO {
        let dto = try req.content.decode(ReconstitutionCalculationRequestDTO.self)
        let calculator = ReconstitutionCalculator()

        let massUnit = MassUnit(rawValue: dto.dryMassUnit?.lowercased() ?? "mg") ?? .mg
        let volumeUnit = VolumeUnit(rawValue: dto.diluentVolumeUnit?.lowercased() ?? "ml") ?? .ml
        let syringeType = SyringeType(rawValue: dto.syringeType?.uppercased() ?? "U-100") ?? .u100
        let barrelCap = dto.syringeBarrelCapacityMl ?? 1.0
        let syringeSpec = SyringeSpecification(type: syringeType, barrelCapacityMl: barrelCap)

        let targetDoseQuantity: DoseQuantity
        let doseUnitStr = dto.targetDoseUnit.lowercased()
        if doseUnitStr == "iu" {
            targetDoseQuantity = .biologicalActivity(iu: dto.targetDoseAmount)
        } else if doseUnitStr == "ml" {
            targetDoseQuantity = .volume(VolumeQuantity(dto.targetDoseAmount, .ml))
        } else if doseUnitStr == "units" || doseUnitStr == "u100" {
            targetDoseQuantity = .syringeUnits(units: dto.targetDoseAmount, syringeType: .u100)
        } else if doseUnitStr == "mg" {
            targetDoseQuantity = .mass(MassQuantity(dto.targetDoseAmount, .mg))
        } else {
            targetDoseQuantity = .mass(MassQuantity(dto.targetDoseAmount, .mcg))
        }

        let activityRatio = dto.iuPerMg.map { CompoundActivityRatio(iuPerMg: $0) }

        let input = ReconstitutionInput(
            dryMass: MassQuantity(dto.dryMassAmount, massUnit),
            diluentVolume: VolumeQuantity(dto.diluentVolumeAmount, volumeUnit),
            targetDose: targetDoseQuantity,
            syringeSpecification: syringeSpec,
            diluentType: .bacteriostaticWater,
            vialCostUsd: dto.vialCostUsd,
            compoundActivity: activityRatio,
            compoundName: dto.compoundName
        )

        do {
            let result = try calculator.calculate(input)
            return CalculationResultResponseDTO(from: result)
        } catch let err as ReconstitutionCalculationError {
            throw Abort(.badRequest, reason: err.localizedDescription)
        } catch {
            throw Abort(.badRequest, reason: error.localizedDescription)
        }
    }

    // MARK: - 2. Diluent Solver
    public func solveDiluentVolume(req: Request) async throws -> DiluentSolverResponseDTO {
        let dto = try req.content.decode(DiluentSolverRequestDTO.self)
        let calculator = ReconstitutionCalculator()

        let massUnit = MassUnit(rawValue: dto.dryMassUnit?.lowercased() ?? "mg") ?? .mg
        let syringeType = SyringeType(rawValue: dto.syringeType?.uppercased() ?? "U-100") ?? .u100

        let targetDoseQuantity: DoseQuantity
        if dto.targetDoseUnit.lowercased() == "mg" {
            targetDoseQuantity = .mass(MassQuantity(dto.targetDoseAmount, .mg))
        } else if dto.targetDoseUnit.lowercased() == "iu" {
            targetDoseQuantity = .biologicalActivity(iu: dto.targetDoseAmount)
        } else {
            targetDoseQuantity = .mass(MassQuantity(dto.targetDoseAmount, .mcg))
        }

        let activityRatio = dto.iuPerMg.map { CompoundActivityRatio(iuPerMg: $0) }

        let input = DiluentSolverInput(
            dryMass: MassQuantity(dto.dryMassAmount, massUnit),
            targetDose: targetDoseQuantity,
            desiredSyringeUnits: dto.desiredSyringeUnits,
            syringeType: syringeType,
            compoundActivity: activityRatio,
            vialCostUsd: dto.vialCostUsd
        )

        do {
            let result = try calculator.solveRequiredDiluentVolume(input)
            return DiluentSolverResponseDTO(from: result)
        } catch let err as ReconstitutionCalculationError {
            throw Abort(.badRequest, reason: err.localizedDescription)
        } catch {
            throw Abort(.badRequest, reason: error.localizedDescription)
        }
    }

    // MARK: - 3. Reverse Dose Solver
    public func reverseCalculateDose(req: Request) async throws -> ReverseDoseResponseDTO {
        let dto = try req.content.decode(ReverseDoseRequestDTO.self)
        let calculator = ReconstitutionCalculator()
        let syringeType = SyringeType(rawValue: dto.syringeType?.uppercased() ?? "U-100") ?? .u100
        let activityRatio = dto.iuPerMg.map { CompoundActivityRatio(iuPerMg: $0) }

        let input = ReverseDoseInput(
            drawnSyringeUnits: dto.drawnSyringeUnits,
            syringeType: syringeType,
            concentrationMgMl: dto.concentrationMgMl,
            compoundActivity: activityRatio
        )

        do {
            let result = try calculator.reverseCalculateDoseFromSyringe(input)
            return ReverseDoseResponseDTO(from: result)
        } catch let err as ReconstitutionCalculationError {
            throw Abort(.badRequest, reason: err.localizedDescription)
        } catch {
            throw Abort(.badRequest, reason: error.localizedDescription)
        }
    }
}

// MARK: - Request & Response DTOs

public struct ReconstitutionCalculationRequestDTO: Content {
    public var dryMassAmount: Double
    public var dryMassUnit: String?
    public var diluentVolumeAmount: Double
    public var diluentVolumeUnit: String?
    public var targetDoseAmount: Double
    public var targetDoseUnit: String
    public var syringeType: String?
    public var syringeBarrelCapacityMl: Double?
    public var vialCostUsd: Double?
    public var iuPerMg: Double?
    public var compoundName: String?
}

public struct CalculationResultResponseDTO: Content {
    public let concentrationMgMl: Double
    public let concentrationMcgMl: Double
    public let concentrationIuMl: Double?
    public let normalizedDoseMg: Double
    public let normalizedDoseMcg: Double
    public let normalizedDoseIu: Double?
    public let drawVolumeMl: Double
    public let drawVolumeMcl: Double
    public let u100Units: Double
    public let u40Units: Double
    public let selectedSyringeUnits: Double
    public let totalDosesInVial: Double
    public let exactDosesCount: Int
    public let costPerDoseUsd: Double?
    public let costPerMgUsd: Double?
    public let summaryExplanation: String
    public let clinicalInstructions: [String]
    public let warnings: [CalculationWarningDTO]
    public let derivationSteps: [DerivationStepDTO]

    public init(from res: ReconstitutionResult) {
        self.concentrationMgMl = res.concentrationMgMl
        self.concentrationMcgMl = res.concentrationMcgMl
        self.concentrationIuMl = res.concentrationIuMl
        self.normalizedDoseMg = res.normalizedDoseMg
        self.normalizedDoseMcg = res.normalizedDoseMcg
        self.normalizedDoseIu = res.normalizedDoseIu
        self.drawVolumeMl = res.drawVolumeMl
        self.drawVolumeMcl = res.drawVolumeMcl
        self.u100Units = res.u100Units
        self.u40Units = res.u40Units
        self.selectedSyringeUnits = res.selectedSyringeUnits
        self.totalDosesInVial = res.totalDosesInVial
        self.exactDosesCount = res.exactDosesCount
        self.costPerDoseUsd = res.costPerDoseUsd
        self.costPerMgUsd = res.costPerMgUsd
        self.summaryExplanation = res.summaryExplanation
        self.clinicalInstructions = res.clinicalInstructions
        self.warnings = res.warnings.map { CalculationWarningDTO(id: $0.id, title: $0.title, message: $0.message, severity: $0.severity.rawValue) }
        self.derivationSteps = res.derivationSteps.map { DerivationStepDTO(stepIndex: $0.stepIndex, title: $0.title, formula: $0.formula, substitution: $0.substitution, evaluatedResult: $0.evaluatedResult, clinicalNote: $0.clinicalNote) }
    }
}

public struct DiluentSolverRequestDTO: Content {
    public var dryMassAmount: Double
    public var dryMassUnit: String?
    public var targetDoseAmount: Double
    public var targetDoseUnit: String
    public var desiredSyringeUnits: Double
    public var syringeType: String?
    public var iuPerMg: Double?
    public var vialCostUsd: Double?
}

public struct DiluentSolverResponseDTO: Content {
    public let recommendedDiluentVolumeMl: Double
    public let resultingConcentrationMgMl: Double
    public let resultingConcentrationMcgMl: Double
    public let targetDoseMg: Double
    public let targetDoseMcg: Double
    public let drawVolumeMl: Double
    public let syringeUnits: Double
    public let totalDosesInVial: Double
    public let costPerDoseUsd: Double?
    public let summaryExplanation: String
    public let derivationSteps: [DerivationStepDTO]

    public init(from res: DiluentSolverResult) {
        self.recommendedDiluentVolumeMl = res.recommendedDiluentVolumeMl
        self.resultingConcentrationMgMl = res.resultingConcentrationMgMl
        self.resultingConcentrationMcgMl = res.resultingConcentrationMcgMl
        self.targetDoseMg = res.targetDoseMg
        self.targetDoseMcg = res.targetDoseMcg
        self.drawVolumeMl = res.drawVolumeMl
        self.syringeUnits = res.syringeUnits
        self.totalDosesInVial = res.totalDosesInVial
        self.costPerDoseUsd = res.costPerDoseUsd
        self.summaryExplanation = res.summaryExplanation
        self.derivationSteps = res.derivationSteps.map { DerivationStepDTO(stepIndex: $0.stepIndex, title: $0.title, formula: $0.formula, substitution: $0.substitution, evaluatedResult: $0.evaluatedResult, clinicalNote: $0.clinicalNote) }
    }
}

public struct ReverseDoseRequestDTO: Content {
    public var drawnSyringeUnits: Double
    public var syringeType: String?
    public var concentrationMgMl: Double
    public var iuPerMg: Double?
}

public struct ReverseDoseResponseDTO: Content {
    public let drawnVolumeMl: Double
    public let administeredDoseMg: Double
    public let administeredDoseMcg: Double
    public let administeredDoseIu: Double?
    public let summaryExplanation: String
    public let derivationSteps: [DerivationStepDTO]

    public init(from res: ReverseDoseResult) {
        self.drawnVolumeMl = res.drawnVolumeMl
        self.administeredDoseMg = res.administeredDoseMg
        self.administeredDoseMcg = res.administeredDoseMcg
        self.administeredDoseIu = res.administeredDoseIu
        self.summaryExplanation = res.summaryExplanation
        self.derivationSteps = res.derivationSteps.map { DerivationStepDTO(stepIndex: $0.stepIndex, title: $0.title, formula: $0.formula, substitution: $0.substitution, evaluatedResult: $0.evaluatedResult, clinicalNote: $0.clinicalNote) }
    }
}

public struct CalculationWarningDTO: Content {
    public let id: String
    public let title: String
    public let message: String
    public let severity: String
}

public struct DerivationStepDTO: Content {
    public let stepIndex: Int
    public let title: String
    public let formula: String
    public let substitution: String
    public let evaluatedResult: String
    public let clinicalNote: String?
}
