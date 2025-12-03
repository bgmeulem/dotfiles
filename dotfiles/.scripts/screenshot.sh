#!/usr/bin/env bash

# Default values
selection=false
scale=0.5

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --selection|-s)
      selection=true
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

fn="$(xdg-user-dir PICTURES)/Screenshots/screenshot_$(date +'_%F-%H-%M-%S.png')"

if $selection; then
  region=$(slurp)
  [ -z "$region" ] && exit 0    # user cancelled slurp

  grim -g "$region" "$fn" && wl-copy < "$fn"

else
  grim -s "$scale" "$fn" && wl-copy < "$fn"
fi

~/.scripts/sounds.sh --screenshot &

user_action=$(notify-send -i "screengrab" \
  --action "default=open" \
  "Screenshot" "$fn")

wait user_action
if [[ "$user_action" == "default" ]]; then
  nemo "$fn" &
fi
