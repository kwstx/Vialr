import Foundation
import Domain

// MARK: - Physical Dimensions

/// Physical dimensions supported by the Vialr calculation engine.
public enum PhysicalDimension: String, Codable, Sendable, CaseIterable {
    case mass
    case volume
    case concentration
    case syringeUnits
    case biologicalActivity
}

// MARK: - Mass Units

/// Standard mass units for dry compounds and peptide powders.
/// Canonical unit internally is Milligrams (mg).
public enum MassUnit: String, Codable, Sendable, CaseIterable, Identifiable {
    case ng = "ng"
    case mcg = "mcg"
    case mg = "mg"
    case g = "g"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ng: return "Nanograms (ng)"
        case .mcg: return "Micrograms (mcg)"
        case .mg: return "Milligrams (mg)"
        case .g: return "Grams (g)"
        }
    }

    public var symbol: String { rawValue }

    /// Multiplier to convert 1 unit of this type to canonical Milligrams (mg).
    public var toCanonicalMgMultiplier: Double {
        switch self {
        case .ng: return 0.000001      // 1 ng = 0.000001 mg (10^-6)
        case .mcg: return 0.001        // 1 mcg = 0.001 mg (10^-3)
        case .mg: return 1.0           // Canonical
        case .g: return 1000.0         // 1 g = 1000 mg (10^3)
        }
    }

    public func toCanonicalMg(value: Double) -> Double {
        value * toCanonicalMgMultiplier
    }

    public func fromCanonicalMg(value: Double) -> Double {
        value / toCanonicalMgMultiplier
    }

    /// Converts an amount in this unit to another target mass unit.
    public func convert(_ value: Double, to targetUnit: MassUnit) -> Double {
        let mg = toCanonicalMg(value: value)
        return targetUnit.fromCanonicalMg(value: mg)
    }
}

// MARK: - Volume Units

/// Standard volume units for diluents (e.g., Bacteriostatic Water, Saline) and liquid draws.
/// Canonical unit internally is Milliliters (mL).
public enum VolumeUnit: String, Codable, Sendable, CaseIterable, Identifiable {
    case mcl = "mcL"
    case ml = "mL"
    case cc = "cc"
    case l = "L"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mcl: return "Microliters (mcL / µL)"
        case .ml: return "Milliliters (mL)"
        case .cc: return "Cubic Centimeters (cc)"
        case .l: return "Liters (L)"
        }
    }

    public var symbol: String {
        switch self {
        case .mcl: return "µL"
        case .ml: return "mL"
        case .cc: return "cc"
        case .l: return "L"
        }
    }

    /// Multiplier to convert 1 unit of this type to canonical Milliliters (mL).
    public var toCanonicalMlMultiplier: Double {
        switch self {
        case .mcl: return 0.001        // 1 mcL = 0.001 mL (10^-3)
        case .ml: return 1.0           // Canonical
        case .cc: return 1.0           // 1 cc = 1 mL
        case .l: return 1000.0         // 1 L = 1000 mL (10^3)
        }
    }

    public func toCanonicalMl(value: Double) -> Double {
        value * toCanonicalMlMultiplier
    }

    public func fromCanonicalMl(value: Double) -> Double {
        value / toCanonicalMlMultiplier
    }

    /// Converts an amount in this unit to another target volume unit.
    public func convert(_ value: Double, to targetUnit: VolumeUnit) -> Double {
        let ml = toCanonicalMl(value: value)
        return targetUnit.fromCanonicalMl(value: ml)
    }
}

// MARK: - Concentration Units

/// Units representing solute mass per solvent volume.
/// Canonical concentration internally is mg/mL (identically equal to mcg/mcL).
public enum ConcentrationUnit: String, Codable, Sendable, CaseIterable, Identifiable {
    case mgPerMl = "mg/mL"
    case mcgPerMl = "mcg/mL"
    case mcgPerMcl = "mcg/µL"
    case gPerL = "g/L"
    case iuPerMl = "IU/mL"

