# Verified facts — Windows, herdr 0.8.2-preview.2026-08-19-b5c4a0176e91

Every line below was confirmed empirically against a running binary on 2026-08-24,
while repairing a docs-derived setup in which most of these were wrong.

**Use them as starting hypotheses, not as truth.** Re-confirm through
`references/calibration.md` before generating anything. A newer herdr may differ,
and none of this was checked on macOS or Linux.

---

## Config

| # | Fact | How it was confirmed |
|---|---|---|
| 1 | `reload-config` returns `{status, diagnostics}` and reports unknown keys *and* out-of-enum values. `diagnostics: []` + `status: applied` = the whole config is valid. | injected a bogus key and a bogus enum value; both were reported |
| 2 | `[[keys.command]] type` ∈ `shell`, `pane`, `popup`, `plugin_action` | bogus value → `unknown variant ...; expected one of ...` |
| 3 | `tab_bar_right` command entry accepts exactly `command`, `interval_seconds`, `timeout_seconds` | bogus field → error listed the real ones |
| 4 | A sidebar token style accepts **only** `token`, `fg`, `bold`, `dim` — `struct RawStyledSidebarToken with 4 elements`. No `bg`, no `italic`, **no alignment of any kind**. | binary strings + rejected `bg`/`italic`/`align` |
| 5 | Row-level alignment does not exist either: `rows` must be a sequence. An object gets `invalid type: map, expected a sequence`. There is no `spacer`/`fill` token. | tried all three forms |
| 6 | Agent sidebar tokens: `state_icon`, `state_text`, `workspace`, `tab`, `pane`, `agent`, `terminal_title`, `terminal_title_stripped` | binary string table |
| 7 | Space sidebar tokens: `state_icon`, `state_text`, `workspace`, `branch`, `git_status`. Custom tokens must start with `$`. | bogus token → `unknown sidebar token X; custom tokens must start with $` |
| 8 | Omitting `fg` preserves the contextual default. `bold = true` **without** `fg` is legal — that is how you emphasise `state_text` while keeping herdr's per-state colouring. | reload accepted it |
| 9 | Built-in `git_status` counts via `git status --porcelain --untracked-files=all`, so it disagrees with a plain `--porcelain` count whenever an untracked directory exists. | binary strings + measured 26 vs 22 on a real repo |
| 10 | Token values are **whitespace-trimmed** server-side. Padding a token to fake alignment does not work. | `"      working"` came back `"working"` |
| 11 | Token names must match `^[A-Za-z0-9_-]{1,32}$`, max 16 per source, `ttl_ms` ≤ 86400000 | API schema |

## Keybindings

| # | Fact |
|---|---|
| 12 | On a collision the **named action wins and the custom command is disabled**: `prefix+alt+w: kept keys.split_vertical, disabled keys.command[0].key` |
| 13 | herdr reports a collision **only when both bindings are explicit in the config**. Overriding a default you have not written down passes silently as `applied` with empty diagnostics. This is why a custom binding on a default key must always be paired with an explicit relocation of that default. |
| 14 | Punctuation is spelled by name: `"prefix+plus"`, `"prefix+minus"`. `"prefix++"` is rejected with `invalid keybinding; disabling binding`. |
| 15 | `prefix+d`, `prefix+t` are free in the stock keymap; `prefix+c`, `prefix+e`, `prefix+v`, `prefix+w`, `prefix+r`, `prefix+s`, `prefix+g`, `prefix+b`, `prefix+z`, `prefix+x`, `prefix+o`, `prefix+q`, `prefix+n`, `prefix+p`, `prefix+h/j/k/l` are not. |

## Plugins

| # | Fact |
|---|---|
| 16 | Plugin action `contexts` ∈ `global`, `workspace`, `tab`, `pane`, `selection` |
| 17 | Pane `placement` ∈ `overlay`, `popup`, `split`, `tab`, `zoomed`. `--help` for `plugin pane open` omits `popup`, but it works. |
| 18 | The manifest validates enum values strictly but **silently drops an unknown top-level section**. A typo'd section name is not an error — it just never runs. |
| 19 | `[[startup]]` runs **only at server start**, not on `plugin link` / `unlink`. After a fresh install any startup-spawned daemon is not running yet. |
| 20 | A plugin `command` is an **argv array with no shell**. No expansion, no quoting, no pipes. Shell examples from the docs cannot be pasted in. |
| 21 | `plugin log list` records `exit_code`, `stdout` and `stderr` per invocation. **`status: succeeded` with `exit 0` does not mean the script did anything** — a script that exits early on a bad field name looks identical to one that worked. |

## Environment inside plugin commands

| # | Fact |
|---|---|
| 22 | Present: `HERDR_BIN_PATH`, `HERDR_ENV=1`, `HERDR_PANE_ID`, `HERDR_TAB_ID`, `HERDR_WORKSPACE_ID`, `HERDR_SOCKET_PATH`, `HERDR_PLUGIN_ID`, `HERDR_PLUGIN_ROOT`, `HERDR_PLUGIN_CONFIG_DIR`, `HERDR_PLUGIN_STATE_DIR`, `HERDR_PLUGIN_CONTEXT_JSON`; plus `HERDR_PLUGIN_ACTION_ID` (actions), `HERDR_PLUGIN_EVENT` + `HERDR_PLUGIN_EVENT_JSON` (hooks), `HERDR_PLUGIN_CLICKED_URL` + `HERDR_PLUGIN_LINK_HANDLER_ID` (link handlers). |
| 23 | **Absent**: `HERDR_ACTIVE_PANE_CWD`, `HERDR_ACTIVE_WORKSPACE_ID`. They exist as strings in the binary but are not set in plugin or keybinding context. Scripts that relied on them fell through to the process cwd — the plugin root — and then silently exited because it is not a git repo. |
| 24 | The plugin command's working directory is the **plugin root**, not the workspace. Never use it as the repo path. |

