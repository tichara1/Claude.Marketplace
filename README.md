# tichara1-marketplace

Personal Claude Code plugin marketplace.

## Adding the marketplace

Run this once inside Claude Code:

```
/plugin marketplace add tichara1/Claude.Marketplace
```

Or with the full URL:

```
/plugin marketplace add https://github.com/tichara1/Claude.Marketplace.git
```

Then browse and install interactively with `/plugin`, or install directly:

```
/plugin install herdr-setup@tichara1-marketplace
```

Restart Claude Code (or run `/plugin` and reload) so the new skills are picked up.

To update later:

```
/plugin marketplace update tichara1-marketplace
```

---

## Plugins

### herdr-setup

Interactive installer for a [herdr](https://herdr.dev) worktree/agent workflow on
**Windows, macOS and WSL2**.

herdr is a terminal multiplexer built for AI coding agents. Getting a useful setup
out of it means writing a `config.toml`, a plugin manifest, event hooks and a pile of
scripts — and every one of those fails *silently* when a field name is wrong. A hook
with a bad key returns `exit 0` and does nothing. A daemon reading a non-existent
property loops forever reporting nothing. An invalid config value falls back to a
default with a warning that scrolls past. The setup looks installed and is dead.

This skill removes that class of bug by never trusting documentation. It discovers
what the installed binary actually accepts, generates the setup from that, and then
proves each piece runs.

**What it does**

1. **Detect** — platform, herdr version, protocol compatibility, which tools are on PATH.
   Offers to install herdr if missing (never without asking).
2. **Calibrate** — reads `herdr --default-config`, `herdr api schema --json` and the real
   `--help` output, then links a temporary probe plugin to dump the true shape of the
   event and context JSON on *this* machine.
3. **Interview** — which modules you want, branch prefix, where worktrees live, agent
   arguments, editors, keybindings. Answers are saved, so a re-run is just confirmation.
4. **Generate** — a standalone setup folder with `config.toml`, the plugin manifest and
   only the scripts for the modules you picked. You choose where it lives.
5. **Install & verify** — links everything up, then runs each action, fires each hook and
   reads the exit codes. Reports **OK / FAILED / UNVERIFIED** per item — never claims
   something works when it was not tested.

**Modules** — all optional:

| Module | What you get |
|---|---|
| worktree | popup for a new worktree with a branch prefix, GC of merged ones |
| agent autostart | agent starts on new workspace/worktree, local `.env` copied in, panes laid out |
| sidebar tokens | `~modified` `?untracked` `^ahead` `vbehind` per space, kept fresh by auto-fetch |
| diff browser | fzf list of changes vs base branch with delta preview |
| editors | open the repo in your IDE, by key or by right-clicking a Space |
| ticket → worktree | Ctrl+click a GitHub issue or Jira ticket to branch off it |
| status bar | branch, change count and how many agents are waiting on you |
| review | pipe the diff through your agent for a pre-commit review |

**Usage**

Once installed, just ask:

```
set up herdr
```

or invoke it directly:

```
/herdr-setup
```

It also handles repairs — if keybindings, plugin actions, event hooks or sidebar
tokens silently do nothing, the skill knows where the logs are and which failure
modes look like success.

**Platform support**

| | Status |
|---|---|
| Windows (native, ConPTY) | verified against herdr 0.8.2-preview |
| macOS | ported, not yet run against a real herdr — the self-test is the safety net |
| WSL2 | ported, not yet run — includes editor interop and the `/mnt` performance warning |
| Linux | ported, not yet run |

The distinction is deliberate and the skill carries it too: `references/verified-windows.md`
records what was confirmed empirically, `references/platform-notes.md` marks the rest as
hypotheses with instructions for confirming each one.
