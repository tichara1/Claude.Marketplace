#!/usr/bin/env bash
# New worktree with a branch prefix. Bound to a popup key.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

root="$(h_git_root "$(h_cwd)")"
[ -n "$root" ] || { printf 'This workspace is not a git repo.\n'; sleep 2; exit 1; }
cd "$root" || exit 1

printf 'New worktree  repo: %s\n' "$(basename "$root")"
printf 'prefix: %s/\n' "$WORKTREE_PREFIX"
printf '(change WORKTREE_PREFIX in settings.sh)\n\n'

read -r -p "name (e.g. 'kafka retry' or 'EETS-1234 toll sync'): " raw
[ -n "${raw// /}" ] || exit 0

ticket="$(printf '%s' "$raw" | grep -oE '^[A-Z][A-Z0-9]+-[0-9]+' || true)"
if [ -n "$ticket" ]; then
  rest="$(h_slug "${raw#"$ticket"}")"
  branch="$WORKTREE_PREFIX/$(printf '%s' "$ticket" | tr '[:upper:]' '[:lower:]')-$rest"
  branch="${branch%-}"
else
  branch="$WORKTREE_PREFIX/$(h_slug "$raw")"
fi

defBase="$(h_base_branch "$root")"
read -r -p "base ref [$defBase]: " base
[ -n "$base" ] || base="$defBase"

printf '\n-> branch: %s\n-> base:   %s\n\n' "$branch" "$base"
read -r -p 'Create? [Y/n] ' ok
case "$ok" in [nN]*) exit 0 ;; esac

label="${ticket:-$(h_slug "$raw")}"
out="$("$HERDR" worktree create --cwd "$root" --branch "$branch" --base "$base" --label "$label" --focus 2>&1)"
case "$out" in
  *'"error"'*) printf '%s\n' "$out"; read -r -p 'Enter closes'; exit 1 ;;
esac
printf 'OK - bootstrap runs in the background (worktree.created hook)\n'
sleep 1
