#!/usr/bin/env bash
# Open a plugin pane entrypoint as a popup (action -> popup bridge).
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
ep="${1:-diff}"
# NOTE: `--placement popup` is valid even though `plugin pane open --help` omits it.
"$HERDR" plugin pane open --plugin "${HERDR_PLUGIN_ID:-$PLUGIN_ID}" --entrypoint "$ep" --placement popup >/dev/null 2>&1
