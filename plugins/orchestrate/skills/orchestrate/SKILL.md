---
name: orchestrate
description: Route a task to a pre-curated, role-tiered workflow and run it. Use when the user says "orchestrate", "decompose", "delegate this", "parallelize", "fan out", or hands you a multi-part task. Detects the task type (research · design · implement · debug · review · optimize), then runs that workflow's recipe — a shared sequential prelude, a parallel fan-out, and a convergence step. Resolve models from the active harness before delegating. Decomposes work into a dependency graph and isolates parallel writers in git worktrees.
argument-hint: "[task]  |  go <run>  |  cleanup <run>"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/worktree.sh *)
---

# orchestrate — the router

You are a **router**, not a freelancing supervisor. Detect what kind of task this is,
select the matching **pre-curated workflow**, and run its recipe. The recipe — not you
in the moment — decides the fan-out shape and which tier does what. You still own the
thinking: classification, the prelude reasoning, and the final synthesis.

The pattern (Anthropic, *Building Effective Agents*): classify the input, dispatch to a
specialized followup. Cheap, deterministic, debuggable. Keep it that way.

## Step 0 — Load config

Deep-merge these (first present wins **per key**), so the user sets global defaults and a
repo overrides specifics:

1. The active harness's project-level config location (for example `.claude/` or `.codex/`)
2. The active harness's user-level config location
3. The installed package's `orchestrate.config.json` (shipped default)

Keys you act on: `roles.{orchestrator,builder,scout}`, `autonomy`, `threshold.*`,
`workflows.<name>.{enabled,maxParallel}`, `escalation.scoutToBuilder`,
`worktrees.{mode,cleanup,link,setup}`,
`harness`, `harnessProfiles`, and `alwaysPassModelExplicitly`. Defaults if no file: detect
the harness from its available delegation tool, use its profile, and inherit a role when no
supported model can be established. Never pass a Claude alias to Codex or a Codex model ID
to Claude.
`autonomy=propose`, all workflows except `optimize` enabled, pass model explicitly,
`worktrees.mode=auto` (worktrees whenever two or more writing nodes run concurrently),
`worktrees.cleanup=on-success`, `worktrees.link=[]`, no `worktrees.setup`.

## Resolve harness and roles before delegation

Set the harness in this precedence order:

1. An explicit `harness` config value other than `auto`.
2. The available delegation capability: Claude's `Agent`/Task interface means `claude`;
   Codex's `spawn_agent`/collaboration interface means `codex`.
3. If still uncertain, do not guess a model. Omit the model override and use the harness
   default (or stay single-agent if delegation is unavailable).

Resolve each role by taking an explicit non-`auto` `roles.<role>` value, otherwise the
selected `harnessProfiles.<harness>.roles.<role>` value. Before passing it, verify the value
is in the runtime's advertised model choices. If it is absent, omit the model parameter;
the harness default is safer than a stale profile. The active primary model is context, not
a reliable model catalog.

## The roles

Everything routes to **four roles**, not four fixed model names. The config maps roles → models.

| Role | Does | Default | Read/write |
|------|------|---------|-----------|
| **orchestrator** | classify · run the recipe · reason on the prelude · synthesize · adversarially judge/verify | harness profile | you (this session) + peer instances you spawn for judging |
| **builder** | implement code · write prose · run tests to verify | harness profile | writes |
| **scout** | search · locate · map · external research | harness profile | read-only |

**Swapping the orchestrator = swapping the whole top tier.** A natural-language model
override applies only when that model is advertised by the active harness; it always beats
the config for that run. Keep the other roles unchanged unless the user explicitly retieres
them. In Codex, “use Astra to orchestrate” means
`roles.orchestrator = gpt-6-astra` for that run only; builders and scouts retain their
resolved tiers. In Claude, the equivalent established override is Fable.

## The shared 3-stage skeleton

Every workflow has the same spine. The **prelude is the point** — it is the common,
sequential piece that produces the shared artifact the parallel legs depend on. Without it,
the "parallel" legs collide on undecided shared context (an interface, a repro, a frame) and
aren't actually independent.

```
Prelude   (sequential · orchestrator reasons, may use 1 scout)
              → produces the SHARED artifact that unblocks fan-out
   Fan-out  (parallel · N cheap agents, capped at workflows.<name>.maxParallel)
              → the independent work the prelude just unblocked
      Converge (sequential · orchestrator)
              → synthesize / verify / adversarially check → report
```

