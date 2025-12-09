# 333fred's Dotfiles

These are my dotfiles, designed to run on Windows.

## Fonts

Install the Hack Nerd Font from https://www.nerdfonts.com/font-downloads.  
Install the Monaspace Nerd Fonts from https://github.com/githubnext/monaspace/releases/.

## Powershell

* Install/update Windows Terminal
* Download [`winget\install.json`](./winget/install.json), and install with:
```powershell
winget import -i ~/Downloads/install.json
```
* Open an admin Terminal, and run the following to enable OpenSSH:
```powershell
Get-Service -Name ssh-agent | Set-Service -Startup
```
* Open Windows Terminal settings, replace with [`terminal\settings.json`](./terminal/settings.json)
* Restart Windows Terminal so you're in a pwsh session
* Install the following powershell modules if they don't automatically get populated from Onedrive backup:
```powershell
Install-Module PSReadLine -AllowPrerelease -Force -Scope CurrentUser # https://github.com/PowerShell/PSReadLine
Install-Module posh-git -Scope CurrentUser # https://github.com/dahlbyk/posh-git
Install-Module posh-sshell -Scope CurrentUser # https://github.com/dahlbyk/posh-sshell
Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser # https://github.com/devblackops/Terminal-Icons
```
* Copy [`powershell\Profile.ps1`](./powershell/Profile.ps1) to `C:\Users\<user>\Documents\Powershell\`
* Copy [`git\.gitconfig`](./git/.gitconfig) to `C:\Users\<user>`
* Generate ssh key (or import existing key): `ssh-keygen -t ed25519 -C <email>`
* Generate or import a private key for gpg
  * Import
```powershell
gpg --import <path>
gpg --edit-key <email>
trust
5
y
```
* Get keyid:
```powershell
gpg --list-keys --keyid-format long
```
* Create `C:\Users\<user>\.gitconfig.user`
* Add to user config:
```ini
[user]
  email = ...
  signingkey = ...
```
* `gh auth login`
* Download this repo:
```powershell
gh repo clone 333fred/dotfiles
```
* Open Powertoys settings and, under General -> Backup and Restore, set the restore location to `.\powertoys\Backup\`. Restore settings from backup.
* Copy [`vsvim\vsvimrc`](./vsvim/vsvimrc) to `C:\Users\<home>\.vsvimrc`
