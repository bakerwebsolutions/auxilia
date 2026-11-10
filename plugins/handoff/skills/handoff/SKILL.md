---
name: handoff
description: Write a self-contained prompt that lets a fresh agent session (or another harness, or a colleague) pick up the current work cold. Saves it to a collision-free file (handoff-<slug>-<6 digits>.md) in /tmp, in the directory a repo's checked-in .claude/handoff.json names, or wherever the user says, and copies it to the clipboard. Use when the user says /handoff, "hand this off", "write a handoff", "prompt for a new session", or wants to continue the work somewhere else.
argument-hint: "[goal for the next session] [--dir <path>]"
---

# handoff

A handoff is **extraction, not compression**. `/compact` summarizes everything that
happened. A handoff pulls out only what the *next* task needs, so a reader with zero
context can act on it. Write it for a stranger arriving cold.

## Inputs

- **Goal** (the argument): what the next session is for. It decides what goes in.
  If it's missing or too vague to steer ("continue", "fix it", "more"), infer it from
  the conversation and state your inference on the prompt's first line. Ask only when
  the conversation supports two very different goals.
- **`--dir <path>`** or an explicit location in the request ("save it in docs/handoffs").
  This wins over config for this run.

## Procedure

### 1. Resolve where it goes

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/handoff/scripts/handoff.sh" config
"${CLAUDE_PLUGIN_ROOT}/skills/handoff/scripts/handoff.sh" path --slug "<2-4 word goal slug>" [--dir <path>]
```

`path` checks, in order: `--dir`, then `<repo>/.claude/handoff.json` `dir` (relative to
the repo root), then `~/.claude/handoff.json` `dir`, then `${TMPDIR:-/tmp}`. It reserves an
empty file named `handoff-<slug>-<NNNNNN>.md` and prints its absolute path. Write to
exactly that path; never invent one. If `config` returns `instructions`, follow them.
They are the repo's own rules for handoffs.

If the resolved directory is inside the repo and not gitignored (`git check-ignore -q`),
say so once in the final message. Don't edit `.gitignore` yourself.

### 2. Gather facts, checking each one cheaply

Look at real state, not only at memory of the conversation:

- `git status --short`, `git branch --show-current`, `git log --oneline -5`, and
  `git diff --stat` when there are changes. Record which changes belong to this task
  and which were already there when the task began.
- Re-check any claim the next session will build on, such as "tests pass" or "the
  endpoint returns 200", with one command or file read. When you can't, mark it.

Tag every claim about state:
- **[verified]**: a command or read *in this session* confirmed it. Name the check.
- **[unverified]**: believed, reported by a subagent, or inferred.

A confident wrong claim becomes a false premise for the next agent. When in doubt,
tag it [unverified].

### 3. Write the prompt

Use this skeleton. Drop a section only when it would be empty; never drop
**Dead ends**. Point to specs, plans, issues and diffs by path, URL or commit hash
instead of pasting them.

```markdown
# Handoff: <goal in one line>

<One paragraph: what we're building and why, and where it stands right now. Write it
as a brief to the next agent ("You are picking up…"), not as a diary.>

## Goal for this session
<The next task, stated so success is checkable. Keep the user's words verbatim when
they gave a goal.>

## Done when
- <observable check: a command that passes, a behavior you can see, a file that exists>

## Current state
- Repo: <abs path> · branch `<branch>` · <clean | N files changed>
- <claim> [verified: <check>]
- <claim> [unverified]

## Decisions made (don't reopen)
- <decision> because <reason>. <What the user pushed back on or rejected, if anything.>

## Dead ends
- Tried <X>; it failed because <Y>. Don't retry unless <condition>.

## Hazards
- <traps, fragile spots, destructive commands to avoid, rules the user set>

## Key files
- `<path>`: <why it matters for the goal>

## Commands
- `<command>`: <what it checks or does>

## Open questions
- <question>. Ask the user | decide yourself, default: <default>.

## First step
<The single concrete action to take first.>
```

Rules for the content:
- **Secrets:** never include tokens, keys or passwords. Refer to where they live
  (an env var name, a secrets store, a file path).
- **User preferences:** carry over any rule the user stated this session ("don't
  push", "use rg") under Hazards. The next session won't know them.
- **Length:** usually 40–150 lines. Cut narrative before you cut Dead ends or Hazards.
- **Agent-neutral:** don't assume the reader is Claude Code unless the user said so.
  Spell out tool or skill names when the next step depends on them.

### 4. Cold-read check

Reread it as someone with only this file. Fix anything that fails:
- Could they do the **First step** without asking anything?
- Do any pronouns or nicknames ("the bug", "option B", "the new script") point to
  something the file never defines?
- Is every state claim tagged?

### 5. Deliver

1. Write the prompt to the reserved path.
2. If `clipboard` is true (the default), run `handoff.sh copy <path>`. If it exits
   non-zero, say the clipboard wasn't available.
3. Reply with:
   - the **full absolute path** of the file, every time, never a shortened form
   - whether it was copied to the clipboard
   - a one-line suggested opener for the next session, for example:
     `Read <abs path> and continue from "First step".`
   - any [unverified] claims the user may want to confirm first

Don't print the whole prompt in chat unless asked, because the file is the deliverable.
Don't launch a new session or end this one.

## Config

`.claude/handoff.json` at the repo root (checked in) or `~/.claude/handoff.json`.
The repo file wins key by key.

```json
{
  "dir": "docs/handoffs",
  "clipboard": true,
  "instructions": "Always include the staging deploy status and the open PR number."
}
```

| key | default | meaning |
|---|---|---|
| `dir` | `${TMPDIR:-/tmp}` | Where handoffs are written. Relative paths resolve from the repo root (repo config) or `$HOME` (user config). `~` expands. |
| `clipboard` | `true` | Also copy the prompt to the clipboard. |
| `instructions` | none | Extra repo-specific guidance the skill follows when writing. |
