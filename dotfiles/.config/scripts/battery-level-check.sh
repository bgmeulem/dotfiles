#!/usr/bin/env bash

SOUND_DIR="$HOME/.config/hypr/scripts"
ADAPTER="/sys/class/power_supply/ACAD"
LOW_THRESHOLD=15
FULL_THRESHOLD=96
BATTERY_ID_FILE="/tmp/battery_notification_id"
FULL_BATTERY_ID_FILE="/tmp/full_battery_notification_id"
BATTERY_STATUS=$(cat /sys/class/power_supply/BAT1/status)
BATTERY_CAPACITY=$(cat /sys/class/power_supply/BAT1/capacity)

is_power_connected() {
    if [ -f "$ADAPTER/online" ] && [ "$(cat $ADAPTER/online)" = "1" ]; then
        return 0  # Power connected
    fi
    return 1  # No power connected
}

handle_full_charge () {
    # Check if battery is fully charged
    if [ "$BATTERY_STATUS" == "Full" ] || [ "$BATTERY_CAPACITY" -gt "$FULL_THRESHOLD" ]; then
        # Only show full battery notification once (avoid spam)
        if [ ! -f "$FULL_BATTERY_ID_FILE" ]; then
            # Display a notification for full battery
            NOTIFICATION_ID=$(notify-send "Battery Full" -u critical -i "battery-full" --print-id)
            echo "$NOTIFICATION_ID" > "$FULL_BATTERY_ID_FILE"
            $SOUND_DIR/sounds.sh --battery-full
        fi
    else
        # Remove full battery notification file if battery is no longer full
        rm -f "$FULL_BATTERY_ID_FILE"
    fi
}

handle_low_battery() {
    # Handle low battery notifications
    if [[ "$BATTERY_CAPACITY" -le "$LOW_THRESHOLD" ]] && [[ "$BATTERY_STATUS" != "Charging" ]]; then
        # Only show low battery notification if power is NOT connected
        if ! is_power_connected; then
            # Display a low battery notification and store its ID
            NOTIFICATION_ID=$(notify-send "Battery low" "Battery is at ${BATTERY_CAPACITY}%" -u critical -i "battery-caution" -h string:x-canonical-private-synchronous:anything --print-id)
            echo "$NOTIFICATION_ID" > "$BATTERY_ID_FILE"
            $SOUND_DIR/sounds.sh --battery-warning
        fi
    else
        # If battery is above threshold or charging, just remove notification ID file
        rm -f "$BATTERY_ID_FILE"
    fi
}

handle_full_charge
handle_low_battery
