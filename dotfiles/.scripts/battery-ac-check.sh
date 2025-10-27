#!/usr/bin/env bash

SOUND_DIR="$HOME/.scripts"
ADAPTER="/sys/class/power_supply/ACAD"
NOTIFICATION_ID_FILE="/tmp/battery_notification_id"
POWER_STATE_FILE="/tmp/battery_power_state"
BATTERY_CAPACITY=$(cat /sys/class/power_supply/BAT1/capacity)

is_power_connected() {
    if [ -f "$ADAPTER/online" ] && [ "$(cat $ADAPTER/online)" = "1" ]; then
        return 0  # Power connected
    fi
    return 1  # No power connected
}

if is_power_connected; then
    current_power_state="connected"
else
    current_power_state="disconnected"
fi

# Read previous power state if file exists
if [ -f "$POWER_STATE_FILE" ]; then
    previous_power_state=$(cat "$POWER_STATE_FILE")
fi

# Update power state file
echo "$current_power_state" > "$POWER_STATE_FILE"

# Handle power state changes
if [ "$previous_power_state" != "$current_power_state" ]; then
    let "ROUNDED_BC = $BATTERY_CAPACITY / 10 * 10"
    case "$current_power_state" in
        "connected")
            # Power just connected
            if [ -f "$NOTIFICATION_ID_FILE" ]; then
                # Replace low battery notification
                NOTIFICATION_ID=$(cat "$NOTIFICATION_ID_FILE");
                notify-send --replace-id="$NOTIFICATION_ID" "Power Connected" "Battery charging (${BATTERY_CAPACITY}%)" -i "battery-0${ROUNDED_BC}-charging" -t 3000;
                rm -f "$NOTIFICATION_ID_FILE"
            else
                # Show general power connected notification
                notify-send "Power Connected" "Battery charging (${BATTERY_CAPACITY}%)" -i "battery-0${ROUNDED_BC}-charging" -t 3000
            fi
            ;;
        "disconnected")
            # Power just disconnected
            notify-send "Power Disconnected" "Running on battery (${BATTERY_CAPACITY}%)" -i "battery-0${ROUNDED_BC}" -t 3000
            ;;
    esac
    $SOUND_DIR/sounds.sh --battery-warning
fi
