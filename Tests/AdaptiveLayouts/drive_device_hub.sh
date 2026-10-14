#!/bin/bash
set -euo pipefail

log_path="${1:?Live test log required}"
simulator_id="${2:?Duo simulator UUID required}"
mode="${3:-round-trip}"
case "$mode" in round-trip|width) ;; *) printf 'Use round-trip or width.\n' >&2; exit 2 ;; esac
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
test_dir="$(cd "$(dirname "$0")" && pwd)"
image_dir="$(mktemp -d "${TMPDIR:-/tmp}/SimpleWorth-duo-live-images.XXXXXX")"
printf 'Active-display screenshots: %s\n' "$image_dir"

wait_for_stage() {
    local deadline=$((SECONDS + 180))
    while (( SECONDS < deadline )); do
        if rg -q "^QA_LIVE_STAGE: $1$" "$log_path"; then return; fi
        if rg -q '\*\* TEST FAILED \*\*|Test Case .* failed' "$log_path"; then
            printf 'Live test failed before %s.\n' "$1" >&2
            return 1
        fi
        sleep 0.5
    done
    printf 'Timed out waiting for %s.\n' "$1" >&2
    return 1
}

wait_for_pose() {
    local deadline=$((SECONDS + 25))
    local previous_geometry="" matching_since=-1 geometry
    while (( SECONDS < deadline )); do
        if ! kill -0 "$app_pid" 2>/dev/null; then
            printf 'The original test app process has exited.\n' >&2
            return 1
        fi
        if jq -e --argjson pid "$app_pid" ".processID == \$pid and .sceneIsActive == true and ($1)" "$pose_path" >/dev/null; then
            geometry="$(jq -c '[.status,.angle,.interfaceOrientation,.sceneWidth,.sceneHeight,.width,.height,.divisions]' "$pose_path")"
            if [[ "$geometry" != "$previous_geometry" || "$matching_since" == -1 ]]; then
                previous_geometry="$geometry"
                matching_since=$SECONDS
            elif (( SECONDS - matching_since >= 2 )); then
                jq -c '{processID,status,angle,interfaceOrientation,sceneWidth,sceneHeight,width,height}' "$pose_path"
                return
            fi
        else
            matching_since=-1
        fi
        sleep 0.25
    done
    printf 'The expected live pose was not observed in the original process.\n' >&2
    return 1
}

pose_control() { osascript "$test_dir/device_hub_pose.applescript" "$1"; }
screenshot() { xcrun simctl io "$simulator_id" screenshot --display="$2" "$image_dir/$1.png"; }

open_landscape() {
    pose_control open
    wait_for_pose '.status == "fullyOpen" and .angle >= 179 and (.sceneWidth >= 760 or .sceneHeight >= 760)'
    if jq -e '.height > .width' "$pose_path" >/dev/null; then pose_control rotate-right; fi
    wait_for_pose '.status == "fullyOpen" and .width > .height and .sceneWidth >= 760'
}

close_outer() {
    pose_control closed
    local outer_geometry="((.sceneWidth == $outer_scene_width and .sceneHeight == $outer_scene_height) or (.sceneWidth == $outer_scene_height and .sceneHeight == $outer_scene_width))"
    wait_for_pose ".status == \"closed\" and .angle <= 1 and $outer_geometry"
    local turn previous_orientation
    for turn in 1 2 3; do
        if jq -e ".interfaceOrientation == $outer_orientation" "$pose_path" >/dev/null; then break; fi
        previous_orientation="$(jq -er '.interfaceOrientation' "$pose_path")"
        pose_control rotate-right
        wait_for_pose ".status == \"closed\" and .interfaceOrientation != $previous_orientation and $outer_geometry"
    done
    wait_for_pose ".status == \"closed\" and .angle <= 1 and .sceneWidth == $outer_scene_width and .sceneHeight == $outer_scene_height and .interfaceOrientation == $outer_orientation"
    screenshot restored-outer primary
}

if [[ "$mode" == round-trip ]]; then initial_stage=WIDTH_ROUNDTRIP_OPEN; else initial_stage=WIDTH_OPEN; fi
wait_for_stage "$initial_stage"
container="$(xcrun simctl get_app_container "$simulator_id" com.simpleworth.qa.adaptivelayouts data)"
pose_path="$container/Documents/qa-pose.json"
app_pid="$(jq -er '.processID' "$pose_path")"
outer_scene_width="$(jq -er '.sceneWidth' "$pose_path")"
outer_scene_height="$(jq -er '.sceneHeight' "$pose_path")"
outer_orientation="$(jq -er '.interfaceOrientation | select(. > 0)' "$pose_path")"
wait_for_pose '.status == "closed" and .angle <= 1'
screenshot initial-outer primary
open_landscape

if [[ "$mode" == width ]]; then
    wait_for_stage WIDTH_PORTRAIT
    screenshot opened-landscape primary-1
    pose_control rotate-right
    wait_for_pose '.status == "fullyOpen" and .height > .width and .sceneWidth < 760'
    wait_for_stage WIDTH_CLOSE
    screenshot opened-portrait primary-1
    close_outer
    wait_for_stage WIDTH_COMPLETE
else
    wait_for_stage WIDTH_ROUNDTRIP_CLOSE
    screenshot opened-landscape primary-1
    close_outer
    wait_for_stage WIDTH_ROUNDTRIP_COMPLETE
fi
printf 'All Device Hub controls completed; inspect the final xcresult separately.\n'