Always find the prelude first. Ask: *what one thing, once decided, makes the rest
independent?* Do that, then fan out.

When the work has more than one piece, the skeleton generalizes to a **work graph**: the
prelude is the graph's root, and "fan-out" becomes "run every node whose blockers are done".
See Step 2.

## Step 1 — Classify the task

Pick **one** workflow. Route on the **oracle** (how success is judged), not the verb —
keywords overlap, oracles don't.

| Workflow | Oracle — success is judged by… | Signals | Shape |
|----------|-------------------------------|---------|-------|
| **research** | synthesized information | "how does", "find out", "compare", "investigate", a question | parallel read-only |
| **design** | options/an artifact to choose among | "design", "architect", "approach", "how should we", "spike" | parallel read-only |
| **implement** | a spec / contract satisfied | "add", "build", "implement", "make it do X", refactor/test/docs/migrate | sequential + verify |
| **debug** | a reproduction stops failing | "bug", "broken", "fails", "crash", "regression", a stack trace | empirical loop |
| **review** | judgment of existing code | "review", "critique", "find bugs in", "is this correct", a diff/PR | parallel-adversarial read-only |
| **optimize** | a measurement improves | "slow", "faster", "optimize", "latency", "memory", "reduce cost" | empirical loop |

**Flavors ride on a base workflow** (they toggle stages, they are not their own route):
refactor · test · docs · small-migration → **implement**; security-audit → **review**.

If two workflows genuinely tie, or the request is too vague to classify, **ask one
question** — do not guess. If the picked workflow is `enabled: false` in config, say so and
route to the closest enabled one (or ask). The user can force a workflow in natural language
("orchestrate this as a review") — honor it over your own classification.

## Step 2 — Decompose into a work graph

Before fanning out, break the work into **nodes** and the **edges** between them — a
dependency graph (a DAG). The point is to find what is *blocking*: the pieces that
everything else waits on are the ones to do first, and do well.

Each node is one self-contained unit of work:

| Field | Meaning |
|-------|---------|
| `id` | short slug, `[a-z0-9._-]` (it names the worktree and branch) |
| `does` | one line: what this node makes true |
| `owns` | files/modules it may write — nodes that run concurrently must own **disjoint** sets |
| `needs` | ids of nodes that must be **merged** before this one starts |
| `role` | scout / builder / orchestrator |

Add an edge `A → B` (B needs A) when any of these hold:

- **B consumes A's output** — an interface, type, schema, generated file, or finding.
- **They write the same file.** Either serialize them with an edge, or merge them into one
  node; never run two writers on one file in parallel.
- **B's verification depends on A** — B's tests exercise A's code.

Then read the graph:

- **Blockers** are the nodes with the most downstream dependents. They are usually the
  shared contract — the prelude. Do them first; spend the orchestrator's reasoning there.
- **The critical path** (longest chain of `needs`) sets the run's minimum length. If it is
  long, look for a contract you can pull upstream to cut it — a node that only needs an
  *interface* from A, not A's implementation, can depend on a small "define the interface"
  node instead.
- **A cycle** means the decomposition is wrong: extract the piece both sides need into a new
  upstream node (that is a contract), or merge the cycle into one node.
- **Waves** are the topological layers: wave 0 has no `needs`, wave *k* needs only earlier
  waves. Nodes in a wave are the parallel fan-out, capped at `workflows.<name>.maxParallel`.

Collapse the graph when it's trivial: a single node, or a straight chain of small edits, is
just sequential work — don't build ceremony around it. Read-only workflows (research,
design, review, debug hypotheses) usually produce a flat graph of independent legs; the
graph matters most for **implement** and **optimize**, where nodes write.

## Step 3 — Run the workflow recipe

Read this package's `skills/orchestrate/workflows/<workflow>.md` and follow it. Each
recipe specifies its prelude, its fan-out (which role, how many, what each does), and its
convergence. It also lists the flavors that ride on it and which stages they toggle.

## Step 4 — Announce, then act per `autonomy`

Announce the plan compactly before spawning anything: the **detected workflow** (and why),
the **prelude**, the **work graph**, the tier each node runs on, and the **convergence**.
Show the graph as a table (`id · does · owns · needs · role`) followed by its waves and
critical path, e.g. `wave 0: contract → wave 1: api, ui → wave 2: e2e`.

