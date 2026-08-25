import Foundation

/// Represents a financial expense or transaction tied to a protocol, vial, supplies, or lab test.
/// Enables precise calculation of the real cost of a protocol (total expenditure, cost per day,
/// cost per dose, and categorical breakdown across compounds, diagnostics, and supplies).
public struct CostEvent: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var userId: UUID?
    public var title: String
    public var amount: Double
    public var currencyCode: String
    public var category: CostCategory
    public var dateIncurred: Date
    public var vendor: String
    
    // MARK: - Relational Allocations
    public var protocolId: UUID?
    public var compoundId: UUID?
    public var vialId: UUID?
    public var doseEventId: UUID?
    public var labPanelId: UUID?
    public var receiptDocumentId: UUID?
    
    // MARK: - Allocation & Amortization
    public var allocationType: CostAllocationType
    public var amortizationDays: Int?
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    // MARK: - Compatibility Accessors for Legacy CostRecord
    public var amountUsd: Double {
        get { amount }
        set { amount = newValue }
    }

    public var associatedVialId: UUID? {
        get { vialId }
        set { vialId = newValue }
    }

    public var associatedCompoundId: UUID? {
        get { compoundId }
        set { compoundId = newValue }
    }

    // MARK: - Primary Initializer
    public init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        title: String,
        amount: Double,
        currencyCode: String = "USD",
        category: CostCategory = .peptideVial,
        dateIncurred: Date = Date(),
        vendor: String = "",
        protocolId: UUID? = nil,
        compoundId: UUID? = nil,
        vialId: UUID? = nil,
        doseEventId: UUID? = nil,
        labPanelId: UUID? = nil,
        receiptDocumentId: UUID? = nil,
        allocationType: CostAllocationType = .direct,
        amortizationDays: Int? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.amount = amount
        self.currencyCode = currencyCode
        self.category = category
        self.dateIncurred = dateIncurred
        self.vendor = vendor
        self.protocolId = protocolId
        self.compoundId = compoundId
        self.vialId = vialId
        self.doseEventId = doseEventId
        self.labPanelId = tabPanelId
        self.receiptDocumentId = receiptDocumentId
        self.allocationType = allocationType
        self.amortizationDays = amortizationDays
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Compatibility Initializer for CostRecord Call Sites
    public init(
        id: UUID = UUID(),
        title: String,
        category: CostCategory,
        amountUsd: Double,
        dateIncurred: Date = Date(),
        vendor: String = "",
        associatedVialId: UUID? = nil,
        associatedCompoundId: UUID? = nil,
        notes: String = ""
    ) {
        self.init(
            id: id,
            userId: nil,
            title: title,
            amount: amountUsd,
            currencyCode: "USD",
            category: category,
            dateIncurred: dateIncurred,
            vendor: vendor,
            protocolId: nil,
            compoundId: associatedCompoundId,
            vialId: associatedVialId,
            notes: notes
        )
    }

    // MARK: - Formatted Display Helper
    /// Formats amount into a localized currency string (e.g. "$85.00")
    public var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

// MARK: - Protocol Cost Summary
/// Aggregated financial breakdown calculating the true multi-dimensional cost of a protocol.
public struct ProtocolCostSummary: Sendable, Codable, Hashable {
    public let protocolId: UUID
    public let protocolName: String
    public let totalCost: Double
    public let totalCompoundCost: Double
    public let totalSuppliesCost: Double
    public let totalBloodworkCost: Double
    public let totalConsultCost: Double
    public let totalShippingCost: Double
    public let costPerDay: Double
    public let costPerDoseAverage: Double
    public let projectedMonthlyCost: Double
    public let totalDosesDelivered: Int
    public let currencyCode: String

