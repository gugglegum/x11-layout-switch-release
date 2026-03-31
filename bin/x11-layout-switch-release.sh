#!/usr/bin/env bash

set -u

readonly KEYBOARD_NAME="${KB_LAYOUT_SWITCH_KEYBOARD_NAME:-AT Translated Set 2 keyboard}"
readonly FALLBACK_KEYBOARD_NAME="${KB_LAYOUT_SWITCH_FALLBACK_KEYBOARD_NAME:-Virtual core keyboard}"
readonly XKB_SWITCH_CMD="${XKB_SWITCH_CMD:-xkb-switch}"
readonly DEBUG="${KB_LAYOUT_SWITCH_DEBUG:-0}"
readonly LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/x11_layout_switch_release.lock"

readonly KEY_LEFT_CTRL=37
readonly KEY_LEFT_ALT=64
readonly KEY_LEFT_SHIFT=50
readonly KEY_RIGHT_CTRL=105
readonly KEY_RIGHT_ALT=108
readonly KEY_RIGHT_SHIFT=62

switch_sequences=(
    "Ctrl_Down Shift_Down Ctrl_Up"
    "Ctrl_Down Shift_Down Shift_Up"
    "Shift_Down Ctrl_Down Ctrl_Up"
    "Shift_Down Ctrl_Down Shift_Up"
    "Alt_Down Shift_Down Alt_Up"
    "Alt_Down Shift_Down Shift_Up"
    "Shift_Down Alt_Down Alt_Up"
    "Shift_Down Alt_Down Shift_Up"
)

buffer=()

log_debug() {
    if [[ "$DEBUG" == "1" ]]; then
        echo "$*" >&2
    fi
}

die() {
    echo "$*" >&2
    exit 1
}

acquire_lock() {
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        log_debug "Another x11-layout-switch-release instance is already running"
        exit 0
    fi
}

resolve_xkb_switch_cmd() {
    if [[ "$XKB_SWITCH_CMD" == */* ]]; then
        [[ -x "$XKB_SWITCH_CMD" ]] || die "Cannot execute xkb-switch at '$XKB_SWITCH_CMD'"
        printf '%s\n' "$XKB_SWITCH_CMD"
        return 0
    fi

    if command -v "$XKB_SWITCH_CMD" >/dev/null 2>&1; then
        command -v "$XKB_SWITCH_CMD"
        return 0
    fi

    die "Cannot find xkb-switch. Install it first or set XKB_SWITCH_CMD."
}

resolve_keyboard_id() {
    local id

    if [[ -n "${KB_LAYOUT_SWITCH_KEYBOARD_ID:-}" ]]; then
        printf '%s\n' "$KB_LAYOUT_SWITCH_KEYBOARD_ID"
        return 0
    fi

    id=$(xinput list --id-only "$KEYBOARD_NAME" 2>/dev/null | head -n 1)
    if [[ -n "$id" ]]; then
        printf '%s\n' "$id"
        return 0
    fi

    id=$(xinput list --id-only "$FALLBACK_KEYBOARD_NAME" 2>/dev/null | head -n 1)
    if [[ -n "$id" ]]; then
        printf '%s\n' "$id"
        return 0
    fi

    die "Cannot resolve keyboard id for xinput test."
}

map_event() {
    local event_type="$1"
    local keycode="$2"

    case "$event_type:$keycode" in
        press:$KEY_LEFT_CTRL|press:$KEY_RIGHT_CTRL) printf '%s\n' "Ctrl_Down" ;;
        release:$KEY_LEFT_CTRL|release:$KEY_RIGHT_CTRL) printf '%s\n' "Ctrl_Up" ;;
        press:$KEY_LEFT_ALT|press:$KEY_RIGHT_ALT) printf '%s\n' "Alt_Down" ;;
        release:$KEY_LEFT_ALT|release:$KEY_RIGHT_ALT) printf '%s\n' "Alt_Up" ;;
        press:$KEY_LEFT_SHIFT|press:$KEY_RIGHT_SHIFT) printf '%s\n' "Shift_Down" ;;
        release:$KEY_LEFT_SHIFT|release:$KEY_RIGHT_SHIFT) printf '%s\n' "Shift_Up" ;;
        press:*) printf '%s\n' "Other_Down" ;;
        release:*) printf '%s\n' "Other_Up" ;;
        *) return 1 ;;
    esac
}

check_sequence() {
    local switch_sequence

    if [[ ${#buffer[@]} -ne 3 ]]; then
        return 0
    fi

    for switch_sequence in "${switch_sequences[@]}"; do
        if [[ "${buffer[*]}" == "$switch_sequence" ]]; then
            log_debug "--- KEYBOARD SWITCH ---"
            buffer=()

            if ! "$LAYOUT_SWITCH_CMD" -n; then
                echo "Layout switch failed" >&2
            fi
            return 0
        fi
    done
}

command -v xinput >/dev/null 2>&1 || die "Cannot find xinput."
readonly LAYOUT_SWITCH_CMD="$(resolve_xkb_switch_cmd)"
readonly KEYBOARD_ID="$(resolve_keyboard_id)"

acquire_lock
log_debug "Listening on keyboard id $KEYBOARD_ID"
log_debug "Using xkb-switch command $LAYOUT_SWITCH_CMD"

while read -r line; do
    local_event=""

    log_debug "$line"

    if [[ "$line" =~ ^key[[:space:]]+(press|release)[[:space:]]+([0-9]+)$ ]]; then
        local_event=$(map_event "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}") || continue
    else
        continue
    fi

    log_debug "$local_event"
    buffer+=("$local_event")

    if [[ ${#buffer[@]} -gt 3 ]]; then
        buffer=("${buffer[@]: -3}")
    fi

    if [[ "${buffer[*]}" == *"Other_Down"* ]] || [[ "${buffer[*]}" == *"Other_Up"* ]]; then
        buffer=()
    fi

    check_sequence
done < <(xinput test "$KEYBOARD_ID")
