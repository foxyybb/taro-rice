#!/usr/bin/env bash

# Optional per-machine override. Copy local_config.example.sh to local_config.sh
# and set NETWORK_IFACE there if a machine should pin a specific interface.
LOCAL_CONFIG="${SKETCHYBAR_LOCAL_CONFIG:-$HOME/.config/sketchybar/plugins/local_config.sh}"
[ -f "$LOCAL_CONFIG" ] && . "$LOCAL_CONFIG"

PREFERRED="${NETWORK_IFACE:-}"
if [ -n "$PREFERRED" ] && ipconfig getifaddr "$PREFERRED" >/dev/null 2>&1; then
	IFACE="$PREFERRED"
else
	IFACE=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
	[ -z "$IFACE" ] && IFACE="${PREFERRED:-en0}"
fi

UPDOWN=$(ifstat -i "$IFACE" -b 0.1 1 | tail -n1)
DOWN=$(echo "$UPDOWN" | awk "{ print \$1 }" | cut -f1 -d ".")
UP=$(echo "$UPDOWN" | awk "{ print \$2 }" | cut -f1 -d ".")

DOWN_FORMAT=""
if [ "$DOWN" -gt "999" ]; then
	DOWN_FORMAT=$(echo "$DOWN" | awk '{ printf "%03.0f Mbps", $1 / 1000}')
else
	DOWN_FORMAT=$(echo "$DOWN" | awk '{ printf "%03.0f kbps", $1}')
fi

UP_FORMAT=""
if [ "$UP" -gt "999" ]; then
	UP_FORMAT=$(echo "$UP" | awk '{ printf "%03.0f Mbps", $1 / 1000}')
else
	UP_FORMAT=$(echo "$UP" | awk '{ printf "%03.0f kbps", $1}')
fi

sketchybar -m --set network.down label="$DOWN_FORMAT" icon.highlight=$(if [ "$DOWN" -gt "0" ]; then echo "on"; else echo "off"; fi) \
	--set network.up label="$UP_FORMAT" icon.highlight=$(if [ "$UP" -gt "0" ]; then echo "on"; else echo "off"; fi)