#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
    printf 'Usage: bash Tests/ChartEntrance/run.sh SIMULATOR_UUID [xcodebuild options...]\n' >&2
    exit 2
fi
simulator_id="$1"
shift
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
test_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$test_dir/../.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/SimpleWorth-chart-entrance.XXXXXX")"
cp "$test_dir/Fixture.swift" "$test_dir/EntranceTests.swift" "$test_dir/project.yml" "$work_dir/"

# Use the exact production animation and ring instead of reimplementing them.
awk '
    BEGIN { print "import SwiftUI" }
    /^private struct SWChartPageActiveKey:/ { emit = 1; found = 1 }
    /^extension Color/ { emit = 0; foundEnd = 1 }
    emit
    END { if (!found || !foundEnd) exit 1 }
' "$repo_dir/Sources/Theme/Theme.swift" > "$work_dir/ProductionEntrance.swift"
awk '
    BEGIN { print "import SwiftUI" }
    /^struct ProgressRing:/ { emit = 1; found = 1 }
    /^struct FlowSummaryCard:/ { emit = 0; foundEnd = 1 }
    emit
    END { if (!found || !foundEnd) exit 1 }
' "$repo_dir/Sources/Views/DashboardComponents.swift" > "$work_dir/ProductionRing.swift"

printf 'Test artifacts: %s\n' "$work_dir"
cd "$work_dir"
xcodegen generate
xcodebuild -project ChartEntranceCheck.xcodeproj -scheme ChartEntranceCheck \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -parallel-testing-enabled NO -derivedDataPath "$work_dir/DerivedData" \
    -resultBundlePath "$work_dir/Results.xcresult" test "$@"
