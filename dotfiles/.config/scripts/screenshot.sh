fn=$(xdg-user-dir)/Pictures/$(date +'screenshot_%F-%T.png')
scale=0.5

grim -s "$scale" "$fn";
notify-send -i "screengrab" "Screenshot" "$fn"
