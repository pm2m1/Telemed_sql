#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

echo "Checking the existing schema before recording a V5 baseline..."
preflight="$(
  docker compose exec -T postgres sh -c \
    'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /workspace/db/legacy/legacy_preflight.sql'
)"

if [[ "$preflight" != *"LEGACY_V5_SCHEMA_CONFIRMED"* ]]; then
  echo "Legacy schema confirmation marker was not returned." >&2
  exit 1
fi

docker compose run --rm \
  -e FLYWAY_BASELINE_VERSION=5 \
  -e FLYWAY_BASELINE_DESCRIPTION="Legacy init schema through analytical views" \
  flyway baseline
docker compose run --rm flyway migrate
docker compose run --rm flyway validate

echo "Legacy schema baselined at V5 and upgraded successfully."
