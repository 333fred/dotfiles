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

I use Neovim with Roslyn for C#, Snacks for file navigation, Bufferline for open files,
Gitsigns/CodeDiff/GHLite for integrated Git and PR review, and Lazygit/Octo as alternative interfaces.
The config is in `config/.config/nvim`, with the Ocean Dark Extended colors from my VS Code profile.

Install instructions:

1. Add the Neovim PPA: `sudo add-apt-repository ppa:neovim-ppa/stable`.
2. `sudo apt update && sudo apt install neovim gh curl` (the config requires Neovim 0.12 or newer).
3. Lazygit (can be simplified on 25.10 or later to `sudo apt install lazygit`)
    ```bash
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
    LAZYGIT_ARCH=$(uname -m | sed -e 's/aarch64/arm64/')
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${LAZYGIT_ARCH}.tar.gz"
    tar xf lazygit.tar.gz lazygit
    sudo install lazygit -D -t /usr/local/bin/
    rm lazygit lazygit.tar.gz
    ```
8. `dotnet tool install -g roslyn-language-server --prerelease --source https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json` (use `dotnet tool update -g` if already installed).
9. Make sure `dotnet` and `~/.dotnet/tools` are on `PATH`.
10. Run `stow -t ~ config` from this repo, then `nvim`. The first launch downloads the plugins.

Open `nvim .` at a solution or project root for C# support. Use `:Roslyn target` to choose a solution if needed.
`vim` and `v` alias to `nvim`; it is also the default `EDITOR` and `VISUAL`.

Shortcuts (`,` is the leader):

| Key | Action |
| --- | --- |
| `,e` | Toggle the file tree |
| `,f` / `,b` | Find a file / open buffer |
| `[b` / `]b` | Previous / next buffer in the top bar |
| `,x` | Close the buffer without closing its pane (prompts for unsaved changes) |
| `,g` | Toggle Lazygit in the folder opened at startup (or the launch directory if none) |
| `gd` / `gr` / `gi` | Definition / references / implementation |
| `,m` / `,,` | Document / workspace symbols |
| `,h` / `,l` | Jump back / forward |
| `Alt+h/j/k/l` | Focus the left / lower / upper / right pane |
| `<Space>` | Toggle a fold (folds start open) |
| `Ctrl+Space` | Show completions in Insert mode |
| `Ctrl+.` | Show quick fixes and code actions |
| `Ctrl+Backspace` | Delete the previous word in Insert or command-line mode |

Use Up / Down and Enter to select and accept completions or code actions.
The top buffer bar shows open files and LSP diagnostic counts. Click a file to switch to it;
its close button, right-click, or middle-click closes it with the same unsaved-change prompt as `,x`.
Octo PR descriptions remain in the bar with a `repo#number` label, alongside local files used in reviews.
Picker, terminal, and Octo auxiliary review buffers are excluded.
In the file tree, `H` / `I` toggle hidden / ignored files, and `Esc` exits search without closing the tree.
In Lazygit, `Esc` dismisses the current dialog or exits at the top level; `q` quits.

### Integrated Git and PR prototype

Gitsigns displays working-tree and staged changes in the gutter. CodeDiff provides a
tree of changed files with editable working-tree buffers and Ocean-colored diffs.
CodeDiff downloads its native diff library automatically on first use.
Revision buffers keep UTF-8 BOMs as buffer metadata, matching ordinary file buffers
instead of displaying a spurious first-line change.

| Key | Action |
| --- | --- |
| `,Gd` | Open local Git changes explorer; close the current CodeDiff view when already inside it |
| `,Gf` | Diff the current file against HEAD |
| `,Gb` | Toggle current-line Git blame |
| `,Gh` | Preview the current Git hunk inline (move the cursor to dismiss) |
| `[c` / `]c` | Previous / next Git hunk |
| `,Gp` | Open the current branch's PR changed-files explorer; close when already inside CodeDiff |
| `,Gc` | Load/refresh and show PR comment signs, or hide them |
| `,Gt` | Open current-line PR comments in a floating window |
| `,Ga` | Add a PR comment/reply at the cursor or visual selection |
| `,Gr` | Resolve the PR comment thread at the cursor |
| `,Gs` / `,Gu` | Start / submit a pending PR review |

