---
name: spring-boot-architecture-evolution
description: >-
  Guides Spring Boot / Java backends through incremental architecture evolution
  (Clean Code -> Hexagonal -> DDD -> Bounded Contexts -> Modular Monolith ->
  Domain Events -> External Messaging -> Microservices), recommending only the
  smallest next step justified by an observable problem. Use whenever the task
  involves reviewing, assessing, restructuring or refactoring a Spring Boot
  codebase; deciding package/module structure; ports and adapters; aggregates,
  value objects or domain services; bounded contexts; Spring Modulith or
  ArchUnit boundaries; domain events, Kafka, RabbitMQ or transactional outbox;
  splitting a god service; or "should we move to microservices / extract this
  module". Also use before adding a non-trivial feature to a Spring Boot app.
  Do not use for non-JVM code or pure formatting/styling changes.
---

# Architecture Evolution — Spring Boot

Your job is to keep the architecture **as simple as possible** while keeping the system maintainable, testable and able to evolve. Reaching microservices is **not** the goal.

**Prime directive:** every architectural change MUST solve an observable, named problem in this codebase. "Best practice" is not a problem.

Prefer: simple over abstract · explicit over hidden dependencies · strong module boundaries over premature microservices · business-oriented over framework-oriented design · evolution over rewrites.

## The ladder

| Level | Stage | Move here only when… |
|---|---|---|
| 1 | Clean Code / Layered (Controller → Service → Repository) | default; CRUD, few integrations |
| 2 | Hexagonal (domain / application / ports / infrastructure) | infrastructure contaminates business logic |
| 3 | Tactical DDD (aggregates, VOs, policies) | the domain is genuinely complex (invariants, state transitions, calculations) |
| 4 | Bounded Contexts | business models with different language/rules are entangling |
| 5 | Modular Monolith | contexts need enforced isolation inside one deployable |
| 6 | Domain Events (in-process) | one action triggers independent reactions |
| 7 | External Messaging (Kafka/RabbitMQ + outbox) | durable, async or cross-process communication is required |
| 8 | Microservice-ready | a context passes the readiness checklist |
| 9 | Microservice extracted | the Mandatory Microservice Gate is passed convincingly |

Levels may differ **per module**. Never force every module to the same complexity. Details per level: [references/levels.md](references/levels.md).

## Step 0 — Route the task

| Task looks like | Mode |
|---|---|
| "review / assess / what's wrong with / how should we structure" | **A. Review** |
| changing existing code, splitting a class, moving logic | **B. Refactor** |
| adding a new capability | **C. New feature** |
| "microservice", "extract", "split the app", "Kafka", "scale independently" | **D. Microservice / messaging question** |

## Mode A — Review

1. **Understand before proposing.** Run the scanner (read-only) from the project root, then inspect what it flags:
   `bash <this-skill-dir>/scripts/scan-architecture.sh [project-dir]`
   Then read build files, package tree, controllers, services, repositories, entities, config, integrations, messaging, tests. Never propose architecture before this.
2. **Classify** the current level, per module where they differ, citing evidence (file paths).
3. **List pain points** with evidence. Look for: god services, cyclic deps, cross-module imports, persistence or framework in domain, business logic in controllers/repositories, duplicated rules, huge transactions, shared entities, modules editing others' tables, hard-to-test code, coupling-driven regressions. Signals and fixes: [references/anti-patterns.md](references/anti-patterns.md).
4. **Recommend the smallest next step** that fixes the listed problems — normally one level up, only for the affected module(s).
5. **Report** using [templates/assessment-report.md](templates/assessment-report.md). Each structural change gets an [architecture decision](templates/architecture-decision.md).

## Mode B — Refactor existing code

1. Identify the bounded context and the current level of the code you touch.
2. Preserve existing conventions where reasonable; improve **only** the relevant boundary.
3. Migrate strangler-style: move **one use case** at a time; leave the rest in place.
4. Keep behavior unchanged unless the task says otherwise.
5. Deliver compilable, reviewable steps; never reorganize the whole repository unless explicitly asked.
6. Do not introduce unrelated abstractions.

Playbook with the worked example: [references/refactoring-playbook.md](references/refactoring-playbook.md).

## Mode C — New feature

Classify first:

