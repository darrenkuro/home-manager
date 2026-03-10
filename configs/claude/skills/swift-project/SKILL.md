---
name: swift-project
description: Scaffold and develop Swift projects (macOS/iOS apps, libraries, CLI tools). Use when the user asks to create a new Swift project, SwiftUI app, Swift package, XcodeGen-based project, or set up a Swift codebase with standard tooling.
---

# Swift Project Development

Load the `/project-init` skill for shared initialization steps (git, LICENSE, README, CI, repo audit) before proceeding with language-specific setup.

## Scaffold

Two project types are supported. Ask the user which one if unclear.

### Library / CLI (SPM-only)

```
PackageName/
├── Sources/
│   └── PackageName/
│       └── PackageName.swift
├── Tests/
│   └── PackageNameTests/
│       └── PackageNameTests.swift
├── Package.swift
└── .github/
    └── workflows/
        └── ci.yml
```

### App (XcodeGen + SPM)

```
ProjectName/
├── Sources/
│   ├── App.swift             # @main entry point
│   ├── ContentView.swift
│   ├── Models/
│   ├── ViewModels/
│   ├── Views/
│   └── Services/
├── Package.swift             # SPM dependencies
├── project.yml               # XcodeGen config
└── .github/
    └── workflows/
        └── ci.yml
```

After scaffolding:
- SPM-only: `swift build` and `swift test` must succeed
- XcodeGen: `xcodegen generate` then `xcodebuild build` must succeed

## Naming

- Project/Package name: `PascalCase`
- Types/Protocols: `PascalCase`
- Functions/variables: `camelCase`
- Bundle ID prefix: `com.darrenkuro`

## Key Decisions

- **Swift 6.0**: Latest language version with full concurrency checking
- **SPM for dependency management**: Always include `Package.swift`
- **XcodeGen for apps**: Generate `.xcodeproj` from `project.yml` — never commit `.xcodeproj` to git
- **Platforms**: macOS 14.0+, iOS 17.0+ (adjust per-repo based on target)
- **SwiftUI + MVVM**: Models as value types, ViewModels as `@Observable` classes, Views as stateless SwiftUI components
- **Platform conditionals**: Use `#if os(iOS)` / `#if os(macOS)` for platform-specific code

## Versioning

Tags use **no `v` prefix**: `1.0.0` — this is required by SPM for version resolution.

```bash
git tag 1.0.0
git push --tags
```

## .gitignore (repo-specific)

Swift projects need a repo-specific `.gitignore` for Xcode/SPM artifacts not covered by the global gitignore:

```
xcuserdata/
*.xcworkspace/
Package.resolved
DerivedData/
.build/
*.xcodeproj
```

Only include `*.xcodeproj` if using XcodeGen (the generated project should not be committed).

## Build & Tooling Reference

For exact file contents (Package.swift, project.yml, CI workflow), read `references/setup.md`.
