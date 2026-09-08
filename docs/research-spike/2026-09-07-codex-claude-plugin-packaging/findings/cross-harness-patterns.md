# Cross-harness packaging patterns

## User / job to be done

Avoid behavioral drift while supporting the packaging contracts each host currently requires.

## Sources reviewed

- [Agent Skills specification](https://agentskills.io/specification)
- [Claude Code skills](https://code.claude.com/docs/en/skills)
- [Claude Code plugins](https://code.claude.com/docs/en/plugins)
- [Claude Code marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)
- [OpenAI plugin packaging](https://developers.openai.com/plugins/build/plugins)
- [Agent Plugins v1](https://agent-plugins.org/specification)

## Patterns compared

| Pattern | Benefit | Cost | Fit |
|---|---|---|---|
| One canonical skill + thin host adapters | One workflow, native installation on each host | Two small manifests and catalogs | Recommended now |
| Generated host packages | Prevents metadata drift at scale | Build/release tooling and generated-file policy | Later, if plugin count grows |
| Portable root plugin spec + extensions | Architecturally attractive | Native marketplace support is not the present contract | Watch, do not adopt yet |
| Symlinks/shared external files | Looks DRY locally | Breaks package caching/boundaries | Do not use |

## Implications for Auxilia

Keep `skills/research-spike/SKILL.md` as the single source of workflow truth. Keep the shared frontmatter within the portable `name`/`description` subset. Place only platform-specific metadata in `.claude-plugin/`, `.codex-plugin/`, and their marketplace catalogs. Do not use outside-package references.

## Open questions

- Does Codex need optional `agents/openai.yaml` presentation metadata for this skill?
- When should a manifest/catalog consistency check be introduced?
