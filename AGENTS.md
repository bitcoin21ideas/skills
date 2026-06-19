# AGENTS.md

Guidance for AI coding agents (Codex, Claude Code, Cursor, Copilot, Gemini, and others) working **in this repository**. This is a distribution repo for reusable agent skills — there is no application to build or run. Most contributions add or edit a skill.

For human-facing usage and install instructions, see [`README.md`](./README.md).

## Repository layout

```
skills/<name>/
  SKILL.md      # required — the skill itself (the agent-facing instructions)
  README.md     # required — human-facing overview, install, examples
  examples/     # optional — sample sessions or supporting docs
.claude-plugin/ # optional — plugin manifest (not present yet)
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

## Commit conventions

- Commits in this repo are made with its own [`commit`](./skills/commit/README.md) skill: conventional-commit messages, logical grouping, approval before committing.
- `type(scope): lowercase imperative subject`, no trailing period.
- **No em dashes** in commit messages. **Never** add a `Co-Authored-By` trailer or mention Claude, Anthropic, or any AI agent in a commit message.
- Never use `--no-verify` or bypass hooks.

## What not to commit

- Personal/local config: `.claude/settings.local.json`, `CLAUDE.local.md`.
- OS cruft: `.DS_Store`.
- See [`.gitignore`](./.gitignore).
