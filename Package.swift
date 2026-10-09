// swift-tools-version: 5.9
// MacroFactorClone — Swift Package for the MacroFactor clone iOS app.
//
// iOS 17+ deployment target. This package holds every library module; the
// thin Xcode application target (see SETUP.md) links them and owns the
// asset catalog, Info.plist, entitlements, and the watchOS companion app.
//
// Target map (see MODULE_MAP.md for owners and dependency rules):
//   DesignSystem     — issue #1 (done): tokens + components. No deps.
//   AppShell         — issue #2 (this scaffold): entry, tabs, router,
//                      onboarding, theming, settings/about. Depends on
//                      DesignSystem + all feature modules.
//   DataLayer        — issue #3: SwiftData models + repositories.
//   FoodLogFeature   — issue #4: food search, custom foods, timeline log.
//   CaptureFeature   — issue #5: barcode, label OCR, photo, voice, recipes.
//   CoachingEngine   — issue #6: expenditure algorithm, programs, strategy
//                      (pure Foundation logic, no UI deps).
//   TrackingFeature  — issue #7: weight trend, measurements, photos, streaks.
//   StrategyFeature  — issue #14: strategy tab UI (program, targets,
//                      expenditure, check-in). Depends on DesignSystem,
//                      DataLayer, CoachingEngine (same sanctioned deviation
//                      as TrackingFeature/AnalyticsFeature).
//   AnalyticsFeature — issue #8: dashboards, charts, micros, insights.
//   HealthKitSync    — issue #9: HealthKit import + background delivery.
//   EngagementFeature— issue #10: notifications, widgets data, watch sync.
//
// Dependency rule: feature modules may depend on DesignSystem and
// DataLayer only — never on AppShell or on each other. AppShell composes
// them. This keeps the graph acyclic and every feature independently
// testable.
import PackageDescription

let package = Package(
    name: "MacroFactorClone",
    platforms: [
        .iOS(.v17),
        // watchOS so the watchOS app target (app/WatchApp, issue #10) can
        // link DesignSystem / DataLayer / EngagementFeature. Only products
        // actually linked by the watch target are built for watchOS.
        .watchOS(.v10),
    ],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "AppShell", targets: ["AppShell"]),
        .library(name: "DataLayer", targets: ["DataLayer"]),
        .library(name: "FoodLogFeature", targets: ["FoodLogFeature"]),
        .library(name: "CaptureFeature", targets: ["CaptureFeature"]),
        .library(name: "CoachingEngine", targets: ["CoachingEngine"]),
        .library(name: "TrackingFeature", targets: ["TrackingFeature"]),
        .library(name: "StrategyFeature", targets: ["StrategyFeature"]),
        .library(name: "AnalyticsFeature", targets: ["AnalyticsFeature"]),
        .library(name: "HealthKitSync", targets: ["HealthKitSync"]),
        .library(name: "EngagementFeature", targets: ["EngagementFeature"]),
    ],
    targets: [
        .target(
            name: "DesignSystem",
            path: "Sources/DesignSystem"
        ),
        .target(
            name: "AppShell",
            dependencies: [
                "DesignSystem",
                "DataLayer",
                "FoodLogFeature",
                "CaptureFeature",
                "CoachingEngine",
                "TrackingFeature",
                "AnalyticsFeature",
                "HealthKitSync",
                "EngagementFeature",
                "StrategyFeature",
            ],
            path: "Sources/AppShell",
            exclude: ["MacroFactorCloneApp.swift"]
        ),
        .target(
            name: "DataLayer",
            dependencies: ["DesignSystem", "CoachingEngine"],
            path: "Sources/DataLayer",
            resources: [.process("Schema/Resources")]
        ),
        .target(
            name: "FoodLogFeature",
            dependencies: ["DesignSystem", "DataLayer"],
            path: "Sources/FoodLogFeature"
        ),
        .target(
            name: "CaptureFeature",
            dependencies: ["DesignSystem", "DataLayer"],
            path: "Sources/CaptureFeature"
        ),
        .target(
            name: "CoachingEngine",
            path: "Sources/CoachingEngine"
        ),
        .target(
            name: "StrategyFeature",
            // DEVIATION (issue #14): depends on CoachingEngine, like
            // TrackingFeature (issue #7) and AnalyticsFeature (issue #8).
            // CoachingEngine is dep-free pure Foundation; calling
            // MacroPlanner / ExpenditureEstimator / WeeklyCheckIn directly
            // is sanctioned by the #6 README integration contract.
            dependencies: ["DesignSystem", "DataLayer", "CoachingEngine"],
            path: "Sources/StrategyFeature"
        ),
        .target(
            name: "TrackingFeature",
            // Sanctioned deviation (issue #7, 2026-09-28): CoachingEngine is
            // dep-free pure Foundation, so the trend chart may call its pure
            // smoothing functions directly. Logged in issues/07-tracking.md.
            dependencies: ["DesignSystem", "DataLayer", "CoachingEngine"],
            path: "Sources/TrackingFeature"
        ),
        .target(
            name: "AnalyticsFeature",
            // DEVIATION (issue #8, 2026-09-28): depends on CoachingEngine.
            // CoachingEngine is dep-free pure Foundation; consuming
            // WeightTrend.summarize / ExpenditureEstimator.estimate directly
            // is sanctioned by the #6 README integration contract. This keeps
            // AnalyticsFeature acyclic (CoachingEngine depends on nothing).
            dependencies: ["DesignSystem", "DataLayer", "CoachingEngine"],
            path: "Sources/AnalyticsFeature"
        ),
        .target(
            name: "HealthKitSync",
            dependencies: ["DesignSystem", "DataLayer"],
            path: "Sources/HealthKitSync"
        ),
        .target(
            name: "EngagementFeature",
            dependencies: ["DesignSystem", "DataLayer"],
            path: "Sources/EngagementFeature"
        ),
        .testTarget(
            name: "CoachingEngineTests",
            dependencies: ["CoachingEngine"],
            path: "Tests/CoachingEngineTests"
        ),
        .testTarget(
            name: "DataLayerTests",
            dependencies: ["DataLayer"],
            path: "Tests/DataLayerTests"
        ),
        .testTarget(
            name: "FoodLogFeatureTests",
            dependencies: ["FoodLogFeature", "DataLayer"],
            path: "Tests/FoodLogFeatureTests"
        ),
    ]
)
