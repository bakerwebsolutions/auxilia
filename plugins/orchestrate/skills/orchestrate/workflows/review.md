---
name: review
description: Oracle = judgment of existing code. Route here for "review", "critique", "find bugs in", "is this correct", a diff/PR — parallel lenses, then an adversarial judge.
---

# review — parallel-adversarial read-only

Oracle: judgment of existing code, not new code. Shape: one independent reviewer per lens,
each judging the same diff against the same intent, then an adversarial judge who keeps only
what survives scrutiny.

**Route here when:** the ask is "review", "critique", "find bugs in", "is this correct", or
hands you a diff/PR — success is judged by whether the findings are real, not by information
returned or a spec satisfied.
**Roles:** orchestrator (context pack + judge) · reviewer (the lenses)
**Cap:** parallel reviewers ≤ `workflows.review.maxParallel`.

## Prelude (sequential — the shared unblock)

Orchestrator assembles the **context pack**: the exact diff/PR/files under review, plus the
contract they're supposed to meet — what the change is meant to do, the invariants it must
preserve. This is the artifact that unblocks fan-out: every reviewer judges the *same* code
against the *same* intent, so their findings come back comparable and dedupable instead of
each reviewer inventing its own frame.

## Fan-out (parallel — reviewer, one per lens)

One reviewer per lens, capped at `workflows.review.maxParallel`. Default lenses:
correctness, security, performance, API/style. Each reviewer sees the context pack but
**not** the other reviewers' findings — independence is what prevents groupthink. Give each
the 4-part contract, framed as "review only through the `<lens>` lens." Read-only, zero write
access — reviewers report, they don't fix. Each returns findings as `file:line` + severity +
a one-line failure scenario (the concrete input/state that breaks).

## Converge (sequential — orchestrator judge)

Orchestrator dedupes overlapping findings across lenses, ranks by severity, and
**adversarially** drops false positives — a finding survives only if you can state the
concrete case it breaks. Report the ranked, surviving findings. Do not apply fixes unless the
user asks; if they do, hand off to the `implement` workflow.

## Flavors

- **security-audit** — threat-model-driven; the security lens expands to become the whole
  panel (auth, injection, secrets, supply-chain, data exposure), each its own reviewer.

## Notes

- Reviewers are read-only and independent — that's the whole value; don't let them see each
  other's output before Converge.
- Scale lens count to the diff. A tiny diff doesn't need 4 reviewers — collapse to 1–2.
- This complements the repo's own `/code-review` skill; use this workflow when you want the
  parallel multi-lens + judge shape.
