* 333fred's Dotfiles

These are my dotfiles, designed to run inside WSL with the https://github.com/mintty/wsltty terminal emulator. Installation steps are as follows:

1. Install Ubuntu from the Window store.
2. Install wsltty. I prefer using chocolatey for this.
    * Base16-Ocean theme for wsltty: https://github.com/iamthad/base16-mintty/blob/master/mintty/base16-ocean.minttyrc. Install by putting in `%APPDATA%\wsltty\themes`.
	* Install patched consolas fonts: https://github.com/whitecolor/my-nerd-fonts/tree/master/Consolas%20NF. Set wsltty fonts to be these (size 10 is what I use).
3. `sudo apt update && sudo apt upgrade && sudo apt autoremove # Yes, WSL Ubuntu comes with unrequired packages`
4. `sudo apt install git gnupg2 tmux zsh stow zsh-doc doc-base # Last 2 are optional. Stow is optional if you want to symlink everyting manually"`
5. `git clone git@github.com:333fred/dotfiles.git .dotfiles --recursive`
6. `cd .dotfiles && stow bash config git tmux vim zsh`
7. Modify `~/.zprezto/modules/tmux/init.zsh`, and replace calls to tmux with `tmux -2`, to force 256 color support in the terminal.
8. Restart wsl terminal.
9. Open vim. There will be errors. Ignore, and run `:PlugInstall`. Restart vim, and errors should be gone.
10. Create ~/.gitconfig_local, and put anything you need to have locally. I put my email and git signing key here. These are in the .gitignore, so even if you decide to put them in the `.dotfiles` folder they shouldn't be committed.
10. ...
11. Profit?

This is more manual steps than I would like, but considering how often they need to be run, I don't care to attempt to automate it.

I've also included my VsVim config, but this doens't need to be linked from linux.
