# ~/.oh-my-zsh/custom/aliases.zsh
# CUSTOM ALIASES FILE (zsh version)
# Author: Krisha A. Kumar (2025)
# Edit Date: 2025-10-07
#
# NOTE This file is automatically loaded by Oh My Zsh.

# Maintenance
alias editrc="nvim ~/.zshrc && source ~/.zshrc"
alias edital="nvim ~/.oh-my-zsh/custom/aliases.zsh && source ~/.zshrc"
alias editpr="p10k configure"
alias editvim="nvim ~/.config/nvim/init.lua"
alias up="sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && clear"

# TEMPORARY COMMANDS --- be sure to regularly purge this section
alias dev="pnpm dev" # 2025-10-03 T 12:54-0600

# Clear Commands
alias c="clear"
alias cls="clear"
alias clc="clear"
alias Clear="clear"
alias clear-host="clear"
alias Clear-Host="clear"
alias Clear-host="clear"

# Navigation Commands
alias cd="z"
alias projects="z ~/Documents/Projects"
alias Projects="z ~/Documents/Projects"
alias base="z ~/Documents/Projects/BAES_Projects"
alias baes="z ~/Documents/Projects/BAES_Projects"
alias BAES="z ~/Documents/Projects/BAES_Projects"
alias Baes="z ~/Documents/Projects/BAES_Projects"
alias ..="z .."

# Auto-Coloring
if [ -x /usr/bin/dircolors ];
then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)"
  eval "$(dircolors -b)"
  alias ls='eza'
  #alias dir='dir --color=auto'
  #alias vdir='vdir --color=auto'

  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi 

# Listing Commands
alias ll='eza -A -l -F'
alias la='eza -A'
alias l='eza -C -F'
alias lu='eza -l -h -A -F --color=auto --time-style="+%Y-%m-%d|%I:%M%p"'
alias lse="lu"

# Alert Alias (for long running commands)
# Updated to use `fc -ln -1`, the Zsh way to get the last command without history numbers.
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(fc -ln -1 | sed -e '\''s/[;&|]\s*alert$//'\'')"'

# Editing Commands
alias neovim="nvim"
alias n="nvim"
alias edit="nvim"

# Just for fun
alias dog="echo woof && cat"
alias please="sudo"
alias sukit="echo YOU suck it... suck i-i-i-iitt!"
