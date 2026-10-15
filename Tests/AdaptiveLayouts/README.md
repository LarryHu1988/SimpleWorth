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

## In-place category expansion

Run the phone case with the real root and the workspace case on a wide iPad:

```sh
bash Tests/AdaptiveLayouts/run.sh PHONE_SIMULATOR_UUID \
  -only-testing:ResizeTests/ScrollingTests/testCategoryExpansionStaysInPlaceOnPhone

bash Tests/AdaptiveLayouts/run.sh IPAD_SIMULATOR_UUID \
  -only-testing:ResizeTests/ScrollingTests/testCategoryExpansionStaysInPlaceInWorkspace
```

On 2026-10-13, the pre-fix iPhone 17 Pro case reproduced the reported jump after
a short scroll: expanding expense categories moved the toggle from y=179.5 to
y=-1348.8 (SimpleWorth-adaptive.3gPXaa/Results.xcresult). Only ledger rows had
registered scroll targets; SwiftUI retained one of those rows as the content
above it expanded. Apple's
[scroll-position documentation](https://developer.apple.com/documentation/swiftui/view/scrollposition%28id%3Aanchor%3A%29)
describes identity-based position retention.

The ledger header now has stable UUID targets for its summary, category toggle
and category grid. Its target layout is a sibling of the existing ledger-row
target layout, so the individual row targets remain available after scrolling
past the header. No forced scroll-to-top, content-offset mutation or delayed
scroll correction is added. Expense and income share the same fix; categories,
search, entry presets, animations and ledger actions are unchanged.

Phone cases check repeated expansion/collapse at the top and after a short
scroll, with at most four points of toggle movement, a visible search field and
no accidental editor. Both iPhone 17 Pro
(SimpleWorth-adaptive.XVUslr/Results.xcresult) and iPhone SE
(SimpleWorth-adaptive.sZteAv/Results.xcresult) passed this case and all four page
end-clearance checks without skips or runtime warnings. The workspace case also
checks that the right chart's frame does not move while the left categories
expand. These are isolated simulator checks, not a new live Duo fold acceptance
or TestFlight upload.

The workspace case and nine existing resize/workspace cases passed together
(SimpleWorth-adaptive.DCI5gK/Results.xcresult), with no skips or runtime warnings.
This includes independent scrolling, shared periods, exposed-row closure,
chart/goal selections, real-root settings migration and amount-input controls.
The main project passed an unsigned Release build
(/tmp/SimpleWorth-Category-Expansion-Release.log) and git diff --check. At this
acceptance point the fix was local only; TestFlight was still 0.8.1 (34), without
this category-expansion fix. The subsequent release request increments the
version to 0.8.2 (35).

## Main-page category grid without search

The next local change removes the search field, query state, filtering and
no-match message from the shared expense/income main-page category grid. It
iterates the complete category library directly. Category selection still opens
the matching entry editor. The separate editor category search and currency
search are unchanged.

The in-place expansion cases now assert that no category search field exists
on either main page and that the first category is visible after expansion,
while retaining the toggle-position and right-pane checks. The new
testCategoryGridKeepsLastCategoryAndEntryAction case scrolls to the final
expense/income category and opens/cancels each matching entry editor. It does
not save records into the fixture or production store.

On 2026-10-13, three iPhone SE cases passed
(SimpleWorth-adaptive.B669KQ/Results.xcresult): in-place expansion without search,
last-category entry actions, and full final-item clearance on all four pages.
The workspace expansion case passed on iPad Pro
(SimpleWorth-adaptive.RUWGca/Results.xcresult), preserving the right chart frame.
Both results had no skips or runtime warnings. Earlier expansion results above
describe the previous version with a search field; they are not the current
no-search acceptance. These checks are simulator evidence, not a new Duo fold
round trip or TestFlight upload.
The main project passed an unsigned Release build
(/tmp/SimpleWorth-Category-NoSearch-Release.log) and git diff --check. This change
was local at 0.8.2 (35), without a commit, version bump or upload. The subsequent
release request increments the version to 0.8.3 (36).

## Native Duo category, editor and settings refinements

The editor category selector now uses the complete library without a search
field on every device. In an opened landscape workspace, amount, note, date
and tags share the left column; only categories occupy the right column.
Workspace ledger create/edit/copy/refund presentations use a full-screen cover
so the native Duo modal does not restrict the editor to a half-screen column.
The presentation mode is captured when opening, not changed during a fold,
preserving the existing editor draft and operation. Compact launches retain
their ordinary sheet presentation. Currency search remains available.

Statistics now uses the same navigation/title helper as the other three pages.
All four titles are explicitly leading; native principal positioning can shift
on narrow displays depending on the number of trailing date controls.
Its embedded settings hosting root is overlaid outside the main navigation
stack, using the actual secondary-pane bounds. This preserves independent
subsettings navigation and keeps overview/trend visible on the left. The
workspace continues to use the physical division even while the embedded
navigation changes the division's active flag, avoiding a column-width jump.

The workspace supplies settings page margins once. Embedded root/detail pages
do not reapply the native device rail's horizontal safe area, while keyboard
avoidance remains enabled. Compact settings retain their original margins and
native navigation. See Apple's documentation for
[UIHostingController.safeAreaRegions](https://developer.apple.com/documentation/swiftui/uihostingcontroller/safearearegions).

Additional physical-pose regressions:

```sh
bash Tests/AdaptiveLayouts/run.sh DUO_SIMULATOR_UUID \
  -only-testing:ResizeTests/NativeDeviceTests/testNativeCategoryExpansionAndMainTitles \
  -only-testing:ResizeTests/NativeDeviceTests/testNativeWideEditorColumnPlacement \
  -only-testing:ResizeTests/NativeDeviceTests/testNativeWideSettingsContentWidth \
  -only-testing:ResizeTests/NativeDeviceTests/testNativeWideLedgerEditorOperations
```

The category/title case applies to actual outer, inner portrait and landscape
poses. It checks all four title coordinates, both flows' repeated in-place
expansion/collapse, and absence of search. Wide-only cases require a real
landscape workspace; skips are not acceptance. They check editor columns,
create/edit/copy/refund entry points, root/currency settings content bounds,
and unchanged left-pane geometry. The live fold case additionally checks that
category search stays absent and the editor restores its wide column layout.

General resize tests use bounded layout readbacks before asserting the target
width; category UI tests scroll lazy cells into existence before reading their
frames. Both retain their original interaction and state assertions.

The 2026-10-13 local verification covered:

- Eleven general iPad cases, with zero skips/runtime warnings
  (SimpleWorth-adaptive.kevk3r/Results.xcresult).
- Two latest compact settings/title/category phone cases
  (SimpleWorth-adaptive.14onp6/Results.xcresult), plus the four initial phone
  navigation/input/category/end-clearance cases
  (SimpleWorth-adaptive.HtcGo7/Results.xcresult). Both had no skips/warnings.
- Nine category/tag model and UI cases, including complete expense/income
  selection, legacy categories, reorder persistence and backup compatibility
  (SimpleWorth-categories-tags.LXWLhV/Results.xcresult).
- Three ledger gesture cases
  (SimpleWorth-row-gestures.0FFX3n/Results.xcresult) and two bilingual fixed-header
  cases (SimpleWorth-fixed-headers.tHArHj/Results.xcresult).
- Actual opened Duo title/category checks passed in
  SimpleWorth-adaptive.O5m5YP/Results.xcresult. Its compact settings case skipped
  because the device was wide; that skip is not outer-display acceptance.
- Actual opened Duo editor columns and edit/copy/refund cases passed in
  SimpleWorth-adaptive.OEijdn/Results.xcresult. Its initial Equals readback failed;
  the full native interactions rerun passed in
  SimpleWorth-adaptive.6QhOjf/Results.xcresult with expression 146. This rerun's
  root Done target was only 34 points tall, so the target was corrected within
  the button label. Final root/currency width, unchanged left-pane bounds and
  44-point Done checks passed with no skips/warnings in
  SimpleWorth-adaptive.eiOUOS/Results.xcresult.

The actual fold attempt SimpleWorth-adaptive.ZDIkJR/Results.xcresult retained
120+30 and the note in process 61781 across closed 0-degree outer and opened
180-degree landscape scenes. It then timed out waiting for the settings-close
pose. This is partial draft evidence, not a passing complete fold case.
SimpleWorth-adaptive.eQJdQf/Results.xcresult observed the earlier outer title
misalignment and skipped all four wide cases; neither failures nor skips count
as acceptance. After the title correction, actual inner portrait, outer display
and a complete settings fold round trip were pending the subsequent native
verification below.

Embedded settings additionally expand the custom Done header to the assigned
pane and adapt language controls without truncation. Ordinary compact settings
retain native navigation. These changes remain local at 0.8.3 (36): no version
bump, commit, signed archive or TestFlight upload is implied by these tests.

On 2026-10-14, actual fully opened inner portrait geometry was 669x951 points
with a 180-degree hinge. The native amount/navigation case passed in
SimpleWorth-adaptive.Th59k6/Results.xcresult, but that run failed two default-hit
cases: tapping the statistics tab left vault selected, and the visible category
toggle reported non-hittable. No production change was inferred from those
automation failures.

Native tests now tap visible tab icons/control centers and require the selected
tab and actual page title to agree. Category checks retain the four-point
in-place expansion limit, assert visible bounds, and additionally open/cancel a
category-preset editor. Preset cells are scrolled into the editor viewport before
checking their selection, including on a short phone.

Both inner portrait title/category/preset and compact-settings-return cases
passed with zero skips/runtime warnings in
SimpleWorth-adaptive.1tzfBh/Results.xcresult. The expanded iPhone SE rerun also
passed both cases with zero skips/runtime warnings in
SimpleWorth-adaptive.tOF6H6/Results.xcresult. Its earlier baXjoD run stopped at a
lazy preset cell that had not been scrolled into existence; it is not a pass.

For a focused actual settings migration/fold check, keep the currency subpage
open in the same app process while operating Device Hub at the printed stages:

```sh
QA_LIVE_TRANSITIONS=1 bash Tests/AdaptiveLayouts/run.sh DUO_SIMULATOR_UUID \
  -only-testing:ResizeTests/LiveTransitionTests/testActualSettingsFoldContinuity
```

When starting compact, SETTINGS_LANDSCAPE first requests fully opened landscape.
FOLD_SETTINGS_CLOSE and FOLD_SETTINGS_OPEN then check outer/inner migration,
unchanged PID, foreground scene, currency-route retention, left overview and
donut selection after Back/Done. Each transition retains the bounded 15-minute
wait. Until the complete case and final outer-page tests pass, the earlier
settings-fold and outer-display acceptance gaps remain open.

The first focused run, SimpleWorth-adaptive.ajEw3Z/Results.xcresult, selected
the shoe sector and opened currency settings in actual inner portrait process
6907. It timed out at SETTINGS_LANDSCAPE after 15 minutes without observing the
required wide scene. No transition is certified by this failed run; settings
fold and final outer-page checks were still pending at that point. The passing
portrait and phone results above are separate evidence, not a claim that this
live case passed.

The subsequent focused run on 2026-10-14 started in actual opened landscape and
passed the full settings fold round trip in
SimpleWorth-adaptive.Lb6h45/Results.xcresult: one pass, zero failures/skips and
no runtime warnings. Process 38686 stayed foreground throughout 951x669-point
opened landscape (180 degrees), 466x678-point closed outer display (0 degrees),
and restored 951x669-point landscape. Currency settings retained its route;
Back/Done, the restored left overview, retained shoe-sector selection and the
January period menu all passed. This closes the actual landscape-to-outer-to-
landscape settings gap; it does not certify the timed-out initial portrait-to-
landscape transition in ajEw3Z.

Final actual closed outer-display acceptance passed all three native cases in
SimpleWorth-adaptive.VXQ6Dx/Results.xcresult, with zero failures/skips and no
runtime warnings. Recorded geometry was 466x678 points, a closed 0-degree hinge
and a 382x644-point content root, without workspace overrides. All four title
coordinates, repeated in-place expense/income category expansion, preset editor
selection without category search, settings currency Back/Done, and all four
amount operators/Equals/Done passed. The selected-category editor test scrolls
back to the amount area before checking Cancel. Its reveal helper uses the
active window's bounds and scrolls in either direction to reach the target.

The earlier outer run SimpleWorth-adaptive.u8L1Ht/Results.xcresult passed settings
and amount input but failed to find Cancel after scrolling to the preset cell;
that run is not complete acceptance. The final rerun retained all assertions.
The same title/category/preset and settings cases passed on iPhone SE in
SimpleWorth-adaptive.xkJrGV/Results.xcresult, again with zero failures/skips or
runtime warnings. These are isolated simulator checks, not a signed archive,
version change, commit, push or TestFlight upload.

## Responsive width repair, 2026-10-14

The closed Duo stress case reproduced a 122-point-high, three-line summary
amount in SimpleWorth-adaptive.owV5A2/Results.xcresult. Earlier short QA amounts
did not exercise that constraint. Page and editor content now receive a finite
width from their current geometry after page margins, rather than relying on
unconstrained ideal widths. Compact pages fill up to 760 points of content;
the system-owned rail and safe area remain outside that allocation. Cards fill
their assigned columns. No device model names or nominal UIScreen widths are
used for these layouts.

SWOverviewLayout measures heading, amount and detail separately. The ring follows
the current content width, while money remains one line. If the complete amount
cannot fit beside the ring at the permitted text scale, it receives a full-width
row below the heading/ring instead of an ellipsis. Expense, income and vault use
the same rule. Statistics and settings metric pairs use an intrinsic-width check
to choose equal columns or full-width rows. Donut center labels follow the actual
chart diameter and inner radius. These measurements use SwiftUI's
[Layout proposals](https://developer.apple.com/documentation/swiftui/layout)
without publishing scroll-driven sizing state.

Ledger and editor categories use adaptive cells with a 68-point minimum scaled
with caption text size. Short records retain an inline note and amount; longer
records give the amount its own row and the note/tags the remaining full text
column. All tags and notes remain present. Converted amounts can move beneath
the date rather than squeezing it. No ledger actions, chart animations, category
choices, tag ordering or persistence functions have been removed.

Width stress fixtures contain large amounts, long notes and four tags. Native
Chinese/English cases use the actual production root without width overrides.
The width matrix uses isolated compact containers of 320, 360, 390, 430, 600, 669
and 760 points, plus English at 320 and 669. Its explicitly compact size class
tests phone-style content on iPad; it does not certify a physical device pose.
The initial mqtdio matrix stopped when native iPad navigation moved the year
control into overflow at 600 points. Its eleven general cases passed separately;
the corrected matrix fixture no longer treats that toolbar as its readiness
condition. Earlier width checks that asserted line height alone are not complete
acceptance: image inspection also found truncated English money at 320 points.
The final assertions require full-width large summary/metric amounts there and
check the donut center's dimensions, in addition to screenshots and bounds.

The new opt-in live width case accepts a closed outer display or an opened
landscape workspace, then checks opened landscape, inner portrait and restored
outer geometry in one foreground process:

```sh
QA_LIVE_TRANSITIONS=1 bash Tests/AdaptiveLayouts/run.sh DUO_SIMULATOR_UUID \
  -only-testing:ResizeTests/LiveTransitionTests/testActualResponsiveWidthContinuity
```

Its stages are WIDTH_OPEN (when starting closed), WIDTH_PORTRAIT and WIDTH_CLOSE.
The initial SimpleWorth-adaptive.mZRsAj/Results.xcresult verified the closed
466x678-point scene and 382x644-point content in process 83534, but timed out
waiting for actual WIDTH_OPEN. That failed attempt is not physical folding
acceptance for this width repair. Prior passing settings-fold evidence above
predates the new responsive layouts and is not substituted for a new live pass.

The live rerun in SimpleWorth-adaptive.D8qdVi/Results.xcresult started on the
actual fully opened landscape display. All four page checks completed in the
951x669-point scene with an 867x635-point root, then completed again after
rotation to the 669x951-point inner portrait scene with a 669x835-point root.
Both poses retained foreground process 1825 and the 180-degree hinge; compact
cards filled the portrait root minus 32 points. WIDTH_CLOSE then timed out after
900 seconds without observing a closed foreground pose. The whole case is
failed (one failure, zero skips/runtime warnings), not a complete fold pass.
Its log is /tmp/SimpleWorth-Responsive-LiveDuo-Rerun-20261014.log. Active-display
landscape and portrait statistics screenshots were inspected at
/tmp/SimpleWorth-Responsive-Live-Stats-Landscape-20261014.png and
/tmp/SimpleWorth-Responsive-Live-Stats-Portrait-20261014.png. Attachments are in
/tmp/SimpleWorth-Responsive-LiveDuo-Attachments-20261014. Return to the outer
display in the same running process remained unverified in this attempt.

An outer-only round-trip case avoids repeating the already checked portrait
rotation. Start with the Duo closed and operate Device Hub when the stages
WIDTH_ROUNDTRIP_OPEN and WIDTH_ROUNDTRIP_CLOSE appear:

```sh
QA_LIVE_TRANSITIONS=1 bash Tests/AdaptiveLayouts/run.sh DUO_SIMULATOR_UUID \
  -only-testing:ResizeTests/LiveTransitionTests/testActualResponsiveOuterRoundTrip
```

Its first run, SimpleWorth-adaptive.DgUOUI/Results.xcresult, completed all four
initial outer page checks in process 9582: scene 466x678, root 382x644, hinge
zero degrees, foreground and no width override. The active outer screenshot
/tmp/SimpleWorth-Responsive-RoundTrip-Initial-Outer-20261014.png was inspected.
The run then timed out waiting for WIDTH_ROUNDTRIP_OPEN and is failed, with one
failure and zero skips/runtime warnings. It does not certify an actual round
trip. Log: /tmp/SimpleWorth-Responsive-LiveDuo-OuterRoundTrip-20261014.log.
XCTest tears down the app after a timeout; the old qa-pose.json can remain marked
active after its recorded process exits, so that file alone is not proof of a
running app. Check process liveness before reusing telemetry outside a live test.

Device Hub desktop automation was requested. System Events reported UI access
enabled, but CGSessionCopyCurrentDictionary reported CGSSessionScreenIsLocked=1;
DeviceHub exposed no windows while locked. Unlock the Mac before attempting its
buttons. This diagnostic attempt did not demonstrate automated pose changes.

After unlocking, Device Hub exposed its actual pose-bar controls through System
Events. device_hub_pose.applescript targets the Duo window and the control's Help
label (Closed, Open, Partially Open or Rotate Right), without guessing screen
coordinates or changing simulated geometry. drive_device_hub.sh follows the live
test stages, verifies the original app process is still alive, and captures the
active outer/inner displays. Run it alongside the corresponding opt-in live case:

```sh
bash Tests/AdaptiveLayouts/drive_device_hub.sh LIVE_TEST_LOG DUO_SIMULATOR_UUID round-trip
bash Tests/AdaptiveLayouts/drive_device_hub.sh LIVE_TEST_LOG DUO_SIMULATOR_UUID width
```

The first automated attempt in SimpleWorth-adaptive.xGR9i0/Results.xcresult
failed the unchanged compact/wide assertion. Hinge status arrived before inner
viewport geometry, so the driver mistook the old outer viewport for an inner
portrait display and rotated an already-landscape display again. The driver now
waits for a stable inner viewport before choosing orientation; live predicates
also require two seconds of stable matching geometry. It checks process liveness
instead of trusting a stale pose file. Fixture telemetry now includes the actual
interface orientation, allowing the driver to restore the initial outer direction
after portrait testing, not just the same width/height with a reversed rail.

Automated round-trip acceptance passed in
SimpleWorth-adaptive.feaw6v/Results.xcresult: one pass, zero failures, skips and
runtime warnings. All four pages were checked at each of three actual poses in
foreground process 21247: closed landscape outer scene 678x466/root 594x432,
fully opened landscape scene 951x669/root 867x635, and restored closed outer
scene 678x466/root 594x432. This is real Device Hub folding, not a synthetic width
override. Active-display screenshots in SimpleWorth-duo-live-images.YPgWmX were
inspected. Test log:
/tmp/SimpleWorth-Responsive-LiveDuo-AutomatedRoundTrip-Stable-20261014.log.
Controller log: /tmp/SimpleWorth-Responsive-LiveDuo-Controls-Stable-20261014.log.

After the orientation-telemetry addition, both current-source Chinese/English
native stress cases passed in SimpleWorth-adaptive.WFvNvX/Results.xcresult with
zero failures, skips and runtime warnings. Setup of the larger sequence that
also visits inner portrait was initially blocked by the Mac locking again.
Keep the Mac unlocked while operating Device Hub; a
temporary caffeinate assertion during the test does not bypass the lock screen.

After the next unlock, the complete automatic width sequence passed in
SimpleWorth-adaptive.TpZDE4/Results.xcresult: one pass, zero failures, skips and
runtime warnings. All sixteen page checks completed in the same foreground
process 48610, using the production root without synthetic width overrides:

- Initial closed portrait outer: scene 466x678, root 382x644, hinge 0 degrees,
  interface orientation 1.
- Fully opened landscape inner: scene 951x669, root 867x635, hinge 180 degrees,
  interface orientation 3.
- Fully opened portrait inner: scene 669x951, root 669x835, hinge 180 degrees,
  interface orientation 1.
- Restored closed portrait outer: scene 466x678, root 382x644, hinge 0 degrees,
  interface orientation 1, matching the initial direction and width.

Device Hub buttons performed opening, rotation and closing automatically. The
driver observed the intermediate landscape outer after closing from inner
portrait, then rotated it back before the final four-page checks. This verifies
orientation restoration rather than accepting a different outer aspect ratio.
Test log: /tmp/SimpleWorth-Responsive-LiveDuo-AutomatedFullWidth-20261014.log.
Controller log: /tmp/SimpleWorth-Responsive-LiveDuo-FullWidth-Controls-20261014.log.
Active-display landscape, portrait and restored-outer screenshots in
SimpleWorth-duo-live-images.rq3KTF were inspected for clipping and overlap.
The larger physical fold/rotation sequence is now accepted; earlier timeout and
driver-race results remain recorded as failed attempts, not converted to passes.

Final automatic acceptance for the responsive implementation:

- Fourteen width-matrix, layout, resize, chart-selection, draft, keyboard,
  workspace and tag-reflow cases passed in
  SimpleWorth-adaptive.ME6IdI/Results.xcresult.
- Both native Chinese/English stress cases passed on the actual closed Duo in
  SimpleWorth-adaptive.OO25xI/Results.xcresult. Recorded scenes were 466x678 points
  with 382x644-point roots, zero-degree closed hinges and no width overrides.
  Each language case launches separately; this is not same-process continuity.
- Both native stress cases passed on iPhone SE in
  SimpleWorth-adaptive.hoYYCP/Results.xcresult. Four iPhone 17 Pro cases, including
  native input and compact settings return, passed in
  SimpleWorth-adaptive.rPzytV/Results.xcresult.

All four final results had zero failures, skips and runtime warnings. The
unchanged ledger/category/tag behavior additionally passed three gesture cases
(SimpleWorth-row-gestures.tyTkaj), nine category/tag cases
(SimpleWorth-categories-tags.yln9IT), and three phone scrolling/end-clearance
cases (SimpleWorth-adaptive.m1bzUJ), each with zero skips/runtime warnings.
The final 320-point English summary/statistics images were inspected to confirm
complete monetary strings, including the donut center. The active-display outer
screenshot /tmp/SimpleWorth-Responsive-Outer-Acceptance-20261014.png was also
inspected. The main project passed an unsigned Release simulator build in
/tmp/SimpleWorth-Responsive-Release-Acceptance-20261014.log. This does not imply
a signed archive, commit, push or TestFlight upload. Physical round-trip evidence
is recorded separately above.

## Six-item Duo repair acceptance (2026-10-14)

The latest repair also keeps the compact horizontal size class inside phone
navigation. This prevents an inner-portrait NavigationStack from reserving an
additional side-toolbar column after returning from a landscape workspace.
Embedded settings use 24-point content padding with an explicit available-width
constraint; root, currency and detail pages share the same hosting contract.

The isolated device `SimpleWorth Duo Layout QA`
(`6815A36B-A194-4E00-AA1B-D4CC947F56DC`, iOS 27.1) completed the real Device Hub
sequence in foreground process 31885 without a relaunch or width override:

| Pose | Scene size | Root size | Layout / compact card width |
| --- | --- | --- | --- |
| Closed outer portrait | 466 x 678 | 382 x 644 | Phone / 350 |
| Opened inner landscape | 951 x 669 | 867 x 635 | Two-pane workspace |
| Opened inner portrait | 669 x 951 | 669 x 835 | Phone / 637 |
| Closed outer landscape | 678 x 466 | 594 x 432 | Phone / 562 |
| Restored outer portrait | 466 x 678 | 382 x 644 | Phone / 350 |

All four pages passed at each pose (20 page checks). Phone poses had bottom tabs
and full usable card widths, no secondary pane or Compact/Wide controls, and no
extra per-goal deposit buttons. Inner landscape switched automatically and its
settings summary had at least 16 points of visible space on both sides. The
final outer direction matched the initial direction (interface orientation 1).
The live case, compact settings/currency return and two layout unit cases passed
with zero failures, skips or runtime warnings:
`/tmp/SimpleWorth-duo-six-fixes-isolated-verified.xcresult`.
Log: `/tmp/SimpleWorth-duo-six-fixes-isolated-verified.log`.

Three explicitly synthetic state tests passed with zero failures, skips or
runtime warnings in `/tmp/SimpleWorth-duo-six-fixes-state-regression.xcresult`:
all four periods survived resizing, donut selection survived resizing, and plain
goals/recent deposits remained usable across compact/wide changes. These tests
are state regression evidence; the real poses are established by the live run.

On iPhone SE, native Chinese long-money/row width checks and last-category entry
actions passed in `/tmp/SimpleWorth-duo-six-fixes-final-phone.xcresult`. That run
also contains one missed statistics-tab tap in the settings case, so the combined
run is recorded as failed. The unchanged settings case then passed alone with
zero failures, skips or runtime warnings in
`/tmp/SimpleWorth-duo-six-fixes-phone-settings-recheck.xcresult`. The recording of
the missed tap was inspected; it stayed on the expense page before opening any
settings route.

Before the final compact-navigation adjustment, native inner-landscape editor,
swipe/chart/goal interactions and ledger editor operations passed in
`/tmp/SimpleWorth-duo-six-fixes-native-wide.xcresult`; settings/currency margin
and return checks passed in `SimpleWorth-adaptive.0YySsx/Results.xcresult`. The
final live run above rechecked automatic landscape entry and settings margins.

Earlier shared-device pose attempts and the isolated run interrupted by desktop
screen-capture failure remain failed attempts. They are superseded by the
successful isolated real-pose run, not counted as successful acceptance.

The final production source passed an unsigned Release simulator build in
`/tmp/SimpleWorth-duo-six-fixes-final-release.log`, producing `简值` 0.8.4 (37)
with portrait and both landscape orientations enabled. This is local build and
simulator evidence; signed archive, Git publication and TestFlight release are
handled by the separate release chat after this repair handoff.

The production Release app and the native-default fixture were installed on the
original Duo simulator as well. The isolated Duo displays the production app's
landscape settings page. Its active-inner-display screenshot was inspected:
`/tmp/SimpleWorth-duo-six-fixes-production-settings.png`; the outer portrait
production screenshot is `/tmp/SimpleWorth-duo-six-fixes-production-outer.png`.

## Right rail, inline language and fixed headers (2026-10-15)

This follow-up replaces the outer-display bottom-tab policy recorded on October
14. A closed hinge enables the system right rail; each page independently keeps
compact navigation sizing, so the rail does not add another inset inside the
content. Inner portrait retains phone bottom tabs.

Language controls try the regular inline layout, then caption2 text with smaller
horizontal padding and gaps, before falling back for genuinely narrower/larger
text layouts. The actual Duo landscape settings pane keeps the label and all four
options on one row, while preserving its existing content margins.

The baseline scroll test reproduced disappearing title/date controls. Setting
toolbar visibility alone did not prevent minimization. The shared main-page
modifier now uses iOS 27's
[`toolbarMinimizationBehavior(.never, for: .navigationBar)`](https://developer.apple.com/documentation/swiftui/view/toolbarminimizationbehavior(_:for:))
and keeps the existing behavior on older systems. Up/down drags verify unchanged
title/year frames and hittability on all four pages.

Final successful results, all with zero failures, skips or runtime warnings:

| Device / pose | Checks | Result bundle |
| --- | --- | --- |
| Duo closed outer | Right-rail alignment/content separation, four fixed headers, native long-money widths | `/tmp/SimpleWorth-duo-followup-fixed-outer.xcresult` (3 passed) |
| Duo opened landscape | Four fixed headers, settings/currency margins, inline language options and return | `/tmp/SimpleWorth-duo-followup-wide.xcresult` (2 passed) |
| iPhone SE | Four fixed headers, native long-money widths, compact settings/currency return | `/tmp/SimpleWorth-duo-followup-phone.xcresult` (3 passed) |
| Duo real folding/rotation | Five poses / 20 page checks, outer right rail, inner portrait bottom tabs, inline language row | `/tmp/SimpleWorth-duo-followup-live.xcresult` (1 passed) |

The real sequence used unchanged foreground process 69322 on isolated device
`6815A36B-A194-4E00-AA1B-D4CC947F56DC`. It restored the initial outer portrait
direction (orientation 1), with compact card widths 350 / 637 / 562 / 350 points
in initial outer portrait / inner portrait / outer landscape / restored outer.

Baseline and intermediate failed attempts remain failed: the early native rail
assertion required disjoint accessibility rectangles, but native hit rectangles
overlap at their edges. The final check verifies aligned horizontal centers,
ordered vertical centers, and separation from the page content instead.

The three changed production files match the tested source copy; hashes are in
`/tmp/SimpleWorth-duo-followup-source-sha256.txt`. The unsigned Release simulator
build passed in `/tmp/SimpleWorth-duo-followup-release.log`. That app was installed
on the isolated Duo and its actual landscape settings screenshot was inspected:
`/tmp/SimpleWorth-duo-followup-settings-inline.png`. Scroll-after screenshots
`/tmp/SimpleWorth-duo-followup-vault-pinned.png` and
`/tmp/SimpleWorth-duo-followup-stats-pinned.png` show the QA data fixture with
fixed headers and right tabs. These are local changes marked unreleased in the
main README; no signed archive, commit, push or TestFlight upload was performed.
