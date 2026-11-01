# 333fred's Dotfiles

These are my dotfiles for Regolith Linux 3 and native Windows. I manage them
with chezmoi.

## Setup

Install Git and chezmoi, then initialize the main branch in chezmoi's
standard source directory:

```sh
chezmoi init --ssh --branch main 333fred/dotfiles
chezmoi diff --exclude=externals
chezmoi apply --exclude=externals --error-on-conflict
```

Migration guides are available for [Linux](MIGRATION-LINUX.md) and
[Windows](MIGRATION-WINDOWS.md). `chezmoi source-path` shows the source
directory.

The Linux externals follow their upstream branches. To initialize or refresh
them:

```sh
chezmoi apply --include=externals --refresh-externals=always
```

## Neovim

I use Neovim with Roslyn for C#, Snacks for navigation, Bufferline, and
Gitsigns/CodeDiff/GHLite for Git and PR review. Sidekick provides Copilot CLI
and next-edit suggestions, with review.nvim for local feedback. The theme is
Ocean Dark Extended.

The shared configuration is in `.chezmoitemplates/nvim`, linked to
`~/.config/nvim` on Linux and `AppData\Local\nvim` on Windows. The plugins
require Neovim 0.12 or later, Git, gh, curl, tar, the Tree-sitter CLI, and a
C compiler. On Ubuntu I use the Neovim PPA:

```sh
sudo add-apt-repository ppa:neovim-ppa/stable
sudo apt update && sudo apt install neovim gh curl
```

Install the Roslyn language server with the .NET SDK:

```sh
dotnet tool install -g roslyn-language-server --prerelease --source https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json
```

Use `dotnet tool update -g` if it is already installed. The .NET tools directory
must be on `PATH`. The first Neovim launch downloads the locked plugins.
Open `nvim .` at a solution or project root and use `:Roslyn target` to choose
a solution if needed. On Linux, `vim` and `v` alias to `nvim`.

Pause after `,` or `\` for shortcut hints, or press `,?` for available
keymaps. See the [review notes](NEOVIM-REVIEW.md) for PR and Copilot workflows.

## Copilot CLI

`dot_copilot` contains my global instructions, settings, and Roslyn LSP
configuration. The LSP requires `dnx`. Authentication, permissions, sessions,
and other runtime files stay outside the repository.

## Git

The shared Git configuration uses Delta and selects platform-specific settings,
email, and signing key through chezmoi. SSH keys can be created with
`ssh-keygen -t ed25519`; `gh auth login` configures the GitHub CLI. My YubiKey
and GPG setup is documented in [gnupg/README.md](gnupg/README.md).

## Linux

### Monitor management

Monitor mappings are in `.chezmoidata.toml`. Kanshi profiles and display
layout are managed separately.

### `dotnet` management

I use dotnetup to install and manage .NET SDKs:

```sh
curl --proto '=https' -fsSL https://aka.ms/dotnetup/get-dotnetup.sh | bash
```

### `i3status-rust`

Regolith's packaged i3status-rust is older than the version I use. The
chezmoi external checks out the source at `~/.tools/i3status-rust`:

```sh
cd ~/.tools/i3status-rust
sudo apt install pandoc libpulse-dev libsensors-dev
cargo install --path . --locked
./install.sh
```

### Regolith overrides

I maintain copies of Regolith defaults with my changes. The original setup
removed these packages to avoid conflicts with those overrides:

- `regolith-wm-navigation`
- `regolith-wm-resize`
- `regolith-i3-gaps`
- `i3-swap-focus`
- `i3xrocks`
- `regolith-i3-control-center-regolith`
- `regolith-i3-ftue`
- `regolith-i3-gaps-partial`
- `regolith-i3-i3xrocks`
- `regolith-i3-ilia`
- `regolith-i3-rofication-ilia`
- `regolith-i3-swap-focus`
- `regolith-sway-ilia`
- `regolith-sway-control-center-regolith`
- `regolith-control-center`
- `regolith-sway-i3status-rs`
- `regolith-sway-grimshot`

For [regolith-desktop#1042](https://github.com/regolith-linux/regolith-desktop/issues/1042),
the old setup renamed `/etc/environment` to `/etc/environment.back`. The
current profile reads `/env/environment.back` instead, so those paths need
reconciling for the workaround.

### Fonts

I use Monaspace as my main font, Hack as a monospace fallback, and Noto for
fallback/CJK. Monaspace and Hack are included in the Linux source; refresh the
font cache and install Noto with:

```sh
fc-cache -fv
sudo apt install fonts-noto
```

### Rofimoji and navigation

[Rofimoji](https://github.com/fdw/rofimoji) provides emoji input:

```sh
sudo apt install pipx
pipx install rofimoji
```

I use enhancd for directory navigation, with fzy or fzf as its filter.

### Other settings

The IBus emoji shortcut conflicts with `Ctrl+.` in VS Code:

```sh
gsettings set org.freedesktop.ibus.panel.emoji hotkey "[]"
```

For simultaneous analog and digital SPDIF output, the ALSA card profile at
`/usr/share/alsa-card-profile/mixer/profile-sets/9999-custom.conf` can include:

```ini
[Profile output:analog-stereo+output:iec958-stereo+input:analog-stereo]
description = Analog + Digital Output + Analog Input
output-mappings = analog-stereo iec958-stereo
input-mappings = analog-stereo
```

## Windows

### Fonts

Install [Hack Nerd Font](https://www.nerdfonts.com/font-downloads) and
[Monaspace Nerd Fonts](https://github.com/githubnext/monaspace/releases/).

### PowerShell and Windows Terminal

The Windows configuration includes the PowerShell profile, packaged Windows
Terminal settings, and VsVim settings. The package inventory is in
[winget/install.json](winget/install.json):

```powershell
winget import -i .\winget\install.json
```

The profile uses Starship and these PowerShell modules:

```powershell
Install-Module PSReadLine -AllowPrerelease -Force -Scope CurrentUser
Install-Module posh-git -Scope CurrentUser
Install-Module posh-sshell -Scope CurrentUser
Install-Module Terminal-Icons -Scope CurrentUser
```

To enable the OpenSSH agent, run in an administrator terminal:

```powershell
Get-Service -Name ssh-agent | Set-Service -Startup Manual
```

PowerToys settings can be restored from [powertoys/Backup](powertoys/Backup/)
using its General > Backup and Restore settings.
