#!/bin/sh

media_cover=(
  script="$PLUGIN_DIR/media.sh"
  click_script="$PLUGIN_DIR/media.sh toggle"
  icon=􀑪
  icon.font="CaskaydiaCove Nerd Font:16.0"
  icon.color=0xffcba6f7
  icon.padding_left=10
  icon.padding_right=4
  label.padding_left=6
  label.padding_right=10
  label.color=0xffcdd6f4
  label.font="CaskaydiaCove Nerd Font:Bold:14.0"
  label.max_chars=50
  drawing=off
  update_freq=3
  background.color=0xcc1e1e2e
  background.border_color=0x44cba6f7
  background.border_width=1
  background.corner_radius=8
  background.height=30
)

sketchybar --add item media.cover right \
           --set media.cover "${media_cover[@]}" \
           --subscribe media.cover media_change


#### test

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
	icon.font="$NERD_FONT:Bold:16.0"
	icon.color="$BLUE"
	update_freq=2
	drawing=off
	script="$PLUGIN_DIR/cpu.sh"
)

sketchybar 	--add item cpu.percent right 					\
						--set cpu.percent "${cpu_percent[@]}"


memory=(label.font="$FONT:Bold:12.0"
	label.color="$TEXT"
	icon="$MEMORY"
	icon.font="$NERD_FONT:Bold:16.0"
	icon.color="$GREEN"
	update_freq=15
	drawing=off
	script="$PLUGIN_DIR/ram.sh"
)

sketchybar 	--add item memory right 		\
						--set memory "${memory[@]}"

disk=(
	label.font="$FONT:Bold:12.0"
	label.color="$TEXT"
	icon="$DISK"
	icon.font="$NERD_FONT:Bold:16.0"
	icon.color="$MAROON"
	update_freq=60
	drawing=off
	script="$PLUGIN_DIR/disk.sh"
)

sketchybar --add item disk right 		\
					 --set disk "${disk[@]}"

network_down=(
	label.font="$FONT:Bold:12.0"
	label.color="$TEXT"
	icon="$NETWORK_DOWN"
	icon.font="$NERD_FONT:Bold:16.0"
	icon.color="$GREEN"
	icon.highlight_color="$BLUE"
	update_freq=1
	drawing=off
)

network_up=(
	label.font="$FONT:Bold:12.0"
	label.color="$TEXT"
	icon="$NETWORK_UP"
	icon.font="$NERD_FONT:Bold:16.0"
	icon.color="$GREEN"
	icon.highlight_color="$BLUE"
	update_freq=1
	drawing=off
	script="$PLUGIN_DIR/network.sh"
)

sketchybar 	--add item network.down right 						\
						--set network.down "${network_down[@]}" 	\
						--add item network.up right 							\
						--set network.up "${network_up[@]}"


separator_right=(
	icon=$'\xef\x81\x94'
	icon.font="$NERD_FONT:Regular:16.0"
	icon.padding_left=6
	icon.padding_right=6
	background.padding_left=8
	background.padding_right=8
	label.drawing=off
	click_script='sketchybar --trigger toggle_stats'
	icon.color="$TEXT"
)

sketchybar  --add item separator_right right \
	          --set separator_right "${separator_right[@]}"