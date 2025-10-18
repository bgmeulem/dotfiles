#!/bin/bash
killall waybar
pkill waybar
sleep 0.5

config_file="config.jsonc"
style_file="style.css"

waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css &
