#!/usr/bin/env bash

# Kill any running waybar instances
pkill -x .waybar-wrapped 2>/dev/null || true
while pgrep -x .waybar-wrapped >/dev/null 2>&1; do sleep 0.5; done

# Respawn loop - restart waybar if it gets killed (e.g. by nixos-rebuild)
while true; do
    waybar "$@"
    sleep 1
done
