#!/usr/bin/env bash

# Stat items toggled together by the right-side separator chevron.
stats=(
	cpu.percent
	memory
	disk
	network.down
	network.up
)

# Separator chevron glyphs (nerd font): left (U+F053) = stats visible (click to
# hide), right (U+F054) = stats hidden (click to show). Use UTF-8 byte escapes so
# this works on macOS's bash 3.2 (which lacks $'\u' unicode escapes).
ICON_VISIBLE=$'\xef\x81\x93'
ICON_HIDDEN=$'\xef\x81\x94'

apply_stats() {
	draw="$1"
	sep_icon="$2"
	args=()
	for item in "${stats[@]}"; do
		args+=(--set "$item" drawing="$draw")
	done
	sketchybar "${args[@]}" --set separator_right icon="$sep_icon"
}

hide_stats() { apply_stats off "$ICON_HIDDEN"; }
show_stats() { apply_stats on "$ICON_VISIBLE"; }

# Decide based on the ACTUAL drawing state of a stat item (robust) rather than
# parsing the separator glyph.
toggle_stats() {
	state=$(sketchybar --query cpu.percent | jq -r '.geometry.drawing')
	if [ "$state" = "on" ]; then
		hide_stats
	else
		show_stats
	fi
}

case "$SENDER" in
"hide_stats")
	hide_stats
	;;
"show_stats")
	show_stats
	;;
"toggle_stats")
	toggle_stats
	;;
esac
