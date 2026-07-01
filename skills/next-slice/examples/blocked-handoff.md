# Blocked — When next-slice Refuses to Hand Off

The skill has two halt points. It **hands off or halts** — it never papers a blocker into a green prompt, and it never re-plans. Two scenarios show both refusals.

---

## Scenario A — the gate says stop (§2)

The implementer *thinks* Slice 2 is done. It isn't.

> User: `/next-slice` — key-issuance slice is done, hand off the middleware slice.

**Agent:** Running the landed-state gate before anything else.

### 2. Landed-state gate

- **Clean tree** — ❌ `git status` shows `src/auth/crypto.ts` modified and **uncommitted** (it still has a `console.log(rawKey)` debug line).
- **Green gate** — ❌ `npm test` → **1 failing:** `issues a key and stores only the hash` — the test sees a plaintext `key` column that shouldn't exist.
- **Committed** — ❌ the last commit is Slice 1; Slice 2's work is in the working tree, not in history.

**STOP.** Two of three gate conditions fail. I am not emitting a handoff — a handoff layered on uncommitted, red work would poison the next session. Handing back to you:

> **Slice 2 has not landed.** Before `/next-slice` can hand off:
> 1. Remove the `console.log(rawKey)` in `src/auth/crypto.ts:38` (it also leaks the raw key — a §3 invariant).
> 2. Fix `issues a key and stores only the hash` — persist `key_hash`, not the raw `key`.
> 3. Commit Slice 2 on `feat/api-keys`.
>
> Re-run `/next-slice` once `npm test` is green and the tree is clean. **No prompt emitted.**

*(No §3–§6. The gate is a hard gate: nothing downstream runs until the slice is actually landed.)*

---

## Scenario B — green gate, still no-go (§6)

Everything landed clean and green — but building the slice revealed that the *next* slice, as planned, can't be built atomically.

> User: `/next-slice` — issuance slice is committed and green. Hand off the middleware slice.

**Agent:** Gate passes cleanly (tree clean, `npm test` green, Slice 2 @ `a1b9f3c`). But §3 surfaced a structural problem — walking it before I decide the verdict.

### 3. Pre-mortem — the blocker

Slice 3's middleware must look up keys by `prefix`, then hash-compare (Slice 2 stores only `key_hash`). Safe lookup needs a **unique index on `key_hash`** to guarantee one match — but:

- No slice owns that index. Slice 1's migration shipped `api_keys` with only a **non-unique** index on `prefix`, and that migration is already committed and deployed.
- Adding the unique index is a **new migration** — schema work, out of scope for a middleware slice, and it needs a backfill/dedup decision for any keys already issued.

This isn't a stale line number I can re-anchor (§3b) or a seam I can document (§3c). Slice 3 as scoped is **not atomic**: it now implies a migration slice that doesn't exist.

### 8. Verdict

**No-go — blocked. This needs a re-split, not a handoff.** Handing back to you:

> Slice 3 depends on a `UNIQUE` index on `api_keys.key_hash` that no slice creates. Options, all of which are a **planning** decision, not mine to make:
> - insert a new migration slice (2.5) before Slice 3, or
> - fold the unique index into a follow-up migration and re-scope Slice 3 to depend on it.
>
> This is `to-plan`'s job, not `next-slice`'s. I re-anchored nothing and appended nothing to the plan, because the plan's structure itself is what needs to change. **No green prompt emitted** — emitting one would bury a real blocker under a checklist.

*(The gate was green, and the skill still said no. That's the point of §6: it never papers a blocker into a green prompt.)*
