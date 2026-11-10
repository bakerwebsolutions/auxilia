#!/usr/bin/env bash
# handoff.sh — path resolution + clipboard for the /handoff skill.
#
#   handoff.sh path [--dir DIR] [--slug SLUG]
#       Resolve the handoff directory, reserve a collision-free file in it,
#       and print its absolute path. Directory precedence:
#         1. --dir DIR                    (user said where, this run)
#         2. <repo>/.claude/handoff.json  "dir"  (checked in; relative = repo root)
#         3. ~/.claude/handoff.json       "dir"  (relative = $HOME)
#         4. ${TMPDIR:-/tmp}
#       File name: handoff-<slug>-<6 random digits>.md
#
#   handoff.sh config
#       Print the merged config as JSON (repo over user over defaults).
#
#   handoff.sh copy FILE
#       Copy FILE to the clipboard (wl-copy, xclip, xsel, pbcopy, clip.exe).
#       Exit 3 if no clipboard tool is found.
set -euo pipefail

repo_root() { git rev-parse --show-toplevel 2>/dev/null || true; }

read_json() { # file key
  [[ -f "$1" ]] || return 0
  if command -v jq >/dev/null; then
    jq -r --arg k "$2" 'if has($k) and .[$k] != null then .[$k] | tostring else empty end' "$1" 2>/dev/null || true
  else
    python3 -c 'import json,sys; v=json.load(open(sys.argv[1])).get(sys.argv[2]); print("" if v is None else (json.dumps(v) if not isinstance(v,str) else v))' "$1" "$2" 2>/dev/null || true
  fi
}

ROOT="$(repo_root)"
REPO_CFG="${ROOT:+$ROOT/.claude/handoff.json}"
USER_CFG="$HOME/.claude/handoff.json"

cfg() { # key -> repo value, else user value
  local v=""
  [[ -n "$REPO_CFG" ]] && v="$(read_json "$REPO_CFG" "$1")"
  [[ -z "$v" ]] && v="$(read_json "$USER_CFG" "$1")"
  printf '%s' "$v"
}

expand() { # path, base -> absolute path
  local p="$1" base="$2"
  p="${p/#\~/$HOME}"
  [[ "$p" = /* ]] || p="$base/$p"
  printf '%s' "$p"
}

cmd_path() {
  local dir="" slug="handoff"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) dir="$(expand "$2" "$PWD")"; shift 2 ;;
      --slug) slug="$2"; shift 2 ;;
      *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
  done
  if [[ -z "$dir" && -n "$REPO_CFG" ]]; then
    local d; d="$(read_json "$REPO_CFG" dir)"; [[ -n "$d" ]] && dir="$(expand "$d" "$ROOT")"
  fi
  if [[ -z "$dir" ]]; then
    local d; d="$(read_json "$USER_CFG" dir)"; [[ -n "$d" ]] && dir="$(expand "$d" "$HOME")"
  fi
  [[ -z "$dir" ]] && dir="${TMPDIR:-/tmp}"
  dir="${dir%/}"
  mkdir -p "$dir"

  slug="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-40)"
  [[ -z "$slug" ]] && slug="handoff"
  [[ "$slug" = handoff* ]] || slug="handoff-$slug"

  local f n
  for _ in $(seq 1 50); do
    n="$(printf '%06d' $(( (RANDOM * 32768 + RANDOM) % 1000000 )))"
    f="$dir/$slug-$n.md"
    # noclobber makes the reservation atomic: fails if the file already exists.
    if ( set -o noclobber; : > "$f" ) 2>/dev/null; then
      printf '%s\n' "$(cd "$dir" && pwd)/$slug-$n.md"
      return 0
    fi
  done
  echo "could not reserve a unique file in $dir" >&2; exit 1
}

cmd_config() {
  local dir clip instr
  dir="$(cfg dir)"; clip="$(cfg clipboard)"; instr="$(cfg instructions)"
  jq -n --arg repo "${REPO_CFG:-}" --arg user "$USER_CFG" \
        --arg dir "${dir:-${TMPDIR:-/tmp}}" --arg clip "${clip:-true}" --arg instr "$instr" \
        '{repoConfig: (if $repo == "" then null else $repo end), userConfig: $user, dir: $dir,
          clipboard: ($clip == "true"), instructions: (if $instr == "" then null else $instr end)}' 2>/dev/null \
  || printf '{"dir":"%s","clipboard":%s}\n' "${dir:-${TMPDIR:-/tmp}}" "${clip:-true}"
}

cmd_copy() {
  local f="$1"
  [[ -f "$f" ]] || { echo "no such file: $f" >&2; exit 2; }
  if   [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null; then wl-copy < "$f"
  elif command -v xclip   >/dev/null && [[ -n "${DISPLAY:-}" ]]; then xclip -selection clipboard < "$f"
  elif command -v xsel    >/dev/null && [[ -n "${DISPLAY:-}" ]]; then xsel --clipboard --input < "$f"
  elif command -v pbcopy  >/dev/null; then pbcopy < "$f"
  elif command -v clip.exe >/dev/null; then clip.exe < "$f"
  elif command -v wl-copy >/dev/null; then wl-copy < "$f"
  else echo "no clipboard tool found" >&2; exit 3
  fi
}

case "${1:-}" in
  path)   shift; cmd_path "$@" ;;
  config) shift; cmd_config ;;
  copy)   shift; cmd_copy "$@" ;;
  *) sed -n '2,20p' "$0" >&2; exit 2 ;;
esac
