#!/bin/bash

sleep 1
clear

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

aur_helper="$(cat ~/.config/ml4w/settings/aur.sh)"

if [[ $(_isInstalled "timeshift") == "0" ]]; then
    echo
    if gum confirm "DO YOU WANT TO CREATE A SNAPSHOT?"; then
        echo
        c=$(gum input --placeholder "Enter a comment for the snapshot...")
        sudo timeshift --create --comments "$c"
        sudo timeshift --list
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        echo ":: DONE. Snapshot $c created!"
        echo
    elif [ $? -eq 130 ]; then
        echo ":: Snapshot skipped."
        exit 130
    else
        echo ":: Snapshot skipped."
    fi
    echo
fi

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
