#!/usr/bin/env bash
set -euo pipefail

MACBOX="$(cd "$(dirname "$0")/.." && pwd -P)/macbox"
PASSED=0
FAILED=0

pass() { ((PASSED++)); printf "\033[0;32m  PASS\033[0m %s\n" "$1"; }
fail() { ((FAILED++)); printf "\033[0;31m  FAIL\033[0m %s\n" "$1"; }

run_test() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

echo "=== macbox smoke tests ==="
echo ""

# Cleanup from previous runs
$MACBOX rm test-ubuntu --force 2>/dev/null || true

echo "--- Create ---"
$MACBOX create ubuntu --name test-ubuntu
run_test "container exists" podman container exists macbox-test-ubuntu
run_test "container is running" $MACBOX enter test-ubuntu -- true

echo ""
echo "--- Enter ---"
WHOAMI="$($MACBOX enter test-ubuntu -- whoami 2>/dev/null)"
if [[ "$WHOAMI" == "$(whoami)" ]]; then
  pass "whoami matches host user ($WHOAMI)"
else
  fail "whoami mismatch: got '$WHOAMI', expected '$(whoami)'"
fi

UIDCHECK="$($MACBOX enter test-ubuntu -- id -u 2>/dev/null)"
if [[ "$UIDCHECK" == "$(id -u)" ]]; then
  pass "UID matches host (${UIDCHECK})"
else
  fail "UID mismatch: got '$UIDCHECK', expected '$(id -u)'"
fi

run_test "home directory accessible" $MACBOX enter test-ubuntu -- test -d "$HOME"

echo ""
echo "--- List ---"
LIST="$($MACBOX list --quiet 2>/dev/null)"
if echo "$LIST" | grep -q "test-ubuntu"; then
  pass "container appears in list"
else
  fail "container not in list"
fi

echo ""
echo "--- Stop ---"
$MACBOX stop test-ubuntu
if ! podman inspect --format '{{.State.Running}}' macbox-test-ubuntu 2>/dev/null | grep -q true; then
  pass "container stopped"
else
  fail "container still running after stop"
fi

echo ""
echo "--- Re-enter (auto-restart) ---"
WHOAMI2="$($MACBOX enter test-ubuntu -- whoami 2>/dev/null)"
if [[ "$WHOAMI2" == "$(whoami)" ]]; then
  pass "re-entered after stop"
else
  fail "failed to re-enter"
fi

echo ""
echo "--- Remove ---"
$MACBOX rm test-ubuntu --force
if ! podman container exists macbox-test-ubuntu 2>/dev/null; then
  pass "container removed"
else
  fail "container still exists after rm"
fi

echo ""
echo "=== Results: ${PASSED} passed, ${FAILED} failed ==="
[[ "$FAILED" -eq 0 ]] && exit 0 || exit 1
