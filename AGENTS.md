# App Agent Guide

Shared instructions for all coding agents (Claude Code reads this via `CLAUDE.md`, Codex reads it directly).

Monorepo with two apps:

| App | Stack |
|---|---|
| `apps/backend` | Spring Boot 4.1.1, Java 25, Maven wrapper. Base package `com.redpetalsclosetllc.backend`. Spring MVC + Spring GraphQL, Spring Data JPA + Flyway on PostgreSQL, Spring Security (OAuth2 resource server), Mail, Validation, Actuator, **Spring Modulith 2.1.1** (core, JPA, observability, actuator). |
| `apps/frontend` | Next.js 16.3.8, React 19.2.8, TypeScript, pnpm 10. **Read [apps/frontend/AGENTS.md](apps/frontend/AGENTS.md) before writing frontend code**: this Next.js version differs from your training data. |

## Commands

```bash
# Backend (from apps/backend). Docker must be running: compose.yaml starts Postgres via spring-boot-docker-compose.
./mvnw spring-boot:run
./mvnw test
./mvnw verify

# Frontend (from apps/frontend)
pnpm dev
pnpm build
pnpm lint
```

## Backend architecture (MUST follow)

**Use the `spring-boot-architecture-evolution` skill** (Claude: `.claude/skills/`, Codex: `.codex/skills/`) for any backend task that touches structure: reviews, refactors, new non-trivial features, package/module decisions, events, messaging or microservice questions. The skill holds the full rules. This section only records how they apply to this project.

**Current state:** greenfield, Level 1 (only `BackendApplication`).
**Target shape:** a **Modular Monolith on Spring Modulith**. Modulith is already on the classpath, so use it for boundaries, verification and events. Do NOT add a second boundary tool unless Modulith can't express a rule.

- Every architectural change MUST solve an observable problem. Never skip levels. Stop escalating at the first "no".
- Before building a feature, classify it as **simple CRUD** (`Controller/Resolver → Application Service → Repository`) or **complex domain behavior** (`Adapter → Use Case → Aggregate/Domain Service → Port → Adapter`).
- Top-level packages under `com.redpetalsclosetllc.backend` are **business modules** (feature-first). NEVER create top-level `controller/`, `service/`, `repository/` or `entity/` packages.
- Add `domain/`, `application/`, `ports/` or `infrastructure/` inside a module only when its complexity justifies it. Modules may sit at different levels.
- A module exposes only what others need: an `api` package or published events. NEVER import another module's internal, `infrastructure` or persistence classes.
- Each module owns its tables. Name Flyway migrations with the owning module (e.g. `V3__catalog_create_listing.sql`). NEVER write to another module's tables.
- NEVER put framework types (Spring, JPA, Hibernate, servlet, HTTP clients) in `domain` code without a stated reason.
- GraphQL/REST input types and DTOs NEVER become domain models. Map them to application commands.
- Events between modules are **in-process first** (`ApplicationEventPublisher` + `@ApplicationModuleListener`). Event names are past-tense facts. NEVER add Kafka or RabbitMQ without a concrete durability or cross-process need.
- NEVER create `XService` + `XServiceImpl` without a real boundary or a second implementation.
- NEVER recommend extracting a microservice unless the skill's 10-question Mandatory Microservice Gate is answered convincingly.
- When the first business module is created, add a verification test: `ApplicationModules.of(BackendApplication.class).verify()`.

## Frontend architecture (MUST follow)

**Use the `nextjs-architecture-evolution` skill** for any frontend task that touches structure: reviews, refactors, new non-trivial pages or workflows, state/data decisions, Server vs Client boundaries, Server Actions or Route Handlers, real-time, or micro-frontend questions.

**Current state:** greenfield, Level 1 (only the default `app/`).
**Target shape:** a **modular frontend** in one Next.js app: `app/` (thin routes), `modules/<feature>/` (with a `public.ts` API), `shared/ui` and `shared/lib`, and `config/`. These sit at the existing root next to `app/`. There is no `src/`, and the alias `@/*` points to `./*`.

- Check Next.js APIs against `apps/frontend/node_modules/next/dist/docs/` before writing them (see [apps/frontend/AGENTS.md](apps/frontend/AGENTS.md)).
- Use Server Components by default. Push `"use client"` down to interactive leaves, and NEVER put it on `app/layout.tsx`.
- Classify each feature first. A **simple page** is a thin route, a Server Component fetch and a presentational component. A **business workflow** gets a `modules/<feature>/` with `ui/` and `infrastructure/`; add `domain/` and `application/` only when they're justified.
- Frontend modules follow **user workflows**. They may line up with backend modules, but NEVER mirror them mechanically.
- Modules import each other only through `@/modules/<x>/public`. When the second module appears, enforce this with ESLint `no-restricted-imports`.
- Pick the smallest state that works: URL, then server, then local, then reducer, then feature Context. NEVER add Zustand, Redux or TanStack Query without a concrete need.
- The Spring Boot backend is authoritative for validation and authorization. Frontend checks are UX only. Secrets stay in server-only code.
- NEVER build a second business backend in Route Handlers or Server Actions.

## Testing

Backend:
- Domain: plain JUnit, no Spring context.
- Use cases: fake or mock the output ports.
- Adapters: slice tests (`@WebMvcTest`, `@GraphQlTest`, `@DataJpaTest`, `@ApplicationModuleTest`).
- `@SpringBootTest` only for real integration. Never use it in place of domain tests.

Frontend (no test runner yet; add one when the first logic worth testing appears):
- Pure domain functions: unit tests without React.
- Components: rendering, interaction and accessibility. Don't test implementation details.
- E2E only for critical workflows.

## Working rules

- Change incrementally: every step compiles (backend) or type-checks and lints (frontend), and leaves tests green.
- Keep existing conventions and behavior unless the task says otherwise.
- NEVER reorganize the whole repo or rewrite a whole module unless asked.
- Architecture advice follows the relevant skill's output contract: assessment, problems with file paths, smallest next step, structure, dependencies, migration steps, what not to introduce yet, triggers for the next stage.

## Agent skills

| Skill | For |
|---|---|
| `spring-boot-architecture-evolution` | `apps/backend` |
| `nextjs-architecture-evolution` | `apps/frontend` |

The canonical copies live in `skills-example/skills/`, which is the only copy committed to git. `.claude/` and `.codex/` are git-ignored local installs, and `.claude/skills/` and `.codex/skills/` MUST stay byte-identical copies of the canonical ones. After cloning, or after editing a canonical copy, run from the repo root:

```bash
for s in spring-boot-architecture-evolution nextjs-architecture-evolution; do
  for d in .claude/skills .codex/skills; do
    mkdir -p "$d"
    rm -rf "${d:?}/${s:?}"
    cp -r "skills-example/skills/$s" "$d/"
    diff -r "skills-example/skills/$s" "$d/$s"
  done
done
```

Read-only architecture scans (run before any review):

```bash
bash skills-example/skills/spring-boot-architecture-evolution/scripts/scan-architecture.sh apps/backend
bash skills-example/skills/nextjs-architecture-evolution/scripts/scan-frontend.sh apps/frontend
```
