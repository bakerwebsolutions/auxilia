---
name: copywriter
description: Write or rewrite customer-facing copy (landing pages, service pages, ad landing pages, location pages, about pages) so it reads like the business wrote it, not a model. Gathers a fact sheet and voice sample first, drafts with [PLACEHOLDERS] instead of filler, fits search/ad basics, then runs the copy-reviewer agent for AI tells and unsupported claims. Use when asked to write, rewrite, or de-AI website or ad copy.
---

# copywriter

Generated copy sounds generated when the model has no facts and no voice to work from,
so it fills gaps with filler. This skill fixes the inputs first, then drafts, then gets
an independent read.

Search fit is one checklist step, not the goal. Keyword-first writing is a main source
of the repetition that makes copy read as AI.

## Inputs

- What to write: the page(s), or existing copy to rewrite (file paths or a diff).
- Optional: a voice sample (call transcript, the owner's emails or texts, their own
  reviews replies), a fact sheet, the ad or campaign the page serves.

## Procedure

### 1. Scope

Establish, from the request and the repo, in one pass:
- **Reader:** who lands here and from where (Google ad, organic search, referral link).
- **Action:** the one thing the page should get them to do (call, form, book).
- **Promise:** what the ad or search query promised, so the H1 can match it.

### 2. Fact sheet

Read the project's identity doc (its `AGENTS.md`/`CLAUDE.md` names it) and the existing
site copy. Build a fact sheet with only what those sources state:

- who: business name, owner, where they're based, crew size
- tenure: years in business or start year
- what: services offered, and **services excluded** (unlicensed, not offered, not yet)
- proof: equipment, licenses, real jobs (town + scope + problem solved), reviews
- terms: estimates, pricing stance, guarantees, service area

Then ask the user **once**, in a single message, for the missing facts that the copy
needs most (usually tenure, one or two real jobs, and equipment). Do not ask again.
Anything still missing becomes a placeholder in the draft (`[YEARS]`, `[JOB: town +
scope]`, `[EQUIPMENT]`). Never invent a number, testimonial, license, award, or
guarantee to fill a gap.

### 3. Voice

If there's a voice sample, lift its phrasing, vocabulary and sentence length. Real
phrases from the owner beat anything you write. If there's none, write in a plain
spoken register: what the owner would say to a customer on the phone. Note in the
handoff that a voice sample would improve it.

### 4. Draft

Read [`references/ai-tells.md`](references/ai-tells.md) before drafting and write
against it. In short:
- A fact or placeholder in place of every adjective that would otherwise carry the
  claim.
- Vary sentence length and shape; lists can be lumpy.
- Each claim once per page; each CTA phrase at most twice.
- At most one memorable line per page, and it must carry a fact.

Match the surrounding codebase: edit the existing data/props/components rather than
restructuring markup to suit the copy.

### 5. Search and ad fit

Check once, fix in place:
- Title ≤ 60 chars with the service and the place; meta description ≤ 155 chars with
  the action.
- H1 matches what the ad or query promised.
- Place names appear where a person would mention them, not as a repeated list.
- Ad-only pages: keep any existing `noindex`/sitemap exclusions as they are.

### 6. Independent review

Spawn the `copy-reviewer` agent with a brief containing only:
- the draft copy (visible text, title and meta, not markup),
- the fact sheet from step 2,
- the full text of `references/ai-tells.md`.

Do not include your reasoning or the old copy; the reviewer should read it cold.
Apply its findings. Run a second review only if the first returned a blocker; stop
after two rounds and report whatever remains.

### 7. Hand off

Report, briefly:
- what changed (or where the draft lives),
- every placeholder left and the fact it needs,
- claims the user should confirm before publishing,
- whether a voice sample was used.

Suggest reading it aloud once: any line the owner wouldn't say on the phone gets cut.
