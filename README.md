# auxilia

Reusable [Claude Code](https://claude.ai/code) skills — install once, use in any project.

## What's here

| Skill | Description |
|-------|-------------|
| [`research-spike`](skills/research-spike/SKILL.md) | Fan out parallel web-research agents, synthesize findings, save durable artifacts |

## Installing a skill

Copy the skill directory into your project's `.claude/skills/`:

```sh
cp -r skills/research-spike /path/to/your/project/.claude/skills/
```

Or symlink it if you want live updates:

```sh
ln -s /path/to/auxilia/skills/research-spike /path/to/your/project/.claude/skills/research-spike
```

Then invoke it in Claude Code:

```
/research-spike
```

## Adding a skill

1. Create `skills/<name>/SKILL.md` with the frontmatter header (`name`, `description`) and procedure.
2. Add it to the table in this README.
