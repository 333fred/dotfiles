# 333fred's Codespaces Dotfiles

This branch is a Codespaces-focused subset of my personal dotfiles, managed with GNU Stow.

## Included packages

The default bootstrap applies:

- `bash`
- `git`
- `profile`
- `vim`
- `zsh`

## GitHub Codespaces behavior

Codespaces dotfiles are account-level settings. GitHub clones your configured dotfiles repository into each new codespace and runs a supported root script such as `install.sh`.

Codespaces uses the repository's default branch for dotfiles, so test this branch by making it the default branch first or by merging it before pointing Codespaces at the repo.

The root `install.sh` is idempotent and does the following:

1. Ensures required CLI utilities are installed in Codespaces, including `stow`, `git-delta`, `bat`, and `fzy`, and installs the latest `btm` release from GitHub.
2. Backs up conflicting files from `$HOME` into `~/.dotfiles-backup/...`.
3. Initializes submodules.
4. Stows the default package set.

You can rerun the installer with a custom package list:

```sh
DOTFILES_PACKAGES="bash git profile vim zsh" ./install.sh
```

## Local overrides

Machine-specific settings can go in:

- `~/.gitconfig.local`
- `~/.profile.local`

The shell startup files also pick up Cargo and DNVM environment files if those tools are present.

## Setup

1. Open GitHub **Settings**.
2. Go to **Codespaces**.
3. Set your **Dotfiles** repository to this repo.
4. Create a new codespace.
