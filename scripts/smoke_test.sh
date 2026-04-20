#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}

assert_contains() {
  local file_path="$1"
  local expected="$2"

  if ! grep -Fq "${expected}" "${file_path}"; then
    echo "Expected output to contain: ${expected}" >&2
    echo "--- actual output ---" >&2
    cat "${file_path}" >&2
    exit 1
  fi
}

trap cleanup EXIT

projects=(
  "starter/lab1-process-explorer"
  "starter/lab2-counter-lab"
  "starter/lab3-memory-probe"
  "starter/lab4-tiny-shell"
)

echo "==> building zig starters"
zig build -p "${ROOT_DIR}/zig-out"

echo "==> demo checks"
"${ROOT_DIR}/zig-out/bin/process_explorer" 2 3 >"${TMP_DIR}/lab1.out"
assert_contains "${TMP_DIR}/lab1.out" "[child] worker=0"
assert_contains "${TMP_DIR}/lab1.out" "[parent] pid="

"${ROOT_DIR}/zig-out/bin/counter_lab" race 2 100 >"${TMP_DIR}/lab2-race.out"
"${ROOT_DIR}/zig-out/bin/counter_lab" mutex 2 100 >"${TMP_DIR}/lab2-mutex.out"
assert_contains "${TMP_DIR}/lab2-race.out" "mode=race"
assert_contains "${TMP_DIR}/lab2-mutex.out" "mode=mutex"

"${ROOT_DIR}/zig-out/bin/memory_probe" maps >"${TMP_DIR}/lab3-maps.out"
if [[ ! -s "${TMP_DIR}/lab3-maps.out" ]]; then
  echo "Expected maps output to be non-empty" >&2
  exit 1
fi

if "${ROOT_DIR}/zig-out/bin/memory_probe" touch 1 typo >"${TMP_DIR}/lab3-invalid.out" 2>&1; then
  echo "Expected invalid memory pattern to fail" >&2
  exit 1
fi
assert_contains "${TMP_DIR}/lab3-invalid.out" "pattern must be"

printf "help\nquit\n" | "${ROOT_DIR}/zig-out/bin/tinysh" >"${TMP_DIR}/lab4-help.out"
assert_contains "${TMP_DIR}/lab4-help.out" "tinysh commands:"

if printf "echo hi >\nquit\n" | "${ROOT_DIR}/zig-out/bin/tinysh" >"${TMP_DIR}/lab4-invalid.out" 2>&1; then
  echo "Expected malformed redirection to fail" >&2
  exit 1
fi
assert_contains "${TMP_DIR}/lab4-invalid.out" "parse error"

echo "Smoke test completed."
