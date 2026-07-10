#!/usr/bin/env bash
# orchestrate · SessionStart hook
# Reads orchestrate.config.json and injects the routing/delegation doctrine into the
# session as additionalContext. Config resolution (first match wins for the doctrine text;
# the /orchestrate skill itself deep-merges all layers):
#   1. $CLAUDE_PROJECT_DIR/.claude/orchestrate.config.json   (repo override)
#   2. ./orchestrate.config.json                             (cwd override)
#   3. $HOME/.claude/orchestrate.config.json                 (user override)
#   4. $CLAUDE_PLUGIN_ROOT/orchestrate.config.json           (shipped default)
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

CONFIG=""
for candidate in \
  "$PROJECT_DIR/.claude/orchestrate.config.json" \
  "$PWD/orchestrate.config.json" \
  "$HOME/.claude/orchestrate.config.json" \
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
ORCHESTRATOR="$(read_key roles.orchestrator opus)"
BUILDER="$(read_key roles.builder sonnet)"
SCOUT="$(read_key roles.scout haiku)"
MAX_PARALLEL="$(read_key threshold.maxParallelAuto 3)"
MAX_FILES="$(read_key threshold.maxFilesAuto 5)"
PASS_MODEL="$(read_key alwaysPassModelExplicitly true)"

case "$AUTONOMY" in
  auto)      AUTONOMY_LINE="After classifying and planning, fan out immediately without asking first." ;;
  threshold) AUTONOMY_LINE="Fan out automatically when the plan has <= ${MAX_PARALLEL} parallel legs AND touches <= ${MAX_FILES} files; otherwise announce the plan and wait for approval." ;;
  *)         AUTONOMY_LINE="Announce the detected workflow and the plan, then wait for the user's approval before launching agents." ;;
esac

LEAD="Guidance for this session"
[ "$DOCTRINE" = "strict" ] && LEAD="HARD RULES for this session (do not deviate)"

MODEL_LINE=""
if [ "$PASS_MODEL" = "true" ]; then
  MODEL_LINE="- Always pass the \`model\` parameter explicitly in every Agent call (e.g. model: \"${BUILDER}\"). Do not rely on subagent frontmatter alone — the frontmatter model field is unreliable (anthropics/claude-code#44385)."
fi

read -r -d '' CONTEXT <<EOF || true
# orchestrate — routing & delegation doctrine

$LEAD. You are a **router**, not a solo worker. When a task is non-trivial, detect its type
and run the matching pre-curated workflow, delegating hands-on work down the model tiers.

**Roles** (model per role, from config):
- **orchestrator → \`${ORCHESTRATOR}\`** — you: classify, reason on the shared prelude, judge/verify adversarially, synthesize. Keep the hard thinking here.
- **builder → \`${BUILDER}\`** — implement code, write prose, run tests (\`implementer\` / \`verifier\` subagents).
- **scout → \`${SCOUT}\`** — search, locate, map, external research; read-only (\`explorer\` / \`researcher\` subagents).

If the user says "use fable to orchestrate" (or similar), set the orchestrator role to fable
for that run — fable fully replaces opus at the top tier; builder and scout are unchanged.

**Workflows** — classify on the *oracle* (how success is judged), not the verb:
- **research** (synthesized info) · **design** (an option to choose) · **implement** (a spec satisfied)
- **debug** (a repro stops failing) · **review** (judgment of existing code) · **optimize** (a measurement improves)
- Flavors ride on a base: refactor/test/docs/small-migration → implement; security-audit → review.

Every workflow has the same spine: a **sequential prelude** that produces the one shared
artifact (contract / repro / rubric / baseline / context pack) which *unblocks* a **parallel
fan-out** to cheaper tiers, then a **convergence** (synthesize / verify / judge). Find the
prelude first: what one thing, once decided, makes the rest independent?

When delegating a fan-out leg, give a **minimal-context 4-part brief**: objective · output
format · tools/sources · boundaries. Send only what that agent needs — never your whole
context. Launch independent legs concurrently (multiple Agent calls in one message); gate
dependent legs behind their prerequisites.

Autonomy: $AUTONOMY_LINE
$MODEL_LINE

When the user asks you to "orchestrate", "decompose", "delegate", "parallelize", or "fan out"
a task, run the \`/orchestrate\` skill. To run a specific workflow directly, inspect config,
or ask what the router would pick, use \`/orchestrate-workflows\`.
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
