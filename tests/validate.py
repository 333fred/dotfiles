"""Validate deployment only in an explicitly supplied disposable directory."""
import argparse
import json
import os
import shutil
import subprocess
import tomllib
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--chezmoi", required=True)
parser.add_argument("--scratch", required=True, type=Path)
parser.add_argument("--externals", action="store_true")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
scratch = args.scratch.resolve()
if scratch == Path.home() or scratch == root or scratch in root.parents:
    raise SystemExit("Refusing a live home or repository destination")
scratch.mkdir(parents=True, exist_ok=True)
platform = "windows" if os.name == "nt" else "linux"


def run(*command, **kwargs):
    result = subprocess.run(command, text=True, encoding="utf-8", capture_output=True, **kwargs)
    if result.returncode:
        print(result.stderr, flush=True)
        raise subprocess.CalledProcessError(result.returncode, command, result.stdout, result.stderr)
    return result.stdout


def command(name, mode="file", source=root):
    state = scratch / name
    state.mkdir(exist_ok=True)
    dest = state / "home"
    dest.mkdir(exist_ok=True)
    config = state / "config.json"
    config.write_text(json.dumps({
        "tempDir": str(state), "scriptTempDir": str(state),
        "git": {"autoCommit": False, "autoPush": False},
    }))
    return dest, [args.chezmoi, "--source", str(source), "--destination", str(dest),
                  "--config", str(config), "--persistent-state", str(state / "state.db"),
                  "--cache", str(state / "cache"), "--mode", mode,
                  "--no-pager", "--no-tty", "--error-on-conflict"]


dest, cm = command("copies")
excluded = [] if args.externals else ["--exclude=externals"]
run(*cm, "apply", *excluded)
assert not run(*cm, "diff", *excluded).strip(), "Repeat application is not clean"
run(*cm, "apply", *excluded)

nvim = dest / ("AppData/Local/nvim" if platform == "windows" else ".config/nvim")
assert (nvim / "init.lua").is_file()
assert json.loads((nvim / "lazy-lock.json").read_text())
canonical_nvim = root / ".chezmoitemplates/nvim"
assert nvim.is_symlink()
assert nvim.resolve() == canonical_nvim.resolve()
for source in canonical_nvim.rglob("*"):
    if source.is_file():
        assert (nvim / source.relative_to(canonical_nvim)).read_bytes() == source.read_bytes()
assert (dest / ".copilot/copilot-instructions.md").exists()
assert not (dest / ".copilot/config.json").exists()
assert not (dest / ".copilot/session-state").exists()
assert (dest / ".gitconfig").is_file()
assert not (dest / ".gitconfig.linux").exists()
assert not (dest / ".gitconfig.windows").exists()
assert not (dest / (".fonts" if platform == "windows" else "AppData")).exists()
assert (dest / ".vsvimrc").read_text().splitlines() == (root / "dot_vsvimrc").read_text().splitlines()

repository_only = (
    "README.md", "NEOVIM-REVIEW.md", "MIGRATION-LINUX.md",
    "MIGRATION-WINDOWS.md", "LICENSE", ".gitignore",
    "installed_packages.txt", "monaspace_frozen.css",
    "gnupg", "powertoys", "winget", "tests",
)


def check_repository_exclusions(cm):
    targets = run(*cm, "managed", "--exclude=externals").splitlines()
    assert not any(
        target == ignored or target.startswith(ignored + "/")
        for target in targets for ignored in repository_only
    ), "Repository-only files entered the target state"
    return targets


check_repository_exclusions(cm)


def external_repositories(cm):
    return tomllib.loads(run(*cm, "execute-template", "--file",
                             str(root / ".chezmoiexternal.toml.tmpl")))


def check_external_branches(destination, externals):
    for target, external in externals.items():
        clone_args = external["clone"]["args"]
        branch = clone_args[clone_args.index("--branch") + 1]
        checkout = destination / target
        assert run("git", "-C", str(checkout), "branch", "--show-current").strip() == branch
        assert run("git", "-C", str(checkout), "rev-parse", "--abbrev-ref", "@{upstream}").strip() == "origin/" + branch
        run("git", "-C", str(checkout), "merge-base", "--is-ancestor", "HEAD", "@{upstream}")


def git_config(config, key, *, missing=False):
    result = subprocess.run(
        ["git", "config", "--file", str(config), "--includes", "--get", key],
        text=True, capture_output=True,
    )
    if missing and result.returncode == 1:
        return None
    if result.returncode:
        raise subprocess.CalledProcessError(result.returncode, result.args, result.stdout, result.stderr)
    if missing:
        raise AssertionError(f"Unexpected Git setting {key}: {result.stdout}")
    return result.stdout.strip()


