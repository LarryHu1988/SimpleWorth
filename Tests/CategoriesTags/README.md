# Categories and tag ordering regression

Run `bash Tests/CategoriesTags/run.sh SIMULATOR_UUID` with an installed Xcode.
The harness compiles production sources into an isolated QA app; it never accesses the release app's data.

Coverage: complete category selection without UI search, category model aliases, SF Symbols, translations, native reorder gestures, restart persistence, editor tag order, historical categories, duplicate tags, new-tag placement, and backup compatibility.
Temporary Xcode projects and xcresult screenshots are retained at the printed artifact path.

For an upgrade check on a device without this QA app's data, first run `bash Tests/CategoriesTags/seed-legacy.sh SIMULATOR_UUID`, wait for the QA tags to appear, then run the regular test script on the same device. The old model comes from V0.7.20 (override with a second argument). Original tag IDs are retained in the isolated app's preferences; the UI test checks that upgrade and relaunch preserve them. Do not downgrade an already upgraded QA store to repeat this check.
