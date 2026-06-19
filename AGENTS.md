# AGENTS.md

Guidance for AI coding agents (Codex, Claude Code, Cursor, Copilot, Gemini, and others) working **in this repository**. This is a distribution repo for reusable agent skills — there is no application to build or run. Most contributions add or edit a skill.

For human-facing usage and install instructions, see [`README.md`](./README.md).

## Repository layout

```
skills/<name>/
  SKILL.md      # required — the skill itself (the agent-facing instructions)
  README.md     # required — human-facing overview, install, examples
  examples/     # optional — sample sessions or supporting docs
```

Each skill is a self-contained folder under `skills/`. Keep skills independent — a user should be able to take one folder without the rest.

## Skill conventions

- **`SKILL.md` frontmatter** uses YAML with:
  - `name` — kebab-case, matches the folder name (this is the invocation name, e.g. `/commit`).
  - `description` — what the skill does and *when to use it*. Phrase triggers as explicit user actions ("when the user says…", "run when the user asks to…") so cross-agent harnesses don't auto-fire it spuriously.
  - `disable-model-invocation: true` — set this for explicit-only skills (e.g. `pressure-test`); omit it for skills that should also auto-trigger from natural-language intent (e.g. `commit`, which still waits for plan approval before committing). Claude Code and Copilot honor the field; agents that don't recognize it ignore it safely and fall back to description matching.
  - `metadata:` block holding `version` (semver string), `author`, and `source` if adapted from someone else's work. Use this nested block, not top-level keys.
- **Cross-agent first.** Unknown frontmatter fields are ignored per the agentskills.io standard, so Claude-specific fields are safe. Don't write a skill that only works in one agent unless it's inherently agent-specific.
- **Progressive disclosure.** Keep `SKILL.md` focused; move long or rarely-needed detail into sibling files (e.g. `tailoring.md`, `examples/`) that the agent loads only when relevant.
- **Every promoted skill must be listed in the root [`README.md`](./README.md) skills table**, with the name linked to its per-skill `README.md`.

## Contributing

This repo is agent-first: the easiest way to add or fix a skill is to ask your coding agent. Point it at this file, describe the change ("read AGENTS.md and add a skill that …"), let it follow the conventions above, then have it open a PR. Contributions are welcome from any agent or by hand.

A skill contribution should:

- Live in a self-contained `skills/<name>/` folder with `SKILL.md` + `README.md` (per the layout above).
- Use cross-agent frontmatter and appear in the root [`README.md`](./README.md) skills table.
- Be committed using this repo's [`commit`](./skills/commit/README.md) skill, which owns the message conventions.
