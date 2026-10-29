# Neovim review

[Installation](README.md#neovim).

## Shortcuts

Open a review before commenting or submitting. The statusline shows whether it
targets a PR or local feedback for Copilot. Pause after a prefix for shortcuts;
`,?` shows all mappings.

| Prefix | Purpose |
| --- | --- |
| `\r` | Open, submit, and manage reviews |
| `\p` | Select or check out PRs and view their descriptions |
| `\c` | Add and manage comments |
| `\d` | Diffs |
| `\h` | Hunks |
| `\x` | Merge conflicts |

Use `\rp` to review a PR, `\rl` for local changes, `\rb` for branch changes,
or `\rc` for commits. `\ca` adds a comment, `\rs` starts a review, and `\ru`
submits it. Comment editors use Ctrl+S to save or send and Esc to cancel.
File comments are local-only; approval is PR-only.

## Copilot feedback

`,aa` toggles the Copilot CLI terminal; use `/resume` to continue a session.
Esc enters Neovim Normal mode, `i` resumes terminal input, and Alt+Esc sends
Escape to Copilot. Run `:Copilot auth` once for next-edit suggestions.

Local feedback persists per repository. `\ru` sends only new or edited
unresolved comments; submitted comments remain saved. `\cl` lists comments,
and `\cy` copies pending feedback without sending it. Closing a review keeps
comments; `\rd` confirms before discarding them. If the repository, branch, or
review changes while drafting, the draft is retained in a scratch buffer.

## PR reviews

Run `gh auth login`; for fork checkouts, use `gh repo set-default upstream` to
select the PR's repository. Select a PR with `\po` or `\pO`, or use `\rp` to
resolve the current branch's PR. The overview includes checks and review status;
`gx` opens the GitHub discussion.

PR checkout (`\pc`) requires confirmation and a clean checkout, including
untracked files and unsaved buffers. Browsing a PR diff does not change files:
the working tree is shown when HEAD matches the PR head, otherwise the PR
snapshots are read-only.

`\rp` loads existing comments; `\ct` toggles their annotations, even in a dirty
worktree. Comments on edited or deleted lines use approximate, read-only
positions. Posting or resolving requires a clean checkout and unchanged,
contiguous PR lines; a draft is retained if the checkout or PR changes while
drafting. Before checkout, comment on the right-hand PR snapshot instead of
unrelated local files. Use `\rs` to batch comments in a review; otherwise they
are posted when saved.

`\rP` compares the latest submitted review with the current PR head. Save and
commit or stash local changes first. Both sides are read-only, and new comments
must be on the right; GitHub may reject threads outside the commentable diff.
