<#
.SYNOPSIS
    Check Judge0 status

.DESCRIPTION
    Check the status of Judge0 services, git repository, and API health

.PARAMETER ApiUrl
    API URL to check (default: http://localhost:2358)

.EXAMPLE
    .\Get-Judge0Status.ps1
    Check status with default settings

.EXAMPLE
    .\Get-Judge0Status.ps1 -ApiUrl "http://your-vm-ip:2358"
    Check remote Judge0 instance
#>

[CmdletBinding()]
param(
    [string]$ApiUrl = "http://localhost:2358",
    [string]$ComposeFile = "docker-compose.yml"
)

$ErrorActionPreference = "Continue"
$Judge0Dir = Split-Path -Parent $PSScriptRoot

# Colors
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

# Header
Write-Host "Judge0 Status Check" -ForegroundColor White
Write-Host ("=" * 40)
Write-Host ""

Push-Location $Judge0Dir
try {
    # Git info
    Write-Info "Repository Status:"

    $branch = git branch --show-current
    Write-Host "  Branch: $branch" -ForegroundColor Gray

    $localCommit = git rev-parse --short HEAD
    Write-Host "  Commit: $localCommit" -ForegroundColor Gray

    try {
        $remoteCommit = git rev-parse --short origin/master 2>$null
        Write-Host "  Remote: $remoteCommit" -ForegroundColor Gray

        if ($localCommit -ne $remoteCommit) {
            Write-Warning "  Local and remote commits differ!"
        }
    }
    catch {
        Write-Host "  Remote: unknown" -ForegroundColor Gray
    }

    Write-Host ""

    # Docker containers
    Write-Info "Docker Containers:"
    docker-compose -f $ComposeFile ps
    Write-Host ""

    # API health check
    Write-Info "API Health Check:"
    try {
        $response = Invoke-WebRequest -Uri "$ApiUrl/about" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Success "API is responding at $ApiUrl"

        # Try to parse version
        if ($response.Content -match '"version":"([^"]+)"') {
            Write-Host "  Version: $($matches[1])" -ForegroundColor Gray
        }

        # Try to parse languages count
        try {
            $langResponse = Invoke-WebRequest -Uri "$ApiUrl/languages" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            $languages = ($langResponse.Content | ConvertFrom-Json)
            Write-Host "  Languages: $($languages.Count)" -ForegroundColor Gray
        }
        catch {
            # Languages endpoint might not work, that's ok
        }
    }
    catch {
        Write-Warning "API is not responding at $ApiUrl"
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
    }

    Write-Host ""

    # Disk space check
    Write-Info "Disk Space:"
    $drive = (Get-Location).Drive.Name
    $driveInfo = Get-PSDrive $drive
    $freeGB = [math]::Round($driveInfo.Free / 1GB, 2)
    $usedGB = [math]::Round($driveInfo.Used / 1GB, 2)
    $totalGB = [math]::Round(($driveInfo.Free + $driveInfo.Used) / 1GB, 2)
    $percentUsed = [math]::Round(($usedGB / $totalGB) * 100, 1)

    Write-Host "  Drive ${drive}: ${usedGB}GB used / ${totalGB}GB total (${percentUsed}% used)" -ForegroundColor Gray
    Write-Host "  Free space: ${freeGB}GB" -ForegroundColor Gray

    if ($percentUsed -gt 90) {
        Write-Warning "  Low disk space!"
    }

}
catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Pop-Location
}

Write-Host ""
Write-Info "Done"
