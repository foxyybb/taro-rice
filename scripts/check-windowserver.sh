#!/bin/bash
# Compare two samples without changing SketchyBar, playback, or the session.
set -euo pipefail
export LC_ALL=C
seconds=${1:-600}
if [[ $# -gt 1 || ! "$seconds" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: $0 [positive sample duration in seconds]" >&2
  exit 2
fi

pid=$(/usr/bin/pgrep -x WindowServer)
[[ "$pid" =~ ^[0-9]+$ ]] || { echo "Expected one WindowServer process" >&2; exit 1; }
identity=$(/bin/ps -p "$pid" -o lstart=)
port_count() {
  /usr/bin/top -l 1 -pid "$pid" -stats pid,ports | /usr/bin/awk -v p="$pid" '
    $1 == p && $2 ~ /^[0-9]+$/ {print $2; found=1} END {if (!found) exit 1}'
}
dead_names() {
  /usr/bin/lsmp -p "$pid" | /usr/bin/awk '
    /^Process .*WindowServer/ {found=1}
    $1 ~ /^0x/ && tolower($0) ~ /dead[-_]name/ {n++}
    END {if (!found) exit 1; print n+0}'
}

before=$(port_count)
dead_before=""
if (( EUID == 0 )); then dead_before=$(dead_names); fi
start=$(/bin/date '+%Y-%m-%d %H:%M:%S')
printf 'WindowServer %s: sampling from %s for %s seconds\n' "$pid" "$start" "$seconds"
/bin/sleep "$seconds"
end=$(/bin/date '+%Y-%m-%d %H:%M:%S')
if [[ "$(/bin/ps -p "$pid" -o lstart=)" != "$identity" ]]; then
  echo "WindowServer restarted; discard this comparison." >&2
  exit 1
fi
after=$(port_count)
printf 'Total ports: %s -> %s (%+d)\n' "$before" "$after" "$((after-before))"
if [[ -n "$dead_before" ]]; then
  dead_after=$(dead_names)
  printf 'Dead names: %s -> %s (%+d)\n' "$dead_before" "$dead_after" "$((dead_after-dead_before))"
fi
/usr/bin/log show --start "$start" --end "$end" --style compact --info \
  --predicate "processID == $pid AND (eventMessage CONTAINS \"New conn \" OR eventMessage CONTAINS \"Process creation:\")" |
  /usr/bin/awk '
    /\[ ConnectionDebug \] New conn / {connections++}
    /Process creation:.*\(osascript\) connectionID:/ {scripts++}
    END {printf "New WindowServer connections: %d; osascript launches: %d\n", connections, scripts}'
