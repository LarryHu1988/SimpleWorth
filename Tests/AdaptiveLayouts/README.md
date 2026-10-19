# Duo workspace regression

## Layout contract

- Outer display in either orientation retains each complete phone page as one
  column, with system tabs vertically aligned on the right rail. Page navigation
  keeps compact sizing independently of tab placement, avoiding duplicate side
  insets. Inner portrait keeps the same floating bottom tabs as a slab iPhone.
  Card widths follow the current usable viewport; a large camera/status safe
  area alone never enables side tabs or a workspace.
- Inner landscape adds a separately scrolling secondary pane; available space and
  the inner display's reserved division determine eligibility, not a device name.
- Expense/income retain summary, quick categories and records on the left, with
  their own category/tag distribution and drilldown on the right.
- Vault retains overview, goals and deposits on the left, with ledger overview
  and monthly trend on the right. Goal rows retain tap-to-edit and the existing
  progress display, without extra per-goal deposit buttons or duplicate goals.
- Statistics puts overview/trend on the left and distribution on the right.
- Settings and subsettings replace only the statistics right pane. A separate
  hosting root prevents navigation/toolbar preferences from taking over the page.
  Both keep at least 16 points of horizontal content padding within that pane;
  embedded presentation is a separate environment value from content padding.
- Compact statistics continues to present settings using the production app sheet.
- Settings language controls try a smaller inline font and spacing before using
  a second row; normal Duo landscape keeps the label and all four options aligned.
- All four main titles/date controls stay visible while scrolling. On iOS 27,
  the shared title modifier disables navigation-bar minimization explicitly.
- Period bindings are shared within each page; selection state survives reparenting.
  Donut selection publishes only to the chart/list, not to the ledger or trend.

## General checks

Run on a wide iPad simulator:

```sh
bash Tests/AdaptiveLayouts/run.sh IPAD_SIMULATOR_UUID \
  -only-testing:LayoutTests -only-testing:ResizeTests/ResizeTests \
  -only-testing:ResizeTests/WorkspaceTests
```

The fixture uses an isolated bundle and QA records, and its visible app name is
`简值布局测试`. A default/manual launch uses the production AppRootView and native
viewport, with no artificial width or Compact/Wide buttons. Those controls
require `QA_SYNTHETIC_SIZE=1`, which the synthetic test cases explicitly supply.
They override workspace eligibility solely for general layout testing and do
not certify real Duo poses. The harness exposes the production AppRootView only
in its temporary source copy to test the real compact settings sheet.

Coverage: inner-landscape eligibility, accessibility fallback, all four page
compositions, independent scrolling, shared periods, right-settings navigation
and return, chart selection retention, editor draft rotation, resize closing an
exposed row without editing, and plain goals/deposits across resizing.

The presentation-migration case uses QA_WORKSPACE_COMMANDS and an isolated
fixture command file to switch eligibility while the real settings sheet is
open. It verifies the currency route, right-pane bounds, close/return and retained
donut selection. This deliberately synthetic check is not real folding or Split
View acceptance. The editor-draft case checks values after orientation requests;
the Xcode 27.1 RC may accept those requests without physically rotating the iPad.

## Native checks

Set the physical pose in Device Hub before running:

```sh
bash Tests/AdaptiveLayouts/run.sh DUO_SIMULATOR_UUID \
  -only-testing:ResizeTests/NativeDeviceTests/testNativeNavigationAndEntryDraft \
  -only-testing:ResizeTests/NativeDeviceTests/testNativeWideInteractions
```

The wide case skips unless the actual viewport is an inner-landscape workspace;
a skip is not acceptance. It tests copy-swipe closure, donut cross-highlighting,
settings/subsettings staying on the right, return/close, plain goals/deposits and all
four amount operators. The expression 120+30-10*2/5 must evaluate to 146, with a
bounded three-second accessibility readback. System back controls can reside
on Duo's right rail rather than in the horizontal navigation bar.

On a phone, also run testCompactSettingsRoutesAndReturn and
testNativeNavigationAndEntryDraft. QA_REAL_ROOT uses the actual production root,
including its settings sheet; QA_NATIVE_SIZE has no artificial width controls.

Fixture.swift records process ID, scene size/activation, geometry, origin, hinge
angle/status and reserved division in its Documents/qa-pose.json, also exposed
as the QA-only qa.pose element. The live tests read the atomic fixture file
because accessibility values beneath a presented sheet can be stale.
Native assertions check the left ledger and right distribution against active
vertical divisions. XCTest images may capture an inactive display and be black;
use simctl io DEVICE screenshot --display=primary-1 for inner-screen visual QA.

## Actual pose and Split View checks

For the Duo layout repairs and current navigation policy, start closed in portrait and run:

```sh
QA_LIVE_TRANSITIONS=1 bash Tests/AdaptiveLayouts/run.sh DUO_SIMULATOR_UUID \
  -only-testing:ResizeTests/LiveTransitionTests/testDuoPhoneNavigationAcrossPoses
```

At each `SIX_FIXES_*` stage, use Device Hub to open landscape, rotate the inner
display to portrait, close and rotate the outer display to landscape, then return
to outer portrait. The test uses one unchanged app process with native geometry,
checks all four pages in every pose, checks the default fixture has no width
buttons, verifies right-side navigation on the outer display, bottom navigation
in inner portrait and full usable card widths in phone poses,
and measures the embedded settings content margins.

These opt-in tests keep one app process alive throughout each sequence. Start
with a fully opened landscape Duo; the folding case also accepts a closed Duo.
Operate Device Hub only when the corresponding QA_LIVE_STAGE is printed:

```sh
QA_LIVE_TRANSITIONS=1 bash Tests/AdaptiveLayouts/run.sh DUO_SIMULATOR_UUID \
  -only-testing:ResizeTests/LiveTransitionTests/testActualFoldContinuity

QA_LIVE_TRANSITIONS=1 bash Tests/AdaptiveLayouts/run.sh DUO_SIMULATOR_UUID \
  -only-testing:ResizeTests/LiveTransitionTests/testActualSplitViewContinuity
```

Fold stages use fully closed outer and fully opened landscape inner displays.
They check the expression/note draft, currency subsettings migration and retained
donut selection without relaunching. Split stages place the app on the left,
then right, then restore full screen. They check all four compact pages, shared
period retention, an editor draft, and migration of currency settings back to the
right pane. Real division placement, actual width, active foreground scene and
unchanged process ID are required;
fake width overrides cannot satisfy these cases. Each requested transition has
a bounded 15-minute wait. Skips and timeouts are not acceptance.

## Known limitation

Closed Duo outer-display upside-down portrait remains unresolved. Rotating the
device shell is not evidence that the app content has adopted portrait geometry.
The iOS 27.1 diagnostic rejected a native upside-down geometry request with
`UISceneErrorDomain / 101`; an app-window transform also failed keyboard and
safe-area acceptance and is not included in the app. Do not count this pose as
supported. Reproduce with actual Device Hub pose changes and verify content,
keyboard, active geometry and safe areas together.

## Recording results

Keep xcresult bundles and device screenshots outside the repository. Record the
commit, Xcode/runtime, native pose and test counts for each new run. Synthetic
resizing, skipped tests and timeouts do not establish physical-pose acceptance.
