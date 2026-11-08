---
name: orchestrate-workflows
description: Companion to /orchestrate — run a specific workflow directly (bypassing the router's classification), inspect or edit the layered config, or dry-run "what would the router pick" for a prompt. Use when the user says "run the review workflow", "force implement", "run this as a large build", "show my orchestrate config", "use Astra to orchestrate", "edit the orchestrate config", or "what workflow would this be".
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/worktree.sh *)
---

# orchestrate-workflows — run + manage

The management surface for the `orchestrate` router. Three jobs: **run** a workflow
directly, **manage** the config, **explain** what the router would do. Figure out which
from the request, then do that one thing.

## Config resolution (used by every mode)

Layered, deep-merged, first present wins **per key**:

1. The active harness's project-level config location (for example `.claude/` or `.codex/`)
2. The active harness's user-level config location
3. The installed package's `orchestrate.config.json` (shipped default)

The schema is this package's `orchestrate.config.schema.json`. The workflow recipes live in
`skills/orchestrate/workflows/<name>.md`.

Resolve the harness before showing or editing role choices: explicit `harness` wins; else
use the available delegation API (`Agent`/Task = Claude; `spawn_agent` = Codex). Resolve a
role from an explicit non-`auto` value, otherwise from `harnessProfiles.<harness>`. A model
override is valid only if it is advertised by that running harness; omit invalid overrides
and inherit the harness default.

## Mode A — Run a workflow directly

Use when the user names a workflow ("run implement", "use the review workflow on this
diff", "force debug"). This **skips classification** — the user has already chosen.

1. Load the merged config.
2. If the named workflow is `enabled: false`, say so and confirm the user wants it anyway
   (a direct request overrides the enabled flag — honor it, just flag it once).
3. Read this package's `skills/orchestrate/workflows/<name>.md` and run it exactly
   as the router would (Steps 2 and 4–8 of the `orchestrate` skill: build the work graph,
   announce per `autonomy`, isolate writing nodes in worktrees, fan out with 4-part briefs
   capped at `maxParallel`, converge, clean up). Call the worktree script as
   `${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/worktree.sh`. Honor a natural-language role
   override only when the active harness advertises that model.

**Forcing large build.** "Run this as a large build" (or "large-build this", "force large
build") runs `workflows/large-build.md`: build the implement graph, skip the router's
Step 2b threshold check, and go straight to the manager/lead recipe. "Force implement" or
"no large build" does the opposite and keeps plain implement even over the threshold. If
`largeBuild.enabled` is false, flag it once and honor the request. Under any `autonomy`, the
large-build plan is checkpoint 1 of its recipe; follow `autonomy` for whether to wait.

## Mode B — Manage the config

Use for "show my config", "use Astra to orchestrate", "bump implement's maxParallel",
"enable optimize", "put this at the user level", "scaffold a repo config".

- **Show** — print the three layers and the effective merged result, so the user can see
  which layer wins each key.
- **Edit** — ask **which layer** to write if it's ambiguous (repo vs user); repo is the
  default for project-specific changes, user for "everywhere". Create the file from the
  shipped default if it doesn't exist yet, then apply the change. Keep the `$schema`
  pointer. Write only the keys the user wants to override — a partial file is valid, since
  config is deep-merged over the shipped default; don't copy the whole default in unless
  they ask.
- **Validate** — after any edit, check the result against `orchestrate.config.schema.json`
  (`additionalProperties: false`, enums, types). Report if anything is off.

Common edits and where they land:

| Ask | Key |
|-----|-----|
| "use a model to orchestrate everywhere" | `roles.orchestrator: "<supported model>"` (user layer) |
| "retier a role" | `roles.{senior,builder,scout}` or `harnessProfiles.<harness>.roles.*` |
| "allow more hard nodes on the top tier" | `workflows.<name>.maxSenior` |
| "don't escalate failed builders" | `escalation.builderToSenior: false` |
| "enable/disable a workflow" | `workflows.<name>.enabled` |
| "allow more parallel agents" | `workflows.<name>.maxParallel` |
| "just run it, don't ask" | `autonomy: "auto"` |
| "stop injecting the doctrine" | `doctrine: "off"` |
| "don't use worktrees" / "always use worktrees" | `worktrees.mode: "off"` / `"always"` |
| "throw away failed worktrees too" | `worktrees.cleanup: "always"` |
| "builders can't run tests in worktrees" | `worktrees.link: ["node_modules", …]` and/or `worktrees.setup: "<install cmd>"` |
| "never switch to large build on its own" | `largeBuild.enabled: false` |
| "large build only for bigger graphs" | `largeBuild.minWorkstreams` / `largeBuild.minNodes` |
| "only two leads" | `largeBuild.maxLeads: 2` |
| "run leads on a different model" | `roles.lead` (or `roles.manager` for the manager) |
| "keep the decision ledger in the repo" | `largeBuild.ledger: "docs/decisions/<run>.md"` |
| "write decisions to our decision log" | `largeBuild.projectLog: "<path>"` (`auto` detects it, `none` uses the MR/PR description) |

## Mode C — Explain / dry-run

Use for "what workflow would this be", "which tier handles X", "explain the routing". Do
**not** execute anything.

1. Load the merged config.
2. Apply the router's Step 1 classification to the user's described task: name the
   **workflow**, the **oracle** that decided it (not just the keyword), and the runner-up if
   it was close. For implement, say whether Step 2b would switch to large build: the
   workstream and writing-node counts against `largeBuild.minWorkstreams` / `minNodes`.
3. Sketch the plan the recipe would produce: the **prelude** (shared unblock), the **work
   graph** (nodes, `needs` edges, waves, critical path, which nodes get worktrees), and the
   **convergence** — without spawning agents or creating worktrees.
4. Note the effective roles (including any top-tier model override and which nodes would
   run at the senior tier, with why) and the `maxParallel` cap that would
   apply.

## Notes

- This skill manages and launches; the actual recipes and the routing logic live in the
  `orchestrate` skill and `workflows/*.md`. Keep them the source of truth — don't duplicate
  recipe steps here.
- Prefer editing config over hand-holding: if the user keeps forcing the same workflow or
  role, offer to make it the default in their user-layer config.
