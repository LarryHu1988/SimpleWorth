#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
    printf 'Usage: bash Tests/FixedHeaders/run.sh SIMULATOR_UUID [xcodebuild options...]\n' >&2
    exit 2
fi
simulator_id="$1"
shift
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
test_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$test_dir/../.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/SimpleWorth-fixed-headers.XXXXXX")"
cp -R "$repo_dir/Sources" "$work_dir/Sources"
cp "$test_dir/Fixture.swift" "$test_dir/HeaderTests.swift" "$test_dir/project.yml" "$work_dir/"

# Keep all production views and controllers, replacing only the test app's entry point.
awk '!/^@main$/' "$repo_dir/Sources/App/SimpleWorthApp.swift" > "$work_dir/Sources/App/SimpleWorthApp.swift"
printf 'Test artifacts: %s\n' "$work_dir"
cd "$work_dir"
xcodegen generate
xcodebuild -project FixedHeaderCheck.xcodeproj -scheme FixedHeaderCheck \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -parallel-testing-enabled NO -derivedDataPath "$work_dir/DerivedData" \
    -resultBundlePath "$work_dir/Results.xcresult" test "$@"
