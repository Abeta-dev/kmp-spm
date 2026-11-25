# Abeta KMP Kit — Swift Package Manager Mirror (`Abeta-dev/kmp-spm`)

Direct-URL Swift Package Manager distribution for [`Abeta-dev/kmp`](https://github.com/Abeta-dev/kmp) Apple Release XCFrameworks and plug-and-play SwiftUI host wrappers:

- **`AbetaSduiKit`** — Binary XCFramework for iOS / iPadOS 15+ (`import AbetaSduiKit`)
- **`AbetaWatchKit`** — Binary XCFramework for watchOS 9+ (`import AbetaWatchKit`)
- **`AbetaWatchSwiftUI`** — Ready-made SwiftUI renderer for `WatchGlancePage` (`AbetaWatchGlanceView`, `AbetaWatchMetricRow`, `AbetaWatchStatusBadge`, `AbetaWatchActionButton`, `AbetaWatchNavigationRoot`) (`import AbetaWatchSwiftUI`)
- **`AbetaSduiSwiftUI`** — SwiftUI `UIViewControllerRepresentable` host wrapper (`AbetaSduiHostView`) for iOS / iPadOS (`import AbetaSduiSwiftUI`)

- **Latest Release**: `0.6.0` ([`Abeta-dev/kmp@v0.6.0`](https://github.com/Abeta-dev/kmp/releases/tag/v0.6.0))
- **Live Portal & WasmJS Storybook**: https://abeta-dev.github.io/kmp/
- **AI / LLM Docs**: [`llms.txt`](llms.txt) · [`Abeta-dev/kmp/llms.txt`](https://raw.githubusercontent.com/Abeta-dev/kmp/main/llms.txt)

---

## Xcode — Add Package Dependency (Zero Auth)

1. Open your Xcode project -> **File -> Add Package Dependencies...**
2. Enter the package URL:
   ```
   https://github.com/Abeta-dev/kmp-spm
   ```
3. Select **Up to Next Major Version** starting from **`0.6.0`**.
4. Link:
   - **`AbetaSduiKit`** and/or **`AbetaSduiSwiftUI`** -> your **iOS / iPadOS 15+** app target
   - **`AbetaWatchKit`** and/or **`AbetaWatchSwiftUI`** -> your **watchOS 9+** app target

---

## `Package.swift` Dependency

```swift
dependencies: [
    .package(url: "https://github.com/Abeta-dev/kmp-spm.git", from: "0.6.0"),
],
targets: [
    .target(
        name: "MyIosApp",
        dependencies: [
            .product(name: "AbetaSduiSwiftUI", package: "kmp-spm"),
        ]
    ),
    .target(
        name: "MyWatchApp",
        dependencies: [
            .product(name: "AbetaWatchSwiftUI", package: "kmp-spm"),
        ]
    ),
]
```

## Checksums (`SHA256SUMS.txt`)

All binary target SHA-256 checksums are verified with `swift package compute-checksum` and published alongside the upstream GitHub Release at https://github.com/Abeta-dev/kmp/releases/tag/v0.6.0.
