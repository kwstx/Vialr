// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Vialr",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "VialrApp", targets: ["VialrApp"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "CalculationEngine", targets: ["CalculationEngine"]),
        .library(name: "Data", targets: ["Data"]),
        .library(name: "Health", targets: ["Health"]),
        .library(name: "Analytics", targets: ["Analytics"]),
        .library(name: "Feature", targets: ["Feature"]),
    ],
    dependencies: [
        // Pure native standard library & Apple frameworks (SwiftUI, Observation, Charts, HealthKit)
    ],
    targets: [
        // MARK: - Core Domain Models & Rules
        .target(
            name: "Domain",
            dependencies: [],
            path: "Sources/Domain",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        
        // MARK: - Design System & UI Components
        .target(
            name: "DesignSystem",
            dependencies: [],
            path: "Sources/DesignSystem",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        
        // MARK: - Calculation Engine (Reconstitution, Site Rotation, Depletion)
        .target(
            name: "CalculationEngine",
            dependencies: ["Domain"],
            path: "Sources/CalculationEngine",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        
        // MARK: - Data Layer (Persistence, Mocking, Sync)
        .target(
            name: "Data",
            dependencies: ["Domain"],
            path: "Sources/Data",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        
        // MARK: - HealthKit Integration
        .target(
            name: "Health",
            dependencies: ["Domain"],
            path: "Sources/Health",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        
        // MARK: - Analytics Engine
        .target(
            name: "Analytics",
            dependencies: ["Domain", "CalculationEngine"],
            path: "Sources/Analytics",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        
        // MARK: - Feature Modules (Screens & Flows)
        .target(
            name: "Feature",
            dependencies: [
                "DesignSystem",
                "Domain",
                "CalculationEngine",
                "Data",
                "Health",
                "Analytics"
            ],
            path: "Sources/Feature",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        
        // MARK: - Main Application Coordinator & Entry
        .target(
            name: "VialrApp",
            dependencies: [
                "Feature",
                "DesignSystem",
                "Domain",
                "CalculationEngine",
                "Data",
                "Health",
                "Analytics"
            ],
            path: "Sources/VialrApp",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        
        // MARK: - Unit Tests
        .testTarget(
            name: "CalculationEngineTests",
            dependencies: ["CalculationEngine", "Domain"],
            path: "Tests/CalculationEngineTests"
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            path: "Tests/DomainTests"
        ),
        .testTarget(
            name: "AnalyticsTests",
            dependencies: ["Analytics", "Domain", "CalculationEngine"],
            path: "Tests/AnalyticsTests"
        )
    ]
)
