# Neovim PR review

[Installation](README.md#neovim).

## Setup and selection

Run `gh auth login` and open the repository. For fork checkouts, use
`gh repo set-default upstream` to select the PR's repository. Repository
mismatches are reported rather than checking out or commenting on the wrong PR.

Select with `\o` / `\O`, or use `\p` without a selection to resolve the current
branch's PR. Selection opens a read-only overview with the description, checks,
review status, and merge readiness; it does not check out the branch.
The overview also appears below the changed-files tree in `\p` / `\S`.
Use `\v` to toggle it and `gx` in the overview to open GitHub's full discussion.

Selections are repository/branch-scoped. Switching branches externally returns
ordinary files to branch-based PR discovery; an overview or existing diff still
targets the PR it displays.

## Checkout and diffs

`\C` requires confirmation and blocks tracked changes, untracked files, unsaved
buffers, or a changed pane/selection while confirming. It never uses `--force`.

`\p` compares against the PR's merge base, not just uncommitted changes. Browsing
accepts untracked files, tracked changes, unsaved edits, and locally merged/rebased
main changes without saving or discarding them.

If local HEAD equals the PR head, the working-tree side includes local edits.
Otherwise the diff uses read-only remote PR snapshots, excluding main-only local
changes. Missing snapshots are fetched from the PR's repository, not assumed to
be on `origin`. Browsing does not change the branch or publish reviews.

`\g` / `\d` shows local Git changes in native CodeDiff panes, not Lazygit.
CodeDiff downloads its native diff library on first use. Revision buffers retain
UTF-8 BOM metadata rather than displaying a false first-line change.

## Reading and addressing comments

`\c` loads comments even in dirty worktrees. Purple `C` signs and inline previews
follow the live buffer, including unsaved edits; `\t` opens the full thread.
PR comments do not count as compiler diagnostics.

Threads on edited or deleted code remain near the affected lines, marked
`[local edit]` / `[local deletion]`. These are approximate, read-only anchors:
their popup identifies the original PR line, and canonical GitHub coordinates
never change.

Posting or resolving requires a clean checkout and only maps unchanged,
contiguous ranges. Approximate anchors and new local lines cannot be used for
posting. If the checkout/PR changes or becomes dirty while drafting, sending is
blocked and the draft is retained.

Local-file comments require the selected PR branch or exact PR head. Before
checkout, use the right-hand PR snapshot in `\p`; unrelated local files receive
no PR comment signs. Changing checkout/repository clears comment context.
Toggle `\c` off/on to refresh remote comments; outdated threads are excluded and
background polling is disabled.

Use `\s` before commenting to batch a review; otherwise comments are posted
immediately. In the comment editor, `c` then `Enter` sends; `\u` submits the review.
Native `:GHLitePR*` commands bypass the integration's checkout guards and line
mapping: use the shortcuts for locally merged/rebased checkouts.

## Changes since your last review

`\S` / `:GitReviewSince` selects your latest submitted review, ignoring pending
reviews, and compares its commit directly with the current PR head, including
force-pushes. Missing reviewed commits are fetched from the PR's repository.
Local merges/rebases are supported, but tracked and unsaved changes block this
view.

Both sides are read-only. Comment or reply on the right with `\a`; start/submit
with `\s` / `\u` without closing the incremental view. Actions use current PR
coordinates, not incremental-diff positions.

Historical-side comments are blocked; GitHub may reject new threads outside the
PR's commentable diff. Missing history, unavailable commits, or identical trees
are reported rather than falling back to the full PR diff.
