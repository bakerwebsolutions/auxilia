#!/usr/bin/env bash
# orchestrate · SessionStart hook
# Reads orchestrate.config.json and injects the delegation doctrine into the
# session as additionalContext. Config resolution (first match wins):
#   1. $CLAUDE_PROJECT_DIR/.claude/orchestrate.config.json   (per-project override)
#   2. ./orchestrate.config.json                             (cwd override)
#   3. $CLAUDE_PLUGIN_ROOT/orchestrate.config.json           (shipped default)
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

CONFIG=""
for candidate in \
  "$PROJECT_DIR/.claude/orchestrate.config.json" \
  "$PWD/orchestrate.config.json" \
  "$PLUGIN_ROOT/orchestrate.config.json"; do
  if [ -f "$candidate" ]; then CONFIG="$candidate"; break; fi
done

# --- read a scalar key; jq if present, else a tolerant grep/sed fallback -------
read_key() { # read_key <dotted.path> <default>
  local path="$1" def="$2" val=""
  if [ -n "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
    val="$(jq -r --arg d "$def" ".${path} // \$d" "$CONFIG" 2>/dev/null || echo "$def")"
  elif [ -n "$CONFIG" ]; then
    local leaf="${path##*.}"
    val="$(grep -oE "\"${leaf}\"[[:space:]]*:[[:space:]]*(\"[^\"]*\"|[0-9]+|true|false)" "$CONFIG" 2>/dev/null \
            | head -n1 | sed -E 's/.*:[[:space:]]*//; s/^"//; s/"$//')"
    [ -z "$val" ] && val="$def"
  else
    val="$def"
  fi
  printf '%s' "$val"
}

DOCTRINE="$(read_key doctrine standard)"
[ "$DOCTRINE" = "off" ] && exit 0

AUTONOMY="$(read_key autonomy propose)"
EXPLORE="$(read_key tiers.explore haiku)"
IMPLEMENT="$(read_key tiers.implement sonnet)"
VERIFY="$(read_key tiers.verify sonnet)"
MAX_PARALLEL="$(read_key threshold.maxParallelAuto 3)"
MAX_FILES="$(read_key threshold.maxFilesAuto 5)"
PASS_MODEL="$(read_key alwaysPassModelExplicitly true)"

case "$AUTONOMY" in
  auto)      AUTONOMY_LINE="Fan out delegated agents immediately without asking first." ;;
  threshold) AUTONOMY_LINE="Fan out automatically when the plan has <= ${MAX_PARALLEL} parallel units AND touches <= ${MAX_FILES} files; otherwise present the plan and wait for approval." ;;
  *)         AUTONOMY_LINE="Present the decomposition plan and wait for the user's approval before launching agents." ;;
esac

LEAD="Guidance for this session"
[ "$DOCTRINE" = "strict" ] && LEAD="HARD RULES for this session (do not deviate)"

MODEL_LINE=""
if [ "$PASS_MODEL" = "true" ]; then
  MODEL_LINE="- Always pass the \`model\` parameter explicitly in every Agent call (e.g. model: \"${IMPLEMENT}\"). Do not rely on subagent frontmatter alone — the frontmatter model field is unreliable (anthropics/claude-code#44385)."
fi

read -r -d '' CONTEXT <<EOF || true
# orchestrate — delegation doctrine

$LEAD. You are the **orchestrator**. Your job is reasoning, design, planning,
and synthesis. Push hands-on work down the model tiers instead of doing it all yourself.

- **Reason / design / plan / synthesize → you (Opus).** Keep the hard thinking here.
- **Implement targeted, well-defined changes → \`${IMPLEMENT}\`** via the \`implementer\` subagent.
- **Explore / search / locate / read-heavy discovery → \`${EXPLORE}\`** via the \`explorer\` subagent.
- **Run tests / check diffs / confirm done-criteria → \`${VERIFY}\`** via the \`verifier\` subagent.

Before delegating any non-trivial task:
1. Decompose it into units of work.
2. Classify each unit as **parallel** (independent) or **sequential** (depends on a prior unit).
3. Give each delegated agent a **minimal-context brief**: goal · in-scope files · contract · done-criteria · out-of-scope. Send only what that agent needs — not your whole context.
4. Launch independent units concurrently (multiple Agent calls in one message); gate dependent units behind their prerequisites.

Autonomy: $AUTONOMY_LINE
$MODEL_LINE

When the user asks you to "look at parallelization", "decompose", "delegate", or
"orchestrate" a task, run the \`/orchestrate\` skill.
EOF

# Emit as SessionStart additionalContext.
printf '%s' "$CONTEXT" | python3 -c '
import json, sys
print(json.dumps({
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": sys.stdin.read()
  }
}))
' 2>/dev/null || {
  # Fallback: plain stdout is also added to context on SessionStart.
  printf '%s\n' "$CONTEXT"
}
