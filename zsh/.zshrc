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

export GOPATH=~/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

#####
## Autorun for the gpg-relay bridge
##
#####
## Autorun for the gpg-relay bridge
##
SOCAT_PID_FILE=$HOME/.misc/socat-gpg.pid

if [[ -f $SOCAT_PID_FILE ]] && kill -0 $(cat $SOCAT_PID_FILE); then
   : # already running
else
    rm "$HOME/.misc/socat-gpg.pid" 2> /dev/null
    rm -f "$HOME/.gnupg/S.gpg-agent"
    (trap "rm $SOCAT_PID_FILE" EXIT; socat UNIX-LISTEN:"$HOME/.gnupg/S.gpg-agent,fork" EXEC:'/mnt/c/Users/frsilb/go/bin/npiperelay.exe -ei -ep -s -a "C:/Users/frsilb/AppData/Roaming/gnupg/S.gpg-agent"',nofork </dev/null &>/dev/null) &
    echo $! >$SOCAT_PID_FILE
fi
