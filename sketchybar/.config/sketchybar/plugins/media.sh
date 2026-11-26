#!/usr/bin/env bash

export LC_ALL=en_US.UTF-8

# Query on initialization, wake, click, or an incomplete notification, never
# on a timer. Don't send Apple events to an app that isn't already running.
snapshot() {
  local app
  local -a running=()
  for app in Spotify Music; do
    if pgrep -x -u "$UID" "$app" >/dev/null; then running+=("$app"); fi
  done
  if [ "${#running[@]}" -eq 0 ]; then printf '{}\n'; return; fi
  osascript -l JavaScript - "${1:-refresh}" "${running[@]}" <<'JXA'
function run([action, ...names]) {
  for (const name of names) {
    try {
      const app = Application(name);
      let state = String(app.playerState());
      if (state !== 'playing' && state !== 'paused') continue;
      if (action === 'toggle') {
        app.playpause();
        state = String(app.playerState());
      }
      const track = app.currentTrack;
      return JSON.stringify({'Player State':state, Name:track.name(), Artist:track.artist()});
    } catch (_) { /* Player quit or has no current track. */ }
  }
  return '{}';
}
JXA
}

parse_info() {
  jq -er 'select(type == "object") |
    [((."Player State" // "") | ascii_downcase), (.Name // ""), (.Artist // "")] |
    .[] | strings | gsub("[\r\n]"; " ")' <<<"$1"
}

if [ "${1:-}" = toggle ]; then
  info=$(snapshot toggle) || exit 1
else
  case "${SENDER:-forced}" in
    spotify_playback|music_playback)
      info=${INFO:-}
      # Spotify has priority when both players are open. A stop from one
      # player, or a notification without userInfo, may expose the other.
      if ! jq -e '((."Player State" // "") | ascii_downcase | . == "playing" or . == "paused")
                  and (.Name | type == "string") and (.Artist | type == "string")' \
            >/dev/null 2>&1 <<<"$info" ||
         { [ "$SENDER" = music_playback ] && pgrep -x -u "$UID" Spotify >/dev/null; }; then
        info=$(snapshot) || exit 1
      fi
      ;;
    forced|system_woke) info=$(snapshot) || exit 1 ;;
    *) exit 0 ;;
  esac
fi

fields=$(parse_info "$info") || exit 1
{
  IFS= read -r state
  IFS= read -r title
  IFS= read -r artist
} <<<"$fields"
case "$state" in
  playing) icon="􀊆" ;;
  paused)  icon="􀊄" ;;
  *) exec sketchybar --set media.cover drawing=off ;;
esac

label="$artist - $title"
if [ "${#label}" -gt 50 ]; then label="${label:0:47}..."; fi
exec sketchybar --set media.cover drawing=on label="$label" icon="$icon"
