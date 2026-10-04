# Events, Real-Time & Micro-Frontends

Contents: [Frontend events](#level-7--shared-contracts--frontend-events) · [Real-time](#real-time-communication) · [Micro-frontend evaluation](#level-8--micro-frontend-candidate-evaluation) · [Gate](#mandatory-micro-frontend-gate) · [Extraction](#level-9--micro-frontend-extraction) · [Warnings](#micro-frontend-warnings)

---

## Level 7 — Shared contracts / frontend events

Use events sparingly. Good reasons:
- independent UI modules must react to a shared action
- loose coupling between distant modules is valuable
- browser-wide coordination exists (e.g. across tabs)
- WebSocket/SSE messages represent backend events

Never introduce an event bus merely to avoid normal function calls.

Example: backend `PurchaseOrderApproved` arrives via SSE/WebSocket → Purchasing UI updates status, Accounting dashboard refreshes, Notification center shows an update.

Explicit, typed contracts:

```ts
type PurchaseOrderApprovedEvent = {
  type: "purchase-order.approved";
  purchaseOrderId: string;
  occurredAt: string;
};
```

Events are past-tense facts. Keep the contract in a shared, versionable place (e.g. `shared/events/` or the owning module's `public.ts`).

## Real-time communication

Only when the product requires real-time behavior. Choose by requirement:

| Option | Use when |
|---|---|
| **Polling** | freshness tolerance is seconds/minutes; simplicity matters; updates infrequent |
| **Server-Sent Events** | updates flow server → client; live notifications; simpler than WebSockets |
| **WebSockets** | true bidirectional real-time; collaboration; low-latency push both ways |

Do not add WebSockets merely because the backend supports them.

---

## Level 8 — Micro-frontend candidate evaluation

Do not introduce micro-frontends because the frontend is large. Evaluate only for organizational or deployment requirements.

**Valid reasons:** independent teams own major bounded contexts; independent deployment required; release cycles differ significantly; strong organizational boundaries; unavoidable separate stacks; very large teams with coordination bottlenecks.

**Weak reasons (reject):** "The frontend has many pages." · "We already use microservices." · "The backend is distributed." · "We want independent folders." · "We use Module Federation." · "Micro-frontends scale better."

## Mandatory micro-frontend gate

Answer every question **in writing** before recommending micro-frontends:

1. Are frontend business boundaries already clear?
2. Does each candidate area have clear ownership?
3. Are module public APIs stable?
4. Is independent deployment actually required?
5. Are multiple teams blocked by a single frontend release process?
6. Can design-system consistency be maintained?
7. Can authentication remain coherent?
8. Can routing remain understandable?
9. Can shared state be minimized?
10. Is runtime duplication acceptable?
11. Is observability available?
12. Is the added operational complexity justified?

If not convincingly answered → remain a modular frontend and name the failing questions.

## Level 9 — Micro-frontend extraction

Extract one bounded frontend area at a time.

Before:

```text
Next.js App
├── Purchasing
├── Inventory
├── Accounting
└── HR
```

Possible later:

```text
Shell Application
    ├── Purchasing Frontend
    ├── Inventory Frontend
    ├── Accounting Frontend
    └── HR Frontend
```

Only when deployment/team independence creates measurable value.

## Micro-frontend warnings

They introduce routing complexity, duplicated dependencies, design-system drift, authentication complexity, cross-app communication complexity, observability requirements, version compatibility issues, bundle duplication and more pipelines. Treat them as an **organizational scaling technique**, not a default code-organization pattern.
