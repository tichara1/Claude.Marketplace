#!/usr/bin/env bash
# Sidebar: show only agents in blocked/done state. Press again to restore.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

stateDir="${HERDR_PLUGIN_STATE_DIR:-${TMPDIR:-/tmp}}"
mkdir -p "$stateDir"
flag="$stateDir/attention.on"

# NOTE: `source` must be "plugin:<real-plugin-id>" - an arbitrary string returns
# plugin_not_found.
src="plugin:${HERDR_PLUGIN_ID:-$PLUGIN_ID}"

if [ -f "$flag" ]; then
  rm -f "$flag"
  h_socket "{\"id\":\"v\",\"method\":\"agent.view.clear\",\"params\":{\"source\":\"$src\"}}" >/dev/null
  h_notify "Sidebar" "all agents"
else
  : > "$flag"
  req="{\"id\":\"v\",\"method\":\"agent.view.set\",\"params\":{"
  req="$req\"source\":\"$src\",\"label\":\"waiting\","
  req="$req\"filter\":{\"op\":\"in\",\"field\":\"status\",\"values\":[\"blocked\",\"done\"]},"
  req="$req\"sort\":[{\"field\":\"attention\",\"order\":\"desc\"},"
  req="$req{\"field\":\"state_change_seq\",\"order\":\"desc\"}]}}"
  h_socket "$req" >/dev/null
  h_notify "Sidebar" "blocked / done only" request
fi
