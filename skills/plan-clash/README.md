# plan-clash

Harden an existing implementation plan by running it through a fixed number of
**cross-model critique→fold rounds**. A GPT model (via the `codex` CLI) plays the
adversarial critic; a Claude model (via the `claude` CLI) plays the adjudicator that
rules on each finding and folds the accepted fixes into a copy of the plan.

Two models with disjoint blind spots, fresh and stateless each round. The loop
**improves** a plan; it deliberately does **not certify** one. There is no pass/fail,
no green light, no stop condition — the human is the only judge of "good enough".

```
critic (codex / GPT)  ──finds──▶  adjudicator (claude / opus)  ──rules + folds──▶  plan-vN
        ▲                                                                              │
        └───────────────────────── next round reviews plan-vN ◀────────────────────────┘
```

## Install

**GitHub CLI (recommended)** — installs into whichever agent you use:

```sh
gh skill preview bitcoin21ideas/skills plan-clash   # inspect
gh skill install bitcoin21ideas/skills plan-clash   # install
```

**Ask your agent** — point it at this folder:

> I like this skill — add it to my project:
> https://github.com/bitcoin21ideas/skills/tree/main/skills/plan-clash

This is a **multi-file** skill — `run.sh`, `prompts/`, and `schemas/` come along with `SKILL.md`, and `run.sh` must stay executable. `gh skill install` handles that for you; if you copy by hand, copy the whole folder.

**By hand** — see the [repo-level README](../../README.md#install) for per-agent paths.

> The skill itself is just orchestration — it shells out to the `codex` and `claude` CLIs. See [Prerequisites](#prerequisites) for what must already be installed and logged in before a run will work.

## Prerequisites

- **codex CLI**, installed and logged in (ChatGPT subscription). If it isn't on your
  `PATH`, the script also looks at `$CODEX_BIN`, the macOS app bundle
  (`/Applications/Codex.app/Contents/Resources/codex`), and VS Code / Cursor extension
  paths. Set `CODEX_BIN=/path/to/codex` to be explicit.
- **Claude Code (`claude`)**, installed and logged in (Max/Pro subscription).
- **jq**, **git**, **openssl** on `PATH`.
- The **code_root must be inside a git repo** (it may be a subdirectory of one) — the script
  asserts the code_root subtree is left byte-identical after every adjudicator call, and that
  assertion uses git.

Children run with `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` unset, so they bill the CLI
**subscriptions**, not the metered API.

## Usage

```sh
./run.sh [options] <plan.md> <code_root>
```

| Option | Default | Meaning |
|---|---|---|
| `--rounds N` | `2` | number of critique→fold rounds |
| `--source-context DIR` | none | extra read-only dir of source docs (specs, API snapshots) the critic/adjudicator may consult |
| `--out FILE` | `<plan-dir>/<stem>.hardened.md` | where to write the hardened plan |

Env overrides: `CODEX_BIN`, `CLAUDE_BIN`, `CODEX_EFFORT` (default `xhigh`),
`ADJ_MODEL` (default `opus`), `ADJ_EFFORT` (default `xhigh`), `RETAIN_DAYS` (default `7`).

### Example

```sh
./run.sh ~/plans/ab-harness.md ~/code/my-service
# → hardened plan: ~/plans/ab-harness.hardened.md
# → full trail:    ~/.plan-clash/runs/2026-06-23-…-ab-harness/
```

## Outputs

The **hardened plan** is written next to the input as `<stem>.hardened.md` (the original
is never touched). Everything else lands in a per-run directory under
`~/.plan-clash/runs/` — never inside your repo:

- `plan-v0.md … plan-vN.md` — the original copy and each round's result
- `review-1.json … review-N.json`, `final-review.json` — critic output per round
- `decisions-1.json … decisions-N.json` — adjudicator rulings per round
- `decision-log.md` — the per-finding trail (the real product)
- `RESULT.md` — trajectory table, residual concerns, cost/wall-clock
- `prompts/`, `raw/` — assembled prompts and raw CLI logs

Run dirs older than `RETAIN_DAYS` (default 7) are pruned automatically at the start of
the next run. Nothing is ever auto-deleted from the current run.

## Safety model

- **Read-only by assertion.** The adjudicator gets `--add-dir <code_root>` (read access to the
  code) but the script snapshots a content-level `git` fingerprint of the **code_root subtree**
  before each call — HEAD, porcelain status, a hash of the working-tree/staged diff, and hashes
  of untracked files — and aborts if anything changed, so even an in-place edit of an
  already-dirty file is caught. The fingerprint is scoped to code_root, so concurrent edits
  elsewhere in an enclosing repo don't false-abort. It does **not** auto-restore — your
  uncommitted work is never clobbered.
- **Data-fencing.** The plan and the critic findings are passed inside an `UNTRUSTED`
  fence with a per-run nonce; the workers treat fenced bytes as data and raise any embedded
  steering as a finding rather than obeying it.
- **Coverage, fold, and size checks.** Each round, the script verifies the adjudicator ruled on
  every finding exactly once (a bijection), never rewrote its own input review, gave every ruling
  a reason, actually landed the edits it claimed (a claimed fold that leaves the plan byte-identical
  aborts), and didn't shrink the plan by more than 40% (a truncation / off-spec-rewrite tripwire).
  Any failure aborts the run.

## Scope (current)

Wired for a single setup: codex/GPT critic + claude/opus adjudicator, both on subscription
auth. Model, effort, and auth choices live in the config block at the top of `run.sh`.
API-key auth and arbitrary model pairings are a future extension over the same loop.

**Validation status — plan size.** This flow has been validated end-to-end on regular-sized
plans (tens of KB) and behaves well there. Very large plans (**100KB+**) are not yet exercised.
The plan moves through the adjudicator as `Edit`/`Write` tool calls rather than one big model
response, so truncation is unlikely *by design* — but it's unproven at that scale. Keep plans
reasonably sized for now; if you harden a very large one, give the hardened result a
closer-than-usual read before trusting it. This is a known limitation, not a warning.

## Pairs with

- **[to-plan](../to-plan/README.md)** — produces the implementation plan that
  `plan-clash` hardens. Run `to-plan` before `plan-clash`.
- **[pressure-test](../pressure-test/README.md)** — the upstream interrogation skill.
  `pressure-test` → `to-plan` → `plan-clash` is the full pipeline.
