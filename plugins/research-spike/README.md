# research-spike

**Version:** 1.0.0

Run a **stored, repeatable research spike** in any project:

1. anchors the research to the product,
2. tightens the scope into a few non-overlapping workstreams,
3. fans out parallel web research,
4. writes durable artifacts to `docs/research-spike/`.

Use it for competitor scans, UX pattern research, pricing/monetization analysis,
onboarding/retention studies, or market-gap exploration.

## Install

### Claude Code

```
/plugin marketplace add bakerwebsolutions/auxilia
/plugin install research-spike@auxilia
```

### Codex

Add the repository marketplace with the Codex CLI, then open the Plugins
Directory in the ChatGPT desktop app and install `research-spike` from the
`auxilia` marketplace:

```
codex plugin marketplace add bakerwebsolutions/auxilia
```

The plugin uses the same `skills/research-spike/SKILL.md` on both hosts; only
the host-specific manifests and marketplace metadata differ.

## Use

```
/research-spike <your research goal>
```

The full procedure lives in [`skills/research-spike/SKILL.md`](skills/research-spike/SKILL.md).

## Output

Each run creates or updates:

- `docs/research-spike/README.md` — index of all saved spikes
- `docs/research-spike/<date>-<slug>/README.md` — main synthesis
- `docs/research-spike/<date>-<slug>/brief.md` — research brief and workstream plan
- `docs/research-spike/<date>-<slug>/findings/*.md` — one file per workstream
- `docs/research-spike/<date>-<slug>/sources.md` — source inventory by workstream
