[CmdletBinding()]
param(
    [string]$ProjectName = $env:COMPOSE_PROJECT_NAME
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
Set-Location $repoRoot

$sessionA = $null
$setupComplete = $false
$composeProjectArgs = @()
if (-not [string]::IsNullOrWhiteSpace($ProjectName)) {
    $composeProjectArgs = @("-p", $ProjectName)
}

function Invoke-Compose {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    & docker compose @composeProjectArgs @Arguments
}

function Invoke-DatabaseFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $previousPreference = $ErrorActionPreference
    try {
        # Windows PowerShell 5 surfaces native stderr (including psql NOTICE
        # messages) as ErrorRecord objects. Process exit status remains the
        # authoritative success signal for these commands.
        $ErrorActionPreference = "Continue"
        $output = & docker compose @composeProjectArgs exec -T postgres sh -c "psql -v ON_ERROR_STOP=1 -U `"`$POSTGRES_USER`" -d `"`$POSTGRES_DB`" -f /workspace/$Path" 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($exitCode -ne 0) {
        throw "SQL file failed: $Path`n$($output -join [Environment]::NewLine)"
    }
    return $output
}

try {
    Invoke-Compose run --rm flyway validate
    if ($LASTEXITCODE -ne 0) {
        throw "Flyway validation failed."
    }

    Invoke-DatabaseFile "db/tests/concurrency/setup.sql" | Out-Null
    $setupComplete = $true

    $sessionA = Start-Job -ScriptBlock {
        param($WorkingDirectory, $ComposeProject)
        Set-Location $WorkingDirectory
        $dockerArguments = @("compose")
        if (-not [string]::IsNullOrWhiteSpace($ComposeProject)) {
            $dockerArguments += @("-p", $ComposeProject)
        }
        $dockerArguments += @(
            "exec",
            "-T",
            "postgres",
            "sh",
            "-c",
            'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /workspace/db/tests/concurrency/session_a.sql'
        )
        $output = & docker @dockerArguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw ($output -join [Environment]::NewLine)
        }
        $output
    } -ArgumentList $repoRoot, $ProjectName

    $ready = $false
    for ($attempt = 0; $attempt -lt 75; $attempt++) {
        $readyOutput = Invoke-DatabaseFile "db/tests/concurrency/ready.sql"
        if (($readyOutput -join "").Trim() -eq "t") {
            $ready = $true
            break
        }
        if ($sessionA.State -in @("Completed", "Failed", "Stopped")) {
            $earlyOutput = Receive-Job -Job $sessionA -ErrorAction SilentlyContinue
            throw "Session A exited before reaching its coordinated hold.`n$($earlyOutput -join [Environment]::NewLine)"
        }
        Start-Sleep -Milliseconds 200
    }

    if (-not $ready) {
        throw "Timed out waiting for Session A readiness."
    }

    $sessionBOutput = Invoke-DatabaseFile "db/tests/concurrency/session_b.sql"

    Wait-Job -Job $sessionA | Out-Null
    $sessionAOutput = Receive-Job -Job $sessionA
    if ($sessionA.State -ne "Completed") {
        throw "Session A failed: $($sessionAOutput -join [Environment]::NewLine)"
    }

    if (($sessionBOutput -join [Environment]::NewLine) -notmatch "EXPECTED_SQLSTATE=23P01") {
        throw "Session B did not report expected SQLSTATE 23P01."
    }

    Invoke-DatabaseFile "db/tests/concurrency/verify.sql"
    Write-Host "Two-session concurrency test passed."
}
finally {
    if ($null -ne $sessionA) {
        if ($sessionA.State -eq "Running") {
            Wait-Job -Job $sessionA -Timeout 15 | Out-Null
        }
        Remove-Job -Job $sessionA -Force -ErrorAction SilentlyContinue
    }
    if ($setupComplete) {
        try {
            Invoke-DatabaseFile "db/tests/concurrency/cleanup.sql" | Out-Null
        }
        catch {
            Write-Warning "Concurrency fixture cleanup failed: $_"
        }
    }
}
