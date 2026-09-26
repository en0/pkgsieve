#!/usr/bin/env bash
#
# run.sh - dependency-free test harness for pkgsieve.
#
# Runs pkgsieve against the fixtures in ./fixtures with an isolated, stubbed
# cache so the suite is deterministic and works fully offline. No bats, no pip.
#
# Usage: tests/run.sh   (exit 0 = all pass, 1 = failures)

set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(dirname "$HERE")
PKGSIEVE="$ROOT/pkgsieve"
FIX="$HERE/fixtures"

# Isolated cache so we never touch the user's real ~/.cache/pkgsieve.
TEST_CACHE=$(mktemp -d)
trap 'rm -rf "$TEST_CACHE"' EXIT

# Stub a blocklist + npm payload list so tests are offline & deterministic.
mkdir -p "$TEST_CACHE/pkgsieve"
cat > "$TEST_CACHE/pkgsieve/blocklist.txt" <<'EOF'
blocked-victim
some-other-evil-pkg
EOF
cat > "$TEST_CACHE/pkgsieve/npm-payloads.txt" <<'EOF'
atomic-lockfile
js-digest
lockfile-js
nextfile-js
EOF
# Pretend we already synced this SHA so --no-update has data; we always pass
# --no-update anyway to avoid network.
echo "testsha" > "$TEST_CACHE/pkgsieve/blocklist.sha"

# Common env: isolated cache, assume-yes (never block on staleness), no network.
run() {
    XDG_CACHE_HOME="$TEST_CACHE" PKGSIEVE_ASSUME_YES=1 \
        "$PKGSIEVE" --no-update -q "$@"
}

PASS=0
FAIL=0

# assert_exit <expected-code> <label> -- <pkgsieve args...>
assert_exit() {
    local expected="$1" label="$2"; shift 2
    [[ "$1" == "--" ]] && shift
    local out rc
    out=$(run "$@" 2>&1); rc=$?
    if [[ "$rc" == "$expected" ]]; then
        printf '  \033[0;32mPASS\033[0m  %s (exit %s)\n' "$label" "$rc"
        PASS=$((PASS + 1))
    else
        printf '  \033[0;31mFAIL\033[0m  %s (expected %s, got %s)\n' "$label" "$expected" "$rc"
        printf '%s\n' "$out" | sed 's/^/        /'
        FAIL=$((FAIL + 1))
    fi
}

# assert_contains <needle> <label> -- <pkgsieve args...>
assert_contains() {
    local needle="$1" label="$2"; shift 2
    [[ "$1" == "--" ]] && shift
    local out
    out=$(run "$@" 2>&1)
    if grep -qF "$needle" <<< "$out"; then
        printf '  \033[0;32mPASS\033[0m  %s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf '  \033[0;31mFAIL\033[0m  %s (missing: %s)\n' "$label" "$needle"
        printf '%s\n' "$out" | sed 's/^/        /'
        FAIL=$((FAIL + 1))
    fi
}

echo "pkgsieve test suite"
echo "==================="

# Exit-code contract.
assert_exit 0 "clean package passes"              -- "$FIX/clean"
assert_exit 1 "npm payload package fails"          -- "$FIX/evil-npm"
assert_exit 1 "curl|sh in .install fails"          -- "$FIX/evil-curlpipe"
assert_exit 1 "blocklisted name fails"             -- "$FIX/blocked-victim"
assert_exit 1 "untrusted host now fails"           -- "$FIX/oddhost"
assert_exit 2 "missing directory is usage error"   -- "$FIX/does-not-exist"

# Content expectations.
assert_contains "atomic-lockfile"  "reports the payload name"       -- "$FIX/evil-npm"
assert_contains "blocklist"        "reports blocklist hit"          -- "$FIX/blocked-victim"
assert_contains "curl | sh"        "names the curl-pipe red flag"   -- "$FIX/evil-curlpipe"
assert_contains "sketchy-cdn"      "flags the untrusted host"       -- "$FIX/oddhost"
assert_contains "PASS"             "clean run prints PASS"          -- "$FIX/clean"

# Multiple targets: one bad among good => overall fail (exit 1).
assert_exit 1 "mixed batch fails if any target is bad" -- "$FIX/clean" "$FIX/evil-npm"

echo "==================="
printf 'Total: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
