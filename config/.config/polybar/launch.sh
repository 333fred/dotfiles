#!/usr/bin/env bash

# Terminate already running bar instances
killall -q polybar
# If all your bars have ipc enabled, you can also use 
# polybar-msg cmd quit

for m in $(polybar --list-monitors | cut -d":" -f1); do
    MONITOR=$m polybar --reload example >> /tmp/polybar.$m.log 2>&1 &
done

echo "Bars launched..."
