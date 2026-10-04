# Frontend Architecture Assessment — <app / feature>

## 1. Current architecture
| Feature / module | Level | Evidence (paths) |
|---|---|---|
| <feature> | L<n> — <name> | <files that prove it> |

Next.js version: <x.y.z> (APIs verified against installed docs: yes/no)

## 2. Problems found
| # | Problem | Where | Impact |
|---|---|---|---|
| P1 | <e.g. 1,800-line page mixing fetch, dialogs, rules> | <path> | <change cost / bugs / bundle size> |

(No real problems → recommend **no structural change**.)

## 3. Recommended next stage
<Smallest step; link each item to P#.>

## 4. Proposed folder structure
```text
<affected feature(s) only>
```

## 5. Allowed dependencies / imports
```text
ui → application → domain
infrastructure → application/domain contracts
modules/a → @/modules/b/public        (allowed)
modules/a → @/modules/b/infrastructure (forbidden)
```

## 6. Migration steps
1. <step that type-checks, lints, keeps behavior>
2. …

## 7. Do not introduce yet
- <tool/pattern> — <why>

## 8. Next trigger
- <observable condition>
