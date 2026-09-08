# Claude Code distribution

## User / job to be done

Keep Claude Code installation and upgrade behavior working while sharing plugin content with Codex.

## Sources reviewed

- [Create plugins](https://code.claude.com/docs/en/plugins)
- [Create and distribute a plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces)
- [Discover and install prebuilt plugins](https://code.claude.com/docs/en/discover-plugins)
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference)

## Core distribution model

Claude Code plugins are self-contained directories with `.claude-plugin/plugin.json` and sibling component directories such as `skills/`. A `.claude-plugin/marketplace.json` catalog can point at a relative path in the same repository, a Git source, an archive, or other supported sources.

## Packaging and versioning implications

Plugin versions drive update detection. Claude caches installed packages, so a plugin must not rely on symlinked or relative files outside its package directory. Its marketplace is a distribution catalog, not the authoritative location for shared workflow content.

## Implications for Auxilia

The existing plugin directory is already a viable shared package root. Keep Claude’s manifest and catalog, but treat them as Claude-specific delivery metadata. A second manifest does not imply a second implementation.

## Open questions

- Whether explicit versions should remain the release contract or each catalog should resolve Git commits.
- Whether catalog metadata should be generated once the repository has more plugins.
