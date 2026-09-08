---
name: debug
description: Oracle = a reproduction stops failing. Route here for "bug", "broken", "fails", "crash", "regression", or a stack trace. Empirical loop — reproduce, fan out hypotheses, fix, skeptic, re-run.
---

# debug — empirical loop

The oracle is a reproduction: the fix is done when a deterministic repro stops failing, not
when an explanation sounds plausible. Shape: reproduce first, then fan out competing
root-cause hypotheses in parallel, then converge on a fix that survives a skeptic and the
repro.

**Route here when:** "bug", "broken", "fails", "crash", "regression", a stack trace — success
is judged by a failing reproduction turning green, not by a plausible-sounding story.
**Roles:** orchestrator (repro + judge + skeptic) · scout (hypotheses) · builder (the fix)
**Cap:** parallel hypotheses ≤ `workflows.debug.maxParallel`.

## Prelude (sequential — the shared unblock)

Reproduce the failure: get a deterministic repro — a command, test, or input that fails
reliably. Optionally use **1 scout** to map the failure surface — where it manifests and the
relevant call sites. The repro is the shared artifact that unblocks fan-out: every hypothesis
leg is evaluated against the *same* reproduction, and the repro doubles as the final oracle
in Converge.

If you can't reproduce it, that **is** the first task — don't fan out hypotheses against a
failure you can't trigger. Stay in the prelude until the repro is solid.

## Fan-out (parallel — scout, one per hypothesis)

One scout per candidate root-cause hypothesis, capped at `workflows.debug.maxParallel`.
Diversity of hypotheses is the point — pick genuinely different candidate causes, not
variations on one guess. Each scout is **read-only**: investigate whether its hypothesis is
the cause, don't touch code.

Give each the 4-part contract, framed as "investigate whether X is the cause; report
evidence, don't change code." Output format: evidence for/against the hypothesis, with
`file:line` — not a fix. Launch all legs in one message.

**Cascade:** if a scout leg comes back thin — no evidence either way — re-run that one leg at
the builder tier per `escalation.scoutToBuilder` before discarding the hypothesis.

## Converge (sequential — judge → fix → skeptic → re-run)

1. **Judge.** Weigh the evidence across legs and converge on the single most-supported root
   cause.
2. **Fix.** `builder` writes the minimal fix targeted at that root cause.
3. **Skeptic.** Spawn an independent orchestrator-tier instance that has **not** seen the fix
   author's reasoning, and have it try to refute the fix: is this the true root cause, or does
   the fix just mask the symptom? Default to skeptical.
4. **Re-run.** Run the repro from the prelude to confirm it now passes, and check for
   regressions.

If the skeptic refutes the fix or the repro still fails, loop back to Judge and pick the next
most-supported hypothesis. Don't re-fan-out unless the surviving hypotheses are exhausted.

## Notes

- The fix is minimal and targeted at the root cause, not the symptom — resist patching the
  symptom just to make the repro pass.
- Keep hypothesis legs read-only so they don't trample each other or the repro state.
- The repro from the prelude is the non-negotiable final gate — a fix that "looks right" but
  doesn't clear the repro isn't done.
