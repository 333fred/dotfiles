#!/usr/bin/env bash

# Terminate already running bar instances
killall -q polybar
# If all your bars have ipc enabled, you can also use 
# polybar-msg cmd quit

MONITOR="DP-4" polybar --reload main >> /tmp/polybar.main.log 2>&1 &
MONITOR="DP-2" polybar --reload second >> /tmp/polybar.second.log 2>&1 &

echo "Bars launched..."
