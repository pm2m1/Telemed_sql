#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! docker compose config --quiet; then
  echo "Docker Compose configuration is invalid." >&2
  exit 1
fi

if ! docker compose exec -T postgres sh -c \
  'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null; then
  echo "PostgreSQL is not ready. Run: docker compose up -d" >&2
  exit 1
fi

docker compose run --rm flyway validate
docker compose exec -T postgres sh -c \
  'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /workspace/demo/demo.sql'
