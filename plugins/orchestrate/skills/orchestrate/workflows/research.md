---
name: research
description: Serves the oracle "synthesized information" — route here for how-does/find-out/compare/investigate questions and plain "ask/explain" asks. Parallel read-only fan-out.
---

# research — parallel read-only

Oracle: synthesized information. Shape: parallel read-only fan-out — split the topic into
non-overlapping workstreams, fan them out read-only, then synthesize one answer.

**Route here when:** "how does", "find out", "compare", "investigate", or a bare question —
success is judged by whether the information returned is correct and complete, not by an
artifact produced or a spec satisfied.
**Roles:** orchestrator (prelude + synthesis) · scout (the legs)
**Cap:** parallel legs ≤ `workflows.research.maxParallel`.

## Prelude (sequential — the shared unblock)

Reason on the topic yourself; optionally send **1 scout** to gather anchors (entry points,
key files, product docs) if you don't already know where to look. Then decide two things —
this is the artifact that unblocks the fan-out:

1. **3–4 non-overlapping workstreams.** Split the topic so no two legs would read the same
   ground or need each other's output. If you can't cut it non-overlapping, the topic isn't
   ready to fan out — narrow it or keep it sequential.
2. **One shared reporting frame** — the same set of headings every leg fills in (e.g.
   Answer / Evidence / Gaps, or whatever headings fit this topic). Without a shared frame the
   legs come back shaped differently and can't be merged; this is the actual deliverable of
   the prelude, not the workstream split.

## Fan-out (parallel — scout)

One scout per workstream, capped at `workflows.research.maxParallel`. Pick the tool for the
territory:

- **Codebase research** → the `explorer` agent (Read/Grep/Glob/Bash, read-only, Haiku).
- **External/web research** → the `researcher` agent (web-capable, Haiku).

Every leg gets the 4-part contract (Objective / Output format / Tools-sources / Boundaries).
Output format is always the shared reporting frame from the prelude, plus concrete sources —
`file:line` for codebase legs, URLs/citations for web legs. Launch all legs in one message.

**Cascade:** if a scout leg comes back thin — vague answer, no sources, gaps it can't fill —
re-run that one leg at the builder tier per `escalation.scoutToBuilder` before accepting it.

## Converge (sequential — orchestrator)

Synthesize the filled frames into **one** answer. Reconcile conflicts between legs yourself —
don't just concatenate them. Cite sources (files/lines, URLs) inline. You own the synthesis;
a scout's filled-in frame is input, never the conclusion — do not let a leg's wording stand
in as the final answer.

## Notes

- For a small, single-question codebase lookup, degenerate to **one** scout inline — this
  workflow absorbs plain "ask/explain" questions too. Don't fan out 3–4 legs to answer
  something one `explorer` call settles.
- For heavyweight external research that needs saved artifacts (a written report, not just an
  answer in-thread), this composes with the separate `research-spike` plugin instead of
  reinventing that here.
