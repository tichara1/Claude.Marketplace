#!/usr/bin/env bash
# Cleanup: worktrees whose branch is already merged into base.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
root="$(h_git_root "$(h_cwd)")"
[ -n "$root" ] || exit 1
cd "$root" || exit 1
base="$(h_base_branch .)"
git fetch -q --prune 2>/dev/null

printf 'Merged worktrees (base: %s)\n\n' "$base"
cands=()
while IFS= read -r wt; do
  [ "$wt" = "$root" ] && continue
  b="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if git merge-base --is-ancestor "$b" "$base" 2>/dev/null; then
    dirty="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$dirty" -gt 0 ]; then printf '  %s  -> %s (! %s changes)\n' "$b" "$wt" "$dirty"
    else printf '  %s  -> %s\n' "$b" "$wt"; fi
    cands+=("$wt")
  fi
done < <(git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}')

[ "${#cands[@]}" -eq 0 ] && { printf '  nothing to clean\n'; sleep 2; exit 0; }

read -r -p $'\nDelete all? [y/N] ' ok
case "$ok" in [yY]*) ;; *) exit 0 ;; esac

# `workspace list` has no cwd; for a worktree the path is worktree.checkout_path.
wsList="$(h_json workspace list)"
for wt in "${cands[@]}"; do
  ws="$(printf '%s' "$wsList" | h_jq "next((w['workspace_id'] for w in d['result']['workspaces'] if (w.get('worktree') or {}).get('checkout_path','').rstrip('/') == '$wt'), None)")"
  if [ -n "$ws" ]; then
    "$HERDR" worktree remove --workspace "$ws" >/dev/null 2>&1 || \
      "$HERDR" worktree remove --workspace "$ws" --force >/dev/null 2>&1
  else
    git worktree remove "$wt" 2>/dev/null || git worktree remove --force "$wt"
  fi
  printf '  OK %s\n' "$wt"
done
sleep 2
