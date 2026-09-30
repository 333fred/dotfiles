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

The entry point is `config/.config/nvim/init.lua`. General options, keymaps, and lazy.nvim bootstrapping live in `lua/config`; plugin specs and overrides live in `lua/plugins`. lazy.nvim imports the top-level plugin modules automatically, while plugin-specific helper modules live in subdirectories.

Install Neovim 0.12 or newer, then run `stow -t ~ config` from the repository root to link `~/.config/nvim`. The first launch downloads the plugins with lazy.nvim; building the C# Tree-sitter parser also requires `make`, a C compiler, `curl`, `tar`, and `tree-sitter` CLI 0.26.1 or newer on `PATH`. Install `lazygit` separately and keep it on `PATH` to use the Git interface. The config keeps my Vim navigation, search, indentation, and folding settings; folds start open and `<Space>` toggles them. `,e` toggles Snacks Explorer's file tree, which shows Git changes and diagnostics beside files; press Enter to open a file or expand a directory, and type to search. `,b` opens an instant fuzzy picker for open buffers from any normal-mode window. `,g` toggles Lazygit in a floating terminal to inspect changes, stage files, and browse commits; press `q` in Lazygit to close it. Lazygit's edit action opens files in the current Neovim instance. The previous Neo-tree Files / Buffers / Git tabs and side-by-side Diffview are no longer configured.

Explorer shows hidden files and Git-ignored files by default; `H` and `I` toggle those independently. `Esc` leaves Explorer open (and exits search input); its cancel shortcuts no longer close the sidebar, so use `,e` to toggle it. In Lazygit, `Esc` dismisses the floating terminal from either Terminal or Normal mode; `,g` brings it back.

The colors use the Ocean Dark Extended palette from my VS Code profile, including its C# semantic token overrides, blue namespace segments in using aliases, and bold control keywords. Diffs use background-only shading to preserve syntax and semantic text colors: muted green/red for added/deleted lines and stronger shading for changed words in Octo. C# Tree-sitter highlighting also enables colored nesting for brackets. The status line shows mode, Git branch, file path, diagnostics, attached LSP, file type, and cursor position.

For GitHub PR reviews, authenticate `gh` (`gh auth login`) and open Neovim in a dedicated checkout such as `~/git/review`. Press `,p` to choose from the first 100 open PRs with instant fuzzy filtering, or `,P` for PRs requesting your review. Enter opens the selected PR in Octo; `:Octo https://github.com/owner/repo/pull/123` opens one directly. From the PR buffer, press `,r` to browse a full review tab with changed files and side-by-side code. If necessary, it asks to check out the PR locally first and reloads Roslyn afterward; checkout refuses modified file buffers or a dirty worktree. Octo uses local files on the right side when the PR branch is checked out, allowing Roslyn semantic coloring and navigation there; the historical left side is not attached to LSP.

Browsing does not start a pending review. Use `:Octo review start` (or `:Octo review resume` for an existing pending review), then `\ca` to add a comment or `\sa` to suggest a change on a line or visual selection. Save the comment buffer with `:w`; comments stay pending until `:Octo review submit`. `]q` / `[q` switch changed files, `\e` focuses the review's file panel, and `:Octo review close` returns to the PR. The backslash is Octo's local leader, separate from the comma leader used for `,b` and `,e`.

The PR picker loads lightweight list metadata first and fetches full details for the selected PR, avoiding expensive bulk merge-status queries in large repositories. It uses `gh`'s default repository; check it with `gh repo view --json nameWithOwner`, or set it with `gh repo set-default upstream` from your checkout.

VSCodeVim-style navigation: `gd` jumps to a sole definition or opens a fuzzy picker for multiple targets; `gr` finds references, `gi` goes to implementation, `,m` searches document symbols, `,,` searches workspace symbols, `,f` finds files, and `,h` / `,l` move backward / forward through the jump list. `Alt+h/j/k/l` focuses the pane to the left / below / above / right in Normal, Insert, and Terminal modes, including the sides of an Octo diff; terminal navigation first leaves terminal-input mode. These shortcuts move between visible panes, while `,b` selects any open buffer. Snacks pickers update fuzzy matches as you type; workspace-symbol results also depend on Roslyn's responses.

`Ctrl+Backspace` deletes the previous word in Insert and command-line modes. `Ctrl+Space` opens built-in LSP completions in Insert mode; both the modern Ctrl+Space key and the legacy Ctrl+@ / NUL terminal encoding are mapped. `Ctrl+.` opens LSP quick fixes and code actions in Normal, Insert, or Visual mode (not the Vim quickfix list). In both menus, use Up / Down to select and Enter to accept; Enter accepts the first completion if none is selected yet. Outside completion menus, Up / Down move the cursor and Enter inserts a newline as usual. These shortcuts require the terminal to transmit the corresponding key chords; the desktop's emoji shortcut must not intercept `Ctrl+.`.

For C# support, install the Roslyn language server as a global .NET tool (or use `dotnet tool update -g` if already installed):

```sh
dotnet tool install -g roslyn-language-server --prerelease --source https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json
```

Make sure `~/.dotnet/tools` and `dotnet` are on `PATH` when launching Neovim. All Roslyn startup paths use dedicated servers rather than the shared daemon. Opening a folder with a `.sln`, `.slnx`, or `.csproj` at its root (for example, `nvim .`) starts Roslyn immediately, even before opening a C# file. Standalone projects are explicitly opened during server initialization, whether you start with the folder or a C# file; solution folders use `--autoLoadProjects`. C# buffers in that folder reuse the project-loaded server. If a directly opened C# file has multiple possible solution targets, Roslyn automatically loads projects from their common folder instead of attaching to an empty workspace. Project loading is asynchronous, so completions and quick fixes can take a moment to become available after startup; use `:Roslyn target` to select a particular solution when needed.

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
