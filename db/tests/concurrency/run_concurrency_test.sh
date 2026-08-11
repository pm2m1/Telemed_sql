#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo_root"

log_a="$(mktemp)"
log_b="$(mktemp)"
session_a_pid=""
setup_complete=0

run_sql_file() {
  local file="$1"
  docker compose exec -T postgres sh -c \
    "psql -v ON_ERROR_STOP=1 -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -f /workspace/$file"
}

cleanup() {
  local exit_code=$?
  if [[ -n "$session_a_pid" ]] && kill -0 "$session_a_pid" 2>/dev/null; then
    wait "$session_a_pid" || true
  fi
  if [[ "$setup_complete" -eq 1 ]]; then
    run_sql_file db/tests/concurrency/cleanup.sql >/dev/null 2>&1 || true
  fi
  rm -f "$log_a" "$log_b"
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

docker compose run --rm flyway validate
run_sql_file db/tests/concurrency/setup.sql
setup_complete=1

run_sql_file db/tests/concurrency/session_a.sql >"$log_a" 2>&1 &
session_a_pid=$!

ready="f"
for _ in {1..75}; do
  ready="$(run_sql_file db/tests/concurrency/ready.sql | tr -d '[:space:]')"
  if [[ "$ready" == "t" ]]; then
    break
  fi
  if ! kill -0 "$session_a_pid" 2>/dev/null; then
    echo "Session A exited before reaching its coordinated hold." >&2
    cat "$log_a" >&2
    exit 1
  fi
  sleep 0.2
done

if [[ "$ready" != "t" ]]; then
  echo "Timed out waiting for Session A readiness." >&2
  cat "$log_a" >&2
  exit 1
fi

if ! run_sql_file db/tests/concurrency/session_b.sql >"$log_b" 2>&1; then
  echo "Session B failed unexpectedly." >&2
  cat "$log_b" >&2
  exit 1
fi

if ! wait "$session_a_pid"; then
  echo "Session A failed unexpectedly." >&2
  cat "$log_a" >&2
  exit 1
fi
session_a_pid=""

if ! grep -q "EXPECTED_SQLSTATE=23P01" "$log_b"; then
  echo "Session B did not report the expected exclusion SQLSTATE." >&2
  cat "$log_b" >&2
  exit 1
fi

run_sql_file db/tests/concurrency/verify.sql
echo "Two-session concurrency test passed."
