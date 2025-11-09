#!/bin/bash

sleep 1
clear
aur_helper=$(cat ~/.config/defaults/aur_helper.conf)

_isInstalled() {
    package="$1"
    check="$($aur_helper -Qs --color always "${package}" | grep "local" | grep "${package} ")"
    if [ -n "${check}" ]; then
        echo 0 
        return
    fi
    echo 1 
    return
}

$aur_helper

if [[ $(_isInstalled "flatpak") == "0" ]]; then
    flatpak upgrade
fi

notify-send "Update complete"
echo
echo ":: Update complete"
echo
echo

echo "Press [ENTER] to close."
read
