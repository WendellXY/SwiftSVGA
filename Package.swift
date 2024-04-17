// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SwiftSVGA",
  platforms: [
    .iOS(.v12)
  ],
  products: [
    .library(
      name: "SwiftSVGA",
      targets: ["SwiftSVGA"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.6.0"),
    .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.0")),
  ],
  targets: [
    .target(
      name: "SwiftSVGA",
      dependencies: [
        "ZIPFoundation",
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
      ],
      path: "SwiftSVGA"
    )
  ]
)
