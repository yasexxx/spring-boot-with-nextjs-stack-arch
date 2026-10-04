# Next.js Rules

Contents: [Version rule](#version-rule) · [Server Components first](#server-components-first) · [Client Components](#client-component-responsibilities) · [Server-only code](#server-only-code) · [Data fetching](#data-fetching-rule) · [Server Actions](#server-actions) · [Route Handlers & BFF](#route-handlers--bff) · [Loading & errors](#loading-strategy) · [Auth](#authentication-rules) · [Backend independence](#backend-independence-rule)

---

## Version rule

APIs for route `params`, caching, revalidation, middleware/proxy, Server Actions and config differ between Next.js majors. Before writing such code, check `package.json` and read the matching page in `node_modules/next/dist/docs/` when present. Treat snippets here as architectural illustrations.

## Server Components first

Server Components are the default. Add `"use client"` only where interaction requires it.

```text
Server Component
    ↓
Interactive Client Component
    ↓
Small client-side leaf components
```

Avoid `"use client"` on `RootLayout` / the entire application unless there is a concrete reason.

Server Components fit: server-side data fetching, auth-aware rendering, initial page data, static content, composition, server-only services, smaller client bundles.

```tsx
export async function InventoryPage() {
  const inventory = await getInventory();

  return <InventoryScreen initialData={inventory} />;
}
```

Pass **serializable** props across the server → client boundary (no class instances, functions or gateways).

## Client Component responsibilities

Input interaction, local state, browser APIs, event listeners, drag-and-drop, dialogs, interactive tables, optimistic UI, client-side mutations. Keep client boundaries as low as practical.

## Server-only code

Never expose database credentials, private API keys, internal service tokens or admin credentials to client bundles. Mark server-only modules with `import "server-only"`. Only `NEXT_PUBLIC_*` env vars belong in client code — and they are public by definition.

## Data fetching rule

**Server-fetched** (Server Components) when: data is needed for initial render, SEO matters, data rarely needs client refresh, server credentials are required, interactivity is limited.

**Client-fetched server state** (query library such as TanStack Query) when: polling, background refetching, optimistic updates, complex cache sync, or the same server state is reused across many client components.

Do not introduce TanStack Query just because API calls exist. After mutations, refresh/revalidate using the mechanism documented for the installed Next.js version.

## Server Actions

Use when they simplify a server-side mutation: form submission, simple server mutations, authenticated server-side actions. Do not use them merely to hide every API call. Keep domain and infrastructure boundaries clear — a Server Action is an adapter that calls the feature's application/infrastructure code. Always re-check authorization inside the action.

## Route Handlers & BFF

Route Handlers fit: BFF endpoints, server-only proxying, combining backend calls, protecting secrets, adapting external APIs.

Consider a BFF when the frontend needs aggregation across services, UI-specific response shaping, protection from backend topology, centralized auth/session handling, or less frontend orchestration. Route Handlers or Server Actions may play this role. Do not add a BFF automatically.

**Never recreate the backend business layer inside Next.js.** The frontend server layer must not become a second business backend.

## Loading strategy

Use `loading.tsx`, `Suspense`, skeleton components and local mutation progress. Avoid one global spinner for the whole app.

## Error boundaries

Use route-level (`error.tsx`, `not-found.tsx`) or component-level boundaries where useful. Avoid one boundary swallowing every failure without context. Typed UI error states: [state-forms-data.md](state-forms-data.md#error-handling).

## Authentication rules

Centralize session handling, token refresh, route protection and permission loading in shared infrastructure (e.g. `shared/auth/`). Feature modules must not implement their own authentication; they may evaluate permissions for UI behavior.

## Authorization rule

Frontend authorization improves UX; it is **not** security.

```text
Frontend: hide Delete button
Backend:  still rejects unauthorized deletion
```

## Backend independence rule

The frontend should not need major structural changes when a backend bounded context moves from monolith to microservice. Depend on stable contracts:

```text
Frontend Inventory Module → /api/inventory
Initially: /api/inventory → Spring Boot monolith
Later:     /api/inventory → API Gateway / BFF → Inventory microservice
```

The frontend module stays largely unchanged.
