# Linux migration guide for Copilot

Migrate one native Regolith Linux installation to this chezmoi source. This
guide authorizes no changes by itself: get the user's approval at the gates
below. Do not commit, push, change branches, install packages, run `sudo`,
alter system settings, or modify the live home merely because this guide
says how.

The goal is a complete move, not a partial migration. Normal files, external
repositories, nested Git metadata, legacy links, and dependent worktrees must
all be reconciled so the old checkout is no longer needed by the live setup.
A clean diff with `--exclude=externals` is only an intermediate checkpoint.
If any dependency cannot be migrated safely, report the migration as blocked
or incomplete; do not describe the move as complete. Keeping the old checkout
as an inactive rollback copy is different from leaving live dependencies on it.

## 1. Establish the source and scope

1. Ask the user which machine, reviewed branch/revision, and target scope to
   migrate. If the desired revision is uncommitted or unavailable, stop and
   ask how to make it available; cloning does not copy uncommitted changes.
   Do not commit or publish it without separate approval.
2. Check for chezmoi, Git, Stow, Neovim, gh, Copilot, Delta, .NET/dnx, the
   Tree-sitter CLI and compiler, and relevant Regolith tools. Ask before
   installing or upgrading anything, using apt/sudo, or building software.
   Check `apt-cache policy chezmoi` before choosing an installation method.
   If the configured indexes have no candidate, upstream publishes a `.deb`;
   offer that option rather than assuming a standalone binary is necessary.
   Verify the approved release's checksum and package architecture. If sudo
   needs a password, provide the exact install command for the user to run.
   After installation, check `command -v chezmoi`, its version, and package
   status; an earlier `~/.local/bin/chezmoi` can shadow `/usr/bin/chezmoi`.
   Remove only an approved redundant binary, after the package works.
3. Identify the old Regolith/Stow checkout and its installed packages. Inspect
   its status, submodule status, and local changes without altering it.
   Include `git worktree list` and inspect each dependent worktree's staged,
   unstaged, untracked, and ignored files. A clean main checkout does not mean
   its linked worktrees are clean or independent.
4. Run `SOURCE=$(chezmoi source-path) || exit 1` to find the configured source.
   The standard Linux
   default is `~/.local/share/chezmoi`, or `$XDG_DATA_HOME/chezmoi` when set.
   Config and state normally live under `~/.config/chezmoi` and cache under
   `~/.cache/chezmoi`, subject to `XDG_CONFIG_HOME` and `XDG_CACHE_HOME`.
   Inspect existing chezmoi configuration and state without exposing secrets.
   Inspect the source and config paths' ancestors for folded Stow links before
   creating files there, so setup cannot write through them into the old source.
   If the configured source is nonstandard or the standard location already
   contains another installation, stop and ask how to reconcile it. Do not
   overwrite or move existing files automatically. The source config template
   expects JSON and refuses to initialize over an existing non-JSON chezmoi
   configuration; agree on any format migration before proceeding.
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
   If the standard source was already cloned and reviewed, initialize that
   checkout with `chezmoi init --apply=false`, without a repository argument or
   branch switch. Preserve its uncommitted changes. If the old checkout will
   eventually be retired, the new source must be a standalone clone, not a
   linked worktree whose Git metadata depends on the old checkout.

Keep this standard source directory in place: the Neovim link points into it.
The global `work` value is computed during `chezmoi init`; rerun initialization
after a hostname or login change. Commands below assume a native Linux shell
and do not require changing directories.

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
   Record directory and file permissions as well as link destinations. Compare
   the staged modes: an existing private directory can otherwise be widened
   to `0775` under the user's umask. In particular, preserve the approved
   private modes of `.config`, `.copilot`, `.local`, `.local/share`, and
   `.local/share/applications`. If source attributes need correction, get
   approval and use nonrecursive `chezmoi chattr private PATH...` for the
   selected directories, then repeat the preview. Do not chmod whole runtime
   trees or rely on a one-off chmod that the next apply would undo.
