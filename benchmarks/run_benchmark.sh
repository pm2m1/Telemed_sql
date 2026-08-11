#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

project="telemed_benchmark"
export POSTGRES_DB="telemed_benchmark"
export POSTGRES_PORT="${BENCHMARK_PORT:-55434}"
doctor_count="${BENCHMARK_DOCTORS:-1000}"
patient_count="${BENCHMARK_PATIENTS:-20000}"
appointment_count="${BENCHMARK_APPOINTMENTS:-100000}"

cleanup() {
  docker compose -p "$project" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

cleanup
docker compose -p "$project" up -d postgres
docker compose -p "$project" run --rm flyway migrate

docker compose -p "$project" exec -T postgres sh -c \
  "psql -v ON_ERROR_STOP=1 -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" \
   -v doctor_count=$doctor_count -v patient_count=$patient_count \
   -v appointment_count=$appointment_count \
   -f /workspace/benchmarks/generate_data.sql"

mkdir -p benchmarks/results
docker compose -p "$project" exec -T postgres sh -c \
  'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /workspace/benchmarks/queries.sql' \
  | tee benchmarks/results/latest.txt

echo "Benchmark plans saved to benchmarks/results/latest.txt"
