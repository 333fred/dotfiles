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
alias cat='batcat'
export PATH=$HOME/.dotnet/tools:$HOME/.local/bin:$PATH

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
