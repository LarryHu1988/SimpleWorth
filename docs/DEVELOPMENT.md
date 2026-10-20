# Development · SimpleWorth 1.0

## Project

`project.yml` is the XcodeGen source of truth. Generate with `xcodegen generate` after editing project configuration. The checked-in Xcode project is included for convenient inspection.

- `Sources/App`: app entry point, settings and account integration.
- `Sources/Models`: SwiftData ledger, categories, currencies and backup models.
- `Sources/Views`: expense, income, vault, statistics and settings UI.
- `Sources/Theme`: shared colours, materials, chart motion and layout components.
- Localized resources: Simplified Chinese, Traditional Chinese, English and Japanese.

Use a full Xcode installation with a compatible iOS SDK. The shared navigation modifier uses an iOS 27.1 availability guard because the 27.0 runtime cannot resolve that modifier when built with the 27.1 SDK. Older systems use the compatible fallback.

## Isolated regression suites

Install XcodeGen and an iOS simulator runtime. List available simulators with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available
```

Each runner creates a temporary project and uses a separate QA bundle or in-memory data. Do not point QA tools at a production ledger.

| Suite | Entry point | Scope |
| --- | --- | --- |
| [Row gestures](../Tests/RowGestures/README.md) | `bash Tests/RowGestures/run.sh SIMULATOR_UUID` | Swipe arbitration, copy, refund, delete, tap |
| [Fixed headers](../Tests/FixedHeaders/README.md) | `bash Tests/FixedHeaders/run.sh SIMULATOR_UUID` | Four page titles and date controls while scrolling |
| [Chart motion](../Tests/ChartEntrance/README.md) | `bash Tests/ChartEntrance/run.sh SIMULATOR_UUID` | One-second entrance, ring caps, selection, Reduce Motion |
| [Categories and tags](../Tests/CategoriesTags/README.md) | `bash Tests/CategoriesTags/run.sh SIMULATOR_UUID` | Category completeness, ordering, persistence, migration |
| [Adaptive layouts](../Tests/AdaptiveLayouts/README.md) | `bash Tests/AdaptiveLayouts/run.sh SIMULATOR_UUID` | Native and synthetic width, settings panes, keyboard, state continuity |

The migration seeder uses a fixed historical commit rather than a retired release tag. Keep Git history available when running that migration check.

## Layout contract and known limitation

Phone layouts keep a complete single column. Duo outer-display navigation uses a system rail on the right; inner portrait uses the normal phone composition. A wide inner display can use two independently scrolling panes. Width tests alone do not establish physical fold or rotation acceptance.

**Duo closed outer-display upside-down portrait is unresolved.** The shell can rotate without the app adopting the expected portrait layout. Native scene rotation was rejected in the iOS 27.1 diagnostic, and an app-window transform failed keyboard and safe-area checks. No transform workaround is shipped and no claim of full orientation support should be made.

Record actual native pose, scene geometry, keyboard, safe areas and retained state together. Simulator results do not replace device checks. Store screenshots, logs and xcresult bundles outside the repository; record the exact commit and distinguish failures, skips and successful reruns.

## Release scope

See [release retention](RELEASES.md): retain 1.0 and later versions.

GitHub presentation and version metadata are unified at **1.0 (1)**. App Store availability is linked from the product pages. Pending in-app-event preparation is not part of the 1.0 product announcement. Submission materials, account records, build archives and generated evidence belong in the local release workspace and are ignored by Git.
