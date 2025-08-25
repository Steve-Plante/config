#!/bin/bash
which dpkg
status=$?
if [ $status == 0 ]; then
    dpkg --list > dpkg.inventory.txt
fi
which pacman
status=$?
if [ $status == 0 ]; then
    sudo pacman -Q > pacman.inventory.txt
fi
flatpak list > flatpak.inventory.txt
snap list > snap.inventory.txt
