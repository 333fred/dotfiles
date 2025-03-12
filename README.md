# 333fred's Dotfiles

These are my dotfiles, designed to run on Windows.

## Fonts

Install the Hack Nerd Font from https://www.nerdfonts.com/font-downloads.

## Powershell

* Install/update Windows Terminal
* Install the following winget packages:
```powershell
winget install --id Microsoft.Powershell
winget install --id Starship.Starship
```
* Install the following powershell modules:
```powershell
Install-Module PSReadLine -AllowPrerelease -Force -Scope CurrentUser # https://github.com/PowerShell/PSReadLine
Install-Module posh-git -Scope CurrentUser # https://github.com/dahlbyk/posh-git
Install-Module posh-sshell -Scope CurrentUser # https://github.com/dahlbyk/posh-sshell
Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser # https://github.com/devblackops/Terminal-Icons
```
* Copy [`powershell\Profile.ps1`](./powershell/Profile.ps1) to `C:\Users\<user>\Documents\Powershell\`
* Open Windows Terminal settings, replace with [`terminal\settings.json`](./terminal/settings.json)

## Git

* Install the following powershell modules
```powershell
winget install --id git.git
winget install --id GnuPG.GnuPG
winget install --id github.cli
```
* Copy [`git\.gitconfig`](./git/.gitconfig) to `C:\Users\<user>`
* Generate or import a private key for gpg
  * Import
```powershell
gpg --import <path>
gpg --edit-key <email>
trust
5
y
```
* Get keyid: `gpg --list-keys --keyid-format long`
* Create `C:\Users\<user>\.gitconfig.user`
* Add to user config:
```ini
[user]
  email = ...
  signingkey = ...
```
* Generate ssh key (or import existing key): `ssh-keygen -t ed25519 -C <email>`
* Enable the OpenSSH service
* `gh auth login`

## Misc

* Install:
```powershell
winget install --id 7zip.7zip
```
* Copy [`vsvim\vsvimrc`](./vsvim/vsvimrc) to `C:\Users\<home>\.vsvimrc`
