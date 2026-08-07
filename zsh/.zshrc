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

update-github() {
  local package='github'
  local installed_version latest_tag latest_version architecture asset temp_dir exit_status

  installed_version=$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null) || {
    print -u2 "The $package package is not installed."
    return 1
  }

  latest_tag=$(gh api repos/github/app/releases/latest --jq '.tag_name') || return
  latest_version=${latest_tag#v}

  if ! dpkg --compare-versions "$latest_version" gt "$installed_version"; then
    print "GitHub is already up to date ($installed_version)."
    return
  fi

  architecture=$(dpkg --print-architecture)
  case "$architecture" in
    amd64) asset='GitHub-Copilot-linux-x64.deb' ;;
    arm64) asset='GitHub-Copilot-linux-arm64.deb' ;;
    *)
      print -u2 "GitHub does not publish a .deb release for $architecture."
      return 1
      ;;
  esac

  temp_dir=$(mktemp -d) || return
  chmod 755 "$temp_dir" || {
    rm -rf -- "$temp_dir"
    return 1
  }
  print "Updating GitHub from $installed_version to $latest_version..."

  gh release download "$latest_tag" \
    --repo github/app \
    --pattern "$asset" \
    --dir "$temp_dir" || {
      rm -rf -- "$temp_dir"
      return 1
    }

  sudo apt install "$temp_dir/$asset"
  exit_status=$?
  rm -rf -- "$temp_dir"
  return "$exit_status"
}

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

# dotnetup: begin
if [ -x '/home/fred/.dotnetup/dotnetup' ]; then
    eval "$('/home/fred/.dotnetup/dotnetup' print-env-script --shell zsh)"
fi
# dotnetup: end
