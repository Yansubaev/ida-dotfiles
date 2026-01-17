#!/usr/bin/env bash
set -euo pipefail

# Power menu for wofi (dmenu mode).
# Uses your existing wofi style/config automatically.
#
# Features:
# - compact menu geometry
# - confirm dialog in one row
# - prompt shows selected action
# - "toggle" behavior: re-run closes existing wofi

if pgrep -x wofi >/dev/null; then
  pkill -x wofi
  exit 0
fi

shutdown_label="  1. Shutdown"
reboot_label="  2. Reboot"
logout_label="󰍃  3. Logout"
suspend_label="󰤄  4. Suspend"

entries=$(printf "%s\n%s\n%s\n%s\n" "$shutdown_label" "$reboot_label" "$logout_label" "$suspend_label")

# Compact power menu. Height set to exact rows; width small but readable.
# (wofi doesn't autosize to content reliably, so we pick sane compact defaults.)
# Use fixed size to avoid any geometry reflow/jitter when moving selection.
choice="$(printf "%s" "$entries" | wofi --dmenu --prompt "Power" --width 280 --height 255)"

[ -z "${choice}" ] && exit 0

action_text="$choice"
action_text="${action_text#*  }" # strip icon + double-space

confirm_label="  Confirm"
cancel_label="  Cancel"
confirm_entries=$(printf "%s\n%s\n" "$confirm_label" "$cancel_label")

# Confirm/cancel in one row.
# Keep the same theme; just hide the search bar.
confirm="$(printf "%s" "$confirm_entries" | wofi --dmenu --prompt "${action_text}?" --columns 2 --width 360 --height 117)"

[ "${confirm}" != "${confirm_label}" ] && exit 0

case "$choice" in
"$shutdown_label")
  systemctl poweroff
  ;;
"$reboot_label")
  systemctl reboot
  ;;
"$logout_label")
  hyprctl dispatch exit
  ;;
"$suspend_label")
  systemctl suspend
  ;;
*)
  exit 0
  ;;
esac
