---
name: herdr-setup
description: Use when the user wants to install, configure, repair or extend a herdr setup - the terminal multiplexer for AI coding agents from herdr.dev. Interactively builds a worktree/agent workflow (worktree popups, Claude autostart, sidebar git tokens, diff browser, editor launchers, ticket links) on Windows, macOS or WSL2. Also use when herdr keybindings, plugin actions, event hooks or sidebar tokens silently do nothing.
---

# herdr-setup

Build a working herdr setup on this machine, interactively, and prove it works.

## The Iron Law

```
NEVER write a config value, an API field name, or an env var you have not
confirmed against the installed binary. Calibrate first. Always.
```

herdr fails *silently* when you guess wrong. A hook with a bad field name returns
`exit 0` and does nothing. A daemon reading a non-existent property loops forever
reporting nothing. An invalid config value falls back to a default with a warning
that scrolls past. The setup looks installed and is dead.

Every fact in `references/verified-windows.md` was originally wrong in a
docs-derived setup. Treat that file as **starting hypotheses to re-confirm**, never
as truth.

## Run the phases in order

Create a todo per phase. Do not skip ahead — phase N+1 consumes phase N's output.

1. **Detect** — platform, herdr, tooling
2. **Calibrate** — discover what this version actually accepts
3. **Interview** — ask what the user wants
4. **Generate** — write the setup folder
5. **Install & verify** — link it up, then prove each part runs

If the user asks for a single phase (`repair my keybindings`, `re-run verify`),
run just that one, but read `references/calibration.md` first regardless.

---

## Phase 1 — Detect

```bash
herdr --version          # missing => offer install
herdr status             # server running? protocol compatible?
```

Platform:

| Platform | Detect | Scripts | Config dir |
|---|---|---|---|
| Windows | `$IsWindows` / `%OS%` | `.ps1` | `%APPDATA%\herdr` |
| WSL2 | `microsoft` in `/proc/version` | `.sh` | `~/.config/herdr` |
| macOS | `uname` = `Darwin` | `.sh` | `~/.config/herdr` |
| Linux | otherwise | `.sh` | `~/.config/herdr` |

**Check WSL2 before Linux** — WSL2 reports `Linux` from `uname` but needs different
notification delivery and editor interop.

If herdr is missing, show the install command and **ask before running it**:

- Windows: `irm https://herdr.dev/install.ps1 | iex`
- macOS / Linux / WSL2: the install script at https://herdr.dev

If `herdr status` reports `compatible: no`, stop. Tell the user to restart herdr or
run `herdr update` — a protocol mismatch makes every later step unreliable.

Probe PATH for `git`, `fzf`, `delta`, `lazygit`, `claude`, and editors (`rider`,
`code`, `cursor`, `subl`, `idea`). Record what exists; the interview only offers
tools that are actually present. On WSL2 also probe the `.exe` interop variants.

---

## Phase 2 — Calibrate

Read `references/calibration.md` and follow it. It produces `calibration.json`.

Short version — four sources, in this order:

1. `herdr --default-config` → valid keys, enum values, **the default keymap**
2. `herdr api schema --json` → socket methods and parameter shapes
3. `herdr <cmd> --help` for every subcommand you intend to call
4. **the probe plugin** in `probe/` → the real shape of `HERDR_PLUGIN_*` env

The probe is not optional. It is the only way to learn the event and context JSON
shape, and getting that wrong is the single most common cause of a dead setup.

**Clean up the probe even if something fails.** Unlink it, close the throwaway
workspace, remove the worktree and branch. Check for and remove a stale
`herdr-setup.probe` at the start of every run.

### The config oracle

```bash
herdr server reload-config
```

Returns `{"status", "diagnostics"}`. It reports unknown keys *and* out-of-enum
values:

```
unknown config key theme.bogus_key_xyz; ignoring key
unknown theme name theme.name = "..."; using "catppuccin"; valid themes: ...
```

`status: "applied"` with `diagnostics: []` means the whole config is valid.

Use it to test any value you are unsure about — but **write to a temporary copy of
the config, never the user's live one**, until the value is confirmed.

---

## Phase 3 — Interview

Ask with AskUserQuestion, grouping related choices. Persist answers to
`answers.json` in the setup folder so a re-run only needs confirmation.

