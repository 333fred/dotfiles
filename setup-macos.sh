#!/bin/bash
# macOS setup script for 333fred's dotfiles
# Run this after cloning the repo to ~/git/dotfiles
set -euo pipefail

DOTFILES_DIR="${HOME}/git/dotfiles"

echo "=== macOS Dotfiles Setup ==="

# ──────────────────────────────────────────────
# 1. Install Homebrew if not present
# ──────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ──────────────────────────────────────────────
# 2. Install packages from Brewfile
# ──────────────────────────────────────────────
echo "Installing Homebrew packages..."
# Tap the fonts cask
brew tap homebrew/cask-fonts 2>/dev/null || true
brew bundle --file="${DOTFILES_DIR}/Brewfile"

# ──────────────────────────────────────────────
# 3. Initialize submodules (prezto, etc.)
# ──────────────────────────────────────────────
echo "Initializing git submodules..."
cd "${DOTFILES_DIR}"
git submodule update --init --recursive

# ──────────────────────────────────────────────
# 4. Stow dotfile packages
# ──────────────────────────────────────────────
echo "Stowing dotfiles..."
cd "${DOTFILES_DIR}"

STOW_PACKAGES=(
    bash
    config
    git
    gnupg
    profile
    vim
    vsvim
    zsh
)

for pkg in "${STOW_PACKAGES[@]}"; do
    echo "  Stowing ${pkg}..."
    stow -v --target="${HOME}" "${pkg}" 2>&1 | grep -v "^$" || true
done

# ──────────────────────────────────────────────
# 5. Install dnvm for dotnet management
# ──────────────────────────────────────────────
if [ ! -f "${HOME}/Library/Application Support/dnvm/env" ]; then
    echo "Installing dnvm..."
    curl --proto '=https' -sSf https://dnvm.net/install.sh | sh
    echo "  NOTE: dnvm env is already sourced from .zprofile and .profile"
fi

# ──────────────────────────────────────────────
# 6. Install Rust toolchain via rustup
# ──────────────────────────────────────────────
if ! command -v rustc &>/dev/null; then
    echo "Installing Rust toolchain..."
    rustup-init -y --no-modify-path
fi

# ──────────────────────────────────────────────
# 7. GPG agent setup
# ──────────────────────────────────────────────
echo "Restarting gpg-agent..."
gpgconf --kill gpg-agent 2>/dev/null || true
gpg-agent --daemon 2>/dev/null || true

# ──────────────────────────────────────────────
# 8. macOS defaults (optional quality-of-life)
# ──────────────────────────────────────────────
echo "Applying macOS defaults..."
# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true
# Show file extensions in Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
# Fast key repeat rate
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

echo ""
echo "=== Setup complete! ==="
echo ""
echo "Next steps:"
echo "  1. Restart your terminal (or run: exec zsh)"
echo "  2. Set your git signing key: git config --global user.signingkey YOUR_KEY_ID"
echo "  3. Create ~/.gitconfig.local for machine-specific git settings"
echo "  4. Create ~/.profile.local for machine-specific environment variables"
echo "  5. Install vim plugins: vim +PlugInstall +qall"
echo ""
