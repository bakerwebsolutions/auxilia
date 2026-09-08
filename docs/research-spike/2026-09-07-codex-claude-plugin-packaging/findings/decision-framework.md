# Decision framework

## Options

1. Share the plugin’s skills directory and add thin Codex/Claude manifests and catalogs.
2. Generate both sets of metadata from a canonical project-level definition.
3. Package two independently maintained plugins.

## Decision criteria

- One authoritative workflow body.
- Native install and update behavior on both hosts.
- No packaged dependency outside a plugin root.
- Low release complexity at the repository’s current size.
- A clear upgrade path if adapter metadata becomes burdensome.

## Recommended stance

Choose option 1 now. It satisfies all criteria: the substantive workflow remains a single standard skill while the unavoidable host-specific parts are tiny. Option 2 becomes worthwhile when enough plugins make repeated metadata synchronization a measurable maintenance burden. Reject option 3 because it creates behavioral drift without gaining installation capability.

## Migration and versioning considerations

Make `name`, `description`, and `version` equal in host manifests and their catalog entries. Keep the current explicit release version strategy, then add a small comparison check when the Codex adapter lands. This is an inference from both hosts’ documented native manifests and update behavior, not a new external packaging requirement.

## Sources

- [OpenAI plugin packaging](https://developers.openai.com/plugins/build/plugins)
- [Anthropic plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)
- [Agent Skills specification](https://agentskills.io/specification)
