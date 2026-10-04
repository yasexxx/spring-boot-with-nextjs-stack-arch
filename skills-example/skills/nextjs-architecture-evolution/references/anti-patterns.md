# Frontend Anti-Patterns to Detect

For each finding report: **where** (paths), **signal**, **impact**, **smallest fix**. `scripts/scan-frontend.sh` surfaces many of these; confirm by reading the code before reporting.

| Anti-pattern | Detection signals | Smallest fix |
|---|---|---|
| **Giant component / page** | `DashboardPage.tsx` 2,500 lines; fetch + dialogs + table + rules + mutations in one file | Split by responsibility into feature `ui/` components; move fetch to `infrastructure/` |
| **Feature logic in route files** | Large `app/**/page.tsx` with business rules | Thin route → `modules/<feature>/ui/pages/<Page>` |
| **Fetch everywhere** | `fetch(` repeated across many components for the same resource | Feature API module/gateway; add a query cache only if polling/optimistic/shared cache is needed |
| **Excessive `"use client"`** | Client layouts or pages; most files are client | Move the client boundary down to interactive leaves |
| **Secrets in client code** | Non-`NEXT_PUBLIC_` `process.env` in client files; private keys in shared modules | Move to server-only modules (`import "server-only"`), Route Handler or Server Action |
| **Giant global store** | `useAppStore` with inventory, purchasing, payroll, theme, dialogs, auth, reports | Feature-owned state; URL/server state where appropriate |
| **Server state in a client store** | API responses copied into Zustand/Redux and manually synced | Server Components or a query cache |
| **Shared dumping ground** | Domain-named files in `shared/`; `utils.ts`, `helpers.ts`, `misc.ts` | Move to owning module; split utilities by purpose |
| **Deep cross-module imports** | `@/modules/x/infrastructure/...` imported from module `y` | Export via `@/modules/x/public`; add lint rule |
| **Cyclic module dependencies** | Module A imports B and B imports A | Move the concept to its owner or introduce a contract/event |
| **Backend DTO coupling everywhere** | snake_case transport fields spread across components | Map at the infrastructure boundary where it reduces coupling |
| **Duplicated types** | Same entity shape redefined in many files | Single type owned by the module, exported via `public.ts` |
| **Excessive prop drilling** | Same props passed through 4+ layers | Composition (children), feature Context |
| **Inconsistent loading/error handling** | One global spinner; raw error messages shown | `loading.tsx`/Suspense per route; typed UI error states |
| **Premature domain modeling** | Aggregate/Repository/ValueObject/UseCase/Factory for a dropdown fetch | Delete the layers; plain fetch + component |
| **Premature event bus** | Event bus used where a function call would do | Direct call or callback prop |
| **Premature micro-frontends** | Module Federation with one team, shared releases | Merge into a modular frontend |

## Examples

Giant component:

```text
DashboardPage.tsx — 2,500 lines
```
→ split by feature responsibility.

Fetch everywhere:

```text
Component A → fetch()
Component B → fetch()
Component C → fetch()
```
→ reusable feature data access when repetition or coordination appears.

Giant global store:

```text
useAppStore
├── inventory
├── purchasing
├── payroll
├── theme
├── dialogs
├── auth
└── reports
```
→ feature-owned state.
