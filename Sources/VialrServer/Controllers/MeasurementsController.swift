import Vapor
import Fluent

public struct MeasurementsController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let measurementsGroup = routes.grouped("measurements")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        measurementsGroup.get(use: listMeasurements)
        measurementsGroup.post(use: createMeasurement)
        measurementsGroup.get("trends", use: getMeasurementTrends)
        measurementsGroup.get(":measurementId", use: getMeasurement)
        measurementsGroup.put(":measurementId", use: updateMeasurement)
        measurementsGroup.delete(":measurementId", use: deleteMeasurement)
    }

    public func listMeasurements(req: Request) async throws -> [MeasurementResponseDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let typeFilter = try? req.query.get(String.self, at: "type")

        var query = MeasurementEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)

        if let t = typeFilter, !t.isEmpty {
            query = query.filter(\.$type == t)
        }

        let measurements = try await query
            .sort(\.$dateRecorded, .descending)
            .all()

        return measurements.map { m in
            makeDTO(from: m)
        }
    }

    public func createMeasurement(req: Request) async throws -> MeasurementResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(MeasurementRequestDTO.self)

        // Zero-Trust Physiological Sanity Checks
        try BackendValidationService.validateMeasurementBounds(
            type: dto.type,
            value: dto.value,
            secondaryValue: dto.secondaryValue
        )

        // Status evaluation against reference ranges
        var status = "Optimal / Normal"
        if let min = dto.referenceRangeMin, dto.value < min {
            status = "Low"
        } else if let max = dto.referenceRangeMax, dto.value > max {
            status = "High"
        }

        let entityId = dto.id ?? UUID()
        let entity = MeasurementEntity(
            id: entityId,
            userId: payload.userId,
            associatedProtocolId: dto.associatedProtocolId,
            name: dto.name,
            type: dto.type,
            category: dto.category,
            value: dto.value,
            secondaryValue: dto.secondaryValue,
            unit: dto.unit,
            dateRecorded: dto.dateRecorded,
            source: dto.source ?? "Manual Entry",
            referenceRangeMin: dto.referenceRangeMin,
            referenceRangeMax: dto.referenceRangeMax,
            status: status,
            notes: dto.notes
        )
        try await entity.save(on: req.db)

        return makeDTO(from: entity)
    }

    public func getMeasurement(req: Request) async throws -> MeasurementResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let mId = req.parameters.get("measurementId", as: UUID.self),
              let m = try await MeasurementEntity.query(on: req.db)
                .filter(\.$id == mId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Measurement not found.")
        }

        return makeDTO(from: m)
    }

    public func updateMeasurement(req: Request) async throws -> MeasurementResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let mId = req.parameters.get("measurementId", as: UUID.self),
              let entity = try await MeasurementEntity.query(on: req.db)
                .filter(\.$id == mId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Measurement not found.")
        }

        let dto = try req.content.decode(MeasurementRequestDTO.self)
        try BackendValidationService.validateMeasurementBounds(
            type: dto.type,
            value: dto.value,
            secondaryValue: dto.secondaryValue
        )

        entity.name = dto.name
        entity.type = dto.type
        entity.category = dto.category
        entity.value = dto.value
        entity.secondaryValue = dto.secondaryValue
        entity.unit = dto.unit
        entity.dateRecorded = dto.dateRecorded
        entity.referenceRangeMin = dto.referenceRangeMin
        entity.referenceRangeMax = dto.referenceRangeMax
        entity.notes = dto.notes

        var status = "Optimal / Normal"
        if let min = dto.referenceRangeMin, dto.value < min {
            status = "Low"
        } else if let max = dto.referenceRangeMax, dto.value > max {
            status = "High"
        }
        entity.status = status

        try await entity.save(on: req.db)

        return makeDTO(from: entity)
    }

    public func deleteMeasurement(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let mId = req.parameters.get("measurementId", as: UUID.self),
              let entity = try await MeasurementEntity.query(on: req.db)
                .filter(\.$id == mId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Measurement not found.")
        }

        try await entity.delete(on: req.db)
        return .noContent
    }

    public func getMeasurementTrends(req: Request) async throws -> MeasurementTrendDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let type = try? req.query.get(String.self, at: "type") else {
            throw Abort(.badRequest, reason: "Query parameter 'type' is required (e.g. 'Body Weight', 'Blood Pressure').")
        }

        let entries = try await MeasurementEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .filter(\.$type == type)
            .sort(\.$dateRecorded, .ascending)
            .all()

        guard !entries.isEmpty else {
            return MeasurementTrendDTO(
                type: type,
                name: type,
                unit: "",
                count: 0,
                latestValue: 0,
                changeOverPeriod: 0,
                averageValue: 0,
                minValue: 0,
                maxValue: 0,
                entries: []
            )
        }

        let values = entries.map { $0.value }
        let latest = entries.last!.value
        let initial = entries.first!.value
        let total = values.reduce(0.0, +)
        let avg = total / Double(values.count)
        let minVal = values.min() ?? 0.0
        let maxVal = values.max() ?? 0.0
        let change = latest - initial

        let dtos = entries.map { makeDTO(from: $0) }

        return MeasurementTrendDTO(
            type: type,
            name: entries.first?.name ?? type,
            unit: entries.first?.unit ?? "",
            count: entries.count,
            latestValue: latest,
            changeOverPeriod: change,
            averageValue: avg,
            minValue: minVal,
            maxValue: maxVal,
            entries: dtos
        )
    }

    private func makeDTO(from m: MeasurementEntity) -> MeasurementResponseDTO {
        let formattedVal: String
        if m.type.lowercased().contains("pressure"), let diastolic = m.secondaryValue {
            formattedVal = "\(Int(m.value))/\(Int(diastolic)) \(m.unit)"
        } else if m.unit == "/10" {
            formattedVal = "\(String(format: "%.1f", m.value)) / 10"
        } else {
            let valStr = String(format: m.value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", m.value)
            formattedVal = "\(valStr) \(m.unit)"
        }

        return MeasurementResponseDTO(
            id: m.id ?? UUID(),
            name: m.name,
            type: m.type,
            category: m.category,
            value: m.value,
            secondaryValue: m.secondaryValue,
            formattedValue: formattedVal,
            unit: m.unit,
            dateRecorded: m.dateRecorded,
            source: m.source,
            referenceRangeMin: m.referenceRangeMin,
            referenceRangeMax: m.referenceRangeMax,
            status: m.status,
            associatedProtocolId: m.$associatedProtocol.id,
            notes: m.notes,
            createdAt: m.createdAt,
            updatedAt: m.updatedAt
        )
    }
}
