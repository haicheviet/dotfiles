#!/usr/bin/env bash

set -e  # Exit on error

# Colors and formatting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

have_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_local_bin_on_path() {
    # Add ~/.local/bin to PATH for current shell and future logins
    mkdir -p "$HOME/.local/bin"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH"
           # persist for bash/zsh
           for f in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
               [ -f "$f" ] && grep -q 'PATH=.*\.local/bin' "$f" || \
                 printf '\n# ensure local bin on PATH\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$f"
           done
           ;;
    esac
}

ensure_bat_available() {
    if have_cmd bat; then
        log_success "bat is already available"
        return 0
    fi

    if have_cmd batcat; then
        log_info "Found batcat; creating bat symlink..."
        ensure_local_bin_on_path
        ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
        log_success "Symlink created: ~/.local/bin/bat -> /usr/bin/batcat"
        return 0
    fi

    # Not present; install package (apt will provide batcat)
    log_info "bat not found; installing package 'bat'..."
    install_package "bat" || { log_error "Failed to install bat"; return 1; }

    # After install, prefer to expose it as 'bat'
    if have_cmd bat; then
        log_success "bat installed as 'bat'"
    elif have_cmd batcat; then
        log_info "bat installed as 'batcat'; linking to 'bat'..."
        ensure_local_bin_on_path
        ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
        log_success "bat is now available as 'bat'"
    else
        log_error "Install finished but neither 'bat' nor 'batcat' found"
        return 1
    fi
}

ensure_ripgrep_available() {
    if have_cmd rg; then
        log_success "ripgrep (rg) is already available"
        return 0
    fi
    log_info "ripgrep not found; installing..."
    install_package "ripgrep" || { log_error "Failed to install ripgrep"; return 1; }

    if have_cmd rg; then
        log_success "ripgrep installed successfully (rg)"
    else
        log_error "ripgrep installation finished but 'rg' command not found."
        return 1
    fi
}

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
        wget --quiet https://github.com/neovim/neovim/releases/download/v0.11.0/nvim-linux-x86_64.appimage
        chmod u+x nvim-linux-x86_64.appimage
        sudo mv nvim-linux-x86_64.appimage /usr/bin/nvim
    fi
    log_success "Neovim installed successfully!"
}

# Install Pier
install_pier() {
    log_info "Installing Pier..."
    # Check if cargo is installed
    if ! command -v cargo >/dev/null; then
        log_info "Installing Rust..."
        curl https://sh.rustup.rs -sSf | sh
    fi
    cargo install pier
    log_success "Pier installed successfully!"
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
    
    # Neovim configuration
    if get_confirmation "Would you like to use Neovim config?"; then
        rm -rf ~/.config/nvim
        git clone https://github.com/LazyVim/starter ~/.config/nvim
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

    # Install Pier
    install_pier

    # Install batcat
    ensure_bat_available

    # Install ripgrep (if not present)
    ensure_ripgrep_available
    
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
