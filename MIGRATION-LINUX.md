# Linux migration guide for Copilot

Migrate one native Regolith Linux installation to this chezmoi source. This
guide authorizes no changes by itself: get the user's approval at the gates
below. Do not commit, push, change branches, install packages, run `sudo`,
alter system settings, or modify the live home merely because this guide
says how.

## 1. Establish the source and scope

1. Ask the user which machine, reviewed branch/revision, and target scope to
   migrate. If the desired revision is uncommitted or unavailable, stop and
   ask how to make it available; cloning does not copy uncommitted changes.
   Do not commit or publish it without separate approval.
2. Check for chezmoi, Git, Stow, Neovim, gh, Copilot, Delta, .NET/dnx, the
   Tree-sitter CLI and compiler, and relevant Regolith tools. Ask before
   installing or upgrading anything, using apt/sudo, or building software.
3. Identify the old Regolith/Stow checkout and its installed packages. Inspect
   its status, submodule status, and local changes without altering it.
4. Run `SOURCE=$(chezmoi source-path) || exit 1` to find the configured source.
   The standard Linux
   default is `~/.local/share/chezmoi`, or `$XDG_DATA_HOME/chezmoi` when set.
   Config and state normally live under `~/.config/chezmoi` and cache under
   `~/.cache/chezmoi`, subject to `XDG_CONFIG_HOME` and `XDG_CACHE_HOME`.
   Inspect existing chezmoi configuration and state without exposing secrets.
   If the configured source is nonstandard or the standard location already
   contains another installation, stop and ask how to reconcile it. Do not
   overwrite or move existing files automatically.
5. If the standard source exists, inspect it with `git -C "$SOURCE" status
   --short --branch` and `git -C "$SOURCE" worktree list`, preserving unrelated
   changes. Ask whether it is the intended reviewed revision; do not
   reinitialize or update it without approval.
6. If the standard source is available and the chosen branch is accessible,
   **ask before initializing**. After approval, set `BRANCH` to the approved
   branch and use `chezmoi init --ssh --branch "$BRANCH" 333fred/dotfiles`.
   This initializes the standard source without applying it to the home. Use
   the approved origin and transport if they differ; never use `--apply` here.
   Verify the resulting branch, origin, and status before proceeding.

Keep this standard source directory in place: the Neovim link points into it.
Commands below assume a native Linux shell and do not require changing directories.

## 2. Inspect the existing installation

1. Record `hostname`, `$HOME`, and Neovim's actual config path. If Neovim is
   installed, `nvim --headless -u NONE -i NONE -n -c
   'lua print(vim.fn.stdpath("config"))' -c qa` does not load the user's init.
   Inspect the existing Neovim directory or symlink and its link target.
2. Inspect the actual Stow links and their **parent directories**, especially
   `~/.config`, `~/.config/nvim`, `~/.copilot`, `~/.gitconfig`, shell files,
   `~/.fonts`, `~/.gnupg`, and `~/.local`. A folded directory link may point
   into the old checkout: writing through it can modify that checkout. Do not
   run a blanket `stow -D`, unlink directories, or delete old sources.
3. Inspect the existing `.copilot` instructions, `settings.json`, and
   `lsp-config.json` individually. Ask which contents to keep if they differ;
   in particular, account for the old `AGENTS.md` versus the new
   `copilot-instructions.md`. Never replace or link the whole runtime directory,
   or expose authentication, permissions, sessions, or secrets.
4. Compare effective Git email, signing key, credential helper, GPG, and
   pager with the rendered template. The new template does **not** include
   `.gitconfig.local`. Ask how to preserve any needed local settings; do not
   delete local files or silently move credentials into tracked source.
5. Check the hostname against `.chezmoidata.toml` and inspect actual outputs
   with `xrandr --query` or `i3-msg -t get_outputs` in the user's graphical
   session. `frsilb-desk` is configured as `DP-2`/`DP-0`; `fred-desk` as
   `DP-4`/`DP-2`. The latter mapping is inferred from an older personal signing
   key. Ask the user to confirm the names and which output is main before
   changing or applying the mapping. Other hostnames use the old `DP-4`/`DP-2`
   defaults. Existing Kanshi profiles are unmanaged; preserve them.
6. Check the hard-coded `/home/fred` paths in the i3 bar, Kanshi include, and
   other Linux files against this machine's home. Also note that `.profile`
   reads `/env/environment.back`, while older documentation mentioned
   `/etc/environment.back`. If either assumption is wrong or needed behavior
   is unclear, stop and ask how to adapt it. Do not rename system files.

## 3. Choose the migration and preview it

