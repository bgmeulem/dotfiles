#!/bin/bash
#  _   _           _       _             
# | | | |_ __   __| | __ _| |_ ___  ___  
# | | | | '_ \ / _` |/ _` | __/ _ \/ __| 
# | |_| | |_) | (_| | (_| | ||  __/\__ \ 
#  \___/| .__/ \__,_|\__,_|\__\___||___/ 
#       |_|                              
#  

script_name=$(basename "$0")

# Count the instances
instance_count=$(ps aux | grep -F "$script_name" | grep -v grep | grep -v $$ | wc -l)

if [ $instance_count -gt 1 ]; then
    sleep $instance_count
fi


install_platform="arch"
aur_helper="yay"

# check_lock_files
local pacman_lock="/var/lib/pacman/db.lck"
local checkup_lock="${TMPDIR:-/tmp}/checkup-db-${UID}/db.lck"

while [ -f "$pacman_lock" ] || [ -f "$checkup_lock" ]; do
    sleep 1
done

updates=$(checkupdates-with-aur | wc -l)

# ----------------------------------------------------- 
# Output in JSON format for Waybar Module custom-updates
# ----------------------------------------------------- 

if [ "$updates" != 0 ]; then
    printf '{"text": "%s", "alt": "%s", "tooltip": "Click to update", "class": "update-class"}' "$updates" "$updates"
else
    printf '{"tooltip": "No updates available", "class": "update-class"}'
fi
