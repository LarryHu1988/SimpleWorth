# Categories and tag ordering regression

Run `bash Tests/CategoriesTags/run.sh SIMULATOR_UUID` with an installed Xcode.
The harness compiles production sources into an isolated QA app; it never accesses the release app's data.

Coverage: complete category selection without UI search, category model aliases, SF Symbols, translations, native reorder gestures, restart persistence, editor tag order, historical categories, duplicate tags, new-tag placement, and backup compatibility.
Five-column coverage checks the first and last rows in four languages, centered labels, complete historical-category rows, native wide editors, the review destination and the system share sheet. Prepare the real Duo posture in Device Hub before running the wide-editor test; it skips windows under 600 points and does not synthesize a device rotation. The QA app intercepts review links instead of launching the real App Store.
Temporary Xcode projects and xcresult screenshots are retained at the printed artifact path.

Settings coverage includes direct feedback mail and privacy URLs without navigation, unavailable-mail fallback, single-language About introductions matching each of the four app languages, bundle-derived version text, the product homepage, and the Other Apps links without a support section. The harness intercepts external URLs at the navigation host and never sends mail. Only the selected language's introduction is shown; tests assert that the other three are absent. Use `QA_DARK=1` for dark-mode fixtures. Native embedded settings geometry is covered by `NativeDeviceTests.testNativeWideSimplifiedSettings` in `Tests/AdaptiveLayouts`; prepare the real unfolded landscape pose before running it.

About layout checks cover a 64-point app icon beside the slogan, no language or basic-information headings, emoji-leading information rows, and a version value without the app name. Other Apps has no section heading in any locale. Light/dark icon assets are verified at runtime; `SimpleWorthIcon.imageset` contains byte-for-byte copies of the corresponding `AppIcon.appiconset` artwork and should be refreshed whenever the app icon changes.

For an upgrade check on a device without this QA app's data, first run `bash Tests/CategoriesTags/seed-legacy.sh SIMULATOR_UUID`, wait for the QA tags to appear, then run the regular test script on the same device. The migration fixture is pinned to a historical commit (override with a second argument), independently of release tags. Original tag IDs are retained in the isolated app's preferences; the UI test checks that upgrade and relaunch preserve them. Do not downgrade an already upgraded QA store to repeat this check.