3. Inspect the existing `.copilot` instructions, `settings.json`, and
   `lsp-config.json` individually. Ask which contents to keep if they differ;
   in particular, account for the old `AGENTS.md` versus the new
   `copilot-instructions.md`. Never replace or link the whole runtime directory,
   or expose authentication, permissions, sessions, or secrets.
   The settings template accepts the machine-specific agent-host block as
   `data.copilotAhpEnvironment` in the local chezmoi configuration; preserve
   it locally where needed, without committing machine identifiers.
   Keep that local JSON config private (`0600`, in a `0700` directory), and
   persist the chosen mode there. Render settings using the initialized `work`
   value and local data, not an empty config. Present a key-sorted settings
   diff with unchanged agent-host data omitted, verifying separately that the
   block is preserved. Include live-only preferences, feature flags, and
   marketplace entries in the review rather than silently dropping them.
   Check both work and non-work renders when changing shared settings.
4. Compare effective Git email, signing key, credential helper, GPG, and
   pager with the rendered template. The new template does **not** include
   `.gitconfig.local`. Ask how to preserve any needed local settings; do not
   delete local files or silently move credentials into tracked source.
   Check every key in the local file, not just the expected identity fields.
   Use a rendered candidate with a temporary `GIT_CONFIG_GLOBAL` to compare
   effective values without editing the live configuration. Removing a
   redundant earlier entry is not the same as changing the effective value;
   leave the local file in place even when all its values are duplicated.
5. Check the hostname against `.chezmoidata.toml` and inspect actual outputs
   with `xrandr --query` or `i3-msg -t get_outputs` in the user's graphical
   session. `frsilb-ubuntu` is configured as `DP-2`/`DP-0`; `fred-desk` as
   `DP-4`/`DP-2`. The latter mapping is inferred from an older personal signing
   key. Ask the user to confirm the names and which output is main before
   changing or applying the mapping. Other hostnames use the old `DP-4`/`DP-2`
   defaults. Existing Kanshi profiles are unmanaged; preserve them.
   Compare current `wm.mainOutput` and `wm.secondaryOutput` Xresource overrides
   too: the new templates render outputs directly instead of consulting those
   overrides. Use the actual hostname, not a remembered alias.
6. Check the hard-coded `/home/fred` paths in the i3 bar, Kanshi include, and
   other Linux files against this machine's home. The profile reads
   `/etc/environment.back` when present. If either assumption is wrong or
   needed behavior is unclear, stop and ask how to adapt it. Do not rename
   system files.
   Check whether both `/env/environment.back` and `/etc/environment.back`
   actually exist before discussing a merge. If both exist, compare them
   privately; if only one exists, there is no two-file content merge to do.
   Correcting a source reference does not require creating or renaming a
   system file.

## 3. Choose the migration and preview it

**Confirm with the user** the source of truth for differing files, the target
scope, a backup location, and file mode versus symlink mode. Neovim is always
a directory link. File mode still retains explicitly defined symlinks, such
as the relative Rofi shortcut links; inventory these separately rather than
promising that every target will be a regular file. Symlink mode also links
eligible regular files; templated Copilot settings remain a copy. Explain
that editing through the Neovim link changes the checkout immediately.

After the user approves disposable test files and available disk space, stage
the source in a unique directory. The temporary path overrides isolate the
test without changing the standard source, config, cache, or state paths.
This may copy the Linux font payload; it does not fetch externals or touch the
live home.

This preview deliberately excludes externals to isolate normal-file conflicts;
it is not the final scope. Inventory and migrate all externals in section 5
before declaring success.

First finish the approved local JSON initialization, including machine-specific
data and the chosen mode. Copy that config into the private staging directory.
Initialize the staged config against its own state so subsequent commands do
not report a stale config template. Do not substitute an empty TOML file:
it lacks the computed `work` value and local settings.

Record `umask` and use the same value for staging, diffing, and the proposed
live apply. Setting `umask 077` only during the first staged apply creates
permission-only drift when later commands use the normal shell umask. Protect
the staging directory and config directly instead.

