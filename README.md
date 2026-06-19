# skills

[![License](https://img.shields.io/badge/License-MIT-1f6feb?style=for-the-badge)](LICENSE)
[![Release](https://img.shields.io/github/v/release/bitcoin21ideas/skills?style=for-the-badge&label=Release&color=1f6feb)](https://github.com/bitcoin21ideas/skills/releases/latest)
[![Zap me a coffee](https://img.shields.io/badge/Zap_me_a_coffee-⚡-orange?style=for-the-badge)](https://zapmeacoffee.com/npub10awzknjg5r5lajnr53438ndcyjylgqsrnrtq5grs495v42qc6awsj45ys7)

A collection of agent skills for Claude Code, Codex, Copilot, and other AI coding assistants.

> [!NOTE]  
> These skills are designed to be useful across agents. Unknown frontmatter fields (like `disable-model-invocation`) are ignored per the agentskills.io standard, so Claude-Code-specific fields are safe to include in any compliant agent.

## Skills

| Skill | Description |
| --- | --- |
| [pressure-test](skills/pressure-test/README.md) | Interviews you relentlessly about a plan, branch by branch, and ends with a consolidated decision artifact. |
| [commit](skills/commit/README.md) | Project-agnostic git commit workflow — triages secrets, runs the project's test/lint gate, groups changes, and writes conventional commits after you approve. Tailorable per project. |

## Install

> [!IMPORTANT]
> A skill is instructions your agent runs on your behalf — anyone can publish one, and GitHub doesn't verify them. Inspect before you install: `gh skill preview bitcoin21ideas/skills <name>`, or read the skill's `SKILL.md` on GitHub. The skills here are MIT-licensed and meant to be auditable; apply the same caution to skills from anywhere.

Three ways, easiest first: the **GitHub CLI** (one command, cross-agent), **ask your agent**, or **by hand**.

### GitHub CLI — `gh skill` (recommended)

[`gh skill`](https://github.blog/changelog/2026-04-16-manage-agent-skills-with-github-cli/) (GitHub CLI ≥ 2.90.0) installs a skill into whichever agent you use — Claude Code, Copilot, Cursor, Codex, or Gemini CLI — resolving the right location for you and recording where it came from:

```sh
gh skill preview bitcoin21ideas/skills pressure-test   # inspect first
gh skill install bitcoin21ideas/skills pressure-test   # then install
```

Swap `pressure-test` for any skill in the table above.

### Ask your agent

No CLI? Hand your agent the skill's folder URL and ask it to install:

> I like this skill — install it in my project:
> https://github.com/bitcoin21ideas/skills/tree/main/skills/pressure-test

This needs an agent that can fetch a URL — **Claude Code** and **Gemini CLI** do by default; **Cursor** and **Copilot** may need web access turned on; **Codex CLI** needs a fetch tool (MCP) wired up. Tell it two things: a skill is a multi-file *folder* (not one file), and read the **raw** files (`raw.githubusercontent.com`), not the rendered `blob` page. On a model with no skills runtime (a bare Kimi / OpenAI-compatible endpoint), just paste `SKILL.md` into your system prompt.

### By hand

```sh
git clone https://github.com/bitcoin21ideas/skills.git
cd skills
```

Drop a skill folder where your agent looks. `.agents/skills/` is the vendor-neutral location honored by Codex, Cursor, Gemini, and Copilot:

```sh
ln -s "$PWD/skills/pressure-test" .agents/skills/pressure-test      # project-level
ln -s "$PWD/skills/pressure-test" ~/.agents/skills/pressure-test    # user-level
```

Prefer an agent-specific home?

| Agent | Project path | User path | Invoke |
| --- | --- | --- | --- |
| Claude Code | `.claude/skills/` | `~/.claude/skills/` | `/pressure-test` |
| Codex CLI | `.agents/skills/` | `~/.agents/skills/` | `$pressure-test` |
| Cursor | `.cursor/skills/` | `~/.cursor/skills/` | `/` menu |
| Copilot (VS Code) | `.github/skills/` | `~/.copilot/skills/` | `/pressure-test` |
| Gemini CLI | `.gemini/skills/` | `~/.gemini/skills/` | `/skills` |

Most agents also auto-load a skill when its description matches, so explicit invocation is optional.

## Cross-agent compatibility note

As of June 2026 the [Agent Skills standard](https://agentskills.io) is natively supported across the major coding agents (Claude Code, Codex, Cursor, Copilot, Gemini CLI, and dozens more), so these skills are portable without per-agent rewrites.

The `disable-model-invocation: true` frontmatter field prevents Claude Code and Copilot from auto-invoking a skill based on its description — the user must call it explicitly. Agents that don't recognize the field ignore it safely, falling back to description-based triggering.

Invocation mode is chosen per skill:

- **`pressure-test`** is explicit-only (`disable-model-invocation: true`) — you rarely want to be auto-grilled.
- **`commit`** is both user- and model-invocable (no such field) — natural-language requests like "commit this" can trigger it, and it always proposes a plan and waits for approval before committing, so the model can never make a surprise commit.

Either way, skill descriptions are phrased with explicit user-action triggers ("when the user says...") so even agents that ignore the field don't fire them spuriously.

## Contributing

This repo is agent-first. The easiest way to add or fix a skill is to ask your coding agent: point it at [`AGENTS.md`](AGENTS.md), describe the change, and have it open a PR. See [`AGENTS.md`](AGENTS.md) for the layout and conventions. Issues and PRs welcome — from an agent or by hand.

## License

MIT — see [LICENSE](LICENSE).

> _Commits in this repo are made with its own [`commit`](skills/commit/README.md) skill._
