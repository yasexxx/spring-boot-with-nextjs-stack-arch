# Architecture Assessment — <system / module name>

## 1. Current architecture
| Module / context | Level | Evidence (paths) |
|---|---|---|
| <module> | L<n> — <name> | <files/packages that prove it> |

## 2. Problems found
| # | Problem | Where | Impact |
|---|---|---|---|
| P1 | <concrete issue, e.g. god service 2,500 lines mixing JPA + REST> | <path> | <testing / change cost / regressions> |

(If no real problems: say so and recommend **no structural change**.)

## 3. Recommended next stage
<Smallest step, e.g. "Hexagonal boundaries for `purchasing` only". Link each recommendation to P#.>

## 4. Target package/module structure
```text
<concrete tree for the affected module(s) only>
```

## 5. Allowed dependencies
```text
infrastructure → application → domain
<module A> → <module B>.api   (allowed)
<module A> → <module B>.infrastructure   (forbidden)
```

## 6. Migration steps
1. <compilable, reviewable step>
2. …
(Each step keeps behavior and leaves tests green.)

## 7. Do not introduce yet
- <pattern/technology> — <why not justified today>

## 8. Conditions that would justify the next stage
- <observable trigger, e.g. "a second consumer needs PurchaseOrderApproved asynchronously and durably">
