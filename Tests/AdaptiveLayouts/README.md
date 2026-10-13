# Duo workspace regression

## Layout contract

- Outer display and inner portrait retain each complete phone page as one column.
- Inner landscape adds a separately scrolling secondary pane; available space and
  the inner display's reserved division determine eligibility, not a device name.
- Expense/income retain summary, quick categories and records on the left, with
  their own category/tag distribution and drilldown on the right.
- Vault retains overview, goals and deposits on the left, with ledger overview
  and monthly trend on the right.
- Statistics puts overview/trend on the left and distribution on the right.
- Settings and subsettings replace only the statistics right pane. A separate
  hosting root prevents navigation/toolbar preferences from taking over the page.
- Compact statistics continues to present settings using the production app sheet.
- Period bindings are shared within each page; selection state survives reparenting.
  Donut selection publishes only to the chart/list, not to the ledger or trend.

## General checks

Run on a wide iPad simulator:

```sh
bash Tests/AdaptiveLayouts/run.sh IPAD_SIMULATOR_UUID \
  -only-testing:LayoutTests -only-testing:ResizeTests/ResizeTests \
  -only-testing:ResizeTests/WorkspaceTests
```

The fixture uses an isolated bundle and QA records. Its Compact/Wide controls
override workspace eligibility solely for general layout testing. This does not
certify real Duo poses. The harness exposes the production AppRootView only in
its temporary source copy to test the real compact settings sheet.

Coverage: inner-landscape eligibility, accessibility fallback, all four page
compositions, independent scrolling, shared periods, right-settings navigation
and return, chart selection retention, editor draft rotation, resize closing an
exposed row without editing, and retained goal-deposit selection.

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
settings/subsettings staying on the right, return/close, goal filtering and all
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

## Verification status

On 2026-10-12 the redesigned workspace passed nine general cases, two phone
cases and two real opened Duo landscape cases under Xcode 27.1. The production
simulator build, two fixed-header cases, four chart-entrance cases and three
ledger-gesture cases also passed. Inspect xcresult summaries as the authority;
the RC diagnostic collector sometimes reports a missing simctl after completion.

Before release, still verify physical accessibility text sizes. The redesigned
partially-open pose, live folding and both Split View sides are recorded below;
no synthetic resize is counted as physical acceptance. Simulator acceptance does
not replace on-device checks.

On 2026-10-12/13 the iPad keyboard issue was reproduced and the amount controls
moved to a native UITextField inputAccessoryView. The full sequence
120+30-10*2/5 = 146, Done and keyboard dismissal passed on iPad Pro iOS 26.4.1.
The earlier failed/skipped operator case is now included in the general suite.
An additional warning from resigning first responder during a SwiftUI update was
fixed and its rerun had no runtime warnings. The new real-root presentation
migration case also passed, as did two phone cases, three row-gesture cases,
production build and plist/localization checks.

The complete general rerun passed all 11 cases with no skips or runtime warnings
(SimpleWorth-adaptive.fmYIKm/Results.xcresult). The phone rerun passed two cases
with no runtime warnings (SimpleWorth-adaptive.x2ALZ2/Results.xcresult).

The real fold round trip subsequently PASSED, superseding the earlier waiting
timeout (SimpleWorth-adaptive.O1arM0/Results.xcresult). App process 2321 retained
the expression/note draft across inner/outer switching, then retained the currency
route and donut selection across another closed/opened round trip. The fixture
observed real scenes of 951x669 and 466x678 points, without workspace overrides.

After recovering the preview, two native outer-display navigation/input/settings
cases passed with no skips or runtime warnings
(SimpleWorth-adaptive.bElTa9/Results.xcresult). At that point coverage was 19 passing
cases: 11 general, two phone, three row gestures, one live fold and two Duo outer.

On 2026-10-13, after the Mac was unlocked, actual left/right Split View and full
screen restoration PASSED (SimpleWorth-adaptive.YlFLkR/Results.xcresult), with
no skips or runtime warnings. Process 18309 stayed alive through 951x669,
469x669 left, 469x669 right, and 951x669 foreground scenes. All four compact
pages retained January; the amount/note draft survived the side change, and the
currency route returned to the right settings pane before Back/Done succeeded.

The RC reports a zero screen-space origin for either half-screen scene. The
live test therefore checks the actual reserved division at x=455.5 on the left
and x=0 on the right, together with scene width, foreground activation and PID.
Device Hub window captures corroborate real placement. An app-switcher snapshot
is not foreground acceptance, even if its scene has already regained full width.

This acceptance uncovered keyboard toolbar overflow in narrow Duo scenes: Done
was hidden behind More. The amount accessory now uses six equally sized native
buttons over system material, preserving all operators, Equals and Done without
UIToolbar overflow. Statistics accessibility containers also now preserve their
child control identifiers, so the overview month is not confused with the
offscreen distribution month. Earlier failed/interrupted split runs are superseded
only by the complete passing run above.

The latest accessory/container code passed 11 general iPad cases
(SimpleWorth-adaptive.oC1ezk/Results.xcresult), two narrow iPhone SE cases
(SimpleWorth-adaptive.FaSgni/Results.xcresult), and two native Duo landscape cases
(SimpleWorth-adaptive.j6n8tB/Results.xcresult). All had zero skips/runtime warnings.
The expanded native input case checks every operator, Equals, Done, calculation
and a minimum 44-point hit region for each operator.

