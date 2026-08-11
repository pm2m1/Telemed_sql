[CmdletBinding()]
param(
    [ValidateRange(1, 10000)][int]$Doctors = 1000,
    [ValidateRange(1, 200000)][int]$Patients = 20000,
    [ValidateRange(1, 1000000)][int]$Appointments = 100000,
    [ValidateRange(1024, 65535)][int]$Port = 55434
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$project = "telemed_benchmark"
$oldDatabase = $env:POSTGRES_DB
$oldPort = $env:POSTGRES_PORT
$env:POSTGRES_DB = "telemed_benchmark"
$env:POSTGRES_PORT = $Port.ToString()

try {
    # Windows PowerShell 5 represents native stderr as ErrorRecord objects.
    # Docker/psql process exit codes are authoritative for this runner.
    $ErrorActionPreference = "Continue"

    Write-Host "Preparing isolated benchmark project..."
    docker compose -p $project down -v --remove-orphans 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to prepare the isolated benchmark project."
    }

    Write-Host "Starting benchmark PostgreSQL..."
    docker compose -p $project up -d --wait postgres
    if ($LASTEXITCODE -ne 0) {
        throw "Benchmark PostgreSQL failed to become healthy."
    }

    Write-Host "Applying Flyway migrations..."
    docker compose -p $project run --rm flyway migrate
    if ($LASTEXITCODE -ne 0) {
        throw "Benchmark Flyway migration failed."
    }

    Write-Host "Generating $Doctors doctors, $Patients patients, and $Appointments appointments..."
    $generate = "psql -v ON_ERROR_STOP=1 -U `"`$POSTGRES_USER`" -d `"`$POSTGRES_DB`" " +
        "-v doctor_count=$Doctors -v patient_count=$Patients " +
        "-v appointment_count=$Appointments " +
        "-f /workspace/benchmarks/generate_data.sql"
    docker compose -p $project exec -T postgres sh -c $generate
    if ($LASTEXITCODE -ne 0) {
        throw "Benchmark data generation failed."
    }

    Write-Host "Capturing EXPLAIN (ANALYZE, BUFFERS) plans..."
    $resultsDirectory = Join-Path $PSScriptRoot "results"
    New-Item -ItemType Directory -Force -Path $resultsDirectory | Out-Null
    $queryOutput = docker compose -p $project exec -T postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /workspace/benchmarks/queries.sql' 2>&1
    $queryExitCode = $LASTEXITCODE
    if ($queryExitCode -ne 0) {
        throw "Benchmark queries failed.`n$($queryOutput -join [Environment]::NewLine)"
    }
    $queryOutput | Tee-Object -FilePath (Join-Path $resultsDirectory "latest.txt")
    Write-Host "Benchmark plans saved to benchmarks/results/latest.txt"
}
finally {
    Write-Host "Removing isolated benchmark project..."
    $cleanupOutput = docker compose -p $project down -v --remove-orphans 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Benchmark cleanup failed: $($cleanupOutput -join [Environment]::NewLine)"
    }
    $env:POSTGRES_DB = $oldDatabase
    $env:POSTGRES_PORT = $oldPort
    $ErrorActionPreference = "Stop"
}
