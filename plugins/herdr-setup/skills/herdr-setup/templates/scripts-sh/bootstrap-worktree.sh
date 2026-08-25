#!/usr/bin/env bash
# Event hook: worktree.created
#   1) copy untracked local files from the main checkout
#   2) dev layout (agent | shell / test)
#   3) start the agent with branch context
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

ev="$(h_ev)"; [ -n "$ev" ] || exit 0
ws="$(printf '%s'  "$ev" | h_jq "d['data']['workspace'].get('workspace_id')")"
path="$(printf '%s' "$ev" | h_jq "d['data']['worktree'].get('path')")"
branch="$(printf '%s' "$ev" | h_jq "d['data']['worktree'].get('branch')")"
[ -n "$ws" ] && [ -n "$path" ] || exit 0
path="$(h_path "$path")"

# --- 1) local files -----------------------------------------------------------
main="$(git -C "$path" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10); exit}')"
if [ -n "$main" ] && [ "$main" != "$path" ]; then
  # BOOTSTRAP_COPY holds file names, not glob patterns. Search recursively and skip
  # build directories. -print0 so filenames with spaces survive.
  for nameOnly in $BOOTSTRAP_COPY; do
    while IFS= read -r -d '' f; do
      rel="${f#"$main"/}"
      dst="$path/$rel"
      [ -e "$dst" ] && continue
      mkdir -p "$(dirname "$dst")"
      cp "$f" "$dst"
    done < <(find "$main" \( -name bin -o -name obj -o -name node_modules -o -name .git \) -prune -o \
                    -type f -name "$(basename "$nameOnly")" -print0 2>/dev/null)
  done
fi

# --- 2) layout ----------------------------------------------------------------
root="$(h_pane_of_workspace "$ws")"
right="$(h_json pane split "$root" --direction right --ratio 0.45 --no-focus | h_jq "d['result']['pane']['pane_id']")"
[ -n "$right" ] && "$HERDR" pane split "$right" --direction down --ratio 0.5 --no-focus >/dev/null 2>&1
"$HERDR" pane rename "$root" "$AGENT_KIND" >/dev/null 2>&1

# --- 3) setup command + agent -------------------------------------------------
if [ -n "$right" ] && [ -n "${WORKTREE_SETUP_COMMAND:-}" ]; then
  "$HERDR" pane run "$right" "cd '$path'; $WORKTREE_SETUP_COMMAND" >/dev/null 2>&1
fi
prompt="${WORKTREE_PROMPT//\{branch\}/$branch}"
prompt="${prompt//\{path\}/$path}"
h_start_agent "$root" "${branch:-worktree}" "$prompt" >/dev/null

h_notify "Worktree ready" "${branch:-$(basename "$path")}" done
