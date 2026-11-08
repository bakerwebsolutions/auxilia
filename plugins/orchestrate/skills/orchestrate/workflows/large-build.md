---
name: large-build
description: A scale mode of implement, not a seventh oracle. Route here for an explicit "large build" request, or when an implement work graph splits into several independent workstreams over the largeBuild threshold. A manager owns the plan, merge order and decision ledger; two or three workstream leads each run their own builders and verifiers in per-node worktrees.
---

# large-build — implement, managed in workstreams

Oracle: the same as **implement** — a spec/contract satisfied — judged per MR/PR rather
than once at the end. Shape: one shared contract, then two or three **workstreams** run in
parallel by their own **leads**, merged in an order the **manager** owns, with every design
call written to one **decision ledger**.

This recipe changes who runs the implement graph, not how a node is built. Nodes, tiers,
worktrees, the status gate and the escalation cascade are the router's (Steps 2, 5 and 6)
and `implement.md`'s, unchanged.

**Route here when:** the user asks for a "large build" (or "big build", "run this as a
managed build"), or the router's implement graph crosses the `largeBuild` threshold (router
Step 2b). Typical shape: many MRs, a feature spanning backend and UI, a long autonomous run.
**Don't route here when:** the graph is one workstream, or under the threshold. Plain
`implement` is cheaper and has fewer handoffs.
**Roles:** manager (plan + merge order + ledger + synthesis) · lead × 2–3 (one workstream
each) · builder / senior (nodes) · verifier (node checks, MR checks)
**Cap:** leads ≤ `largeBuild.maxLeads`; concurrent builders and verifiers across all leads
≤ `largeBuild.maxParallel`; per lead ≤ `workflows.implement.maxParallel`; senior nodes ≤
`workflows.implement.maxSenior` per workstream.

## The roles

| Role | Model | Owns | Never |
|------|-------|------|-------|
| **manager** | `roles.manager` — `auto` = the orchestrator role (this session) | the plan, the contract, the work graph, merge order, MR boundaries, the decision ledger, the status file, every checkpoint report | builds nodes inline |
| **lead** | `roles.lead` — `auto` = the senior role (the profile's top tier unless set) | one workstream: its nodes' briefs, worktrees, builders, verifiers and status gate | decides a spec, contract, product-behavior, cost or vendor question; merges into the main checkout; writes the ledger |
| **builder / senior** | as the router resolves them | one node, in its worktree | commits, or touches files outside its `owns` |
| **verifier** | builder tier | a node check (for a lead) or an MR check (for the manager) | fixes what it finds |

The manager is this session unless `roles.manager` names a different advertised model; then
spawn one manager agent at that model and hand it this recipe, the ledger path and the
status path. If the harness can't spawn it, manage from this session and say so.

**Leads need to spawn agents.** If the harness doesn't give a spawned agent a delegation
tool (nested spawning off, or a depth limit of one), run each lead as a **planning lead**:
it writes its workstream's node briefs and gates the results, and the manager spawns the
builders and verifiers it names. Everything else in this recipe stays the same. Say which
form the run uses in the plan.

## The decision ledger

One file at `largeBuild.ledger` (`<run>` is replaced by the run id). It is the **only** place
a design call is written down. Briefs, commit messages and reports point at an entry (`D4`);
they don't restate or re-decide it. Only the manager writes it.

A design call is anything a reasonable reviewer could have decided the other way: an
interface shape, a data model, a behavior the spec leaves open, a library, a naming scheme
other code will follow, a trade-off between workstreams. A mechanical choice the contract
already fixes is not one.

Each entry:

```
## D<n> — <one-line title>
- Decided by: agent decision, not reviewed by the user
- Raised by: manager | lead <workstream>
- Question: what had to be decided, and why it couldn't wait
- Decision: what was chosen
- Why: the reason, and the main alternative rejected
- Affects: contract sections, nodes, MRs
- Kind: durable | implementation
- Project log: <where it was copied, or "PR description">  (durable only)
- Review: unreviewed
```

**Who decided.** `Decided by` is `agent decision, not reviewed by the user` unless the user
made that call in this conversation; then it is `user, in conversation` with their words
quoted. An agent never puts the user's name on a decision it made, and never upgrades an
entry to `user` because the user didn't object. A replacement manager keeps every entry's
`Decided by` as written.

**Kind.** A **durable** decision changes behavior, a spec or contract, money, cost, a
vendor, or a data shape (schema, API payload, stored format). Everything else is
**implementation**: naming, file layout, internal structure, refactors. Implementation
decisions stay in the ledger and the commits. Durable ones also go somewhere that outlives
the run, because the ledger's default path is git-excluded and local.

**Where durable decisions go.** Write each one into the project's own decision log as soon as
it is made, in addition to the ledger:

1. `largeBuild.projectLog` if it is a path (`none` skips to step 3).
2. Otherwise (`auto`, the default) detect one: a log the project's `CLAUDE.md`/`AGENTS.md`
   names; else `docs/**/decision-log.md`, `DECISIONS.md`, `docs/**/decisions.md`, or an ADR
   directory (`docs/adr/`, `docs/decisions/`, `adr/`). If several match, ask the user once
   at checkpoint 1 which one.
3. No project log: copy the durable decisions into the description of the MR/PR they ship
   in, and into the final report.

Write the entry in **the project's own format** (match its existing entries: heading style,
fields, numbering, one ADR file per decision if that's the convention), commit it with the
change it governs, and record where it went in the ledger's `Project log` line. Sign it as
an agent decision, never in the user's name. The default wording is
`Agent, <YYYY-MM-DD> (not reviewed by <user>)`. **A project's own signing rule wins** — if its
`CLAUDE.md`/`AGENTS.md` or the log's header says how agent decisions are signed, use that.
When the user confirms or rejects a decision, update the project log entry too.

**Review.** `unreviewed` until the user answers at the final checkpoint (or earlier); then
`confirmed by user` or `rejected by user: <what instead>`. A rejected entry gets a new entry
for the replacement decision and, if built, follow-up nodes to change it.

## The status file

A short file at `largeBuild.status`, rewritten (not appended) at every checkpoint and
whenever a node changes state. It is what a resumed or replacement manager reads first:

- phase (planning · building · blocked on user · finishing · done) and the next action
- the workstreams, their leads, and each node's state (pending · running · `DONE` merged ·
  `NO_OP` · `BLOCKED` · escalated)
