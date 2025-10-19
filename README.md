# uparch

A polished interactive update script for Arch Linux that handles system updates, Flatpak apps, and npm packages while automatically creating a Timeshift snapshot first.

No more manually running multiple update commands or forgetting to snapshot before updates. Just run `uparch` and it handles everything with a nice TUI.

## Quick Start

```bash
# Download the script or clone it using Jujutsu VCS
jj git clone https://github.com/AliQ80/uparch.git
cd uparch
```

Remove *jj* if you're using regular git

Install it system-wide using [binmy](https://github.com/AliQ80/binmy) tool:

```bash
binmy uparch.sh
uparch
```

Or install it system-wide manually:

```bash
sudo cp uparch.sh /usr/local/bin/uparch
uparch

# Make it executable
chmod +x uparch.sh

# Run it
./uparch.sh
```

## What It Does

1. **Creates a Timeshift snapshot** - You'll be prompted for a description. If you leave it blank, it uses a timestamped default.

2. **Updates system packages with paru** - Runs `paru -Syu` to update official repos + AUR packages.

3. **Updates Flatpak apps** - Automatically updates all installed Flatpak packages (skips if none installed).

4. **Updates npm global packages** - Runs `npm update -g` for your global npm packages (skips if none installed).

Each step shows clear progress indicators and emojis so you know what's happening. At the end, you get a summary of what succeeded, failed, or was skipped.

## Auto-Confirm Mode

When you run the script, it'll ask if you want to run all updates automatically without confirmation prompts for each step.

- **Yes** - Script runs all steps unattended (you only provide the snapshot description)
- **No** - You'll be asked to confirm before each update step

The Timeshift snapshot always happens first (for safety), but you can still customize its description.

## Requirements

You need these installed:

- **[gum](https://github.com/charmbracelet/gum)** - For the interactive TUI elements
- **[paru](https://github.com/Morganamilo/paru)** - AUR helper (or modify script to use yay/pacman)
- **[timeshift](https://github.com/linuxmint/timeshift)** - For system snapshots
- **npm** - If you use global npm packages
- **flatpak** - If you use Flatpak apps

Install the essentials:

```bash
# Core tools
paru -S gum timeshift

# Optional (if you use them)
paru -S flatpak npm
```

The script will check for missing dependencies and let you know what's needed before running.

## Error Handling

If any step fails, the script asks if you want to continue with the remaining steps or abort. Useful if, say, paru fails but you still want to update Flatpak packages.

## Customization

Want to modify which package managers it uses? The script is straightforward bash - just edit the functions for each step. For example, to use `yay` instead of `paru`, change line 185:

```bash
# Change this
if paru -Syu; then

# To this
if yay -Syu; then
```

## Why This Exists

Updating Arch can involve multiple commands across different package managers. I got tired of:

- Forgetting to create snapshots before updates
- Manually running paru, flatpak update, and npm update -g separately
- Not having a clear summary of what actually got updated

So I built this. It's opinionated (uses paru, gum for UI, etc.) but easily tweakable.