rendered_configs = {}
for os_name, hostname in (
    ("windows", "FRED-DESK"),
    ("linux", "fred-desk"),
    ("linux", "frsilb-desk"),
    ("linux", "FRSILB-DESK"),
    ("windows", "work-laptop"),
    ("linux", "work-laptop"),
):
    rendered, rc = command(f"{os_name}-{hostname}-render")
    data = {"chezmoi": {"os": os_name, "hostname": hostname, "homeDir": "/home/example user"}}
    render_cm = [*rc, "--override-data", json.dumps(data)]
    targets = check_repository_exclusions(render_cm)
    assert ".gitconfig" in targets
    assert ".gitconfig.linux" not in targets and ".gitconfig.windows" not in targets
    assert run(*render_cm, "cat", str(rendered / ".vsvimrc")).splitlines() == \
        (root / "dot_vsvimrc").read_text().splitlines()
    config = rendered / ".gitconfig"
    config.write_text(run(*render_cm, "cat", str(config)), encoding="utf-8")
    assert git_config(config, "merge.conflictstyle") == "zdiff3"
    assert git_config(config, "pull.ff") == "only"
    assert git_config(config, "core.pager") == "delta"
    signing_key = (
        "4305D17549D17C130E4F4FEE855E17DE1D09184F"
        if hostname.lower() == "fred-desk"
        else "66C04B3419EC346816F3C2275D1C0E06CE5CD929"
    )
    assert git_config(config, "user.signingkey") == signing_key
    git_config(config, "include.path", missing=True)
    if os_name == "windows":
        assert not any(p.startswith(".config/regolith3/") for p in targets)
        assert git_config(config, "user.email") == "fred@silberberg.xyz"
        assert git_config(config, "core.sshCommand") == "C:/Windows/System32/OpenSSH/ssh.exe"
        assert git_config(config, "gpg.program") == r"C:\Program Files (x86)\gnupg\bin\gpg.exe"
        git_config(config, "credential.helper", missing=True)
    else:
        basesettings = run(*render_cm, "cat", str(
            rendered / ".config/regolith3/i3/config.d/10_basesettings"
        ))
        main_output, secondary_output = (
            ("DP-2", "DP-0") if hostname.lower() == "frsilb-desk" else ("DP-4", "DP-2")
        )
        for workspace in ("$ws1", "$ws2", "$ws3"):
            assert f"workspace {workspace} output {main_output}" in basesettings.splitlines()
        assert f"workspace $ws4 output {secondary_output}" in basesettings.splitlines()
        assert "$wm.mainOutput" not in basesettings and "$wm.secondaryOutput" not in basesettings
        bars = run(*render_cm, "cat", str(rendered / ".config/regolith3/i3/config.d/70_bar"))
        assert f"    output {main_output}" in bars.splitlines()
        assert f"    tray_output {main_output}" in bars.splitlines()
        assert f"    output {secondary_output}" in bars.splitlines()
        assert "    tray_output none" in bars.splitlines()
        assert "$wm.mainOutput" not in bars and "$wm.secondaryOutput" not in bars
        assert git_config(config, "user.email") == "frsilb@microsoft.com"
        assert git_config(config, "credential.helper") == "/home/example user/.dotnet/tools/git-credential-manager"
        assert git_config(config, "credential.credentialStore") == "cache"
        assert git_config(config, "credential.azrepos:org/devdiv.username") == "frsilb@microsoft.com"
        git_config(config, "core.sshCommand", missing=True)
        git_config(config, "gpg.program", missing=True)

    (rendered / ".gitconfig.user").write_text(
        "[core]\n  editor = prototype-user-editor\n"
        "[user]\n  email = user@example.test\n  signingkey = old-user-key\n"
    )
    assert git_config(config, "core.editor") == "vim"
    assert git_config(config, "user.email") == (
        "fred@silberberg.xyz" if os_name == "windows" else "frsilb@microsoft.com"
    )
    assert git_config(config, "user.signingkey") == signing_key
    (rendered / ".gitconfig.local").write_text(
        "[core]\n  editor = prototype-local-editor\n"
        "[user]\n  email = local@example.test\n  signingkey = local-key\n"
    )
    assert git_config(config, "core.editor") == "vim"
    assert git_config(config, "user.email") == (
        "fred@silberberg.xyz" if os_name == "windows" else "frsilb@microsoft.com"
    )
    assert git_config(config, "user.signingkey") == signing_key
    rendered_configs[os_name] = (rendered, render_cm, targets)

(dest / ".gitconfig.local").write_text("[core]\n  editor = prototype-local-editor\n")
assert git_config(dest / ".gitconfig", "core.editor") == "vim"
assert not run(*cm, "diff", *excluded).strip()
(dest / ".gitconfig.local").unlink()

settings = dest / ".copilot/settings.json"
original = settings.read_bytes()
settings.write_bytes(original + b"\n")
conflict = subprocess.run([*cm, "apply", "--include=files", str(settings)],
                          text=True, capture_output=True)
assert conflict.returncode != 0, "Local edits were silently overwritten"
settings.write_bytes(original)

if args.externals and platform == "linux":
    externals = external_repositories(cm)
    check_external_branches(dest, externals)
    run(*cm, "apply", "--include=externals", "--refresh-externals=always")
    check_external_branches(dest, externals)

