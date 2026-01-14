#!/usr/bin/env bash
# ==============================================================================
# IDA Dotfiles - Bootstrap Script
# ==============================================================================
# One-liner installation:
#   bash <(curl -s https://raw.githubusercontent.com/anomalyco/ida/main/setup/bootstrap.sh)
#
# This script:
#   1. Clones the repository to ~/.dotfiles/ida
#   2. Runs the installer

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

REPO_URL="https://github.com/Yansubaev/ida-dotfiles.git"
INSTALL_DIR="$HOME/.dotfiles/ida"

echo -e "${BOLD}"
echo "  ╦╔╦╗╔═╗  ╔╦╗╔═╗╔╦╗╔═╗╦╦  ╔═╗╔═╗"
echo "  ║ ║║╠═╣   ║║║ ║ ║ ╠╣ ║║  ║╣ ╚═╗"
echo "  ╩═╩╝╩ ╩  ═╩╝╚═╝ ╩ ╚  ╩╩═╝╚═╝╚═╝"
echo -e "${RESET}"
echo ""

# Check for git
if ! command -v git &>/dev/null; then
    echo -e "${RED}Error: git is not installed${RESET}"
    echo "Please install git first:"
    echo "  sudo pacman -S git"
    exit 1
fi

# Check if already installed
if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${BLUE}[INFO]${RESET} Repository already exists at $INSTALL_DIR"
    echo ""
    read -r -p "Update and reinstall? [y/N] " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}[INFO]${RESET} Updating repository..."
        cd "$INSTALL_DIR"
        git pull
    else
        echo "Aborted."
        exit 0
    fi
else
    # Clone repository
    echo -e "${BLUE}[INFO]${RESET} Cloning repository to $INSTALL_DIR..."
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Run installer
echo ""
echo -e "${BLUE}[INFO]${RESET} Running installer..."
echo ""

cd "$INSTALL_DIR"
./setup/install "$@"
