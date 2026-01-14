#!/usr/bin/env bash
# ==============================================================================
# IDA Dotfiles - Repository Setup
# ==============================================================================
# Ensures the repository is in the canonical location: ~/.dotfiles/ida
# Handles: cloning, moving, or validating existing repo

# When sourced from install script, lib.sh is already loaded
# When run standalone, load it
if [[ -z "${IDA_DOTFILES_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/lib.sh"
fi

# ==============================================================================
# Configuration
# ==============================================================================

REPO_URL="https://github.com/anomalyco/ida.git"  # Update with your actual repo URL
CANONICAL_PATH="$HOME/.dotfiles/ida"
DOTFILES_PARENT="$HOME/.dotfiles"

# ==============================================================================
# Functions
# ==============================================================================

# Get current repo path (where this script is running from)
get_current_repo_path() {
    # Go up from setup/ to repo root
    dirname "$SCRIPT_DIR"
}

is_git_repo() {
    local path="$1"
    [[ -d "$path/.git" ]] || git -C "$path" rev-parse --git-dir &>/dev/null
}

is_ida_repo() {
    local path="$1"
    # Check if it looks like ida dotfiles repo (has setup/ and config/)
    [[ -d "$path/setup" && -d "$path/config" ]]
}

# ==============================================================================
# Main Logic
# ==============================================================================

setup_repo() {
    local current_path
    current_path=$(get_current_repo_path)
    current_path=$(cd "$current_path" && pwd)  # Resolve to absolute path
    
    log_info "Current repo location: $current_path"
    log_info "Canonical location: $CANONICAL_PATH"
    
    # Case 1: Already in canonical location
    if [[ "$current_path" == "$CANONICAL_PATH" ]]; then
        log_success "Repository is already in canonical location"
        return 0
    fi
    
    # Case 2: Canonical location exists
    if [[ -e "$CANONICAL_PATH" ]]; then
        if is_ida_repo "$CANONICAL_PATH"; then
            log_warn "Canonical location already contains ida repo"
            log_info "You are running from: $current_path"
            log_info "But ida repo exists at: $CANONICAL_PATH"
            echo ""
            log_info "Options:"
            log_info "  1. Use existing repo at $CANONICAL_PATH"
            log_info "  2. Remove it and move current repo there"
            echo ""
            
            if [[ "$IDA_DRY_RUN" == "true" ]]; then
                log_dry "Would need user decision for repo conflict"
                return 0
            fi
            
            if ask_yes_no "Use existing repo at $CANONICAL_PATH?" "y"; then
                log_info "Using existing repo. Re-run installer from there:"
                log_info "  cd $CANONICAL_PATH && ./setup/install"
                exit 0
            else
                log_info "Removing existing repo and moving current one..."
                rm -rf "$CANONICAL_PATH"
            fi
        else
            log_error "Path exists but is not ida repo: $CANONICAL_PATH"
            log_info "Please remove or rename it manually"
            return 1
        fi
    fi
    
    # Case 3: Need to move repo to canonical location
    log_info "Moving repository to canonical location..."
    
    if [[ "$IDA_DRY_RUN" == "true" ]]; then
        log_dry "Would create: $DOTFILES_PARENT"
        log_dry "Would move: $current_path -> $CANONICAL_PATH"
        # In dry-run, use current path for subsequent steps
        export IDA_DOTFILES_DIR="$current_path"
        return 0
    fi
    
    # Create parent directory
    mkdir -p "$DOTFILES_PARENT"
    
    # Move the repo
    mv "$current_path" "$CANONICAL_PATH"
    log_success "Moved repository to $CANONICAL_PATH"
    
    # Update IDA_DOTFILES_DIR for subsequent steps
    export IDA_DOTFILES_DIR="$CANONICAL_PATH"
    
    # Inform user about the move
    echo ""
    log_info "Repository has been moved!"
    log_info "Please re-run the installer from the new location:"
    echo ""
    echo "  cd $CANONICAL_PATH && ./setup/install"
    echo ""
    
    # Exit so user re-runs from new location (paths in memory are stale)
    exit 0
}

# ==============================================================================
# Run
# ==============================================================================

print_header "Repository Setup"
setup_repo
