# Spring Boot Layer & Design Rules

Contents: [Domain](#domain-layer) · [Application](#application-layer) · [Infrastructure](#infrastructure-layer) · [JPA](#jpa-rules) · [Repositories](#repository-rules) · [Interfaces](#interface-rule) · [DTOs](#dto-rules) · [Visibility](#package-visibility) · [Dependency validation](#dependency-validation) · [Spring Modulith](#spring-modulith) · [Testing](#testing-strategy)

---

## Domain layer

Prefer plain Java (`public class PurchaseOrder { }`, records for value objects).

Avoid inside domain code unless strongly justified:

```java
@Entity  @Table  @Component  @Service  @Repository  @Configuration
```

No imports from `org.springframework.*`, `jakarta.persistence.*`, `org.hibernate.*`, messaging clients, HTTP clients, servlet APIs.

## Application layer

Application services (use cases) **coordinate**. They may:
- load aggregates
- invoke domain behavior
- persist changes
- publish events
- call output ports

They should **not** hold large amounts of business logic that belongs in the domain. Transaction boundaries (`@Transactional`) usually live here — keep them as small as the use case.

## Infrastructure layer

Handles Spring MVC / GraphQL controllers, Spring Data JPA, JDBC, REST clients, messaging, persistence mapping, external APIs, security integration and framework configuration. Adapters implement ports; controllers translate requests into application commands.

## JPA rules

- Do not automatically expose JPA entities as domain objects.
- For **simple CRUD** modules, using JPA entities directly is acceptable.
- For **complex domains**, consider `Domain Model ↔ mapper ↔ Persistence Entity`.
- Do not create mapping layers without a reason. **Complexity is the deciding factor.**

## Repository rules

Repository interfaces express domain/application needs. Avoid generic `BaseRepository<T, ID>` that leaks persistence semantics everywhere. Prefer intention-revealing interfaces:

```java
public interface PurchaseOrderRepository {

    Optional<PurchaseOrder> findById(PurchaseOrderId id);

    void save(PurchaseOrder purchaseOrder);
}
```

The Spring Data interface (`JpaPurchaseOrderRepository extends JpaRepository<…>`) stays in infrastructure and backs an adapter implementing the port.

## Interface rule

Create an interface only when it represents:
- an architectural boundary
- an external dependency
- an alternative implementation
- a testing seam with real value
- a domain/application contract

Avoid `EmployeeService` + `EmployeeServiceImpl` when only one implementation exists and no boundary is created.

## DTO rules

DTOs live at application or adapter boundaries. REST/GraphQL request DTOs never become domain models.

```text
HTTP/GraphQL Request DTO → Application Command → Domain
```

## Package visibility

- Use package-private visibility to protect module internals.
- Expose only the APIs another module actually needs.
- Do not make everything `public`.

## Dependency validation

Enforce architecture with tests or build tooling when possible: ArchUnit, Java modules (JPMS), Maven/Gradle module boundaries, Spring Modulith.

Example rules:

```text
purchasing.domain   must not depend on   purchasing.infrastructure
accounting          must not access      inventory.infrastructure.persistence
```

ArchUnit sketch:

```java
@AnalyzeClasses(packages = "com.company.system")
class ArchitectureTest {

    @ArchTest
    static final ArchRule domainIsFrameworkFree = noClasses()
        .that().resideInAPackage("..domain..")
        .should().dependOnClassesThat()
        .resideInAnyPackage("org.springframework..", "jakarta.persistence..", "org.hibernate..");

    @ArchTest
    static final ArchRule noCrossModuleInfrastructure = noClasses()
        .that().resideInAPackage("..purchasing..")
        .should().dependOnClassesThat()
        .resideInAPackage("..inventory.infrastructure..");
}
```

Add the rule that protects the boundary you just created — not a wall of speculative rules.

## Spring Modulith

Consider it for modular monoliths **when it provides real value**: module verification (`ApplicationModules.of(App.class).verify()`), generated module documentation, application events with an event publication registry, `@ApplicationModuleTest` module integration tests, clearer boundaries.

Do not introduce it solely because the project uses Spring Boot. If it is already on the classpath, use its verification test to enforce the boundaries you define rather than adding a second mechanism.

## Testing strategy

Match tests to the architectural level.

| Test type | What | Spring context? |
|---|---|---|
| Domain | invariants, value objects, aggregate behavior, policies | **No** — fast unit tests |
| Application | use-case orchestration; fake/mock output ports | Usually no |
| Adapter | REST/GraphQL mapping, persistence, messaging, external APIs | Slice tests (`@WebMvcTest`, `@DataJpaTest`, `@GraphQlTest`) |
| Integration | real infrastructure interactions (e.g. Testcontainers) | Yes |

Do not replace domain tests with large `@SpringBootTest` integration tests.