    public var id: String { rawValue }

    public var displayName: String { rawValue }

    /// Conversion factor relative to canonical mg/mL.
    public var canonicalMultiplier: Double {
        switch self {
        case .mgPerMl: return 1.0
        case .mcgPerMl: return 1000.0  // 1 mg/mL = 1000 mcg/mL
        case .mcgPerMcl: return 1.0    // 1 mg/mL = 1 mcg/µL
        case .gPerL: return 1.0        // 1 mg/mL = 1 g/L
        case .iuPerMl: return 1.0      // Subject to biological activity ratio
        }
    }
}

// MARK: - Syringe Types & Geometry

/// Syringe calibration standards for insulin and medical syringes.
public enum SyringeType: String, Codable, Sendable, CaseIterable, Identifiable {
    case u100 = "U-100"
    case u40 = "U-40"
    case u500 = "U-500"

    public var id: String { rawValue }

    /// Number of syringe units / markings per 1.0 mL of liquid volume.
    public var unitsPerMl: Double {
        switch self {
        case .u100: return 100.0   // 1 unit = 0.01 mL = 10 µL
        case .u40: return 40.0     // 1 unit = 0.025 mL = 25 µL
        case .u500: return 500.0   // 1 unit = 0.002 mL = 2 µL
        }
    }

    /// Volume of liquid represented by a single unit tick mark (in mL).
    public var volumePerUnitMl: Double {
        1.0 / unitsPerMl
    }

    /// Converts volume in mL to syringe tick mark units.
    public func units(forVolumeMl volumeMl: Double) -> Double {
        volumeMl * unitsPerMl
    }

    /// Converts syringe tick mark units to liquid volume in mL.
    public func volumeMl(forUnits units: Double) -> Double {
        units * volumePerUnitMl
    }
}

/// Syringe specification pairing standard syringe calibration with barrel volume capacity.
public struct SyringeSpecification: Codable, Sendable, Hashable, Identifiable {
    public let type: SyringeType
    public let barrelCapacityMl: Double
    public let displayName: String

    public var id: String { "\(type.rawValue)_\(barrelCapacityMl)ml" }

    public var totalUnits: Double {
        type.units(forVolumeMl: barrelCapacityMl)
    }

    public init(type: SyringeType = .u100, barrelCapacityMl: Double = 1.0, displayName: String? = nil) {
        self.type = type
        self.barrelCapacityMl = barrelCapacityMl
        if let name = displayName {
            self.displayName = name
        } else {
            let units = Int(type.units(forVolumeMl: barrelCapacityMl))
            self.displayName = "\(String(format: "%.1f", barrelCapacityMl)) mL (\(units) Units \(type.rawValue))"
        }
    }

    // Standard pre-defined clinical syringe sizes
    public static let u100_30unit = SyringeSpecification(type: .u100, barrelCapacityMl: 0.3, displayName: "0.3 mL (30 Units U-100)")
    public static let u100_50unit = SyringeSpecification(type: .u100, barrelCapacityMl: 0.5, displayName: "0.5 mL (50 Units U-100)")
    public static let u100_100unit = SyringeSpecification(type: .u100, barrelCapacityMl: 1.0, displayName: "1.0 mL (100 Units U-100)")
    public static let u40_20unit = SyringeSpecification(type: .u40, barrelCapacityMl: 0.5, displayName: "0.5 mL (20 Units U-40)")
    public static let u40_40unit = SyringeSpecification(type: .u40, barrelCapacityMl: 1.0, displayName: "1.0 mL (40 Units U-40)")

    public static let standardSizes: [SyringeSpecification] = [
        .u100_30unit,
        .u100_50unit,
        .u100_100unit,
        .u40_20unit,
        .u40_40unit
    ]

    /// Calculates the visual fractional fill of the syringe barrel (0.0 to 1.0+).
    public func barrelFillFraction(forVolumeMl volumeMl: Double) -> Double {
        guard barrelCapacityMl > 0 else { return 0 }
        return volumeMl / barrelCapacityMl
    }

