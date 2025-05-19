#!/usr/bin/bash

# make sure we have pulled in and updated any submodules
git submodule init
git submodule update


# Stow the contents of the directory "dotfiles" to $HOME
stow -v -R -t ~ dotfiles

# Install wikiman sources: Arch and tldr
if [[ ! -d /usr/share/doc/arch-wiki ]] || [[ ! -d /usr/share/doc/tldr-pages ]]; then
	mkdir wikiman
	# Download wikiman makefile
	curl -L 'https://raw.githubusercontent.com/filiparag/wikiman/master/Makefile' -o 'wikiman/wikiman-makefile'
	make -f ./wikiman/wikiman-makefile source-arch source-tldr
	sudo make -f ./wikiman/wikiman-makefile source-install
	sudo make -f ./wikiman/wikiman-makefile clean
	rm -rf wikiman
fi


