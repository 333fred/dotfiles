---
name: update-and-apply
description: Update this repository's configured chezmoi source and apply its dotfiles. Use when asked to pull the latest dotfile changes, check local diffs, or apply chezmoi updates.
---

# Update and apply dotfiles

Use the configured chezmoi source and its Git upstream. Preserve local commits
and changes; never stash, discard, rebase, or force-pull them.

1. Find the source and inspect its Git state:

   ```sh
   source_dir="$(chezmoi source-path)" || exit 1
   git -C "$source_dir" status --short --branch
   ```

   If there are local changes, do not pull. Show the actual output of
   `git diff` and `git diff --cached` for tracked changes, and report untracked
   paths separately. Do not substitute a prose description for the diff. Ask
   whether to commit the changes or leave them untouched. Never commit without
   explicit approval. If approved, stage only the approved paths, then stop and
   ask for approval again before committing. After an approved commit, check
   the Git state again and continue only if the source is clean.

2. If the source is clean and has a configured upstream, pull with
   `git -C "$source_dir" pull --ff-only`. Do not override the configured remote
   or branch. Check the Git status again after pulling.

   If the pull fails, inspect the Git status. If it remains clean and shows
   that local and upstream commits have diverged, merge the configured
   upstream instead of stopping:

   ```sh
   git -C "$source_dir" merge --no-edit '@{upstream}'
   ```

   Never rebase or reset local commits. If the merge conflicts, inspect both
   sides and resolve only when the intended combined result is clear and
   preserves both changes; otherwise stop and ask how to proceed. After a
   successful merge, verify the Git status. For pull failures other than a
   clean divergence, stop and report the failure.

3. Preview the dotfile changes with:

   ```sh
   chezmoi diff
   ```

   If the diff reports an error or reveals a conflict, stop before applying.

4. Preflight the complete update, including externals:

   ```sh
   chezmoi apply --dry-run --refresh-externals=always --error-on-conflict
   ```

   If the config-template warning says to regenerate the config, include
   `--init` in both the preflight and the eventual apply command.

5. On any conflict, do not use `--force` or continue applying. For a managed
   target, show the actual `chezmoi diff` output. For an
   external Git repository, find its destination in
   `.chezmoiexternal.toml.tmpl`, then show the actual output of its
   `git status --short --branch`, `git diff`, and `git diff --cached`; also
   show `git diff HEAD..@{upstream}` if that upstream ref is available. Report
   untracked paths separately. Do not substitute a prose description for the
   diff. Then use `ask_user` or the interactive equivalent to ask whether to
   overwrite, preserve/merge, or skip the affected target. Wait for explicit
   approval. If approved, apply only the specifically approved target or
   targets; never force unrelated targets. Stop if preserving or merging
   requires changes the user has not approved.

6. If preflight succeeds without conflicts, apply all targets and refresh
   externals together:

   ```sh
   chezmoi apply --refresh-externals=always --error-on-conflict
   ```

   Add `--init` if the config template changed. Do not add `--force`.

7. Verify with `chezmoi status`, `chezmoi diff`, the source
   Git status, and the status of each external repository. Report any remaining
   diff or error; do not claim the update is complete until verified.
