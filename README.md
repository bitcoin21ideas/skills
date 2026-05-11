# skills

[![License](https://img.shields.io/badge/License-MIT-1f6feb?style=for-the-badge)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-1f6feb?style=for-the-badge)](skills/pressure-test/SKILL.md)
[![Zap me a coffee](https://img.shields.io/badge/Zap_me_a_coffee-⚡-orange?style=for-the-badge)](https://zapmeacoffee.com/npub10awzknjg5r5lajnr53438ndcyjylgqsrnrtq5grs495v42qc6awsj45ys7)

A collection of agent skills for Claude Code, Codex, Copilot, and other AI coding assistants.

> [!NOTE]
> These skills are designed to be useful across agents. Unknown frontmatter fields (like `disable-model-invocation`) are ignored per the agentskills.io standard, so Claude-Code-specific fields are safe to include in any compliant agent.

## Skills

| Skill | Description |
| --- | --- |
| [pressure-test](skills/pressure-test/README.md) | Interviews you relentlessly about a plan, branch by branch, and ends with a consolidated decision artifact. |
| new skills to come | More skills are planned to populate this repo. Keep an eye out. | 

## Install

```sh
git clone https://github.com/bitcoin21ideas/skills.git
```

### Claude Code

```sh
# User-level (available in all projects)
ln -s "$PWD/skills/skills/pressure-test" ~/.claude/skills/pressure-test

# Project-level
ln -s "$PWD/skills/skills/pressure-test" .claude/skills/pressure-test
```

Then invoke with `/pressure-test` in the Claude Code prompt.

### Codex CLI

```sh
ln -s "$PWD/skills/skills/pressure-test" ~/.codex/skills/pressure-test
```

Invoke with `$pressure-test` or let Codex auto-select based on the description.

### VS Code (Copilot)

Place the `skills/pressure-test` folder in your workspace at `.github/skills/pressure-test`, or in your user-level skills directory per Copilot's documentation.

### Cursor

```sh
# Project-level
cp -r "$PWD/skills/skills/pressure-test" .cursor/skills/pressure-test
```

Reload the workspace. Cursor loads skills dynamically based on relevance — `disable-model-invocation` is not honored. For explicit-only control, place the folder outside `.cursor/skills/` (e.g. `.cursor/pressure-test/`) and `@`-mention `SKILL.md` in chat when needed. See the [per-skill README](skills/pressure-test/README.md) for details.

## Cross-agent compatibility note

The `disable-model-invocation: true` frontmatter field prevents Claude Code and Copilot from auto-invoking skills based on the description — the user must call them explicitly. Agents that don't recognize the field ignore it safely, falling back to description-based triggering. Skill descriptions in this repo are phrased with explicit user-action triggers ("when the user says...") to minimize spurious auto-invocations even in those agents.

## License

MIT — see [LICENSE](LICENSE).

Issues welcome. PRs at my discretion.
