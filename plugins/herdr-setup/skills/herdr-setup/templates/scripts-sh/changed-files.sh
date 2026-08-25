#!/usr/bin/env bash
# "What changed" - files vs the base branch. fzf optional.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

root="$(h_git_root "$(h_cwd)")"
[ -n "$root" ] || { printf 'not a git repo\n'; sleep 2; exit 1; }
cd "$root" || exit 1

base="$(h_base_branch .)"
mb="$(git merge-base HEAD "$base" 2>/dev/null)"; [ -n "$mb" ] || mb=HEAD

files="$( { git diff --name-only "$mb"; git diff --name-only; git ls-files --others --exclude-standard; } \
          2>/dev/null | awk 'NF && !seen[$0]++' )"
[ -n "$files" ] || { printf 'Clean.  base: %s\n' "$base"; sleep 2; exit 0; }

branch="$(git rev-parse --abbrev-ref HEAD)"
printf '%s vs %s   %s files   %s\n\n' "$branch" "$base" \
  "$(printf '%s\n' "$files" | wc -l | tr -d ' ')" "$(git diff --shortstat "$mb")"

if ! command -v fzf >/dev/null 2>&1; then
  git -c color.ui=always diff --stat "$mb"
  printf '\n(fzf not installed -> listing only)\n'
  read -r -p 'Enter closes'; exit 0
fi

prev="git -c color.ui=always diff $mb -- {} | delta 2>/dev/null || git -c color.ui=always diff $mb -- {}"
mapfile -t sel < <(printf '%s\n' "$files" | fzf --ansi --multi --height=100% --border \
  --header="enter=primary editor  ctrl-e=secondary  ctrl-y=copy  ctrl-a=send to agent" \
  --preview="$prev" --preview-window="right,65%,border-left" \
  --expect=ctrl-e,ctrl-y,ctrl-a)

# With --expect the first line is the pressed key (empty when none of them was).
[ "${#sel[@]}" -lt 2 ] && exit 0
key="${sel[0]}"
picks=()
for f in "${sel[@]:1}"; do picks+=("$root/$f"); done

case "$key" in
  ctrl-e) "$_LIB_DIR/open-editor.sh" "$SECONDARY_EDITOR" "${picks[0]}" ;;
  ctrl-y) printf '%s\n' "${picks[@]}" | { command -v pbcopy >/dev/null && pbcopy || xclip -selection clipboard; } ;;
  ctrl-a) "$_LIB_DIR/send-to-agent.sh" "${picks[@]}" ;;
  *)      "$_LIB_DIR/open-editor.sh" "$PRIMARY_EDITOR" "${picks[0]}" ;;
esac
