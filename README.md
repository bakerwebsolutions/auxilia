# auxilia

Reusable [Claude Code](https://claude.ai/code) skills, packaged as an installable
**plugin marketplace**. Add the marketplace once, then install any plugin below —
on any machine.

## Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| [research-spike](plugins/research-spike/README.md) | Fan out parallel web-research agents, synthesize findings, and save durable research artifacts | `1.0.0` |

## Install

In Claude Code, add this repo as a marketplace, then install a plugin from it:

```
/plugin marketplace add bakerwebsolutions/auxilia
/plugin install research-spike@auxilia
```

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
