# orchestrate

A **task router** for Claude Code. Instead of one session doing everything, `/orchestrate`
detects *what kind of task* this is, then runs a **pre-curated, model-tiered workflow** for
it. Unlike model-router tools that *demote your main session* to save cost, orchestrate keeps
the hard thinking on the top tier and pushes only well-defined execution to cheaper ones.

The routing thesis (Anthropic, *Building Effective Agents*): classify the input, dispatch to
a specialized followup. Cheap, deterministic, debuggable — a **router**, not an LLM that
freelances delegation each turn.

## The shape every workflow shares

Each workflow has the same spine. The **prelude is the point** — the one sequential, shared
piece that produces the artifact the parallel legs depend on. Without it, the "parallel" legs
collide on undecided shared context and aren't actually independent.

```
Prelude   (sequential · orchestrator) → the SHARED artifact that unblocks fan-out
   Fan-out  (parallel · cheaper tiers) → the independent work it just unblocked
      Converge (sequential · orchestrator) → synthesize / verify / judge → report
```

Always find the prelude first: *what one thing, once decided, makes the rest independent?*

## Roles, not fixed model names

Work routes to **three roles**; config maps roles → models.

| Role | Does | Default | Read/write |
|------|------|---------|-----------|
| **orchestrator** | classify · reason on the prelude · judge/verify adversarially · synthesize | `opus` | you + peer instances for judging |
| **builder** | implement code · write prose · run tests | `sonnet` | writes |
| **scout** | search · locate · map · external research | `haiku` | read-only |

**Swapping the orchestrator swaps the whole top tier.** Say "use fable to orchestrate" in
natural language and Fable **fully replaces Opus** for that run — it coordinates *and* does
the deep reasoning and adversarial judging. Builder stays Sonnet, scout stays Haiku. A
natural-language override always beats the config file for that one run.

## The six workflows

The router picks **one**, on the **oracle** (how success is judged), not the verb.

| Workflow | Oracle | Prelude (shared unblock) | Fan-out | Converge |
|----------|--------|--------------------------|---------|----------|
| **research** | synthesized info | workstream frame + anchors | scouts, 1/workstream | synthesize + cite |
| **design** | an option to choose | problem frame + eval rubric | 2–4 proposers, distinct approaches | judge on rubric, pick + graft |
| **implement** | a spec satisfied | **the shared contract/interfaces** | builders, 1/independent unit | verify (tests/typecheck) |
| **debug** | a repro stops failing | **reproduce + map the surface** | scouts, 1/root-cause hypothesis | judge → fix → skeptic → re-run |
| **review** | judgment of code | the diff + context pack | reviewers, 1/lens (correctness/security/perf/API) | judge dedupes + ranks |
| **optimize** ¹ | a measurement improves | baseline benchmark + profile | builders, 1/candidate (worktree-isolated) | keep the measured winner |

¹ `optimize` ships **disabled** — enable it in config when you have a benchmark harness.

