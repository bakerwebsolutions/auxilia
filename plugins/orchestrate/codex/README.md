# Codex adapter

Copy `agents/*.toml` into the consuming repository's `.codex/agents/` directory (or into
`~/.codex/agents/` for a user-wide installation). Codex loads those as custom subagent
types; they inherit the parent session's sandbox and tools unless their TOML says otherwise.

When the router skill is installed for Codex, use this package's `orchestrate.config.json`
as the base config. Leave `harness: "auto"` to choose the Codex profile from the available
`spawn_agent` capability. The router must validate its configured model against the model
choices advertised in the active session before sending it to `spawn_agent`. If a model is
not offered, it omits the override and lets Codex inherit its configured default.

The shipped profile expresses a policy, not an availability claim:

- orchestrator: `gpt-5.6-sol`
- builder: `gpt-5.6-terra`
- scout: `gpt-5.6-luna`

Senior nodes (hard work-graph nodes) reuse `implementer` with the model overridden at spawn
time. With no `senior` entry in the profile, that is the profile's top tier (`gpt-5.6-sol`);
set `harnessProfiles.codex.roles.senior` to pick a different step up from Terra.

Large-build leads (`workflows/large-build.md`) spawn their own builders, which needs nested
`spawn_agent`. If the session's agent depth limit doesn't allow it, the recipe runs leads as
planning leads and the manager spawns the builders they name.

Override `harnessProfiles.codex` or individual `roles` in a project config only after
confirming the model is available in that Codex runtime.

`gpt-6-astra` is the explicit top-tier override: “use Astra to orchestrate” (or
`roles.orchestrator: "gpt-6-astra"`) promotes the orchestration and adversarial-judging
role for that run, just as “use Fable to orchestrate” does on Claude. It does not retier
builders or scouts.
