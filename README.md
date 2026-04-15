# X11 Layout Switch Release

[English](README.md) | [Русский](README_RU.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/gugglegum/x11-layout-switch-release/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/gugglegum/x11-layout-switch-release/actions/workflows/ci.yml)

Scripts for Linux/X11 that switch the keyboard layout not when `Alt+Shift` or `Ctrl+Shift` is pressed, but when the keys are released.

## What This Is

In a typical XKB setup, layout switching by `Alt+Shift` or `Ctrl+Shift` happens on key press. This becomes inconvenient when the same modifiers are also part of other shortcuts, for example:

- `Alt+Shift+Tab`
- `Ctrl+Shift+Arrow`
- any custom hotkeys where `Alt+Shift` or `Ctrl+Shift` is only part of a larger combination

This project solves that problem in a simple way:

1. `xinput test` listens to keyboard events on X11.
2. The script recognizes a short press-and-release sequence for `Alt+Shift` or `Ctrl+Shift`.
3. After the second key is released, it runs `xkb-switch -n`.

As a result, layout switching happens on key release rather than on key press.

## Where This Applies

This implementation is intended for X11 systems and desktop environments where layout state mostly lives in XKB without a separate input-source manager layered on top. Because of that, it can potentially work on a fairly wide range of systems:

- Linux Mint
- LMDE
- Ubuntu
- Debian
- Fedora
- Arch Linux
- Manjaro
- openSUSE
- Linux Mint with MATE or Xfce
- MATE, Xfce, LXDE, Openbox, and other X11 environments
- older Cinnamon versions where direct XKB switching does not drift away from the panel state

In practice, the project is tied less to a specific distribution name and more to a combination of:

- an X11 session
- XKB as the main layout-switching mechanism
- a desktop environment that does not maintain a separate input-source state on top of XKB

## Where This Does Not Fit

- Wayland: `xinput` and direct XKB manipulation are not a reliable model there
- modern Cinnamon 6.6+:
  Cinnamon now maintains its own input-source state, and direct switching through `xkb-switch` can drift away from the panel indicator and Cinnamon's internal state

If you are on Linux Mint 22.3+ / Cinnamon 6.6+, it is better to use the Cinnamon-specific solution instead:

<https://github.com/gugglegum/cinnamon-layout-switch-release>

## Dependencies

The following must be available on the system:

- `bash`
- `xinput`
- `xkb-switch`

`xkb-switch` is not bundled in this repository and must be installed separately.

## Installing `xkb-switch` First

Upstream project:

<https://github.com/grwlf/xkb-switch>

A typical installation flow on Debian/Ubuntu/Linux Mint:

```bash
sudo apt install cmake make g++ libxkbfile-dev
git clone https://github.com/grwlf/xkb-switch.git
cd xkb-switch
mkdir build
cd build
cmake ..
make
sudo make install
sudo ldconfig
```

After that, confirm that the tool is available:

```bash
xkb-switch --help
```

If `xkb-switch` is installed into a non-standard directory, add that directory to `PATH` so that the command is available both in an interactive shell and in desktop autostart.

## Installing This Solution

Below is the main installation flow.

### Step 1. Install `xkb-switch`

First install `xkb-switch` using the instructions above and confirm that the command is available:

```bash
xkb-switch --help
```

### Step 2. Run the installer

By default, installation is per-user and does not require root:

```bash
./install.sh
```

With the default install target, this creates:

- the listener at `~/.local/bin/x11-layout-switch-release.sh`
- the config file at `~/.config/x11-layout-switch-release.conf`
- the autostart entry at `~/.config/autostart/x11-layout-switch-release.desktop`

If the config file already exists, the installer preserves it.

Additional options:

```bash
./install.sh --system
./install.sh --bin-dir /some/path
./install.sh --interactive
```

`--system` installs the listener into `/usr/local/bin` and will usually require `sudo`.
`--bin-dir` normally does not require root if the chosen path is inside the user's home directory. If you choose a path outside the home directory, root privileges may be required.

