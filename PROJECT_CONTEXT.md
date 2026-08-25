# Vialr - Project Overview & Context

## Vision
A premium, all-in-one peptide and protocol tracking app for iPhone, built natively in Swift and SwiftUI, giving users one secure place to manage their entire tracking journey.

The goal is not simply to build another reminder or peptide calculator; it is to create a complete longitudinal personal protocol record where doses, inventory, measurements, bloodwork, outcomes, costs, and protocol changes all connect together in one intelligent system.

---

## Core Capabilities & Features

1. **Compound & Peptide Tracking**: Track any peptide, compound, or supplement.
2. **Protocol Management**: Create, monitor, and compare different protocols over time.
3. **Dose Logging & Reminders**: Log doses with smart scheduled reminders.
4. **Reconstitution & Dosing Calculators**: Exact mathematical reconstitution and unit calculation helpers.
5. **Injection Site Rotation**: Automated rotation mapping to prevent scar tissue and tissue fatigue.
6. **Vial & Supply Inventory**: Manage supply levels, vial volumes, expiration dates, and accessories.
7. **Cost Tracking**: Financial tracking across compounds, protocols, and supplies over time.
8. **Results & Symptom Logging**: Record subjective feedback, side effects, and quantitative outcomes.
9. **Bloodwork Management**: Import, organize, and track biomarkers against active protocols.
10. **Apple Health Integration**: Sync vitals, metrics, and health data seamlessly.
11. **Correlation & Analytics**: Visualize dose-to-result relationships and spot trends.
12. **Inconsistency Detection**: Detect data-entry mistakes, irregular dosing intervals, or conflicts.
13. **Protocol Timeline & History Replay**: Replay entire protocol history longitudinally.
14. **Clinician-Ready Reports**: Generate clean, professional exportable summary reports for medical practitioners.

---

## Architecture & Tech Stack

- **Client**: Native iOS (Swift & SwiftUI).
- **Design Language**: Minimalist and clean (inspired by Uber and Cal AI) — large typography, subtle cards, smooth animations, ultra-fast UI interactions.
- **Data Architecture**: Local-first architecture (fast, fully functional offline) with secure cloud backend synchronization.
- **Backend / Database**: Secure cloud backend backed by PostgreSQL.
- **Onboarding**: Personalized 10–12 question onboarding flow that learns tracking priorities and configures the app experience accordingly before signup.
