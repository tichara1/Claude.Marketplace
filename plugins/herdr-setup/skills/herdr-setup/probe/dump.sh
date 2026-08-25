#!/usr/bin/env bash
# Calibration probe. Dumps every HERDR_* variable so the installer can learn the
# real shape of HERDR_PLUGIN_CONTEXT_JSON / HERDR_PLUGIN_EVENT_JSON on this build.
# Argument 1 is a tag identifying which trigger fired.
set -uo pipefail

tag="${1:-unknown}"
dir="${HERDR_PLUGIN_STATE_DIR:-${TMPDIR:-/tmp}}"
mkdir -p "$dir"
out="$dir/probe-$tag.json"

# Written as raw JSON rather than via jq - jq is not guaranteed present, and the
# installer parses this file itself.
esc() { printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null \
        || printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }

{
  printf '{\n'
  printf '  "tag": %s,\n' "$(esc "$tag")"
  printf '  "cwd": %s,\n' "$(esc "$PWD")"
  printf '  "herdr_vars": {\n'
  first=1
  while IFS='=' read -r name value; do
    case "$name" in
      HERDR*)
        [ $first -eq 0 ] && printf ',\n'
        first=0
        printf '    %s: %s' "$(esc "$name")" "$(esc "$value")"
        ;;
    esac
  done < <(env)
  printf '\n  },\n'
  printf '  "all_var_names": ['
  first=1
  while IFS='=' read -r name _; do
    [ $first -eq 0 ] && printf ', '
    first=0
    printf '%s' "$(esc "$name")"
  done < <(env | sort)
  printf ']\n}\n'
} > "$out"

printf 'probe:%s\n' "$out"
