# Windows migration guide for Copilot

Migrate one native Windows installation to this chezmoi source. This guide
authorizes no changes by itself: get the user's approval at the gates below.
Do not use WSL. Do not commit, push, change branches, install software, alter
system settings, or modify the live home merely because this guide says how.

## 1. Establish the source and scope

1. Ask the user which Windows machine, reviewed branch/revision, and target
   scope to migrate. If the desired revision is uncommitted or unavailable,
   stop and ask how to make it available; cloning does not copy uncommitted
   changes. Do not commit or publish it without separate approval.
2. Check `chezmoi --version`, `git --version`, and whether Neovim, gh, Copilot,
   Delta, .NET/dnx, GPG, and the compiler/Tree-sitter prerequisites are present.
   Ask before installing or upgrading anything. Do not enable Developer Mode
   or change privileges; if creating a symlink fails, report it and ask.
3. Run `$Source = chezmoi source-path` to find the configured source; stop if
   the command fails. The standard
   Windows default is `$HOME\.local\share\chezmoi`; configuration or XDG
   settings may change it. Config and state normally live under
   `$HOME\.config\chezmoi`, with cache under `$HOME\.cache\chezmoi`; XDG or
   explicit settings may change those paths. Inspect the existing chezmoi
   configuration and state without exposing secrets. If the configured source
   is nonstandard or the standard location already contains another
   installation, stop and ask how to reconcile it. Do not overwrite or move
   existing files automatically. The source config template expects JSON and
   refuses to initialize over an existing non-JSON chezmoi configuration;
   agree on any format migration before proceeding.
4. If the standard source already exists, inspect it with `git -C "$Source"
   status --short --branch` and `git -C "$Source" worktree list`, preserving
   unrelated changes. Ask whether it is the intended reviewed revision; do
   not reinitialize or update it without approval.
5. If the standard source is available and the chosen branch is accessible,
   **ask before initializing**. After approval, set `$Branch` to the approved
   branch and use `chezmoi init --ssh --branch "$Branch" 333fred/dotfiles`.
   This initializes the standard source without applying it to the home. Use
   the approved origin and transport if they differ; never use `--apply` here.
   Verify the resulting branch, origin, and status before proceeding.

Keep this standard source directory in place: the Neovim link points into it.
The global `work` value is computed during `chezmoi init`; rerun initialization
after a hostname or login change. Initialization also detects PowerShell 7's
`$PROFILE.CurrentUserAllHosts`, selecting either the standard Documents path
or Microsoft OneDrive Documents. Other profile locations fail initialization
until source support is added. Rerun initialization after changing Documents
redirection. Use PowerShell natively.

## 2. Check destinations and local behavior

Inspect paths and link targets without changing them. Do not print or share
tokens, private keys, Copilot sessions, or entire configuration files.

```powershell
$env:COMPUTERNAME
$env:USERPROFILE
$env:LOCALAPPDATA
[Environment]::GetFolderPath('MyDocuments')
$PROFILE.CurrentUserAllHosts
Get-Command nvim, git, chezmoi, gh, copilot, delta, dnx, gpg -ErrorAction SilentlyContinue
git config --global --show-origin --get-all user.email
git config --global --show-origin --get-all user.signingkey
git config --global --show-origin --get-all gpg.program
git config --global --show-origin --get-all core.sshCommand
```

For an installed Neovim, get its actual config path without loading the user's
config: `nvim --headless -u NONE -i NONE -n -c 'lua print(vim.fn.stdpath("config"))' -c qa`.
Check whether the existing Neovim target is a directory or link, and record
any link target. Inspect the three managed Copilot files individually:
`copilot-instructions.md`, `settings.json`, and `lsp-config.json`. Also check
for an old global `AGENTS.md` and ask the user which instruction content to
keep. Leave the rest of `.copilot` alone.

**Confirm with the user before continuing:**

- The source maps Neovim to `$HOME\AppData\Local\nvim`, PowerShell to
  `Profile.ps1` under the detected `data.powershellProfileDirectory`, and
  Terminal to the packaged
  `Microsoft.WindowsTerminal_8wekyb3d8bbwe` LocalState. Compare those with
  `%LOCALAPPDATA%`, Neovim's reported path, `$PROFILE.CurrentUserAllHosts`,
  redirected Documents, and the actual Terminal installation. If they differ,
  stop and agree on source changes or a different rollout.
- The Git template selects email by work classification and signing key by
  hostname. It no longer includes the old `.gitconfig.user` or
  `.gitconfig.local` files.
  Compare the effective settings, confirm which values should win, and
  preserve and reconcile any needed settings from those files before applying.
  Machine-specific trusted directories can be supplied as
  `data.gitSafeDirectories` in the local chezmoi configuration.
- Check the configured Windows GPG and OpenSSH paths, and Delta. The template
  locates GPG through `PATH`. Do not deploy a known-broken signing configuration.
