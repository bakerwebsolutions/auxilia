---
name: orchestrate
description: Route a task to a pre-curated, model-tiered workflow and run it. Use when the user says "orchestrate", "decompose", "delegate this", "parallelize", "fan out", or hands you a multi-part task. Detects the task type (research · design · implement · debug · review · optimize), then runs that workflow's recipe — a shared sequential prelude, a parallel fan-out to cheaper tiers, and a convergence step. You (the orchestrator) stay on reasoning and synthesis; Sonnet builds, Haiku scouts.
---

# orchestrate — the router

You are a **router**, not a freelancing supervisor. Detect what kind of task this is,
select the matching **pre-curated workflow**, and run its recipe. The recipe — not you
in the moment — decides the fan-out shape and which tier does what. You still own the
thinking: classification, the prelude reasoning, and the final synthesis.

The pattern (Anthropic, *Building Effective Agents*): classify the input, dispatch to a
specialized followup. Cheap, deterministic, debuggable. Keep it that way.

## Step 0 — Load config

Deep-merge these (first present wins **per key**), so the user sets global defaults and a
repo overrides specifics:

1. `$CLAUDE_PROJECT_DIR/.claude/orchestrate.config.json` (repo)
2. `~/.claude/orchestrate.config.json` (user)
3. `${CLAUDE_PLUGIN_ROOT}/orchestrate.config.json` (shipped default)

Keys you act on: `roles.{orchestrator,builder,scout}`, `autonomy`, `threshold.*`,
`workflows.<name>.{enabled,maxParallel}`, `escalation.scoutToBuilder`,
`alwaysPassModelExplicitly`. Defaults if no file: roles `opus/sonnet/haiku`,
`autonomy=propose`, all workflows except `optimize` enabled, pass model explicitly.

## The roles

Everything routes to **four roles**, not four fixed model names. The config maps roles → models.

| Role | Does | Default | Read/write |
|------|------|---------|-----------|
| **orchestrator** | classify · run the recipe · reason on the prelude · synthesize · adversarially judge/verify | `opus` | you (this session) + peer instances you spawn for judging |
| **builder** | implement code · write prose · run tests to verify | `sonnet` | writes |
| **scout** | search · locate · map · external research | `haiku` | read-only |

**Swapping the orchestrator = swapping the whole top tier.** If the user says (in natural
language) "use fable to orchestrate", "orchestrate this with fable", or similar, set
`roles.orchestrator = fable` **for this run only**. Fable then fully replaces Opus: it
coordinates *and* does the deep reasoning and the adversarial judging. Opus is simply not
used. Builder stays Sonnet, scout stays Haiku. A natural-language override always beats the
config file for that one run.

## The shared 3-stage skeleton

Every workflow has the same spine. The **prelude is the point** — it is the common,
sequential piece that produces the shared artifact the parallel legs depend on. Without it,
the "parallel" legs collide on undecided shared context (an interface, a repro, a frame) and
aren't actually independent.

```
Prelude   (sequential · orchestrator reasons, may use 1 scout)
              → produces the SHARED artifact that unblocks fan-out
   Fan-out  (parallel · N cheap agents, capped at workflows.<name>.maxParallel)
              → the independent work the prelude just unblocked
      Converge (sequential · orchestrator)
              → synthesize / verify / adversarially check → report
```

Always find the prelude first. Ask: *what one thing, once decided, makes the rest
independent?* Do that, then fan out.

## Step 1 — Classify the task

Pick **one** workflow. Route on the **oracle** (how success is judged), not the verb —
keywords overlap, oracles don't.

| Workflow | Oracle — success is judged by… | Signals | Shape |
|----------|-------------------------------|---------|-------|
| **research** | synthesized information | "how does", "find out", "compare", "investigate", a question | parallel read-only |
| **design** | options/an artifact to choose among | "design", "architect", "approach", "how should we", "spike" | parallel read-only |
| **implement** | a spec / contract satisfied | "add", "build", "implement", "make it do X", refactor/test/docs/migrate | sequential + verify |
| **debug** | a reproduction stops failing | "bug", "broken", "fails", "crash", "regression", a stack trace | empirical loop |
| **review** | judgment of existing code | "review", "critique", "find bugs in", "is this correct", a diff/PR | parallel-adversarial read-only |
| **optimize** | a measurement improves | "slow", "faster", "optimize", "latency", "memory", "reduce cost" | empirical loop |

**Flavors ride on a base workflow** (they toggle stages, they are not their own route):
refactor · test · docs · small-migration → **implement**; security-audit → **review**.

If two workflows genuinely tie, or the request is too vague to classify, **ask one
question** — do not guess. If the picked workflow is `enabled: false` in config, say so and
route to the closest enabled one (or ask). The user can force a workflow in natural language
("orchestrate this as a review") — honor it over your own classification.

## Step 2 — Run the workflow recipe

Read `${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/workflows/<workflow>.md` and follow it. Each
recipe specifies its prelude, its fan-out (which role, how many, what each does), and its
convergence. It also lists the flavors that ride on it and which stages they toggle.

## Step 3 — Announce, then act per `autonomy`

Announce the plan compactly before spawning anything: the **detected workflow** (and why),
the **prelude**, the **fan-out** (N legs, the tier each runs on), and the **convergence**.

- **`propose`** (default): stop after announcing and wait for approval.
- **`auto`**: run immediately.
- **`threshold`**: run immediately only if `parallel legs <= threshold.maxParallelAuto`
  **and** `files touched <= threshold.maxFilesAuto`; otherwise fall back to `propose`.

## Step 4 — Fan out with tight briefs

Each fan-out leg gets a **self-contained 4-part contract** (Anthropic multi-agent research)
— never forward your whole conversation:

```
Objective:     what to make true / find out
Output format: exactly what to return (headings, shape)
Tools/sources: where to look; what it may touch
Boundaries:    what to leave alone; when it's done
```

- Launch all **parallel** legs **in one message** (multiple Agent calls) so they run concurrently.
- **Cap** parallel legs at `workflows.<name>.maxParallel`. Prefer fewer well-scoped agents.
- **Pass `model` explicitly** on every Agent call when `alwaysPassModelExplicitly` is true
  (e.g. `model: "haiku"`) — subagent frontmatter `model:` is unreliable
  (anthropics/claude-code#44385).
- **Cascade** (`escalation.scoutToBuilder`): if a scout leg returns thin/low-confidence
  output, re-run that one leg at the builder tier before giving up.

## Step 5 — Converge and synthesize

Run the recipe's convergence (synthesize, verify, or adversarially judge — the recipe says
which). Verification (running tests/typecheck) is mechanical → **builder** tier; adversarial
judging (is this finding real? is this the true root cause?) needs reasoning →
**orchestrator** tier, spawned as an independent instance so it doesn't just confirm itself.

Then report: what's done, what each agent changed/found, verification outcomes, follow-ups.
You own the synthesis — never hand judgment to a subagent.

## Notes

- Reasoning, architecture, and trade-off calls stay with the orchestrator. Delegate
  execution, not judgment.
- If a brief can't be made self-contained, the leg isn't ready to fan out — tighten the
  prelude first.
- To run a specific workflow directly (bypassing classification), inspect config, or check
  what the router *would* pick, use the **`/orchestrate-workflows`** companion skill.
