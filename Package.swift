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
        // MARK: - iOS Client Target & Libraries
        .library(name: "VialrApp", targets: ["VialrApp"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "CalculationEngine", targets: ["CalculationEngine"]),
        .library(name: "Data", targets: ["Data"]),
        .library(name: "Health", targets: ["Health"]),
        .library(name: "Analytics", targets: ["Analytics"]),
        .library(name: "Feature", targets: ["Feature"]),

        // MARK: - Backend Server Executable
        .executable(name: "VialrServer", targets: ["VialrServer"])
    ],
    dependencies: [
        // MARK: - Vapor Backend Ecosystem
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "5.0.0")
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

        // MARK: - Data Layer (Persistence, Networking, Remote Sync)
        .target(
            name: "Data",
            dependencies: ["Domain", "CalculationEngine"],
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

        // MARK: - Main iOS Application Coordinator & Entry
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

        // MARK: - Backend Server (Vapor 4 & PostgreSQL Fluent)
        .executableTarget(
            name: "VialrServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "JWT", package: "jwt"),
                "Domain",
                "CalculationEngine",
                "Analytics"
            ],
            path: "Sources/VialrServer",
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
        ),
        .testTarget(
            name: "StorageTests",
            dependencies: [
                "Domain",
                "Data",
                "Health",
                "VialrServer",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent")
            ],
            path: "Tests/StorageTests"
        ),
        .testTarget(
            name: "HealthTests",
            dependencies: ["Health", "Domain", "Data"],
            path: "Tests/HealthTests"
        ),
        .testTarget(
            name: "ServerAPITests",
            dependencies: [
                "VialrServer",
                "Domain",
                "CalculationEngine",
                "Analytics",
                "Data",
                .product(name: "XCTVapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent")
            ],
            path: "Tests/ServerAPITests"
        ),
        .testTarget(
            name: "FeatureUITests",
            dependencies: [
                "Feature",
                "DesignSystem",
                "Domain",
                "CalculationEngine",
                "Data",
                "Health",
                "Analytics"
            ],
            path: "Tests/FeatureUITests"
        )
    ]
)
