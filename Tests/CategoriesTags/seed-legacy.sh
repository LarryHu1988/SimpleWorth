#!/bin/bash
set -euo pipefail
simulator_id="${1:?Simulator UUID required}"
legacy_ref="${2:-V0.7.20}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
test_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$test_dir/../.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/SimpleWorth-legacy-tags.XXXXXX")"
git -C "$repo_dir" archive "$legacy_ref" Sources | tar -x -C "$work_dir"
cp "$test_dir/"*.swift "$test_dir/project.yml" "$work_dir/"
awk '!/^@main$/' "$work_dir/Sources/App/SimpleWorthApp.swift" > "$work_dir/App.tmp"
mv "$work_dir/App.tmp" "$work_dir/Sources/App/SimpleWorthApp.swift"
printf 'Legacy test artifacts: %s\n' "$work_dir"
cd "$work_dir"
xcodegen generate
xcodebuild -project CategoriesTagsCheck.xcodeproj -scheme CategoriesTagsCheck \
    -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$work_dir/DerivedData" build
xcrun simctl boot "$simulator_id" 2>/dev/null || true
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl install "$simulator_id" "$work_dir/DerivedData/Build/Products/Debug-iphonesimulator/CategoriesTagsCheck.app"
xcrun simctl launch "$simulator_id" com.simpleworth.qa.categoriestags
