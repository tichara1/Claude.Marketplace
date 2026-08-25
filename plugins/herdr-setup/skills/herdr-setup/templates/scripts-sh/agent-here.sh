#!/usr/bin/env bash
# Start the agent in the current (or root) pane of this workspace.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
ws="$(h_workspace_id)"
pane="${HERDR_PANE_ID:-$(h_pane_of_workspace "$ws")}"
[ -n "$pane" ] || exit 1
label="$(basename "$(h_cwd)")"
name="$(h_start_agent "$pane" "$label")" && h_notify "Agent running" "$label ($name)" done
