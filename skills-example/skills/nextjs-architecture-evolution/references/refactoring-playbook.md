# Frontend Refactoring Playbook

## Implementation behavior (existing projects)

1. Inspect the existing structure first.
2. Preserve sound conventions.
3. Change one feature boundary at a time.
4. Avoid unrelated refactoring.
5. Keep route files thin where practical.
6. Prefer Server Components by default.
7. Keep `"use client"` boundaries narrow.
8. Avoid global state unless truly cross-cutting.
9. Keep business-specific logic inside feature modules.
10. Keep infrastructure access out of purely presentational components where practical.
11. Avoid unnecessary interface layers.
12. Preserve existing behavior unless explicitly asked to change it.

Every step should type-check (`tsc --noEmit` / build), lint and keep tests green.

## Smallest next step — never jump

Current: `app/purchasing/page.tsx`, 1,800 lines containing fetch logic, dialog state, table config, domain rules, mutation logic, formatting.

Smallest useful change:

```text
Extract:
modules/purchasing/ui/
modules/purchasing/infrastructure/
```

Do not immediately introduce Redux, CQRS, an event bus or micro-frontends.

## Incremental migration

Starting point:

```text
app/inventory/
├── page.tsx
└── InventoryClient.tsx
```

Move gradually:

```text
modules/inventory/
├── ui/
│   ├── InventoryScreen.tsx
│   └── InventoryTable.tsx
└── infrastructure/
    └── inventory-api.ts
```

Step sequence:

1. **Pin behavior** — add/confirm a test or a manual checklist for the current flow.
2. **Extract data access** into `infrastructure/inventory-api.ts`; route/Server Component calls it.
3. **Extract UI** into `modules/inventory/ui/`; the route file becomes a thin composition.
4. **Push `"use client"` down** to the interactive leaves only.
5. **Add `public.ts`** once another module needs something from this one.
6. **Add `domain/` / `application/`** only when meaningful rules are duplicated across workflows.
7. **Lock the boundary** with the `no-restricted-imports` rule ([modules-and-boundaries.md](modules-and-boundaries.md#import-rules)).

## New feature shapes

- Simple page: `app/<route>/page.tsx` (thin) → Server Component fetch → presentational component.
- Business workflow: `modules/<feature>/{ui,infrastructure}` + `domain/`/`application/` as justified + `public.ts`.

## Testing strategy

| Type | What | Notes |
|---|---|---|
| Domain logic | pure business functions | no React; fastest |
| Component | rendering, interaction, accessibility, form behavior | avoid implementation-detail tests |
| Integration | important feature flows: create/approve purchase order, receive inventory, submit timesheet | |
| End-to-end | critical workflows only | never test every component through E2E |

```ts
expect(
  canApprovePurchaseOrder("PENDING_APPROVAL", ["purchase-order:approve"]),
).toBe(true);
```

If no test runner exists, propose one only when the first piece of logic worth testing appears (domain functions are the usual trigger).

## Worked review example

**Current Problem** — `InventoryPage.tsx` contains API calls, sorting, filters, table rendering, dialogs, mutation logic and stock calculations.

**Smallest Change**

```text
modules/inventory/
├── infrastructure/
│   └── inventory-api.ts
└── ui/
    ├── InventoryScreen.tsx
    ├── InventoryTable.tsx
    ├── InventoryFilters.tsx
    └── AdjustStockDialog.tsx
```

**Why Now** — the route component has too many responsibilities.

**Do Not Introduce Yet** — Redux, DDD aggregates, event bus, micro-frontends.

**Next Trigger** — introduce `application/`/`domain/` when stock-management rules start being duplicated across multiple UI workflows.
