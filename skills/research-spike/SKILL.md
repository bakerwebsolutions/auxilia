---
name: research-spike
description: Run a reusable external research spike. Tighten a broad topic into a few high-signal workstreams, fan out parallel web-research agents, synthesize the findings, and save durable artifacts to docs/research-spike/<date>-<slug>/. Use for competitor scans, UX pattern research, pricing/monetization analysis, onboarding/retention studies, or market-gap exploration.
---

# research-spike

Run a **stored, repeatable research spike** that does four things:

1. anchors the research to the product,
2. tightens the scope into a few non-overlapping workstreams,
3. fans out parallel web research,
4. writes durable artifacts to `docs/research-spike/`.

## Inputs

- The user's research goal or question.
- Optional competitor/product lists, themes, or angles to investigate.
- Optional preferred slug if the user wants a specific spike folder name.

If the scope is ambiguous in a way that materially changes the spike design,
ask one clarifying question before proceeding.

## Output contract

Every run creates or updates:

- `docs/research-spike/README.md` — index of all saved spikes
- `docs/research-spike/<date>-<slug>/README.md` — main synthesis
- `docs/research-spike/<date>-<slug>/brief.md` — research brief, scope, and workstream plan
- `docs/research-spike/<date>-<slug>/findings/*.md` — one file per workstream
- `docs/research-spike/<date>-<slug>/sources.md` — source inventory grouped by workstream

Prefer this folder shape exactly unless the user asks for something different.

## Procedure

### Phase 1 — Anchor to the product

Before researching the market, understand what the research must answer for.

1. Read the project's product docs if they exist (e.g. `docs/product/README.md`, `README.md`, `PROMPT.md`).
2. If a `loadctx` skill is available and the scope is broad, use it.
3. Extract **product anchors** — the specific constraints, differentiators, or open questions this research should illuminate.

Do not start external research without first identifying these anchors.

### Phase 2 — Tighten the spike

Turn the user's broad topic into **3–4 parallel workstreams** with minimal overlap.

Guidelines:

- Default to **4 workstreams max** to fit typical parallel agent limits.
- Collapse overlapping areas rather than launching near-duplicate agents.
- Give every stream the same reporting frame so synthesis is easy.

Default reporting frame for each stream:

- user / job to be done
- products or sources reviewed
- core loop / interaction model
- recurrence / scheduling model (if relevant)
- reminder / notification model (if relevant)
- onboarding friction
- complaints / churn signals
- pricing / monetization (if relevant)
- implications for this product
- open questions
- sources (URLs)

Before the fan-out, briefly state:

- the tightened workstreams,
- the product anchors they serve,
- the output folder you will write to.

### Phase 3 — Create the artifact scaffold first

Before launching research, create:

- `docs/research-spike/README.md` if missing
- `docs/research-spike/<date>-<slug>/`
- `brief.md`
- `findings/`
- `sources.md`

Folder naming:

- Default to `YYYY-MM-DD-<slug>`.
- Use a short, human-readable slug derived from the research topic.

`brief.md` should capture:

- the user's research question,
- the product anchors,
- original topic list (if the user provided one),
- tightened workstreams,
- the shared reporting frame.

### Phase 4 — Fan out the research

Launch **one research subagent per workstream** in a single message so they
run in parallel.

Model guidance:

- Prefer a **fast web-research model** for subagents, e.g. `claude-haiku-4-5-20251001`.
- Use the orchestrating model for synthesis and final prose.

Prompt each research subagent with:

- the product anchors,
- the exact workstream question,
- representative products or categories to cover,
- required output headings (the reporting frame),
- a request for concrete sources and URLs,
- a bias toward official docs, pricing pages, app store listings, reviews, and
  credible commentary.

### Phase 5 — Save findings as they land

When each workstream completes:

1. read the result,
2. distill it into a durable markdown file under `findings/`,
3. append or update the relevant source section in `sources.md`.

Do not store raw tool dumps. Save curated findings instead.

### Phase 6 — Synthesize the spike

Write `docs/research-spike/<date>-<slug>/README.md` as the main briefing.

Structure:

1. **Summary** — 2–4 sentences
2. **Strongest conclusions** — concise table or bullets
3. **What to copy**
4. **What to avoid**
5. **Recommended product stance**
6. **Open questions to test**
7. **Files in this spike**

The synthesis should answer: **what should the product believe or do differently
because of this spike?**

### Phase 7 — Update the spike index

Update `docs/research-spike/README.md` so the new spike is discoverable.

For each saved spike, include:

- title,
- date,
- short summary,
- path to the spike folder.

## Notes

- Prefer breadth-to-structure, then depth: shape the streams first, then fan out.
- If public artifacts are sparse for a category, say so plainly and lean on app
  store reviews, pricing pages, support docs, and adjacent products.
- Keep saved findings concise and readable; they should be useful months later
  without reopening the full conversation.
