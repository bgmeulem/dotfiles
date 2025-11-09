fn=$(xdg-user-dir)/Pictures/$(date +'screenshot_%F-%T.png')
scale=0.5

grim -s "$scale" "$fn" && ~/.scripts/sounds.sh --screenshot

# Send clickable notification
user_action=$(notify-send -i "screengrab" --action "default=open" "Screenshot" "$fn");
wait user_action
if [[ "$user_action" == "default" ]]; then
  nemo $fn &
fi