A stricter live fold rerun also PASSED
(SimpleWorth-adaptive.nhNqOy/Results.xcresult), with no skips/runtime warnings.
Process 21299 preserved the expression/note, currency route and donut selection
through two round trips. Each acceptance waited for both scene/root geometry and
the final hinge angle: closed 0 degrees at 466x678 and opened 180 degrees at
951x669. Intermediate pose updates are not accepted.

The redesigned native partially-open interaction case PASSED
(SimpleWorth-adaptive.KD3Sxw/Results.xcresult), with no skips/runtime warnings.
Device Hub's default Partially Open control reports approximately 127.78 degrees,
not 90 degrees. Its active vertical division occupied x=455.5...495.5 points;
the test checked left-ledger/right-distribution avoidance, swipe closure without
editing, donut selection, right settings, goal filtering and all four operators.
This verifies that sampled pose, not every possible hinge angle.

Two latest native outer-display cases also PASSED
(SimpleWorth-adaptive.ZN3Bbi/Results.xcresult), with no skips/runtime warnings.
The latest verification matrix therefore contains 20 passing cases: 11 general,
two iPhone SE, two Duo landscape, one partially-open, two Duo outer, one strict
live fold and one actual Split View round trip. The earlier three ledger-gesture
cases remain separate evidence, not part of that count.

The main SimpleWorth project built successfully in Release for generic iOS
using Xcode 27.1 with CODE_SIGNING_ALLOWED=NO
(/tmp/SimpleWorth-Duo-Validation-Release.log). Info.plist, all four localization
files and git diff --check passed. This is an unsigned build check, not a signed
archive, App Store Connect upload or TestFlight release. At the end of that
acceptance pass the version was 0.7.21 (32); no commit, push, version bump or
upload was performed during acceptance.

Apple describes the Device Hub home-indicator drag/drop procedure in
[Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/).

## Phone scrolling regression

Run the real-root end-clearance and long multi-tag ledger cases on a phone:

```sh
bash Tests/AdaptiveLayouts/run.sh PHONE_SIMULATOR_UUID \
  -only-testing:ResizeTests/ScrollingTests/testAllPhonePageEndsClearTheTabBar \
  -only-testing:ResizeTests/ScrollingTests/testLongTaggedLedgerScrollsWithoutEditing
```

Run tag wrapping across compact/wide/compact widths on a wide iPad:

```sh
bash Tests/AdaptiveLayouts/run.sh IPAD_SIMULATOR_UUID \
  -only-testing:ResizeTests/ScrollingTests/testTaggedRowsReflowAcrossWorkspaceWidths
```

QA_SCROLL_ROWS=300 seeds 300 expense and 300 income records with four tags in
the isolated QA store only. Returning to the default fixture restores 25 records
per flow. Neither mode changes production data. The width case requires a wide
iPad; the end-clearance case requires the phone's custom bottom navigation.

On 2026-10-13, before the fix, the end-clearance case reproduced a 24.5-point
overlap on iPhone SE: the last expense row ended at y=623 while the navigation
bar began at y=598.5 (SimpleWorth-adaptive.ZGdktY/Results.xcresult). Main pages
now reserve the measured floating bar height in addition to their normal bottom
spacing. Native navigation and presented editors do not receive this extra
clearance. All four phone pages are checked using the complete final row bounds,
not just a visible label or its hittability.

Scroll-position updates now invalidate only their scroll-view wrapper, keeping
the page's data builders out of visible-row updates. Each ledger list shares one
filtered/sorted record set and tag-color lookup per render. Tag wrapping caches
its measurement/placement arrangement, and initial row-width tracking no longer
triggers a second row render. Actual width changes still close exposed actions
and suppress accidental editing. Existing copy/refund/delete, vertical scrolling,
elastic horizontal gestures, haptics and chart animations are retained.

The latest production code passed four iPhone 17 Pro cases, including both new
phone scrolling cases and native settings/amount input
(SimpleWorth-adaptive.CvYGOD/Results.xcresult). Eleven general iPad cases passed
(SimpleWorth-adaptive.noCJjq/Results.xcresult), as did the multi-tag width case
(SimpleWorth-adaptive.mqi6L4/Results.xcresult) and all three ledger-gesture cases
(SimpleWorth-row-gestures.9vgNSn/Results.xcresult). Each result had no skips or
runtime warnings. The earlier SE check passed end clearance and native amount
input (SimpleWorth-adaptive.UcjgJX/Results.xcresult); its scroll-position owner was
subsequently refined, so the iPhone 17 Pro and general results are the later code
evidence.

The final iPhone SE rerun also passed all four page ends with the refined
scroll-position owner and final test guards, without skips or runtime warnings
(SimpleWorth-adaptive.2GKxcB/Results.xcresult).

The long-ledger test collects scroll-deceleration duration only. It does not
measure display FPS or hitch counts and is not evidence of a quantified frame
rate improvement. Real-device smoothness still needs a new TestFlight build.
The main project also passed an unsigned Release build
(/tmp/SimpleWorth-Scroll-Release-Validation.log). At the end of this local fix
acceptance, the version was still 0.8.0 (33), without a commit, push, archive or
upload. The subsequently requested release increments it to 0.8.1 (34).
Previous live fold/Split View results above remain historical evidence; this
pass reruns synthetic width continuity, not physical pose transitions.
