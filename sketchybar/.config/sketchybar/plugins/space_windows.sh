#!/usr/bin/env bash

# --- Yabai version ---
# update_space() {
#   space=$1
#   apps=$(yabai -m query --windows --space $space | jq -r '.[] | select(."is-minimized" == false and .role == "AXWindow") | .app')
#   icon_strip=" "
#   if [ "$apps" != "" ]; then
#     while read -r app; do
#       icon=$($CONFIG_DIR/plugins/icon_map.sh "$app")
#       case "$icon_strip" in
#       *"$icon"*) : ;;
#       *) icon_strip+="$icon " ;;
#       esac
#     done <<<"$apps"
#   else
#     icon_strip=" —"
#   fi
#   sketchybar --set space.$space label="$icon_strip"
# }
#
# if [ "$SENDER" = "space_windows_change" ]; then
#   for space in $(yabai -m query --spaces | jq '.[].index'); do
#     update_space $space
#   done
# elif [ "$SENDER" = "space_change" ]; then
#   update_space $(yabai -m query --spaces --space | jq '.index')
# fi

# --- AeroSpace version ---
# AEROSPACE_PATH=$(command -v aerospace)
# ICON_MAP_PATH="$HOME/.config/sketchybar/plugins/icon_map.sh"
# if [ -z "$AEROSPACE_PATH" ]; then
#   [ -f "/opt/homebrew/bin/aerospace" ] && AEROSPACE_PATH="/opt/homebrew/bin/aerospace"
#   [ -f "/usr/local/bin/aerospace" ] && AEROSPACE_PATH="/usr/local/bin/aerospace"
# fi
#
# for sid in 1 2 3 4; do
#   apps=$($AEROSPACE_PATH list-windows --workspace "$sid" --format "%{app-name}")
#   icon_strip=""
#   if [ -n "$apps" ]; then
#     while read -r app; do
#       if [ -n "$app" ]; then
#         icon=$($ICON_MAP_PATH "$app")
#         case "$icon_strip" in
#           *"$icon"*) ;;
#           *) icon_strip+=" $icon" ;;
#         esac
#       fi
#     done <<< "$apps"
#   else
#     icon_strip=" —"
#   fi
#   sketchybar --set space.$sid label="$icon_strip"
# done

# --- Amethyst version ---
export LC_ALL=en_US.UTF-8
umask 077
CACHE_DIR="${TMPDIR:-$HOME/Library/Caches}/taro-rice-spaces"
mkdir -p "$CACHE_DIR" || exit 1
[[ "${NAME:-}" = discord_badge || "${SENDER:-}" = space_windows_change ]] || exit 0

# SketchyBar launches event scripts concurrently. Don't let a slow window-open
# snapshot overwrite a later close, or race a badge redraw.
exec 9>"$CACHE_DIR/events.lock"
/usr/bin/lockf 9 || exit 1

# Events for different Spaces arrive concurrently. Replace just one complete
# label at a time; a badge refresh must never clear another Space's icons.
write_cache() {
  local path=$1 value=$2 tmp
  tmp=$(mktemp "$CACHE_DIR/.write.XXXXXX") || return 1
  printf '%s\n' "$value" > "$tmp" && mv -f "$tmp" "$path"
}

render() {
  local sid=$1 base badge=""
  IFS= read -r base < "$CACHE_DIR/space.$sid" || return 1
  if [ -f "$CACHE_DIR/badge" ]; then IFS= read -r badge < "$CACHE_DIR/badge"; fi
  sketchybar --set "space.$sid" label="${base/:discord:/:discord:$badge}"
}

discord_badge() {
  local app raw count digits=(⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹)
  for app in Discord "Discord Canary" "Discord PTB" Vesktop; do
    pgrep -x -u "$UID" "$app" >/dev/null || continue
    raw=$(lsappinfo info -only StatusLabel "$app" 2>/dev/null)
    count=$(sed -n 's/.*"label"="\([^"]*\)".*/\1/p' <<<"$raw" | tr -cd '0-9')
    case "$count" in ''|0) continue ;; [1-9]) printf '%s' "${digits[$count]}" ;; *) printf '⁹⁺' ;; esac
    return
  done
}

if [ "${NAME:-}" = discord_badge ]; then
  # Skip LaunchServices entirely if Discord has no cached window.
  if ! grep -Fqs ':discord:' "$CACHE_DIR"/space.[0-9]*; then exit 0; fi
  badge=$(discord_badge)
  old=""
  if [ -f "$CACHE_DIR/badge" ]; then IFS= read -r old < "$CACHE_DIR/badge"; fi
  [ "$old" != "$badge" ] || exit 0
  write_cache "$CACHE_DIR/badge" "$badge" || exit 1
  for ((sid=1; sid<=10; sid++)); do
    if grep -Fqs ':discord:' "$CACHE_DIR/space.$sid"; then render "$sid"; fi
  done
  exit 0
fi

# The index in the native event is the Mission Control ordinal, not the CGS ID.
# Ignore partial events; only an explicit empty apps object clears the label.
snapshot=$(jq -er '
  select((.space | type) == "number" and .space >= 1 and .space <= 10 and .space == (.space|floor))
  | select((.apps | type) == "object" and all(.apps[]; type == "number"))
  | .space, (.apps | to_entries[] | select(.value > 0) | .key | gsub("[\r\n]"; " "))
' <<<"${INFO:-}") || exit 0
{
  IFS= read -r sid
  strip=" "
  while IFS= read -r app; do
    case "$app" in
      "Visual Studio Code - Insiders") app="Code - Insiders" ;;
      "Visual Studio Code") app="Code" ;;
    esac
    icon=$("$CONFIG_DIR/plugins/icon_map.sh" "$app") || exit 1
    case "$strip" in *" $icon "*) ;; *) strip+="$icon " ;; esac
  done
} <<<"$snapshot"
[ "$strip" != " " ] || strip=" —"
write_cache "$CACHE_DIR/space.$sid" "$strip" && render "$sid"
