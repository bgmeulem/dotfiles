#!/usr/bin/env bash

sDIR="$HOME/.config/hypr/scripts"

# Battery thresholds for notifications (change as needed)
LOW_THRESHOLD=20
FULL_THRESHOLD=97

# Get current battery percentage using /sys/class/power_supply

BATTERY_STATUS=$(cat /sys/class/power_supply/BAT1/status)
BATTERY_CAPACITY=$(cat /sys/class/power_supply/BAT1/capacity)

# Check if battery is fully charged
if [ "$BATTERY_STATUS" == "Full" ] || [ "$BATTERY_CAPACITY" -eq 100 ]; then
    # Display a notification for full battery
    notify-send "Battery Full" -u critical -i "battery-full" && $sDIR/sounds.sh --battery-full
fi

# Check if battery percentage is below the low threshold when not charging
if [[ "$BATTERY_CAPACITY" -le "$LOW_THRESHOLD" ]] && [[ "$BATTERY_STATUS" != "Charging" ]]; then
    # Display a low battery notification
    notify-send "Battery low" "Battery is at ${BATTERY_CAPACITY}%" -u critical -i "battery-caution" -h string:x-canonical-private-synchronous:anything && $sDIR/sounds.sh --battery-warning
fi
