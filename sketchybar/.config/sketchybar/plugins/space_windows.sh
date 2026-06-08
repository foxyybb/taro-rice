#!/bin/bash

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
# Amethyst is a native-macOS-Spaces tiling WM and exposes NO CLI to query windows
# per space. Earlier revisions read only the CURRENT space's on-screen windows,
# which was inherently racy: rapid space switches and the macOS space-switch
# animation (which briefly shows windows from two spaces) produced wrong/phantom
# icons or cleared spaces.
#
# We use the private CoreGraphics "Spaces" API (the same one yabai/AeroSpace use
# internally) to map windows to the space they live on via CGSCopySpacesForWindows.
# IMPORTANT macOS limitation: CGWindowListCopyWindowInfo only reliably enumerates
# windows on the CURRENTLY ACTIVE space — windows on other spaces are usually not
# returned until that space is rendered. So a single pass can only see the active
# space's windows; rebuilding every label from one pass would blank all the others.
#
# To "remember" the other spaces, we keep a persistent cache (one line per space)
# of each space's last-known icon strip. Each run:
#   - spaces we CAN see this pass (the active space, plus any other space whose
#     windows happen to be enumerable) are refreshed and written to the cache;
#   - the ACTIVE space, if it has no windows, is genuinely empty -> show " —";
#   - all other (unseen) spaces keep their cached icons instead of being blanked.
# This way each space's icons are captured the moment you're on it and remembered
# afterward, while still self-correcting whenever a space becomes visible again.
ICON_MAP_PATH="$CONFIG_DIR/plugins/icon_map.sh"
[ -x "$ICON_MAP_PATH" ] || ICON_MAP_PATH="$HOME/.config/sketchybar/plugins/icon_map.sh"

MAX_SPACES=10
CACHE_FILE="/tmp/sketchybar_space_cache"

# CoreGraphics reports an app's localized display name (e.g. "Visual Studio Code -
# Insiders"), whereas icon_map.sh keys off the shorter menu-bar name yabai returns
# (e.g. "Code - Insiders"). Normalize the known mismatches here.
normalize_app() {
  case "$1" in
    "Visual Studio Code - Insiders") echo "Code - Insiders" ;;
    "Visual Studio Code")            echo "Code" ;;
    *)                                echo "$1" ;;
  esac
}

# Read Discord's Dock badge (mention / unread-DM count) via lsappinfo and return
# the digits of that badge, or "" when there is no badge / Discord isn't running.
# Discord variants register under different display names, so query each known
# name until one responds; the badge value looks like:  "StatusLabel"={ "label"="5" }
# We keep digits only, so an empty badge or a non-numeric indicator yields "".
discord_badge() {
  local name raw
  for name in "Discord" "Discord Canary" "Discord PTB" "Vesktop"; do
    raw="$(lsappinfo info -only StatusLabel "$name" 2>/dev/null)"
    [ -z "$raw" ] && continue                       # variant not running
    raw="$(printf '%s' "$raw" | sed -n 's/.*"label"="\([^"]*\)".*/\1/p')"
    raw="$(printf '%s' "$raw" | tr -cd '0-9')"
    if [ -n "$raw" ]; then
      printf '%s' "$raw"
      return 0
    fi
  done
  printf ''
}

# Render a notification COUNT as raised superscript glyphs, capped at "9+".
# sketchybar-app-font is a ligature ICON font whose plain ASCII digits are partly
# mapped to BLANK glyphs (invisible) and otherwise fall back, so an inline plain
# count renders inconsistently. Filled circled digits stay visible but are large,
# baseline-aligned glyphs that sit too low (a single label shares one y_offset,
# so the badge can't be nudged up on its own). The SUPERSCRIPT codepoints
# (U+2070, U+00B9-U+00B3, U+2074..U+2079, and U+207A for '+') are ALL absent from
# this font, so they fall back to the system font, stay fully visible, AND are
# raised by design — which lifts the count to a better height. Counts above 9 are
# shown as "9+" to keep the badge compact.
to_superscript_digit() {
  case "$1" in
    0) printf '⁰' ;;
    1) printf '¹' ;;
    2) printf '²' ;;
    3) printf '³' ;;
    4) printf '⁴' ;;
    5) printf '⁵' ;;
    6) printf '⁶' ;;
    7) printf '⁷' ;;
    8) printf '⁸' ;;
    9) printf '⁹' ;;
    *) printf '%s' "$1" ;;
  esac
}

