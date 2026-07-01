# next-slice

Closes out a just-finished implementation slice and hands the next one off to a fresh session — gated, re-anchored, and self-contained.

> The plan goes stale the moment you edit the code. This captures what you learned before the session ends.

## What it does

You run it at a slice boundary, as the agent that just finished implementing slice N of a sliced plan (a [to-plan](../to-plan/README.md) / [plan-clash](../plan-clash/README.md) plan, or any plan split into session-sized slices). It:

1. **Gates that the slice actually landed** — clean tree, the project's own build/test command green, committed — and refuses to hand off if not.
2. **Pre-mortems the next slice** — mines what the implementation revealed that the plan's author couldn't know: broken assumptions, deferred dependencies, competing constraints, invariants you touched.
3. **Re-anchors the plan** — greps every `file:line` and symbol the next slice cites and rewrites them to current reality, flagging anything that no longer exists.
4. **Diffs the seam** — the exact interfaces this slice exposed that the next one consumes (endpoints, props, env vars, migrations, response shapes).
5. **Records durable findings back into the plan** — append-only, never rewriting existing prose.
6. **Emits a command-first handoff prompt** you paste into a fresh session, then verdicts go / no-go.

## Why

The biggest loss in multi-session agent work is that the implementing agent finishes each slice holding context the plan never captured — and it evaporates when the session ends. The next agent then trusts a plan that has already drifted: wrong line numbers, an assumption that broke, a seam that changed shape. This skill converts that throwaway context into a durable handoff, and re-anchors the plan against the real code so the next session starts from reality instead of a stale spec.

It is deliberately narrow. It **never re-plans** (that's [to-plan](../to-plan/README.md)) and **never writes your always-loaded guidance file** (`CLAUDE.md` / `AGENTS.md`) — durable slice knowledge lives in the plan, which is read on demand, not in the file taxed on every request.

## Sample sessions

The output scales to how much the plan drifted, and the skill will refuse to hand off rather than pass a blocker forward. Three worked sessions:

| Scenario | Example |
| --- | --- |
| **Trivial** — slice landed exactly as planned; sections collapse, handoff is a short pointer | [examples/trivial-slice-handoff.md](examples/trivial-slice-handoff.md) |
| **Standard** — a broken assumption, a moved helper, a seam the next slice consumes; full ceremony + field notes | [examples/standard-slice-handoff.md](examples/standard-slice-handoff.md) |
| **Blocked** — the landed-state gate (§2) and the verdict (§6) each refuse to hand off | [examples/blocked-handoff.md](examples/blocked-handoff.md) |

## Compatibility

| Agent | Auto-invoke | Explicit invoke | Notes |
| --- | --- | --- | --- |
| Claude Code | Disabled | `/next-slice` | `disable-model-invocation: true` honored |
| Claude.ai | Disabled | menu / mention | Same |
| Codex CLI | Possible | `$next-slice` | Disable field not honored; description tuned to user-driven phrases |
| Copilot (VS Code) | Disabled | `/next-slice` | Disable field honored |
| Gemini CLI | Varies | per docs | Unknown field ignored; falls back to description match |
| Cursor | Dynamic (description-based) | mention in prompt | Place skill folder in `.cursor/skills/`; `disable-model-invocation` not honored — agent loads skills when it deems them relevant |

> [!NOTE]
> This skill is intentionally user-invoked — you run it at a slice boundary, not mid-task. It performs one narrow, high-value handoff and stops; it does not edit code, commit, deploy, or re-plan.

## Install

**GitHub CLI (recommended):**

```sh
gh skill preview bitcoin21ideas/skills next-slice   # inspect
gh skill install bitcoin21ideas/skills next-slice   # install
```

**Ask your agent** — point it at this folder; `next-slice` installs as-is, no tailoring:

> I like this skill — add it to my project:
> https://github.com/bitcoin21ideas/skills/tree/main/skills/next-slice

**By hand** — see the [repo-level README](../../README.md#install) for per-agent paths.

## Pairs with

- **[to-plan](../to-plan/README.md)** — produces the sliced plan this skill hands off between. `next-slice` re-anchors that plan's references and appends field notes to it, but never re-plans it.
- **[plan-clash](../plan-clash/README.md)** — hardens the plan before you build. Run it once, up front; run `next-slice` at every slice boundary after.

The full loop: `pressure-test` → `to-plan` → `plan-clash` → **[build slice]** → `next-slice` → **[build slice]** → `next-slice` → …

## Changelog

- **1.0.0** — Initial release. Landed-state gate, forward-framed pre-mortem, mechanical re-anchoring, seam diff, append-only plan field notes, command-first self-contained handoff prompt, and an explicit go/no-go verdict. Read-only toward the always-loaded guidance file.
