# copywriter

**Version:** 1.0.0

Write customer-facing copy that reads like the business wrote it. Generated copy
sounds generated because the model has no facts or voice to work from, so this plugin
fixes the inputs before it drafts:

1. builds a fact sheet from the repo and asks once for what's missing,
2. uses a voice sample (call transcript, owner's emails) when there is one,
3. drafts with `[PLACEHOLDERS]` instead of filler,
4. checks title, meta and H1 against the ad or search intent,
5. hands the draft to a fresh-context `copy-reviewer` for AI tells and unsupported claims.

## Install

```
/plugin marketplace add bakerwebsolutions/auxilia
/plugin install copywriter@auxilia
```

## Use

```
/copywriter rewrite the copy on pages/service-areas/missouri.vue
```

Or run the reviewer alone on existing copy by asking for the `copy-reviewer` agent.

The procedure lives in [`skills/copywriter/SKILL.md`](skills/copywriter/SKILL.md); the
pattern list both halves share is
[`skills/copywriter/references/ai-tells.md`](skills/copywriter/references/ai-tells.md).
