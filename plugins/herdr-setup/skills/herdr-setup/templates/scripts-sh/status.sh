#!/usr/bin/env bash
# Tab bar right edge: branch, change count, how many agents are waiting.
#
# IMPORTANT: HERDR_ACTIVE_PANE_CWD does not exist. The focused pane has to come from
# `herdr pane current`.
set -uo pipefail
HERDR="${HERDR_BIN_PATH:-herdr}"

jq_() { python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
try: v=$1
except Exception: sys.exit(0)
if v is not None: print(v)
" 2>/dev/null; }

out=""
d="$("$HERDR" pane current 2>/dev/null | jq_ "d['result']['pane'].get('cwd')")"
if [ -n "$d" ]; then
  d="${d%/}"
  b="$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [ -n "$b" ]; then
    n="$(git -C "$d" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    ab="$(git -C "$d" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)"
    sync=""
    if [ -n "$ab" ]; then
      behind="${ab%%[[:space:]]*}"; ahead="${ab##*[[:space:]]}"
      [ "${ahead:-0}"  -gt 0 ] 2>/dev/null && sync="^$ahead"
      [ "${behind:-0}" -gt 0 ] 2>/dev/null && sync="${sync}v$behind"
    fi
    out="$b"
    [ "$n" -gt 0 ] && out="$out +-$n"
    [ -n "$sync" ] && out="$out $sync"
  fi
fi
w="$("$HERDR" agent list 2>/dev/null | jq_ "sum(1 for a in d['result']['agents'] if a.get('agent_status') in ('blocked','done'))")"
[ "${w:-0}" -gt 0 ] 2>/dev/null && out="$out  !$w"
printf '%s' "$out"
