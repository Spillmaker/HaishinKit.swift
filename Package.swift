// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "HaishinKit",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "HaishinKit", targets: ["HaishinKit"]),
        .library(name: "SRTHaishinKit", targets: ["SRTHaishinKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/shogo4405/Logboard.git", "2.3.1"..<"2.4.0")
    ],
    targets: [
        .binaryTarget(
            name: "libsrt",
            path: "Vendor/SRT/libsrt.xcframework"
        ),
        .target(name: "SwiftPMSupport"),
        .target(name: "HaishinKit",
                dependencies: ["Logboard", "SwiftPMSupport"],
                path: "Sources",
                sources: [
                    "Codec",
                    "Extension",
                    "FLV",
                    "HTTP",
                    "Media",
                    "MPEG",
                    "Net",
                    "RTMP",
                    "Util",
                ]),
        .target(name: "SRTHaishinKit",
                dependencies: [
                    "libsrt",
                    "HaishinKit"
                ],
                path: "SRTHaishinKit"
        )
    ]
)
