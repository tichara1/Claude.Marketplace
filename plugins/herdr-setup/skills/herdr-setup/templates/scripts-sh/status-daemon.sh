#!/usr/bin/env bash
# Background poller: fills the sidebar tokens $mod, $untracked and $sync per space.
#
# IMPORTANT: `workspace list` has NO cwd field. A loop testing it skips every workspace
# and reports nothing, forever, while looking perfectly healthy. h_workspace_path
# resolves the path via worktree.checkout_path or the first pane.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# Single instance. flock where available; a pid file otherwise (stock macOS has no
# flock). A pid file alone is not enough on its own because HERDR_PLUGIN_STATE_DIR only
# exists in plugin context, so a manual run would track state elsewhere.
LOCK_DIR="${HERDR_PLUGIN_STATE_DIR:-${TMPDIR:-/tmp}}"
mkdir -p "$LOCK_DIR"
LOCK="$LOCK_DIR/status-daemon.lock"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK"
  flock -n 9 || exit 0
else
  if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then exit 0; fi
  printf '%s' "$$" > "$LOCK"
fi

# Fetch must never block on credentials - without this the daemon freezes forever on a
# repo that asks for a password.
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/echo

# Dedupe key for fetching. Several worktrees share one parent repo, so fetch once per
# repo rather than once per workspace. bash 3.2 (stock macOS) has no associative
# arrays, so the timestamps live in files instead.
FETCH_STATE="$LOCK_DIR/fetch"
mkdir -p "$FETCH_STATE"

repo_key() { git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null; }

repo_fetch() {
  dir="$1"
  key="$2"
  [ "${FETCH_INTERVAL_SECONDS:-0}" -gt 0 ] || return 0
  stamp="$FETCH_STATE/$(printf '%s' "$key" | cksum | cut -d' ' -f1)"
  now="$(date +%s)"
  last=0
  [ -f "$stamp" ] && last="$(cat "$stamp" 2>/dev/null || echo 0)"
  [ $(( now - last )) -lt "$FETCH_INTERVAL_SECONDS" ] && return 0
  # Stamp even on failure so an unreachable remote is not retried every cycle.
  printf '%s' "$now" > "$stamp"

  git -C "$dir" fetch --quiet --prune >/dev/null 2>&1 &
  fpid=$!
  waited=0
  limit=$(( FETCH_TIMEOUT_MS / 1000 ))
  while kill -0 "$fpid" 2>/dev/null; do
    [ "$waited" -ge "$limit" ] && { kill "$fpid" 2>/dev/null; break; }
    sleep 1
    waited=$(( waited + 1 ))
  done
  wait "$fpid" 2>/dev/null
  return 0
}

while :; do
  while IFS= read -r ws; do
    [ -n "$ws" ] || continue
    d="$(h_workspace_path "$ws")"
    [ -n "$d" ] || continue
    key="$(repo_key "$d")"
    [ -n "$key" ] || continue    # not a git repo

    # -uall expands untracked directories into individual files; without it a whole new
    # directory counts as a single entry.
    lines="$(git -C "$d" status --porcelain --untracked-files=all 2>/dev/null)"
    total=0
    untracked=0
    if [ -n "$lines" ]; then
      total="$(printf '%s\n' "$lines" | wc -l | tr -d ' ')"
      untracked="$(printf '%s\n' "$lines" | grep -c '^??' || true)"
    fi
    mod=$(( total - untracked ))

    sync=""
    ab="$(git -C "$d" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)"
    if [ -n "$ab" ]; then
      # left = commits only upstream (behind), right = commits only in HEAD (ahead)
      behind="${ab%%[[:space:]]*}"
      ahead="${ab##*[[:space:]]}"
      if [ "${ahead:-0}" -gt 0 ] 2>/dev/null; then sync="^$ahead"; fi
      if [ "${behind:-0}" -gt 0 ] 2>/dev/null; then sync="${sync}v$behind"; fi
    fi

    modTok=""
    untTok=""
    [ "$mod" -gt 0 ] && modTok="~$mod"
    [ "$untracked" -gt 0 ] && untTok="?$untracked"

    # Tokens are reported BEFORE fetching so the sidebar fills immediately on startup
    # instead of waiting on the network. The fetch shows up next cycle.
    "$HERDR" workspace report-metadata "$ws" \
      --source "plugin:$PLUGIN_ID" \
      --token "mod=$modTok" --token "untracked=$untTok" --token "sync=$sync" \
      --ttl-ms $(( (STATUS_INTERVAL + 60) * 1000 )) >/dev/null 2>&1

    repo_fetch "$d" "$key"
  done < <(h_json workspace list | h_jq "chr(10).join(w['workspace_id'] for w in d['result']['workspaces'])")
  sleep "$STATUS_INTERVAL"
done
