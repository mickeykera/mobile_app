#!/usr/bin/env bash

set -u

avd_name="${1:?AVD name is required}"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}"
emulator="$sdk_root/emulator/emulator"

QT_QPA_PLATFORM=xcb "$emulator" -avd "$avd_name" -no-snapshot &
emulator_pid=$!

if command -v wmctrl >/dev/null 2>&1 && command -v xrandr >/dev/null 2>&1; then
  for _ in {1..60}; do
    window_id="$(wmctrl -l 2>/dev/null | awk -v avd="$avd_name" '$0 ~ avd { print $1; exit }')"
    if [[ -n "$window_id" ]]; then
      screen_width="$(xrandr --current 2>/dev/null | awk '/ connected primary/ { split($4, size, "x"); print size[1]; exit }')"
      if [[ "$screen_width" =~ ^[0-9]+$ ]]; then
        if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
          position_x=$(( (screen_width - 730) / 2 ))
          position_y=40
        else
          position_x=$((screen_width - 730))
          position_y=80
        fi
        wmctrl -i -r "$window_id" -e "0,$position_x,$position_y,702,1560" 2>/dev/null || true
      fi
      break
    fi
    sleep 1
  done
fi

wait "$emulator_pid"