    public init(
        protocolId: UUID,
        protocolName: String,
        totalCost: Double,
        totalCompoundCost: Double,
        totalSuppliesCost: Double,
        totalBloodworkCost: Double,
        totalConsultCost: Double,
        totalShippingCost: Double,
        costPerDay: Double,
        costPerDoseAverage: Double,
        projectedMonthlyCost: Double,
        totalDosesDelivered: Int,
        currencyCode: String = "USD"
    ) {
        self.protocolId = protocolId
        self.protocolName = protocolName
        self.totalCost = totalCost
        self.totalCompoundCost = totalCompoundCost
        self.totalSuppliesCost = totalSuppliesCost
        self.totalBloodworkCost = totalBloodworkCost
        self.totalConsultCost = totalConsultCost
        self.totalShippingCost = totalShippingCost
        self.costPerDay = costPerDay
        self.costPerDoseAverage = costPerDoseAverage
        self.projectedMonthlyCost = projectedMonthlyCost
        self.totalDosesDelivered = totalDosesDelivered
        self.currencyCode = currencyCode
    }

    /// Calculates a complete cost summary from protocol events, doses, and cost transactions.
    public static func calculate(
        protocolModel: ProtocolModel,
        costEvents: [CostEvent],
        completedDoses: [DoseEvent] = []
    ) -> ProtocolCostSummary {
        let protoCosts = costEvents.filter { $0.protocolId == protocolModel.id }
        
        var compCost: Double = 0.0
        var supCost: Double = 0.0
        var labCost: Double = 0.0
        var consultCost: Double = 0.0
        var shipCost: Double = 0.0
        var total: Double = 0.0

        for event in protoCosts {
            total += event.amount
            switch event.category {
            case .peptideVial: compCost += event.amount
            case .medicalSupplies: supCost += event.amount
            case .bloodwork: labCost += event.amount
            case .doctorConsult, .subscription: consultCost += event.amount
            case .shipping: shipCost += event.amount
            case .other: total += 0
            }
        }

        let elapsedDays = max(1, protocolModel.elapsedDays)
        let costPerDay = total / Double(elapsedDays)
        let projectedMonth = costPerDay * 30.4375
        let dosesCount = max(1, completedDoses.filter { $0.protocolId == protocolModel.id && $0.status == .taken }.count)
        let costPerDose = total / Double(dosesCount)

        return ProtocolCostSummary(
            protocolId: protocolModel.id,
            protocolName: protocolModel.name,
            totalCost: total,
            totalCompoundCost: compCost,
            totalSuppliesCost: supCost,
            totalBloodworkCost: labCost,
            totalConsultCost: consultCost,
            totalShippingCost: shipCost,
            costPerDay: costPerDay,
            costPerDoseAverage: costPerDose,
            projectedMonthlyCost: projectedMonth,
            totalDosesDelivered: dosesCount
        )
    }
}

// MARK: - Cost Category
public enum CostCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case peptideVial = "Peptide / Compound Vial"
    case medicalSupplies = "Supplies (Syringes, BAC Water)"
    case bloodwork = "Bloodwork / Lab Tests"
    case doctorConsult = "Physician / Clinic Consult"
    case subscription = "Telehealth / Subscription"
    case shipping = "Shipping & Handling"
    case other = "Other Expense"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .peptideVial: return "cross.vial.fill"
        case .medicalSupplies: return "syringe"
        case .bloodwork: return "drop.triangle.fill"
        case .doctorConsult: return "stethoscope"
        case .subscription: return "creditcard.fill"
        case .shipping: return "shippingbox.fill"
        case .other: return "dollarsign.circle.fill"
        }
    }
}

// MARK: - Cost Allocation Type
public enum CostAllocationType: String, Codable, Sendable, CaseIterable, Identifiable {
    case direct = "Direct Protocol Cost"
    case amortized = "Amortized Supplies"
    case perDose = "Calculated Per-Dose Cost"

    public var id: String { rawValue }
}

// MARK: - Legacy Compatibility Typealias
public typealias CostRecord = CostEvent