# Map a numeric count to its superscript badge text, capping anything >= 10 at
# the superscript "9+".
to_count_badge() {
  local v="$1"
  case "$v" in ''|*[!0-9]*) printf ''; return ;; esac
  v=$((10#$v))                                    # strip leading zeros safely
  if [ "$v" -le 0 ]; then
    printf ''
  elif [ "$v" -ge 10 ]; then
    printf '%s⁺' "$(to_superscript_digit 9)"  # 9+
  else
    to_superscript_digit "$v"
  fi
}

# Emit the active space index as "CURRENT<TAB>idx", then "spaceIndex<TAB>appName"
# for every standard window we can enumerate.
window_space_map() {
  osascript -l JavaScript <<'JXA'
ObjC.import('CoreGraphics');
ObjC.import('Foundation');
// Private SkyLight/CoreGraphics symbols, bound by signature.
ObjC.bindFunction('CGSMainConnectionID', ['int', []]);
ObjC.bindFunction('CGSCopyManagedDisplaySpaces', ['id', ['int']]);
ObjC.bindFunction('CGSCopySpacesForWindows', ['id', ['int', 'int', 'id']]);
const cid = $.CGSMainConnectionID();

// Build a map of macOS space id -> 1-based ordinal (matches sketchybar numbering)
// and record the active space's ordinal.
const displays = ObjC.deepUnwrap($.CGSCopyManagedDisplaySpaces(cid));
const indexOfSpace = {};
let ordinal = 0;
let currentIdx = 0;
displays.forEach(d => {
  const curId = (d['Current Space'] || {}).ManagedSpaceID;
  (d.Spaces || []).forEach(s => {
    ordinal++;
    indexOfSpace[s.ManagedSpaceID] = ordinal;
    if (curId != null && s.ManagedSpaceID === curId) currentIdx = ordinal;
  });
});

const wins = $.CGWindowListCopyWindowInfo(1 << 0, 0); // kCGWindowListOptionAll
const n = $.CFArrayGetCount(wins);
const out = ['CURRENT\t' + currentIdx];
for (let i = 0; i < n; i++) {
  const dict = ObjC.castRefToObject($.CFArrayGetValueAtIndex(wins, i));
  if (ObjC.unwrap(dict.objectForKey('kCGWindowLayer')) !== 0) continue; // app windows only
  const owner = ObjC.unwrap(dict.objectForKey('kCGWindowOwnerName'));
  const wnum = ObjC.unwrap(dict.objectForKey('kCGWindowNumber'));
  if (!owner || wnum == null) continue;
  const spaces = ObjC.deepUnwrap($.CGSCopySpacesForWindows(cid, 0x7, $([wnum])));
  if (!spaces || !spaces.length) continue;
  const idx = indexOfSpace[spaces[0]];
  if (idx) out.push(idx + '\t' + owner);
}
out.join('\n');
JXA
}

# Per-space icon strips for what we can SEE this pass, plus which spaces had any
# window (bash 3.2-safe: numeric indexed arrays).
strip=()
seen=()
current_idx=0
i=1
while [ "$i" -le "$MAX_SPACES" ]; do strip[$i]=" "; seen[$i]=0; i=$((i + 1)); done

while IFS=$'\t' read -r sidx app; do
  [ -z "$sidx" ] && continue
  if [ "$sidx" = "CURRENT" ]; then
    case "$app" in ''|*[!0-9]*) : ;; *) current_idx="$app" ;; esac
    continue
  fi
  case "$sidx" in *[!0-9]*) continue ;; esac
  [ "$sidx" -ge 1 ] && [ "$sidx" -le "$MAX_SPACES" ] || continue
  seen[$sidx]=1
  app="$(normalize_app "$app")"
  icon=$("$ICON_MAP_PATH" "$app")
  case "${strip[$sidx]}" in
    *"$icon"*) : ;;                               # dedup repeated icons per space
    *) strip[$sidx]="${strip[$sidx]}$icon " ;;
  esac
