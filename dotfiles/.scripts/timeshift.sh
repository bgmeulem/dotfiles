# Send clickable notification
user_action=$(notify-send -i "mintbackup" --action "default=open" "Timeshift" "Click to create a backup");
wait user_action
if [[ "$user_action" == "default" ]]; then
  $(cat ~/.config/defaults/terminal.conf) -e sudo timeshift --create;
fi
