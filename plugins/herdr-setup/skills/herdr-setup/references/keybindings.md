# Keybindings

## The rule that matters

> On a collision the **named action wins** and the custom command is **disabled**.
> herdr reports this **only when both bindings are explicit in the config**.

So a custom command placed on a key that a *default* action owns will silently never
fire, and `reload-config` will happily say `applied` with empty diagnostics.

**Therefore: any custom binding on a default-owned key must be paired with an
explicit relocation of that default action.** Writing only the custom command is a
silent no-op.

When both are explicit you get a real diagnostic:

```
prefix+alt+w: kept keys.split_vertical, disabled keys.command[0].key
```

## Collision algorithm

1. Parse the default keymap out of `herdr --default-config` — the `[keys]` block
   lists every action as a commented `# action = "prefix+x"` line. Build
   `action -> key` and the inverse `key -> action`.
2. Build the desired custom map from the interview.
3. For each desired key, look it up in `key -> action`.
4. On a hit, relocate the **default action**:
   - prefer the `shift+` variant of the same letter (`prefix+c` → `prefix+shift+c`)
   - then the `alt+` variant
   - then any free key from the same mnemonic family
   - never pick a key another custom command or relocated action already claims
5. Write the relocation **explicitly** into `[keys]` with a comment saying which
   custom command displaced it.
6. `reload-config`; assert diagnostics contain no `disabled keys.command`.
7. Tell the user every action that moved and where.

## Syntax

- Prefix bindings: `"prefix+<key>"`. Modifiers `ctrl`, `shift`, `alt`, `cmd`/`super`.
- Direct (no prefix) bindings are written as the chord itself: `"ctrl+alt+n"`.
- Indexed bindings use a range: `"prefix+1..9"`.
- **Punctuation is spelled by name**: `plus`, `minus`, `comma`, `ampersand`,
  `backtick`. `"prefix++"` is rejected — `invalid keybinding; disabling binding`.
- Optional bindings can be disabled with `""`.
- Most reliable: `ctrl+letter`, function keys, explicit modified chords. `alt+…`,
  `cmd`/`super` and punctuation-with-modifiers depend on the outer terminal.

## Stock defaults (0.8.2 — re-read from `--default-config`)

`prefix` is `ctrl+b`.

| Key | Action | | Key | Action |
|---|---|---|---|---|
| `?` | help | | `c` | new_tab |
| `s` | settings | | `shift+t` | rename_tab |
| `q` | detach | | `p` / `n` | prev / next tab |
| `shift+r` | reload_config | | `1..9` | switch_tab |
| `o` | open_notification_target | | `shift+x` | close_tab |
| `w` | workspace_picker | | `shift+p` | rename_pane |
| `g` | goto | | `e` | edit_scrollback |
| `shift+n` | new_workspace | | `h` `j` `k` `l` | focus pane |
| `shift+g` | new_worktree | | `tab` / `shift+tab` | cycle panes |
| `shift+w` | rename_workspace | | `v` | split_vertical |
| `shift+d` | close_workspace | | `minus` | split_horizontal |
| `b` | toggle_sidebar | | `x` | close_pane |
| | | | `z` | zoom |
| | | | `r` | resize_mode |

Unbound by default (free to take, no relocation needed): `prefix+d`, `prefix+t`,
`prefix+a`, `prefix+f`, `prefix+i`, `prefix+m`, `prefix+u`, `prefix+y`, and most
`alt+` chords.

Optional, unset by default: `open_worktree`, `remove_worktree`, `previous_workspace`,
`next_workspace`, `previous_agent`, `next_agent`, `focus_agent`, `switch_workspace`,
`last_pane`, `move_tab_previous`, `move_tab_next`, `resize_pane_*`.

## Suggested map

Offer this, then let the user remap. Keys marked ⚠ displace a default and require
the relocation step.

| Key | Command | |
|---|---|---|
| `prefix+w` | new worktree | ⚠ displaces `workspace_picker` |
| `prefix+d` | changed files vs base | free |
| `prefix+e` | open in primary IDE | ⚠ displaces `edit_scrollback` |
| `prefix+v` | open in secondary editor | ⚠ displaces `split_vertical` |
| `prefix+c` | start agent in this pane | ⚠ displaces `new_tab` |
| `prefix+t` | scratch terminal | free |
| `prefix+alt+b` | dev layout | free |
| `prefix+alt+a` | only agents awaiting me | free |
| `prefix+alt+v` | agent review of the diff | free |
| `prefix+alt+x` | GC merged worktrees | free |
| `prefix+alt+l` | lazygit | free |

Corresponding relocations:

```toml
workspace_picker = "prefix+alt+w"
edit_scrollback  = "prefix+shift+e"
split_vertical   = "prefix+plus"
new_tab          = "prefix+shift+c"
```

Note `alt+r` is deliberately unused — it collides with common GPU-overlay hotkeys.

## Custom command types

`type` ∈ `shell` (detached background), `pane` (temporary pane, closes on exit),
`popup` (session-modal terminal), `plugin_action` (invokes `<plugin-id>.<action-id>`).

`popup` and `pane` accept `width` / `height` in cells or percentages.
