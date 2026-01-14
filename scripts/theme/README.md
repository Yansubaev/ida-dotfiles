# IDA Theme System

Automatic theme generation from wallpaper with semantic color override support.

## Overview

The IDA theme system automatically generates color schemes for your desktop environment based on the current wallpaper. It uses [wallust](https://github.com/dharmx/wallust) to extract a color palette and applies it to:

- **Hyprland** - Window borders, decorations
- **Waybar** - Status bar colors
- **Wofi** - Application launcher
- **Fish Shell** - Syntax highlighting
- **Terminals** - Alacritty, Kitty, Ghostty
- **GTK/Qt** - Application theming
- **Mako** - Notification daemon

The system supports semantic color overrides, allowing you to manually set colors for specific purposes (urgent, warning, success, etc.) that remain consistent across wallpaper changes.

## Quick Start

### Apply Theme

Generate and apply theme from current wallpaper:

```bash
~/ida/scripts/theme/ida-theme
```

With verbose output for debugging:

```bash
~/ida/scripts/theme/ida-theme -v
```

### Auto-Watch

The theme automatically regenerates when you change wallpaper. The watcher runs on system startup via `config/hypr/autostart.conf`.

To start manually:

```bash
~/ida/scripts/theme/ida-theme-watch
```

## Architecture

```
scripts/theme/
├── ida-theme                 # Main entry point (generate + apply)
├── ida-theme-builder.py      # Python semantic color builder
├── ida-theme-utils.sh        # Bash utility functions
├── ida-theme-watch          # Wallpaper change monitor
└── templates/               # Semantic override templates (2nd pass)
    ├── fish-theme.fish.tmpl         # Fish with semantic urgent color
    ├── wofi-colors.css.tmpl         # Wofi with semantic colors
    ├── ida-semantic.conf.tmpl       # Hyprland semantic vars
    ├── ida-semantic.css.tmpl        # CSS semantic vars
    └── ida-semantic.fish.tmpl       # Fish semantic exports

config/wallust/
├── wallust.toml             # Wallust configuration
└── templates/ida/           # Base palette templates (1st pass)
    ├── semantic.json                # Semantic color defaults
    ├── theme.json                   # Base palette structure
    ├── hyprland-colors.conf         # Hyprland base colors
    ├── waybar-colors.css            # Waybar base colors
    ├── alacritty.toml               # Terminal colors
    ├── kitty.conf                   # Terminal colors
    ├── ghostty.conf                 # Terminal colors
    ├── gtk.css                      # GTK colors
    ├── qt.conf                      # Qt colors
    └── ida-git-colors.fish          # Git status colors

~/.cache/ida-theme/
├── current/                 # Currently active theme files
├── themes/<theme-id>/       # Theme history with per-theme overrides
└── current-theme           # Theme ID pointer
```

### Two-Pass Template System

The theme system uses two separate template sets that work in sequence:

**Pass 1: Wallust Templates** (`config/wallust/templates/ida/`)
- Run by `wallust` to extract base color palette from wallpaper
- Use wallust syntax: `{{color1}}`, `{{background}}`, etc.
- Generate base colors for all components
- Output: `~/.cache/ida-theme/current/*.{conf,css,toml,fish,json}`

**Pass 2: Semantic Templates** (`scripts/theme/templates/`)
- Run by `ida-theme-builder.py` to apply semantic overrides
- Use simple substitution: `{urgent}`, `{accent}`, etc.
- Override specific colors based on user preferences
- Output: Semantic override files that take precedence

This separation allows:
- Base palette changes automatically with wallpaper
- Semantic meanings (urgent, success, etc.) stay consistent
- User overrides persist across wallpaper changes

## Theme Generation Flow

1. **Extract wallpaper path** from `config/hypr/hyprpaper.conf`
2. **Run wallust** to generate base color palette
3. **Calculate theme ID** from wallpaper filename + hash
4. **Apply semantic overrides** (global and per-theme)
5. **Generate theme files** from templates
6. **Symlink to config directories** (`~/.config/*/`)
7. **Reload components** (Hyprland, Waybar)

## Semantic Color Overrides

Semantic colors allow you to define colors by purpose rather than by palette position. This ensures consistent meaning across different wallpapers.

### Available Semantic Colors

| Key | Purpose | Default Source |
|-----|---------|----------------|
| `IDA_URGENT` | Errors, critical states | `color1` (red) |
| `IDA_WARNING` | Warning states | `color3` (yellow) |
| `IDA_SUCCESS` | Success states | `color2` (green) |
| `IDA_INFO` | Info, neutral states | `color4` (blue) |
| `IDA_ACCENT` | Primary accent | `color4` (blue) |
| `IDA_ACCENT2` | Secondary accent | `color5` (magenta) |

### Global Overrides

Edit `~/.config/ida-theme/overrides.conf`:

```bash
# Global semantic color overrides (hex #RRGGBB format)

# Your overrides:
IDA_URGENT=#ff5f5f
IDA_WARNING=#f5c542
IDA_SUCCESS=#4ee48a
IDA_ACCENT=#7aa2f7
```

Apply changes:

```bash
~/ida/scripts/theme/ida-theme
```

### Per-Theme Overrides

Each theme has its own override file that takes precedence over global settings:

```bash
vim ~/.cache/ida-theme/themes/<theme-id>/overrides.conf
```

Override precedence: **Default < Global < Per-Theme**

## Customization

### Edit Wofi Styles

Wofi styles are separated from colors. Edit visual styling without affecting the color scheme:

```bash
vim ~/ida/config/wofi/wofi-base.css
```

Changes apply on next theme generation. The system automatically merges your styles with generated colors.

### Add New Templates

1. Create template in `scripts/theme/templates/`
2. Use `{variable}` syntax for substitution
3. Add generation logic to `ida-theme-builder.py`
4. Add symlink logic to `ida-theme` script

Example template:

```css
/* my-app.css.tmpl */
.error { color: {urgent}; }
.warning { color: {warning}; }
```

### Extend Wallust Templates

Base palette templates in `config/wallust/templates/ida/` use wallust's template syntax:

```
{{color1}}           - Palette color
{{background}}       - Background color
{{foreground}}       - Foreground color
{{color1 | strip}}   - Remove # prefix
{{background | lighten(0.1)}}  - Lighten by 10%
```

See [wallust documentation](https://github.com/dharmx/wallust) for full syntax.

## Troubleshooting

### Theme not applying

Check if wallust is installed:

```bash
which wallust
```

Verify wallpaper path in `config/hypr/hyprpaper.conf`:

```bash
grep -E "^(preload|path)" ~/ida/config/hypr/hyprpaper.conf
```

Run with verbose mode to see detailed errors:

```bash
~/ida/scripts/theme/ida-theme -v
```

### Invalid hex color error

Semantic override values must be in hex format: `#RRGGBB` or `RRGGBB`

Valid examples:
- `#ff5f5f`
- `ff5f5f`
- `#FF5F5F`

Invalid examples:
- `rgb(255, 95, 95)`
- `#fff` (too short)
- `notahex`

### Colors not visible in terminal

Fish shell picks up color changes on new shell sessions. Reload fish config:

```bash
source ~/.config/fish/ida-theme.fish
```

Or start a new terminal.

### Wofi styles not applying

Wofi doesn't support CSS `@import`. The system automatically merges `wofi-base.css` with generated colors into a single file.

Verify merge result:

```bash
head -20 ~/.cache/ida-theme/current/wofi-style.css
```

## Files Generated

Theme files are generated in `~/.cache/ida-theme/current/`:

| File | Purpose |
|------|---------|
| `theme.json` | Base palette (from wallust) |
| `semantic.json` | Semantic color defaults |
| `fish-theme.fish` | Fish shell syntax highlighting |
| `wofi-colors.css` | Wofi color definitions |
| `wofi-style.css` | Merged Wofi styles + colors |
| `ida-semantic.conf` | Hyprland semantic variables |
| `ida-semantic.css` | CSS semantic variables |
| `ida-semantic.fish` | Fish semantic exports |
| `hyprland-colors.conf` | Hyprland base palette |
| `waybar-colors.css` | Waybar color definitions |
| `ida-git-colors.fish` | Git status color wrapper |
| `alacritty.toml` | Alacritty terminal colors |
| `kitty.conf` | Kitty terminal colors |
| `ghostty.conf` | Ghostty terminal colors |
| `gtk.css` | GTK color variables |
| `qt.conf` | Qt color variables |
| `mako-colors.conf` | Mako notification colors |

## Dependencies

- [wallust](https://github.com/dharmx/wallust) - Color palette generation
- Python 3.6+ - Semantic color processing
- bash - Script orchestration
- inotify-tools - File watching (`inotifywait`)

## Development

### Code Structure

- **ida-theme** (bash) - Main orchestration script
- **ida-theme-builder.py** (Python) - Semantic color logic and validation
- **ida-theme-utils.sh** (bash) - Shared utility functions
- **templates/*.tmpl** - Simple string substitution templates

### Adding Semantic Colors

1. Add key to `config/wallust/templates/ida/semantic.json`
2. Add default in wallust template
3. Update `ida-theme-builder.py` to handle new key
4. Update template files to use new variable
5. Document in this README

### Testing

Test theme generation:

```bash
# Delete cache and regenerate
rm -rf ~/.cache/ida-theme/current
~/ida/scripts/theme/ida-theme -v
```

Test override validation:

```bash
echo "IDA_TEST=invalid" >> ~/.config/ida-theme/overrides.conf
~/ida/scripts/theme/ida-theme 2>&1 | grep -i error
```

## License

Part of the IDA dotfiles system.
