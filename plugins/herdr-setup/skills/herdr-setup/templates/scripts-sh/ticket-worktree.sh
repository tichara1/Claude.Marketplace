#!/usr/bin/env bash
# Link handler: Ctrl+click a GitHub issue / Jira ticket -> worktree named after it.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

url="${HERDR_PLUGIN_CLICKED_URL:-${1:-}}"
[ -n "$url" ] || exit 0

root="$(h_git_root "$(h_cwd)")"
[ -n "$root" ] || exit 0

case "$url" in
  *atlassian.net/browse/*) key="${url##*/}" ;;
  *github.com/*)           key="gh-${url##*/}" ;;
  *)                       key="task-$(date +%H%M)" ;;
esac
branch="$WORKTREE_PREFIX/$(h_slug "$key")"

out="$("$HERDR" worktree create --cwd "$root" --branch "$branch" --label "$key" --focus 2>&1)"
case "$out" in
  *'"error"'*) h_notify "Worktree failed" "$key"; exit 1 ;;
esac

ws="$(printf '%s' "$out" | h_jq "d['result']['workspace']['workspace_id']")"
if [ -n "$ws" ]; then
  "$HERDR" workspace report-metadata "$ws" --source "plugin:$PLUGIN_ID" --token "ticket=$key" >/dev/null 2>&1
fi
h_notify "Worktree from ticket" "$key" done
