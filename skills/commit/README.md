# commit

A project-agnostic, multi-step git commit workflow — gathers state, keeps secrets out of history, runs the project's test/lint gate, groups changes into logical units, and writes clean conventional commits **after** you approve the plan. No `Co-Authored-By`, no AI attribution in messages, ever.

Both user- and model-invocable — call it explicitly with `/commit`, or let your agent start it when you express commit intent (e.g. "commit this"). It always proposes a plan and waits for your approval before committing, so model-invocation never means a surprise commit. To make it explicit-only, add `disable-model-invocation: true` to the frontmatter.

## What it does

1. Gathers `git status` / diffs / recent log in one pass.
2. Triages: nothing-to-commit, merge conflicts, secret-shaped content (scanned, never printed), sensitive files by name, and generated artifacts.
3. Respects what you've already staged.
4. Groups changes into logical commits.
5. **Runs the project's gate** (tests/lint/typecheck) and **stops on failure** — never `--no-verify`.
6. Proposes a commit plan and waits for your approval.
7. Executes with conventional messages, matching your repo's existing `git log` style.

## Use it as a generic skill

The bundled [`SKILL.md`](./SKILL.md) works on any repo as-is — it detects the gate (npm scripts, `make`, `cargo`, `pytest`, …) at runtime. Install it with `gh skill install bitcoin21ideas/skills commit` (or drop the folder into `.claude/skills/commit/`), then call `/commit`.

## Or tailor it to one project (recommended)

Each project has its own gate, scopes, and conventions. Instead of re-detecting them on every commit, you can have your agent bake them in **once** and install a lean, project-specific copy. You don't need to clone this repo — point your agent at the folder and ask:

> Look at the commit skill at
> `https://github.com/bitcoin21ideas/skills/tree/main/skills/commit`,
> tailor it to this project, and install it into my `.claude/skills/`.

The agent follows [`tailoring.md`](./tailoring.md): it fetches the template, detects this project's gate / scopes / commit style / sensitive paths, confirms with you, then writes a ready-to-use `.claude/skills/commit/SKILL.md` with the specifics hard-wired and the detection prose stripped. `tailoring.md` itself is never copied in — only the finished skill lands. If the project's tooling later changes, just re-run the same ask.

## Files

| File | Role |
| --- | --- |
| [`SKILL.md`](./SKILL.md) | The skill — generic template, also the thing that gets tailored |
| [`tailoring.md`](./tailoring.md) | Build-time playbook: detect a project's realities and install a tailored copy |

## Install

See the [repo-level README](../../README.md) for per-agent install paths, or use the tailoring ask above to have your agent place a copy directly.
