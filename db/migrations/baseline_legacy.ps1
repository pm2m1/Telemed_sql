[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $repoRoot

Write-Host "Checking the existing schema before recording a V5 baseline..."
$preflight = docker compose exec -T postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /workspace/db/legacy/legacy_preflight.sql' 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Legacy schema preflight failed.`n$($preflight -join [Environment]::NewLine)"
}
if (($preflight -join [Environment]::NewLine) -notmatch "LEGACY_V5_SCHEMA_CONFIRMED") {
    throw "Legacy schema confirmation marker was not returned."
}

docker compose run --rm `
    -e FLYWAY_BASELINE_VERSION=5 `
    -e 'FLYWAY_BASELINE_DESCRIPTION=Legacy init schema through analytical views' `
    flyway baseline
if ($LASTEXITCODE -ne 0) {
    throw "Flyway baseline failed."
}

docker compose run --rm flyway migrate
if ($LASTEXITCODE -ne 0) {
    throw "Flyway migration failed after baseline."
}

docker compose run --rm flyway validate
if ($LASTEXITCODE -ne 0) {
    throw "Flyway validation failed after migration."
}

Write-Host "Legacy schema baselined at V5 and upgraded successfully."
