#!/bin/sh

killall .waybar-wrapped

if [[ $USER = "kerby" ]]
then
	waybar -c ~/dotfiles/waybar/config.jsonc & -s ~/dotfiles/waybar/style.css
else
	waybar &
fi
