#!/usr/bin/env bash
# Event hook: workspace.created -> start the agent in the root pane.
#
# IMPORTANT: creating a worktree emits BOTH worktree.created AND workspace.created.
# Worktrees are skipped here and handled by bootstrap-worktree.sh, otherwise the agent
# would start twice. The discriminator is data.workspace.worktree - the
# workspace.created payload carries no `branch` field, so testing for one fails.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
[ "${AGENT_AUTOSTART:-1}" = "1" ] || exit 0

ev="$(h_ev)"; [ -n "$ev" ] || exit 0
ws="$(printf '%s' "$ev" | h_jq "d['data']['workspace'].get('workspace_id')")"
[ -n "$ws" ] || exit 0
is_wt="$(printf '%s' "$ev" | h_jq "'1' if d['data']['workspace'].get('worktree') else ''")"
[ -n "$is_wt" ] && exit 0

# The workspace.created payload has no cwd - fetch it from the server.
cwd="$(h_workspace_path "$ws")"
[ -n "$cwd" ] || exit 0
git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0   # git repos only

sleep 1.2
pane="$(h_pane_of_workspace "$ws")"
[ -n "$pane" ] && h_start_agent "$pane" "$(basename "$cwd")" >/dev/null
