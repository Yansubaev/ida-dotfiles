#!/usr/bin/env bash
# ==============================================================================
# IDA Dotfiles - Bin Symlinks
# ==============================================================================
# Creates symlinks for "public" scripts in ~/.local/bin
# Only files directly in scripts/ (not subdirectories) are considered public CLI tools

# When sourced from install script, lib.sh is already loaded
if [[ -z "${IDA_DOTFILES_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/lib.sh"
fi

# ==============================================================================
# Configuration
# ==============================================================================

# These are computed at runtime to pick up any changes to IDA_DOTFILES_DIR
get_scripts_source() {
    echo "$IDA_DOTFILES_DIR/scripts"
}

get_bin_target() {
    echo "$IDA_BIN_DIR"
}

# ==============================================================================
# Functions
# ==============================================================================

is_executable_script() {
    local file="$1"
    
    # Check if file is executable
    if [[ -x "$file" ]]; then
        return 0
    fi
    
    # Or has a shebang (script that might not be chmod +x yet)
    if head -1 "$file" 2>/dev/null | grep -q '^#!'; then
        return 0
    fi
    
    return 1
}

link_public_scripts() {
    local SCRIPTS_SOURCE
    local BIN_TARGET
    SCRIPTS_SOURCE=$(get_scripts_source)
    BIN_TARGET=$(get_bin_target)
    
    if [[ ! -d "$SCRIPTS_SOURCE" ]]; then
        log_error "Scripts source directory not found: $SCRIPTS_SOURCE"
        return 1
    fi
    
    log_info "Source: $SCRIPTS_SOURCE"
    log_info "Target: $BIN_TARGET"
    echo ""
    
    # Ensure target directory exists
    if [[ ! -d "$BIN_TARGET" ]]; then
        if [[ "$IDA_DRY_RUN" == "true" ]]; then
            log_dry "Would create: $BIN_TARGET"
        else
            mkdir -p "$BIN_TARGET"
            log_info "Created: $BIN_TARGET"
        fi
    fi
    
    # Counter for stats
    local linked=0
    local skipped=0
    
    # Process only files directly in scripts/ (not subdirectories)
    for item in "$SCRIPTS_SOURCE"/*; do
        # Skip directories
        if [[ -d "$item" ]]; then
            continue
        fi
        
        # Skip non-files
        if [[ ! -f "$item" ]]; then
            continue
        fi
        
        local name
        name=$(basename "$item")
        
        # Check if it's an executable script
        if is_executable_script "$item"; then
            create_symlink "$item" "$BIN_TARGET/$name"
            ((linked++)) || true
        else
            log_skip "Not executable: $name"
            ((skipped++)) || true
        fi
    done
    
    echo ""
    log_info "Linked: $linked scripts"
    [[ $skipped -gt 0 ]] && log_info "Skipped: $skipped non-executable files" || true
}

check_path() {
    local BIN_TARGET
    BIN_TARGET=$(get_bin_target)
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$BIN_TARGET:"* ]]; then
        echo ""
        log_warn "$BIN_TARGET is not in your PATH"
        log_info "Add this to your shell config (e.g., ~/.bashrc, ~/.config/fish/config.fish):"
        echo ""
        echo "  # For bash/zsh:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        echo "  # For fish:"
        echo "  fish_add_path ~/.local/bin"
        echo ""
    fi
}

# ==============================================================================
# Run
# ==============================================================================

print_header "Script Symlinks (~/.local/bin)"
link_public_scripts
check_path
