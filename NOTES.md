# NOTES.md — iac-terraform-ansible (Project 2)

Study notes, chronological by session. Short definitions + real examples from this project.

## Session 1 — 2026-09-09 — Repo Setup

**MinTTY has no PTY support** — Git Bash's terminal (MinTTY) can't run tools that need
an interactive pseudo-terminal (arrow-key menus, live prompts). Same root cause as the
`winpty python` requirement.

*This project:* `gh auth login` failed with "You appear to be running in MinTTY without
pseudo terminal support" — fixed with `winpty gh auth login`.

**Cross-device `mv`** — `mv` between different drives (e.g. C: → G:) can't do an atomic
rename; it copies then deletes. If the destination already has a same-named non-empty
folder, it fails with "unable to remove target: Directory not empty" instead of merging.

*This project:* had a stray `iac-terraform-ansible/PROGRESS.md` already sitting on G:
from before the repo existed — had to move that file into the cloned repo first, then
`rmdir` the empty leftover folder, then `mv` the real repo into place.

**Git line-ending conversion (CRLF/LF)** — On Windows, Git's `core.autocrlf` setting
converts LF → CRLF in your working directory and back on commit. The "LF will be
replaced by CRLF" warning on `git add` is expected behavior, not an error.

*This project:* saw this on `git add .gitignore PROGRESS.md` — no action needed.

**`gh repo create --clone`** — clones into your *current* working directory at the time
the command runs, not a directory you `cd` into afterward. Always `cd` to the target
location first.

*This project:* ran `gh repo create ... --clone` from `~`, so it cloned into
`~/iac-terraform-ansible` instead of the intended `G:\...\DevOps Project\`, requiring
a manual move afterward.

## Session 2 — 2026-09-10 — Terraform Version Verification

**Chocolatey installs/upgrades need an elevated shell** — Chocolatey installs packages
under `C:\ProgramData\...`, a system-owned folder. A non-admin terminal can run `choco`
but can't write there, so upgrades fail with `UnauthorizedAccessException: Access ... is
denied` after retrying each file 2-3 times, even after confirming "Y" to proceed.

*This project:* `choco upgrade terraform -y` from a normal Git Bash window failed on
every file under `chocolatey\lib\terraform\`. Re-running the identical command from
Git Bash opened via "Run as administrator" succeeded — Terraform went from v1.15.7 to
v1.16.1. Same root cause as `winpty` and package-manager admin requirements: Windows
permission boundaries, not a tool bug.
