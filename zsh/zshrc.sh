# Vars
HISTFILE=~/.zsh_history
SAVEHIST=10000

# Custom cd
source ~/dotfiles/zsh/plugins/fixls.zsh

chpwd() ls

# Add custom completions dir to fpath
fpath=(~/dotfiles/zsh/completions $fpath)

# Speed up zsh startup by compiling configuration files
if [ -f ~/.zshrc ] && [ ! -f ~/.zshrc.zwc ]; then 
    zcompile ~/.zshrc 
fi
if [ -f ~/dotfiles/zsh/zshrc.sh ] && [ ! -f ~/dotfiles/zsh/zshrc.sh.zwc ]; then 
    zcompile ~/dotfiles/zsh/zshrc.sh 
fi

# Completion system with caching
autoload -Uz compinit
cache_dump=~/.zcompdump
if [ -f "$cache_dump" ]; then 
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS/BSD stat
        dump_day=$(stat -f '%Sm' -t '%j' "$cache_dump")
    else
        # Linux/GNU stat
        dump_day=$(date -r "$cache_dump" +%j 2>/dev/null || date -d @$(stat -c %Y "$cache_dump" 2>/dev/null) +%j)
    fi
else
    dump_day="0"
fi

if [ "$(date +'%j')" != "$dump_day" ]; then
  compinit
else
  compinit -C
fi

# Load aliases
source ~/dotfiles/aliases/.aliases

# Plugins
source ~/dotfiles/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/dotfiles/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/dotfiles/zsh/prompt.sh
source ~/dotfiles/zsh/keybindings.sh
source ~/dotfiles/zsh/bindings.zsh
source ~/dotfiles/zsh/history.zsh

# Add dir colors for terminal (Linux only)
if [[ "$OSTYPE" != "darwin"* ]]; then
    if [ -f ~/dotfiles/.dir_colors ]; then
        eval $(dircolors -b ~/dotfiles/.dir_colors)
    fi
fi

# Set default text editor to nvim
export VISUAL=nvim
export PATH="$HOME/.local/bin:$PATH"