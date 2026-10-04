# Refactoring Playbook

## Rules for existing code

1. Identify the bounded context.
2. Identify the current architecture level.
3. Preserve existing conventions when reasonable.
4. Improve only the relevant boundary.
5. Do not introduce unrelated abstractions.
6. Keep changes incremental.
7. Keep existing behavior unless the task explicitly changes it.
8. Prefer compilable, reviewable steps (each step builds and tests pass).

Do not reorganize the whole repository without need. Do not rewrite a whole module at once unless specifically requested.

## Never skip levels

Current: `Controller → Service → Repository`
Problem: `PurchaseOrderService` has 2,500 lines and mixes business rules with JPA and REST calls.

Recommend:

```text
Extract purchasing domain
Introduce application use cases
Create output ports for external dependencies
```

Do **not** recommend: 10 microservices, Kafka, Kubernetes, service mesh, CQRS, event sourcing — unless requirements justify them.

## Strangler-style migration of one use case

Existing:

```text
purchasing/
    PurchaseOrderController
    PurchaseOrderService
    PurchaseOrderRepository
```

Move one use case (e.g. approval):

```text
purchasing/
├── legacy/
│   └── PurchaseOrderService          (everything not yet migrated)
├── domain/
│   └── PurchaseOrder                 (approve(...) with invariants)
├── application/
│   └── ApprovePurchaseOrder          (use case: load → approve → save → publish)
├── ports/
│   └── PurchaseOrderRepository       (intention-revealing port)
└── infrastructure/
    └── JpaPurchaseOrderRepository    (adapter implementing the port)
```

Step sequence (each step compiles and passes tests):

1. **Pin behavior:** add/confirm tests covering the use case as it works today.
2. **Extract domain behavior:** move rules into `PurchaseOrder.approve(...)`; add fast domain unit tests.
3. **Introduce the port** for persistence/external calls the use case needs; implement it with an adapter wrapping the existing repository/client.
4. **Create the use case** class; the controller calls it instead of the legacy service method.
5. **Delete the migrated method** from the legacy service.
6. **Lock the boundary:** add one ArchUnit/Modulith rule protecting what you just created.
7. Repeat for the next use case only when there is a reason.

## New feature shapes

Classify first: **Simple CRUD** or **Complex Domain Behavior**.

CRUD:

```text
Controller → Application Service → Repository
```

Complex domain behavior:

```text
Adapter (web/graphql/messaging)
    ↓
Use Case (application)
    ↓
Aggregate / Domain Service (domain)
    ↓
Port (ports/out)
    ↓
Adapter (infrastructure)
```

Use architecture proportionally — match the owning module's current level unless the feature itself is the trigger to move up one level (then state the trigger explicitly).

## Worked architecture decision

**Current Problem** — `PurchaseOrderService` handles validation, approval rules, budget checking, database access, inventory calls and notifications.

**Smallest Change** — introduce `purchasing/domain`, `purchasing/application`, `purchasing/ports`, `purchasing/infrastructure`; move approval logic into the domain; create `BudgetAvailabilityPort` and `InventoryAvailabilityPort`.

**Why Now** — mixed business and infrastructure responsibilities make testing and modification difficult.

**Do Not Introduce Yet** — Kafka, microservices, saga, Kubernetes, event sourcing.

**Future Evolution** — once Purchasing and Inventory are clear bounded contexts, communication can move from direct application contracts to domain events, and later to external messaging if required.
