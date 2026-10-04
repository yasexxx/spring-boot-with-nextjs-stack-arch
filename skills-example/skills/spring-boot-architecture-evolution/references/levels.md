# Architecture Levels — Detail

Contents: [L1 Clean Code](#level-1--clean-code--layered) · [L2 Hexagonal](#level-2--hexagonal-architecture) · [L3 DDD](#level-3--tactical-domain-driven-design) · [L4 Bounded Contexts](#level-4--bounded-contexts) · [L5 Modular Monolith](#level-5--modular-monolith) · [L6 Domain Events](#level-6--domain-events) · [L7 External Messaging](#level-7--external-messaging) · [L8 Microservice-ready](#level-8--microservice-candidate) · [L9 Microservices](#level-9--microservice-extraction) · [Classification cheat-sheet](#classification-cheat-sheet)

---

## Level 1 — Clean Code / Layered

**Characteristics**
- Controller → Service → Repository is acceptable.
- Business logic relatively simple; modules small; few integrations; simple deployment; mostly CRUD.

**Primary concerns:** naming, readability, method size, duplication, responsibilities, testability, dependency clarity.

**Do not** introduce DDD merely for simple CRUD.

```java
@Service
public class EmployeeService {

    private final EmployeeRepository repository;

    public EmployeeService(EmployeeRepository repository) {
        this.repository = repository;
    }

    public Employee create(CreateEmployeeRequest request) {
        validate(request);

        Employee employee = new Employee(
            request.name(),
            request.departmentId()
        );

        return repository.save(employee);
    }
}
```

This is acceptable when the business logic is simple.

---

## Level 2 — Hexagonal Architecture

**Move here when infrastructure concerns contaminate business/application logic.** Triggers:
- services depend directly on external APIs
- persistence logic leaks everywhere
- changing databases affects business code
- controllers contain business rules
- testing requires a Spring context unnecessarily
- domain logic depends on framework classes
- infrastructure dependencies are hard to replace

**Target structure (per module)**

```text
module/
├── domain/
├── application/
├── ports/
│   ├── in/
│   └── out/
└── infrastructure/
    ├── web/
    ├── persistence/
    ├── messaging/
    └── external/
```

**Dependency direction:** `Infrastructure → Application → Domain`. Infrastructure may depend inward; domain must not depend outward.

**Domain code must not know about:** Spring MVC, Spring Data, Hibernate, JPA, Kafka, RabbitMQ, REST clients, GraphQL, SMTP, AWS SDKs, Redis clients, servlet APIs. Avoid framework annotations in domain models unless there is a very strong reason.

Port (owned by application/domain):

```java
public interface PaymentGateway {
    PaymentResult charge(PaymentRequest request);
}
```

Adapter (infrastructure):

```java
@Component
public class StripePaymentAdapter implements PaymentGateway {
}
```

Application/domain code depends on `PaymentGateway`, never on `StripePaymentAdapter`.

---

## Level 3 — Tactical Domain-Driven Design

**Introduce only for areas with meaningful business complexity:** complex invariants, multi-step rules, state transitions, policies, calculations, business-specific terminology, workflows that are not cleanly CRUD.

- Do not turn every table into an aggregate.
- Do not create value objects for trivial fields unless they enforce meaningful rules.

**Building blocks (use only when justified):** Entity, Aggregate, Aggregate Root, Value Object, Domain Service, Domain Event, Repository, Factory, Specification, Policy.

```java
public class PurchaseOrder {

    private final PurchaseOrderId id;
    private PurchaseOrderStatus status;
    private Money total;

    public void approve(ApprovalPolicy policy) {
        policy.validate(this);

        if (status != PurchaseOrderStatus.PENDING) {
            throw new InvalidPurchaseOrderStateException();
        }

        status = PurchaseOrderStatus.APPROVED;
    }
}
```

Business rules that represent domain behavior belong in the domain. Avoid `purchaseOrder.setStatus(APPROVED);` when approval has business meaning; prefer `purchaseOrder.approve(policy);`.

### CRUD vs domain logic — classify every feature first

| Simple CRUD | Complex domain |
|---|---|
| lookup tables, configuration values, reference data, simple admin screens | purchase-order approval, payroll calculation, accounting posting, inventory allocation, manufacturing scheduling, credit approval, repair workflows |
| Controller → Application Service → Repository → DTO | Aggregates, value objects, policies, domain services, ports |

---

## Level 4 — Bounded Contexts

**Introduce when business areas develop:** different terminology, different rules, separate ownership, separate data responsibilities, conflicting models for similar concepts, growing coupling.

Typical contexts: Purchasing, Inventory, Accounting, HR, Production, Sales, Quality.

Each context owns its own model. No universal shared model:

```text
Purchasing:  Supplier
Accounting:  Payee
Inventory:   VendorReference
```

Same real-world company, different domain purposes.

**Rules**
- A context must not directly manipulate another context's internal domain objects.
- Avoid `inventoryRepository.updateStockFromPurchasing(...)` from Purchasing.
- Prefer explicit communication — an event (`Purchasing → PurchaseOrderApproved → Inventory`) or an explicit application-facing interface.
- Do not import internal package classes from another context.

---

## Level 5 — Modular Monolith

Normally preferred **before** microservices. Still `1 application · 1 deployment · 1 JVM · 1 repository`, but with strong internal boundaries.

```text
com.company.system
├── purchasing
│   ├── api            (public contracts other modules may use)
│   ├── domain
│   ├── application
│   ├── ports
│   └── infrastructure
├── inventory
│   └── … same shape
├── accounting
│   └── … same shape
└── hr
    └── … same shape
```

**Each module:** owns its domain, use cases and persistence adapter; exposes only explicit public interfaces; never accesses another module's internals.

```java
// BAD — from Purchasing
import com.company.inventory.infrastructure.persistence.InventoryJpaRepository;

// GOOD
import com.company.inventory.api.InventoryQuery;
```

…or communicate via domain events.

**Database:** one physical database is fine initially, but ownership must be explicit — schemas (`purchasing.*`, `inventory.*`, `accounting.*`, `hr.*`) or clear table-ownership conventions. One module must not casually modify another's tables. Data ownership follows bounded contexts as far as reasonable.

Enforce boundaries with ArchUnit / Spring Modulith / build modules — see [spring-boot-rules.md](spring-boot-rules.md#dependency-validation).

---

## Level 6 — Domain Events

Introduce when one business action has consequences that should be decoupled (e.g. `PurchaseOrderApproved` → Accounting, Inventory, Notifications, Analytics). In a monolith, publish **in-process first**. Full rules: [events-messaging-microservices.md](events-messaging-microservices.md#domain-events).

## Level 7 — External Messaging

Kafka/RabbitMQ only for concrete needs: durability, retries, independent consumers, external integration, high volume, process isolation, independent deployment, eventual consistency. Use a transactional outbox when events mirror DB changes. Full rules: [events-messaging-microservices.md](events-messaging-microservices.md#external-messaging).

## Level 8 — Microservice candidate

Requires the readiness checklist and the Mandatory Gate: [events-messaging-microservices.md](events-messaging-microservices.md#microservice-readiness-checklist).

## Level 9 — Microservice extraction

One bounded context at a time, database per service, explicit contracts: [events-messaging-microservices.md](events-messaging-microservices.md#extraction).

---

## Classification cheat-sheet

| Evidence in the code | Likely level |
|---|---|
| `controller/ service/ repository/ entity/` top-level packages; JPA entities everywhere | 1 |
| Port interfaces for external systems; adapters under `infrastructure`; domain free of framework imports | 2 |
| Aggregates with behavior methods, value objects with invariants, policies; no public setters for state transitions | 3 |
| Top-level packages per business area with separate models for overlapping concepts | 4 |
| Per-module `api` packages, package-private internals, ArchUnit/Modulith verification, schema per module | 5 |
| `ApplicationEventPublisher` / `@ApplicationModuleListener` / `@TransactionalEventListener` between modules | 6 |
| Kafka/RabbitMQ/SQS clients, outbox table, idempotent consumers | 7 |
| A module with own data, only contract-based dependencies, events for interactions | 8 |
| Separate deployables with their own databases | 9 |