done <<< "$(window_space_map)"

# Load last-known labels + per-space "first seen empty" timestamps from the cache.
# Cache lines: "index<TAB>label<TAB>emptySinceEpoch" (emptySince is "" when the
# space last had windows).
cache=()
empty_since=()
if [ -f "$CACHE_FILE" ]; then
  while IFS=$'\t' read -r cidx clabel cts; do
    case "$cidx" in ''|*[!0-9]*) continue ;; esac
    [ "$cidx" -ge 1 ] && [ "$cidx" -le "$MAX_SPACES" ] || continue
    cache[$cidx]="$clabel"
    empty_since[$cidx]="$cts"
  done < "$CACHE_FILE"
fi

# A label counts as "empty" if it has no icon tokens (just spaces or the dash).
is_empty_label() {
  case "$1" in
    *:*) return 1 ;;   # contains an :icon: token
    *)   return 0 ;;
  esac
}

# How long (seconds) the ACTIVE space must stay empty before we actually clear it.
# This rides out the macOS space-switch animation: when you switch onto a space,
# its windows are not enumerable for a fraction of a second, so a naive reading
# looks empty and would wipe the cache. We keep the cached icons until the space
# has been verifiably empty for this long, which only happens for genuinely empty
# spaces (a populated space starts reporting its windows well within the window).
EMPTY_GRACE=2
now="$(date +%s)"

# Discord's current notification count, read once per pass and rendered as a
# raised superscript badge (capped at 9+). Injected at render time (below) rather
# than baked into the cached icon strip, so the count stays fresh for spaces we
# can't re-enumerate this pass (Discord sitting on a non-active space) and clears
# automatically once the badge is read.
DISCORD_BADGE="$(discord_badge)"
DISCORD_COUNT=""
[ -n "$DISCORD_BADGE" ] && DISCORD_COUNT="$(to_count_badge "$DISCORD_BADGE")"

# Merge:
#   - any space we positively SEE with windows this pass -> refresh + cache it;
#   - the ACTIVE space with no windows -> keep cached icons during the grace
#     period, only commit to empty once it has stayed empty long enough;
#   - all other unseen spaces -> keep their cached icons (never blanked here).
args=()
: > "$CACHE_FILE"
i=1
while [ "$i" -le "$MAX_SPACES" ]; do
  ts=""
  if [ "${seen[$i]}" = "1" ]; then
    label="${strip[$i]}"                          # confident: real windows seen
  elif [ "$i" = "$current_idx" ]; then
    # Active but nothing enumerated yet — could be a transition or truly empty.
    since="${empty_since[$i]}"
    [ -z "$since" ] && since="$now"               # start the grace clock
    if [ -n "${cache[$i]}" ] && ! is_empty_label "${cache[$i]}" \
       && [ "$((now - since))" -lt "$EMPTY_GRACE" ]; then
      label="${cache[$i]}"                         # within grace: keep icons
      ts="$since"                                  # remember when empty started
    else
      label=" —"                                   # stayed empty: truly empty
      ts="$since"
    fi
  elif [ -n "${cache[$i]}" ]; then
    label="${cache[$i]}"                            # unseen: remember last-known
    ts="${empty_since[$i]}"
  else
    label=" —"
  fi
  # Cache the icon-only base label, but DISPLAY the discord glyph with its
  # notification count (raised superscript, capped at 9+) appended when Discord
  # has notifications.
  display="$label"
  if [ -n "$DISCORD_COUNT" ]; then
    case "$label" in
      *":discord:"*) display="${label/:discord:/:discord:$DISCORD_COUNT}" ;;
    esac
  fi
  args+=(--set "space.$i" label="$display")
  printf '%s\t%s\t%s\n' "$i" "$label" "$ts" >> "$CACHE_FILE"
  i=$((i + 1))
done
sketchybar "${args[@]}"
