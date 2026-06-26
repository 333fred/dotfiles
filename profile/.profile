# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# Copy from /etc/environment. See https://github.com/regolith-linux/regolith-desktop/issues/1042
if [ -f  "/env/environment.back" ]; then
    . "/env/environment.back"
fi

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi

. "$HOME/.cargo/env"

# Define  a `.profile.local` file for setting local globals, such as `PRIMARY_MONITOR`` and `SECONDARY_MONITOR``
if [ -f "$HOME/.profile.local" ]; then
    . "$HOME/.profile.local"
fi

# if [ -f "$HOME/.local/share/dnvm/env" ]; then
#     . "$HOME/.local/share/dnvm/env"
# fi

export PATH="/home/fred/.dotnetup:$PATH"

export WLR_NO_HARDWARE_CURSORS=1
