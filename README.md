# 333fred's Dotfiles

These are my dotfiles, designed to run on Regolith Linux 3. I manage them using GNU Stow.

Other branches are old customizations for other distros, or my Windows config.

## Monitor management

I use two monitors, and make these files layout agnostic, I read values from Xresources to set my monitors correctly. Make a machine-specific `~/.Xresources` file and include the following:

```Xresources
wm.mainOutput: DP-X
wm.secondaryOutput: DP-Y
```

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
* `regolith-sway-ilia`
* `regolith-sway-control-center-regolith`
* `regolith-control-center`
* `regolith-sway-i3status-rs`
* `regolith-sway-grimshot`

Due to https://github.com/regolith-linux/regolith-desktop/issues/1042, rename `/etc/environment` to `/etc/environment.back`. Hopefully I can remove this hack at some point in the future.

## Fonts

I use Monaspace as my main font, with Noto as the backup/CJK font, and Hack as the backup monospace font. To install:

1. Download Monaspace from https://github.com/githubnext/monaspace/releases.
2. Run the installer in util/install_linux.sh
3. Download Hack Nerd Font from https://www.nerdfonts.com/font-downloads
4. Copy the contents of the zip to `~/.fonts`, and run `fc-cache -fv`
5. `sudo apt install fonts-noto`

## Rofimoji

I use [Rofimoji](https://github.com/fdw/rofimoji) to input emoji. This is a python package, and should be installed with pipx:

1. `sudo apt install pipx`
2. `pipx install rofimoji`

## Other settings

Make sure to turn off the ibus emoji shortcut, or `ctrl+.` will be globally hooked and will mess up vscode.

`gsettings set org.freedesktop.ibus.panel.emoji hotkey "[]"`

https://stackoverflow.com/questions/71997823/ctrl-dot-makes-e-appear-instead-of-showing-suggestions-in-vscode-on-gnome
