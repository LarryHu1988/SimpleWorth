<div align="center">
<img src="docs/assets/icon.png" width="96" alt="SimpleWorth app icon">

# SimpleWorth

### Less clutter. More clarity.

Keep up with everyday spending. Make steady progress toward your goals.

**1.0** · Free · No ads · iPhone / iPad · iOS 17+

[Download on the App Store](https://apps.apple.com/app/id6761478113) · [Product website](https://larryhu.com/simpleworth/) · [简体中文](README.md)
</div>

## Four spaces for everyday life

| Expenses | Income | Vault | Statistics |
| --- | --- | --- | --- |
| Categories, tags and notes | Monthly income records | Goals, deposits and progress | Overview, trends and breakdowns |

SimpleWorth brings a calm, translucent interface to daily bookkeeping. Record expenses and income, duplicate entries, handle expense refunds, and calculate amounts with the built-in arithmetic controls. Explore monthly trends and interactive category or tag charts. Set savings goals with optional deadlines and track each deposit.

Use common currencies with base-currency conversion. Choose light, dark or system appearance. The app supports Simplified Chinese, Traditional Chinese, English and Japanese, with layouts that adapt to iPhone and iPad.

## Your data, your control

Core bookkeeping works offline, with ledger data stored on your device by default. No app account is required. The app has no advertising or cross-app tracking SDKs and does not upload ledger content to developer-operated servers.

Optional iCloud automatic backup provides backup and restore under your Apple Account; it does not merge ledgers in real time. Restoring replaces the current on-device data. File import and export are available. Exchange-rate refreshes need a network connection; rates are indicative. See the [privacy policy](https://larryhu.com/simpleworth/privacy/) for service and data-handling details.

## Download and support

[App Store](https://apps.apple.com/app/id6761478113) · [Support](https://larryhu.com/simpleworth/support/#english) · [Privacy](https://larryhu.com/simpleworth/privacy/#english)

Contact [simpleworth@larryhu.com](mailto:simpleworth@larryhu.com). Include your app version, device, OS and steps to reproduce an issue. Redact private ledger details in screenshots.

## Development

SwiftUI, SwiftData, Swift Charts and XcodeGen. Minimum iOS / iPadOS 17; version **1.0 (1)**. Run `xcodegen generate`, then open `SimpleWorth.xcodeproj`. Physical-device development requires your own signing and iCloud configuration.

See [development and isolated test instructions](docs/DEVELOPMENT.md), including the unresolved Duo outer-display upside-down portrait limitation. Only the **1.0** release and version tag are retained in this repository.

© 2026 Larry Hu. All rights reserved.
