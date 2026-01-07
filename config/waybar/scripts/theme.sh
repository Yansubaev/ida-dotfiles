#!/bin/bash

# Reload Waybar without changing themes.

# Prefer asking Waybar to reload itself; fall back to restart.
if pkill -SIGUSR2 waybar 2>/dev/null; then
  exit 0
fi

pkill waybar 2>/dev/null
waybar & disown
