# auxilia

Reusable [Claude Code](https://claude.ai/code) skills, packaged as an installable
**plugin marketplace**. Add the marketplace once, then install any plugin below —
on any machine.

## Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| [research-spike](plugins/research-spike/README.md) | Fan out parallel web-research agents, synthesize findings, and save durable research artifacts | `1.0.0` |
| [orchestrate](plugins/orchestrate/README.md) | Task router — detect the task type and run a pre-curated, model-tiered workflow (research · design · implement · debug · review · optimize): shared prelude → parallel fan-out (Sonnet builds, Haiku scouts) → converge; Opus orchestrates, swappable to Fable | `2.0.0` |

## Install

In Claude Code, add this repo as a marketplace, then install a plugin from it:

```
/plugin marketplace add bakerwebsolutions/auxilia
/plugin install research-spike@auxilia
```

Codex users can add the repository’s `.codex-plugin/marketplace.json` catalog
and install either plugin from the same canonical directories.

`bakerwebsolutions/auxilia` is the GitHub `owner/repo`; `auxilia` (after the `@`)
is the marketplace name. Browse and manage everything interactively with:

```
/plugin
```

### Updating

When a plugin's version is bumped here, pull the latest into Claude Code:

```
/plugin marketplace update auxilia
```

## Versioning

Each plugin is versioned independently with [semantic versioning](https://semver.org).
The version lives in two places that must stay in sync:

- `plugins/<name>/.claude-plugin/plugin.json` → `version`
- the plugin's entry in `.claude-plugin/marketplace.json` → `version`

Bump both (and the version shown in the table above and the plugin's README) when
you change a plugin. Users only receive updates when the version changes.

The same identity metadata is repeated in each host's native adapter and
catalog. Run the lightweight consistency check before publishing changes:

```
python3 scripts/validate-plugin-metadata.py
```

It checks every Claude manifest, any matching Codex manifest, and either
supported Codex catalog location. Host-specific fields are intentionally left
to each platform.

## Repository layout

```
auxilia/
├── .claude-plugin/
│   └── marketplace.json          # marketplace manifest (lists all plugins)
├── plugins/
│   └── research-spike/
│       ├── .claude-plugin/
│       │   └── plugin.json        # plugin manifest (name, version, …)
│       ├── skills/
│       │   └── research-spike/
│       │       └── SKILL.md       # the skill itself
│       └── README.md
└── README.md
```

## Adding a plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json` with `name`, `description`, `version`.
2. Add the skill(s) under `plugins/<name>/skills/<skill-name>/SKILL.md`.
3. Add a `plugins/<name>/README.md`.
4. Append the plugin to the `plugins` array in `.claude-plugin/marketplace.json`.
5. Add a row to the table above.
