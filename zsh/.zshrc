#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Ensure tmux is aliased before it's called. This will ensure that 256 colors are supported
alias tmux="tmux -2"

BASE16_SHELL=$HOME/.config/base16-shell/
[ -n "$PS1" ] && [ -s $BASE16_SHELL/profile_helper.sh ] && eval "$($BASE16_SHELL/profile_helper.sh)"

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Customize to your needs...
alias cmd="cmd.exe /c"
alias isCase="fsutil.exe file queryCaseSensitiveInfo ."
alias setCase="fsutil.exe file setCaseSensitiveInfo ."