- **`propose`** (default): stop after announcing and wait for approval. Pick the run id now
  and tell the user they can approve with `/orchestrate go <run>`.
- **`auto`**: run immediately.
- **`threshold`**: run immediately only if `parallel legs <= threshold.maxParallelAuto`
  **and** `files touched <= threshold.maxFilesAuto`; otherwise fall back to `propose`.

**Approval and the script grant.** This skill pre-approves its worktree script
(`allowed-tools`) only for the turn that invokes the skill; the grant clears when the user
sends their next message. Approving with `/orchestrate go <run>` invokes the skill again,
so the whole run executes with the script approved. If the user approves in plain words
instead, carry on — the script calls simply go through the normal permission flow.

## Step 5 — Isolate writing nodes in worktrees

When `worktrees.mode` allows it, every node that **writes** gets its own git worktree and
branch, so concurrent builders never share a checkout:

- **`auto`** (default): use worktrees whenever two or more writing nodes run at once; a lone
  writer works in the main checkout.
- **`always`**: every writing node gets a worktree, even alone.
- **`off`**: builders share the main checkout — the disjoint-`owns` rule is then the only
  thing keeping parallel writers apart, so be strict about it. The status gate (item 5
  below) still applies; there is just no worktree to discard.

Read-only nodes always run in the main checkout. All worktree operations go through the
bundled script — never run `git worktree` or `git branch -D` by hand:

```
${CLAUDE_SKILL_DIR}/scripts/worktree.sh create  <run> <node> [base] [--link <path>]...   # prints the path
${CLAUDE_SKILL_DIR}/scripts/worktree.sh merge   <run> <node>          # commit + merge into the current branch
${CLAUDE_SKILL_DIR}/scripts/worktree.sh status  [run]
${CLAUDE_SKILL_DIR}/scripts/worktree.sh remove  <run> <node> [--force]
${CLAUDE_SKILL_DIR}/scripts/worktree.sh cleanup <run|--all> [--force]
```

Worktrees live at `<repo>/.orchestrate/worktrees/<run>/<node>` (git-excluded locally) on
branches `orchestrate/<run>/<node>`. The script touches nothing outside that namespace.
`<run>` is a short slug for this orchestration (e.g. `auth-refresh`).

Execute the graph wave by wave:

1. **Precondition.** The main checkout must have no uncommitted tracked changes — `merge`
   refuses otherwise. If it's dirty, ask the user to commit or stash first. If the prelude
   wrote a contract into the main checkout, commit it before creating worktrees — that
   commit is the base every node builds on.
2. **Create** a worktree for each ready writing node in the wave. It branches from the
   current `HEAD`, which already contains every earlier wave's merged work — that is how a
   node sees what it `needs`.
3. **Make it buildable.** A fresh worktree holds only tracked files — no installed
   dependencies, env files, or build output — so a builder can't run its check without help:
   - pass `--link <path>` to `create` for each entry in `worktrees.link` (e.g.
     `node_modules`, `.venv`, `.env`). The script symlinks it from the main checkout and only
     accepts gitignored paths. Linked dependencies are **shared**: a node must not install
     or upgrade packages through a link — if it needs a new dependency, that's its own
     upstream node.
   - if `worktrees.setup` is set, run it inside the new worktree (`cd <path> && <setup>`) as
     an ordinary command, under normal permissions. It deliberately doesn't go through the
     script: the script is pre-approved, and config-supplied commands must not inherit that.
4. **Brief** each builder with its worktree path as its working root: *"Work only inside
   `<path>`. Use absolute paths under it for every read and edit, and `cd <path>` in every
   shell command. Do not commit — leave your changes in the worktree."* Plus its **node
   check**: the narrowest test/typecheck/lint command that covers what it `owns`. Do **not**
   also pass the harness's own worktree isolation (e.g. `isolation: "worktree"`); the script
   already isolated it.
5. **Gate on the result.** Every builder's reply opens with a status (see Step 6). Decide
   per node before merging:
   - **`DONE`** — skim the diff (`git -C <path> diff --stat`) for out-of-scope files, then
     merge. Merge on the check passing and the diff matching the brief, not on the worker's
     own account of its work.
   - **`NO_OP`** — nothing to merge; `remove` the worktree. If the graph *expected* this
     node to change something, treat it as a signal, not a pass: either the work was already
     done or the brief was wrong. Check which before releasing the nodes that `need` it.
   - **`BLOCKED`** — the builder already spent its one correction pass. Don't merge; keep
     the worktree, and decide yourself: fix the brief and re-run, absorb the fix, or stop the
     nodes downstream of it. A broken node never reaches the main branch.
