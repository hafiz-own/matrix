# Matrix

A reproducible Hyprland desktop for Arch Linux. One command turns a fresh Arch install into the full setup: packages, dotfiles, session services and helper scripts.

Two rules guide every choice here: stay light on CPU, RAM and battery without giving up quality, and keep the interface minimal.

## Contents

- [What you get](#what-you-get)
- [Requirements](#requirements)
- [Installation](#installation)
- [First login](#first-login)
- [Optional modules](#optional-modules)
- [Keybindings](#keybindings)
- [How the session is put together](#how-the-session-is-put-together)
- [Hybrid graphics (Intel + NVIDIA)](#hybrid-graphics-intel--nvidia)
- [Idle, lock and power](#idle-lock-and-power)
- [Repository layout](#repository-layout)
- [Day-to-day use](#day-to-day-use)
- [Troubleshooting](#troubleshooting)

## What you get

| Area | Tools |
|---|---|
| Compositor | Hyprland (Lua configuration), with switchable variants for animations, decorations, borders and monitor presets |
| Bar | Waybar, theme `matrix-minimal` (a `starter` theme is included) |
| Launcher | Walker with the Elephant backend: apps, clipboard, calculator, symbols, todo, web search, reminders |
| Notifications | SwayNC with a compact media player |
| Lock and idle | Hyprlock (password and fingerprint), Hypridle |
| Terminal and shell | Kitty, Zsh with Oh-My-Zsh and Powerlevel10k |
| Media | mpv with uosc and thumbfast, MPD with ncmpcpp, synced lyrics |
| Files | Yazi |
| Editor | Neovim (LazyVim) |
| Dictation | Voxtype (local Whisper speech-to-text) |
| Session services | systemd user units under `hyprland-session.target` |

## Requirements

- A fresh Arch Linux installation with a working network connection.
- A regular user account with `sudo` rights. Do not run the bootstrap as root.

## Installation

### Recommended: download, read, run

```bash
curl -fsSL -o bootstrap.sh https://raw.githubusercontent.com/hafiz-own/matrix/main/bootstrap.sh
less bootstrap.sh
bash bootstrap.sh
```

### One-liner

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hafiz-own/matrix/main/bootstrap.sh)
```

### What the bootstrap does

| Stage | Action |
|---|---|
| 0 | Checks that you are not root, that the system is Arch Linux and that the internet is reachable |
| 1 | Upgrades the system (`pacman -Syu`) and installs `git` and `stow` |
| 2 | Clones this repository to `~/.matrix` |
| 3 | Builds and installs the `paru` AUR helper |
| 4 | Installs the core packages from `packages/pacman-core.txt` and `packages/aur-core.txt`, then asks whether to install the optional lists |
| 5 | Links every package in `dotfiles/` into your home directory with GNU Stow |
| 6 | Enables NetworkManager, Bluetooth, tuned, PipeWire and the session's user units |

Reboot when it finishes. The full output is saved to `~/.matrix-bootstrap.log`.

AUR packages are built without stopping for review (`--noconfirm`). If you want to read each PKGBUILD first, install the packages in `packages/aur-core.txt` yourself with `paru -S` before running the bootstrap; it skips anything already installed.

### Manual installation

If you prefer to run each step yourself:

```bash
sudo pacman -S --needed git stow base-devel
git clone https://github.com/hafiz-own/matrix ~/.matrix
cd ~/.matrix

# AUR helper
git clone https://aur.archlinux.org/paru.git /tmp/paru
(cd /tmp/paru && makepkg -si)

# Packages (comments and blank lines are skipped)
sudo pacman -S --needed $(grep -v '^\s*#' packages/pacman-core.txt | grep -v '^\s*$')
paru -S --needed $(grep -v '^\s*#' packages/aur-core.txt | grep -v '^\s*$')

# Dotfiles (the systemd package must not be folded, see the note below)
cd dotfiles
for pkg in */; do
    pkg=${pkg%/}
    if [ "$pkg" = systemd ]; then
        stow --no-folding --target="$HOME" "$pkg"
    else
        stow --target="$HOME" "$pkg"
    fi
done

# Session services
systemctl --user daemon-reload
systemctl --user enable hypridle swaync waybar elephant walker low-battery
```

The `systemd` package is stowed with `--no-folding` because systemd ignores drop-in folders that are symlinks.

If Stow reports a conflict, a file already exists where a link should go. Move that file aside, or adopt it into the repository with `stow --adopt <package>` and review the result with `git diff`.

## First login

Log in on a TTY and start Hyprland with:

```bash
hypr
```

`hypr` is a Zsh alias for `~/.config/matrix/scripts/matrix-start-hyprland`. On laptops with both an Intel and an NVIDIA GPU it starts Hyprland on the Intel GPU only, so the NVIDIA card can power down when nothing uses it. On other machines it runs `start-hyprland` unchanged, which also works directly.

After logging in:

1. Press `SUPER + F1` to see every keybinding.
2. Set up your monitors with `nwg-displays`. It writes `~/.config/hypr/monitors.lua`.
3. Pick GTK, icon and cursor themes with `nwg-look`. Hyprland reads the cursor theme from the same settings at the next login.

## Optional modules

Hardware drivers and extra setups are kept out of the core install. Run the interactive installer after the first reboot and tick the modules you want:

```bash
~/.matrix/install-extras.sh
```

| Module | What it sets up |
|---|---|
| Pacman | Faster pacman and makepkg settings |
| Shell | Oh-My-Zsh, Powerlevel10k and plugins |
| System tuning | Low-level system and performance settings |
| Memory | Compressed RAM swap with zram |
| Hibernation | Hibernation to swap, including the GRUB resume entry |
| Snapshots | Btrfs snapshots with snapper |
| Voxtype | Local voice dictation |
| Fingerprint | Broadcom ControlVault 3 reader with `fprintd` |
| Face ID | IR camera unlock with `facelock` |
| Printers | CUPS with driverless (IPP) printing |
| Reminders | Reminder app; add reminders from Walker with the `+` prefix |
| mpv | uosc, thumbfast and hardware decoding |
| Yazi | Yazi plugins |
| Peripherals | Fonts and hardware extras |
| llama.cpp | Local LLMs with Vulkan acceleration |
| NVIDIA | `nvidia-open`, PRIME offload and Wayland setup |

## Keybindings

`SUPER` is the Windows key. Press `SUPER + F1` for the full, searchable list.

| Keys | Action |
|---|---|
| `SUPER + RETURN` | Terminal |
| `SUPER + CTRL + RETURN` | Application launcher |
| `SUPER + B` | Browser |
| `SUPER + E` | File manager |
| `SUPER + V` | Clipboard history |
| `SUPER + D` | Dictionary lookup |
| `SUPER + Q` | Close window |
| `SUPER + F` | Fullscreen |
| `SUPER + M` | Maximize |
| `SUPER + T` | Toggle floating |
| `SUPER + 1` to `0` | Go to workspace 1 to 10 |
| `SUPER + SHIFT + 1` to `0` | Move window to workspace 1 to 10 |
| `SUPER + S` | Scratchpad |
| `SUPER + CTRL + L` | Lock screen |
| `PRINT` | Screenshot, text capture (OCR) or screen recording |
| `SUPER + SHIFT + B` | Reload the bar |
| `SUPER + ALT + G` | Game mode (no animations, blur or gaps) |
| `SUPER + CTRL + X` | Toggle dictation |
| Media keys, `SUPER + F9` to `F12` | Play/pause, previous, next, stop. MPD first, then any other player |
| `SUPER + F8` | Toggle synced lyrics |
| `SUPER + CTRL + R` | Reload Hyprland |
| `SUPER + F1` | Keybinding cheat sheet |

## How the session is put together

Long-running services are systemd user units rather than processes started from the Hyprland config. They start and stop with the session, restart if they crash and log to the journal.

| Unit | Purpose |
|---|---|
| `hyprland-session.target` | Started by Hyprland after it exports the session environment; pulls in `graphical-session.target` |
| `waybar.service` | Status bar, started with the selected theme |
| `swaync.service` | Notifications |
| `hypridle.service` | Idle timers |
| `elephant.service`, `walker.service` | Launcher backend and launcher |
| `voxtype.service` | Dictation (installed by the Voxtype module) |
| `low-battery.service` | Warnings at 20% and 15%, driven by UPower events instead of polling |

```bash
systemctl --user status hyprland-session.target
systemctl --user --failed
journalctl --user -u waybar -b
```

## Hybrid graphics (Intel + NVIDIA)

The desktop runs on the Intel GPU. The NVIDIA GPU stays powered down until a program asks for it.

Run one program on the NVIDIA GPU:

```bash
use-gpu blender
```

For a Steam game, set the launch option to:

```text
~/.config/matrix/scripts/matrix-use-gpu %command%
```

The kernel has to be allowed to suspend the NVIDIA card. Run this once after the NVIDIA module:

```bash
sudo bash ~/.config/matrix/scripts/fix-nvidia-pm.sh
```

Check that the card sleeps when idle and wakes on demand:

```bash
~/.config/matrix/scripts/matrix-gpu-check
```

## Idle, lock and power

| Time idle | What happens |
|---|---|
| 2:00 | Screen dims to 10% |
| 2:30 | Matrix screensaver on every screen |
| 6:30 | Lock screen; music pauses |
| 8:00 | Screens turn off |
| 17:30 | Hibernate, on battery only |
| 32:30 | Suspend, on AC only |

Opening the screensaver counts as activity, so the later steps are counted from 2:30. A fullscreen video or game keeps the screen awake. To keep it awake by hand, click the coffee cup in the bar.

If the screen does not lock or sleep when you expect it to, run:

```bash
~/.config/matrix/scripts/matrix-idle-why
```

It lists every program and setting that is keeping the system awake.

## Repository layout

```text
~/.matrix/
├── bootstrap.sh             One-command installer
├── install-extras.sh        Optional modules (interactive)
├── packages/
│   ├── pacman-core.txt      Official packages, always installed
│   ├── aur-core.txt         AUR packages, always installed
│   ├── pacman-optional.txt  Official packages, offered during install
│   └── aur-optional.txt     AUR packages, offered during install
└── dotfiles/                One Stow package per program
    ├── hypr/                Hyprland, Hyprlock, Hypridle and their scripts
    ├── waybar/              Bar, themes and launch scripts
    ├── walker/              Launcher configuration and theme
    ├── swaync/              Notification center
    ├── systemd/             Session user units (stow with --no-folding)
    ├── matrix/              Helper scripts, settings and module installers
    ├── kitty/ mpv/ mpd/ ncmpcpp/ nvim/ yazi/ btop/
    ├── zshrc/ zshrc-home/   Shell configuration
    └── ...                  Fonts, GTK and Qt themes, audio, displays
```

Each folder in `dotfiles/` mirrors your home directory. For example, `dotfiles/hypr/.config/hypr/hyprland.lua` is linked to `~/.config/hypr/hyprland.lua`.

## Day-to-day use

### Changing a setting

Every file in `~/.config` that Matrix manages is a link into `~/.matrix`, so editing the file in place edits the repository.

```bash
nvim ~/.config/hypr/conf/keybindings/default.lua
cd ~/.matrix
git status
git diff
git add -A
git commit -m "Describe the change"
git push
```

Hyprland reloads its configuration when a file is saved. Reload it by hand with `SUPER + CTRL + R`.

### Adding a package to the install

Put the package name on its own line in the matching file under `packages/` and commit. Lines starting with `#` are comments.

### Trying something risky

Work on a branch so `main` stays the version you know works:

```bash
cd ~/.matrix
git switch -c experiment
# edit, test, commit
git switch main                  # back to the known-good version
git merge --ff-only experiment   # keep the changes once you are happy
```

Your live configuration always matches the branch that is checked out, because `~/.config` links into this folder.

### Updating another machine

```bash
cd ~/.matrix
git pull
cd dotfiles
stow --restow --target="$HOME" $(find . -mindepth 1 -maxdepth 1 -type d ! -name systemd -printf '%f ')
stow --restow --no-folding --target="$HOME" systemd
systemctl --user daemon-reload
```

## Troubleshooting

| Problem | What to run |
|---|---|
| Hyprland config error | `hyprctl configerrors` |
| Bar missing | `systemctl --user status waybar`, then `SUPER + SHIFT + B` |
| Screen never locks or sleeps | `~/.config/matrix/scripts/matrix-idle-why` |
| NVIDIA GPU stays on | `~/.config/matrix/scripts/matrix-gpu-check` |
| A service keeps failing | `systemctl --user --failed`, then `journalctl --user -u <name> -b` |
| Stow conflict | Move the existing file aside, or `stow --adopt <package>` and review with `git diff` |
| Fingerprint unlock unreliable on the lock screen | `sudo bash ~/.config/hypr/scripts/fix-fingerprint.sh` |
