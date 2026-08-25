#!/usr/bin/env bash
# open-editor.sh <rider|idea|code|cursor|subl|open> [path]
#
# On WSL2 JetBrains IDEs are Windows processes and need a UNC path via `wslpath -w`,
# while VS Code and Cursor run a Remote-WSL server and want the Linux path unchanged.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

what="${1:-$PRIMARY_EDITOR}"
target="${2:-}"
if [ -z "$target" ]; then
  d="$(h_cwd)"
  target="$(h_git_root "$d")"
  [ -n "$target" ] || target="$d"
fi

is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

win_path() {
  if is_wsl; then wslpath -w "$1" 2>/dev/null || printf '%s' "$1"
  else printf '%s' "$1"; fi
}

toolbox_dir() {
  case "$(uname)" in
    Darwin) printf '%s' "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" ;;
    *)      printf '%s' "$HOME/.local/share/JetBrains/Toolbox/scripts" ;;
  esac
}

# Windows .exe binaries reached through WSL interop need the UNC path; everything else
# takes the native path.
launch() {
  for bin in "$@"; do
    if command -v "$bin" >/dev/null 2>&1; then
      case "$bin" in
        *.exe) "$bin" "$(win_path "$target")" >/dev/null 2>&1 & ;;
        *)     "$bin" "$target" >/dev/null 2>&1 & ;;
      esac
      return 0
    fi
    if [ -x "$(toolbox_dir)/$bin" ]; then
      "$(toolbox_dir)/$bin" "$target" >/dev/null 2>&1 &
      return 0
    fi
  done
  return 1
}

ok=1
case "$what" in
  rider)
    if is_wsl; then launch rider.exe rider64.exe; else launch rider; fi
    ok=$? ;;
  idea)
    if is_wsl; then launch idea.exe idea64.exe; else launch idea; fi
    ok=$? ;;
  code)   launch code code-insiders; ok=$? ;;   # Remote-WSL server: Linux path
  cursor) launch cursor; ok=$? ;;
  subl)   launch subl; ok=$? ;;
  open)
    if is_wsl; then
      explorer.exe "$(win_path "$target")"
      ok=0
    else
      case "$(uname)" in
        Darwin) open "$target"; ok=$? ;;
        *)      xdg-open "$target" >/dev/null 2>&1; ok=$? ;;
      esac
    fi ;;
  *)
    printf 'unknown editor: %s\n' "$what" >&2
    ok=1 ;;
esac

if [ "$ok" -eq 0 ]; then
  h_notify "$what" "$(basename "$target")"
else
  h_notify "Could not find $what" "add it to PATH"
fi