- The Copilot settings template accepts the machine-specific agent-host block
  as `data.copilotAhpEnvironment` in the local chezmoi configuration.
  Preserve it locally where needed, without committing machine identifiers.
  Compare the rendered result with the live file, including permission,
  tool-availability, and privacy settings.
- Confirm normal file mode versus chezmoi symlink mode. Neovim is always a
  directory link; templated Copilot settings remain a copy, while other
  eligible files may link to source. The whole `.copilot` directory must
  remain a real runtime directory.

## 3. Preview in an isolated destination

After the user approves creating disposable test files, make a unique scratch
directory. These temporary path overrides isolate the test; they do not change
chezmoi's normal source, config, cache, or state paths.

```powershell
$Stage = Join-Path ([IO.Path]::GetTempPath()) ("chezmoi-migration-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Stage -ErrorAction Stop | Out-Null
New-Item -ItemType Directory -Path "$Stage\home" -ErrorAction Stop | Out-Null
$StageConfig = chezmoi execute-template '{{ dict "data" (dict "work" .work "powershellProfileDirectory" .powershellProfileDirectory) | toJson }}'
if ($LASTEXITCODE -ne 0) { throw 'Could not read approved template data' }
New-Item -ItemType File -Path "$Stage\config.json" -Value $StageConfig -ErrorAction Stop | Out-Null
$StageArgs = @('--source', $Source, '--destination', "$Stage\home",
  '--config', "$Stage\config.json", '--persistent-state', "$Stage\state.db",
  '--cache', "$Stage\cache", '--mode', 'file', '--no-tty', '--error-on-conflict')
chezmoi @StageArgs apply --exclude=externals
if ($LASTEXITCODE -ne 0) { throw 'Isolated apply failed' }
chezmoi @StageArgs managed --exclude=externals
if ($LASTEXITCODE -ne 0) { throw 'Could not list isolated targets' }
chezmoi @StageArgs diff --exclude=externals
if ($LASTEXITCODE -ne 0) { throw 'Isolated diff failed' }
```

Check that the Neovim target is a symlink to the approved checkout and that
only intended Windows files are managed. Compare the rendered Git settings
and Copilot payload with the user's choices. If symlinks are unavailable, a
path is wrong, or the user wants symlink mode for eligible files, stop and
resolve that decision before proceeding.

## 4. Back up, resolve conflicts, and apply

1. Inventory the actual targets from the isolated `managed` output and inspect
   existing files, directories, symlinks, and **parent** links. Compare local
   edits with the proposed source. Do not expose private contents in the
   conversation. Ask the user which version to keep whenever they differ.
2. Propose a backup location and the exact affected paths and link targets.
   **Get approval** before creating backups or changing any target. Back up
   the affected files and record their original link destinations; do not copy
   or delete the entire home, `.copilot`, or other runtime directories.
3. The Neovim link template refuses an existing non-symlink target, so even
   `chezmoi diff` may fail before that conflict is resolved. Once its backup
   and replacement are specifically approved, move the existing Neovim
   directory aside. An existing symlink can be replaced: review and record its
   target first. Never remove its target tree.
4. Preview the real-home changes with
   `chezmoi --mode file diff --exclude=externals`.
   Review every affected target and ask for approval of the concrete apply
   plan. If the user chose another mode, use that same mode for preview and
   apply. First-time existing files can be replaced even with
   `--error-on-conflict`; that flag is not a substitute for backups and review.
5. Only after approval, apply the agreed targets with `chezmoi --mode file apply
   --exclude=externals --error-on-conflict`, or
   specify the approved individual target paths. Stop on errors or unexpected
   conflicts; do not use `--force` or discard local changes.

## 5. Verify and hand off

- Check `chezmoi --mode file diff --exclude=externals`,
  the Neovim link target, and effective Git email, signing key, GPG, SSH, and
  pager settings. Confirm the selected signing key is actually available; do
  not create a commit just to test it without approval.
- With the user's permission, launch Neovim and check its config, plugin
  bootstrap, and C# tooling. Plugin installation changes local state. Check
  Copilot's `/instructions` and LSP only with permission; do not authenticate,
  send prompts, or submit GitHub reviews on the user's behalf without approval.
- Separately ask whether the user wants the winget inventory applied, the
  PowerToys backup restored, fonts installed, PowerShell modules installed, or
  the SSH agent's service settings changed. None of these is a chezmoi apply
  step, and the historical inventory may not include current prerequisites.
- Report the source path, selected mode, backup paths, remaining prerequisites,
  and any checks not performed. Keep backups and old checkouts until the user
  approves their removal.
- For rollback, get approval and restore only the recorded targets and original
  link destinations from the backup. Do not remove the whole home or delete a
  symlink's target. Keep the checkout available while Neovim points to it.