**Flavors** ride on a base workflow (they toggle stages, they aren't their own route):
refactor · test · docs · small-migration → **implement**; security-audit → **review**.

## What it ships

| Component | What it does |
|-----------|--------------|
| **`/orchestrate`** (skill) | The router: load config → classify → announce → run the workflow recipe → converge. |
| **`/orchestrate-workflows`** (skill) | Companion: **run** a workflow directly (bypass classification), **manage** the layered config, or **explain** what the router would pick. |
| **Workflow recipes** (`skills/orchestrate/workflows/*.md`) | One curated recipe per workflow — prelude, fan-out, convergence, flavors. |
| **Delegation doctrine** (`SessionStart` hook) | Injects the routing/roles doctrine every session (`doctrine: off` to disable). |
| **`explorer`** (agent · Haiku) | Read-only code search & discovery — a scout. |
| **`researcher`** (agent · Haiku) | Read-only external/web research — a scout. |
| **`implementer`** (agent · Sonnet) | Targeted, well-scoped implementation — a builder. |
| **`verifier`** (agent · Sonnet) | Independently checks done-criteria (tests/lint/diff). |
| **`reviewer`** (agent · Sonnet) | Single-lens, read-only, adversarial code review. |

The agents double as **agent-team teammate types** since they carry their own `tools` and `model`.

## Install

```
/plugin marketplace add bakerwebsolutions/auxilia
/plugin install orchestrate@auxilia
```

Restart the session after install so the `SessionStart` hook and agents load.

## Configuration

Behavior is driven by `orchestrate.config.json`, **layered and deep-merged** (first present
wins per key), so your user config sets global defaults and a repo overrides specifics:

1. `.claude/orchestrate.config.json` (repo)
2. `~/.claude/orchestrate.config.json` (user)
3. the shipped default in the plugin root

```jsonc
{
  "autonomy": "propose",
  "roles": { "orchestrator": "opus", "builder": "sonnet", "scout": "haiku" },
  "workflows": {
    "research":  { "enabled": true,  "maxParallel": 4 },
    "design":    { "enabled": true,  "maxParallel": 3 },
    "implement": { "enabled": true,  "maxParallel": 3 },
    "debug":     { "enabled": true,  "maxParallel": 4 },
    "review":    { "enabled": true,  "maxParallel": 4 },
    "optimize":  { "enabled": false, "maxParallel": 3 }
  },
  "escalation": { "scoutToBuilder": true },
  "doctrine": "standard",
  "alwaysPassModelExplicitly": true
}
```

| Key | Values | Meaning |
|-----|--------|---------|
| `autonomy` | `propose` · `auto` · `threshold` | After classifying + planning: announce and wait (default), run immediately, or auto only under the thresholds. |
| `roles.orchestrator` / `builder` / `scout` | model alias or ID | Which model plays each role. Set `orchestrator` to `fable` to make Fable the top tier permanently. |
| `workflows.<name>.enabled` | bool | Whether the router may select this workflow. |
| `workflows.<name>.maxParallel` | int | Cap on parallel fan-out legs for this workflow (guards over-fan-out — multi-agent fan-out costs ~15× a single pass). |
| `escalation.scoutToBuilder` | bool | Re-run a thin/low-confidence scout leg at the builder tier before giving up (cascade). |
| `threshold.maxParallelAuto` / `maxFilesAuto` | int | Limits used when `autonomy=threshold`. |
| `doctrine` | `off` · `standard` · `strict` | How forcefully the `SessionStart` hook injects the doctrine (`off` disables it). |
| `alwaysPassModelExplicitly` | bool | Tell the orchestrator to pass `model` on every Agent call — works around the frontmatter model bug ([anthropics/claude-code#44385](https://github.com/anthropics/claude-code/issues/44385)). |

Manage all of this conversationally with `/orchestrate-workflows` ("set orchestrator to
fable", "enable optimize", "show my config").

## Why pass `model` explicitly?

The subagent frontmatter `model:` field can be ignored, so subagents may silently inherit
the orchestrator. The reliable lever is the **per-invocation `model` parameter**, which takes
precedence over frontmatter — the doctrine instructs the orchestrator to always set it. We
deliberately **do not** use `CLAUDE_CODE_SUBAGENT_MODEL` — it would force every subagent to a
single tier and defeat mixed delegation.

## How it fits together

```
You (orchestrator · Opus/Fable): classify · prelude · judge · synthesize
   │
   ├── Step 1  classify on the oracle ─► one of six workflows
   │
   ├── Prelude   ─► the shared artifact (contract / repro / rubric / baseline / context pack)
   │
   ├──► scout      (Haiku)   explorer · researcher   search / map / research
   ├──► builder    (Sonnet)  implementer             scoped change against the shared contract
   ├──► reviewer   (Sonnet)  reviewer                single-lens adversarial review
   │
   └── Converge  ─► verifier (Sonnet) checks · orchestrator judges & synthesizes
```
