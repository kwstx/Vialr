# Vialr

A premium, all-in-one peptide and protocol tracking application for iPhone, built natively in **Swift 6** using **SwiftUI**, **Observation**, **Swift Concurrency**, and **Swift Charts**.

Vialr provides a longitudinal protocol record where doses, vial inventory, physical measurements, bloodwork biomarkers, subjective outcomes, financial costs, and protocol changes connect together in one intelligent, local-first system.

---

## Architecture & Modular SPM Structure

Vialr is partitioned into decoupled Swift Package Manager targets under `Sources/`:

- **`DesignSystem`**: Luxury minimalist design system (inspired by Uber & Cal AI) with custom typography, dark palette (`#0A0D12`), glassmorphic cards, status badges, interactive U-100 syringe visualizer, and anatomical body rotation map.
- **`Domain`**: Core domain entities (`Compound`, `ProtocolModel`, `DoseLog`, `InjectionSite`, `Vial`, `SupplyItem`, `Biomarker`, `SymptomLog`, `CostRecord`, `ClinicianReport`) and repository protocols.
- **`CalculationEngine`**: Mathematical reconstitution engine (exact concentration mg/mL, draw volume, U-100 syringe markings, cost/dose), smart site rotation engine with resting heat maps, inventory depletion burn rate forecaster, and inconsistency/overdose safety detector.
- **`Data`**: Local-first actor store (`LocalStore`), realistic seed data factory (`MockDataFactory`), and repository implementations.
- **`Health`**: Native Apple HealthKit synchronization manager for weight, resting heart rate, HRV, and blood glucose.
- **`Analytics`**: Pharmacokinetic half-life clearance curve modeling (\( C(t) = D \cdot 0.5^{t / t_{1/2}} \)), protocol adherence scoring, and dose-to-outcome correlation engine.
- **`Feature`**: Complete user flows:
  - 11-step personalized onboarding wizard
  - Hero Dashboard with 1-tap quick log
  - Protocol management & comparison
  - Interactive reconstitution calculator
  - Injection site rotation map
  - Swift Charts analytics & trends
  - Clinician summary report generator
  - Settings & data backup
- **`VialrApp`**: Root application coordinator, DI container (`AppContainer`), and floating tab navigation.

---

## Requirements & Tech Stack

- **iOS 17.0+** / **macOS 14.0+**
- **Swift 6** with Strict Concurrency Checking
- **SwiftUI** & Apple **Observation** framework (`@Observable`)
- **Swift Charts**
- **HealthKit**

---

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/kwstx/Vialr.git
   cd Vialr
   ```
2. Open `Package.swift` in Xcode 16+ or add to an Xcode iOS App project.
3. Run tests:
   ```bash
   swift test
   ```

---

## License

Private / All Rights Reserved.
