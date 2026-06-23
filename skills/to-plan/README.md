# to-plan

Turns a settled set of decisions into a **pure implementation plan** on disk — file
paths, modules, sequencing, and verification.
The output is shaped to be consumed immediately by [`plan-clash`](../plan-clash/README.md).

> Distilled decisions in, a plan-clash-ready artifact out.

## What it does

You hand it a decisions context. It reads the codebase, proposes the module boundaries, **pauses for your confirmation**, and then writes a single `./<slug>.plan.md`: overview, settled decisions, code orientation, architecture, ordered implementation slices (each one a session gate), end-to-end verification, and explicit out-of-scope and risk sections. It never interviews you and never writes code — the plan is the deliverable.

## Why

`plan-clash`'s critic verifies a plan against the real codebase and cites `file:line`
evidence. A plan written in prose — no named paths, no anchored tests — gives that
critic nothing falsifiable to check, so the hardening pass has little to bite on.
`to-plan` exists to produce the grounded, code-anchored artifact that makes the
hardening loop worth running: every path is real (or explicitly marked new), every
slice's "done when" is a test anchored to the repo's actual test pattern, and every
unverifiable external claim is flagged in the critic's own language so it doesn't
resurface as a surprise finding.

## Where it fits — the pipeline

```
pressure-test (elicit)  →  to-plan (synthesize)  →  plan-clash (harden)
```

- **[pressure-test](../pressure-test/README.md)** interrogates you branch by branch and
  (optionally) saves a `.decisions.md`.
- **to-plan** synthesizes those decisions plus a repo read into an implementation plan.
- **[plan-clash](../plan-clash/README.md)** adversarially hardens that plan against the
  real code.

You don't need the whole pipeline — `to-plan` works from any decisions context, however
you arrived at it.

## Input sources

`to-plan` is session-agnostic. It takes a decisions context from whichever of these is
available:

- **live conversation** — if `pressure-test` or a planning discussion just ran in this
  session;
- **a `.decisions.md` file** — pass the path (e.g. the file `pressure-test` saved);
- **pasted prose** — paste a plan or set of decisions directly.

If none is available, it asks you to describe the plan first.

## Output

A single Markdown file at `./<slug>.plan.md` with this structure:

| Section | Contents |
| --- | --- |
| 1. Overview | The user-visible behavior, and how to observe it. |
| 2. Settled decisions | Each decision + one-line rationale; deferred items labelled. |
| 3. Context & orientation | Existing modules, patterns, test layout, test command. |
| 4. Architecture | Modules/interfaces to build or modify, by path + symbol. |
| 5. Implementation slices | 2–6 ordered tracer bullets; **each slice is one session gate**. |
| 6. End-to-end verification | One check proving the whole feature works. |
| 7. Out of scope | Explicit negative boundaries. |
| 8. Risks & open questions | Known unknowns; unverifiable claims flagged. |
| 9. Idempotence & recovery | **Only** for destructive/migrational plans. |

The original decisions file, if you provided one, is never mutated.

## The confirmation gate

Before writing the plan, `to-plan` stops and shows you the module boundaries it intends
to build against — which modules, each interface (the test surface), and the integration
points — and asks: *"Do these module boundaries look right before I write the plan?"* A
wrong boundary would propagate into every slice and then into `plan-clash`'s critique, so
this one cheap confirmation is deliberate. It does not proceed until you confirm or
redirect.

## Install

**GitHub CLI (recommended)** — installs into whichever agent you use:

```sh
gh skill preview bitcoin21ideas/skills to-plan   # inspect
gh skill install bitcoin21ideas/skills to-plan   # install
```

**Ask your agent** — point it at this folder:

> I like this skill — add it to my project:
> https://github.com/bitcoin21ideas/skills/tree/main/skills/to-plan

**By hand** — see the [repo-level README](../../README.md#install) for per-agent paths.

## Pairs with

- **[pressure-test](../pressure-test/README.md)** — the upstream interrogation skill;
  feed its saved `.decisions.md` into `to-plan`.
- **[plan-clash](../plan-clash/README.md)** — hardens the plan `to-plan` produces. Run
  `to-plan` first, then `plan-clash`.

## Changelog

- **1.0.0** — Initial release. Synthesizes a decisions context + repo read into a
  code-anchored `./<slug>.plan.md`, with a module-boundary confirmation gate and
  phase-gated implementation slices sized for single-session execution.
