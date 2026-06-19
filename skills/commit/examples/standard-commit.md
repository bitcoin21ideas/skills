# Example: a standard multi-file commit

A working tree holding a feature change, an unrelated docs typo fix, and a stray
`.env` file. Shows triage (sensitive file excluded), logical grouping into two
commits, the gate, the proposed plan, and execution after approval.

## Starting state

```
$ git status --short
 M src/auth/login.ts
 M src/auth/session.ts
 M README.md
?? .env
```

## What the skill does

**Steps 1–2 — gather & triage.** Reads status, diffs, and recent `git log` in one
pass. Flags `.env` as a sensitive file *by name* → excluded by default; it is
never staged and its contents are never read or printed. The `README.md` edit is
a typo fix, unrelated to the auth work.

**Steps 3–4 — group.** The two `src/auth/` files are one concern (session refresh
wired into login); the README typo is separate. → **two commits**.

**Step 5 — gate.** Runs the project's detected gate once on the whole tree (e.g.
`npm run -s check`) and reports the result. Docs-only changes skip the gate.

**Step 6 — proposed plan** (waits for approval):

> Gate: `npm run -s check` passed (12 tests, 0 lint errors).
> `.env` excluded — sensitive, left untracked.
> 2 commits:
>
> 1. `feat(auth): refresh session on login`
>    — `src/auth/login.ts`, `src/auth/session.ts`
> 2. `docs: fix typo in setup steps`
>    — `README.md`
>
> Approve?

**Step 7 — execute** (only after you say yes): stages each commit's files
explicitly (`git add src/auth/login.ts src/auth/session.ts`), commits with a
HEREDOC message, then `git status` to verify. Never `git add -A`, never
`--no-verify`.
