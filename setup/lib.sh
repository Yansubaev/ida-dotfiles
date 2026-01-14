#!/usr/bin/env bash
# ==============================================================================
# IDA Dotfiles - Shared Library
# ==============================================================================
# Common functions for all setup scripts: logging, symlinks, backups, OS detection
# Source this file in other scripts: source "$(dirname "$0")/lib.sh"

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

# Canonical paths
export IDA_DOTFILES_DIR="${IDA_DOTFILES_DIR:-$HOME/.dotfiles/ida}"
export IDA_CONFIG_DIR="${IDA_CONFIG_DIR:-$HOME/.config}"
export IDA_BIN_DIR="${IDA_BIN_DIR:-$HOME/.local/bin}"
export IDA_BACKUP_DIR="${IDA_BACKUP_DIR:-$HOME/.config/.ida-backups}"

# Installation mode: safe | default | force
export IDA_MODE="${IDA_MODE:-default}"

# Dry run mode
export IDA_DRY_RUN="${IDA_DRY_RUN:-false}"

# Timestamp for backups
export IDA_BACKUP_TIMESTAMP="${IDA_BACKUP_TIMESTAMP:-$(date +%Y%m%d_%H%M%S)}"

# ==============================================================================
# Colors and Logging
# ==============================================================================

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' BOLD='' DIM='' RESET=''
fi

log_info() {
    echo -e "${BLUE}[INFO]${RESET} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${RESET} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $*" >&2
}

log_step() {
    echo -e "${MAGENTA}[STEP]${RESET} ${BOLD}$*${RESET}"
}

log_dry() {
    echo -e "${CYAN}[DRY-RUN]${RESET} $*"
}

log_skip() {
    echo -e "${DIM}[SKIP]${RESET} $*"
}

# ==============================================================================
# OS Detection
# ==============================================================================

detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "${ID:-unknown}"
    elif [[ -f /etc/arch-release ]]; then
        echo "arch"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/fedora-release ]]; then
        echo "fedora"
    else
        echo "unknown"
    fi
}

detect_os_family() {
    local os
    os=$(detect_os)
    case "$os" in
        arch|cachyos|endeavouros|manjaro|garuda)
            echo "arch"
            ;;
        debian|ubuntu|linuxmint|pop|elementary|zorin)
            echo "debian"
            ;;
        fedora|centos|rhel|rocky|alma)
            echo "fedora"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# ==============================================================================
# Package Manager Detection
# ==============================================================================

detect_aur_helper() {
    if command -v paru &>/dev/null; then
        echo "paru"
    elif command -v yay &>/dev/null; then
        echo "yay"
    else
        echo ""
    fi
}

detect_package_manager() {
    local os_family
    os_family=$(detect_os_family)
    case "$os_family" in
        arch)
            echo "pacman"
            ;;
        debian)
            echo "apt"
            ;;
        fedora)
            echo "dnf"
            ;;
        *)
            echo ""
            ;;
    esac
}

# ==============================================================================
# Backup Functions
# ==============================================================================

# Create backup directory for current session
ensure_backup_dir() {
    local backup_session_dir="$IDA_BACKUP_DIR/$IDA_BACKUP_TIMESTAMP"
    if [[ "$IDA_DRY_RUN" == "true" ]]; then
        log_dry "Would create backup directory: $backup_session_dir"
    else
        mkdir -p "$backup_session_dir"
    fi
    echo "$backup_session_dir"
}

# Backup a file or directory
# Usage: backup_item /path/to/item
backup_item() {
    local item="$1"
    local backup_session_dir
    backup_session_dir=$(ensure_backup_dir)
    
    if [[ ! -e "$item" && ! -L "$item" ]]; then
        return 0  # Nothing to backup
    fi
    
    local item_name
    item_name=$(basename "$item")
    local backup_path="$backup_session_dir/$item_name"
    
    if [[ "$IDA_DRY_RUN" == "true" ]]; then
        log_dry "Would backup: $item -> $backup_path"
    else
        # Handle case where backup already exists (add suffix)
        if [[ -e "$backup_path" ]]; then
            backup_path="${backup_path}.$(date +%s)"
        fi
        mv "$item" "$backup_path"
        log_info "Backup: $item -> $backup_path"
    fi
}

