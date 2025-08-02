#!/usr/bin/env bash

sDIR="$HOME/.config/hypr/scripts"

ADAPTER="/sys/class/power_supply/ACAD"

# Battery thresholds for notifications (change as needed)
LOW_THRESHOLD=20
FULL_THRESHOLD=97

# Notification ID files for persistent notification management
LOW_BATTERY_ID_FILE="/tmp/battery_low_notification_id"
FULL_BATTERY_ID_FILE="/tmp/battery_full_notification_id"
POWER_STATE_FILE="/tmp/battery_power_state"

# Get current battery percentage and status using /sys/class/power_supply
BATTERY_STATUS=$(cat /sys/class/power_supply/BAT1/status)
BATTERY_CAPACITY=$(cat /sys/class/power_supply/BAT1/capacity)

# Function to check if AC power is connected
is_power_connected() {
    if [ -f "$ADAPTER/online" ] && [ "$(cat $ADAPTER/online)" = "1" ]; then
        return 0  # Power connected
    fi
    return 1  # No power connected
}

# Function to check and handle power state changes
handle_power_state_change() {
    local current_power_state
    local previous_power_state=""
    
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
        case "$current_power_state" in
            "connected")
                # Power just connected
                if [ -f "$LOW_BATTERY_ID_FILE" ]; then
                    # Replace low battery notification
                    NOTIFICATION_ID=$(cat "$LOW_BATTERY_ID_FILE")
                    notify-send --replace-id="$NOTIFICATION_ID" "Power Connected" "Battery charging (${BATTERY_CAPACITY}%)" -i "battery-charging" -t 3000
                    rm -f "$LOW_BATTERY_ID_FILE"
                else
                    # Show general power connected notification
                    notify-send "Power Connected" "Battery charging (${BATTERY_CAPACITY}%)" -i "battery-charging" -t 3000
                fi
                ;;
            "disconnected")
                # Power just disconnected
                notify-send "Power Disconnected" "Running on battery (${BATTERY_CAPACITY}%)" -i "battery" -t 3000
                ;;
        esac
    fi
}

# Function to dismiss low battery notifications when power is connected (legacy function for compatibility)
dismiss_low_battery_notification() {
    if [ -f "$LOW_BATTERY_ID_FILE" ]; then
        NOTIFICATION_ID=$(cat "$LOW_BATTERY_ID_FILE")
        # Replace the low battery notification with a charging notification
        notify-send --replace-id="$NOTIFICATION_ID" "Power Connected" "Battery charging (${BATTERY_CAPACITY}%)" -i "battery-charging" -t 3000
        rm -f "$LOW_BATTERY_ID_FILE"
    fi
}

# Check for power state changes and handle notifications
handle_power_state_change

# Check if battery is fully charged
if [ "$BATTERY_STATUS" == "Full" ] || [ "$BATTERY_CAPACITY" -eq 100 ]; then
    # Only show full battery notification once (avoid spam)
    if [ ! -f "$FULL_BATTERY_ID_FILE" ]; then
        # Display a notification for full battery
        NOTIFICATION_ID=$(notify-send "Battery Full" -u critical -i "battery-full" --print-id)
        echo "$NOTIFICATION_ID" > "$FULL_BATTERY_ID_FILE"
        $sDIR/sounds.sh --battery-full
    fi
else
    # Remove full battery notification file if battery is no longer full
    rm -f "$FULL_BATTERY_ID_FILE"
fi

# Handle low battery notifications
if [[ "$BATTERY_CAPACITY" -le "$LOW_THRESHOLD" ]] && [[ "$BATTERY_STATUS" != "Charging" ]]; then
    # Only show low battery notification if power is NOT connected
    if ! is_power_connected; then
        # Display a low battery notification and store its ID
        NOTIFICATION_ID=$(notify-send "Battery low" "Battery is at ${BATTERY_CAPACITY}%" -u critical -i "battery-caution" -h string:x-canonical-private-synchronous:anything --print-id)
        echo "$NOTIFICATION_ID" > "$LOW_BATTERY_ID_FILE"
        $sDIR/sounds.sh --battery-warning
    fi
else
    # If battery is above threshold or charging, just remove notification ID file
    rm -f "$LOW_BATTERY_ID_FILE"
fi
