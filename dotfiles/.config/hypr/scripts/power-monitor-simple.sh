#!/bin/bash

POWER_STATE_FILE="/tmp/battery_power_state"
ADAPTER="/sys/class/power_supply/ACAD"

# Verify the adapter exists
if [ ! -f "$ADAPTER/online" ]; then
    echo "Error: $ADAPTER/online not found"
    exit 1
fi

echo "Monitoring power adapter: $ADAPTER"

while true; do
    # Check if power is connected
    POWER_STATUS=$(cat "$ADAPTER/online")
    
    # Read previous state
    PREVIOUS_STATE=$(cat "$POWER_STATE_FILE" 2>/dev/null || echo "")
    
    # Determine current state
    if [ "$POWER_STATUS" = "1" ]; then
        CURRENT_STATE="connected"
    else
        CURRENT_STATE="disconnected"
    fi
    
    # Show notification on state change
    if [ "$PREVIOUS_STATE" != "$CURRENT_STATE" ] && [ -n "$PREVIOUS_STATE" ]; then
        echo "$CURRENT_STATE" > "$POWER_STATE_FILE"
        BATTERY_CAPACITY=$(cat /sys/class/power_supply/BAT1/capacity)
        
        case "$CURRENT_STATE" in
            "connected")
                notify-send "Power Connected" "Battery charging (${BATTERY_CAPACITY}%)" -i "battery-charging" -t 3000
                ;;
            "disconnected")
                notify-send "Power Disconnected" "Running on battery (${BATTERY_CAPACITY}%)" -i "battery" -t 3000
                ;;
        esac
    elif [ -z "$PREVIOUS_STATE" ]; then
        # First run - just set the state without notification
        echo "$CURRENT_STATE" > "$POWER_STATE_FILE"
    fi
    
    sleep 3  # Check every 3 seconds
done
