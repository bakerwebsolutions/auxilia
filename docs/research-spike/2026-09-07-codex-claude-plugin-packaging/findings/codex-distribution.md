# Codex distribution

## User / job to be done

Ship one skills-based plugin to Codex without copying its workflow merely to make it discoverable and installable.

## Sources reviewed

- [Build plugins](https://learn.chatgpt.com/docs/build-plugins)
- [Package your plugin](https://developers.openai.com/plugins/build/plugins)
- [Plugin architecture](https://developers.openai.com/plugins/concepts/plugins)
- [Build skills](https://learn.chatgpt.com/docs/build-skills)
- [Submit your Claude Code plugin to OpenAI](https://developers.openai.com/plugins/guides/submit-claude-plugin)

## Core distribution model

Codex has a native plugin package: a skills-only package contains a `.codex-plugin/plugin.json` manifest and `skills/<name>/SKILL.md`. OpenAI documents repository and personal marketplace catalogs for private or development distribution, plus a public directory shared by ChatGPT and Codex. The Claude-plugin submission guide also describes converting a Claude skills-only package while preserving its skills.

## Packaging and versioning implications

Codex uses an explicit manifest version; a marketplace can use Git refs/SHAs or npm versions. This permits a Codex catalog to reference the same plugin directory that Claude’s catalog references. It does not require a second `SKILL.md`.

## Implications for Auxilia

The appropriate Codex addition for `research-spike` is a thin `.codex-plugin/plugin.json` adjacent to the existing `.claude-plugin/plugin.json`, plus a Codex marketplace catalog if repository/personal marketplace installation is the intended path. The canonical workflow remains `skills/research-spike/SKILL.md`.

## Open questions

- Whether the intended audience is Codex CLI/IDE, ChatGPT desktop, or public-directory users.
- Whether the repository needs only a Codex catalog, or eventual public-directory submission.
