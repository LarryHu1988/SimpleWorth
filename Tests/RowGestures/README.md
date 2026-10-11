# Row Gesture Regression Checks

Requirements: Xcode with an iOS simulator runtime, and XcodeGen.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available
bash Tests/RowGestures/run.sh SIMULATOR_UUID
```

The runner extracts `SwipeableLedgerRow` and `HorizontalPanGestureBridge` from the current
production source into a temporary test app. Only the entry presentation and business
callbacks are replaced with fixtures. The original gesture arbitration, action buttons,
tap suppression, haptics and spring animations run unchanged inside nested lazy stacks
and a SwiftUI scroll view.

Checks:

- Repeated left/right swipes with upward/downward drift keep the page's vertical position.
- Returning an open row never calls the edit callback.
- Vertical scrolling works on both closed and open rows.
- Copy, refund, delete and ordinary tap callbacks remain reachable.

All data is in-memory. The test app uses a separate bundle identifier, does not access
the ledger database or iCloud, and is not part of the shipping app target. Build artifacts
and the `.xcresult` report remain in the temporary directory printed by the runner.

This is component-level UI coverage; real-device verification of the full ledger page
remains necessary before release.
