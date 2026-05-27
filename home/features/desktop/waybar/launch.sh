#!/usr/bin/env bash

pkill '\.waybar-wrapp' 2>/dev/null || true
sleep 1

while true; do
    waybar "$@"
    sleep 1
done
