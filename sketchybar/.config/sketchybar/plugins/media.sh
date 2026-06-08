#!/bin/sh

# Ensure UTF-8 encoding for proper handling of international characters
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

APP=""
for app in "Spotify" "Music"; do
  if pgrep -x "$app" > /dev/null 2>&1; then
    STATE="$(osascript -e "tell application \"$app\" to player state" 2>/dev/null)"
    if [ "$STATE" = "playing" ] || [ "$STATE" = "paused" ]; then
      APP="$app"
      break
    fi
  fi
done

if [ -n "$APP" ]; then
  # A click (click_script passes "toggle") flips play/pause on the active app,
  # then we fall through to refresh the label/icon with the new state.
  if [ "$1" = "toggle" ]; then
    osascript -e "tell application \"$APP\" to playpause" 2>/dev/null
    STATE="$(osascript -e "tell application \"$APP\" to player state" 2>/dev/null)"
  fi

  TITLE="$(osascript -e "tell application \"$APP\" to name of current track" 2>/dev/null)"
  ARTIST="$(osascript -e "tell application \"$APP\" to artist of current track" 2>/dev/null)"

  # Convert to UTF-8 and sanitize for sketchybar
  TITLE="$(echo "$TITLE" | iconv -f UTF-8 -t UTF-8//IGNORE 2>/dev/null | tr -d '\n\r')"
  ARTIST="$(echo "$ARTIST" | iconv -f UTF-8 -t UTF-8//IGNORE 2>/dev/null | tr -d '\n\r')"

  LABEL="$ARTIST - $TITLE"
  if [ ${#LABEL} -gt 50 ]; then
    LABEL="$(echo "$LABEL" | cut -c1-47)..."
  fi

  # Icon reflects current state: pause glyph while playing, play glyph while paused.
  if [ "$STATE" = "playing" ]; then
    ICON="􀊆"
  else
    ICON="􀊄"
  fi

  sketchybar --set media.cover drawing=on label="$LABEL" icon="$ICON"
else
  sketchybar --set media.cover drawing=off
fi