if platform == "windows":
    rendered, linux, targets = rendered_configs["linux"]
    assert ".config/nvim" in targets
    assert not any(p.startswith(".config/nvim/") for p in targets)
    assert ".fonts" in targets and ".zshrc" in targets
    assert not any(p.startswith(("AppData", "Documents")) for p in targets)
    externals = external_repositories(linux)
    print("Linux target selection, Git, and host-specific monitor rendering: passed (not Linux runtime validation)")
    if args.externals:
        run(*linux, "apply", "--include=externals")
        check_external_branches(rendered, externals)
        run(*linux, "apply", "--include=externals", "--refresh-externals=always")
        check_external_branches(rendered, externals)
        print(f"All {len(externals)} externals cloned and refreshed on their declared branches using native Git")

links, lc = command("symlink-mode", "symlink")
run(*lc, "apply", "--exclude=externals")
assert (links / nvim.relative_to(dest)).is_symlink()
link = links / ".copilot/settings.json"
assert link.is_symlink()
shared = root / "dot_copilot/settings.json"
saved = shared.read_bytes()
try:
    link.write_bytes(saved + b"\n")
    assert shared.read_bytes() == saved + b"\n"
finally:
    shared.write_bytes(saved)

fixture = scratch / "nvim-link-source"
fixture_nvim = fixture / ".chezmoitemplates/nvim"
fixture_nvim.mkdir(parents=True, exist_ok=True)
(fixture_nvim / "init.lua").write_text("-- fixture\n")
for relative in (
    ".chezmoiignore",
    ".chezmoitemplates/nvim-link.tmpl",
    "dot_config/symlink_nvim.tmpl",
    "AppData/Local/symlink_nvim.tmpl",
):
    destination = fixture / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / relative, destination)

fixture_links = []
for os_name, target in (
    ("windows", "AppData/Local/nvim"),
    ("linux", ".config/nvim"),
):
    fixture_dest, fc = command(f"nvim-link-{os_name}", source=fixture)
    fc.extend(["--override-data", json.dumps({"chezmoi": {"os": os_name}})])
    run(*fc, "apply")
    target_path = fixture_dest / target
    assert target_path.is_symlink()
    assert target_path.resolve() == fixture_nvim.resolve()
    fixture_links.append(target_path)

added = fixture_nvim / "added.lua"
added.write_text("return true\n")
assert all((link / "added.lua").read_text() == "return true\n" for link in fixture_links)
added.unlink()
assert all(not (link / "added.lua").exists() for link in fixture_links)

for os_name, target in (
    ("windows", "AppData/Local/nvim"),
    ("linux", ".config/nvim"),
):
    conflict_dest, conflict_cm = command(f"nvim-existing-{os_name}", source=fixture)
    conflict_cm.extend(["--override-data", json.dumps({"chezmoi": {"os": os_name}})])
    existing = conflict_dest / target
    existing.mkdir(parents=True)
    (existing / "keep.lua").write_text("-- existing config\n")
    conflict = subprocess.run([*conflict_cm, "apply"], text=True, capture_output=True)
    assert conflict.returncode != 0, "Existing Neovim directory was silently replaced"
    assert "Refusing to replace existing Neovim target" in conflict.stderr
    assert (existing / "keep.lua").read_text() == "-- existing config\n"
    assert not existing.is_symlink()

    file_dest, file_cm = command(f"nvim-existing-file-{os_name}", source=fixture)
    file_cm.extend(["--override-data", json.dumps({"chezmoi": {"os": os_name}})])
    existing_file = file_dest / target
    existing_file.parent.mkdir(parents=True)
    existing_file.write_text("existing target\n")
    conflict = subprocess.run([*file_cm, "apply"], text=True, capture_output=True)
    assert conflict.returncode != 0, "Existing Neovim file was silently replaced"
    assert "Refusing to replace existing Neovim target" in conflict.stderr
    assert existing_file.read_text() == "existing target\n"

    link_dest, link_cm = command(f"nvim-existing-link-{os_name}", source=fixture)
    link_cm.extend(["--override-data", json.dumps({"chezmoi": {"os": os_name}})])
    previous_source = scratch / f"nvim-previous-source-{os_name}"
    previous_source.mkdir()
    (previous_source / "keep.lua").write_text("-- previous source\n")
    previous_link = link_dest / target
    previous_link.parent.mkdir(parents=True)
    previous_link.symlink_to(previous_source, target_is_directory=True)
    run(*link_cm, "apply")
    assert previous_link.is_symlink() and previous_link.resolve() == fixture_nvim.resolve()
    assert (previous_source / "keep.lua").read_text() == "-- previous source\n"
print("Neovim directory links, added/removed files, existing-directory protection, and Copilot writeback: passed")

print(f"{platform}: canonical Neovim payload, repository exclusions, platform Git settings, repeat apply, local-edit protection passed")
