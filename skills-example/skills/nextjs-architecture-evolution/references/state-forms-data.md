# State, Forms & Data Flow

Contents: [State escalation](#state-management-strategy) · [URL](#url-state) · [Local](#local-state) · [Reducer](#reducers) · [Context](#context) · [Zustand](#zustand) · [Redux](#redux) · [Forms](#form-strategy) · [Application layer](#application-layer) · [Mutation flow](#mutation-flow) · [Errors](#error-handling) · [DTO vs model](#domain-vs-api-models)

---

## State management strategy

Use the smallest state solution that fits. Escalate in order:

```text
URL State
    ↓
Server State
    ↓
Component State (useState)
    ↓
Reducer (useReducer)
    ↓
Feature Context
    ↓
Zustand
    ↓
Redux only when justified
```

Never start with global state.

## URL state

For state that should be shareable, bookmarkable, navigable, restorable: search, page, sort, filters, selected tab, date range.

```text
/inventory?page=3&warehouse=MAIN
```

Prefer this over global state when navigation semantics matter.

## Local state

`useState` for dialog open/closed, selected row, input state, temporary selection. Never put local component state into Zustand or Redux.

## Reducers

`useReducer` when one component/feature has multiple related transitions: multi-step forms, complex filters, workflow editors, local wizards.

## Context

Use React Context for state/behavior shared by a feature subtree. Prefer `PurchaseOrderFormProvider` over a giant `ApplicationStateProvider` with unrelated state.

## Zustand

Appropriate for complex feature-wide UI state, state shared across unrelated branches, persistent UI state, client-side workflows. Not for server cache by default — server state belongs in server fetching or a query cache. Prefer feature-owned stores over one app store.

## Redux

Only for substantial cross-application state complexity where its tooling clearly helps. Never because the app is "enterprise".

## Form strategy

Keep concerns separate:

```text
Form UI → Validation → Application command → API adapter
```

Use schema validation (Zod, Valibot) when useful. Do not put all business rules in form schemas — backend rules remain authoritative.

Complex form layout:

```text
modules/purchasing/
├── ui/forms/
│   ├── PurchaseOrderForm.tsx
│   ├── PurchaseOrderItems.tsx
│   └── usePurchaseOrderForm.ts
├── application/
│   └── create-purchase-order.ts
└── infrastructure/
    └── purchase-order-api.ts
```

## Application layer

Coordinates frontend use cases:

```ts
export async function approvePurchaseOrder(
  gateway: PurchaseOrderGateway,
  id: string,
) {
  await gateway.approve(id);
}
```

May coordinate API calls, mapping, cache invalidation, navigation intent, multiple domain operations. Do not create use-case files for every trivial fetch.

## Mutation flow

```text
Approve Button
    ↓
approvePurchaseOrder()
    ↓
PurchaseOrderGateway / API module
    ↓
Backend API
    ↓
Refresh / invalidate data
```

Components should not orchestrate many infrastructure concerns directly.

## Error handling

Differentiate domain/validation, authorization, not-found, network and unexpected errors. Never show raw backend exception messages; map to user-friendly UI states.

```ts
type PurchaseOrderError =
  | { type: "not-found" }
  | { type: "forbidden" }
  | { type: "validation"; message: string }
  | { type: "unknown" };
```

## Domain vs API models

Do not use backend DTOs everywhere by default. When useful:

```text
API DTO → Mapper → Frontend Model
```

```ts
type PurchaseOrderDto = {
  purchase_order_id: string;
  total_amount: string;
};

type PurchaseOrder = {
  id: string;
  total: string; // decimal string; format for display, don't do float math on money
};

export function mapPurchaseOrder(dto: PurchaseOrderDto): PurchaseOrder {
  return {
    id: dto.purchase_order_id,
    total: dto.total_amount,
  };
}
```

> **Money:** keep monetary values as decimal strings, integer minor units, or a decimal library; never `Number()` them for arithmetic.

Only map when it improves maintainability (naming mismatch, transport quirks, backend churn). Do not map mechanically. If the API types are generated (OpenAPI/GraphQL codegen), keep generated types inside `infrastructure/`.
