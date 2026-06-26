#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Customize to your needs...

# Spaceship Customization

export SPACESHIP_TIME_SHOW=true

export SPACESHIP_PROMPT_ORDER=(
  vi_mode       # Vi-mode indicator
  time          # Time stamps section
  user          # Username section
  dir           # Current directory section
  host          # Hostname section
  dotnet
  git           # Git section (git_branch + git_status)
  exec_time     # Execution time
  line_sep      # Line break
  jobs          # Background jobs indicator
  exit_code     # Exit code section
  char          # Prompt character
)

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export ENHANCD_ENABLE_DOUBLE_DOT=false

# if [ -f "$HOME/.local/share/dnvm/env" ]; then
#     . "$HOME/.local/share/dnvm/env"
# fi

export PATH="/home/fred/.dotnetup:$PATH"

if command -v code-insiders &> /dev/null; then
  alias code='code-insiders'
fi

alias c='code'

alias gar='gh auth refresh -c'

scratch() {
  local dir
  dir=$(mktemp -d /tmp/scratch.XXXXXX) || return
  touch "$dir/test.cs"
  code "$dir"
}

# BEGIN Agency MANAGED BLOCK
if [[ ":${PATH}:" != *":/home/fred/.config/agency/CurrentVersion:"* ]]; then
    export PATH="/home/fred/.config/agency/CurrentVersion:${PATH}"
fi
# END Agency MANAGED BLOCK
