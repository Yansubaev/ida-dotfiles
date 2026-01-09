#!/usr/bin/env bash
# IDA Theme Utilities
# Common functions for theme management

set -euo pipefail

# Extract wallpaper path from hyprpaper.conf
extract_wallpaper_path() {
    # Try live config first, then repo config
    local hyprpaper_conf="$HOME/.config/hypr/hyprpaper.conf"
    if [[ ! -f "$hyprpaper_conf" ]]; then
        hyprpaper_conf="$REPO_ROOT/config/hypr/hyprpaper.conf"
    fi
    
    if [[ ! -f "$hyprpaper_conf" ]]; then
        echo "Error: hyprpaper.conf not found" >&2
        return 1
    fi
    
    # Extract from first matching preload= or path= line
    local wallpaper_rel
    wallpaper_rel="$(
        awk -F= '
            $1 ~ /^[[:space:]]*(preload|path)[[:space:]]*$/ {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2);
                print $2;
                exit
            }
        ' "$hyprpaper_conf"
    )"
    
    if [[ -z "$wallpaper_rel" ]]; then
        echo "Error: Failed to extract wallpaper path from: $hyprpaper_conf" >&2
        return 1
    fi
    
    # Expand ~ and make absolute
    local wallpaper="$wallpaper_rel"
    if [[ "$wallpaper" == ~* ]]; then
        wallpaper="$HOME${wallpaper:1}"
    fi
    
    if [[ ! "$wallpaper" = /* ]]; then
        # Treat relative as repo-relative
        wallpaper="$REPO_ROOT/$wallpaper"
    fi
    
    if [[ ! -f "$wallpaper" ]]; then
        echo "Error: Wallpaper file not found: $wallpaper" >&2
        return 1
    fi
    
    echo "$wallpaper"
}

# Calculate theme ID from wallpaper
calculate_theme_id() {
    local wallpaper="$1"
    local base
    local sha
    
    base="$(basename "$wallpaper")"
    sha="$(sha1sum "$wallpaper" | awk '{print $1}')"
    
    echo "${base%.*}-${sha:0:8}"
}

# Run wallust to generate base palette
run_wallust() {
    local wallpaper="$1"
    
    if ! command -v wallust >/dev/null 2>&1; then
        echo "Error: wallust not found in PATH" >&2
        return 1
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[Wallust] Generating palette from: $wallpaper"
    fi
    
    wallust run -q \
        -C "$REPO_ROOT/config/wallust/wallust.toml" \
        --templates-dir "$REPO_ROOT/config/wallust/templates" \
        "$wallpaper"
    
    # Verify output
    if [[ ! -f "$CURRENT_DIR/theme.json" ]]; then
        echo "Error: wallust did not generate theme.json" >&2
        return 1
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[Wallust] Generation complete"
    fi
}

# Initialize override files
init_override_files() {
    local theme_id="$1"
    local global_override="$HOME/.config/ida-theme/overrides.conf"
    local theme_dir="$CACHE_BASE/themes/$theme_id"
    local per_theme_override="$theme_dir/overrides.conf"
    
    # Create config directory
    mkdir -p "$HOME/.config/ida-theme"
    
    # Create global override template if missing
    if [[ ! -f "$global_override" ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[Init] Creating global override template"
        fi
        cat >"$global_override" <<'EOF'
# Global semantic color overrides (hex #RRGGBB format)
# Per-theme overrides: ~/.cache/ida-theme/themes/<theme_id>/overrides.conf
#
# Available keys:
#   IDA_URGENT    - Error/critical states
#   IDA_WARNING   - Warning states
#   IDA_SUCCESS   - Success states
#   IDA_INFO      - Info/neutral states
#   IDA_ACCENT    - Primary accent color
#   IDA_ACCENT2   - Secondary accent color
#
# Example:
#IDA_URGENT=#ff5f5f
#IDA_WARNING=#f5c542
#IDA_SUCCESS=#4ee48a
#IDA_INFO=#7aa2f7
#IDA_ACCENT=#7aa2f7
#IDA_ACCENT2=#bb9af7
EOF
    fi
    
    # Create theme directory and copy current theme if new
    if [[ ! -d "$theme_dir" ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[Init] Creating theme directory: $theme_id"
        fi
        mkdir -p "$theme_dir"
        cp -a "$CURRENT_DIR/." "$theme_dir/"
    fi
    
    # Create per-theme override if missing
    if [[ ! -f "$per_theme_override" ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[Init] Creating per-theme override file"
        fi
        cp "$global_override" "$per_theme_override"
    fi
}

# Reload running components
reload_components() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[Reload] Reloading components..."
    fi
    
    # Reload Hyprland config
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[Reload] Hyprland reloaded"
        fi
    fi
    
    # Wait a moment for Hyprland to process config
    sleep 0.2
    
    # Restart Waybar if running
    if pgrep -x waybar >/dev/null 2>&1; then
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[Reload] Restarting Waybar"
        fi
        pkill -x waybar || true
        sleep 0.3
        nohup waybar >/dev/null 2>&1 &
        disown
    fi
    
    # Note: Wofi is spawned on-demand, no restart needed
    # Note: Fish will pick up changes on next shell start or source
}
