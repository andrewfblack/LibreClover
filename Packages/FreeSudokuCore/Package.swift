// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FreeSudokuCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "FreeSudokuCore", targets: ["FreeSudokuCore"])],
    targets: [
        .target(name: "FreeSudokuCore"),
        .testTarget(name: "FreeSudokuCoreTests", dependencies: ["FreeSudokuCore"])
    ]
)
