# 333fred's Dotfiles

These are my dotfiles, designed to run on Regolith Linux 3. I manage them using GNU Stow.

Other branches are old customizations for other distros, or my Windows config.

## `dotnet` management

I use @agocke's [DN-VM](https://github.com/dn-vm/dnvm) to manage my `dotnet` installation, so there's nothing checked in this repo for it. Install instructions for this set of dotfiles:

1. `curl --proto '=https' -sSf https://dnvm.net/install.sh | sh`
2. Do not accept adding the helpers to environment files, it's already in `.zprofile` and `.profile` from this repo. Just make sure to `stow` as appropriate.
