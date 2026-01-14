# IDA Dotfiles

Personal dotfiles for Arch Linux with Hyprland. Minimalist, themed, and ready to use.

## Quick Install

One-liner to clone and install:

```bash
bash <(curl -s https://raw.githubusercontent.com/Yansubaev/ida-dotfiles/main/setup/bootstrap.sh)
```

Or manually:

```bash
git clone https://github.com/Yansubaev/ida-dotfiles.git ~/.dotfiles/ida
cd ~/.dotfiles/ida
./setup/install
```

## What's Included

### Window Manager & Desktop
- **Hyprland** — Wayland compositor
- **Waybar** — Status bar
- **Wofi** — Application launcher
- **Hyprpaper** — Wallpaper manager

### Terminals
- **Alacritty** (default)
- **Kitty**
- **Ghostty**

### Shell & Editor
- **Fish** — Shell with custom config
- **Neovim** — Editor (LazyVim-based config)

### Theming
- **Wallust** — Color extraction from wallpapers
- Dynamic theme system (`ida-theme`) that generates colors from your wallpaper

### Other
- **Dunst** / **Mako** — Notifications
- **Dolphin** — File manager

## Installation Options

```bash
# Preview changes without modifying anything
./setup/install --dry-run

# Full install (backup existing configs)
./setup/install

# Skip package installation
./setup/install --no-packages

# Safe mode: only install if config doesn't exist
./setup/install --safe

# Force mode: overwrite without backup
./setup/install --force
```

## After Installation

1. **Log out and log back in** (or restart your session)

2. **Ensure `~/.local/bin` is in your PATH**
   ```fish
   # Fish
   fish_add_path ~/.local/bin
   ```
   ```bash
   # Bash/Zsh
   export PATH="$HOME/.local/bin:$PATH"
   ```

3. **Launch Neovim** to install plugins automatically
   ```bash
   nvim
   ```

4. **Set up dynamic theming** (optional)
   ```bash
   ida-theme
   ```

## Structure

```
~/.dotfiles/ida/
├── config/          # App configs (symlinked to ~/.config/)
│   ├── hypr/        # Hyprland
│   ├── waybar/      # Status bar
│   ├── wofi/        # Launcher
│   ├── fish/        # Shell
│   ├── nvim/        # Editor
│   ├── alacritty/   # Terminal
│   ├── kitty/       # Terminal
│   ├── ghostty/     # Terminal
│   └── wallust/     # Theming
├── scripts/         # CLI tools (symlinked to ~/.local/bin/)
├── packages/        # Package lists for installation
├── setup/           # Installation scripts
└── themes/          # Theme files
```

## Backup & Restore

Existing configs are backed up to `~/.config/.ida-backups/`

```bash
# List available backups
./setup/restore --list

# Restore from backup
./setup/restore
```

## Customization

- Edit package lists in `packages/arch-pacman.txt` and `packages/arch-aur.txt`
- Hyprland keybindings: `config/hypr/keybindings.conf`
- Waybar modules: `config/waybar/config.jsonc`

## Requirements

- Arch Linux (or Arch-based: CachyOS, EndeavourOS, Manjaro, etc.)
- Git

## License

MIT
