# orchestrate

A **task router** for Claude Code and Codex. Instead of one session doing everything, `/orchestrate`
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
| **orchestrator** | classify · reason on the prelude · judge/verify adversarially · synthesize | harness profile | you + peer instances for judging |
| **builder** | implement code · write prose · run tests | harness profile | writes |
| **scout** | search · locate · map · external research | harness profile | read-only |

**The runtime chooses the tier names.** A role begins with the profile for the running
harness, then an explicit config or natural-language override wins for that run. The router
only passes a model value when it is advertised by that runtime; otherwise it inherits the
harness default. This prevents stale Claude aliases being sent to Codex and vice versa.

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
| **Delegation doctrine** (`SessionStart` hook) | Claude Code injection of the routing/roles doctrine (`doctrine: off` to disable). |
| **Claude agents** (`agents/`) | Claude-frontmatter versions of the scout and builder roles. |
| **Codex agents** (`codex/agents/`) | Native TOML versions of explorer, researcher, implementer, verifier, and reviewer. |

The agents double as **agent-team teammate types** since they carry their own `tools` and `model`.

## Install

Claude Code:

```
/plugin marketplace add bakerwebsolutions/auxilia
/plugin install orchestrate@auxilia
```

Codex: add this repository's `.codex-plugin/marketplace.json` to the Codex
plugin marketplace, then install `orchestrate`. The package contains the same
canonical skills and the native Codex agent definitions under `codex/agents/`.

Restart Claude Code after installation so its `SessionStart` hook and agents load. Codex
loads the plugin's skills from the package and its native agent definitions from
`codex/agents/`; see [`codex/README.md`](codex/README.md) for manual installation when a
marketplace is unavailable.

## Configuration

Behavior is driven by `orchestrate.config.json`, **layered and deep-merged** (first present
wins per key), so your user config sets global defaults and a repo overrides specifics:

1. Harness project config (for example `.claude/orchestrate.config.json` or a Codex project config)
2. Harness user config
3. the shipped default in the plugin root

```jsonc
{
  "autonomy": "propose",
  "harness": "auto",
  "roles": { "orchestrator": "auto", "builder": "auto", "scout": "auto" },
  "harnessProfiles": {
    "claude": { "roles": { "orchestrator": "opus", "builder": "sonnet", "scout": "haiku" } },
    "codex": { "roles": { "orchestrator": "gpt-5.6-sol", "builder": "gpt-5.6-terra", "scout": "gpt-5.6-luna" } }
  },
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
| `harness` | `auto` · `claude` · `codex` | Chooses a profile. `auto` detects from the available delegation API. |
| `roles.orchestrator` / `builder` / `scout` | `auto` or model alias/ID | Explicit role override. It wins over the profile only when the running harness advertises it. |
| `harnessProfiles` | per-harness role mappings | Fallback policy for Claude and Codex. Update it when your runtime offers a different model set. |
| `workflows.<name>.enabled` | bool | Whether the router may select this workflow. |
| `workflows.<name>.maxParallel` | int | Cap on parallel fan-out legs for this workflow (guards over-fan-out — multi-agent fan-out costs ~15× a single pass). |
| `escalation.scoutToBuilder` | bool | Re-run a thin/low-confidence scout leg at the builder tier before giving up (cascade). |
| `threshold.maxParallelAuto` / `maxFilesAuto` | int | Limits used when `autonomy=threshold`. |
| `doctrine` | `off` · `standard` · `strict` | How forcefully the `SessionStart` hook injects the doctrine (`off` disables it). |
| `alwaysPassModelExplicitly` | bool | Tell the orchestrator to pass a validated model override whenever its harness supports explicit model selection. |

Manage all of this conversationally with `/orchestrate-workflows` ("set the Codex builder
role", "enable optimize", "show my config").

## Harness adapters

Claude Code keeps the plugin hook and Markdown agents in `agents/`. Codex uses the native
TOML role files in [`codex/agents`](codex/agents), which can be copied to `.codex/agents/`
or `~/.codex/agents/`. The router detects the harness from its agent-spawning capability,
not an environment variable that another harness could happen to set.

The Codex default is intentionally cost-shaped: Sol orchestrates, Terra builds and verifies,
and Luna handles bounded scouting and web research. “Use Astra to orchestrate” is a
top-tier-only override, analogous to Claude's Fable override; it leaves Terra and Luna in
place.

## Why pass `model` explicitly?

On Claude, the subagent frontmatter `model:` field can be ignored, so the per-invocation
model parameter is the reliable lever. On Codex, an explicit spawn model takes precedence
over the configured default. In either harness, pass it only after checking its availability;
otherwise inherit the default rather than failing the spawn with an invalid name.

## How it fits together

```
You (orchestrator · active harness model): classify · prelude · judge · synthesize
   │
   ├── Step 1  classify on the oracle ─► one of six workflows
   │
   ├── Prelude   ─► the shared artifact (contract / repro / rubric / baseline / context pack)
   │
   ├──► scout      (profile) explorer · researcher   search / map / research
   ├──► builder    (profile) implementer             scoped change against the shared contract
   ├──► reviewer   (profile) reviewer                single-lens adversarial review
   │
   └── Converge  ─► verifier (profile) checks · orchestrator judges & synthesizes
```
