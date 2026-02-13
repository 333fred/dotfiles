# 333fred's Dotfiles

These are my dotfiles, designed for **macOS**. I manage them using GNU Stow.

Other branches are customizations for other distros/OS's.

## Quick Start

1. Clone this repo: `git clone --recursive git@github.com:333fred/dotfiles.git ~/git/dotfiles`
2. Run the setup script: `./setup-macos.sh`
3. Restart your terminal

The setup script will install Homebrew, packages from the `Brewfile`, stow all dotfile packages, install fonts, and apply sensible macOS defaults.

## Fonts

Fonts are installed via Homebrew casks (`font-monaspace`, `font-hack-nerd-font`, `font-noto-sans`). I use Monaspace as my main font, with Noto as the backup/CJK font, and Hack as the backup monospace font.

## GPG

Install `pinentry-mac` via Homebrew (included in the Brewfile). The `gpg-agent.conf` is configured to use `/opt/homebrew/bin/pinentry-mac`.

## Git Credentials

Git is configured to use the macOS keychain (`osxkeychain`) for credential storage. Machine-specific git settings go in `~/.gitconfig.local`.

## `dotnet` management

I use @agocke's [DN-VM](https://github.com/dn-vm/dnvm) to manage my `dotnet` installation, so there's nothing checked in this repo for it.
Install instructions for this set of dotfiles:

1. `curl --proto '=https' -sSf https://dnvm.net/install.sh | sh`
2. Do not accept adding the helpers to environment files, it's already in `.zprofile` and `.profile` from this repo. Just make sure to `stow` as appropriate.

## cd

I use enhancd for navigation. This requires fzf or fzy being installed. I use fzy (included in the Brewfile).

## Local overrides

- `~/.gitconfig.local` — machine-specific git settings (signing key, etc.)
- `~/.profile.local` — machine-specific environment variables
