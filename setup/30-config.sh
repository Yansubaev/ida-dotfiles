#!/usr/bin/env bash
# ==============================================================================
# IDA Dotfiles - Config Symlinks
# ==============================================================================
# Creates symlinks for all config directories: ~/.config/<name> -> repo/config/<name>
# Special handling for fish (skips fish_variables)

# When sourced from install script, lib.sh is already loaded
if [[ -z "${IDA_DOTFILES_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/lib.sh"
fi

# ==============================================================================
# Configuration
# ==============================================================================

# These are computed at runtime to pick up any changes to IDA_DOTFILES_DIR
get_config_source() {
    echo "$IDA_DOTFILES_DIR/config"
}

get_config_target() {
    echo "$IDA_CONFIG_DIR"
}

# Files/dirs to skip (not symlink)
SKIP_FILES=(
    "fish/fish_variables"  # Fish manages this file dynamically
)

# ==============================================================================
# Functions
# ==============================================================================

should_skip() {
    local relative_path="$1"
    for skip in "${SKIP_FILES[@]}"; do
        if [[ "$relative_path" == "$skip" ]]; then
            return 0
        fi
    done
    return 1
}

# Symlink a single config directory
link_config_dir() {
    local name="$1"
    local CONFIG_SOURCE CONFIG_TARGET
    CONFIG_SOURCE=$(get_config_source)
    CONFIG_TARGET=$(get_config_target)
    
    local source="$CONFIG_SOURCE/$name"
    local target="$CONFIG_TARGET/$name"
    
    if should_skip "$name"; then
        log_skip "Skipping (in skip list): $name"
        return 0
    fi
    
    create_symlink "$source" "$target"
}

# Special handling for fish: symlink directory but handle fish_variables separately
link_fish_config() {
    local CONFIG_SOURCE CONFIG_TARGET
    CONFIG_SOURCE=$(get_config_source)
    CONFIG_TARGET=$(get_config_target)
    
    local source="$CONFIG_SOURCE/fish"
    local target="$CONFIG_TARGET/fish"
    
    # If target doesn't exist or is already a symlink, we can proceed with directory symlink
    # But we need to handle the case where fish_variables should remain local
    
    if [[ -L "$target" ]] && is_correct_symlink "$target" "$source"; then
        log_skip "Already linked: $target"
        return 0
    fi
    
    # If fish config exists and is a directory (not symlink)
    if [[ -d "$target" && ! -L "$target" ]]; then
        # Save fish_variables if it exists
        local fish_vars_backup=""
        if [[ -f "$target/fish_variables" ]]; then
            fish_vars_backup=$(mktemp)
            cp "$target/fish_variables" "$fish_vars_backup"
            log_info "Preserved local fish_variables"
        fi
        
        # Create symlink (will backup/remove existing based on mode)
        create_symlink "$source" "$target"
        
        # Restore fish_variables as a local file (not symlink)
        if [[ -n "$fish_vars_backup" && -f "$fish_vars_backup" ]]; then
            if [[ "$IDA_DRY_RUN" == "true" ]]; then
                log_dry "Would restore fish_variables to $target/"
            else
                # Remove the symlinked fish_variables if it exists
                if [[ -L "$target/fish_variables" ]]; then
                    rm "$target/fish_variables"
                fi
                cp "$fish_vars_backup" "$target/fish_variables"
                log_info "Restored local fish_variables"
            fi
            rm "$fish_vars_backup"
        fi
    else
        # Simple case: just create the symlink
        create_symlink "$source" "$target"
    fi
}

# ==============================================================================
# Main
# ==============================================================================

link_all_configs() {
    local CONFIG_SOURCE CONFIG_TARGET
    CONFIG_SOURCE=$(get_config_source)
    CONFIG_TARGET=$(get_config_target)
    
    if [[ ! -d "$CONFIG_SOURCE" ]]; then
        log_error "Config source directory not found: $CONFIG_SOURCE"
        return 1
    fi
    
    log_info "Source: $CONFIG_SOURCE"
    log_info "Target: $CONFIG_TARGET"
    echo ""
    
    # Ensure target directory exists
    if [[ ! -d "$CONFIG_TARGET" ]]; then
        if [[ "$IDA_DRY_RUN" == "true" ]]; then
            log_dry "Would create: $CONFIG_TARGET"
        else
            mkdir -p "$CONFIG_TARGET"
        fi
    fi
    
    # Process each config directory
    for item in "$CONFIG_SOURCE"/*; do
        if [[ -d "$item" ]]; then
            local name
            name=$(basename "$item")
            
            # Special handling for fish
            if [[ "$name" == "fish" ]]; then
                link_fish_config
            else
                link_config_dir "$name"
            fi
        elif [[ -f "$item" ]]; then
            # Handle individual config files (if any)
            local name
            name=$(basename "$item")
            create_symlink "$item" "$CONFIG_TARGET/$name"
        fi
    done
}

# ==============================================================================
# Run
# ==============================================================================

print_header "Config Symlinks"
link_all_configs
