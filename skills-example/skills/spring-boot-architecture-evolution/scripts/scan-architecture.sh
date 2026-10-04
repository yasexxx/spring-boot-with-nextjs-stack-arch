#!/usr/bin/env bash
# scan-architecture.sh — READ-ONLY evidence scan for a Spring Boot (Java/Kotlin) project.
#
# Usage: scan-architecture.sh [project-dir] [large-file-threshold-lines]
#   project-dir                 default: current directory
#   large-file-threshold-lines  default: 400
#
# Prints heuristic signals only. Every finding MUST be confirmed by reading the
# code before it is reported as a problem. Never modifies files.

set -u

ROOT="${1:-.}"
THRESHOLD="${2:-400}"
MAX_LIST=15

if [ ! -d "$ROOT" ]; then
  echo "error: '$ROOT' is not a directory" >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd)"

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t scanarch)"
trap 'rm -rf "$TMP"' EXIT

section() { printf '\n== %s ==\n' "$1"; }
cap() { head -n "$MAX_LIST"; }
# Paths relative to ROOT for readability.
rel() { sed "s#$ROOT/##"; }

# grep across a file list (null-safe); prints matching file names.
grep_files() { # $1=list-file, rest=grep args
  local list="$1"; shift
  [ -s "$list" ] || return 0
  tr '\n' '\0' < "$list" | xargs -0 grep -l "$@" 2>/dev/null || true
}
# grep across a file list; prints file:line:match.
grep_lines() {
  local list="$1"; shift
  [ -s "$list" ] || return 0
  tr '\n' '\0' < "$list" | xargs -0 grep -Hn "$@" 2>/dev/null || true
}
count_lines() { [ -s "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }

# ---------------------------------------------------------------------------
# Collect sources (skip build output and tooling dirs)
find "$ROOT" \
  -type d \( -name target -o -name build -o -name out -o -name node_modules \
             -o -name .git -o -name .gradle -o -name .idea -o -name .mvn -o -name bin \) -prune \
  -o -type f \( -name '*.java' -o -name '*.kt' \) -print 2>/dev/null > "$TMP/all"

grep -v '/src/test/' "$TMP/all" > "$TMP/main" || true
grep '/src/test/' "$TMP/all" > "$TMP/test" || true

echo "Architecture scan: $ROOT"
echo "Main sources: $(count_lines "$TMP/main") | Test sources: $(count_lines "$TMP/test") | Large-file threshold: $THRESHOLD lines"

# ---------------------------------------------------------------------------
section "Build & stack"
find "$ROOT" -type d \( -name node_modules -o -name target -o -name build -o -name .git \) -prune \
  -o -type f \( -name pom.xml -o -name 'build.gradle' -o -name 'build.gradle.kts' -o -name 'settings.gradle*' \) -print 2>/dev/null \
  | rel | cap > "$TMP/buildfiles"
if [ -s "$TMP/buildfiles" ]; then
  echo "Build files:"; sed 's/^/  /' "$TMP/buildfiles"
  BUILD_CAT="$(sed "s#^#$ROOT/#" "$TMP/buildfiles" | tr '\n' '\0' | xargs -0 cat 2>/dev/null)"
  detect() { printf '%s' "$BUILD_CAT" | grep -qiE "$2" && echo "  [x] $1" || echo "  [ ] $1"; }
  echo "Detected dependencies:"
  detect "Spring Boot"            'spring-boot'
  detect "Spring MVC"             'starter-web([^f]|$)'
  detect "Spring WebFlux"         'webflux'
  detect "Spring GraphQL"         'graphql'
  detect "Spring Data JPA"        'data-jpa'
  detect "Flyway / Liquibase"     'flyway|liquibase'
  detect "Spring Modulith"        'spring-modulith'
  detect "ArchUnit"               'archunit'
  detect "Kafka"                  'kafka'
  detect "RabbitMQ / AMQP"        'amqp|rabbit'
  detect "Spring Cloud"           'spring-cloud'
  detect "Testcontainers"         'testcontainers'
  MODULE_COUNT="$(printf '%s' "$BUILD_CAT" | grep -cE '<module>|include\(' || true)"
  echo "Build sub-modules declared: ${MODULE_COUNT:-0}"
else
  echo "No Maven/Gradle build file found."
fi

if [ ! -s "$TMP/main" ]; then
  echo; echo "No main Java/Kotlin sources found — nothing further to analyze."
  echo "Hint: treat as Level 1 (greenfield). Do not add structure before there is code to justify it."
  exit 0
fi

# ---------------------------------------------------------------------------
section "Base package & top-level layout"
APP_FILE="$(grep_files "$TMP/main" -E '@SpringBootApplication' | head -n 1)"
if [ -n "$APP_FILE" ]; then
  BASE_PKG="$(grep -m1 -E '^[[:space:]]*package[[:space:]]' "$APP_FILE" | sed -E 's/^[[:space:]]*package[[:space:]]+//; s/[;[:space:]]+$//')"
  BASE_DIR="$(dirname "$APP_FILE")"
  echo "Application class: $(echo "$APP_FILE" | rel)"
  echo "Base package:      ${BASE_PKG:-<default>}"
  echo "Top-level packages under base (file count):"
  for d in "$BASE_DIR"/*/; do
    [ -d "$d" ] || continue
    n="$(grep -c "^${d}" "$TMP/main" || true)"
    printf '  %-28s %s\n' "$(basename "$d")" "$n"
  done > "$TMP/toplevel"
  if [ -s "$TMP/toplevel" ]; then cat "$TMP/toplevel"; else echo "  (none — all code in base package)"; fi

  LAYER_DIRS="$(awk '{print $1}' "$TMP/toplevel" | grep -cE '^(controller|controllers|service|services|repository|repositories|entity|entities|model|models|dto|dtos|web|rest)$' || true)"
  TOTAL_DIRS="$(count_lines "$TMP/toplevel")"
  if [ "${TOTAL_DIRS:-0}" -gt 0 ]; then
    if [ "${LAYER_DIRS:-0}" -ge 2 ] && [ "$LAYER_DIRS" -ge $((TOTAL_DIRS / 2)) ]; then
      echo "Hint: layer-first packaging (controller/service/repository at top) → typically Level 1."
    else
      echo "Hint: feature/business-first packaging → candidate bounded contexts / modules (Level 4–5 shape)."
    fi
  fi
else
  BASE_PKG=""; BASE_DIR=""
  echo "No @SpringBootApplication class found."
fi

# ---------------------------------------------------------------------------
section "Largest main source files (> $THRESHOLD lines)  [god-class candidates]"
tr '\n' '\0' < "$TMP/main" | xargs -0 wc -l 2>/dev/null | grep -v ' total$' \
  | awk -v t="$THRESHOLD" '$1 > t' | sort -rn | cap > "$TMP/large"
if [ -s "$TMP/large" ]; then rel < "$TMP/large" | sed 's/^/  /'; else echo "  none"; fi

# ---------------------------------------------------------------------------
section "Framework leaking into domain packages"
grep '/domain/' "$TMP/main" > "$TMP/domain" || true
if [ -s "$TMP/domain" ]; then
  grep_lines "$TMP/domain" -E \
    '^import[[:space:]]+(static[[:space:]]+)?(org\.springframework|jakarta\.persistence|javax\.persistence|org\.hibernate|org\.apache\.kafka|com\.rabbitmq|org\.springframework\.amqp|jakarta\.servlet|javax\.servlet|software\.amazon|redis\.clients|io\.lettuce|com\.fasterxml\.jackson)' \
    | rel | cap > "$TMP/leak_imports"
  grep_lines "$TMP/domain" -E '^[[:space:]]*@(Entity|Table|Component|Service|Repository|Configuration|RestController|Controller|Transactional)\b' \
    | rel | cap > "$TMP/leak_annos"
  echo "Domain files: $(count_lines "$TMP/domain")"
  echo "Framework imports in domain:";     if [ -s "$TMP/leak_imports" ]; then sed 's/^/  /' "$TMP/leak_imports"; else echo "  none"; fi
  echo "Framework annotations in domain:"; if [ -s "$TMP/leak_annos" ];   then sed 's/^/  /' "$TMP/leak_annos";   else echo "  none"; fi
  echo "Note: @Entity in domain can be acceptable for simple CRUD modules; judge by complexity."
else
  echo "No 'domain' packages present (normal for Level 1)."
fi

# ---------------------------------------------------------------------------
section "Cross-module access to internals"
if [ -n "$BASE_PKG" ] && [ -n "$BASE_DIR" ] && [ -s "$TMP/toplevel" ]; then
  : > "$TMP/cross"
  BASE_RE="$(printf '%s' "$BASE_PKG" | sed 's/\./\\./g')"
  for d in "$BASE_DIR"/*/; do
    [ -d "$d" ] || continue
    m="$(basename "$d")"
    grep "^${d}" "$TMP/main" > "$TMP/mod_$m" || true
    grep_lines "$TMP/mod_$m" -E \
      "^import[[:space:]]+(static[[:space:]]+)?${BASE_RE}\.[a-zA-Z0-9_]+\.([a-zA-Z0-9_.]*\.)?(infrastructure|persistence|repository|repositories|internal|adapter|adapters|jpa)\." \
      | grep -vE "import[[:space:]]+(static[[:space:]]+)?${BASE_RE}\.${m}\." >> "$TMP/cross" || true
  done
  if [ -s "$TMP/cross" ]; then
    echo "Imports of another top-level package's infrastructure/persistence/internal classes:"
    rel < "$TMP/cross" | cap | sed 's/^/  /'
    echo "  total: $(count_lines "$TMP/cross")"
  else
    echo "  none detected"
  fi
else
  echo "  skipped (no base package or no sub-packages)"
fi

# ---------------------------------------------------------------------------
section "Controllers touching persistence directly"
grep_files "$TMP/main" -E '@(RestController|Controller|QueryMapping|MutationMapping|SchemaMapping)\b' > "$TMP/controllers"
if [ -s "$TMP/controllers" ]; then
  echo "Controllers/resolvers: $(count_lines "$TMP/controllers")"
  grep_files "$TMP/controllers" -E '(Repository|EntityManager|JdbcTemplate)[[:space:]]+[a-zA-Z_]+' | rel | cap > "$TMP/ctrl_repo"
  if [ -s "$TMP/ctrl_repo" ]; then echo "Injecting Repository/EntityManager/JdbcTemplate:"; sed 's/^/  /' "$TMP/ctrl_repo"; else echo "  none inject persistence directly"; fi
else
  echo "  no controllers found"
fi

# ---------------------------------------------------------------------------
section "Interface-per-class (*Impl)"
grep -E 'Impl\.(java|kt)$' "$TMP/main" | rel | cap > "$TMP/impl"
if [ -s "$TMP/impl" ]; then
  sed 's/^/  /' "$TMP/impl"
  echo "Check each: single implementation and no boundary → remove the interface."
else
  echo "  none"
fi

# ---------------------------------------------------------------------------
section "Setter-driven state changes outside domain  [anemic-model candidates]"
grep -v '/domain/' "$TMP/main" > "$TMP/nondomain" || true
grep_lines "$TMP/nondomain" -E '\.set(Status|State|Approved[A-Za-z]*|Rejected[A-Za-z]*|Cancelled[A-Za-z]*|Closed[A-Za-z]*)\(' \
  | rel | cap > "$TMP/setters"
if [ -s "$TMP/setters" ]; then sed 's/^/  /' "$TMP/setters"; else echo "  none"; fi

# ---------------------------------------------------------------------------
section "Shared / dumping-ground packages"
grep -E '/(common|shared|util|utils|helper|helpers|core)/' "$TMP/main" \
  | sed -E 's#^(.*/(common|shared|util|utils|helper|helpers|core))/.*#\1#' | sort | uniq -c | sort -rn | rel | cap > "$TMP/shared"
if [ -s "$TMP/shared" ]; then sed 's/^/  /' "$TMP/shared"; echo "Check for domain-specific types living here."; else echo "  none"; fi

# ---------------------------------------------------------------------------
section "Events & messaging"
ev() { printf '  %-36s %s\n' "$1" "$(grep_files "$TMP/main" -E "$2" | wc -l | tr -d ' ')"; }
ev "ApplicationEventPublisher"        'ApplicationEventPublisher'
ev "@EventListener"                    '@EventListener\b'
ev "@TransactionalEventListener"       '@TransactionalEventListener\b'
ev "@ApplicationModuleListener"        '@ApplicationModuleListener\b'
ev "KafkaTemplate / @KafkaListener"    'KafkaTemplate|@KafkaListener'
ev "RabbitTemplate / @RabbitListener"  'RabbitTemplate|@RabbitListener'
ev "Outbox (name match)"               '[Oo]utbox'
ev "RestTemplate/RestClient/WebClient" 'RestTemplate|RestClient|WebClient|@FeignClient|@HttpExchange'

# ---------------------------------------------------------------------------
section "Tests"
if [ -s "$TMP/test" ]; then
  sbt="$(grep_files "$TMP/test" -E '@SpringBootTest\b' | wc -l | tr -d ' ')"
  slice="$(grep_files "$TMP/test" -E '@(WebMvcTest|DataJpaTest|GraphQlTest|JsonTest|RestClientTest|WebFluxTest|ApplicationModuleTest)\b' | wc -l | tr -d ' ')"
  arch="$(grep_files "$TMP/test" -E 'com\.tngtech\.archunit|ApplicationModules\.of' | wc -l | tr -d ' ')"
  total="$(count_lines "$TMP/test")"
  echo "  test files:                      $total"
  echo "  @SpringBootTest:                 $sbt"
  echo "  slice / module tests:            $slice"
  echo "  architecture tests (ArchUnit/Modulith verify): $arch"
  [ "$total" -gt 0 ] && [ "$sbt" -gt $((total / 2)) ] && echo "Hint: mostly full-context tests — domain logic may be hard to unit test."
else
  echo "  no tests found"
fi

# ---------------------------------------------------------------------------
section "Next"
echo "These are signals, not verdicts. Read the flagged files, classify the level per module,"
echo "and recommend only the smallest step that fixes a confirmed problem (see SKILL.md)."
exit 0
