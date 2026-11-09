#!/bin/bash

# Turns the displays off or back on for the Screen off action.
#
#   screen-power.sh off      blank the displays
#   screen-power.sh on       wake them
#   screen-power.sh release  undo our changes without waking (the session locked)
#
# By default the displays are switched off with DPMS. A screen-off hook
# (~/.config/omarchy/hooks/screen-off or screen-off.d/) replaces that, for
# displays such as TVs that should be blanked another way; a screen-on hook
# runs when they wake.

set -u

state_file="${XDG_RUNTIME_DIR:-/tmp}/simple-power-menu-screen-off"
hooks_dir="$HOME/.config/omarchy/hooks"

has_hook() {
  [[ -f $hooks_dir/$1 ]] || compgen -G "$hooks_dir/$1.d/*" >/dev/null
}

# Hyprland wakes DPMS on any mouse movement, which a bumped desk would do.
# Keep only keys and buttons (handled by the overlay) as wake-ups while off.
suspend_mouse_wake() {
  [[ -f $state_file ]] && return
  hyprctl -j getoption misc:mouse_move_enables_dpms 2>/dev/null | jq -r '.int // 1' >"$state_file"
  hyprctl eval 'hl.config({ misc = { mouse_move_enables_dpms = false } })' >/dev/null
}

restore_mouse_wake() {
  [[ -f $state_file ]] || return
  local original
  original="$(<"$state_file")"
  rm -f "$state_file"
  [[ $original == 0 ]] && value=false || value=true
  hyprctl eval "hl.config({ misc = { mouse_move_enables_dpms = $value } })" >/dev/null
}

case "${1:-}" in
  off)
    if has_hook screen-off; then
      /usr/bin/omarchy hook screen-off
    else
      suspend_mouse_wake
      /usr/bin/omarchy brightness display off
    fi
    ;;
  on)
    restore_mouse_wake
    /usr/bin/omarchy brightness display on
    has_hook screen-on && /usr/bin/omarchy hook screen-on
    ;;
  release)
    restore_mouse_wake
    ;;
  *)
    echo "Usage: screen-power.sh off|on|release" >&2
    exit 2
    ;;
esac
