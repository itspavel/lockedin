// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LockedIn",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "LockedIn", path: "Sources/LockedIn")
    ]
)
