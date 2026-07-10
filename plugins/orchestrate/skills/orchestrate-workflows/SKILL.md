---
name: orchestrate-workflows
description: Companion to /orchestrate — run a specific workflow directly (bypassing the router's classification), inspect or edit the layered config, or dry-run "what would the router pick" for a prompt. Use when the user says "run the review workflow", "force implement", "show my orchestrate config", "set orchestrator to fable", "edit the orchestrate config", or "what workflow would this be".
---

# orchestrate-workflows — run + manage

The management surface for the `orchestrate` router. Three jobs: **run** a workflow
directly, **manage** the config, **explain** what the router would do. Figure out which
from the request, then do that one thing.

## Config resolution (used by every mode)

Layered, deep-merged, first present wins **per key**:

1. `$CLAUDE_PROJECT_DIR/.claude/orchestrate.config.json` (repo)
2. `~/.claude/orchestrate.config.json` (user)
3. `${CLAUDE_PLUGIN_ROOT}/orchestrate.config.json` (shipped default)

The schema is `${CLAUDE_PLUGIN_ROOT}/orchestrate.config.schema.json`. The workflow recipes
live in `${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/workflows/<name>.md`.

## Mode A — Run a workflow directly

Use when the user names a workflow ("run implement", "use the review workflow on this
diff", "force debug"). This **skips classification** — the user has already chosen.

1. Load the merged config.
2. If the named workflow is `enabled: false`, say so and confirm the user wants it anyway
   (a direct request overrides the enabled flag — honor it, just flag it once).
3. Read `${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/workflows/<name>.md` and run it exactly
   as the router would (Steps 3–5 of the `orchestrate` skill: announce per `autonomy`, fan
   out with 4-part briefs capped at `maxParallel`, converge). Honor any natural-language
   role override in the request ("...with fable orchestrating").

## Mode B — Manage the config

Use for "show my config", "set orchestrator to fable", "bump implement's maxParallel",
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
| "use fable to orchestrate everywhere" | `roles.orchestrator: "fable"` (user layer) |
| "sonnet should build" / retier a role | `roles.{builder,scout}` |
| "enable/disable a workflow" | `workflows.<name>.enabled` |
| "allow more parallel agents" | `workflows.<name>.maxParallel` |
| "just run it, don't ask" | `autonomy: "auto"` |
| "stop injecting the doctrine" | `doctrine: "off"` |

## Mode C — Explain / dry-run

Use for "what workflow would this be", "which tier handles X", "explain the routing". Do
**not** execute anything.

1. Load the merged config.
2. Apply the router's Step 1 classification to the user's described task: name the
   **workflow**, the **oracle** that decided it (not just the keyword), and the runner-up if
   it was close.
3. Sketch the plan the recipe would produce: the **prelude** (shared unblock), the
   **fan-out** (N legs × which role/model), and the **convergence** — without spawning agents.
4. Note the effective roles (incl. any fable override) and the `maxParallel` cap that would
   apply.

## Notes

- This skill manages and launches; the actual recipes and the routing logic live in the
  `orchestrate` skill and `workflows/*.md`. Keep them the source of truth — don't duplicate
  recipe steps here.
- Prefer editing config over hand-holding: if the user keeps forcing the same workflow or
  role, offer to make it the default in their user-layer config.
