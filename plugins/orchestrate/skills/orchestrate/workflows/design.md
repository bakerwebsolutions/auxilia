---
name: design
description: Oracle = options/an artifact to choose among. Route here for "design", "architect", "approach", "how should we", "spike" — when the task needs a decision, not code yet.
---

# design — parallel read-only (proposers)

The oracle is an artifact to choose among: several candidate approaches, judged against
the same rubric, with one picked and refined. Shape: parallel read-only proposers — no
code gets written until a winner is chosen.

**Route here when:** the ask is "design", "architect", "approach", "how should we", "spike" —
a decision is needed before there's anything to build.
**Roles:** orchestrator (frame + judge) · scout or builder (the proposers)
**Cap:** parallel proposers ≤ `workflows.design.maxParallel`.

## Prelude (sequential — the shared unblock)

Orchestrator frames the problem: gather the real constraints and requirements, then write
an explicit **evaluation rubric** — the criteria a good approach must satisfy (e.g.
simplicity, blast radius, performance, migration cost). The rubric is the shared artifact
that unblocks fan-out: every proposer is scored on the same axes, so proposals come back
comparable instead of apples-to-oranges. May use one scout to gather constraints if they
aren't already known.

## Fan-out (parallel — proposers)

2–4 proposers (scout or builder tier, capped at `workflows.design.maxParallel`), each
independently exploring a **distinct** approach against the same rubric. Read-only — no
code is written at this stage. Give each the 4-part contract. Each returns:

- the approach
- how it works
- tradeoffs
- a self-score on each rubric axis

Diversity is the point — steer proposers toward genuinely different angles (e.g.
minimal-change vs. clean-slate vs. library-adopt), not variations on one idea.

## Converge (sequential — orchestrator)

Orchestrator judges the proposals against the rubric, picks a winner, and grafts the best
ideas from the runners-up into it. Report the recommended approach and why it beat the
others. If approved and the user wants it built, hand off to the `implement` workflow.

## Flavors

- **spike** — design with a throwaway prototype instead of pure analysis, and the
  downstream verify disabled. The goal is a decision, not production code.

## Notes

- Keep proposers read-only — the value is comparison, not committing to code early.
- For a genuinely simple choice, don't fan out 4 proposers; reason it out inline or use 2.
