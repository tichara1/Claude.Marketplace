#!/usr/bin/env bash
# [[startup]] hook - launch the daemon in the background and exit (a hook is not a
# supervisor).
#
# IMPORTANT: [[startup]] only runs at SERVER START, not on plugin link/unlink. After
# changing the daemon you must restart the herdr server or run this script by hand.
#
# Double-launch is prevented by the daemon itself (flock / pid file).
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nohup "$DIR/status-daemon.sh" >/dev/null 2>&1 &
disown 2>/dev/null || true
