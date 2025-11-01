<#
.SYNOPSIS
    Judge0 Update Checker and Deployer for Windows/Azure

.DESCRIPTION
    Checks GitHub remote for updates and restarts Judge0 if changes are found.
    Designed for Azure Windows VMs running Judge0 with Docker.

.PARAMETER Force
    Force update even if no changes detected

.PARAMETER DryRun
    Check for updates but don't apply them

.PARAMETER Remote
    Git remote to check (default: origin)

.PARAMETER Branch
    Git branch to check (default: master)

.EXAMPLE
    .\Check-And-Update.ps1
    Check for updates and apply if found

.EXAMPLE
    .\Check-And-Update.ps1 -DryRun
    Check what updates are available without applying

.EXAMPLE
    .\Check-And-Update.ps1 -Force
    Force update even if no changes detected
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$DryRun,
    [string]$Remote = "origin",
    [string]$Branch = "master",
    [string]$ComposeFile = "docker-compose.yml"
)

# Configuration
$ErrorActionPreference = "Stop"
$Judge0Dir = Split-Path -Parent $PSScriptRoot

# Colors for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Separator {
    Write-Host ("=" * 60)
}

function Test-Requirements {
    Write-Info "Checking requirements..."

    # Check git
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "git is not installed or not in PATH"
        exit 1
    }

    # Check docker
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "docker is not installed or not in PATH"
        exit 1
    }

    # Check docker-compose
    if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
        Write-Error "docker-compose is not installed or not in PATH"
        exit 1
    }

    Write-Success "All requirements met"
}

function Test-ForUpdates {
    Write-Info "Checking for updates from ${Remote}/${Branch}..."

    Push-Location $Judge0Dir
    try {
        # Fetch latest changes
        Write-Info "Fetching from remote..."
        git fetch $Remote $Branch 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to fetch from remote"
            exit 1
        }

        # Get current commits
        $localCommit = git rev-parse HEAD
        $remoteCommit = git rev-parse "$Remote/$Branch"

        Write-Host ""
        Write-Info "Local commit:  $localCommit"
        Write-Info "Remote commit: $remoteCommit"
        Write-Host ""

        if ($localCommit -eq $remoteCommit) {
            if ($Force) {
                Write-Warning "No updates found, but -Force specified"
                return $true
            } else {
                Write-Success "Already up to date!"
                return $false
            }
        } else {
            # Show what changed
            Write-Info "Changes found:"
            Write-Host ""
            git log --oneline --decorate "$localCommit..$remoteCommit"
            Write-Host ""
            return $true
        }
    }
    finally {
        Pop-Location
    }
}

function Update-Repository {
    Write-Info "Pulling updates from ${Remote}/${Branch}..."

    Push-Location $Judge0Dir
    try {
        # Check for local changes
        $status = git status --porcelain
        if ($status) {
            Write-Warning "Local changes detected:"
            git status --short
            Write-Host ""
            Write-Error "Please commit or stash local changes before updating"
            exit 1
        }

        # Pull changes
        Write-Info "Pulling changes..."
        git pull $Remote $Branch
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to pull updates"
            exit 1
        }

        Write-Success "Updates pulled successfully"
    }
    finally {
        Pop-Location
    }
}

function Restart-Judge0 {
    Write-Info "Restarting Judge0 services..."

    Push-Location $Judge0Dir
    try {
        # Stop services
        Write-Info "Stopping services..."
        docker-compose -f $ComposeFile down
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to stop services (may not be running)"
        }

        # Pull latest images
        Write-Info "Pulling latest Docker images..."
        docker-compose -f $ComposeFile pull
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to pull Docker images"
            exit 1
        }

        # Start services
        Write-Info "Starting services..."
        docker-compose -f $ComposeFile up -d
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to start services"
            exit 1
        }

        Write-Success "Judge0 services restarted"
    }
    finally {
        Pop-Location
    }
}

function Test-ServiceHealth {
    Write-Info "Checking service health..."

    Push-Location $Judge0Dir
    try {
        # Wait for services to start
        Start-Sleep -Seconds 5

        # Check running containers
        Write-Info "Running containers:"
        docker-compose -f $ComposeFile ps
        Write-Host ""

        # Try to get Judge0 version
        Write-Info "Checking API health..."
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:2358/about" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            Write-Success "API is responding"

            # Try to parse version
            if ($response.Content -match '"version":"([^"]+)"') {
                Write-Info "Version: $($matches[1])"
            }
        }
        catch {
            Write-Warning "API not responding yet (may need more time to start)"
        }
    }
    finally {
        Pop-Location
    }
}

# Main execution
function Main {
    Write-Separator
    Write-Host "Judge0 Update Checker (PowerShell)" -ForegroundColor White
    Write-Host "Directory: $Judge0Dir"
    Write-Host "Remote: $Remote"
    Write-Host "Branch: $Branch"
    Write-Host "Compose: $ComposeFile"
    Write-Separator
    Write-Host ""

    Test-Requirements
    Write-Host ""

    $hasUpdates = Test-ForUpdates

    if ($hasUpdates) {
        if ($DryRun) {
            Write-Info "Dry run mode - skipping update"
            return
        }

        Write-Host ""
        Write-Separator
        Write-Info "Starting update process..."
        Write-Separator
        Write-Host ""

        Update-Repository
        Write-Host ""

        Restart-Judge0
        Write-Host ""

        Test-ServiceHealth
        Write-Host ""

        Write-Separator
        Write-Success "Update complete!"
        Write-Separator
    } else {
        Write-Info "No action needed"
    }

    Write-Host ""
    Write-Info "Done"
}

# Run main
try {
    Main
}
catch {
    Write-Host ""
    Write-Error "An error occurred: $_"
    exit 1
}