### Step 3. Disable your desktop environment's built-in layout switching

If your desktop environment already switches layouts on `Alt+Shift` or `Ctrl+Shift`, that built-in behavior should be disabled. Otherwise you will get double switching:

- one switch from the desktop environment
- one switch from this listener

How to disable the built-in shortcut depends on the desktop environment you use.

### Step 4. Log out and back in, or start the listener manually

After installation you can simply log out and back in. The autostart entry will launch the listener automatically.

If you do not want to wait, start it manually:

```bash
~/.local/bin/x11-layout-switch-release.sh
```

If you installed using `--system` or `--bin-dir`, use the listener path printed by `install.sh`.

### Step 5. If automatic keyboard detection fails, edit the config

The file `~/.config/x11-layout-switch-release.conf` is created automatically during installation. The listener reads it both during manual startup and when started from autostart.

If layout switching does not work, first find the correct keyboard ID:

```bash
xinput list --short
```

Then edit the config and set, for example:

```bash
KB_LAYOUT_SWITCH_KEYBOARD_ID=8
```

After editing the config, restart the listener or simply log out and back in.

## What `install.sh` Does

- checks that `xkb-switch` is available
- checks that `xinput` is available
- installs the listener
- creates the config file if it does not exist yet
- creates the autostart `.desktop` file

If `xkb-switch` is missing, installation stops and prints a short build/install hint.

## Keyboard Configuration

By default, the listener tries to find the keyboard in this order:

1. `KB_LAYOUT_SWITCH_KEYBOARD_ID`, if explicitly set
2. `AT Translated Set 2 keyboard`
3. fallback to `Virtual core keyboard`

In virtual machines, the keyboard ID is often a small number such as `8`, but this is only an example. On another system the ID can be different.

You can list devices like this:

```bash
xinput list --short
```

To query the ID of a specific keyboard:

```bash
xinput list --id-only "AT Translated Set 2 keyboard"
```

For permanent configuration, put the value into:

```text
~/.config/x11-layout-switch-release.conf
```

For example:

```bash
KB_LAYOUT_SWITCH_KEYBOARD_ID=8
```

If the keyboard name is different, you can override the name instead of the ID:

```bash
KB_LAYOUT_SWITCH_KEYBOARD_NAME='My USB Keyboard'
```

The listener reads this file during autostart as well, so there is no need to edit the `.desktop` file by hand.

Environment variables can still be used for temporary manual testing, but for permanent setup it is better to edit the config file itself.

## How It Works

The script reacts to four short sequences for `Alt+Shift` and four for `Ctrl+Shift`:

- `Alt_Down Shift_Down Alt_Up`
- `Alt_Down Shift_Down Shift_Up`
- `Shift_Down Alt_Down Alt_Up`
- `Shift_Down Alt_Down Shift_Up`
- `Ctrl_Down Shift_Down Ctrl_Up`
- `Ctrl_Down Shift_Down Shift_Up`
- `Shift_Down Ctrl_Down Ctrl_Up`
- `Shift_Down Ctrl_Down Shift_Up`

As soon as one of these sequences is recognized, the script runs:

```bash
xkb-switch -n
```

If you have more than two layouts configured, it will cycle to the next layout in the sequence.

## Uninstall

```bash
./uninstall.sh
```

The same path options are supported for removal:

```bash
./uninstall.sh --system
./uninstall.sh --bin-dir /some/path
./uninstall.sh --purge-config
```

By default, `uninstall.sh` removes the listener and the autostart entry, but leaves `~/.config/x11-layout-switch-release.conf` in place. This is intentional so user settings are not lost. If you also want to remove the config, use `--purge-config`.

## Limitations

- the project is intended specifically for X11
- it does not attempt to integrate with Wayland compositors
- on modern Cinnamon 6.6+ it is better to use the Cinnamon-specific backend
- the listener uses `xkb-switch -n`, so it cycles layouts rather than hard-switching only between two languages

## License

MIT, see [LICENSE](LICENSE).
