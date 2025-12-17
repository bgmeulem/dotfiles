#!/usr/bin/env bash

# Send clickable notification
user_action=$(notify-send -i "mintbackup" -u critical --action "default=open" "Timeshift" "Click to create a backup" --wait);
if [[ "$user_action" == "default" ]]; then
  $(cat ~/.config/defaults/terminal.conf) -e sudo timeshift --create;
fi