    /// Checks if a given liquid volume fits inside this syringe's barrel.
    public func isWithinCapacity(volumeMl: Double) -> Bool {
        volumeMl <= (barrelCapacityMl + 0.0001)
    }
}

// MARK: - Strongly-Typed Physical Quantities

/// Strongly typed mass quantity with unit.
public struct MassQuantity: Codable, Sendable, Hashable {
    public let value: Double
    public let unit: MassUnit

    public init(_ value: Double, _ unit: MassUnit = .mg) {
        self.value = value
        self.unit = unit
    }

    /// Canonical value in Milligrams (mg).
    public var mg: Double {
        unit.toCanonicalMg(value: value)
    }

    /// Value converted to Micrograms (mcg).
    public var mcg: Double {
        unit.convert(value, to: .mcg)
    }

    /// Value converted to Grams (g).
    public var g: Double {
        unit.convert(value, to: .g)
    }

    /// Value converted to Nanograms (ng).
    public var ng: Double {
        unit.convert(value, to: .ng)
    }

    public var formattedDescription: String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value)) \(unit.symbol)"
        }
        return "\(String(format: "%.3g", value)) \(unit.symbol)"
    }
}

/// Strongly typed liquid volume quantity with unit.
public struct VolumeQuantity: Codable, Sendable, Hashable {
    public let value: Double
    public let unit: VolumeUnit

    public init(_ value: Double, _ unit: VolumeUnit = .ml) {
        self.value = value
        self.unit = unit
    }

    /// Canonical value in Milliliters (mL).
    public var ml: Double {
        unit.toCanonicalMl(value: value)
    }

    /// Value converted to Microliters (mcL).
    public var mcl: Double {
        unit.convert(value, to: .mcl)
    }

    /// Value converted to Liters (L).
    public var l: Double {
        unit.convert(value, to: .l)
    }

    public var formattedDescription: String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value)) \(unit.symbol)"
        }
        return "\(String(format: "%.3g", value)) \(unit.symbol)"
    }
}

/// Biological activity to mass conversion factor (e.g., Somatropin GH: 1 mg = 3.0 IU).
public struct CompoundActivityRatio: Codable, Sendable, Hashable {
    public let iuPerMg: Double

    public init(iuPerMg: Double) {
        self.iuPerMg = max(0.0001, iuPerMg)
    }

    /// Standard somatropin growth hormone conversion (1 mg = 3.0 IU).
    public static let standardSomatropin = CompoundActivityRatio(iuPerMg: 3.0)

    public func iuToMg(_ iu: Double) -> Double {
        iu / iuPerMg
    }

    public func mgToIu(_ mg: Double) -> Double {
        mg * iuPerMg
    }
}

/// Target dose quantity supporting mass, volume, syringe units, or biological activity (IU).
public enum DoseQuantity: Codable, Sendable, Hashable {
    case mass(MassQuantity)
    case volume(VolumeQuantity)
    case syringeUnits(units: Double, syringeType: SyringeType)
    case biologicalActivity(iu: Double)

    /// Convenience initializer bridging from existing Domain `DoseUnit`.
    public init(amount: Double, unit: DoseUnit) {
        switch unit {
        case .mcg:
            self = .mass(MassQuantity(amount, .mcg))
        case .mg:
            self = .mass(MassQuantity(amount, .mg))
        case .iu:
            self = .biologicalActivity(iu: amount)
        case .ml:
            self = .volume(VolumeQuantity(amount, .ml))
        }
    }

    /// Human readable description.
    public var formattedDescription: String {
        switch self {
        case .mass(let m):
            return m.formattedDescription
        case .volume(let v):
            return v.formattedDescription
        case .syringeUnits(let units, let type):
            return "\(String(format: "%.1f", units)) units (\(type.rawValue))"
        case .biologicalActivity(let iu):
            return "\(String(format: "%.2g", iu)) IU"
        }
    }
}
