# Neovim cheat sheet

[Installation and configuration](README.md#neovim).

`,` is the editor leader; `\` is the Git/review leader. Shortcuts use Normal mode
unless noted otherwise. Press `,?` to open this sheet in a read-only floating
buffer; `Esc` or `q` closes it.

## Files, buffers, and panes

| Key | Action |
| --- | --- |
| `,?` | Open this cheat sheet |
| `,e` | Toggle the file tree |
| `,f` / `,b` | Find a file / open buffer |
| `[b` / `]b` | Previous / next buffer in the top bar |
| `,x` | Close the buffer without closing its pane; prompts for unsaved changes |
| `Alt+h/j/k/l` | Focus the left / lower / upper / right pane; also works in Insert and Terminal modes |
| `` Ctrl+` `` | Toggle the terminal pane; also works in Insert and Terminal modes |
| `<Space>` | Toggle a fold; folds start open |
| `Esc` | Clear search highlighting |

In the file tree, `H` / `I` toggle hidden / ignored files. `Esc` exits search
without closing the tree. The file picker includes hidden files but excludes
Git-ignored files.

The top bar shows open files and compiler diagnostic counts. Click a tab to
switch buffers; right-click or middle-click closes it with the same prompt as
`,x`. PR descriptions remain listed as `repo#number`. Picker, terminal, and
historical revision buffers are excluded.

## Code navigation and editing

| Key | Action |
| --- | --- |
| `gd` / `gi` | Go to definition / implementation; jump directly for one result, otherwise show a floating preview picker |
| `gr` | Find references |
| `,m` / `,,` | Find document / workspace symbols |
| `,h` / `,l` | Jump back / forward |
| `Ctrl+Space` | Show completions in Insert mode |
| `Up` / `Down`, `Enter` | Select and accept a completion in Insert mode |
| `Ctrl+S` | Open LSP signature help in Insert mode, inside an argument list |
| `Ctrl+.` | Show quick fixes and code actions; also works in Insert and Visual modes |
| `Ctrl+Backspace` | Delete the previous word in Insert or command-line mode |
| `Ctrl+Shift+C` | Copy a Visual selection to the system clipboard |
| `;` | Remapped to `:` |
| `j` / `k` | Move down / up by displayed lines when text wraps |

Errors and warnings appear inline and in the gutter. Signature help and other
LSP actions require support from an attached language server.

## Git and PR review

| Key | Action |
| --- | --- |
| `\g` / `\d` | Open local Git changes in CodeDiff; close the current CodeDiff view when already inside it |
| `\f` | Diff the current file against HEAD |
| `\b` | Toggle current-line Git blame |
| `\h` | Preview the current Git hunk inline; moving the cursor dismisses it |
| `\j` / `\k` | Next / previous changed block in ordinary files, CodeDiff, or native diff panes |
| `\o` | Open the PR picker |
| `\O` | PRs mentioning, assigned to, or requesting review from you or the Roslyn compiler team |
| `\p` | Open the selected/current-branch PR's changed-files tree and description; close when already inside CodeDiff |
| `\v` | View the PR description; toggle its pane inside CodeDiff |
| `\C` | Check out the selected PR after confirmation |
| `\S` | Compare your last submitted review's commit with the current PR head |
| `\c` | Load/show PR comments inline and in the gutter, or hide them |
| `\t` | Show the full thread on the current line; press again or `Esc` to close |
| `\a` | Add a PR comment/reply at the cursor or on a Visual selection |
| `\r` | Resolve the current PR comment thread |
| `\s` / `\u` | Start / submit a pending PR review |

### Inside CodeDiff

| Key | Action |
| --- | --- |
| `Enter` | Select a file in the changed-files explorer |
| `\e` / `\E` | Focus / toggle the changed-files explorer |
| `\J` / `\K` | Next / previous changed file |
| `t` | Toggle inline / side-by-side layout |
| `gf` | Return to the file in the previous tab |
| `q` | Close the diff tab |
| `-` | Stage / unstage the current file in the explorer |
| `S` / `U` | Stage / unstage all files in the explorer |
| `\hs` / `\hu` / `\hr` | Stage / unstage / discard a hunk |
| `g?` | Show available actions |

Merge-conflict actions also use `\`:

| Key | Action |
| --- | --- |
| `\ct` / `\cT` | Accept incoming for the current / all conflicts |
| `\co` / `\cO` | Accept current for the current / all conflicts |
| `\cb` / `\cB` | Accept both for the current / all conflicts |
| `\cx` / `\cX` | Discard the current / all conflicts |

CodeDiff downloads its native diff library on first use. Revision buffers retain
UTF-8 BOM metadata rather than displaying a false first-line change.

### Selecting and browsing a PR

Run `gh auth login` and open the repository. For fork checkouts, use
`gh repo set-default upstream` to select the PR's repository. A repository
mismatch is reported rather than checking out or commenting on the wrong PR.

Select with `\o` / `\O` (up to 100 results), or use `\p` without a selection
to resolve the current branch's PR. Selecting opens a read-only overview, not a
checkout. It includes the description, checks and individual results,
review/signoff and reviewer states, pending reviewers, merge readiness/conflicts,
auto-merge, labels, assignees, change counts, and timestamps. Missing or undecided
status is explicit, not assumed passing or approved.

The same overview appears below the changed-files tree in `\p` / `\S`.
`\v` toggles it there, or reopens it outside a diff. In a PR overview, `gx`
opens GitHub for the full discussion and management actions; `q` closes the view.
`,f` opens a file in the overview's pane and retains the description as a hidden
buffer. Use its buffer-bar entry or `[b` / `]b` to return.

`\C` requires confirmation and blocks tracked changes, untracked files, unsaved
buffers, or a changed pane/selection while confirming. It never uses `--force`.
Selections are repository/branch-scoped: switching externally returns ordinary
files to branch-based PR discovery; an overview or existing diff still targets
the PR it displays.

`\p` compares against the PR's merge base, not just uncommitted changes. It accepts
untracked files, uncommitted changes, unsaved edits, and locally merged/rebased main
changes. If local HEAD equals the PR head, its working-tree side includes local
edits without saving or discarding them. Otherwise it uses read-only remote PR
snapshots, excluding main-only local changes. Missing snapshots are fetched from
the PR's repository, not assumed to be on `origin`. Browsing does not change the
branch/worktree or automatically publish reviews.

### Reading and addressing comments

`\c` works in dirty worktrees. Purple `C` signs and inline author/message previews
follow the live buffer, including unsaved edits; `\t` opens the full thread.
PR comments do not count as compiler diagnostics.

Threads on edited or deleted code remain near the affected lines, marked
`[local edit]` / `[local deletion]`. These are approximate, read-only display
anchors; their popup identifies the original PR line. Canonical GitHub coordinates
never change. Posting/resolving still requires a clean checkout and only maps
unchanged, contiguous ranges; approximate anchors cannot be used for posting.
New local lines cannot receive PR comments. If the checkout/PR changes or becomes
dirty while drafting, sending is blocked and the draft is retained.

Local-file comments require the selected PR branch or exact PR head. Before
checkout, use the right-hand PR snapshot in `\p`; unrelated local files receive no
PR comment signs. Changing checkout/repository clears comment context. Toggle
`\c` off/on to refresh remote comments; loading is paginated, excludes outdated
threads, and does not jump to quickfix. Background polling is disabled.

Use `\s` before commenting to batch a review; otherwise comments are posted
immediately. In the comment editor, `c` then `Enter` sends; `\u` submits the review.
Native `:GHLitePR*` commands bypass the integration's checkout guards and line
mapping: use the shortcuts for locally merged/rebased checkouts.

### Changes since your last review

`\S` / `:GitReviewSince` selects your latest submitted review, ignoring pending
reviews, and compares its commit directly with the current PR head, including
force-pushes. Missing reviewed commits are fetched from the PR's repository.
Local merges/rebases are supported, but tracked and unsaved changes still block
this view.

Both sides are read-only. Navigate with `\j` / `\k` and `\J` / `\K`; comment or
reply on the right with `\a`, and start/submit with `\s` / `\u` without closing the
incremental view. Actions use current PR coordinates, not incremental-diff
positions. Historical-side comments are blocked; GitHub may reject new threads
outside the PR's commentable diff. Missing history, unavailable commits, or
identical trees are reported rather than falling back to the full PR diff.

### PR commands

| Command | Action |
| --- | --- |
| `:GitReviewDescription` | View/toggle the selected PR description |
| `:GitReviewCheckout` | Confirm checkout of the selected PR |
| `:GitReviewSince` | Changes since your latest submitted review |
| `:Roslyn target` | Select a C# solution when needed |

## Optional Lazygit

Lazygit remains an alternative terminal Git interface; `\g` uses native CodeDiff,
not its popup. In Lazygit, `Esc` dismisses a dialog or exits at the top level;
`q` quits.

Install with `sudo apt install lazygit` on Ubuntu 25.10 or later, or download it:

```bash
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
LAZYGIT_ARCH=$(uname -m | sed -e 's/aarch64/arm64/')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${LAZYGIT_ARCH}.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit -D -t /usr/local/bin/
rm lazygit lazygit.tar.gz
```
