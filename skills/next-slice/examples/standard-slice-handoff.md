# Standard Handoff — "API-Key Auth, Slice 2 → Slice 3"

A full-ceremony handoff: the gate is green, but building the slice broke a plan assumption, moved a helper, and exposed a seam the next slice codes against. Every section earns its place.

> User: `/next-slice` — I just finished the key-issuance slice. Hand off to the auth-middleware slice.

**Agent:** Slice boundary confirmed. Working the sections in order.

---

### 1. Boundary — inputs

- **Plan:** `docs/plans/api-keys.hardened.md` (the plan-clash hardened copy exists, so the builders read that, not the `.plan.md`).
- **Slice N = 2** (issuance endpoint + hashing) just finished; **N+1 = 3** (auth middleware that validates incoming keys) is next. Confirmed against the plan's slice list and `git log`.

### 2. Landed-state gate

- **Clean tree** — `git status` shows only the two files Slice 2 was scoped to touch, both committed. ✅
- **Green gate** — `npm test` (read from `package.json` → `scripts.test`) run just now: **142 passing, 0 failing**. ✅
- **Committed** — branch `feat/api-keys`, Slice 2 at `a1b9f3c`. ✅

All three hold → proceed.

### 3. Pre-mortem — what I learned that the plan's author didn't

- **Broken assumption (load-bearing).** Plan §Slice 3 says the middleware "looks up the key row by the raw key." Impossible: Slice 2 stores **only** `key_hash` (SHA-256) — the raw key is never persisted. **Resolution:** the middleware must parse the key's 8-char `prefix`, `SELECT` candidate rows by `prefix`, then constant-time-compare `SHA-256(raw)` to `key_hash`. This reshapes Slice 3's core lookup logic.
- **Deferred dependency.** The `last_used_at` column exists but Slice 2 never writes it. Slice 3 now owns updating it on each successful auth.
- **Invariant this slice touched.** Keys are shown exactly once at issuance and must never be logged. Slice 3's failure path must not log the raw key.

**Guidance-file check (read-only).** `AGENTS.md` states *"all persisted secrets use bcrypt."* Slice 2 used SHA-256 for API keys — correct, because keys are high-entropy random tokens (bcrypt is for low-entropy passwords). This contradicts the rule but is **not** an invariant Slice 3 depends on, so I do not edit the guidance file. One loud line, then continue:

> ⚠️ AGENTS.md may be stale: "all persisted secrets use bcrypt" — API keys are high-entropy and use SHA-256 (standard; bcrypt is password-scoped). Human review, not mine to edit.

### 4. Re-anchor the next slice's references

- Plan §Slice 3 cites the hash helper at `src/auth/keys.ts:12 (hashKey)`. Slice 2 moved hashing into `src/auth/crypto.ts` and renamed it. **Re-anchored → `src/auth/crypto.ts:34 hashApiKey()`.** A companion `prefixOf(raw)` now lives at `src/auth/crypto.ts:41`.
- Plan cites the middleware mount point at `src/routes/index.ts:88`. Slice 2's new issuance route shifted it. **Re-anchored → `src/routes/index.ts:103`.**

Both anchors verified against current code by grep — not carried forward on trust.

### 5. Seam diff — what Slice 2 exposed that Slice 3 consumes

- **Endpoint:** `POST /v1/api-keys` → `201 { id, key, prefix, created_at }`. `key` is the raw token `sk_live_<32hex>`, returned once and never stored.
- **DB:** `api_keys(id uuid, key_hash text, prefix text, user_id uuid, created_at, last_used_at null, revoked_at null)`; b-tree index on `prefix`.
- **Helpers:** `hashApiKey(raw) → sha256 hex` (`src/auth/crypto.ts:34`), `prefixOf(raw) → first 8 chars` (`:41`).
- **Invariant:** only `key_hash` is stored; raw key is never persisted or logged; `revoked_at` non-null ⇒ key is invalid.

### 6. Field notes appended to the plan (append-only)

Appended verbatim to the end of `docs/plans/api-keys.hardened.md` — no existing prose touched:

```
## Field notes — post-Slice 2 (feat/api-keys @ a1b9f3c)
- re-anchored: `src/auth/keys.ts:12 hashKey` → `src/auth/crypto.ts:34 hashApiKey`; new `prefixOf` at `:41`
- re-anchored: middleware mount `src/routes/index.ts:88` → `:103`
- seam: `POST /v1/api-keys` → `201 {id,key,prefix,created_at}`; raw key shown once; store is `key_hash` only
- watch: plan's "look up by raw key" is impossible — keys are hashed. Slice 3 looks up by `prefix`, then constant-time-compares `hashApiKey(raw)` to `key_hash`. Tension fast-lookup vs never-store-raw → resolved by prefix index + hash compare.
- watch: Slice 3 owns writing `last_used_at`; must never log the raw key on failure.
```

### 7. Handoff prompt (command-first, self-contained)

```
Task: Implement Slice 3 (API-key auth middleware) of docs/plans/api-keys.hardened.md.
Read that slice and AGENTS.md first.

Branch: feat/api-keys — already committed through Slice 2 @ a1b9f3c. Do NOT branch anew.

GATE (must pass before you commit):
    npm test
Done when (plan §Slice 3): requests with a valid, non-revoked key reach the handler;
missing/invalid/revoked keys get 401; last_used_at is updated on success.

SCOPE: add the auth middleware and wire it in. Do NOT touch:
  - src/routes/api-keys.ts        (Slice 2, done)
  - src/middleware/rate-limit.ts  (Slice 4, not yet built)

RE-ANCHORED REFS (plan's were stale):
  - hash helper:   src/auth/crypto.ts:34  hashApiKey(raw)   (was hashKey in keys.ts)
  - prefix helper: src/auth/crypto.ts:41  prefixOf(raw)
  - mount at:      src/routes/index.ts:103

SEAM you code against:
  - Header: Authorization: Bearer sk_live_<32hex>
  - Lookup: prefixOf(raw) → SELECT api_keys WHERE prefix = ?
            → constant-time compare hashApiKey(raw) to key_hash
  - Store:  api_keys(key_hash, prefix, revoked_at, last_used_at, user_id).
            Only key_hash is stored; the raw key is never persisted.
  - Reject if revoked_at is non-null. On success, set last_used_at = now().

CONSTRAINTS:
  - NEVER log the raw key, even on failure.
  - The plan's "look up by raw key" is wrong — keys are hashed. Look up by prefix,
    then hash-compare. (See "Field notes — post-Slice 2" at the end of the plan.)

Commit per AGENTS.md (use the repo's commit skill). Do NOT deploy.
```

**Self-containment check:** every fact above lives in the prompt, the plan (§Slice 3 + field notes), or `AGENTS.md`. No "as we discussed." The done-when is quoted from the plan rather than restated loosely. ✅

### 8. Verdict

**Go — clear to start Slice 3.** The one broken assumption is captured in the prompt and the plan; it reshapes the slice's logic but does not re-scope it, so this is a handoff, not a re-plan.
