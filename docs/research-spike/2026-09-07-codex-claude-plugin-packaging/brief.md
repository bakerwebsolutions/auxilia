# Research brief: Codex + Claude plugin packaging

## Question

How should Auxilia package the `research-spike` plugin for Codex and Claude Code without maintaining needless duplicate source material or confusing marketplace-specific installation paths?

## Product anchors

- Auxilia is presently a Claude Code plugin marketplace with independently versioned plugins.
- `research-spike` currently contains one harness-neutral `SKILL.md` and no native Claude agents, hooks, or configuration.
- `orchestrate` added a Codex adapter tree because Codex needs native TOML agent definitions while Claude Code uses Markdown agents and plugin hooks.
- The desired outcome is a low-maintenance, discoverable installation experience for both harnesses, without copying content merely for distribution.

## Workstreams

1. Codex’s official skill discovery, installation, and any marketplace/distribution model.
2. Claude Code’s official plugin and marketplace packaging model.
3. Proven cross-harness packaging patterns: shared source, thin adapters, and release/build generation.
4. Maintenance, versioning, and UX tradeoffs, ending in a repo-specific recommendation.

## Shared reporting frame

- user / job to be done
- products or sources reviewed
- core distribution and interaction model
- packaging and versioning implications
- duplication risks and mitigations
- implications for Auxilia
- open questions
- sources (URLs)
