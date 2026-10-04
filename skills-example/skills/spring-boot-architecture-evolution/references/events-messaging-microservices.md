# Events, Messaging & Microservices

Contents: [Domain events](#domain-events) · [External messaging](#external-messaging) · [Reliable messaging / outbox](#reliable-messaging) · [Readiness checklist](#microservice-readiness-checklist) · [Mandatory Gate](#mandatory-microservice-gate) · [Extraction](#extraction) · [Database per service](#database-per-service) · [Inter-service communication](#inter-service-communication) · [Distributed transactions](#distributed-transactions)

---

## Domain events

Introduce when one business action has consequences that should be decoupled.

```text
PurchaseOrderApproved → Accounting, Inventory, Notifications, Analytics
```

**Naming:** events are facts that already happened, in past tense.

| Good (event) | Bad (command in disguise) |
|---|---|
| `PurchaseOrderApproved`, `StockReserved`, `InvoiceIssued`, `EmployeeHired`, `PaymentReceived` | `ApprovePurchaseOrder`, `SendInvoice`, `ReserveStock` |

### Internal event first

In a monolith, publish in-process:

```java
applicationEventPublisher.publishEvent(
    new PurchaseOrderApproved(...)
);
```

- Listeners that must only run after commit: `@TransactionalEventListener(phase = AFTER_COMMIT)` or Spring Modulith `@ApplicationModuleListener` (async, transactional, with publication registry if configured).
- Events carry identifiers and the facts consumers need — not mutable aggregates or JPA entities.
- Do **not** introduce Kafka just because events exist.

## External messaging

Introduce Kafka, RabbitMQ or another broker only for concrete requirements:
- durable asynchronous processing
- retries
- independent consumers
- integration with external systems
- high event volume
- service isolation / cross-process communication
- independent deployment
- eventual consistency

Never introduce a broker merely to appear scalable.

## Reliable messaging

When events correspond to database changes, consider the **transactional outbox**:

```text
Application Transaction
    │
    ├── update business data
    │
    └── insert outbox event
             │
             ▼
      Outbox Publisher
             │
             ▼
           Broker
```

Avoid `save database` then `publish Kafka` as two unrelated operations when consistency matters.

Also consider:
- idempotent consumers (dedupe by event id)
- retry strategy with backoff
- dead-letter queues
- event versioning / schema evolution
- correlation IDs for tracing

(Spring Modulith's event publication registry plus externalization can serve as an outbox in a Spring Boot monolith.)

---

## Microservice readiness checklist

A bounded context is a reasonable extraction candidate when **most** of these hold:

- [ ] clear domain boundary exists
- [ ] module has explicit APIs
- [ ] module does not depend on another module's repositories
- [ ] module owns its data
- [ ] module communicates through explicit contracts
- [ ] transactions across contexts are minimized
- [ ] domain events already model important interactions
- [ ] operational benefit outweighs distributed-system complexity

If not, **improve the modular monolith first** and say which items are missing.

**Valid reasons for extraction:** independent scaling, separate deployment cadence, strong team ownership, fault isolation, regulatory/security boundary, significantly different availability requirements, heavy workload isolated to one domain, independent technology requirements, integration boundaries, organizational ownership.

**Weak reasons (reject):** "Microservices are modern." · "We might scale someday." · "Netflix uses microservices." · "The module has many classes." · "We want Kafka." · "We want Kubernetes."

## Mandatory Microservice Gate

Answer every question **in writing** before recommending extraction:

1. What concrete problem cannot reasonably be solved within the modular monolith?
2. Does the candidate correspond to a clear bounded context?
3. Can it own its data?
4. Can it expose an explicit API or event contract?
5. Are cross-context transactions limited?
6. Is independent deployment useful?
7. Is independent scaling useful?
8. Does fault isolation matter?
9. Is the team prepared for distributed tracing, deployment automation, service monitoring, retries, timeout handling, message duplication, network failures, schema evolution and distributed debugging?
10. Is the operational cost justified?

If these cannot be answered convincingly → recommend keeping the functionality in the modular monolith, and name the failing questions.

## Extraction

Extract **one bounded context at a time** (never several simultaneously unless explicitly required).

Before:

```text
ERP Application
├── Purchasing
├── Inventory
├── Accounting
└── HR
```

After:

```text
ERP Application
├── Purchasing
├── Accounting
└── HR
        │
        ├── REST/gRPC
        └── Messaging
              │
              ▼
       Inventory Service
              │
              ▼
        Inventory Database
```

Suggested order: (1) module already passes boundary verification → (2) replace in-process calls with the contract it will expose → (3) move its schema to a separate database → (4) deploy separately behind the same contract → (5) remove the in-monolith code.

## Database per service

```text
Purchasing Service → Purchasing DB
Inventory Service  → Inventory DB
Accounting Service → Accounting DB
```

Avoid:

```text
Purchasing Service ─┐
Inventory Service  ─┼── Shared Database
Accounting Service ─┘
```

A shared database across independently deployed services is a distributed monolith.

## Inter-service communication

Choose by semantics:

- **REST / gRPC** — caller needs an immediate answer (e.g. Purchasing checks stock availability in Inventory). Always set timeouts; plan for failure.
- **Messaging** — communicating facts or asynchronous work (e.g. `PurchaseOrderApproved` → broker → Accounting).

Do not use events as disguised RPC (publish-and-wait-for-reply for something that needs an immediate answer).

## Distributed transactions

Do not recreate ACID across services:

```text
begin transaction
  update purchasing DB
  update inventory DB
  update accounting DB
commit          ← NEVER
```

Prefer eventual consistency. For multi-service workflows consider — only when needed — Saga (choreography or orchestration), process manager, compensating actions, idempotency, durable events.
