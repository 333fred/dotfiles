# 333fred's Dotfiles

These are my dotfiles, designed to run on Regolith Linux 3. I manage them using GNU Stow.

Other branches are old customizations for other distros, or my Windows config.

## `dotnet` management

I use @agocke's [DN-VM](https://github.com/dn-vm/dnvm) to manage my `dotnet` installation, so there's nothing checked in this repo for it.
Install instructions for this set of dotfiles:

1. `curl --proto '=https' -sSf https://dnvm.net/install.sh | sh`
2. Do not accept adding the helpers to environment files, it's already in `.zprofile` and `.profile` from this repo. Just make sure to `stow` as appropriate.

## `i3status-rust`

The version of i3status-rust in Regolith's repositories is quite old, so I uninstall it and manually depend on the git version. After
updating all submodules, install with:

1. `cd config/i3status-rust`
2. `sudo apt install pandoc libpulse-dev libsensors-dev`
3. `cargo install --path . --locked`
4. `./install.sh`

## Regolith overrides

I override various regolith defaults in unsupported ways, so I maintain copies of the default regolith config files with my changes. Therefore, some packages need to be uninstalled from a default set:

* `regolith-wm-navigation`
* `regolith-wm-resize`
* `regolith-i3-gaps`
* `i3-swap-focus`
* `i3xrocks`
* `regolith-i3-control-center-regolith`
* `regolith-i3-ftue`
* `regolith-i3-gaps-partial`
* `regolith-i3-i3xrocks`
* `regolith-i3-ilia`
* `regolith-i3-rofication-ilia`
* `regolith-i3-swap-focus`