# ==============================================================================
# Symlink Functions
# ==============================================================================

# Check if path is a symlink pointing to expected target
is_correct_symlink() {
    local link_path="$1"
    local expected_target="$2"
    
    if [[ -L "$link_path" ]]; then
        local current_target
        current_target=$(readlink -f "$link_path" 2>/dev/null || echo "")
        local expected_resolved
        expected_resolved=$(readlink -f "$expected_target" 2>/dev/null || echo "$expected_target")
        [[ "$current_target" == "$expected_resolved" ]]
    else
        return 1
    fi
}

# Create symlink with conflict handling based on mode
# Usage: create_symlink /source/path /target/link
create_symlink() {
    local source="$1"
    local target="$2"
    
    # Check if source exists
    if [[ ! -e "$source" ]]; then
        log_error "Source does not exist: $source"
        return 1
    fi
    
    # If target is already correct symlink, skip
    if is_correct_symlink "$target" "$source"; then
        log_skip "Already linked: $target"
        return 0
    fi
    
    # Handle existing target based on mode
    if [[ -e "$target" || -L "$target" ]]; then
        case "$IDA_MODE" in
            safe)
                log_skip "Exists (safe mode): $target"
                return 0
                ;;
            default)
                backup_item "$target"
                ;;
            force)
                if [[ "$IDA_DRY_RUN" == "true" ]]; then
                    log_dry "Would remove: $target"
                else
                    rm -rf "$target"
                    log_info "Removed: $target"
                fi
                ;;
        esac
    fi
    
    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$target")
    if [[ ! -d "$parent_dir" ]]; then
        if [[ "$IDA_DRY_RUN" == "true" ]]; then
            log_dry "Would create directory: $parent_dir"
        else
            mkdir -p "$parent_dir"
        fi
    fi
    
    # Create symlink
    if [[ "$IDA_DRY_RUN" == "true" ]]; then
        log_dry "Would link: $target -> $source"
    else
        ln -s "$source" "$target"
        log_success "Linked: $target -> $source"
    fi
}

# ==============================================================================
# Utility Functions
# ==============================================================================

# Check if command exists
has_command() {
    command -v "$1" &>/dev/null
}

# Ask yes/no question
# Usage: ask_yes_no "Question?" && do_something
ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi
    
    read -r -p "$prompt" response
    response=${response:-$default}
    [[ "$response" =~ ^[Yy]$ ]]
}

# Get script directory (where the calling script is located)
get_script_dir() {
    cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

# Get repo root (assumes setup/ is one level deep)
get_repo_root() {
    local script_dir
    script_dir=$(get_script_dir)
    dirname "$script_dir"
}

# ==============================================================================
# Validation
# ==============================================================================

# Check required commands
check_requirements() {
    local missing=()
    local cmds=("$@")
    
    for cmd in "${cmds[@]}"; do
        if ! has_command "$cmd"; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        return 1
    fi
    return 0
}

# ==============================================================================
# Print helpers
# ==============================================================================

print_header() {
    local title="$1"
    echo ""
    echo -e "${BOLD}════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}  $title${RESET}"
    echo -e "${BOLD}════════════════════════════════════════════════════════════════${RESET}"
    echo ""
}

print_mode_info() {
    echo -e "  Mode:      ${BOLD}$IDA_MODE${RESET}"
    echo -e "  Dry-run:   ${BOLD}$IDA_DRY_RUN${RESET}"
    echo -e "  Repo:      ${BOLD}$IDA_DOTFILES_DIR${RESET}"
    echo -e "  Config:    ${BOLD}$IDA_CONFIG_DIR${RESET}"
    echo -e "  Bin:       ${BOLD}$IDA_BIN_DIR${RESET}"
    echo ""
}