Inside CodeDiff, Enter selects a file, `,Ge` focuses the changed-files pane, `,GE`
toggles it, `t` toggles inline/side-by-side layout, `gf` returns to the file in the
previous tab, and `q` closes the diff tab. `-` stages/unstages the current file;
the explorer's `S` / `U` stage/unstage all files. `g?` shows the available actions.

For PRs, run `gh auth login` and open the checked-out PR branch. `,Gp` resolves the
PR from the branch and compares against its merge base, not just uncommitted changes.
The checkout can include locally merged or rebased main changes, but must have no
tracked or unsaved file changes. When local HEAD differs from the PR head, the explorer
compares the remote PR snapshots so main-only local changes are not included; its PR
buffers are read-only. Missing snapshots are fetched from the PR's repository rather
than assuming `origin` is the upstream repository. This never changes your branch or
working tree, and the prototype does not automatically publish reviews.

`,Gc` loads comments without jumping to a quickfix entry. Purple `C` signs mark
commented lines; comment text is hidden until `,Gt` (press it again or Esc to close).
Compiler diagnostic counts in
the statusline and buffer bar exclude these comments. Changing checkout/repository
or editing local files clears the comment context to avoid stale GitHub line coordinates.
The comment loader paginates GitHub responses and excludes outdated threads.
Enable comments again once the checkout is clean. Refresh remote comments by toggling
`,Gc` off and on; background polling is disabled for this prototype.
With local merges/rebases, comments and selections map between local and PR lines only
where the entire range remains unchanged and contiguous. Comments on locally changed
or deleted lines are omitted with a warning; view or comment on their original PR
version in `,Gp`. New local lines cannot receive PR comments. Replies and new comments
always use the PR's original coordinates. If the checkout changes while drafting a
comment, sending is blocked and the draft is retained.

Use `,Gs` before commenting to batch a review; otherwise GHLite posts comments immediately.
In the comment editor, `c` then Enter sends the comment; `,Gu` publishes a pending review.
GHLite's native `:GHLitePR*` commands remain available, but bypass the prototype's
checkout guards and local-to-PR line mapping; use the shortcuts for locally
merged/rebased checkouts. Octo and the existing review-since workflow are unchanged.

### Octo PR reviews

1. Run `gh auth login` and open Neovim in a clean, dedicated review checkout.
2. Use `,p` for open PRs or `,P` for PRs requesting your review (up to 100 results). The picker uses `gh`'s default repo; set it with `gh repo set-default upstream` if needed.
3. Open a PR, then press `,r` for a side-by-side review. Confirm checkout if prompted. Roslyn works on the checked-out code on the right.
4. Run `:Octo review start` or `:Octo review resume` to comment. Use `\ca` for a comment or `\sa` for a suggestion, then `:w` to save it.
5. Run `:Octo review submit` to publish the pending review, or `:Octo review close` to return to the PR.

`]q` / `[q` switch changed files; `\e` focuses the file panel. Octo uses backslash as its local leader.
From an Octo PR description, `,f` opens the selected file in that same pane, keeping the
description as a hidden buffer rather than targeting a different editing pane. Click its
buffer-bar entry or use `[b` / `]b` to return to the description.

C# review panes automatically open unchanged diff folds within the method containing the cursor,
including its signature. Opened context stays expanded as you navigate; a diff fold may also
reveal neighboring methods. This works on both sides of the review and uses the `c_sharp`
Tree-sitter parser, installed automatically. Parser installation requires a C compiler and
`tree-sitter` CLI 0.26.1 or newer; use `:TSInstall c_sharp` to retry it.

Use `:Octo review since` from a PR buffer or an open review to see the combined diff from your last
submitted review to the current PR head. It uses the signed-in GitHub user's reviews, ignores pending
reviews, and compares the two snapshots directly (including after a force-push). The checkout must be
clean and at the current PR head; update it with `gh pr checkout <number> --repo <owner/repo>` if needed.
The old reviewed commit is fetched if missing. Start/resume and submit reviews with the usual Octo
commands; the custom range is retained when starting or resuming. No prior review or no changes is
reported explicitly rather than falling back to the full PR diff.
The historical left side is read-only. Comments and suggestions on the right use the current PR's
commentable lines, so they retain GitHub's normal coordinates and multiline support.

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
