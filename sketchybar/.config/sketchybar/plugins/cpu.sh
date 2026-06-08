#!/usr/bin/env bash
#cpu.sh

# `top -l 2` is required: the first sample reports the since-boot average, so we
# take the second (live) sample. "-n 0" skips the per-process list for speed.
# The summary line looks like: "CPU usage: 5.88% user, 11.76% sys, 82.35% idle".
# awk reads "5.88%"/"11.76%" as their leading numbers, so user+sys = total busy.
CPU_USAGE=$(top -l 2 -n 0 -s 1 | awk '/^CPU usage/{u=$3; s=$5} END{ printf "%.0f", u + s }')

sketchybar -m --set "$NAME" label="${CPU_USAGE}%"
