#!/usr/bin/ruby

# Usage:
# Update Package.swift, version constants as per package.json

require 'json'

config = JSON.parse(File.read('package.json'), {object_class: OpenStruct})

package_swift = <<PACKAGE
// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "apple-plugin-geofence",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(name: "MoEngagePluginGeofence", targets: ["MoEngagePluginGeofence"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/moengage/apple-sdk.git", exact: "#{config.sdkVerMin}"),
        .package(url: "https://github.com/moengage/iOS-PluginBase.git", exact: "#{config.pluginbaseVerMin}"),
        // For development
        // .package(path: "../iOS-PluginBase")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.

        .target(
            name: "MoEngagePluginGeofence",
            dependencies: [
                .product(name: "MoEngagePluginBase", package: "iOS-PluginBase"),
                .product(name: "MoEngageGeofence", package: "apple-sdk")
            ],
            linkerSettings: [
                .linkedFramework("UIKit"),
                .linkedFramework("Foundation")
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
PACKAGE

File.open('Package.swift', 'w') do |file|
  file.write(package_swift)
end
