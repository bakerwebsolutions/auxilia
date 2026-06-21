# orchestrate

Keep **Opus as the orchestrator** and delegate downward — implementation to
**Sonnet**, exploration/search to **Haiku**, verification to **Sonnet**. Unlike
model-router tools that *demote your main session* to save cost, `orchestrate`
keeps the hard thinking on Opus and pushes only well-defined execution to cheaper
tiers.

## What it ships

| Component | What it does |
|-----------|--------------|
| **Delegation doctrine** (`SessionStart` hook) | Injects standing guidance every session: you orchestrate, you delegate, you analyze parallel-vs-sequential before fanning out. |
| **`/orchestrate`** (skill) | On demand: decompose a task → parallel/sequential plan → minimal-context brief per unit → fan out to the right tier → verify → synthesize. |
| **`explorer`** (agent · Haiku) | Read-only search & discovery. |
| **`implementer`** (agent · Sonnet) | Targeted, well-scoped implementation. |
| **`verifier`** (agent · Sonnet) | Independently checks done-criteria (tests/lint/diff). |

The agents double as **agent-team teammate types** since they carry their own
`tools` and `model`.

## Install

```
/plugin marketplace add bakerwebsolutions/auxilia
/plugin install orchestrate@auxilia
```

Restart the session after install so the `SessionStart` hook and agents load.

## Configuration

Behavior is driven by `orchestrate.config.json`. The shipped default lives in the
plugin root; override it per-project by placing your own at either:

- `.claude/orchestrate.config.json` (preferred), or
- `orchestrate.config.json` in the working directory.

```json
{
  "autonomy": "propose",
  "threshold": { "maxParallelAuto": 3, "maxFilesAuto": 5 },
  "tiers": { "explore": "haiku", "implement": "sonnet", "verify": "sonnet" },
  "doctrine": "standard",
  "alwaysPassModelExplicitly": true
}
```

| Key | Values | Meaning |
|-----|--------|---------|
| `autonomy` | `propose` · `auto` · `threshold` | After building a plan: ask first (default), fan out immediately, or auto only when under the thresholds. |
| `threshold.maxParallelAuto` | int | Max parallel units to auto-launch under `threshold`. |
| `threshold.maxFilesAuto` | int | Max files touched to auto-launch under `threshold`. |
| `tiers.explore` / `implement` / `verify` | model alias or ID | Which model each kind of work runs on. |
| `doctrine` | `off` · `standard` · `strict` | How forcefully the hook injects the doctrine (`off` disables it). |
| `alwaysPassModelExplicitly` | bool | Tell Opus to pass `model` on every Agent call — works around the frontmatter model bug ([anthropics/claude-code#44385](https://github.com/anthropics/claude-code/issues/44385)). |

## Why pass `model` explicitly?

The subagent frontmatter `model:` field can be ignored, so subagents may silently
inherit Opus. The reliable lever is the **per-invocation `model` parameter**, which
takes precedence over frontmatter. The doctrine instructs Opus to always set it.
We deliberately **do not** use `CLAUDE_CODE_SUBAGENT_MODEL` — it would force every
subagent to a single tier and defeat mixed delegation.

## How it fits together

```
You (Opus): reason · design · plan · synthesize
   │
   ├── decompose ─► parallel / sequential plan  (/orchestrate)
   │
   ├──► explorer   (Haiku)   search / locate / map
   ├──► implementer(Sonnet)  scoped change w/ a tight brief
   └──► verifier   (Sonnet)  confirm done-criteria
```
