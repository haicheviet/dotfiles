#!/usr/bin/env bash

set -e  # Exit on error

# Colors and formatting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Progress bar function
progress_bar() {
    local duration=$1
    local steps=20
    local sleep_time=$(bc <<< "scale=4; $duration/$steps")
    
    echo -ne "\r["
    for ((i=0; i<steps; i++)); do
        echo -ne "▓"
        sleep "$sleep_time"
    done
    echo -ne "] ${GREEN}Done!${NC}\n"
}

# Print formatted messages
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Get user confirmation
get_confirmation() {
    local prompt=$1
    echo -n "$prompt (y/n) "
    read -r -n 1 answer
    echo
    [[ $answer =~ ^[Yy]$ ]]
}

# Install package based on OS
install_package() {
    local package=$1
    log_info "Installing $package..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v brew >/dev/null; then
            log_info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install "$package"
    elif command -v apt-get >/dev/null; then
        sudo apt-get update
        sudo apt-get install -y "$package"
    else
        log_error "Unsupported package manager. Please install $package manually."
        return 1
    fi
}

# Install Neovim
install_neovim() {
    log_info "Installing Neovim..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install neovim
    else
        wget --quiet https://github.com/neovim/neovim/releases/download/stable/nvim.appimage --output-document nvim
        chmod u+x nvim
        sudo mv nvim /usr/bin
    fi
    log_success "Neovim installed successfully!"
}

# Check and install required software
check_dependencies() {
    local dependencies=("$@")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null; then
            log_info "$dep is not installed"
            if get_confirmation "Would you like to install $dep?"; then
                if [[ "$dep" == "nvim" ]]; then
                    install_neovim
                else
                    install_package "$dep"
                fi
            fi
        else
            log_success "$dep is already installed"
        fi
    done
}

# Setup dotfiles
setup_dotfiles() {
    local dotfiles_dir="$HOME/dotfiles"
    
    # Clone repository if it doesn't exist
    if [ ! -d "$dotfiles_dir" ]; then
        log_info "Cloning dotfiles repository..."
        git clone --recursive https://github.com/haicheviet/dotfiles.git "$dotfiles_dir"
    fi

    # Clone submodule
    git submodule update --init --recursive
    
    # Backup existing configs
    if get_confirmation "Would you like to backup your current dotfiles?"; then
        log_info "Backing up existing configurations..."
        for file in .zshrc .tmux.conf .vimrc .gitconfig; do
            [ -f "$HOME/$file" ] && mv "$HOME/$file" "$HOME/${file}.backup"
        done
        log_success "Backup completed!"
    fi
    
    # Create symlinks
    log_info "Creating symlinks..."
    printf "source '$HOME/dotfiles/zsh/zshrc_manager.sh'" > ~/.zshrc
    printf "source-file $HOME/dotfiles/tmux/tmux.conf" > ~/.tmux.conf
    
    # WezTerm configuration
    if get_confirmation "Would you like to use WezTerm config?"; then
        ln -sf "$dotfiles_dir/wezterm/.wezterm.lua" "$HOME/.wezterm.lua"
        log_success "WezTerm config linked!"
    fi
    
    # Neovim configuration
    if get_confirmation "Would you like to use Neovim?"; then
        mkdir -p ~/.config/nvim
        ln -sf "$dotfiles_dir/nvim" ~/.config/nvim
        log_success "Neovim config linked!"
    fi
}

# Setup AI commit messages
setup_ai_commit() {
    if get_confirmation "Would you like to use AI to generate commit messages?"; then
        log_info "Setting up AI commit message generation..."
        pip install --user llm
        llm install llm-groq
        
        # Prompt for GROQ_API_KEY
        echo -n "Please enter your GROQ API key: "
        read -r groq_key
        llm keys set groq "$groq_key"
        
        # Copy git config
        yes | cp -rf "$HOME/dotfiles/gitconfig/." ~/
        log_success "AI commit setup completed!"
    fi
}

# Main installation function
main() {
    echo -e "${BOLD}Dotfiles Installation Script${NC}\n"
    
    # Show installation steps
    cat << EOF
Installation steps:
1. Check and install dependencies
2. Configure shell environment
3. Setup dotfiles and configurations
4. Configure AI commit messages (optional)
EOF
    
    if ! get_confirmation "Would you like to proceed with the installation?"; then
        log_info "Installation cancelled. No changes were made."
        exit 0
    fi
    
    # Check dependencies
    check_dependencies zsh tmux nvim
    
    # Check default shell
    if [[ "$SHELL" != *"zsh"* ]]; then
        if get_confirmation "Would you like to set zsh as your default shell?"; then
            chsh -s "$(which zsh)"
            log_success "Default shell changed to zsh"
        fi
    fi
    
    # Setup dotfiles
    setup_dotfiles
    
    # Setup AI commit messages
    setup_ai_commit
    
    log_success "Installation completed successfully!"
    log_info "Please log out and log back in for changes to take effect."
}

# One-line installation command:
# curl -fsSL https://raw.githubusercontent.com/haicheviet/dotfiles/master/install.sh | bash

# Execute main function
main "$@"
