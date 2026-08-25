# Platform notes

Windows rows are verified (see `verified-windows.md`). **macOS, Linux and WSL2 rows
are hypotheses** derived from herdr's docs and from the Windows behaviour — each has
a "how to confirm" note. Confirm before relying on one, and mark anything you could
not confirm as UNVERIFIED in the final report.

---

## Matrix

| | Windows | macOS | Linux | WSL2 |
|---|---|---|---|---|
| scripts | `.ps1` | `.sh` | `.sh` | `.sh` |
| shell for `[[keys.command]]` | `cmd.exe /d /c` | shell | shell | shell |
| var syntax in command strings | `%APPDATA%` | `$HOME` | `$HOME` | `$HOME` |
| config dir | `%APPDATA%\herdr` | `~/.config/herdr` | `~/.config/herdr` | `~/.config/herdr` |
| link type | junction | symlink | symlink | symlink |
| `ui.toast.delivery` | `system` | `system` | `system` | `terminal` |
| `terminal.shell_mode` | `non_login` | `auto` (login on macOS) | `auto` | `non_login` |
| `ui.host_cursor` | `auto` (drawn, ConPTY) | `auto` (native) | `auto` | `auto` (drawn) |
| socket | named pipe, name == path | unix socket | unix socket | unix socket |
| plugin support | preview | full | full | full |
| worktree dir | any drive | `~/src` | `~/src` | **ext4, never `/mnt/*`** |

---

## Windows

- Command strings go through `cmd.exe /d /c`, so call PowerShell explicitly:
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%APPDATA%\herdr\scripts\x.ps1"`
- Forward slashes are fine in TOML paths (`"D:/Code/worktrees"`) and avoid escaping.
  A basic-string Windows path needs doubled backslashes.
- Not supported by herdr on Windows: `terminal attach`, Windows as a `--remote`
  target, live handoff. After `herdr update` the session must be restarted.
- Prefer `pwsh` over `powershell.exe` for anything on a short interval.

## macOS

*Hypotheses.*

- Scripts are plain bash; no `cmd.exe` wrapper, so `$HOME` works directly in command
  strings. **Confirm** by binding a trivial command that writes a file and pressing it.
- `shell_mode = "auto"` uses login shells on macOS, which is usually what you want so
  that `PATH` from `.zprofile` is present. **Confirm** by checking that `git` resolves
  inside a fresh pane.
- The socket is a real unix socket, so a raw client should use `nc -U` or an
  `AF_UNIX` connection rather than a named pipe. **Confirm** with
  `printf '%s\n' '{"id":"t","method":"agent.list","params":{}}' | nc -U "$HERDR_SOCKET_PATH"`.
  Whether the server is one-shot per connection there too is **unconfirmed** — assume
  it is and open a fresh connection per call.
- JetBrains Toolbox shims live in `~/Library/Application Support/JetBrains/Toolbox/scripts`.

## Linux

Same as macOS except `shell_mode = "auto"` does not imply a login shell, and Toolbox
shims live in `~/.local/share/JetBrains/Toolbox/scripts`.

## WSL2

*Hypotheses, except the performance note which is well established.*

- Detect **before** plain Linux: `grep -qi microsoft /proc/version`.
- `ui.toast.delivery = "system"` has no OS notification service inside the distro.
  Use `"terminal"` and let Windows Terminal highlight the tab. **Confirm** by
  triggering a notification and watching for an error.
- Editors are Windows applications reached through interop:
  - VS Code and Cursor have a Remote-WSL server — call `code` / `cursor` natively and
    pass the **Linux** path.
  - JetBrains IDEs are Windows processes and need a UNC path:
    `rider.exe "$(wslpath -w "$dir")"` → `\\wsl.localhost\<distro>\...`
  - `explorer.exe "$(wslpath -w "$dir")"`
- **Keep repos and worktrees on ext4** (`~/src`), never under `/mnt/c` or `/mnt/d`.
  The 9p/drvfs overlay costs several times the performance on `git status` and on any
  build. Warn loudly if the user picks a `/mnt/` path.
- `herdr --remote` from WSL to a Linux/macOS host works; WSL as a *target* is not
  supported.

---

## Writing the bash scripts

These are the places a naive port breaks. None of them are verified — they are the
bash analogues of traps that were real on the PowerShell side.

- `set -euo pipefail` plus `git diff --quiet` (which exits 1 by design) kills the
  script. Guard every git call whose non-zero exit is meaningful:
  `git diff --quiet || changed=1`
- Parsing `git status --porcelain` — the first two characters are the status field,
  so test with `[ "${line:0:2}" = "??" ]`, not a glob.
- Filenames with spaces: read with `while IFS= read -r line`, and prefer
  `-z` / null-delimited output where git offers it.
- An empty array under `set -u` expands unsafely on bash < 4.4: use `"${arr[@]+"${arr[@]}"}"`.
- macOS ships bash 3.2 — no associative arrays, no `${var^^}`. Either target
  POSIX-ish bash 3.2 or require `#!/usr/bin/env bash` with a version check.
- `readlink -f` does not exist on stock macOS. Use a `cd`/`pwd -P` helper.
- `mktemp` differs: macOS needs a template argument (`mktemp -d -t herdr`).
