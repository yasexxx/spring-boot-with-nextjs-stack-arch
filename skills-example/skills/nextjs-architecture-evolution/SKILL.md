---
name: nextjs-architecture-evolution
description: >-
  Guides Next.js / React frontends through incremental architecture evolution
  (Clean UI -> Feature-Based -> API/Infrastructure Boundaries -> Frontend Domain
  Modeling -> Bounded Modules -> Modular Frontend -> Shared Contracts/Events ->
  Micro-Frontends), recommending only the smallest next step justified by an
  observable problem. Use whenever the task involves reviewing, structuring or
  refactoring a Next.js/React app; App Router layout and route files; feature
  folders, modules, public APIs or the shared folder; Server vs Client
  Components and "use client" boundaries; Server Actions, Route Handlers or a
  BFF; data fetching, TanStack Query, Zustand, Redux, Context or forms; design
  system and tables; real-time (polling/SSE/WebSocket); or micro-frontends and
  Module Federation. Also use before adding a non-trivial frontend feature.
  Do not use for pure styling/CSS tweaks or non-React code.
---

# Frontend Architecture Evolution — Next.js

Your job is to keep the frontend **simple, maintainable, testable and aligned with the business domain**. Reaching micro-frontends is **not** the goal.

**Prime directive:** every architectural change MUST solve an observable, named problem in this codebase. Never adopt a pattern because the backend uses DDD/hexagonal or because it is "enterprise".

Prefer: simple React code over ceremony · feature ownership over global technical folders · Server Components over unnecessary Client Components · local state over global state · explicit API boundaries over scattered `fetch` · module boundaries over micro-frontends · business terminology over generic technical names.

## Version rule (MANDATORY)

Next.js APIs change between majors (route `params`, caching/revalidation, middleware vs proxy, Server Actions, config). Before writing Next.js API code:

1. Read the installed version in `package.json`.
2. If `node_modules/next/dist/docs/` exists, read the relevant page there; it beats your training data.
3. Honor project-level agent notes (e.g. an `AGENTS.md` next to `package.json`).

Code examples in this skill show **architecture**, not authoritative API signatures.

## The ladder

| Level | Stage | Move here only when… |
|---|---|---|
| 1 | Clean React / Next.js code | default; simple pages |
| 2 | Feature-based organization | unrelated features mix in global `components/ hooks/ services/` |
| 3 | API / infrastructure boundaries | `fetch` and transport details are scattered or duplicated in UI |
| 4 | Frontend domain modeling | real business behavior (eligibility, transitions, calculations) is duplicated in UI |
| 5 | Bounded frontend modules | business modules are coupled; need `public.ts` APIs |
| 6 | Modular frontend | modules need enforced isolation (lint/import rules) in one app |
| 7 | Shared contracts / events | independent UI areas must react to shared actions or backend push |
| 8 | Micro-frontend ready | modules pass the 12-question gate's prerequisites |
| 9 | Micro-frontends | teams genuinely need independent frontend deployment |

Levels may differ **per feature**. Details: [references/levels.md](references/levels.md).

## Step 0 — Route the task

| Task looks like | Mode |
|---|---|
| "review / assess / how should we structure" | **A. Review** |
| changing existing pages/components, splitting a big file | **B. Refactor** |
| adding a page or workflow | **C. New feature** |
| "where should this state live", Zustand/Redux/TanStack Query/forms | **D. State & data** |
| events, real-time, "micro-frontends", Module Federation, multiple teams | **E. Events / real-time / micro-frontends** |

## Mode A — Review

1. **Understand first.** Run the read-only scanner, then inspect what it flags:
   `bash <this-skill-dir>/scripts/scan-frontend.sh [frontend-dir]`
   Then read `package.json`, Next version, `app/` tree, client/server boundaries, feature folders, API clients, hooks, state, styling, validation, auth, tests.
2. **Classify** the level per feature, citing file paths.
3. **List pain points with evidence** — giant pages, excessive `"use client"`, repeated fetch, duplicated types, giant stores, `shared/` dumping ground, business logic in presentation or route files, deep cross-module imports, cycles, prop drilling, leaked DTOs, inconsistent loading/error handling. Signals and fixes: [references/anti-patterns.md](references/anti-patterns.md).
4. **Recommend the smallest next step** for the affected feature(s) only.
5. **Report** with [templates/assessment-report.md](templates/assessment-report.md); each structural change gets an [architecture decision](templates/architecture-decision.md).

## Mode B — Refactor

Inspect first · preserve sound conventions · change **one feature boundary at a time** · no unrelated refactoring · keep route files thin · keep behavior unless asked. Start with `ui/` + `infrastructure/`; add `domain/` / `application/` only when complexity warrants. Playbook: [references/refactoring-playbook.md](references/refactoring-playbook.md).

## Mode C — New feature

