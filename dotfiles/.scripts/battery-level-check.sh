#!/usr/bin/env bash

SOUND_DIR="$HOME/.scripts"
ADAPTER="/sys/class/power_supply/ACAD"
FULL_THRESHOLD=96
LAST_LEVEL_FILE="/tmp/last_battery_level"
FULL_NOTIFIED_FILE="/tmp/full_battery_notification_id"
LOW_BATTERY_ID_FILE="/tmp/battery_notification_id"

BATTERY_STATUS=$(cat /sys/class/power_supply/BAT1/status)
BATTERY_CAPACITY=$(cat /sys/class/power_supply/BAT1/capacity)
LAST_LEVEL=$(cat "$LAST_LEVEL_FILE" 2>/dev/null || echo 100)

is_charging() {
    [[ "$BATTERY_STATUS" == "Charging" ]] || [[ $(cat "$ADAPTER/online" 2>/dev/null) == "1" ]]
}

# Handle full battery notification
if [[ "$BATTERY_CAPACITY" -gt "$FULL_THRESHOLD" ]] && [[ ! -f "$FULL_NOTIFIED_FILE" ]]; then
    notify-send "Battery Full" -u critical -i "battery-full" > /dev/null
    touch "$FULL_NOTIFIED_FILE"
    $SOUND_DIR/sounds.sh --battery-full
elif [[ "$BATTERY_CAPACITY" -le "$FULL_THRESHOLD" ]]; then
    rm -f "$FULL_NOTIFIED_FILE"
fi

# Handle low battery notifications (15%, 10%, 5%)
if ! is_charging; then
    for THRESHOLD in 15 10 5; do
        if [[ "$BATTERY_CAPACITY" -le "$THRESHOLD" ]] && [[ "$LAST_LEVEL" -gt "$THRESHOLD" ]]; then
            NOTIFICATION_ID=$(notify-send "Battery low" "Battery is at ${BATTERY_CAPACITY}%" -u critical -i "battery-caution" -h string:x-canonical-private-synchronous:anything --print-id)
            echo "$NOTIFICATION_ID" > "$LOW_BATTERY_ID_FILE"
            $SOUND_DIR/sounds.sh --battery-warning
            break
        fi
    done
else
    # Clear low battery notification ID when charging
    rm -f "$LOW_BATTERY_ID_FILE"
fi

# Save current battery level
echo "$BATTERY_CAPACITY" > "$LAST_LEVEL_FILE"
