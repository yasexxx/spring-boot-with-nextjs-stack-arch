# Frontend Architecture Levels — Detail

Contents: [L1](#level-1--clean-react--nextjs-code) · [L2](#level-2--feature-based-organization) · [L3](#level-3--api--infrastructure-boundaries) · [L4](#level-4--frontend-domain-modeling) · [L5](#level-5--bounded-frontend-modules) · [L6](#level-6--modular-frontend) · [L7–L9](#levels-79) · [Enterprise target](#recommended-enterprise-target) · [Cheat-sheet](#classification-cheat-sheet)

> **Project root note:** `src/` is optional. Follow the project's existing root (`app/` at repo root vs `src/app/`); the `@/` alias points to that root. Folder trees below omit `src/` where it doesn't matter.

---

## Level 1 — Clean React / Next.js Code

Focus on: clear component names, small components, clear props, minimal duplication, predictable data flow, sensible state ownership, reusable UI where appropriate, accessibility, consistent error handling.

```tsx
export default async function DepartmentsPage() {
  const departments = await getDepartments();

  return <DepartmentList departments={departments} />;
}
```

Acceptable for a simple feature. Do **not** introduce domain layer, repository interfaces, use cases, factories, events or global state for a simple read-only page.

### Component responsibility

Bad — one component doing everything:

```text
PurchaseOrderPage.tsx
- API fetching        - form validation    - calculations
- approval rules      - modal state        - table state
- permission checks   - formatting         - notifications
- mutation logic
```

Prefer decomposition by responsibility:

```text
PurchaseOrderPage
    ├── PurchaseOrderHeader
    ├── PurchaseOrderForm
    ├── PurchaseOrderItems
    ├── ApprovalPanel
    └── PurchaseOrderActions
```

Move non-UI logic into feature-level code when complexity grows.

---

## Level 2 — Feature-Based Organization

When the app grows beyond a few pages, organize by business feature.

Avoid global technical buckets where unrelated concepts mix:

```text
components/  hooks/  services/  utils/  models/  types/
```

Prefer:

```text
app/
modules/
├── purchasing/
├── inventory/
├── accounting/
└── hr/
shared/
```

Recommended high-level structure:

```text
app/
├── (dashboard)/
├── api/
├── layout.tsx
└── page.tsx
modules/
├── purchasing/
├── inventory/
├── accounting/
└── hr/
shared/
├── ui/
├── lib/
├── hooks/
└── validation/
config/
```

`app/` handles routing, layouts, route composition, metadata, route-level loading/error handling and server entry points. Business logic must not accumulate in route files.

### Thin route files

```tsx
import { PurchaseOrderPage } from "@/modules/purchasing/ui/pages/PurchaseOrderPage";

// Verify the params signature against the installed Next.js version docs.
export default async function Page({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  return <PurchaseOrderPage id={id} />;
}
```

Avoid implementing a complex feature directly in `app/purchasing/[id]/page.tsx`.

---

## Level 3 — API / Infrastructure Boundaries

Avoid scattering `fetch()` through components when many places duplicate similar logic:

```tsx
function ApproveButton() {
  async function approve() {
    await fetch("/api/purchase-orders/123/approve", { method: "POST" });
  }
}
```

Prefer a feature-specific boundary:

```text
modules/purchasing/
├── application/
├── infrastructure/
└── ui/
```

Contract — only where the boundary has real value (multiple implementations, testing seam, server/client variants):

```ts
export interface PurchaseOrderGateway {
  approve(id: string): Promise<void>;
  getById(id: string): Promise<PurchaseOrderDetails>;
}
```

Implementation:

```ts
export class HttpPurchaseOrderGateway implements PurchaseOrderGateway {
  constructor(private readonly baseUrl: string) {}

  async approve(id: string): Promise<void> {
    const response = await fetch(`${this.baseUrl}/purchase-orders/${id}/approve`, {
      method: "POST",
    });

    if (!response.ok) {
      throw new Error("Unable to approve purchase order.");
    }
  }

  async getById(id: string): Promise<PurchaseOrderDetails> {
    const response = await fetch(`${this.baseUrl}/purchase-orders/${id}`);

    if (!response.ok) {
      throw new Error("Unable to load purchase order.");
    }

    return response.json();
  }
}
```

> **Server vs browser URLs:** a relative URL like `/api/...` only resolves in the browser. Code running on the server (Server Components, Server Actions, Route Handlers) needs an absolute base URL from server-side config, or should call the backend directly. Keep base URLs in `config/`, not hard-coded in components.

Often a plain module of functions (`purchase-order-api.ts`) is enough — do not create interfaces automatically.

---

## Level 4 — Frontend Domain Modeling

Use when the UI contains genuine business behavior: approval state, pricing calculations, form eligibility, workflow transitions, permission-dependent actions, quantity validation, scheduling rules, inventory status interpretation. Plain API response types do not require domain models.

```ts
export type PurchaseOrderStatus =
  | "DRAFT"
  | "PENDING_APPROVAL"
  | "APPROVED"
  | "REJECTED";

export function canApprovePurchaseOrder(
  status: PurchaseOrderStatus,
  permissions: string[],
) {
  return (
    status === "PENDING_APPROVAL" &&
    permissions.includes("purchase-order:approve")
  );
}
```

Lives in `modules/purchasing/domain/`. Pure TypeScript — no React, Next.js or query-library imports.

### Backend stays authoritative

Frontend domain logic supports UX, presentation, interaction, early validation and state interpretation. It never replaces backend validation.

```text
Frontend: disable Approve button
Backend:  still validates whether approval is allowed
```

DTO-vs-model mapping rules: [state-forms-data.md](state-forms-data.md#domain-vs-api-models).

---

## Level 5 — Bounded Frontend Modules

Identify business boundaries (`purchasing/ inventory/ accounting/ hr/ quality/ production/`). Each module owns its domain types, feature application logic, API adapters, components, hooks, validation and tests.

Structure for a **complex** module (do not force on trivial features):

```text
modules/purchasing/
├── domain/
│   ├── purchase-order.ts
│   ├── purchase-order-status.ts
│   └── approval-rules.ts
├── application/
│   ├── get-purchase-order.ts
│   ├── approve-purchase-order.ts
│   └── create-purchase-order.ts
├── infrastructure/
│   ├── purchase-order-api.ts
│   └── purchase-order-mappers.ts
├── ui/
│   ├── components/
│   ├── hooks/
│   └── pages/
└── public.ts
```

Public API and cross-module rules: [modules-and-boundaries.md](modules-and-boundaries.md).

---

## Level 6 — Modular Frontend

For large apps, target a modular frontend before micro-frontends:

```text
Next.js Application
├── Purchasing Module
├── Inventory Module
├── Accounting Module
├── HR Module
└── Quality Module
```

Still `1 repository · 1 Next.js app · 1 deployment` — often the frontend sweet spot.

Each module: clear ownership, limited public exports, isolated feature logic, minimal deep cross-module imports, stable contracts, independent tests where useful. **Boundaries must not exist only as folders** — enforce with lint/import rules ([modules-and-boundaries.md](modules-and-boundaries.md#import-rules)).

---

## Levels 7–9

- **L7 Shared contracts / events**, **L8 Micro-frontend ready**, **L9 Micro-frontends**: [events-realtime-microfrontends.md](events-realtime-microfrontends.md).

---

## Recommended enterprise target

```text
app/
├── (auth)/
├── (dashboard)/
└── api/
modules/
├── purchasing/
│   ├── domain/
│   ├── application/
│   ├── infrastructure/
│   ├── ui/
│   └── public.ts
├── inventory/
├── accounting/
├── hr/
└── quality/
shared/
├── ui/
├── lib/
├── auth/
└── validation/
config/
```

No folder is mandatory. Complex modules may use all layers; simple modules may only need:

```text
module/
├── ui/
└── api.ts
```

---

## Classification cheat-sheet

| Evidence | Likely level |
|---|---|
| Logic inside `app/**/page.tsx`; global `components/`, `hooks/`, `utils/` | 1 |
| `modules/` or `features/` per business area; thin routes | 2 |
| Per-feature API files/gateways; few raw `fetch` calls in components | 3 |
| `domain/` with pure functions/types encoding business behavior | 4 |
| `public.ts` per module; cross-module imports only via public APIs | 5 |
| Lint rules enforcing module boundaries | 6 |
| Typed event contracts, SSE/WebSocket subscriptions, cross-module event bus | 7 |
| Modules with stable contracts, own ownership, gate prerequisites met | 8 |
| Shell app + independently deployed frontends | 9 |
