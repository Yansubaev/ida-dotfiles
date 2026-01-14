#!/usr/bin/env bash
# ==============================================================================
# IDA Dotfiles - Package Installation
# ==============================================================================
# Installs packages from package lists. Currently supports Arch Linux (pacman + AUR).
# Other distros: shows "not implemented" message with guidance.

# When sourced from install script, lib.sh is already loaded
if [[ -z "${IDA_DOTFILES_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/lib.sh"
fi

# ==============================================================================
# Configuration
# ==============================================================================

PACKAGES_DIR="$IDA_DOTFILES_DIR/packages"

# ==============================================================================
# Package Installation Functions
# ==============================================================================

# Read package list from file (ignores comments and empty lines)
read_package_list() {
    local file="$1"
    if [[ -f "$file" ]]; then
        grep -v '^\s*#' "$file" | grep -v '^\s*$' | tr '\n' ' '
    fi
}

# ==============================================================================
# Arch Linux (pacman + AUR)
# ==============================================================================

install_yay() {
    log_info "Installing yay (AUR helper)..."
    
    if [[ "$IDA_DRY_RUN" == "true" ]]; then
        log_dry "Would install yay from AUR"
        return 0
    fi
    
    local tmp_dir
    tmp_dir=$(mktemp -d)
    
    # Install dependencies
    sudo pacman -S --needed --noconfirm base-devel git
    
    # Clone and build yay
    git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
    (cd "$tmp_dir/yay" && makepkg -si --noconfirm)
    
    # Cleanup
    rm -rf "$tmp_dir"
    
    log_success "yay installed successfully"
}

ensure_aur_helper() {
    local helper
    helper=$(detect_aur_helper)
    
    if [[ -n "$helper" ]]; then
        log_info "Using AUR helper: $helper"
        echo "$helper"
        return 0
    fi
    
    log_warn "No AUR helper found"
    
    if [[ "$IDA_DRY_RUN" == "true" ]]; then
        log_dry "Would install yay"
        echo "yay"
        return 0
    fi
    
    if ask_yes_no "Install yay (AUR helper)?" "y"; then
        install_yay
        echo "yay"
    else
        log_warn "Skipping AUR packages (no helper available)"
        echo ""
    fi
}

install_arch_packages() {
    local pacman_file="$PACKAGES_DIR/arch-pacman.txt"
    local aur_file="$PACKAGES_DIR/arch-aur.txt"
    
    # Install official packages
    if [[ -f "$pacman_file" ]]; then
        local packages
        packages=$(read_package_list "$pacman_file")
        
        if [[ -n "$packages" ]]; then
            log_info "Installing official packages..."
            
            if [[ "$IDA_DRY_RUN" == "true" ]]; then
                log_dry "Would run: sudo pacman -S --needed $packages"
            else
                # shellcheck disable=SC2086
                sudo pacman -S --needed --noconfirm $packages
                log_success "Official packages installed"
            fi
        fi
    else
        log_warn "Package list not found: $pacman_file"
    fi
    
    # Install AUR packages
    if [[ -f "$aur_file" ]]; then
        local aur_packages
        aur_packages=$(read_package_list "$aur_file")
        
        if [[ -n "$aur_packages" ]]; then
            local aur_helper
            aur_helper=$(ensure_aur_helper)
            
            if [[ -n "$aur_helper" ]]; then
                log_info "Installing AUR packages..."
                
                if [[ "$IDA_DRY_RUN" == "true" ]]; then
                    log_dry "Would run: $aur_helper -S --needed $aur_packages"
                else
                    # shellcheck disable=SC2086
                    $aur_helper -S --needed --noconfirm $aur_packages
                    log_success "AUR packages installed"
                fi
            fi
        fi
    else
        log_warn "AUR package list not found: $aur_file"
    fi
}

# ==============================================================================
# Debian/Ubuntu (apt)
# ==============================================================================

install_debian_packages() {
    local apt_file="$PACKAGES_DIR/debian.txt"
    
    if [[ -f "$apt_file" ]]; then
        local packages
        packages=$(read_package_list "$apt_file")
        
        if [[ -n "$packages" ]]; then
            log_info "Installing packages with apt..."
            
            if [[ "$IDA_DRY_RUN" == "true" ]]; then
                log_dry "Would run: sudo apt install $packages"
            else
                sudo apt update
                # shellcheck disable=SC2086
                sudo apt install -y $packages
                log_success "Packages installed"
            fi
        fi
    else
        log_warn "Package list not found: $apt_file"
        log_info "Create $apt_file with Debian/Ubuntu package names"
    fi
}

# ==============================================================================
# Fedora (dnf)
# ==============================================================================

install_fedora_packages() {
    local dnf_file="$PACKAGES_DIR/fedora.txt"
    
    if [[ -f "$dnf_file" ]]; then
        local packages
        packages=$(read_package_list "$dnf_file")
        
        if [[ -n "$packages" ]]; then
            log_info "Installing packages with dnf..."
            
            if [[ "$IDA_DRY_RUN" == "true" ]]; then
                log_dry "Would run: sudo dnf install $packages"
            else
                # shellcheck disable=SC2086
                sudo dnf install -y $packages
                log_success "Packages installed"
            fi
        fi
    else
        log_warn "Package list not found: $dnf_file"
        log_info "Create $dnf_file with Fedora package names"
    fi
}

# ==============================================================================
# Main
# ==============================================================================

install_packages() {
    local os_family
    os_family=$(detect_os_family)
    
    log_info "OS family: $os_family"
    echo ""
    
    case "$os_family" in
        arch)
            install_arch_packages
            ;;
        debian)
            install_debian_packages
            ;;
        fedora)
            install_fedora_packages
            ;;
        *)
            log_error "Unsupported OS family: $os_family"
            log_info "Package installation is not implemented for your system."
            log_info "Please install packages manually or contribute support!"
            return 1
            ;;
    esac
}

# ==============================================================================
# Run
# ==============================================================================

print_header "Package Installation"
install_packages
