#!/usr/bin/env bash
source "$HOME/.config/sketchybar/plugins/colors.sh"
source "$HOME/.config/sketchybar/plugins/icons.sh"

# Fonts used by the stats items below (match the bar's --default font).
export FONT="CaskaydiaCove Nerd Font"
export NERD_FONT="CaskaydiaCove Nerd Font"

cpu_percent=(
	label.font="$FONT:Bold:12.0"
	label=CPU%
	label.color="$TEXT"
	icon="$CPU"
	icon.color="$BLUE"
	update_freq=2
	script="$PLUGIN_DIR/cpu.sh"
)

sketchybar 	--add item cpu.percent right 					\
						--set cpu.percent "${cpu_percent[@]}"


memory=(label.font="$FONT:Bold:12.0"
	label.color="$TEXT"
	icon="$MEMORY"
	icon.font="$FONT:Bold:16.0"
	icon.color="$GREEN"
	update_freq=15
	script="$PLUGIN_DIR/ram.sh"
)

sketchybar 	--add item memory right 		\
						--set memory "${memory[@]}"

disk=(
	label.font="$FONT:Bold:12.0"
	label.color="$TEXT"
	icon="$DISK"
	icon.color="$MAROON"
	update_freq=60
	script="$PLUGIN_DIR/disk.sh"
)

sketchybar --add item disk right 		\
					 --set disk "${disk[@]}"

network_down=(
	y_offset=-7
	label.font="$FONT:Bold:10.0"
	label.color="$TEXT"
	icon="$NETWORK_DOWN"
	icon.font="$NERD_FONT:Bold:16.0"
	icon.color="$GREEN"
	icon.highlight_color="$BLUE"
	update_freq=1
)

network_up=(
	background.padding_right=-70
	y_offset=7
	label.font="$FONT:Bold:10.0"
	label.color="$TEXT"
	icon="$NETWORK_UP"
	icon.font="$NERD_FONT:Bold:16.0"
	icon.color="$GREEN"
	icon.highlight_color="$BLUE"
	update_freq=1
	script="$PLUGIN_DIR/network.sh"
)

sketchybar 	--add item network.down right 						\
						--set network.down "${network_down[@]}" 	\
						--add item network.up right 							\
						--set network.up "${network_up[@]}"


separator_right=(
	icon=
	icon.font="$NERD_FONT:Regular:16.0"
	background.padding_left=10
	background.padding_right=15
	label.drawing=off
	click_script='sketchybar --trigger toggle_stats'
	icon.color="$TEXT"
)

sketchybar  --add item separator_right right \
	          --set separator_right "${separator_right[@]}"