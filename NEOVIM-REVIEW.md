# Neovim review

[Installation](README.md#neovim).

## Review shortcuts

Open a review before commenting or submitting. The statusline shows its
destination: `PR owner/repo#123` for GitHub or `Local -> Copilot` for local feedback.

| Subject | Shortcuts |
| --- | --- |
| Reviews (`\r`) | `\rp` all PR changes, `\rl` local changes, `\rb` branch, `\rc` commits |
| Review lifecycle | `\rs` start, `\ru` submit, `\ra` approve PR, `\rd` discard (confirm), `\rq` close |
| Review tools | `\rP` since last submitted PR review, `\rm` mark file reviewed, `\rt` toggle read-only |
| PRs (`\p`) | `\po` all PRs, `\pO` relevant PRs, `\pv` description, `\pc` checkout |
| Comments (`\c`) | `\ca` add/reply (also visual selections), `\cf` file comment, `\co` open, `\cl` list |
| Comment tools | `\ct` annotations, `\ce` edit, `\cd` delete (confirm), `\cy` yank Markdown |
| Resolution | `\cr` resolve comment/thread, `\cR` reopen |
| Comment navigation | `\cj` next, `\ck` previous, in the current file |
| Diffs (`\d`) | `\df` file against HEAD, `\dh` history, `\de` focus explorer, `\dE` toggle explorer |
| Hunks (`\h`) | `\hp` preview, `\hs` stage, `\hu` unstage, `\hr` reset (stage/reset in diff panes) |
| Git (`\g`) | `\gb` toggle line blame |
| Merge conflicts (`\x`) | `\xt` theirs, `\xo` ours, `\xb` both, `\xx` discard; uppercase suffix applies to all |

`\j` / `\k` jump to the next/previous hunk; `\J` / `\K` jump to the
next/previous file in a diff. These also work from the PR overview.
Pause after a shortcut prefix for hints; `,?` shows mappings.

Comments use a word-wrapped text box. Ctrl+S saves/sends in normal or insert
mode; Esc cancels in normal mode (press twice from insert mode).
File-level comments are local-only. Approval is PR-only.

Closing a review keeps its comments. `\rd` confirms before discarding a pending
PR review or archiving and clearing local feedback. Local comments persist per
repository; inspect `\cl` if comments from another branch block submission.
`\rt` toggles editing of working-tree buffers; snapshots stay read-only.
`\rm` marks a file reviewed until its contents change.

## Copilot sessions and local feedback

`,aa` toggles the Copilot CLI terminal. Use `/resume` there to continue a conversation.
Esc enters Neovim Normal mode for shortcuts; `i` resumes terminal input.
Alt+Esc sends Escape to Copilot. Terminal bells pass through to the outer terminal
for attention alerts.
`,at` sends the current line or visual selection, and `,af` sends the current file.
Alt+Enter jumps to or accepts the next edit suggestion in normal/insert mode.
Run `:Copilot auth` once to sign in for next-edit suggestions.

Open `\rl`, `\rb`, or `\rc`, add comments with `\ca`, then use `\ru` to send
feedback with file and line locations to Copilot. Only new or edited unresolved
comments are sent; submitted comments stay saved and are not sent again.
`\cy` copies that pending feedback without sending it.
`\cl` lists all local comments with Pending, Submitted, or Resolved status.
Select one to open it, then use `\cr` to resolve, `\cR` to reopen, or `\cd` to
delete after confirmation. These shortcuts also work at the comment's code line.
Reopening makes the comment pending again.
`\rs` begins/resumes a feedback round without clearing comments.
If the repository, branch, or review changes while drafting, the text is
retained in a scratch buffer instead of being saved.

## Setup and selection

Run `gh auth login` and open the repository. For fork checkouts, use
`gh repo set-default upstream` to select the PR's repository. Repository
mismatches block checkout and commenting.

Select with `\po` / `\pO`, or use `\rp` without a selection to resolve the current
branch's PR. Selection opens an overview with the description, checks,
review status, and merge readiness without checking out the branch.
The overview also appears below the changed-files tree in `\rp` / `\rP`.
Use `\pv` to toggle it and `gx` in the overview to open GitHub's full discussion.

Selections belong to the current repository and branch. An open overview or
diff continues to target the PR it displays.

## Checkout and diffs

`\pc` requires confirmation and blocks tracked changes, untracked files, unsaved
buffers, or a changed pane/selection while confirming.

`\rp` shows all PR changes against the merge base. Browsing supports local edits
and merged/rebased branches without changing your files.

If local HEAD equals the PR head, the working-tree side includes local edits.
Otherwise the diff uses read-only PR snapshots. Missing snapshots are fetched
from the PR's repository.

`\rl` shows local Git changes. The diff library downloads on first use.

## Reading and addressing comments

`\ct` toggles comment annotations. Purple `C` signs and inline previews follow
local edits; `\co` opens the full thread.

Threads on edited or deleted code remain near the affected lines, marked
`[local edit]` / `[local deletion]`. These positions are approximate and read-only;
the popup shows the original PR line.

Posting or resolving requires a clean checkout and unchanged, contiguous PR
lines. If the checkout or PR changes while drafting, sending is blocked and
the draft is retained.

Local-file comments require the selected PR branch or exact PR head. Before
checkout, use the right-hand PR snapshot in `\rp`; unrelated local files receive
no PR comment signs. Toggle `\ct` off/on to refresh comments; outdated threads
are excluded.

Use `\rs` before commenting to batch a review; otherwise comments are posted
immediately when saved with Ctrl+S. `\ru` submits the review; `\ra` approves
the PR (including any pending review). `\cl` lists threads in quickfix at their
original PR locations.

## Changes since your last review

`\rP` / `:GitReviewSince` selects your latest submitted review, ignoring pending
reviews, and compares its commit with the current PR head. Missing commits are
fetched from the PR's repository. Save and commit or stash local changes first.

Both sides are read-only. Comment or reply on the right with `\ca`; start/submit
with `\rs` / `\ru` without closing the diff.

Historical-side comments are blocked; GitHub may reject new threads outside the
PR's commentable diff. Unavailable history or no changes are reported.
