#!/usr/bin/bash

# make sure we have pulled in and updated any submodules
git submodule init
git submodule update


# Stow the contents of the directory "dotfiles" to $HOME
stow -v -R -t ~ dotfiles
