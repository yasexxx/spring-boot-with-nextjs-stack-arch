#!/usr/bin/env bash
# scan-frontend.sh — READ-ONLY evidence scan for a Next.js / React project.
#
# Usage: scan-frontend.sh [frontend-dir] [large-file-threshold-lines]
#   frontend-dir                directory containing package.json (default: current directory)
#   large-file-threshold-lines  default: 300
#
# Prints heuristic signals only. Every finding MUST be confirmed by reading the
# code before it is reported as a problem. Never modifies files.

set -u

ROOT="${1:-.}"
THRESHOLD="${2:-300}"
MAX_LIST=15

if [ ! -d "$ROOT" ]; then
  echo "error: '$ROOT' is not a directory" >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd)"

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t scanfe)"
trap 'rm -rf "$TMP"' EXIT

section() { printf '\n== %s ==\n' "$1"; }
cap() { head -n "$MAX_LIST"; }
rel() { sed "s#$ROOT/##"; }
count_lines() { [ -s "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }
grep_files() { # $1=list-file, rest=grep args → matching file names
  local list="$1"; shift
  [ -s "$list" ] || return 0
  tr '\n' '\0' < "$list" | xargs -0 grep -l "$@" 2>/dev/null || true
}
grep_lines() { # $1=list-file, rest=grep args → file:line:match
  local list="$1"; shift
  [ -s "$list" ] || return 0
  tr '\n' '\0' < "$list" | xargs -0 grep -Hn "$@" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Collect sources (skip build output, deps, tooling)
find "$ROOT" \
  -type d \( -name node_modules -o -name .next -o -name out -o -name build -o -name dist \
             -o -name coverage -o -name .git -o -name .turbo -o -name .vercel \) -prune \
  -o -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' \) \
  ! -name '*.d.ts' ! -name '*.config.*' -print 2>/dev/null > "$TMP/all"

grep -E '\.(test|spec)\.[jt]sx?$|/__tests__/|/e2e/|/tests?/' "$TMP/all" > "$TMP/test" || true
grep -vE '\.(test|spec)\.[jt]sx?$|/__tests__/|/e2e/|/tests?/' "$TMP/all" > "$TMP/main" || true

if [ -d "$ROOT/src/app" ] || [ -d "$ROOT/src/pages" ]; then SRC="$ROOT/src"; else SRC="$ROOT"; fi

echo "Frontend scan: $ROOT"
echo "Source root: $(echo "$SRC/" | rel | sed 's#^$#./#') | Main files: $(count_lines "$TMP/main") | Test files: $(count_lines "$TMP/test") | Large-file threshold: $THRESHOLD lines"

# ---------------------------------------------------------------------------
section "package.json & libraries"
PKG="$ROOT/package.json"
if [ -f "$PKG" ]; then
  ver() { grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" "$PKG" | head -n1 | sed -E 's/.*"([^"]+)"$/\1/'; }
  echo "  next:  $(ver next)"
  echo "  react: $(ver react)"
  has() { grep -qE "\"($2)\"[[:space:]]*:" "$PKG" && echo "  [x] $1" || echo "  [ ] $1"; }
  has "TanStack Query"            '@tanstack/react-query'
  has "SWR"                       'swr'
  has "Zustand"                   'zustand'
  has "Redux / RTK"               'redux|@reduxjs/toolkit|react-redux'
  has "Jotai / Recoil"            'jotai|recoil'
  has "React Hook Form"           'react-hook-form'
  has "Zod / Valibot"             'zod|valibot'
  has "server-only"               'server-only'
  has "Vitest / Jest"             'vitest|jest'
  has "Testing Library"           '@testing-library/react'
  has "Playwright / Cypress"      '@playwright/test|cypress'
  has "Module Federation"         '@module-federation/[^"]+|@module-federation/nextjs-mf'
  has "eslint-plugin-boundaries"  'eslint-plugin-boundaries'
  [ -d "$ROOT/node_modules/next/dist/docs" ] && echo "Version docs: node_modules/next/dist/docs/ present — read them before writing Next.js API code."
else
  echo "  no package.json in $ROOT"
fi

if [ ! -s "$TMP/main" ]; then
  echo; echo "No source files found — nothing further to analyze."
  echo "Hint: treat as Level 1. Do not add structure before there is code to justify it."
  exit 0
fi

# ---------------------------------------------------------------------------
section "Layout"
for d in app pages modules features shared components hooks services utils lib config; do
  if [ -d "$SRC/$d" ]; then
    n="$(grep -c "^$SRC/$d/" "$TMP/main" || true)"
    printf '  %-12s %s files\n' "$d/" "$n"
  fi
done
if [ -d "$SRC/modules" ] || [ -d "$SRC/features" ]; then
  MODROOT="$SRC/modules"; [ -d "$MODROOT" ] || MODROOT="$SRC/features"
  echo "Modules ($(basename "$MODROOT")/):"
  for m in "$MODROOT"/*/; do
    [ -d "$m" ] || continue
    pub="no"; ls "$m" 2>/dev/null | grep -qE '^public(\.server)?\.(ts|tsx|js)$|^index\.(ts|tsx)$' && pub="yes"
    layers="$(ls -d "$m"*/ 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
    printf '  %-20s public-api:%-4s layers: %s\n' "$(basename "$m")" "$pub" "${layers:-<flat>}"
  done
  echo "Hint: feature-based organization present (Level 2+)."
else
  MODROOT=""
  GLOBAL="$(for d in components hooks services utils; do [ -d "$SRC/$d" ] && echo "$d"; done | wc -l | tr -d ' ')"
  if [ "$GLOBAL" -ge 2 ]; then
    echo "Hint: global technical folders without feature modules → Level 1; consider Level 2 if features are mixing."
  else
    echo "Hint: no feature modules yet (Level 1)."
  fi
fi

# ---------------------------------------------------------------------------
section "Largest files (> $THRESHOLD lines)  [giant components]"
tr '\n' '\0' < "$TMP/main" | xargs -0 wc -l 2>/dev/null | grep -v ' total$' \
  | awk -v t="$THRESHOLD" '$1 > t' | sort -rn > "$TMP/large"
if [ -s "$TMP/large" ]; then rel < "$TMP/large" | cap | sed 's/^/  /'; else echo "  none"; fi
grep -E '/app/.*(page|layout)\.[jt]sx?$' "$TMP/large" > "$TMP/large_routes" || true
if [ -s "$TMP/large_routes" ]; then
  echo "Large route files (feature logic in app/):"; rel < "$TMP/large_routes" | cap | sed 's/^/  /'
fi

# ---------------------------------------------------------------------------
section "Client boundaries (\"use client\")"
grep_files "$TMP/main" -E "^[[:space:]]*['\"]use client['\"]" > "$TMP/client"
echo "  client files: $(count_lines "$TMP/client") / $(count_lines "$TMP/main")"
grep -E '/app/(.*/)?(layout|page|template)\.[jt]sx?$' "$TMP/client" | rel | cap > "$TMP/client_routes" || true
if [ -s "$TMP/client_routes" ]; then
  echo "  Client layouts/pages (boundary probably too high):"; sed 's/^/    /' "$TMP/client_routes"
else
  echo "  no client layouts/pages"
fi

# ---------------------------------------------------------------------------
section "Secrets risk: non-public env vars in client files"
grep_lines "$TMP/client" -oE 'process\.env\.[A-Za-z0-9_]+' \
  | grep -vE 'process\.env\.(NEXT_PUBLIC_[A-Za-z0-9_]*|NODE_ENV)$' | rel | cap > "$TMP/env"
if [ -s "$TMP/env" ]; then sed 's/^/  /' "$TMP/env"; else echo "  none"; fi

# ---------------------------------------------------------------------------
section "fetch() outside infrastructure/api/lib  [fetch everywhere]"
grep -vE '/(infrastructure|api|lib|services|server)/|/route\.[jt]sx?$|-api\.[jt]sx?$|\.api\.[jt]sx?$' "$TMP/main" > "$TMP/ui_files" || true
if [ -s "$TMP/ui_files" ]; then
  tr '\n' '\0' < "$TMP/ui_files" | xargs -0 grep -cE '\bfetch\(' 2>/dev/null | grep -v ':0$' \
    | awk -F: '{print $NF" "substr($0,1,length($0)-length($NF)-1)}' | sort -rn > "$TMP/fetch" || true
fi
if [ -s "$TMP/fetch" ]; then
  echo "  files: $(count_lines "$TMP/fetch")  (lines-with-fetch path)"; rel < "$TMP/fetch" | cap | sed 's/^/  /'
else
  echo "  none"
fi

# ---------------------------------------------------------------------------
section "Cross-module deep imports (bypassing public API)"
grep_lines "$TMP/main" -oE "from[[:space:]]+['\"]@/(modules|features)/[^'\"]+['\"]" \
  | awk -v root="$ROOT/" '
      {
        line=$0
        match(line, /@\/(modules|features)\/[^"\047]+/)
        spec=substr(line, RSTART+2, RLENGTH-2)          # modules/x/rest
        n=split(spec, p, "/")
        target=p[2]; rest=""
        for (i=3;i<=n;i++) rest = rest (i>3?"/":"") p[i]
        file=line; sub(/:[0-9]+:.*/, "", file)
        own=""
        if (match(file, /\/(modules|features)\/[^\/]+\//)) { s=substr(file,RSTART+1,RLENGTH-2); split(s,q,"/"); own=q[2] }
        if (target != own && rest != "" && rest !~ /^public(\.server)?$/ && rest !~ /^index$/) {
          sub(root, "", line); print line
        }
      }' > "$TMP/deep"
if [ -s "$TMP/deep" ]; then
  cap < "$TMP/deep" | sed 's/^/  /'; echo "  total: $(count_lines "$TMP/deep")"
else
  echo "  none detected"
fi

# ---------------------------------------------------------------------------
section "Catch-all utility files & shared/"
grep -E '/(utils|helpers|common|misc)\.[jt]sx?$' "$TMP/main" | rel | cap > "$TMP/utils" || true
if [ -s "$TMP/utils" ]; then echo "  catch-all files:"; sed 's/^/    /' "$TMP/utils"; else echo "  no catch-all utility files"; fi
if [ -d "$SRC/shared" ]; then
  echo "  shared/ files: $(grep -c "^$SRC/shared/" "$TMP/main" || true) — check for domain-named files (they belong in modules)."
fi

# ---------------------------------------------------------------------------
section "Global state"
grep_files "$TMP/main" -E "from[[:space:]]+['\"]zustand['\"]" | rel | cap > "$TMP/zustand"
grep_files "$TMP/main" -E 'configureStore\(|createSlice\(' | rel | cap > "$TMP/redux"
grep_files "$TMP/main" -E 'createContext\(' | rel | cap > "$TMP/ctx"
echo "  zustand store files: $(count_lines "$TMP/zustand")";  sed 's/^/    /' "$TMP/zustand"
echo "  redux store/slice files: $(count_lines "$TMP/redux")"; sed 's/^/    /' "$TMP/redux"
echo "  React contexts: $(count_lines "$TMP/ctx")";           sed 's/^/    /' "$TMP/ctx"

# ---------------------------------------------------------------------------
section "Tests"
echo "  test files: $(count_lines "$TMP/test")"
if [ -s "$TMP/test" ]; then
  echo "  e2e files:  $(grep -cE '/e2e/|\.e2e\.' "$TMP/test" || true)"
fi

# ---------------------------------------------------------------------------
section "Next"
echo "These are signals, not verdicts. Read the flagged files, classify the level per feature,"
echo "and recommend only the smallest step that fixes a confirmed problem (see SKILL.md)."
exit 0
