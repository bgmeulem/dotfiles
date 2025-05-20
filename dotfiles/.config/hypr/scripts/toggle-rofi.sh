#!/bin/bash

# Check if rofi is running
if pgrep -x rofi > /dev/null; then
  killall rofi
else
  rofi -show drun -monitor -1
fi
