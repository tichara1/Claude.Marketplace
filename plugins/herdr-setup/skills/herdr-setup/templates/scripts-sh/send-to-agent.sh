#!/usr/bin/env bash
# Send a list of files as a prompt to the agent running in this workspace.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
[ $# -gt 0 ] || exit 0
ws="$(h_workspace_id)"
target="$(h_json agent list | h_jq "next((a.get('name') or a['pane_id'] for a in d['result']['agents'] if a.get('workspace_id')=='$ws'), None)")"
[ -n "$target" ] || { h_notify "No agent" "no agent running in this workspace"; exit 0; }
IFS=', '; files="$*"; unset IFS
"$HERDR" agent prompt "$target" "$SEND_FILES_PROMPT: $files" >/dev/null 2>&1
h_notify "Sent to agent" "$# file(s)"
