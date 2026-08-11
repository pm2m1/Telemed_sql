[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

docker compose config --quiet
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose configuration is invalid."
}

docker compose exec -T postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
if ($LASTEXITCODE -ne 0) {
    throw "PostgreSQL is not ready. Run: docker compose up -d"
}

docker compose run --rm flyway validate
if ($LASTEXITCODE -ne 0) {
    throw "Flyway validation failed."
}

docker compose exec -T postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /workspace/demo/demo.sql'
if ($LASTEXITCODE -ne 0) {
    throw "Database demo failed."
}
