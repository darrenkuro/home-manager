# Swift Project — Build & Tooling Reference

## Package.swift (Library / CLI)

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "<PackageName>",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        // Library:
        .library(name: "<PackageName>", targets: ["<PackageName>"]),
        // CLI (use instead of library for executables):
        // .executable(name: "<package-name>", targets: ["<PackageName>"]),
    ],
    targets: [
        .target(name: "<PackageName>"),
        .testTarget(
            name: "<PackageName>Tests",
            dependencies: ["<PackageName>"]
        ),
    ]
)
```

Adjust `platforms` based on the project's target. Remove platforms that aren't needed.

## Package.swift (App with XcodeGen)

For apps using XcodeGen, `Package.swift` manages dependencies only:

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "<ProjectName>",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    dependencies: [
        // Add SPM dependencies here
    ]
)
```

## project.yml (XcodeGen)

```yaml
name: <ProjectName>

options:
  bundleIdPrefix: com.darrenkuro
  xcodeVersion: "16.0"
  deploymentTarget:
    iOS: "17.0"
    macOS: "14.0"

settings:
  base:
    SWIFT_VERSION: "6.0"
    DEAD_CODE_STRIPPING: true
    ENABLE_PREVIEWS: "YES"

targets:
  <ProjectName>:
    type: application
    platform: [iOS, macOS]
    sources:
      - Sources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.darrenkuro.<project-name-lowercase>
        GENERATE_INFOPLIST_FILE: true
        INFOPLIST_KEY_CFBundleDisplayName: "<Project Display Name>"
        CODE_SIGN_STYLE: Automatic
```

Adjust `platform` to `[macOS]` or `[iOS]` for single-platform apps.

## .gitignore

```
xcuserdata/
*.xcworkspace/
Package.resolved
DerivedData/
.build/
*.xcodeproj
```

Remove `*.xcodeproj` line if not using XcodeGen.

## .github/workflows/ci.yml (SPM)

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: swift build
      - name: Test
        run: swift test
```

## .github/workflows/ci.yml (XcodeGen App)

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Install XcodeGen
        run: brew install xcodegen
      - name: Generate Xcode project
        run: xcodegen generate
      - name: Build
        run: xcodebuild build -scheme <ProjectName> -destination 'platform=macOS'
```

## Starter Files

### Sources/App.swift (App)

```swift
import SwiftUI

@main
struct <ProjectName>App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Sources/ContentView.swift (App)

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
    }
}
```

### Sources/PackageName/PackageName.swift (Library)

```swift
// Public API
```

### Tests/PackageNameTests/PackageNameTests.swift (Library)

```swift
import Testing
@testable import <PackageName>

@Test func example() {
    #expect(true)
}
```