- **Simple page** (read-only list, lookup, settings) → thin route + Server Component fetch + presentational component. No domain layer, use cases, gateways, global state.
- **Business workflow** (approvals, multi-step forms, pricing, permission-driven actions) → `modules/<feature>/` with `ui/`, `infrastructure/`, and `domain/`/`application/` as needed, exposed via `public.ts`.

Server Components by default; push `"use client"` down to interactive leaves. Rules: [references/nextjs-rules.md](references/nextjs-rules.md), boundaries: [references/modules-and-boundaries.md](references/modules-and-boundaries.md).

## Mode D — State & data

Escalate only as needed: **URL → server state → `useState` → `useReducer` → feature Context → Zustand → Redux (rarely)**. Server data stays in Server Components or a query cache, not in Zustand/Redux. TanStack Query only for polling, background refetch, optimistic updates, or shared client cache. Details: [references/state-forms-data.md](references/state-forms-data.md).

## Mode E — Events / real-time / micro-frontends

- Event bus only when distant modules must react to a shared action or backend push; never to avoid a function call.
- Real-time: polling → SSE → WebSocket, chosen by required direction and latency.
- Micro-frontends: answer **all 12 gate questions in writing**; if any is weak, stay a modular frontend and name the failing questions.

Details: [references/events-realtime-microfrontends.md](references/events-realtime-microfrontends.md).

## Escalation flow — STOP at the first NO

```text
Page/component hard to understand?                  YES → Clean UI code
Unrelated features mixed together?                  YES → Feature-based organization
API/infrastructure details scattered through UI?    YES → Infrastructure boundaries
Meaningful business logic duplicated in UI?         YES → Frontend domain/application logic
Business modules tightly coupled?                   YES → Module public APIs
Modules need stronger isolation?                    YES → Modular frontend (enforced imports)
Independent UI areas need async coordination?       YES → Explicit events / shared contracts
Teams require independent frontend deployment?      YES → Evaluate micro-frontends (gate)
```

## Hard rules (NEVER)

- NEVER mark a root layout or whole route tree `"use client"` without a concrete reason.
- NEVER put secrets, private API keys or internal tokens where client code can reach them; server-only modules use `server-only`.
- NEVER treat frontend validation or permission checks as security — the backend stays authoritative.
- NEVER put local UI state or server data into a global store; NEVER add TanStack Query, Zustand or Redux "because API calls/state exist".
- NEVER create domain models, use cases, gateways or interfaces for a simple fetch or dropdown.
- NEVER let business logic accumulate in `app/**` route files or in `shared/`.
- NEVER deep-import another module's internals; import from `@/modules/<x>/public`.
- NEVER move a component to `shared/` because it is used twice; share by semantic reuse.
- NEVER turn Route Handlers / Server Actions into a second business backend.
- NEVER add an event bus, WebSocket or micro-frontend without the justification above.
- NEVER mirror the backend's bounded contexts mechanically; follow user workflows.
- NEVER show raw backend exception messages to users; map to typed UI error states.
- NEVER answer with bare slogans; say exactly **where** and **why**.

## Reject weak justifications

"The frontend has many pages" · "we already use microservices" · "the backend is distributed" · "we want independent folders" · "we use Module Federation" · "micro-frontends scale better" · "it's enterprise" · "we might need global state later".

## Output contract

1. Current architecture assessment (level per feature, with evidence)
2. Problems found (concrete, with file paths)
3. Recommended next stage (smallest step)
4. Proposed folder structure
5. Allowed dependencies / imports
6. Incremental migration steps
7. What **not** to introduce yet
8. Next trigger that would justify the following stage

Templates: [templates/assessment-report.md](templates/assessment-report.md), [templates/architecture-decision.md](templates/architecture-decision.md).

## Reference index — load only what the task needs

| File | Load when |
|---|---|
| [references/levels.md](references/levels.md) | classifying a level or designing a target structure |
| [references/nextjs-rules.md](references/nextjs-rules.md) | Server/Client Components, data fetching, Server Actions, Route Handlers/BFF, loading/error, auth |
| [references/state-forms-data.md](references/state-forms-data.md) | state placement, forms, application layer, mutations, errors, DTO mapping |
| [references/modules-and-boundaries.md](references/modules-and-boundaries.md) | modules, `public.ts`, `shared/`, design system, tables, import rules, backend alignment |
| [references/events-realtime-microfrontends.md](references/events-realtime-microfrontends.md) | events, polling/SSE/WebSocket, micro-frontend gate and extraction |
| [references/anti-patterns.md](references/anti-patterns.md) | reviewing code or explaining a smell |
| [references/refactoring-playbook.md](references/refactoring-playbook.md) | incremental migration, implementation behavior, testing strategy |

Final principle: strong module boundaries are usually enough. Do not introduce network or deployment boundaries until team organization and release requirements genuinely need them.
