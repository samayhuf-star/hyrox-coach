// swift-tools-version:6.0
// Test-only package: compiles the app's workout logic (models, session engine, storage) without
// the SwiftUI screens so it can be tested on Linux with `swift test`. The iOS app itself is built
// from HyroxAllInOneCoach.xcodeproj / project.yml and does not use this file.
import PackageDescription

let package = Package(
    name: "HybridTrainingLogic",
    targets: [
        .target(name: "UIKit", path: "LogicTests/Stubs/UIKit"),
        .target(name: "AudioToolbox", path: "LogicTests/Stubs/AudioToolbox"),
        .target(
            name: "HyroxCore",
            dependencies: ["UIKit", "AudioToolbox"],
            path: "HyroxAllInOneCoach",
            exclude: ["Assets.xcassets", "PrivacyInfo.xcprivacy", "Base.lproj", "Design", "Features", "HybridTrainingApp.swift", "Info.plist",
                      "Services/CoachAPI.swift", "Services/CoachAccount.swift", "Services/CoachStore.swift",
                      "Services/PlusPurchaseStore.swift"],
            sources: ["Models", "Services/WorkoutSessionEngine.swift", "Services/TrainingRepository.swift"]
        ),
        .testTarget(name: "LogicTests", dependencies: ["HyroxCore"], path: "LogicTests/Tests"),
    ]
)
