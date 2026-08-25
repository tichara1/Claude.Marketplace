# Calibration playbook

Discover what *this* herdr build actually accepts. Output: `calibration.json`.

Nothing downstream may use a field name, config key or enum value that did not come
out of one of these steps.

---

## 1. Version and health

```bash
herdr --version
herdr status
```

Record `client.version`, `client.protocol`, `server.status`, `server.compatible`.

Stop if `compatible` is not `yes`.

---

## 2. Valid config surface

```bash
herdr --default-config > default-config.toml
```

This is the **only** authoritative list of config keys and permitted values for this
build. It also carries the complete default keymap in `[keys]` (commented out, one
`# action = "prefix+x"` per line) — parse it, you need it for collision detection.

Extract into `calibration.json`:

- `config_keys` — every key path that appears
- `themes` — from the `theme.name` comment
- `default_keymap` — action name → key
- `enums` — any `possible values` / `Values:` lists

---

## 3. Socket API shape

```bash
herdr api schema --json > api-schema.json
```

A full JSON Schema of the socket protocol for this build. More precise than any
website. Use it to confirm:

- a method exists before calling it (`agent.view.set`, `workspace.report_metadata`, …)
- required vs optional params
- enum values for filter/sort fields
- numeric limits (e.g. `ttl_ms` maximum, token count maximum)

The method list lives in the `request` schema's `oneOf` variants, each with a
`method.const`. Parameter shapes are in `$defs`.

---

## 4. Real CLI signatures

`--help` for every subcommand you will call. Do not assume flags.

```bash
herdr agent start --help
herdr workspace report-metadata --help
herdr workspace create --help
herdr worktree create --help
herdr pane split --help
herdr pane run --help
herdr pane list --help
herdr plugin pane open --help
herdr notification show --help
```

`--help` output is occasionally incomplete — on 0.8.2 `plugin pane open --help`
omitted `popup` from its placement list although the value works. When `--help` and
the schema disagree, trust the schema, then test.

Also worth reading once:

```bash
herdr --skill
```

The agent-facing usage guide this build ships. It documents intended workflows
(e.g. that `agent start` needs a pane already at an interactive shell prompt).

---

## 5. Probe plugin — the real env shape

**This step is mandatory.** The shape of `HERDR_PLUGIN_EVENT_JSON` and
`HERDR_PLUGIN_CONTEXT_JSON` is not documented field by field, and guessing it is the
number one cause of hooks that silently do nothing.

### Procedure

1. Remove any stale probe first:
   ```bash
   herdr plugin unlink herdr-setup.probe   # ignore failure
   ```

2. Copy `probe/` to a temp dir and link it:
   ```bash
   herdr plugin link <tmp>/probe
   ```

3. Trigger all three paths:
   ```bash
   herdr plugin action invoke herdr-setup.probe.dump
   herdr workspace create --cwd <some-git-repo> --label herdr-setup-probe --no-focus
   herdr worktree create --cwd <some-git-repo> --branch herdr-setup/probe \
        --base <default-branch> --label herdr-setup-probe-wt --no-focus
   ```
   The worktree step is what reveals that **`worktree.created` and
   `workspace.created` both fire for the same worktree** — a fact that decides
   whether your autostart hook double-starts an agent.

4. Read the dumps from the probe's state dir.

5. **Clean up, even on failure:**
   ```bash
   herdr plugin unlink herdr-setup.probe
   herdr workspace close <probe-ws-ids>
   git -C <repo> worktree remove --force <path>
   git -C <repo> branch -D herdr-setup/probe
   ```
   Then delete the temp probe dir and dumps.

### What to record

From the action dump:
- every `HERDR_*` variable name that exists (and, importantly, which ones do **not**)
- the full key list of `HERDR_PLUGIN_CONTEXT_JSON`

From each event dump:
- `HERDR_PLUGIN_EVENT` value
- the full nested structure of `HERDR_PLUGIN_EVENT_JSON`
- whether `workspace.created` also fired for the worktree, and what distinguishes the
  two payloads

---

## 6. Confirming a suspicious value

When you need to know whether a specific config value is legal:

```bash
cp <live-config> <tmp>/probe-config.toml
# edit the temp copy, then point herdr at it only if it supports that;
# otherwise: back up live config, write, reload, read diagnostics, restore
herdr server reload-config
```

Read `result.diagnostics`:

| diagnostics | meaning |
|---|---|
| `[]` with `status: applied` | value is valid |
| `unknown config key X` | key does not exist in this build |
| `unknown <thing> name X; using Y; valid: ...` | out of enum — the message lists the legal set |
| `invalid <section> config: unknown field / unknown variant ...` | struct or enum mismatch; the message names the accepted fields |
| `<key>: kept keys.X, disabled keys.command[N].key` | keybinding collision |
| `config parse error` | TOML is malformed |

**Always restore the user's config afterwards.** Never leave a probe value behind.

This oracle is precise enough to enumerate an unknown struct: feeding a bogus field
name makes the error list the real ones.

---

## calibration.json shape

```json
{
  "herdr_version": "0.8.2-preview...",
  "protocol": 20,
  "platform": "windows|macos|wsl2|linux",
  "config_dir": "...",
  "script_ext": "ps1|sh",
  "default_keymap": { "new_tab": "prefix+c", "...": "..." },
  "themes": ["catppuccin", "..."],
  "api_methods": ["agent.start", "..."],
  "env_vars_present": ["HERDR_WORKSPACE_ID", "..."],
  "env_vars_absent": ["HERDR_ACTIVE_PANE_CWD", "..."],
  "context_json_keys": ["workspace_id", "focused_pane_cwd", "..."],
  "event_shapes": {
    "workspace.created": { "...": "..." },
    "worktree.created": { "...": "..." }
  },
  "both_events_fire_for_worktree": true,
  "tools": { "git": true, "fzf": false, "...": false }
}
```
