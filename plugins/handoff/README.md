# handoff

**Version:** 1.0.0

`/handoff` writes a prompt that lets a fresh agent session (or another harness, or a
colleague) pick up the current work with no other context. It extracts what the next
task needs, which makes it different from `/compact`'s summary of everything:

- **Goal-driven:** `/handoff <what the next session should do>` decides what goes in.
- **Verified state:** every claim about state is tagged `[verified: <check>]` or
  `[unverified]`, and claims are re-checked against git and the files before writing.
- **Dead ends and hazards:** what failed and why, plus the user's standing rules, so the
  next session doesn't repeat mistakes.
- **Cold-read check:** before saving, the skill confirms a stranger could take the
  first step without asking anything.

## Install

```
/plugin marketplace add bakerwebsolutions/auxilia
/plugin install handoff@auxilia
```

## Use

```
/handoff finish wiring the webhook retry and get the integration test green
/handoff --dir ~/notes/handoffs ship the docs PR
```

Each run writes `handoff-<slug>-<6 random digits>.md` (the file is reserved atomically,
so concurrent runs never collide), copies it to the clipboard, and prints the full path.

## Where it saves

1. `--dir <path>`, or a location named in the request
2. `dir` in `<repo>/.claude/handoff.json` (check this file in to set it per repo)
3. `dir` in `~/.claude/handoff.json`
4. `${TMPDIR:-/tmp}`

```json
{
  "dir": "docs/handoffs",
  "clipboard": true,
  "instructions": "Always include the staging deploy status and the open PR number."
}
```

Relative `dir` values resolve from the repo root. `instructions` lets a repo add its
own required content.

## Prior art

The design borrows from Amp's `/handoff` (goal argument, extraction instead of
compaction), aihero.dev's handoff skill (temp-dir default, reference by path, redact
secrets), ostikwhy-blip's HANDOFF.md skill (verified/unverified tags, dead ends that
are never cut), EpicenterHQ's handoff (task-start baseline, cold-read check, done
definition) and pi-agent-extensions (goal kept verbatim, reject vague goals).
