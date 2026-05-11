# Standard Review — "Adding Stripe Subscriptions"

> User: `/pressure-test` — We're adding subscription billing to our SaaS. Standard review.

**Agent:** Standard review confirmed — ~20–30 questions, covering the main decisions. Let's go.

---

**Q1 — Pricing model**
Recommendation: per-seat pricing. Simpler to reason about, easier to communicate, standard for B2B SaaS.
Are you doing per-seat, flat-rate, or usage-based pricing?

> User: Per-seat. Three tiers: Free, Pro ($12/mo), Team ($30/seat/mo).

---

**Q2 — Annual billing**
Recommendation: offer annual billing at 20% discount. Reduces churn, improves cash flow, expected by most SaaS buyers.
Will you offer annual billing, and at what discount?

> User: Yes, but we haven't decided the discount.

**Agent:** Settle this before implementation — Stripe Checkout surfaces the billing interval prominently and your copy needs a number. 20% is the most common anchor; 17% (two months free) is mathematically equivalent and sometimes easier to market. Pick one now so it doesn't block engineering.

> User: 20% it is.

---

**Q3 — Free trial**
Recommendation: 14-day trial on Pro, no credit card required. Reduces signup friction; gate card collection at trial end.
Will you offer a free trial, and does it require a card upfront?

> User: Yes, 14 days. No card required.

---

**Q4 — Trial-to-paid conversion**
Recommendation: hard-lock the UI on day 15 with inline card-entry prompt, preceded by warning emails on days 10 and 13.
How will you handle users when the trial expires?

> User: We were going to email them and let them keep using it until they add a card.

**Agent:** That's a soft gate — it works, but tends to lower conversion because there's no urgency signal. A hard lock on day 15 also simplifies the state machine: you don't need a "grace period" as a third state alongside "trialing" and "active." Worth reconsidering before you build the model.

> User: Good point. Hard lock on day 15, 2-day warning email on day 13. Agreed.

---

**Q5 — Webhook handler**
Recommendation: build a Stripe webhook handler before anything else — it's the source of truth for subscription state. Handle at minimum: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_failed`.
Do you have a webhook handler planned, or were you going to poll the Stripe API?

> User: We were going to poll.

**Agent:** Polling will drift under load and is fragile on retries. Stripe's own docs recommend webhooks; idempotent event handling is straightforward with their event IDs. This is worth correcting before you commit the data model.

> User: Agreed, we'll do webhooks.

---

**Q6 — Idempotency**
Recommendation: store processed Stripe event IDs in a DB table and skip duplicates. Stripe delivers events at-least-once; without idempotency you risk double-crediting accounts.
How will you handle duplicate webhook deliveries?

> User: We'll store event IDs.

---

**Q7 — Proration**
Recommendation: use Stripe's default proration — charge or credit immediately on upgrade or downgrade. Only override this if you have a specific billing-cycle reason.
How will you handle mid-cycle plan changes?

> User: Default proration is fine.

---

**Q8 — Cancellation behavior**
Recommendation: cancel at period end, not immediately. Users expect access through the period they paid for; immediate cancellation generates support tickets.
When a user cancels, do they lose access immediately or at end of period?

> User: End of period.

---

**Q9 — Payment failure / dunning**
Recommendation: use Stripe Smart Retries plus your own email on first failure. After a 7-day grace window, downgrade to Free — don't delete the account.
What happens when a payment fails?

> User: We hadn't thought about this.

**Agent:** This needs a decision before launch — it directly affects your subscription state machine and user communication flow. A 7-day grace period (retries on days 1, 3, 7) before downgrade is a common, reasonable default. Downgrade rather than delete preserves the user's data and makes recovery easier.

> User: 7-day grace, downgrade to Free. Agreed.

---

**Q10 — Billing UI**
Recommendation: use Stripe's hosted Customer Portal for plan changes, payment method updates, and cancellation. Saves weeks of UI work and is PCI-compliant by default.
Custom billing UI or Stripe Customer Portal?

> User: Hosted portal.

---

*(questions 11–20 cover: team seat management and who controls seat count, invoice PDF access, tax handling — Stripe Tax vs. manual, refund policy, admin override capability, audit log for billing events, staging environment with Stripe test mode, API key scoping, Stripe Radar fraud rules, and rollout plan for existing users)*

---

**Q20 — Rollout for existing users**
Recommendation: enable billing for new signups first. Give existing Free users a 60-day grandfather window — access unchanged — then prompt them to pick a paid plan or stay on the Free tier explicitly.
How will you migrate existing users to the new billing system?

> User: 60-day grandfather window, then prompt. Good.

---

## Consolidated plan

Decisions locked in:
1. Per-seat pricing: Free, Pro ($12/mo), Team ($30/seat/mo).
2. Annual billing at 20% discount.
3. 14-day free trial, no credit card required.
4. Hard lock on day 15; warning email on day 13.
5. Webhook-first architecture; polling ruled out.
6. Idempotency via stored Stripe event IDs.
7. Default Stripe proration on plan changes.
8. Cancellation at period end, not immediately.
9. Payment failure: 7-day grace with Smart Retries, then downgrade to Free (not delete).
10. Stripe hosted Customer Portal for all billing UI.
11–20. *(seat management, tax, refunds, admin overrides, audit log, staging, fraud rules, and rollout — all confirmed in full session)*

Open questions:
- Seat management UX for Team plan: who can add/remove seats, and is there a minimum seat count?
- Tax handling: Stripe Tax vs. manual — deferred pending legal input.

Recommended next actions:
1. Build webhook handler with idempotency table.
2. Implement subscription state machine: `free` → `trialing` → `active` → `past_due` → `canceled`.
3. Configure Stripe Customer Portal.
4. Write trial-end email sequence (days 10, 13, 15).
5. Configure Smart Retries in Stripe dashboard; implement grace-period downgrade job.
6. Plan grandfather migration: set cutover date and draft communication to existing users.
