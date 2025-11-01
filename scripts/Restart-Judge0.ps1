<#
.SYNOPSIS
    Restart Judge0 services

.DESCRIPTION
    Simple script to restart Judge0 Docker services on Windows/Azure

.PARAMETER Dev
    Use development compose file (docker-compose.dev.yml)

.EXAMPLE
    .\Restart-Judge0.ps1
    Restart production instance

.EXAMPLE
    .\Restart-Judge0.ps1 -Dev
    Restart development instance
#>

[CmdletBinding()]
param(
    [switch]$Dev
)

$ErrorActionPreference = "Stop"
$Judge0Dir = Split-Path -Parent $PSScriptRoot

# Select compose file
$ComposeFile = if ($Dev) { "docker-compose.dev.yml" } else { "docker-compose.yml" }
$Mode = if ($Dev) { "Development" } else { "Production" }

# Colors
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

# Header
Write-Host "Judge0 Restart Script" -ForegroundColor White
Write-Host ("=" * 40)
Write-Host "Directory: $Judge0Dir"
Write-Host "Mode: $Mode"
Write-Host "Compose: $ComposeFile"
Write-Host ""

Push-Location $Judge0Dir
try {
    Write-Info "Stopping services..."
    docker-compose -f $ComposeFile down

    Write-Host ""
    Write-Info "Starting services..."
    docker-compose -f $ComposeFile up -d

    Write-Host ""
    Write-Info "Service status:"
    docker-compose -f $ComposeFile ps

    Write-Host ""
    Write-Success "Judge0 restarted!"
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to restart: $_" -ForegroundColor Red
    exit 1
}
finally {
    Pop-Location
}
