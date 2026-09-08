---
name: implement
description: Oracle = a spec/contract satisfied. Route here for "add", "build", "implement", "make it do X" — and its flavors refactor/test/docs/small-migration. Sequential contract, then parallel build, then verify.
---

# implement — sequential-convergent (build + verify)

Oracle: a spec/contract satisfied. Shape: a shared contract nailed down first, then
parallel build against it, then verify.

**Route here when:** "add", "build", "implement", "make it do X", or a refactor/test/docs/
migrate ask — success is judged by whether the change satisfies a spec, not by information
returned or an option chosen.
**Roles:** orchestrator (contract + synthesis) · builder (the units) · builder (verify)
**Cap:** parallel builders ≤ `workflows.implement.maxParallel`.

## Prelude (sequential — the shared unblock)

Orchestrator understands the affected code — optionally send **1 scout** to map it if you
don't already know the terrain. Then write the **shared contract**: the interfaces,
function signatures, types, and data shapes the parallel units will build against. Identify
the seams — which units are truly independent vs. which form a dependency chain.

The contract *is* the artifact that unblocks fan-out: once the interface between pieces is
nailed down, the pieces can be built in parallel without colliding. If you can't write the
contract yet, the work isn't ready to fan out — keep reasoning, don't fan out prematurely.

## Fan-out (parallel — builder)

One builder per independent unit, capped at `workflows.implement.maxParallel`. Each brief
is the 4-part contract (Objective / Output format / Tools-sources / Boundaries) **plus**:

- the shared interface it must satisfy (from the prelude)
- the in-scope files it may touch

Launch all independent units **in one message**. For units that form a dependency chain,
**gate** them — launch the next only after its prerequisite returns, folding that result
into the next unit's brief. Each builder implements to the contract, matches surrounding
style, and runs the local check for what it changed (its own tests/lint, not the full
suite).

## Converge (sequential — verify)

Run the full tests / typecheck / lint — mechanical verification is **builder** tier, not
orchestrator. Orchestrator then reconciles: integrates the units, resolves any contract
drift between them, and reports what changed per file.

## Flavors

- **refactor** — behavior-preserving; the invariant is "no behavior change", so verify is
  **hard-enabled** against the existing tests and the diff must be behavior-neutral.
- **test** — the deliverable is tests; the oracle is red→green / coverage, not a feature
  spec.
- **docs** — the deliverable is prose; verify is a read-back for accuracy, not a test run.
- **small-migration** — many homogeneous mechanical edits: fan out one builder per
  file/module (parallel-per-unit), a verifier does the integration pass. Large or novel
  migrations should go through `design` first, not straight here.

## Notes

- Collapse trivial units — don't spawn an agent for a one-line edit you can do inline.
  Prefer fewer well-scoped builders.
- Pass `model` explicitly on every Agent call per the router
  (`alwaysPassModelExplicitly`).
- If a brief can't carry the shared interface and in-scope files self-contained, the
  contract isn't done — tighten the prelude before fanning out.