```sh
CONFIG=$(chezmoi execute-template '{{ .chezmoi.configFile }}') || exit 1
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/chezmoi-migration.XXXXXXXX") || exit 1
mkdir "$STAGE/home" || exit 1
cp -- "$CONFIG" "$STAGE/config.json" || exit 1
chmod 600 "$STAGE/config.json" || exit 1

stage_chezmoi() {
  chezmoi --source "$SOURCE" --destination "$STAGE/home" \
    --config "$STAGE/config.json" --persistent-state "$STAGE/state.db" \
    --cache "$STAGE/cache" --mode file --no-tty --no-pager \
    --refresh-externals=never "$@"
}

stage_chezmoi init --apply=false --config-path "$STAGE/config.json" || exit 1
stage_chezmoi --error-on-conflict apply --exclude=externals || exit 1
stage_chezmoi managed --exclude=externals > "$STAGE/managed.txt" || exit 1
stage_chezmoi diff --exclude=externals > "$STAGE/remaining.diff" || exit 1
test ! -s "$STAGE/remaining.diff" || exit 1
```

Stop if any command fails; do not suppress template warnings. Check the target
list, rendered monitor and Git values, permissions, and Neovim link destination.
The staging destination differs from the real home; confirm rendered home paths
still refer to the intended machine. If the user chose symlink mode, change the
wrapper's mode and repeat the isolated check in a separate stage.

## 4. Back up, resolve conflicts, and apply

1. Compare every selected live target with the staged result, including
   symlinks and their parents. Ask the user how to reconcile each local edit or
   conflict. Do not paste private configuration or secrets into the conversation.
   Distinguish content changes, new files, permission changes, file-link
   replacements, folded-directory replacements, and explicit symlink changes.
   Count outermost folded links once rather than counting their linked children
   as independent installed links. Compare the old and new Neovim trees too:
   retargeting its directory link can introduce content changes not shown in a
   link-only comparison.
2. Present the exact backup paths, what will change, and how to restore each
   file or link. **Get approval** before creating backups or changing targets.
   Back up only affected items and record link destinations; preserve the old
   checkout, local edits, and unmanaged files. Never copy or delete the whole
   home, `.copilot`, or `.gnupg` runtime directory.
   Use a private backup directory. Save link objects without following them,
   recording both their original link text and resolved destination; relative
   links may not resolve from the backup location but must restore unchanged.
   Record original modes, file hashes, previously absent targets, and a journal
   of replacements. Snapshot affected old-source contents, external Git state,
   and unmanaged subtrees so preservation can be checked afterward.
3. The Neovim link template refuses an existing non-symlink target, so even
   `chezmoi diff` may fail before that conflict is resolved. Once explicitly
   approved and backed up, move the existing Neovim directory aside. Existing
   symlinks can be replaced; review and record their destinations first, and
   never delete the symlink's target.
4. Resolve only the approved Stow/file conflicts. Do not write through a folded
   parent symlink into the old checkout; agree on a safe replacement with the
   user first. Do not use a blanket Stow delete or a force option.
   Prepare real replacement directories separately, preserving existing
   contents, child symlinks, modes, and unmanaged Kanshi profiles. Compare them
   before replacing each approved outermost link, and resolve parents before
   children. Keep a per-target recovery path if replacement fails. Replacing a
   file link must replace the link object, not overwrite its old target.
5. Preview with `chezmoi --mode file diff --exclude=externals`, review the
   concrete target list, and **get approval**
   for the apply. Use the approved mode consistently. First-time existing
   files can be replaced even with `--error-on-conflict`; backups and review
   are still required.
   After resolving links, confirm the pending diff contains only the approved
   content, new-file, and permission changes. Recheck source fingerprints and
   the target list, and stop if a runtime file changed since its backup.
6. Apply only the agreed targets using `chezmoi --mode file apply
   --exclude=externals --error-on-conflict`, optionally listing the
   approved paths. Stop on errors or unexpected conflicts; do not force or
   discard local changes.
   Continue with external and legacy dependency migration. Finishing this
   normal-file phase alone does not complete the requested move.

## 5. External repositories and system setup

The 12 former top-level submodules are branch-tracking chezmoi Git externals.
Inspect `.chezmoiexternal.toml.tmpl`, the old checkouts, and each new
destination before fetching. Some destinations may already be symlinks or
contain local changes. Do not clone over them, update an old checkout through
a link, reset, stash, rebase, or discard work.

External migration is required, not an optional follow-up. Obtain approval for
how to preserve each existing destination, local state, and any upstream
updates. Use the configured repository URLs and transports unchanged. Include
the external phase in the original plan; do not make a normal-files-only plan
and defer these dependencies indefinitely.

