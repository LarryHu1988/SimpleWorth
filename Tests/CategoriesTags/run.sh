#!/bin/bash
set -euo pipefail
simulator_id="${1:?Simulator UUID required}"
shift
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
test_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$test_dir/../.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/SimpleWorth-categories-tags.XXXXXX")"
cp -R "$repo_dir/Sources" "$work_dir/Sources"
cp "$test_dir/"*.swift "$test_dir/project.yml" "$work_dir/"
awk '!/^@main$/' "$repo_dir/Sources/App/SimpleWorthApp.swift" > "$work_dir/Sources/App/SimpleWorthApp.swift"
printf 'Test artifacts: %s\n' "$work_dir"
cd "$work_dir"
xcodegen generate
xcodebuild -project CategoriesTagsCheck.xcodeproj -scheme CategoriesTagsCheck \
    -destination "platform=iOS Simulator,id=$simulator_id" -parallel-testing-enabled NO \
    -derivedDataPath "$work_dir/DerivedData" -resultBundlePath "$work_dir/Results.xcresult" test "$@"
