# Quick Sanity Check — "Should We Add a Caching Layer?"

> User: `/pressure-test` — I want to add Redis caching to our API. Quick sanity check.

**Agent:** Quick sanity check confirmed — ~5–10 questions, surface the major gaps only.

---

**Q1 — What are you caching?**
Recommendation: cache the output of expensive read queries (user profile, product catalog), not write-heavy or user-specific session data.
What data are you planning to cache?

> User: Product catalog queries — they hit the DB on every page load.

---

**Q2 — Cache invalidation strategy**
Recommendation: TTL-based expiry (5–15 min) for catalog data, with a manual flush endpoint for immediate updates after admin edits.
How do you plan to invalidate the cache when catalog data changes?

> User: We were just going to set a 1-hour TTL.

**Agent:** Worth flagging: if your admin interface can update catalog data, a 1-hour TTL means users see stale prices or availability for up to an hour after a change. A shorter TTL (5–10 min) or a write-through flush on admin save would prevent that. Which do you prefer?

> User: Good catch. We'll add a flush on admin save.

---

**Q3 — Redis vs. in-process cache**
Recommendation: Redis, since you mentioned it and your API likely runs multiple instances — an in-process cache (e.g. node-cache) would give each instance a separate cache and amplify DB load.
Do you have multiple API instances running?

> User: Yes, we're on k8s with autoscaling.

**Agent:** Then Redis is the right call — confirmed.

---

**Q4 — Cache warming**
Recommendation: no proactive warming for v1. Let the cache fill on first request. Add warming only if cold-start latency becomes a user-visible problem.
Do you need the cache to be pre-warmed on deploy?

> User: Not for now.

---

**Q5 — Failure mode**
Recommendation: treat Redis as optional — fall through to DB on cache miss or Redis timeout, with a short timeout (200ms) so a Redis outage doesn't take down the API.
What should the API do if Redis is unavailable?

> User: Fall through to DB, agreed.

---

## Consolidated plan

Decisions locked in:
1. Cache product catalog queries in Redis (not session or write-heavy data).
2. TTL: 5–10 min with a manual flush triggered on admin catalog edits.
3. Redis required — multiple k8s instances rule out in-process cache.
4. No cache warming for v1.
5. Redis treated as optional: fall through to DB on miss/timeout; 200ms Redis timeout.

Open questions:
- TTL exact value (5 vs. 10 min) — pick based on how frequently catalog changes in practice.
- Cache key schema not discussed — worth standardizing before implementation.

Recommended next actions:
1. Add Redis client with 200ms timeout and fallback middleware.
2. Implement flush endpoint called by the admin save hook.
3. Define and document cache key format.
