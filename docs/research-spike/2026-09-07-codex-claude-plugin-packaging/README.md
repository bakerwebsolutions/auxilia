# Codex + Claude plugin packaging

## Summary

Auxilia should package `research-spike` as one canonical skills-based plugin, not as two implementations. Both Codex and Claude Code can consume a plugin directory containing the same `skills/research-spike/SKILL.md`; each host currently needs its own small manifest and marketplace catalog. That is necessary distribution metadata, not a duplicated workflow.

## Strongest conclusions

| Conclusion | Evidence | Consequence |
|---|---|---|
| Codex has a native plugin package and marketplace model. | [OpenAI plugin packaging](https://developers.openai.com/plugins/build/plugins) | Add `.codex-plugin/plugin.json` and a Codex catalog that references the existing plugin directory. |
| Claude Code uses its own manifest and marketplace schema. | [Anthropic marketplace docs](https://code.claude.com/docs/en/plugin-marketplaces) | Retain `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` as adapters. |
| Both hosts use a `skills/<name>/SKILL.md` package structure. | [Codex build plugins](https://learn.chatgpt.com/docs/build-plugins), [Claude plugins](https://code.claude.com/docs/en/plugins) | Keep exactly one copy of the skill. |
| Package caching makes outside-package links fragile. | [Claude marketplace docs](https://code.claude.com/docs/en/plugin-marketplaces) | Do not make a packaged plugin depend on symlinks or files outside its root. |

## Options

### 1. Canonical skill plus thin native adapters — recommended

```text
plugins/research-spike/
├── skills/research-spike/SKILL.md       # one workflow source of truth
├── .claude-plugin/plugin.json           # Claude metadata only
└── .codex-plugin/plugin.json            # Codex metadata only

.claude-plugin/marketplace.json          # Claude catalog → same directory
.agents/plugins/marketplace.json          # Codex catalog → same directory
```

Pros: preserves native marketplace UX, needs no build step, and prevents skill drift. Cons: name, description, and version appear in a few small metadata files.

### 2. Generate manifests and catalogs from canonical metadata

Pros: eliminates hand-maintained metadata drift. Cons: adds a build/release contract and is disproportionate for the current two-plugin repository. Add it only once maintaining adapters becomes demonstrably error-prone.

### 3. Adopt the Agent Plugins v1 root specification now

Pros: a clean future-facing portability layer. Cons: the hosts’ documented native installation contracts still use their respective manifest locations. Do not make it the immediate distribution mechanism.

## What to copy

- The `orchestrate` split between portable content and only genuinely native adapters.
- Codex’s native manifest/catalog for distribution, while preserving the one shared skills directory.
- Explicit semantic versions, but enforce their equality across the two manifests and catalogs.

## What to avoid

- Copying or templating `SKILL.md` into a `codex/` subtree.
- Putting host-specific behavioral instructions into the shared workflow.
- Relying on symlinks to an external canonical skill after packaging.
- Introducing a generator before it saves more maintenance than it costs.

## Recommended product stance

Implement option 1 for `research-spike`: retain the plugin’s current directory as canonical, add a native Codex manifest and catalog pointing to it, and revise documentation to show both installation paths. Add a lightweight consistency check for shared `name`, `description`, and `version` once the initial adapter exists. Only platform-native assets—such as `orchestrate`’s Codex agent TOML files—belong in a dedicated adapter subtree.

One outlier was excluded: OpenAI’s API documentation also calls a separate hosted API resource “Skills.” It is not the Codex local-plugin packaging model and should not guide this repository decision.

## Open questions to test

1. Is the desired Codex audience repository/personal marketplace users, or public-directory users as well?
2. Does the intended Codex surface benefit from optional `agents/openai.yaml` UI metadata?
3. Should a small validation script be added now, or after another plugin adopts the dual-manifest layout?

## Files in this spike

- [Brief](brief.md)
- [Codex distribution](findings/codex-distribution.md)
- [Claude distribution](findings/claude-distribution.md)
- [Cross-harness patterns](findings/cross-harness-patterns.md)
- [Decision framework](findings/decision-framework.md)
- [Sources](sources.md)
