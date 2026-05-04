// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        .library(name: "Sentry", targets: ["Sentry", "SentryCppHelper"]),
        .library(name: "SentrySwiftUI", targets: ["Sentry", "SentrySwiftUI", "SentryCppHelper"]),
        .library(name: "SentryDistribution", targets: ["SentryDistribution"]),
    ],
    targets: [
        // Exposes Sources/Sentry/Public as the Sentry module umbrella.
        .target(
            name: "SentryHeaders",
            path: "Sources/Sentry",
            sources: ["SentryDummyPublicEmptyClass.m"],
            publicHeadersPath: "Public"
        ),
        // Private headers needed by the Swift layer.
        .target(
            name: "_SentryPrivate",
            dependencies: ["SentryHeaders"],
            path: "Sources/Sentry",
            sources: ["SentryDummyPrivateEmptyClass.m"],
            publicHeadersPath: "include"
        ),
        // Swift sources.
        .target(
            name: "SentrySwift",
            dependencies: ["_SentryPrivate", "SentryHeaders"],
            path: "Sources/Swift",
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"])
            ]
        ),
        // All ObjC/C/C++ sources built from source — named "Sentry" so `import Sentry` works.
        .target(
            name: "Sentry",
            dependencies: ["SentrySwift", "_SentryPrivate"],
            path: "Sources",
            exclude: [
                "Sentry/SentryDummyPublicEmptyClass.m",
                "Sentry/SentryDummyPrivateEmptyClass.m",
                "Swift",
                "SentrySwiftUI",
                "Resources",
                "Configuration",
                "SentryCppHelper",
                "SentryDistribution",
                "SentryDistributionTests",
            ],
            publicHeadersPath: "Sentry/Public",
            cSettings: [
                .headerSearchPath("Sentry"),
                .headerSearchPath("SentryCrash/Recording"),
                .headerSearchPath("SentryCrash/Recording/Monitors"),
                .headerSearchPath("SentryCrash/Recording/Tools"),
                .headerSearchPath("SentryCrash/Installations"),
                .headerSearchPath("SentryCrash/Reporting/Filters"),
                .headerSearchPath("SentryCrash/Reporting/Filters/Tools"),
            ]
        ),
        .target(
            name: "SentrySwiftUI",
            dependencies: ["Sentry"],
            path: "Sources/SentrySwiftUI",
            exclude: ["module.modulemap"]
        ),
        .target(
            name: "SentryCppHelper",
            path: "Sources/SentryCppHelper",
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        ),
        .target(name: "SentryDistribution", path: "Sources/SentryDistribution"),
    ],
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
