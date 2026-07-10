---
name: optimize
description: Oracle = a measurement improves. Route here for "slow", "faster", "optimize", "latency", "memory", "reduce cost". Opt-in — disabled by default; the router only picks it when enabled in config or forced by the user. Baseline + profile, then parallel measured candidates, then keep the winner.
---

# optimize — empirical loop

The oracle is a measurement, not an impression: a change is "faster" only if a benchmark
says so. Shape: establish a baseline and find the hotspot first, then fan out competing
candidate optimizations in parallel, each measured against that same baseline, then keep
the winner.

**Route here when:** "slow", "faster", "optimize", "latency", "memory", "reduce cost" —
success is judged by a number moving in the right direction, not by a plausible-sounding
change. **Opt-in:** `workflows.optimize.enabled` is `false` in the shipped config — the
router only routes here if the config enables it or the user forces it ("orchestrate this
as an optimize").
**Roles:** orchestrator (baseline + decision) · builder (candidate optimizations)
**Cap:** parallel candidates ≤ `workflows.optimize.maxParallel`.

## Prelude (sequential — the shared unblock)

Establish the **baseline**: a repeatable benchmark (a command, plus the metric it reports —
latency, memory, tokens, throughput) run against the current code, and a **profile**
identifying where the cost actually is. The baseline is the shared artifact that unblocks
fan-out — every candidate is measured against the *same* baseline on the *same* benchmark,
so improvements are comparable and real rather than anecdotal.

No benchmark ⇒ no baseline ⇒ no fan-out. If a benchmark harness doesn't exist, that **is**
the first task — stay in the prelude until you have a repeatable, deterministic measurement.

## Fan-out (parallel — builder, one per candidate)

One builder per candidate optimization, capped at `workflows.optimize.maxParallel`.
Diversity is the point — pick genuinely different optimization approaches (e.g. algorithmic
change, caching, reduced allocations, batching), not variations on one guess. Isolate each
builder in its own git worktree (`isolation: worktree`) so parallel edits don't collide.

Give each the 4-part contract, framed as "try this optimization approach; re-run the
benchmark from the prelude and report the measured delta." Output format: the measured
delta vs. baseline on the shared benchmark, plus whether the existing tests still pass. The
deliverable is a measured change, not just a diff — a candidate that isn't re-benchmarked
isn't done.

## Converge (sequential — orchestrator)

Compare the measured deltas across legs. **Keep the winner**: correctness-preserving
(tests pass) and the best measured improvement — discard the rest. Re-run the benchmark on
the winner one more time to confirm the improvement is real and stable, not noise. Report
the before/after numbers.

## Notes

- This workflow needs a benchmark harness. If none exists, say so and either help build one
  first or fall back to the `debug`-style loop / ask the user — don't fan out candidates
  with nothing to measure them against.
- Never claim an optimization without a measurement — "should be faster" is not a result.
- `optimize` is `enabled: false` by default; only route here when config enables it or the
  user explicitly forces it.
