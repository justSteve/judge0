<#
.SYNOPSIS
    Bootstrap Judge0 installation in WSL2 from Windows.

.DESCRIPTION
    This script prepares and launches the Judge0 WSL2 setup from Windows.
    It verifies prerequisites and copies/runs the setup script in WSL.

.PARAMETER WslDistro
    The WSL distribution to use (default: Ubuntu)

.PARAMETER Judge0Path
    Path in WSL where Judge0 will be installed (default: ~/judge0)

.PARAMETER SkipPrereqCheck
    Skip prerequisite verification

.EXAMPLE
    .\Bootstrap-Judge0-WSL.ps1

.EXAMPLE
    .\Bootstrap-Judge0-WSL.ps1 -WslDistro "Ubuntu-22.04" -Judge0Path "/opt/judge0"
#>

param(
    [string]$WslDistro = "",
    [string]$Judge0Path = "~/judge0",
    [switch]$SkipPrereqCheck,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

#region Helper Functions
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text)
    Write-Host "[STEP] " -ForegroundColor Blue -NoNewline
    Write-Host $Text
}

function Write-Success {
    param([string]$Text)
    Write-Host "[✓] " -ForegroundColor Green -NoNewline
    Write-Host $Text
}

function Write-Warning {
    param([string]$Text)
    Write-Host "[!] " -ForegroundColor Yellow -NoNewline
    Write-Host $Text
}

function Write-Error {
    param([string]$Text)
    Write-Host "[✗] " -ForegroundColor Red -NoNewline
    Write-Host $Text
}

function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}
#endregion

#region Main Script
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       Judge0 WSL2 Bootstrap (Windows Launcher)            ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

#region Check Prerequisites
if (-not $SkipPrereqCheck) {
    Write-Header "Checking Prerequisites"
    
    # Check WSL
    Write-Step "Checking WSL installation..."
    if (-not (Test-Command "wsl")) {
        Write-Error "WSL is not installed!"
        Write-Host ""
        Write-Host "To install WSL, run in PowerShell (Admin):"
        Write-Host "  wsl --install" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
    
    $wslStatus = wsl --status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "WSL may not be properly configured"
    }
    else {
        Write-Success "WSL is installed"
    }
    
    # Check WSL2 default
    Write-Step "Checking WSL version..."
    $wslVersion = wsl --version 2>&1
    if ($wslVersion -match "WSL.*: (\d+)") {
        Write-Success "WSL version detected"
    }
    
    # List distributions
    Write-Step "Checking available distributions..."
    $distros = wsl --list --quiet 2>&1 | Where-Object { $_ -and $_ -notmatch "^$" }
    
    if (-not $distros -or $distros.Count -eq 0) {
        Write-Error "No WSL distributions found!"
        Write-Host ""
        Write-Host "Install a distribution:"
        Write-Host "  wsl --install -d Ubuntu-22.04" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
    
    Write-Success "Found distributions: $($distros -join ', ')"
    
    # Auto-select distro if not specified
    if (-not $WslDistro) {
        # Prefer Ubuntu variants
        $WslDistro = $distros | Where-Object { $_ -match "Ubuntu" } | Select-Object -First 1
        if (-not $WslDistro) {
            $WslDistro = $distros | Select-Object -First 1
        }
        Write-Host "  Using distribution: $WslDistro" -ForegroundColor Cyan
    }
    
    # Check Docker Desktop
    Write-Step "Checking Docker Desktop..."
    $dockerPath = "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerPath) {
        Write-Success "Docker Desktop is installed"
    }
    else {
        Write-Warning "Docker Desktop not found at expected location"
        Write-Host "  Please ensure Docker Desktop is installed" -ForegroundColor Yellow
    }
    
    # Check Docker in WSL
    Write-Step "Checking Docker in WSL..."
    $dockerCheck = wsl -d $WslDistro -- docker --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker available in WSL: $dockerCheck"
    }
    else {
        Write-Error "Docker not available in WSL!"
        Write-Host ""
        Write-Host "Please configure Docker Desktop WSL Integration:"
        Write-Host "  1. Open Docker Desktop"
        Write-Host "  2. Settings → Resources → WSL Integration"
        Write-Host "  3. Enable integration for '$WslDistro'"
        Write-Host "  4. Apply & Restart"
        Write-Host ""
        
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            exit 1
        }
    }
}
#endregion

#region Prepare Setup Script
Write-Header "Preparing Installation"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$setupScript = Join-Path $scriptDir "setup-wsl.sh"

if (-not (Test-Path $setupScript)) {
    Write-Error "Setup script not found at: $setupScript"
    Write-Host "Please ensure setup-wsl.sh exists in the same directory"
    exit 1
}

Write-Success "Found setup script: $setupScript"

# Convert Windows path to WSL path
$wslScriptPath = wsl -d $WslDistro -- wslpath -u "$setupScript" 2>&1
Write-Host "  WSL path: $wslScriptPath" -ForegroundColor Gray
#endregion

#region Run Setup in WSL
Write-Header "Running Setup in WSL"

Write-Step "Launching Judge0 setup in $WslDistro..."
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host " Entering WSL environment..." -ForegroundColor DarkGray
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host ""

# Make script executable and run it
$wslCommand = @"
chmod +x '$wslScriptPath' && '$wslScriptPath' --judge0-dir '$Judge0Path'
"@

wsl -d $WslDistro -- bash -c $wslCommand

$exitCode = $LASTEXITCODE

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host " Returned from WSL environment" -ForegroundColor DarkGray
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
#endregion

#region Summary
Write-Host ""
if ($exitCode -eq 0) {
    Write-Header "Setup Complete!"
    Write-Host ""
    Write-Success "Judge0 is now running in WSL2!"
    Write-Host ""
    Write-Host "Access from Windows:" -ForegroundColor Cyan
    Write-Host "  • API:  http://localhost:2358" -ForegroundColor White
    Write-Host "  • Docs: http://localhost:2358/docs" -ForegroundColor White
    Write-Host ""
    Write-Host "Management (run in WSL):" -ForegroundColor Cyan
    Write-Host "  cd $Judge0Path && docker-compose ps" -ForegroundColor Gray
    Write-Host ""
}
else {
    Write-Header "Setup Failed"
    Write-Error "Setup did not complete successfully (exit code: $exitCode)"
    Write-Host ""
    Write-Host "Check the output above for errors." -ForegroundColor Yellow
    Write-Host "You can also try running the setup manually in WSL:" -ForegroundColor Yellow
    Write-Host "  wsl -d $WslDistro" -ForegroundColor Gray
    Write-Host "  cd ~ && git clone https://github.com/judge0/judge0.git" -ForegroundColor Gray
    Write-Host "  cd judge0 && ./scripts/wsl/setup-wsl.sh" -ForegroundColor Gray
}
#endregion

exit $exitCode
