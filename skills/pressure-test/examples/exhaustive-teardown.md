# Exhaustive Teardown — "We're Rebuilding Our Auth System" (abridged)

> User: `/pressure-test` — We're ripping out our homegrown auth and replacing it with a proper identity provider. Exhaustive teardown.

**Agent:** Exhaustive mode confirmed — I'll keep going until every branch is resolved. Expect 50+ questions. I'll recap locked decisions every 20 questions.

---

**Q1 — Build vs. buy**
Recommendation: buy (managed IdP — Auth0, Clerk, Supabase Auth, or similar). Homegrown auth is the most common source of security incidents in web apps; managed providers offload MFA, breach detection, compliance, and session management.
Are you committed to a managed IdP, or is self-hosted (e.g. Keycloak) on the table?

> User: Managed, yes. Leaning Clerk.

---

**Q2 — Existing session tokens**
Recommendation: issue a migration period (2–4 weeks) where both old and new auth systems are valid, then hard-cut.
How will existing logged-in users be handled during the cutover?

> User: We'll force re-login on next visit.

**Agent:** Simpler than a migration period, and valid for most apps. One consequence: users with long-lived sessions (mobile apps, CLI tokens) will be logged out without warning. Is that acceptable, or do you need to notify them first?

> User: We'll send an email. Fine.

---

*(questions 3–20 cover: OAuth scopes, RBAC model, machine-to-machine tokens, MFA requirements, session length, refresh token rotation, JWT vs. opaque tokens, webhook verification, audit logging, GDPR data residency, rate limiting, account linking, social login providers, admin impersonation, passkey support, SLA requirements, rollback plan, staging environment parity)*

---

**Checkpoint after Q20 — decisions locked in so far:**
1. Managed IdP: Clerk.
2. Cutover: forced re-login with advance email notification.
3. OAuth scopes: minimal (profile, email); no `offline_access` by default.
4. RBAC: three roles (admin, member, viewer) managed in Clerk metadata.
5. M2M tokens: Clerk machine tokens for internal services.
6. MFA: optional for members, required for admins.
7. Session length: 7-day sliding window; refresh token rotation enabled.
8. Token format: JWTs (Clerk default).
9. Webhooks: verified via Clerk's svix signatures.
10. Audit log: Clerk's built-in log forwarded to existing log aggregator.

*(continues...)*

---

*(questions 21–50+ cover: frontend SDK integration, mobile deep-link handling, E2E test auth strategy, load testing plan, incident response contacts, and remaining branches)*

---

## Final consolidated plan *(abridged)*

Decisions locked in: *(full list of all 50+ decisions from the session)*

Open questions:
- Passkey support: deferred to v2 — Clerk supports it but team hasn't evaluated UX.
- Account linking (Google + email, same address): needs a written policy before launch.

Recommended next actions:
1. Provision Clerk org and configure roles.
2. Install Clerk SDK; wire JWT verification middleware.
3. Update staging environment; run smoke tests.
4. Schedule forced re-login cutover date; draft user email.
5. Archive old auth tables after 30-day post-cutover window.