**First question: where should the setup folder live?** Offer a sensible default
per platform (`~/herdr-setup`, or beside the user's code on Windows) but let them
type a path. Never assume.

### Modules

Each is optional; default all on. An unselected module generates **nothing** — no
script, no manifest entry, no keybinding, no config section.

| Module | Scripts | Gives |
|---|---|---|
| `worktree` | `worktree-new`, `worktree-gc` | new-worktree popup, GC of merged worktrees |
| `agent-autostart` | `agent-autostart`, `bootstrap-worktree`, `agent-here`, `dev-layout` | agent on workspace/worktree creation, local-file copy, pane layout |
| `sidebar-tokens` | `status-daemon`, `spawn-status-daemon` | `~modified` `?untracked` `^v` per space, auto-fetch |
| `diff-browser` | `changed-files`, `send-to-agent`, `open-pane` | fzf diff list vs base branch |
| `editors` | `open-editor` | open repo in IDE, by key and by context menu |
| `ticket-worktree` | `ticket-worktree` | Ctrl+click a GitHub/Jira URL to make a worktree |
| `status-bar` | `status`, `attention-view` | tab bar status, "only agents waiting on me" |
| `review` | `review` | agent review of the diff in headless mode |

`lib` is always generated.

### Parameters

Only ask what the selected modules need.

| Question | Default | Needed by |
|---|---|---|
| branch prefix | `feature/<username>` | worktree |
| worktree directory | see below | worktree |
| agent kind | `claude` | agent-autostart |
| agent arguments | `--dangerously-skip-permissions` | agent-autostart |
| autostart on new workspace | yes | agent-autostart |
| files to copy into a new worktree | `.env`, `.env.local`, `appsettings.Development.json` | agent-autostart |
| status poll interval | 12 s | sidebar-tokens |
| auto-fetch interval | 300 s (0 disables) | sidebar-tokens |
| editors | detected on PATH | editors |
| Jira domain | — | ticket-worktree |
| review prompt language | user's language | review |
| theme | from `--default-config` | always |
| prefix key | `ctrl+b` | always |

Worktree directory default: Windows `C:/Users/<user>/herdr-worktrees` unless the
user keeps code elsewhere; macOS/Linux `~/src/worktrees`.

**WSL2:** if the chosen path is under `/mnt/`, warn that the 9p/drvfs overlay costs
several times the performance on `git status` and builds, and offer `~/src`.

### Keybindings

Read `references/keybindings.md`. Show the proposed map, mark what the default
keymap already uses, ask what to remap.

**Resolve collisions automatically.** On a collision the named action wins and the
custom command is silently disabled, so a custom binding must never be left sitting
on an occupied key. Move the *default action* elsewhere, explicitly, and tell the
user where it went.

---

## Phase 4 — Generate

Write into the chosen folder:

```
<setup>/
  config/config.toml            generated from answers + calibration
  plugin/herdr-plugin.toml      only selected modules
  plugin/scripts/               copied verbatim from templates/scripts-{ps1,sh}
  plugin/scripts/settings.<ps1|sh>   generated from answers
  answers.json
  calibration.json
  install.<ps1|sh>
  README.md                     including the final keybinding table
```

Scripts are **static** — they read every tunable from `settings.ps1` / `settings.sh`.
Do not template them. Copy the files for the selected modules plus `lib`.

Comment every non-obvious line in the generated config with *why* it is there.
Future readers (including you) will otherwise "simplify" a workaround back into a bug.

Templates live in `templates/`. Read `references/platform-notes.md` before writing
the config — the `cmd.exe /d /c` wrapper, `%VAR%` vs `$VAR`, and notification
delivery all differ per platform.

---

## Phase 5 — Install and verify

Install:

1. Back up any existing config to `config.toml.bak.<timestamp>`.
2. Copy the config into the platform config dir.
3. Link `<configdir>/scripts` → `<setup>/plugin/scripts` (junction on Windows,
   symlink elsewhere). Fall back to copying, and say so.
4. `herdr plugin link <setup>/plugin`
5. `herdr integration install <agent-kind>`

Then **prove it works**. Do not report success without running these:

| Check | Pass criterion |
|---|---|
| config valid | `reload-config` → `applied`, `diagnostics: []` |
| plugin loaded | `plugin list --json` → `enabled: true`, no `warnings` |
| no key collision | diagnostics contain no `disabled keys.command` |
| scripts parse | PowerShell `Parser::ParseFile`; bash `bash -n` |
| every action runs | `plugin action invoke <id>` then `plugin log list` → exit 0, empty stderr |
| hooks fire | create a throwaway workspace in a git repo, confirm the hook logged and had an effect |
| daemon alive | process exists; tokens appear on a git workspace within TTL |

Clean up everything you created.

**`[[startup]]` only runs at server start, not on `plugin link`.** After a fresh
install the status daemon is not running. Either start it directly or tell the user
to restart the herdr server.

### Report honestly, in three states

- **OK** — tested, works
- **FAILED** — tested, broken; give the exit code and stderr
- **UNVERIFIED** — could not be tested from the CLI; say how to check by hand

Context menu entries and Ctrl+click link handlers need a real mouse. They are
always **UNVERIFIED** — never report them as working.

If the self-test fails, keep the generated folder but **do not** leave a broken
setup linked. Tell the user exactly what failed and offer to restore the backup.

---

## When repairing an existing setup

A user reporting "it does nothing" almost always has a silent-failure bug. Work in
this order:

1. `herdr plugin log list --plugin <id> --limit 30` — hooks and actions log their
   exit code and stderr here. **`succeeded` with `exit 0` does not mean it did
   anything** — check stdout and whether the effect happened.
2. `herdr server reload-config` — read the diagnostics.
3. Run the script by hand outside herdr. If it fails there, the bug is in the
   script, not in herdr.
4. Re-run the probe (phase 2) and compare the real env shape against what the
   scripts expect. This finds the whole class of "field does not exist" bugs.

Use `superpowers:systematic-debugging` if it is available. Do not guess-and-patch.

## Red flags

| Thought | Reality |
|---|---|
| "The docs say the field is `cwd`" | Docs are not the binary. Probe it. |
| "The hook returned exit 0, so it worked" | It exits 0 when it silently does nothing. Check the effect. |
| "I'll just bind the key, it'll override" | Named action wins; your command is disabled silently. |
| "reload-config said applied, config is fine" | Only with `diagnostics: []`. Read them. |
| "I'll port the bash version from the PowerShell one" | Fine — then run the self-test. Never claim it works untested. |
| "It's basically the same on macOS" | You have not run it there. Say UNVERIFIED. |