- the MRs/PRs: their nodes, branch, link, check result
- open escalations and the ledger entries they wait on
- worktrees still alive (`worktree.sh status <run>`)

**Resuming.** A manager that finds an existing status file for the run reads it and the
ledger, runs `worktree.sh status <run>`, reconciles any node the file and the worktrees
disagree on (trust the worktrees and git, then fix the file), and continues from the next
action. It never re-decides a ledger entry; a decision it disagrees with goes to the user
as a question.

## Prelude (sequential — manager)

1. Do implement's prelude: map the terrain (optionally 1 scout), write the **shared
   contract**, build the work graph, classify node tiers.
2. **Cut workstreams.** Remove the contract node(s); the remaining connected groups of
   nodes, by `needs` edges, are the candidate workstreams. Group them into at most
   `largeBuild.maxLeads` workstreams along natural areas (backend · UI · data · infra),
   each owning a disjoint set of files. An edge that crosses workstreams is a dependency the
   manager schedules; if there are many, the cut is wrong — recut or pull a contract
   upstream.
3. **Set MR boundaries and merge order.** Group nodes into MRs/PRs that each build and pass
   on their own, ordered by `needs`. The contract usually ships first, alone.
4. **Open the ledger** with every design call the contract made, each marked
   `agent decision, not reviewed by the user` unless the user made it in conversation, and
   tagged durable or implementation. Find the project decision log (see the ledger
   section) and copy the durable ones into it. Write the status file.
5. Commit the contract on the main checkout (router Step 5, item 1) — the base every
   workstream builds on.

**Checkpoint 1 — plan and contract ready.** Report: the workstreams and their leads (with
models), the graph table and waves per workstream, the MR list and merge order, the
contract, the durable ledger entries so far, where durable decisions will be written (the
project log found, or the MR/PR descriptions), and whether leads spawn their own builders or
run as planning leads. This is the router's Step 4 announcement; under `propose` (and always when
the router picked this mode on its own) wait for approval. Pushing branches and opening
MRs/PRs happens only if the approved plan says so.

## Fan-out (parallel — one lead per workstream)

Spawn every lead **in one message**. Each lead's brief is the 4-part contract plus:

