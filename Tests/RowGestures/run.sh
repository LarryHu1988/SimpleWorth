#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
    printf 'Usage: bash Tests/RowGestures/run.sh SIMULATOR_UUID [xcodebuild options...]\n' >&2
    exit 2
fi
simulator_id="$1"
shift
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
test_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$test_dir/../.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/SimpleWorth-row-gestures.XXXXXX")"
cp "$test_dir/Fixture.swift" "$test_dir/GestureTests.swift" "$test_dir/project.yml" "$work_dir/"

# Exercise the production row and bridge, not a second implementation of their gestures.
awk '
    BEGIN { print "import SwiftUI\nimport UIKit" }
    /^struct SwipeableLedgerRow: View/ { emit = 1; foundRow = 1 }
    /^private struct HorizontalPanGestureBridge: UIViewRepresentable/ { foundBridge = 1 }
    /^struct EmptyStateCard: View/ { emit = 0; foundEnd = 1 }
    emit
    END { if (!foundRow || !foundBridge || !foundEnd) exit 1 }
' "$repo_dir/Sources/Views/DashboardComponents.swift" > "$work_dir/ProductionRows.swift"

printf 'Test artifacts: %s\n' "$work_dir"
cd "$work_dir"
xcodegen generate
xcodebuild -project RowGestureCheck.xcodeproj -scheme RowGestureCheck \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -parallel-testing-enabled NO -derivedDataPath "$work_dir/DerivedData" \
    -resultBundlePath "$work_dir/Results.xcresult" test "$@"
