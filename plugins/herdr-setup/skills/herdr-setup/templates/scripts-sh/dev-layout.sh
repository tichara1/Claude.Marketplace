#!/usr/bin/env bash
# Dev layout: [ agent | shell / test ]
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
ws="$(h_workspace_id)"
root="${HERDR_PANE_ID:-$(h_pane_of_workspace "$ws")}"
[ -n "$root" ] || exit 1
right="$(h_json pane split "$root" --direction right --ratio 0.45 --no-focus | h_jq "d['result']['pane']['pane_id']")"
[ -n "$right" ] && "$HERDR" pane split "$right" --direction down --ratio 0.5 --no-focus >/dev/null 2>&1
"$HERDR" pane rename "$root" "$AGENT_KIND" >/dev/null 2>&1
h_start_agent "$root" "$(basename "$(h_cwd)")" >/dev/null
