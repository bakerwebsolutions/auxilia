#!/usr/bin/env bash
# orchestrate · worktree lifecycle for work-graph nodes
#
# One git worktree + branch per writing node, so parallel builders never share a checkout.
# Every path this script touches lives under <repo>/.orchestrate/worktrees/<run>/ and every
# branch under orchestrate/<run>/ — it never removes anything outside that namespace, which
# is what makes it safe to allowlist.
#
#   worktree.sh create  <run> <node> [base] [--link <path>]...
#                                             new worktree + branch from base (default: HEAD); prints path.
#                                             --link symlinks a gitignored path (node_modules, .env, …)
#                                             from the main checkout so the node can build and test
#   worktree.sh path    <run> <node>          print the node's worktree path
#   worktree.sh status  [run]                 list orchestrate worktrees (all runs if omitted)
#   worktree.sh merge   <run> <node>          commit leftovers in the node, merge it into the current branch
#   worktree.sh remove  <run> <node> [--force] remove one node's worktree + branch
#   worktree.sh cleanup <run|--all> [--force] remove every worktree + branch of a run (or of all runs)
#
# Without --force, remove/cleanup keep any branch that is not merged into HEAD and say so.
set -euo pipefail

die() { printf 'worktree.sh: %s\n' "$*" >&2; exit 1; }
usage() { sed -n '4,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2; }

valid_id() { [[ "$1" =~ ^[a-z0-9][a-z0-9._-]{0,63}$ ]] && [[ "$1" != *..* ]] || die "invalid id '$1' (want [a-z0-9][a-z0-9._-]*)"; }

# Always operate from the main checkout, even when invoked from inside a node worktree.
COMMON_DIR="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || die "not inside a git repository"
REPO="$(dirname "$COMMON_DIR")"
[ "$(basename "$COMMON_DIR")" = ".git" ] || die "bare or unusual repository layout ($COMMON_DIR); refusing"
ROOT="$REPO/.orchestrate/worktrees"
g() { git -C "$REPO" "$@"; }

ensure_excluded() { # ensure_excluded <pattern> — append to the repo-local exclude once
  local exclude="$COMMON_DIR/info/exclude"
  mkdir -p "$(dirname "$exclude")"
  grep -qxF "$1" "$exclude" 2>/dev/null || printf '%s\n' "$1" >> "$exclude"
}

node_path()   { printf '%s/%s/%s' "$ROOT" "$1" "$2"; }
node_branch() { printf 'orchestrate/%s/%s' "$1" "$2"; }

is_merged() { # is_merged <branch> — merged into the main checkout's HEAD?
  g merge-base --is-ancestor "$1" HEAD 2>/dev/null
}

remove_node() { # remove_node <run> <node> <force:0|1>
  local run="$1" node="$2" force="$3" path branch has_branch=0
  path="$(node_path "$run" "$node")"; branch="$(node_branch "$run" "$node")"
  g show-ref --verify --quiet "refs/heads/$branch" && has_branch=1
  if [ "$force" = 0 ]; then
    if [ -d "$path" ] && [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
      echo "kept $run/$node: worktree has uncommitted changes (merge it first, or --force to discard)"; return 1
    fi
    if [ "$has_branch" = 1 ] && ! is_merged "$branch"; then
      echo "kept $run/$node: $branch is not merged into HEAD (merge it first, or --force to discard)"; return 1
    fi
  fi
  if [ -d "$path" ]; then g worktree remove --force "$path" && echo "removed worktree $path"; fi
  if [ "$has_branch" = 1 ]; then g branch -D "$branch" >/dev/null && echo "deleted branch $branch"; fi
}

cmd="${1:-}"; [ -n "$cmd" ] || usage; shift

case "$cmd" in
  create)
    [ $# -ge 2 ] || usage
    run="$1"; node="$2"; shift 2; valid_id "$run"; valid_id "$node"
    base="HEAD"; links=()
    if [ $# -gt 0 ] && [[ "$1" != --* ]]; then base="$1"; shift; fi
    while [ $# -gt 0 ]; do
      [ "$1" = "--link" ] && [ $# -ge 2 ] || usage
      links+=("${2%/}"); shift 2
    done
    path="$(node_path "$run" "$node")"; branch="$(node_branch "$run" "$node")"
    [ -e "$path" ] && die "$path already exists"
    g rev-parse --verify --quiet "$base^{commit}" >/dev/null || die "unknown base '$base'"
    # Only gitignored paths may be linked: they can never be committed by `merge`, and a
    # link can't reach outside the main checkout.
    for l in "${links[@]:-}"; do
      [ -n "$l" ] || continue
      [[ "$l" != /* && "/$l/" != */../* && "/$l/" != */./* ]] || die "--link '$l': want a path relative to the repo root"
      [ -e "$REPO/$l" ] || die "--link '$l': not found in $REPO"
      g check-ignore -q "$l" || die "--link '$l': not gitignored; only ignored paths (dependencies, env files, build output) can be linked"
    done
    ensure_excluded '/.orchestrate/'
    mkdir -p "$(dirname "$path")"
    g worktree add --quiet -b "$branch" "$path" "$base" >&2
    for l in "${links[@]:-}"; do
      [ -n "$l" ] || continue
      [ -e "$path/$l" ] && { echo "skipped link $l: already present in the worktree" >&2; continue; }
      mkdir -p "$(dirname "$path/$l")"
      ln -s "$REPO/$l" "$path/$l"
      # A directory-only ignore rule (`node_modules/`) doesn't match a symlink, so without
      # this exact-path rule `merge` would commit the link over the real directory.
      ensure_excluded "/$l"
    done
    printf '%s\n' "$path"
    ;;

  path)
    [ $# -eq 2 ] || usage; valid_id "$1"; valid_id "$2"
    node_path "$1" "$2"; echo
    ;;

  status)
    [ $# -le 1 ] || usage; [ $# -eq 1 ] && valid_id "$1"
    prefix="$ROOT/${1:-}"
    found=0
    while IFS= read -r line; do
      case "$line" in
        "worktree "*) wt="${line#worktree }" ;;
        "branch "*)
          br="${line#branch refs/heads/}"
          [[ "$wt" == "$prefix"* ]] || continue
          found=1
          ahead="$(g rev-list --count "HEAD..$br")"
          if [ -n "$(git -C "$wt" status --porcelain)" ]; then dirty="dirty"; merged="unmerged"
          else dirty="clean"; merged="unmerged"; is_merged "$br" && merged="merged"; fi
          printf '%s\t%s\t%s\t+%s commits\t%s\n' "${wt#"$ROOT/"}" "$br" "$dirty" "$ahead" "$merged"
          ;;
      esac
    done < <(g worktree list --porcelain)
    [ "$found" = 1 ] || echo "no orchestrate worktrees${1:+ for run $1}"
    ;;

  merge)
    [ $# -eq 2 ] || usage
    run="$1"; node="$2"; valid_id "$run"; valid_id "$node"
    path="$(node_path "$run" "$node")"; branch="$(node_branch "$run" "$node")"
    [ -d "$path" ] || die "no worktree for $run/$node"
    g diff --quiet && g diff --cached --quiet || die "main checkout $REPO has uncommitted tracked changes; commit or stash them before merging"
    if [ -n "$(git -C "$path" status --porcelain)" ]; then
      git -C "$path" add -A
      if typechange="$(git -C "$path" diff --cached --name-only --diff-filter=T)" && [ -n "$typechange" ]; then
        git -C "$path" reset --quiet
        die "$run/$node replaces files with symlinks or vice versa ($typechange); refusing to merge — inspect $path"
      fi
      git -C "$path" commit --quiet --no-verify -m "orchestrate($run): $node"
    fi
    if [ "$(g rev-list --count "HEAD..$branch")" = 0 ]; then
      echo "$node: nothing to merge"; exit 0
    fi
    if g merge --no-ff --no-edit -m "orchestrate($run): merge $node" "$branch" >/dev/null 2>&1; then
      echo "merged $branch into $(g rev-parse --abbrev-ref HEAD)"
      g diff --stat HEAD^1 HEAD
    else
      conflicts="$(g diff --name-only --diff-filter=U)"
      g merge --abort 2>/dev/null || true
      printf 'CONFLICT merging %s; merge aborted, worktree kept at %s\nconflicting files:\n%s\n' "$branch" "$path" "$conflicts" >&2
      exit 3
    fi
    ;;

  remove)
    [ $# -ge 2 ] || usage
    run="$1"; node="$2"; force=0; [ "${3:-}" = "--force" ] && force=1
    valid_id "$run"; valid_id "$node"
    remove_node "$run" "$node" "$force"
    g worktree prune
    ;;

  cleanup)
    [ $# -ge 1 ] || usage
    target="$1"; force=0; [ "${2:-}" = "--force" ] && force=1
    if [ "$target" = "--all" ]; then
      runs=(); [ -d "$ROOT" ] && for d in "$ROOT"/*/; do [ -d "$d" ] && runs+=("$(basename "$d")"); done
      # Branches whose worktree directory is already gone still count.
      while IFS= read -r b; do r="${b#orchestrate/}"; runs+=("${r%%/*}"); done \
        < <(g for-each-ref --format='%(refname:short)' 'refs/heads/orchestrate/*/*')
    else
      valid_id "$target"; runs=("$target")
    fi
    status=0
    for run in $(printf '%s\n' "${runs[@]:-}" | sort -u); do
      [ -n "$run" ] || continue
      nodes=()
      [ -d "$ROOT/$run" ] && for d in "$ROOT/$run"/*/; do [ -d "$d" ] && nodes+=("$(basename "$d")"); done
      while IFS= read -r b; do nodes+=("${b#orchestrate/"$run"/}"); done \
        < <(g for-each-ref --format='%(refname:short)' "refs/heads/orchestrate/$run/*")
      for node in $(printf '%s\n' "${nodes[@]:-}" | sort -u); do
        [ -n "$node" ] || continue
        remove_node "$run" "$node" "$force" || status=1
      done
      rmdir "$ROOT/$run" 2>/dev/null || true
    done
    g worktree prune
    rmdir "$ROOT" "$REPO/.orchestrate" 2>/dev/null || true
    exit "$status"
    ;;

  -h|--help|help) usage ;;
  *) die "unknown command '$cmd'" ;;
esac
