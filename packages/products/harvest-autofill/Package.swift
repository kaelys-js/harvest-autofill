// swift-tools-version:6.0
// Test-only package: builds HarvestCore.swift as a library so the test suite can
// @testable-import the app's logic. The shipped app is still built by build.sh, which
// compiles HarvestCore.swift + HarvestApp.swift together into one module.
import PackageDescription

let package = Package(
    name: "HarvestCore",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "HarvestCore",
            path: ".",
            exclude: [
                "HarvestApp.swift",
                "HarvestSideEffects.swift",
                "tests",
                "dist",
                "vendor",
                "build.sh",
                "release.sh",
                "notarize.sh",
                "engine.sh",
                "discover.py",
                "harvest_weekly.py",
                "config.default.json",
                "Info.plist",
                "pyproject.toml",
                "uv.lock",
                "ruff.toml",
            ],
            sources: ["HarvestCore.swift"],
        ),
        .testTarget(
            name: "HarvestCoreTests",
            dependencies: ["HarvestCore"],
            path: "SwiftTests",
        ),
    ],
)
