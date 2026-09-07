# Matrix Dotfiles

> A fully automated, modular, and reproducible Wayland desktop environment for Arch Linux, centered around the Hyprland compositor.

Matrix is not just a collection of configuration files; it is a complete bootstrap system that transforms a bare Arch Linux installation into a fully functional, highly polished desktop environment with a single command.

---

## ⚡ Features

*   **One-Command Bootstrap**: Completely automates the installation of packages, AUR helpers, dotfiles, system configurations, and systemd services.
*   **GNU Stow Architecture**: Configuration files are symlinked from the repository into your home directory, making live edits automatically trackable by git.
*   **Modular Package Management**: Packages are split into Core (must-have) and Optional (prompted during install) across both standard repositories and the AUR.
*   **Interactive Post-Install (TUI)**: A built-in terminal UI to selectively install hardware-specific drivers (like NVIDIA), peripherals (printers, fingerprint scanners), and system tunings.
*   **Wayland Native**: Built entirely around Wayland using Hyprland, Waybar, Walker, and SwayNC.
*   **PRIME Offload Support**: Hybrid graphics (Intel/NVIDIA) are supported out of the box. The desktop runs efficiently on the iGPU, with the discrete GPU spun up on-demand.

---

## 🚀 Installation

### Prerequisites
1.  A fresh **Arch Linux** installation.
2.  An active internet connection.
3.  A standard user account with `sudo` privileges (Do **not** run the bootstrap as root).

### Bootstrap

Run the following command in your terminal to begin the automated setup:

```bash
bash <(curl -s https://raw.githubusercontent.com/hafiz-own/matrix/main/bootstrap.sh)
```

**What this script does:**
1. Verifies your system environment.
2. Installs `git` and clones this repository to `~/.matrix`.
3. Compiles and installs the `paru` AUR helper.
4. Installs all core packages (and prompts for optional ones).
5. Deploys all configuration files using `stow`.
6. Places system-level configuration files into `/etc`.
7. Enables required systemd services (NetworkManager, Bluetooth, tuned, Pipewire).

---

## 🛠️ Post-Installation & Extras

Matrix includes an interactive installer for optional modules, hardware drivers, and peripheral setups. After the bootstrap script completes (and preferably after a reboot), run the extras installer:

```bash
~/.matrix/install-extras.sh
```

### Available Modules:
*   **System Tuning**: Applies custom `sysctl` rules and CPU governor settings.
*   **Memory Tuning**: Configures `zram-generator` for highly efficient compressed RAM swap.
*   **Hibernation**: Configures system hibernation to swap.
*   **Snapshots**: Sets up BTRFS system snapshots via `snapper` with pacman hooks and GRUB integration.
*   **Printers**: Installs CUPS and standard printer drivers.
*   **Peripherals & Biometrics**: Configures Broadcom Fingerprint readers (`fprintd`) and IR Face ID cameras (`facelock`).
*   **NVIDIA Setup**: Installs proprietary NVIDIA open kernel modules, utilities, Vulkan dependencies, and configures PRIME offload.
*   **ZSH Ecosystem**: Installs Oh-My-Zsh, Powerlevel10k, and useful plugins (`zoxide`, `fzf`, `eza`).
*   **Local LLM Setup**: Compiles `llama.cpp` with Vulkan acceleration for running local AI models.

---

## 📂 Repository Structure

```text
~/.matrix/
├── bootstrap.sh          # The one-liner entry script
├── install-extras.sh     # Interactive TUI for post-install modules
├── .gitignore            # Ignores runtime state and sensitive data
│
├── packages/             # Package Manifests
│   ├── pacman-core.txt     # Mandatory official packages
│   ├── aur-core.txt        # Mandatory AUR packages
│   ├── pacman-optional.txt # Optional official packages (browsers, editors)
│   └── aur-optional.txt    # Optional AUR packages
│
├── dotfiles/             # GNU Stow Packages
│   ├── hypr/               # Window manager configurations
│   ├── waybar/             # Status bar configurations
│   ├── kitty/              # Terminal emulator configurations
│   ├── nvim/               # Neovim configurations
│   ├── zshrc-home/         # Modular ZSH loader
│   ├── matrix/             # Core scripts (including extras installers)
│   └── ...                 # (20+ other managed configurations)
```

---

## ⚙️ How Configuration Works

Matrix uses **GNU Stow** to manage dotfiles.

Instead of copying files into `~/.config/`, Stow creates symbolic links pointing to `~/.matrix/dotfiles/`. 
For example, `~/.config/hypr/hyprland.conf` is actually a symlink to `~/.matrix/dotfiles/hypr/.config/hypr/hyprland.conf`.

### Making Changes

Because of the symlink architecture, you don't need to do anything special to update your configurations.
1. Edit your configuration files normally (e.g., `nvim ~/.config/hypr/hyprland.conf`).
2. Navigate to the repository: `cd ~/.matrix`.
3. Commit your changes: `git add . && git commit -m "Update hyprland config"`.
4. Push to your repository.

### Adding New Software

To add new software to your standard setup so it gets installed automatically on your next machine:
1. Open the relevant file in `~/.matrix/packages/` (e.g., `pacman-core.txt`).
2. Add the package name to the list.
3. Commit and push the changes.

---

## 🎮 Hardware: NVIDIA and Hybrid Graphics

Matrix assumes an integrated GPU (iGPU) as the baseline for maximum battery life and stability on Wayland.

If your machine has a discrete NVIDIA GPU:
1. Run `~/.matrix/install-extras.sh` and execute the **NVIDIA Setup** module.
2. The desktop will continue to run on the iGPU.
3. To run a specific application utilizing the NVIDIA GPU (PRIME Offload), prefix the command with `matrix-use-gpu`:

```bash
matrix-use-gpu blender
```
