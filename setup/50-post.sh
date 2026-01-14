#!/usr/bin/env bash
# ==============================================================================
# IDA Dotfiles - Post-Installation
# ==============================================================================
# Runs after symlinks are created:
# - Validates installation
# - Sets permissions
# - Prints next steps and reminders

# When sourced from install script, lib.sh is already loaded
if [[ -z "${IDA_DOTFILES_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/lib.sh"
fi

# ==============================================================================
# Validation
# ==============================================================================

validate_config_symlinks() {
    log_info "Checking config symlinks..."
    
    local errors=0
    local checked=0
    
    for item in "$IDA_DOTFILES_DIR/config"/*; do
        if [[ -d "$item" ]]; then
            local name
            name=$(basename "$item")
            local target="$IDA_CONFIG_DIR/$name"
            
            ((checked++)) || true
            
            if [[ -L "$target" ]]; then
                log_success "  $name"
            elif [[ -e "$target" ]]; then
                log_warn "  $name (exists but not a symlink)"
                ((errors++)) || true
            else
                log_error "  $name (missing)"
                ((errors++)) || true
            fi
        fi
    done
    
    echo ""
    log_info "Checked $checked configs, $errors issues"
    return $errors
}

validate_bin_symlinks() {
    log_info "Checking bin symlinks..."
    
    local errors=0
    local checked=0
    
    # Check some key commands
    local key_commands=("ida-theme" "ida-create-webapp" "ida-app-launcher")
    
    for cmd in "${key_commands[@]}"; do
        ((checked++)) || true
        
        if [[ -L "$IDA_BIN_DIR/$cmd" ]]; then
            if command -v "$cmd" &>/dev/null; then
                log_success "  $cmd (in PATH)"
            else
                log_warn "  $cmd (linked but not in PATH)"
            fi
        elif [[ -e "$IDA_DOTFILES_DIR/scripts/$cmd" ]]; then
            log_warn "  $cmd (source exists but not linked)"
            ((errors++)) || true
        fi
    done
    
    echo ""
    return $errors
}

# ==============================================================================
# Permissions
# ==============================================================================

fix_script_permissions() {
    log_info "Ensuring scripts are executable..."
    
    if [[ "$IDA_DRY_RUN" == "true" ]]; then
        log_dry "Would chmod +x scripts in $IDA_DOTFILES_DIR/scripts/"
        return 0
    fi
    
    # Make all scripts in root of scripts/ executable
    for script in "$IDA_DOTFILES_DIR/scripts"/*; do
        if [[ -f "$script" && ! -x "$script" ]]; then
            # Check if it has a shebang
            if head -1 "$script" 2>/dev/null | grep -q '^#!'; then
                chmod +x "$script"
                log_info "  chmod +x $(basename "$script")"
            fi
        fi
    done
}

# ==============================================================================
# Next Steps
# ==============================================================================

print_next_steps() {
    echo ""
    echo -e "${BOLD}════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}  Next Steps${RESET}"
    echo -e "${BOLD}════════════════════════════════════════════════════════════════${RESET}"
    echo ""
    
    echo -e "${CYAN}1. Reload your shell or log out/in${RESET}"
    echo "   This ensures PATH and config changes take effect."
    echo ""
    
    echo -e "${CYAN}2. Check PATH (if scripts not found)${RESET}"
    echo "   Make sure ~/.local/bin is in your PATH:"
    echo "   - bash/zsh: export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo "   - fish: fish_add_path ~/.local/bin"
    echo ""
    
    echo -e "${CYAN}3. Launch Neovim to install plugins${RESET}"
    echo "   Run 'nvim' and wait for plugins to install automatically."
    echo ""
    
    echo -e "${CYAN}4. Restart Hyprland (if using)${RESET}"
    echo "   Press Super+Shift+E or run: hyprctl reload"
    echo ""
    
    echo -e "${CYAN}5. Dynamic theme setup (optional)${RESET}"
    echo "   The dynamic theme system uses fish universal variables."
    echo "   Run 'ida-theme' to set up colors based on wallpaper."
    echo ""
}

print_reminders() {
    echo -e "${BOLD}════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}  Reminders (TODO)${RESET}"
    echo -e "${BOLD}════════════════════════════════════════════════════════════════${RESET}"
    echo ""
    
    echo -e "${YELLOW}Config paths in waybar/hyprland:${RESET}"
    echo "   Some configs may reference scripts by absolute path."
    echo "   Update them to use commands from PATH instead:"
    echo "   - Old: ~/.dotfiles/ida/scripts/lyrics/lyrics-main.sh"
    echo "   - New: ida-lyrics-main  (after creating wrapper script)"
    echo ""
    
    echo -e "${YELLOW}Wrapper scripts needed:${RESET}"
    echo "   Create these in scripts/ to expose internal scripts:"
    echo "   - scripts/ida-lyrics-main -> calls scripts/lyrics/lyrics-main.sh"
    # (ida-lyrics-tooltip removed; ida-lyrics-main provides tooltip in JSON output)
    echo "   - scripts/ida-theme-watch -> calls scripts/theme/ida-theme-watch"
    echo ""
}

# ==============================================================================
# Backup Info
# ==============================================================================

print_backup_info() {
    if [[ -d "$IDA_BACKUP_DIR" ]]; then
        local backup_count
        backup_count=$(find "$IDA_BACKUP_DIR" -maxdepth 1 -type d | wc -l)
        ((backup_count--)) || true  # Subtract 1 for the parent dir itself
        
        if [[ $backup_count -gt 0 ]]; then
            echo ""
            log_info "Backups available: $backup_count session(s)"
            log_info "Location: $IDA_BACKUP_DIR"
            log_info "To restore: ./setup/restore"
        fi
    fi
}

# ==============================================================================
# Main
# ==============================================================================

post_install() {
    # Skip most checks in dry-run
    if [[ "$IDA_DRY_RUN" == "true" ]]; then
        log_dry "Would run post-installation checks"
        print_next_steps
        return 0
    fi
    
    fix_script_permissions
    echo ""
    
    validate_config_symlinks || true
    validate_bin_symlinks || true
    
    print_backup_info
    print_next_steps
    print_reminders
}

# ==============================================================================
# Run
# ==============================================================================

print_header "Post-Installation"
post_install