1. Make `.tools` and `.modules` independent real directories before installing
   repositories beneath them. Back up their link objects without following
   them, and preserve non-repository children too.
2. Materialize each external as an independent repository at its configured
   destination. Preserve its working files, ignored build outputs, staged and
   unstaged changes, untracked files, local refs, and remotes. A fresh clone by
   itself does not preserve those. The i3status-rust source moves from the old
   config package to `~/.tools/i3status-rust`; keep the installed binary and
   build artifacts unless the user approves rebuilding.
3. Check `git rev-parse --absolute-git-dir` and the common Git directory for
   every external, initialized nested submodule, and untracked embedded
   repository. No metadata or object alternates may depend on the old
   checkout. Merely copying a submodule directory leaves its `.git` file
   pointing back to the old repository.
4. If metadata is copied, preserve its original copy, correct `core.worktree`,
   and normalize initialized nested repositories with Git's
   `submodule absorbgitdirs` where appropriate. Copied stale `.git/modules`
   stores can still be selected during recursive fetch even when ordinary
   status commands succeed. Reconcile those stores rather than leaving
   duplicate old worktree paths. Preserve untracked embedded repositories
   that are not listed by `git submodule foreach`.
5. Verify repository integrity and recursive submodule operations, not just
   top-level `git status`. Ensure each external follows the configured branch;
   preserve local history and stop on divergence rather than resetting it.
   Compare the original and new working contents and local state before any
   approved upstream refresh.
6. Exercise the real chezmoi external apply path, only after all parent/link
   conflicts are resolved. `chezmoi apply --include=externals` may run an
   initial pull even with `--refresh-externals=never`: that flag is not an
   adoption or revision-pinning mechanism. Review and record the fetched
   fast-forwards and preserved local changes. Subsequent intentional refreshes
   use `chezmoi apply --include=externals --refresh-externals=always`.
   Externals track upstream independently of the dotfiles revision.

Reconcile all remaining dependencies before retiring the old source:

- Audit live home links and relevant system links, including aliases into
  `.config`, Copilot's old `AGENTS.md`, the old i3status source path, and legacy
  configurations. Retarget equivalent aliases to their migrated destinations,
  preserve unique legacy contents independently, and back up any obsolete
  broken link before removing it. Do not silently drop valid files.
- Preserve dependent worktrees as independent repositories, including their
  exact HEAD, index, working edits, untracked/ignored files, and configured
  remotes. Verify the replacement before changing the live worktree path;
  retaining a worktree whose common Git directory is in the old checkout is
  not retirement.
- Audit installed launchers, build-tool source-location metadata, and referenced
  scripts for old paths. Preserve installed binaries. Distinguish historical
  build/debug paths and editor history from active dependencies, and report
  already-missing scripts rather than inventing unrelated replacements.
- Check inherited shell variables such as `SPACESHIP_ROOT` as well as file
  paths. A newly started shell can inherit an old exported theme root from
  its parent even after every link is replaced. Set required managed roots
  before loading their modules, and prove startup with the old source
  temporarily unavailable; successful startup while that source still exists
  can conceal a remaining dependency.
- Record a tested rollback path for the external, legacy, and worktree changes.
  Keep the original data and old repository as inactive rollback material.
  Do not remove broad directories or either source checkout as an implicit
  cleanup step.

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

- Check the full remaining chezmoi diff, including externals, Neovim link
  target, effective Git values, and availability of the selected signing key.
  Do not create a commit to test signing without approval.
- Verify target types and permissions as well as contents. Check the private
  local config, preserved Copilot data, old-source snapshots, external Git
  state, legacy links, and unmanaged profiles against the recorded baseline.
  Account explicitly for approved upstream changes rather than requiring
  refreshed tracked files to match their old revisions.
- Confirm every external and nested repository has independent Git metadata,
  any dirty worktree retains its edits independently, and no active link,
  launcher, or required source path points into the old checkout. Verify a
  fresh shell can load its migrated dependencies without the old source.
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
  Move new replacement directories and files aside before restoring originals,
  and restore recorded absence for newly created files. Report normal-target
  file and external phases together as the migration, and list application
  startup checks and desktop reloads separately. Do not claim completion while
  external or legacy dependencies still require the old checkout. Restarting
  applications or the desktop still requires its own approval.
