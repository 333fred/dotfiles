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
