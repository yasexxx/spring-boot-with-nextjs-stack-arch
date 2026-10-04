# Modules & Boundaries

Contents: [Public API](#public-module-api) · [Cross-module rule](#cross-module-rule) · [Shared folder](#shared-folder-rules) · [Shared vs feature UI](#shared-ui-vs-feature-ui) · [Design system](#design-system) · [Tables](#table-architecture) · [Utilities](#utility-rules) · [Import rules](#import-rules) · [Dependency direction](#dependency-direction) · [Backend alignment](#backend--frontend-alignment)

---

## Public module API

Each major module exposes an intentional public API in `modules/<name>/public.ts`:

```ts
export type { InventoryItemSummary } from "./domain/inventory-item";
export { StockBadge } from "./ui/components/StockBadge";
export { getInventorySummary } from "./application/get-inventory-summary";
```

Other modules import from it:

```ts
import { StockBadge } from "@/modules/inventory/public";
```

not via deep paths:

```ts
import { inventoryDtoMapper } from "@/modules/inventory/infrastructure/internal/...";
```

> Keep server-only exports (anything importing `server-only` or secrets) out of a `public.ts` that client components import, or split into `public.ts` / `public.server.ts`.

## Cross-module rule

A module must not depend on another module's internals.

```ts
// Bad
import { inventoryApiClient } from "@/modules/inventory/infrastructure/inventory-api";

// Good
import { InventorySummary } from "@/modules/inventory/public";
```

…or a shared application contract.

## Shared folder rules

`shared/` must not become a dumping ground.

Good:

```text
shared/
├── ui/          Button.tsx, Dialog.tsx, DataTable.tsx
├── lib/         currency.ts, date.ts, result.ts
└── validation/
```

Bad:

```text
shared/
├── PurchaseOrderRules.ts
├── PayrollLogic.ts
├── InventoryCalculation.ts
└── AccountingMapping.ts
```

Those belong to their modules. Never move code to `shared/` just to resolve import problems — fix ownership instead.

## Shared UI vs feature UI

- `shared/ui/` — visual primitives: Button, Input, Dialog, Select, Table, Badge, Card, Tooltip.
- `modules/<feature>/ui/` — business components: PurchaseOrderStatusBadge, PurchaseOrderApprovalPanel, SupplierSelector, PurchaseOrderItemsTable.

Share by **semantic reuse**, not raw usage count. Used twice ≠ shared.

## Design system

Shared primitives form a design-system-like layer (`shared/ui/`: Button, Input, Select, Dialog, Table, Badge, FormField). Domain-specific components stay in modules.

## Table architecture

Avoid one enormous generic table containing all domain behavior. Generic mechanics in `shared/ui/DataTable`; feature configuration in `modules/inventory/ui/InventoryTable`, `modules/accounting/ui/JournalTable`.

## Utility rules

Avoid `utils.ts`, `helpers.ts`, `common.ts`, `misc.ts`. Prefer specific files: `currency.ts`, `date.ts`, `pagination.ts`, `http-error.ts`. Domain-specific helpers belong in the module's `domain/`.

## Import rules

Use aliases: `@/modules/purchasing`, `@/modules/inventory`, `@/shared/ui`.

Boundary concept:

```text
Purchasing may import:     @/modules/inventory/public
Purchasing may NOT import: @/modules/inventory/infrastructure/*
```

Enforce with ESLint (flat config, no extra dependency):

```js
// eslint.config.mjs — add alongside existing configs
{
  files: ["modules/**/*.{ts,tsx}", "app/**/*.{ts,tsx}"],
  rules: {
    "no-restricted-imports": ["error", {
      patterns: [{
        group: [
          "@/modules/*/domain/*",
          "@/modules/*/application/*",
          "@/modules/*/infrastructure/*",
          "@/modules/*/ui/*",
        ],
        message: "Import from '@/modules/<module>/public' instead of module internals.",
      }],
    }],
  },
},
```

Within a module, use relative imports so the rule only bites across modules. Adjust globs if the project uses `src/`. If finer rules are needed (per-module allow lists, layer direction), consider `eslint-plugin-boundaries` — only when the simple rule is insufficient.

## Dependency direction

For complex modules:

```text
UI → Application → Domain
Infrastructure → Application / Domain contracts
```

Avoid Domain → React, Domain → Next.js, Domain → TanStack Query. Domain logic stays framework-independent pure TypeScript.

## Backend + frontend alignment

When the backend has bounded contexts (Purchasing, Inventory, Accounting, HR), the frontend **may** use similar boundaries when that aids understanding — but frontend boundaries reflect **user workflows**. Do not mirror the backend mechanically.

Example: a user-facing `Receiving` feature can combine Purchasing + Inventory while still respecting backend contracts.
