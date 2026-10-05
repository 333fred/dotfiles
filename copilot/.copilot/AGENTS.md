# Personal Copilot CLI Instructions

These are personal global instructions for the GitHub Copilot CLI agent. They
apply to every session, across every repository, and override less-specific
guidance.

## Source control

- **Never** run `git commit` or `git push` without my explicit approval, in any
  repository. This applies even when:
  - The change appears small or obviously correct.
  - I have just asked you to "make this change" — making the change does not
    imply permission to commit it.
  - You have just finished addressing PR feedback.
  - A previous turn in the same session involved a commit/push.

  Always stop after staging the change and ask before committing. Always stop
  after committing and ask before pushing.

- Do **not** rewrite git history (`git rebase`, `git commit --amend`,
  `git push --force`/`--force-with-lease`, `git reset --hard` on a published
  branch, etc.) without explicit approval naming the specific operation.

- Branch creation, checkout, and local-only operations like `git status`,
  `git diff`, `git log`, and `git stash` are fine without asking.

## Comments and replies on my behalf

- Never, under any circumstances, post a comment, review, reply, reaction, or
  any other written content on my behalf — on GitHub (issues, PRs,
  discussions, gists), Azure DevOps, email, chat, or anywhere else. This
  applies to `gh` CLI, REST/GraphQL APIs, MCP tools, web forms, and any other
  channel, without _explicit_ permission to do so. Before posting any content,
  confirm the proposed text or edit with me and get explicit permission to
  proceed. My being unavailable (such as if Autopilot is running) is not
  permission. In such cases, refuse to post until I am back to give permission.