6. **Merge** each `DONE` node with `merge <run> <node>`. It commits whatever the builder
   left, then merges the branch into the current branch with `--no-ff`. Exit `3` means a
   conflict: the merge is aborted and the worktree kept. A conflict between nodes the graph
   called independent is a missing edge — resolve it yourself (orchestrator), or re-run the
   node from a fresh worktree on the new `HEAD`.
7. **Remove** each merged node's worktree right away (`remove <run> <node>`) so long runs
   don't pile up checkouts, then start the next ready nodes.

Don't wait for a whole wave if a node's blockers are all merged — start it as soon as it's
ready. The waves are the plan; readiness is the schedule.

**optimize** is the exception to "merge everything": its candidates are competing, not
complementary. Create one worktree per candidate, merge only the measured winner, and
`--force`-remove the rest.

## Step 6 — Fan out with tight briefs

Each fan-out leg gets a **self-contained 4-part contract** (Anthropic multi-agent research)
— never forward your whole conversation:

```
Objective:     what to make true / find out
Output format: exactly what to return (headings, shape)
Tools/sources: where to look; what it may touch
Boundaries:    what to leave alone; when it's done
```

- Launch all **parallel** legs **in one message** (multiple Agent calls) so they run concurrently.
- **Cap** parallel legs at `workflows.<name>.maxParallel`. Prefer fewer well-scoped agents.
- **Every writing leg returns a status first**: `DONE` · `NO_OP` · `BLOCKED` (the
  `implementer` agent already does). Say in the brief that no change is an acceptable
  answer — otherwise a builder handed already-clean code will invent a tweak to look useful.
  Read-only legs need no status; "nothing found" is already their valid result.
- Pass an explicit model only when `alwaysPassModelExplicitly` is true **and** the resolved
  model is advertised by the active harness. Use that harness's spawn API and parameter
  spelling; otherwise omit it and inherit the harness default.
- **Cascade** (`escalation.scoutToBuilder`): if a scout leg returns thin/low-confidence
  output, re-run that one leg at the builder tier before giving up.

## Step 7 — Converge and synthesize

Run the recipe's convergence (synthesize, verify, or adversarially judge — the recipe says
which). Verification (running tests/typecheck) is mechanical → **builder** tier; adversarial
judging (is this finding real? is this the true root cause?) needs reasoning →
**orchestrator** tier, spawned as an independent instance so it doesn't just confirm itself.

Then report: what's done, what each agent changed/found, verification outcomes, follow-ups.
You own the synthesis — never hand judgment to a subagent.

## Step 8 — Clean up worktrees

Always finish a run that created worktrees with:

```
${CLAUDE_SKILL_DIR}/scripts/worktree.sh cleanup <run>
```

Without `--force`, cleanup removes merged nodes and **keeps** any node with uncommitted or
unmerged work, printing why (exit `1`). That is the safe default when a node failed or a
merge conflicted — report the kept worktrees and their paths so the user can inspect them.
Per `worktrees.cleanup`:

- **`on-success`** (default): run plain `cleanup`; keep failed/unmerged nodes for inspection.
- **`always`**: run `cleanup <run> --force` after reporting — discards unmerged node work.

Run cleanup even when the run aborts partway: a stopped run must not leave stale
checkouts behind. `status` lists anything left over; `cleanup --all` sweeps every run.

## Arguments

- `go <run>` — the user approved the announced plan for `<run>`; execute it from Step 5.
- `cleanup <run>` (or `cleanup --all`) — run Step 8 only and report what was removed/kept.
- anything else — the task to orchestrate.

## Notes

- Reasoning, architecture, and trade-off calls stay with the orchestrator. Delegate
  execution, not judgment.
- If a brief can't be made self-contained, the leg isn't ready to fan out — tighten the
  prelude first. The same goes for a node whose `owns` overlaps a sibling's: add the edge.
- To run a specific workflow directly (bypassing classification), inspect config, or check
  what the router *would* pick, use the **`/orchestrate-workflows`** companion skill.
