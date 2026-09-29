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

## Neovim

Install Neovim 0.12 or newer, then run `stow -t ~ config` from the repository root to link `~/.config/nvim`. The first launch downloads the plugins with lazy.nvim; building the native fuzzy-search sorter and C# Tree-sitter parser also requires `make`, a C compiler, `curl`, `tar`, and `tree-sitter` CLI 0.26.1 or newer on `PATH`. The config keeps my Vim navigation, search, indentation, and folding settings; folds start open and `<Space>` toggles them. Neo-tree has Files, Buffers, and Git tabs at the top of the sidebar; Buffers lists open files separately from the file tree. Click a tab or press `<` / `>` in Neo-tree to switch sources. `,e` toggles the file browser, `,b` focuses the Buffers view from anywhere, and `,g` opens Git status. Press Enter on a changed file there to open its side-by-side diff (`:DiffviewClose` returns to the previous view); Enter on a directory still expands or collapses it.

The colors use the Ocean Dark Extended palette from my VS Code profile, including its C# semantic token overrides, blue namespace segments in using aliases, and bold control keywords. C# Tree-sitter highlighting also enables colored nesting for brackets. The status line shows mode, Git branch, file path, diagnostics, attached LSP, file type, and cursor position.

For GitHub PR reviews, authenticate `gh` (`gh auth login`) and open Neovim in a checkout of the repository. Press `,p` (or run `:GHOpenPR`) to choose a PR with the fuzzy picker; `:GHOpenPR 123` opens a specific PR, and `:GHRequestedReview` lists PRs requesting your review. In the gh.nvim panel, press Enter on a commit to browse its changed files and diffs; use `:GHStartReview` to collect pending comments, `:GHCreateThread` to comment on a changed line, and `:GHSubmitReview` to submit the review. gh.nvim fetches the PR and checks out its branch locally, so use a clean, dedicated Git worktree for reviews if you don't want it changing your working branch.

VSCodeVim-style navigation: `gd` jumps to a sole definition or opens a fuzzy picker for multiple targets; `gr` finds references, `gi` goes to implementation, `,m` searches document symbols, `,,` searches workspace symbols, `,f` finds files, and `,h` / `,l` move backward / forward through the jump list. The Telescope pickers update fuzzy matches as you type; workspace-symbol results also depend on Roslyn's responses.

For C# support, install the Roslyn language server as a global .NET tool (or use `dotnet tool update -g` if already installed):

```sh
dotnet tool install -g roslyn-language-server --prerelease --source https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json
```

Make sure `~/.dotnet/tools` and `dotnet` are on `PATH` when launching Neovim. Opening a folder with a `.sln`, `.slnx`, or `.csproj` at its root (for example, `nvim .`) starts a dedicated Roslyn server with `--autoLoadProjects` immediately, even before opening a C# file. C# buffers in that folder reuse the project-loaded server. If a directly opened C# file has multiple possible solution targets, Roslyn automatically loads projects from their common folder instead of attaching to an empty workspace. The dedicated server ensures an already-running daemon cannot ignore the startup flag; use `:Roslyn target` to select a particular solution when needed.

`vim` and `v` alias to `nvim` in interactive Bash and Zsh. `EDITOR` and `VISUAL` are `nvim` in shell startup files and the user environment; restart your shell (or sign in again for desktop apps) to pick up the change.

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
