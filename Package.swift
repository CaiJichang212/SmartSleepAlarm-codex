// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SmartSleepAlarm",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SmartSleepDomain", targets: ["SmartSleepDomain"]),
        .library(name: "SmartSleepShared", targets: ["SmartSleepShared"]),
        .library(name: "SmartSleepInfra", targets: ["SmartSleepInfra"]),
        .library(name: "SmartSleepiOS", targets: ["SmartSleepiOS"]),
        .library(name: "SmartSleepWatch", targets: ["SmartSleepWatch"])
    ],
    targets: [
        .target(name: "SmartSleepDomain"),
        .target(
            name: "SmartSleepShared",
            dependencies: ["SmartSleepDomain"]
        ),
        .target(
            name: "SmartSleepInfra",
            dependencies: ["SmartSleepDomain", "SmartSleepShared"]
        ),
        .target(
            name: "SmartSleepiOS",
            dependencies: ["SmartSleepDomain", "SmartSleepShared", "SmartSleepInfra"]
        ),
        .target(
            name: "SmartSleepWatch",
            dependencies: ["SmartSleepDomain", "SmartSleepShared", "SmartSleepInfra"]
        ),
        .testTarget(
            name: "SmartSleepDomainTests",
            dependencies: ["SmartSleepDomain"]
        ),
        .testTarget(
            name: "SmartSleepSharedTests",
            dependencies: ["SmartSleepShared"]
        ),
        .testTarget(
            name: "SmartSleepiOSTests",
            dependencies: ["SmartSleepiOS"]
        ),
        .testTarget(
            name: "SmartSleepWatchTests",
            dependencies: ["SmartSleepWatch", "SmartSleepShared"]
        )
    ]
)