- its workstream: nodes, `owns`, `needs`, tiers, and which MR each node belongs to
- the shared contract and the ledger entries that bind it (by id)
- the run id, the worktree script path, `worktrees.link` / `worktrees.setup`, and its share
  of `largeBuild.maxParallel`
- the escalation rule below, word for word
- how to report: each gated node, each question, and its final status

Each lead runs its workstream the way the router runs a graph: `create` a worktree per ready
node (ids prefixed with the workstream, e.g. `api.auth-routes`), brief a builder or senior
with the node check and that `NO_OP` is acceptable, gate on the status (router Step 5,
item 5), and have a **verifier** confirm the node check on each `DONE` node before handing
it on. Cascades (`escalation.builderToSenior`) apply inside the workstream.

**Leads don't merge.** A lead hands each gated `DONE` node to the manager: id, worktree
path, diff stat, verifier result. The manager runs `merge` in the planned order. Only one
process merges into the main checkout, so merges never race and the merge order stays the
manager's. After a merge, the lead `remove`s that node's worktree and starts any node whose
`needs` are now merged. Report through the harness's messaging if it has one; otherwise the
lead returns at the end of each wave and the manager resumes it.

### The escalation rule

A lead **never decides** anything that changes a spec, a contract, product behavior, cost,
or a vendor or dependency choice. It also sends up anything that touches another
workstream's files or a ledger entry. It sends the question to the manager with the
options it sees and what each would cost, pauses the nodes that depend on the answer, and
keeps building the nodes that don't.

The manager then either:

- **decides** it, writes a ledger entry (`agent decision, not reviewed by the user`) and,
  if it is durable, the project log entry, updates and commits the contract if it changed,
  and tells every affected lead; or
- **stops and asks the user** when the call is theirs to make: cost or spend, a new vendor
  or paid service, product direction, or reversing something the user said. That is
  checkpoint 3. Workstreams that don't depend on the answer keep running.

Inside its workstream a lead still makes ordinary engineering calls the contract leaves to
the implementation (local names, internal structure, test layout). If it isn't sure which
kind a call is, it escalates.

## Converge (sequential — manager, per MR)

When every node of an MR is merged:

1. Run the MR's full tests / typecheck / lint on the main checkout with a **verifier**
   (builder tier). On failure, send the failing scope back to its lead as a fix node; a
   failure that crosses workstreams is the manager's to reconcile.
2. If the plan includes MRs/PRs, push and open it, then wait for its CI.

**Checkpoint 2 — each MR/PR green.** Report: what merged, the check results and link,
ledger entries added since the last checkpoint, and what runs next. Under `propose`,
continue without waiting unless the plan said to pause between MRs.

**Checkpoint 3 — blocked on the user.** Whenever an escalation is the user's call, or no
workstream can make progress: the question, the options and what each costs, the ledger
entries involved, and what is still running. Update the status file to `blocked on user`.

## Stop rules

- **Lead stops** when every node in its workstream is merged or `NO_OP`; or when everything
  it has left waits on an escalation (it returns its state and the questions); or when a
  node is `BLOCKED` after its senior escalation (it returns the node, the failure and the
  worktree path). A lead never waits idle for an answer it could hand back instead.
- **Manager stops** when every MR in the plan is green and the final report is out; or when
  every remaining node waits on the user (checkpoint 3, then wait); or when a `BLOCKED` node
  sits on an MR's critical path and no re-brief fixes it (report it, keep its worktree). It
  does not pick new work outside the approved plan.
- **The mode ends** with the final report and `cleanup <run>` (router Step 8). A run that
  stops partway still updates the status file first, so it can resume.

**Final report.** What shipped per MR (links, check results), what didn't and why, kept
worktrees and their paths, and **every durable decision still `unreviewed`** (with where
each was written), listed for the user to confirm or reject one by one. Implementation
entries aren't listed; the ledger path is given for anyone who wants them. With no project
log, the durable decisions are written out in full here. Record the answers in the ledger
and the project log.

## Notes

- Two leads is the normal size. A third is for a genuinely separate area; past
  `largeBuild.maxLeads`, the build is two builds — plan them separately.
- The manager doesn't build nodes and doesn't run a workstream itself; if a workstream is
  too small to need a lead, fold it into another lead's workstream.
- The ledger, status file and contract are the manager's handoff. If they can't be read
  cold by a replacement manager, they aren't done.
