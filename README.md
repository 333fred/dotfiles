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

I use `dotnetup` to install and manage .NET SDKs.
Install instructions for this set of dotfiles:

1. `curl --proto '=https' -fsSL https://aka.ms/dotnetup/get-dotnetup.sh | bash`
2. `stow -t ~ profile zsh` from the repository root, then restart your shell.

## Copilot CLI

I keep my Copilot CLI instructions, settings, and Roslyn LSP config in `copilot/.copilot`.

Install instructions:

1. Make sure `dnx` is on `PATH`.
2. Back up any existing files in `~/.copilot` that match the files in `copilot/.copilot`.
3. Run `stow --no-folding -t ~ copilot` from the repository root. `--no-folding` keeps runtime data outside the repo.

## Neovim

> [!NOTE]
> My neovim config is heavily created with Copilot, and I am not a lua expert. If you think something in it is bad practice, it probably
> is, and I just haven't been bitten by it yet.

I use Neovim with Roslyn for C#, Snacks for file navigation, Bufferline for open files,
and Gitsigns/CodeDiff/GHLite for integrated Git and PR review.
The config is in `config/.config/nvim`, with the Ocean Dark Extended colors from my VS Code profile.

Install instructions:

1. Add the Neovim PPA: `sudo add-apt-repository ppa:neovim-ppa/stable`.
2. `sudo apt update && sudo apt install neovim gh curl` (the config requires Neovim 0.12 or newer).
3. `dotnet tool install -g roslyn-language-server --prerelease --source https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json` (use `dotnet tool update -g` if already installed).
4. Make sure `dotnet` and `~/.dotnet/tools` are on `PATH`.
5. Run `stow -t ~ config` from this repo, then `nvim`. The first launch downloads the plugins.

Open `nvim .` at a solution or project root for C# support. Use `:Roslyn target` to choose a solution if needed.
`vim` and `v` alias to `nvim`; it is also the default `EDITOR` and `VISUAL`.

Pause after `,` or `\` for shortcut hints, or press `,?` for available keymaps.
See the [PR review notes](NEOVIM-REVIEW.md) for workflow and safety details.

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
2. Download Hack Nerd Font from https://www.nerdfonts.com/font-downloads
3. Copy the contents of the zips to `~/.fonts`, and run `fc-cache -fv`
4. `sudo apt install fonts-noto`

## Rofimoji

I use [Rofimoji](https://github.com/fdw/rofimoji) to input emoji. This is a python package, and should be installed with pipx:

1. `sudo apt install pipx`
2. `pipx install rofimoji`

## cd

I used enhancd for navigation. This requires fzf or fzy being installed. I use fzy.

## Other settings

Make sure to turn off the ibus emoji shortcut, or `ctrl+.` will be globally hooked and will mess up vscode.

`gsettings set org.freedesktop.ibus.panel.emoji hotkey "[]"`

https://stackoverflow.com/questions/71997823/ctrl-dot-makes-e-appear-instead-of-showing-suggestions-in-vscode-on-gnome

If you need to enable both analog and digital spdif on the same audio card, edit `/usr/share/alsa-card-profile/mixer/profile-sets/9999-custom.conf` to add (or possibly uncomment, why is this profile commented if maintainers know it's wanted!) this:

```
[Profile output:analog-stereo+output:iec958-stereo+input:analog-stereo]
description = Analog + Digital Output + Analog Input
output-mappings = analog-stereo iec958-stereo
input-mappings = analog-stereo
```