**Confirm with the user** the source of truth for differing files, the target
scope, a backup location, and file mode versus symlink mode. Neovim is always
a directory link. Symlink mode also links eligible regular files such as
Copilot settings; templates remain copies. Explain that editing through the
Neovim link changes the checkout immediately.

After the user approves disposable test files and available disk space, stage
the source in a unique directory. The temporary path overrides isolate the
test without changing the standard source, config, cache, or state paths.
This may copy the Linux font payload; it does not fetch externals or touch the
live home.

```sh
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/chezmoi-migration.XXXXXXXX") || exit 1
mkdir "$STAGE/home" || exit 1
: > "$STAGE/config.toml"
chezmoi --source "$SOURCE" --destination "$STAGE/home" \
  --config "$STAGE/config.toml" --persistent-state "$STAGE/state.db" \
  --cache "$STAGE/cache" --mode file --no-tty --error-on-conflict \
  apply --exclude=externals
```

Stop if any command fails. Use the same isolation flags with `managed
--exclude=externals` and `diff --exclude=externals`; check the target list,
rendered monitor and Git values, and Neovim link destination. If the user chose
symlink mode, repeat the isolated check in a separate stage with that mode.

## 4. Back up, resolve conflicts, and apply

1. Compare every selected live target with the staged result, including
   symlinks and their parents. Ask the user how to reconcile each local edit or
   conflict. Do not paste private configuration or secrets into the conversation.
2. Present the exact backup paths, what will change, and how to restore each
   file or link. **Get approval** before creating backups or changing targets.
   Back up only affected items and record link destinations; preserve the old
   checkout, local edits, and unmanaged files. Never copy or delete the whole
   home, `.copilot`, or `.gnupg` runtime directory.
3. The Neovim link template refuses an existing non-symlink target, so even
   `chezmoi diff` may fail before that conflict is resolved. Once explicitly
   approved and backed up, move the existing Neovim directory aside. Existing
   symlinks can be replaced; review and record their destinations first, and
   never delete the symlink's target.
4. Resolve only the approved Stow/file conflicts. Do not write through a folded
   parent symlink into the old checkout; agree on a safe replacement with the
   user first. Do not use a blanket Stow delete or a force option.
5. Preview with `chezmoi --mode file diff --exclude=externals`, review the
   concrete target list, and **get approval**
   for the apply. Use the approved mode consistently. First-time existing
   files can be replaced even with `--error-on-conflict`; backups and review
   are still required.
6. Apply only the agreed targets using `chezmoi --mode file apply
   --exclude=externals --error-on-conflict`, optionally listing the
   approved paths. Stop on errors or unexpected conflicts; do not force or
   discard local changes.

## 5. External repositories and system setup

The 12 former top-level submodules are branch-tracking chezmoi Git externals.
Inspect `.chezmoiexternal.toml.tmpl`, the old checkouts, and each new
destination before fetching. Some destinations may already be symlinks or
contain local changes. Do not clone over them, update an old checkout through
a link, reset, stash, rebase, or discard work.

Ask the user whether and when to materialize or refresh externals, how to
handle each existing destination, and whether SSH access is available. Only
after approval, `chezmoi apply --include=externals
--refresh-externals=always` fetches/updates them. They follow upstream
branches independently of the dotfiles revision. The i3status-rust checkout
is now `~/.tools/i3status-rust`; building or installing it requires a separate
decision.

The [Regolith overrides](README.md#regolith-overrides) section lists packages
removed in the old setup. Treat that list as historical, not permission to
remove packages. Ask about any package, font registration, GPG key import,
desktop setting, or system configuration change individually.

The previous setup also used dotnetup, Rofimoji via pipx, fzy for enhancd,
and an optional IBus emoji-shortcut change. It documented a manual PulseAudio
profile adjustment for simultaneous analog and digital SPDIF output. Check
whether any of those are still wanted before proposing changes. The tracked
fonts still need any desired font-cache refresh, and the Neovim Roslyn setup
needs its .NET tooling; none of those steps happens automatically.

## 6. Verify and hand off

- Check the remaining chezmoi diff, Neovim link target, effective Git values,
  and availability of the selected signing key. Do not create a commit to test
  signing without approval.
- With permission, test Neovim startup, locked-plugin bootstrap and C# support,
  then Copilot instruction discovery and LSP. These can download software or
  modify local state. Do not authenticate, send prompts, or submit GitHub
  reviews without approval.
- With permission, verify the workspace/bar placement in the actual Regolith
  session. Arrange a safe rollback before restarting or reloading the window
  manager. Report anything not verified.
- Report the checkout, mode, backups, external state, and remaining
  prerequisites. Keep old checkouts and backups until the user approves cleanup.
  For rollback, obtain approval and restore only recorded targets and link
  destinations; do not delete broad directories or a symlink's target.
