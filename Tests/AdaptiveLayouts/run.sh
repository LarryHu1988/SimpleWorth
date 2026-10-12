#!/bin/bash
set -euo pipefail
simulator_id="${1:?Simulator UUID required}"
shift
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export TEST_RUNNER_QA_LIVE_TRANSITIONS="${QA_LIVE_TRANSITIONS:-0}"
test_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$test_dir/../.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/SimpleWorth-adaptive.XXXXXX")"
cp -R "$repo_dir/Sources" "$work_dir/Sources"
cp "$test_dir/"*.swift "$test_dir/project.yml" "$work_dir/"
awk '!/^@main$/ { sub(/^private struct AppRootView:/, "struct AppRootView:"); print }' "$repo_dir/Sources/App/SimpleWorthApp.swift" > "$work_dir/Sources/App/SimpleWorthApp.swift"
printf 'Test artifacts: %s\n' "$work_dir"
cd "$work_dir"
xcodegen generate
xcodebuild -project AdaptiveLayoutCheck.xcodeproj -scheme AdaptiveLayoutCheck \
    -destination "platform=iOS Simulator,id=$simulator_id" -parallel-testing-enabled NO \
    -derivedDataPath "$work_dir/DerivedData" -resultBundlePath "$work_dir/Results.xcresult" test "$@"
