# Abeta KMP Kit — Swift Package Manager Mirror (`Abeta-dev/kmp-spm`)

Direct-URL binary Swift Package Manager distribution for [`Abeta-dev/kmp`](https://github.com/Abeta-dev/kmp) Apple Release XCFrameworks (**`AbetaSduiKit`** for iOS/iPadOS 15+ and **`AbetaWatchKit`** for watchOS 9+).

- **Latest Release**: `0.1.0` ([`Abeta-dev/kmp@v0.1.0`](https://github.com/Abeta-dev/kmp/releases/tag/v0.1.0))
- **Live Portal & WasmJS Storybook**: https://abeta-dev.github.io/kmp/
- **AI / LLM Docs**: [`llms.txt`](llms.txt) · [`Abeta-dev/kmp/llms.txt`](https://raw.githubusercontent.com/Abeta-dev/kmp/main/llms.txt)

---

## Xcode — Add Package Dependency (Zero Auth)

1. Open your Xcode project -> **File -> Add Package Dependencies...**
2. Enter the package URL:
   ```
   https://github.com/Abeta-dev/kmp-spm
   ```
3. Select **Up to Next Major Version** starting from **`0.1.0`**.
4. Link:
   - **`AbetaSduiKit`** -> your **iOS / iPadOS 15+** app target (`import AbetaSduiKit`)
   - **`AbetaWatchKit`** -> your **watchOS 9+** app target (`import AbetaWatchKit`)

---

## `Package.swift` Dependency

```swift
dependencies: [
    .package(url: "https://github.com/Abeta-dev/kmp-spm.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "MyIosApp",
        dependencies: [
            .product(name: "AbetaSduiKit", package: "kmp-spm"),
        ]
    ),
]
```

## Checksums (`SHA256SUMS.txt`)

All binary target SHA-256 checksums are verified with `swift package compute-checksum` and published alongside the upstream GitHub Release at https://github.com/Abeta-dev/kmp/releases/tag/v0.1.0.
