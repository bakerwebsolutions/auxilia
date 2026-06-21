---
name: orchestrate
description: Decompose a task into a parallel/sequential plan and delegate it down the model tiers. Use when the user says "look at parallelization", "decompose", "delegate this", "orchestrate", or hands you a multi-part task that should be split across agents. Keeps Opus on reasoning/design while implementation goes to Sonnet and exploration goes to Haiku.
---

# orchestrate

Turn a task into a **delegation plan** and run it. You (Opus) stay the orchestrator:
you decompose, write tight briefs, fan out work to cheaper tiers, and synthesize.
You do not hand the *thinking* to a subagent — only the well-defined *doing*.

## Step 0 — Load config

Read the active config (first match wins):

1. `$CLAUDE_PROJECT_DIR/.claude/orchestrate.config.json`
2. `./orchestrate.config.json`
3. `${CLAUDE_PLUGIN_ROOT}/orchestrate.config.json` (shipped default)

Keys you act on: `autonomy`, `threshold.maxParallelAuto`, `threshold.maxFilesAuto`,
`tiers.explore|implement|verify`, `alwaysPassModelExplicitly`. If no file is found,
use defaults: `autonomy=propose`, tiers `haiku/sonnet/sonnet`, pass model explicitly.

## Step 1 — Understand before splitting

If the task touches code you don't already understand, delegate discovery first:
launch one or more **`explorer`** agents (model from `tiers.explore`) to map the
relevant files, contracts, and call sites. Wait for their findings. Do not guess
the decomposition from an unread codebase.

## Step 2 — Decompose

Break the task into **units of work**. For each unit decide:

- **Parallel** — independent of every other unit's output, or
- **Sequential** — depends on a prior unit (note which one).

Find the real seam: what can run concurrently vs. what is a hard dependency chain.
Collapse trivial units; don't create an agent for a one-line edit you can do inline.

## Step 3 — Write a minimal-context brief per unit

Each delegated unit gets a self-contained brief — only what that agent needs:

```
Goal:         <what to make true>
In-scope:     <files/dirs the agent may touch>
Contract:     <interface / behavior to satisfy>
Done-criteria:<how completion is checked>
Out-of-scope: <what to leave alone>
```

Do **not** forward your whole conversation. The point is a tight, targeted prompt.

## Step 4 — Present the plan

Show the user a compact plan:

- the units, each tagged `[parallel]` or `[sequential after #N]`,
- the tier each will run on,
- a one-line brief summary per unit.

## Step 5 — Decide to fan out, per `autonomy`

- **`propose`** (default): stop here and ask for approval before launching.
- **`auto`**: launch immediately.
- **`threshold`**: launch immediately only if `parallel units <= maxParallelAuto`
  **and** `total files touched <= maxFilesAuto`; otherwise fall back to `propose`.

## Step 6 — Execute the plan

- Launch all **parallel** units **in a single message** (multiple Agent calls) so
  they run concurrently. Use the **`implementer`** agent for code, **`explorer`**
  for more discovery.
- Gate **sequential** units: launch each only after its prerequisite returns, and
  fold the prerequisite's result into the next brief.
- **Pass `model` explicitly** on every Agent call when `alwaysPassModelExplicitly`
  is true (e.g. `model: "sonnet"`) — the subagent frontmatter model field is
  unreliable (anthropics/claude-code#44385).
- If agent teams are enabled, these same agent definitions (`explorer`,
  `implementer`, `verifier`) work as teammate types.

## Step 7 — Verify and synthesize

- For units with checkable done-criteria, run a **`verifier`** agent (model from
  `tiers.verify`) — independently confirm rather than trusting the implementer's
  self-report.
- Collect results, reconcile conflicts, and report back: what's done, what each
  agent changed, verification outcomes, and any follow-ups. You own the synthesis.

## Notes

- Reasoning, architecture, and trade-off calls stay with you. Delegate execution,
  not judgment.
- Prefer fewer, well-scoped agents over many thin ones — each agent has startup
  and context cost.
- If a brief can't be made self-contained, the unit isn't ready to delegate yet —
  tighten the scope first.
