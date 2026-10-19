on run arguments
    if (count arguments) < 1 or (count arguments) > 2 then error "Use closed, open, partially-open or rotate-right, with an optional window name prefix."
    set windowPrefix to "iPhone Duo"
    if (count arguments) is 2 then set windowPrefix to item 2 of arguments
    set requestedPose to item 1 of arguments
    if requestedPose is "closed" then
        set controlHelp to "Closed"
    else if requestedPose is "open" then
        set controlHelp to "Open"
    else if requestedPose is "partially-open" then
        set controlHelp to "Partially Open"
    else if requestedPose is "rotate-right" then
        set controlHelp to "Rotate Right"
    else
        error "Unsupported Device Hub control."
    end if

    tell application "DeviceHub" to activate
    delay 0.2
    tell application "System Events"
        tell process "DeviceHub"
            if (count windows) is 0 then error "Unlock the Mac and open the Duo window in Device Hub."
            set targetWindow to first window whose name starts with windowPrefix
            -- Restrict clicks to the device pose bar, not simulated app controls.
            set poseBar to group 3 of splitter group 1 of group 1 of splitter group 1 of group 1 of targetWindow
            repeat with poseButton in buttons of poseBar
                if help of poseButton is controlHelp then
                    if not enabled of poseButton then error "The requested pose control is disabled."
                    click poseButton
                    return "Clicked Device Hub control: " & controlHelp
                end if
            end repeat
        end tell
    end tell
    error "The requested pose control was not found; inspect the current Device Hub UI."
end run