### `HERDR_PLUGIN_CONTEXT_JSON` — flat

```json
{"workspace_id","workspace_label","workspace_cwd","tab_id","tab_label",
 "focused_pane_id","focused_pane_cwd","focused_pane_status",
 "invocation_source","correlation_id"}
```

Plus `"focused_pane_agent"` when an agent is detected, and a nested
`"worktree": {"repo_key","repo_name","repo_root","checkout_path","is_linked_worktree"}`
when the workspace is a worktree.

Note the names: **`focused_pane_cwd` and `workspace_cwd`** — not `cwd`, not
`foreground_cwd`.

### `HERDR_PLUGIN_EVENT_JSON`

`workspace.created`:

```json
{"event":"workspace_created",
 "data":{"type":"workspace_created",
         "workspace":{"workspace_id","number","label","focused",
                      "pane_count","tab_count","active_tab_id","agent_status",
                      "worktree":{...}}}}
```

**No `cwd`. No `branch`.** The path must be fetched separately.

`worktree.created`:

```json
{"event":"worktree_created",
 "data":{"type":"worktree_created",
         "workspace":{...},
         "worktree":{"path","branch","is_bare","is_detached","is_prunable",
                     "is_linked_worktree","open_workspace_id","label"}}}
```

| # | Fact |
|---|---|
| 25 | **Both events fire for the same new worktree.** An autostart hook on `workspace.created` must skip worktrees or the agent starts twice. The reliable discriminator is `data.workspace.worktree` — `branch` is *not* present in the `workspace.created` payload. |

## Paths and the API

| # | Fact |
|---|---|
| 26 | `workspace list` / `workspace get` have **no `cwd` field**. The path exists only as `pane.cwd` or `workspace.worktree.checkout_path`. A daemon looping over `$w.cwd` skips every workspace and reports nothing, forever. |
| 27 | `herdr pane current` returns the UI-focused pane including `cwd`. This is the reliable cwd source for keybinding commands, which get no plugin context. |
| 28 | herdr returns paths with **mixed separators** (`D:/Code/worktrees\repo\branch`), sometimes a `\\?\` prefix, sometimes a trailing separator. Always normalise. |
| 29 | `workspace report-metadata` tokens surface as `workspace.tokens` in `workspace get`. Empty-string values are dropped, not rendered. |
| 30 | `agent start` works on Windows and passes everything after `--` through to the agent, verified as `claude.exe --dangerously-skip-permissions --chrome`. It requires a pane already at an interactive shell prompt and does not create or move panes. |

## Socket

| # | Fact |
|---|---|
| 31 | On Windows `HERDR_SOCKET_PATH` is a **named pipe whose name is literally that path** (`C:\Users\...\herdr\herdr.sock`). No `\\.\pipe\` prefix is stripped. `NamedPipeClientStream('.', $env:HERDR_SOCKET_PATH)` connects. |
| 32 | A file of the same name exists on disk but holds only `<pid>:<nonce>`. The leading number is the **server PID, not a TCP port**. |
| 33 | The server is **one-shot per connection**: after one request/response it closes. A second write gets `Pipe is broken`. Open a fresh connection per call. |
| 34 | `agent.view.set` requires `source` to be `plugin:<real-plugin-id>`; an arbitrary string returns `plugin_not_found`. |

## Language traps

### PowerShell

| Trap | Fix |
|---|---|
| `-like '??*'` does **not** mean "starts with `??`" — `?` is a single-char wildcard, so it matches every line ≥2 chars. Silently counted all files as untracked. | `.StartsWith('??')` |
| A pipeline yielding one item returns a **String, not an array**. `$picks[0]` then returns the first *character* — `'C'` from `'C:\...'` — and the editor opens `<cwd>\C`. | wrap in `@(...)` |
| `$arr[1..($arr.Count-1)]` with `Count == 1` becomes `$arr[1..0]`, a **reverse range**, yielding out-of-bounds nulls. | guard `Count -lt 2` first |
| `.cmd` files with LF line endings break cmd.exe parsing of `if (...)` blocks. | write CRLF |
| A path passed unquoted to `-ArgumentList` breaks apart inside a batch shim when it contains a space. | pass `'"' + $path.TrimEnd('\') + '"'`; trim the trailing backslash or it escapes the closing quote |
| `-replace` treats the pattern as regex; backslashes need doubling. | `.Replace()` for literals |

### Windows shell wrapper

| # | Fact |
|---|---|
| 35 | `[[keys.command]]` command strings run through `cmd.exe /d /c`. `%APPDATA%` expands, and quoted `-File "..."` arguments survive intact — verified end to end. |
| 36 | The Store `pwsh.exe` app-execution alias under `WindowsApps\Microsoft.PowerShell_8wekyb3d8bbwe\` **is** directly executable and is more stable than the versioned `WindowsApps\Microsoft.PowerShell_7.x.y.z_x64__...` path, which changes on update. |
| 37 | `powershell.exe` (5.1) costs ~700 ms to start; `pwsh` ~280 ms. Both fit a `timeout_seconds = 5` tab-bar entry, but the difference matters at an 8-second interval. |
