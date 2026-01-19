#!/usr/bin/env bash

set -e  # Exit on error

# Colors and formatting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

get_confirmation() {
    local prompt=$1
    if [ "$FORCE_YES" = "true" ]; then
        return 0
    fi
    echo -n "$prompt (y/n) "
    read -r -n 1 answer
    echo
    [[ $answer =~ ^[Yy]$ ]]
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_package() {
    local package=$1
    if command_exists "$package"; then
        log_success "$package is already installed"
        return 0
    fi

    log_info "Installing $package..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command_exists brew; then
            log_info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install "$package"
    elif command_exists apt-get; then
        sudo apt-get update -y
        sudo apt-get install -y "$package"
    else
        log_error "Unsupported package manager. Please install $package manually."
        return 1
    fi
}

install_neovim() {
    if command_exists nvim; then
        log_success "neovim is already installed"
        return 0
    fi
    
    log_info "Installing Neovim..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install neovim
    else
        # Install pure linux binary for latest version if package manager is old
        # But for stability on simple install, use package manager if available, 
        # or appimage if requested. Let's stick to simple package install first for reliability
        curl -L https://github.com/neovim/neovim/releases/download/v0.11.5/nvim-linux-x86_64.tar.gz -o nvim-linux-x86_64.tar.gz
        tar xzvf nvim-linux-x86_64.tar.gz
        sudo mv nvim-linux-x86_64/bin/nvim /usr/bin/nvim
        sudo mv nvim-linux-x86_64/lib/nvim /usr/lib/nvim
        sudo mv nvim-linux-x86_64/share/nvim /usr/share/nvim
        rm -rf nvim-linux-x86_64 nvim-linux-x86_64.tar.gz
    fi
    log_success "Neovim installed successfully!"
}

setup_symlinks() {
    log_info "Setting up symlinks..."
    mkdir -p "$BACKUP_DIR"
    
    # Map source -> target
    declare -A symlinks=(
        ["$DOTFILES_DIR/zsh/zshrc_manager.sh"]="$HOME/.zshrc"
        ["$DOTFILES_DIR/tmux/tmux.conf"]="$HOME/.tmux.conf"
    )

    for src in "${!symlinks[@]}"; do
        target="${symlinks[$src]}"
        if [ -f "$target" ] || [ -L "$target" ]; then
            # Check if it's already the correct link
            if [ -L "$target" ] && [ "$(readlink -f "$target")" == "$(readlink -f "$src")" ]; then
                log_success "$target is already correctly linked"
                continue
            fi
            
            log_info "Backing up $target to $BACKUP_DIR"
            mv "$target" "$BACKUP_DIR/"
        fi
        
        ln -sf "$src" "$target"
        log_success "Linked $src -> $target"
    done
}

setup_neovim_config() {
    if [ -d "$HOME/.config/nvim" ]; then
        if get_confirmation "Neovim config already exists. Overwrite with LazyVim starter?"; then
            mv "$HOME/.config/nvim" "$BACKUP_DIR/nvim_backup"
        else
            return 0
        fi
    fi
    
    log_info "Cloning LazyVim starter..."
    git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
    rm -rf "$HOME/.config/nvim/.git" # Remove git to make it user's own config
    log_success "Neovim config set up!"
}

setup_zsh_optimization() {
    log_info "Compiling zsh configuration for speed..."
    if command_exists zsh; then
        zsh -c 'zcompile $HOME/.zshrc' || true
        zsh -c 'zcompile '"$DOTFILES_DIR"'/zsh/zshrc.sh' || true
        log_success "Zsh config compiled"
    fi
}

main() {
    echo -e "${BOLD}Dotfiles Installation Script${NC}\n"

    # 1. Dependencies
    log_info "Checking dependencies..."
    install_package zsh
    install_package tmux
    install_package ripgrep
    install_package bat 
    install_neovim

    # 2. Clone/Update Dotfiles
    if [ ! -d "$DOTFILES_DIR" ]; then
        log_info "Cloning dotfiles..."
        git clone --recursive https://github.com/haicheviet/dotfiles.git "$DOTFILES_DIR"
    else
        log_info "Updating dotfiles..."
        cd "$DOTFILES_DIR" && git pull && git submodule update --init --recursive
    fi

    # 3. Symlinks
    setup_symlinks

    # 4. Neovim Config
    setup_neovim_config

    # 5. Set Shell
    if [[ "$SHELL" != *"zsh"* ]]; then
        if get_confirmation "Change default shell to zsh?"; then
            chsh -s "$(which zsh)"
        fi
    fi

    # 6. Optimize
    setup_zsh_optimization

    log_success "Installation + Optimization Complete!"
    log_info "Backups (if any) are in $BACKUP_DIR"
}

main "$@"
