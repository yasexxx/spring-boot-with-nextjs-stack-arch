# Anti-Patterns to Detect

For each finding, report: **where** (file paths), **signal** observed, **impact**, **smallest fix**. `scripts/scan-architecture.sh` surfaces several of these automatically; confirm by reading the code before reporting.

| Anti-pattern | Detection signals | Smallest fix |
|---|---|---|
| **God service** | Service class with thousands of lines; many unrelated dependencies injected; methods for many use cases | Split by business capability / use case; move rules into the domain |
| **Anemic domain with complex logic** | `setStatus`, `setApprovedBy`, `setApprovedAt` sequences repeated across services | Behavior method on the aggregate, e.g. `order.approve(approver, now)` |
| **Business logic in controllers** | `if`/calculations/state changes in `@RestController` / `@Controller` / GraphQL resolvers | Move into a use case or domain method; controller only maps |
| **Business logic in repositories** | Rule-bearing `@Query` or default methods doing decisions | Keep query in repo; move decision into domain/application |
| **Framework in domain** | `org.springframework`, `jakarta.persistence`, `org.hibernate`, HTTP/messaging imports under `..domain..` | Port + adapter; separate persistence entity only if complexity warrants |
| **Cross-module repository access** | Purchasing imports `inventory..repository` / `inventory..infrastructure..` | Inventory exposes `api` query/command or an event |
| **Modules editing others' tables** | Native SQL / entities mapped to another module's tables | Ownership per schema; go through owning module's API |
| **Cyclic module dependencies** | A imports B and B imports A | Introduce an event or move the shared concept to its true owner |
| **Shared-everything module** | `common/`, `shared/`, `utils/`, `helpers/` containing domain types | Move domain concepts to their context; keep only truly generic code |
| **Interface per class** | `FooService` + `FooServiceImpl`, single implementation, no boundary | Delete the interface; keep the class |
| **Large transaction boundaries** | `@Transactional` on class level spanning remote calls or multiple modules | Narrow to the use case; move side effects after commit (events) |
| **Premature event sourcing** | Event store introduced with no audit/temporal/replay requirement | Remove; keep state-based persistence + domain events |
| **Premature CQRS** | Separate read/write models for every entity with identical shapes | Collapse; split only where read and write models genuinely diverge |
| **Premature Kafka** | Broker used for in-process reactions inside one deployable | Replace with in-process events until a durability/cross-process need exists |
| **Premature microservices** | Several deployables sharing one DB, synchronous call chains, distributed debugging pain | Merge back into a modular monolith; re-extract only after the Gate |

## Examples

God service:

```text
PurchaseOrderService.java — 4,000 lines
```
→ refactor by business capability/use case.

Anemic domain:

```java
order.setStatus("APPROVED");
order.setApprovedBy(user);
order.setApprovedAt(now);
```
spread across services → prefer `order.approve(approver, now);` when approval is meaningful domain behavior.

Cross-module repository access:

```text
Bad:    Purchasing → InventoryRepository
Better: Purchasing → Inventory API / Event
```

Default position on microservices: **keep the bounded context inside the modular monolith.** Extraction must be justified.