- **Simple CRUD** (lookup tables, config, reference data, admin screens) → `Controller → Application Service → Repository (+ DTO)`. No aggregates, no mappers, no ports.
- **Complex domain behavior** (approvals, payroll, posting, allocation, scheduling, credit, workflows) → `Adapter → Use Case → Aggregate / Domain Service → Port → Adapter`.

Place it inside the owning bounded context and match that module's existing level. Layer rules: [references/spring-boot-rules.md](references/spring-boot-rules.md).

## Mode D — Microservice / messaging question

- Events inside a monolith → **in-process first** (`ApplicationEventPublisher` / Spring Modulith events). A broker needs a concrete requirement (durability, retries, independent consumers, external integration, cross-process, volume).
- Extraction → answer **all 10 questions of the Mandatory Microservice Gate** in [references/events-messaging-microservices.md](references/events-messaging-microservices.md), in writing. If any answer is unconvincing, recommend strengthening the modular monolith instead and say which gate item failed.
- Extract **one** bounded context at a time; it owns its database; no distributed ACID.

## Escalation flow — STOP at the first NO

```text
Code hard to understand?                          YES → Clean Code
Business rules coupled to infrastructure?         YES → Hexagonal boundaries
Domain genuinely complex?                         YES → Tactical DDD
Multiple business models entangling?              YES → Bounded Contexts
Contexts need stronger internal isolation?        YES → Modular Monolith
One action triggers independent reactions?        YES → Domain Events (in-process)
Durable async cross-process communication needed? YES → Messaging
Context needs independent deploy/scale/isolation? YES → Evaluate extraction (Gate)
```

If the answer at a stage is NO, stop there. Do not continue escalating.

## Hard rules (NEVER)

- NEVER jump more than one level at once (e.g. layered → microservices).
- NEVER introduce DDD constructs for plain CRUD, or a value object for a trivial field with no rule.
- NEVER create `XService` + `XServiceImpl` when there is one implementation and no boundary.
- NEVER put Spring/JPA/Hibernate/Kafka/HTTP-client/servlet types or `@Entity @Service @Component @Repository @Configuration` in domain code without a strong, stated reason.
- NEVER import another module's `infrastructure`/`persistence`/internal classes; use its public API or events.
- NEVER let one module casually write another module's tables.
- NEVER let REST/GraphQL request DTOs become domain models.
- NEVER add Kafka/RabbitMQ just because events exist; NEVER add event sourcing or CQRS just because events or queries exist.
- NEVER save-to-DB then publish-to-broker as two unrelated operations when consistency matters — use a transactional outbox.
- NEVER share one database across independently deployed services; NEVER recreate ACID transactions across services.
- NEVER rewrite a whole module/repository unless explicitly requested.
- NEVER answer with bare slogans ("use Clean Architecture / DDD / microservices"). Say exactly **where** and **why**.

## Reject weak justifications

Treat these as **insufficient** and say so: "microservices are modern", "we might scale someday", "Netflix does it", "the module has many classes", "we want Kafka", "we want Kubernetes", "it's best practice".

## Output contract

For architecture advice, always give:

1. Current architecture assessment (level per module, with evidence)
2. Problems found (concrete, with file paths)
3. Recommended next stage (smallest step)
4. Concrete package/module structure
5. Example dependencies (what may depend on what)
6. Migration steps (incremental, compilable)
7. What **not** to introduce yet
8. Conditions that would justify the next stage

Templates: [templates/assessment-report.md](templates/assessment-report.md), [templates/architecture-decision.md](templates/architecture-decision.md).

## Reference index — load only what the task needs

| File | Load when |
|---|---|
| [references/levels.md](references/levels.md) | classifying a level or designing a target structure |
| [references/spring-boot-rules.md](references/spring-boot-rules.md) | writing/reviewing layer code: domain, application, infrastructure, JPA, repositories, interfaces, DTOs, visibility, ArchUnit/Modulith, tests |
| [references/events-messaging-microservices.md](references/events-messaging-microservices.md) | events, brokers, outbox, sagas, extraction, inter-service communication |
| [references/anti-patterns.md](references/anti-patterns.md) | reviewing code or explaining a smell |
| [references/refactoring-playbook.md](references/refactoring-playbook.md) | performing an incremental migration or adding a feature to existing code |

Final principle: architecture exists to support the business and the engineering team — never make the business support the architecture.
