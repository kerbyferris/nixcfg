#!/usr/bin/env bash

pkill -f '\.waybar-wrapped' 2>/dev/null || true
sleep 1

while true; do
    waybar "$@"
    sleep 1
done
