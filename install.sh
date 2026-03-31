#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LISTENER_SRC="$SCRIPT_DIR/bin/x11-layout-switch-release.sh"
DESKTOP_TEMPLATE="$SCRIPT_DIR/autostart/x11-layout-switch-release.desktop.in"

print_help() {
    cat <<EOF
Usage: ./install.sh [options]

Options:
  --user          Install into ~/.local/bin (default)
  --system        Install into /usr/local/bin
  --bin-dir PATH  Install binaries into PATH
  -i, --interactive
                  Prompt for the installation target
  -h, --help      Show this help

Environment:
  TARGET_USER       Target user for the autostart file
  INSTALL_BIN_DIR   Alternative way to set the binary install dir
EOF
}

run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

resolve_target_user() {
    TARGET_USER=${TARGET_USER:-${SUDO_USER:-${USER:-}}}
    if [ -z "$TARGET_USER" ]; then
        echo "Cannot detect target user. Set TARGET_USER=username and run again." >&2
        exit 1
    fi

    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    if [ -z "$TARGET_HOME" ]; then
        echo "Cannot resolve home directory for user '$TARGET_USER'." >&2
        exit 1
    fi
}

path_is_under_target_home() {
    case "$1" in
        "$TARGET_HOME"|"$TARGET_HOME"/*) return 0 ;;
        *) return 1 ;;
    esac
}

install_file() {
    destination_check="$1"
    shift

    if path_is_under_target_home "$destination_check"; then
        install "$@"
    else
        run_as_root install "$@"
    fi
}

install_dir() {
    if path_is_under_target_home "$1"; then
        install -d -m 755 "$1"
    else
        run_as_root install -d -m 755 "$1"
    fi
}

choose_bin_dir() {
    if [ ! -t 0 ]; then
        echo "Interactive mode requires a TTY." >&2
        exit 1
    fi

    printf '%s\n' "Select installation target for executable files:"
    printf '  1) %s (Recommended)\n' "$DEFAULT_USER_BIN"
    printf '  2) /usr/local/bin\n'
    printf '  3) Custom path\n'
    printf 'Choice [1]: '
    read -r choice

    case "${choice:-1}" in
        1)
            BIN_DIR="$DEFAULT_USER_BIN"
            ;;
        2)
            BIN_DIR="/usr/local/bin"
            ;;
        3)
            printf 'Enter full path: '
            read -r BIN_DIR
            if [ -z "$BIN_DIR" ]; then
                echo "Custom path cannot be empty." >&2
                exit 1
            fi
            ;;
        *)
            echo "Invalid choice: $choice" >&2
            exit 1
            ;;
    esac
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ensure_xinput() {
    if command_exists xinput; then
        return 0
    fi

    cat >&2 <<EOF
xinput was not found in PATH.

Install the xinput package first, then run install.sh again.
EOF
    exit 1
}

ensure_xkb_switch() {
    if command_exists xkb-switch; then
        return 0
    fi

    cat >&2 <<EOF
xkb-switch was not found.

Install xkb-switch first, then run install.sh again.
Upstream project:
  https://github.com/grwlf/xkb-switch

Typical build steps on Debian/Ubuntu/Linux Mint:
  sudo apt install cmake make g++ libxkbfile-dev
  git clone https://github.com/grwlf/xkb-switch.git
  cd xkb-switch
  mkdir build && cd build
  cmake ..
  make
  sudo make install
  sudo ldconfig

If xkb-switch is installed into a non-standard directory, add that directory
to PATH before running install.sh and before starting your desktop session.
EOF
    exit 1
}

resolve_target_user
DEFAULT_USER_BIN="$TARGET_HOME/.local/bin"
BIN_DIR=${INSTALL_BIN_DIR:-$DEFAULT_USER_BIN}
INTERACTIVE=0
BIN_DIR_EXPLICIT=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --user)
            BIN_DIR="$DEFAULT_USER_BIN"
            BIN_DIR_EXPLICIT=1
            ;;
        --system)
            BIN_DIR="/usr/local/bin"
            BIN_DIR_EXPLICIT=1
            ;;
        --bin-dir)
            shift
            if [ "$#" -eq 0 ]; then
                echo "--bin-dir requires a path." >&2
                exit 1
            fi
            BIN_DIR="$1"
            BIN_DIR_EXPLICIT=1
            ;;
        -i|--interactive)
            INTERACTIVE=1
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_help >&2
            exit 1
            ;;
    esac
    shift
done

if [ "$INTERACTIVE" -eq 1 ] && [ "$BIN_DIR_EXPLICIT" -eq 0 ]; then
    choose_bin_dir
fi

ensure_xinput
ensure_xkb_switch

LISTENER_DST="$BIN_DIR/x11-layout-switch-release.sh"
AUTOSTART_DIR="$TARGET_HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/x11-layout-switch-release.desktop"
TMP_DESKTOP=$(mktemp)
trap 'rm -f "$TMP_DESKTOP"' EXIT INT TERM

install_dir "$BIN_DIR"
install_file "$BIN_DIR" -m 755 "$LISTENER_SRC" "$LISTENER_DST"

install_dir "$AUTOSTART_DIR"
sed "s|@LISTENER_PATH@|$LISTENER_DST|g" "$DESKTOP_TEMPLATE" > "$TMP_DESKTOP"
install -m 644 "$TMP_DESKTOP" "$AUTOSTART_FILE"

if [ "$(id -u)" -eq 0 ]; then
    if path_is_under_target_home "$BIN_DIR"; then
        chown "$TARGET_USER:$TARGET_USER" "$BIN_DIR" "$LISTENER_DST"
    fi
    chown "$TARGET_USER:$TARGET_USER" "$AUTOSTART_DIR" "$AUTOSTART_FILE"
fi

cat <<EOF
Installed:
  $LISTENER_DST
  $AUTOSTART_FILE

Recommended next steps:
  1. Disable built-in layout switching shortcuts in your desktop environment.
  2. Make sure you are on X11, not Wayland.
  3. Log out and log in again, or start the listener manually:
     $LISTENER_DST
EOF

if [ "$BIN_DIR" = "$DEFAULT_USER_BIN" ]; then
    cat <<EOF
  4. If "$DEFAULT_USER_BIN" is not yet in your PATH for the current shell, log in again before using:
     $LISTENER_DST
EOF
fi
