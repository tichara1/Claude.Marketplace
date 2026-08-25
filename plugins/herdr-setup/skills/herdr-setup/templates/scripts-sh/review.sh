#!/usr/bin/env bash
# Pre-commit review: diff -> agent in headless mode -> output into the popup.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
root="$(h_git_root "$(h_cwd)")"
[ -n "$root" ] && cd "$root"
base="$(h_base_branch .)"
mb="$(git merge-base HEAD "$base" 2>/dev/null)"; [ -n "$mb" ] || mb=HEAD
diff="$( { git diff "$mb"; git diff --cached; } 2>/dev/null )"
[ -n "${diff// /}" ] || { printf 'No diff.\n'; sleep 2; exit 0; }

printf 'Review %s vs %s\n\n' "$(git rev-parse --abbrev-ref HEAD)" "$base"
printf '%s' "$diff" | "$AGENT_KIND" -p "$REVIEW_PROMPT"
read -r -p $'\nEnter closes'
