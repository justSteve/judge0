<#
.SYNOPSIS
    Creates a dedicated minimal WSL2 instance for hosting Judge0.

.DESCRIPTION
    This script creates a fresh, minimal Ubuntu WSL2 instance specifically
    for running Judge0. It:
    1. Downloads Ubuntu 22.04 minimal rootfs
    2. Creates a new WSL instance named 'judge0-wsl'
    3. Configures Docker integration
    4. Sets up Judge0 using the local Windows repo
    
    The Judge0 source is mounted from your Windows filesystem, making it
    editable from both Windows and WSL.

.PARAMETER InstanceName
    Name for the WSL instance (default: judge0-wsl)

.PARAMETER InstallPath
    Where to store the WSL instance (default: C:\WSL\judge0-wsl)

.PARAMETER Judge0WindowsPath
    Windows path to your Judge0 repo (default: C:\myStuff\_tooling\Judge0)

.PARAMETER Force
    Remove existing instance if it exists

.EXAMPLE
    .\Create-Judge0-WSL.ps1

.EXAMPLE
    .\Create-Judge0-WSL.ps1 -Force -InstanceName "judge0-dev"
#>

[CmdletBinding()]
param(
    [string]$InstanceName = "judge0-wsl",
    [string]$InstallPath = "C:\WSL\judge0-wsl",
    [string]$Judge0WindowsPath = "C:\myStuff\_tooling\Judge0",
    [switch]$Force,
    [switch]$SkipDockerCheck
)

$ErrorActionPreference = "Stop"

#region Configuration
# Ubuntu Base (minimal) rootfs - official Canonical release
# These are ~30MB minimal installations, perfect for purpose-built instances
$UbuntuBaseUrl = "https://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04-base-amd64.tar.gz"
$TempDownloadPath = "$env:TEMP\ubuntu-base-22.04-amd64.tar.gz"
#endregion

#region Helper Functions
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text)
    Write-Host "[STEP] " -ForegroundColor Blue -NoNewline
    Write-Host $Text
}

function Write-SubStep {
    param([string]$Text)
    Write-Host "       " -NoNewline
    Write-Host $Text -ForegroundColor Gray
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

function Write-ErrorMsg {
    param([string]$Text)
    Write-Host "[✗] " -ForegroundColor Red -NoNewline
    Write-Host $Text
}

function Write-Info {
    param([string]$Text)
    Write-Host "[i] " -ForegroundColor Cyan -NoNewline
    Write-Host $Text
}
#endregion

#region Banner
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         Judge0 Dedicated WSL2 Instance Creator                        ║" -ForegroundColor Cyan
Write-Host "║         Creates a minimal Ubuntu instance for hosting Judge0          ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Info "Instance Name:    $InstanceName"
Write-Info "Install Location: $InstallPath"
Write-Info "Judge0 Source:    $Judge0WindowsPath"
Write-Host ""
#endregion

#region Prerequisites Check
Write-Header "Checking Prerequisites"

# Check if running as admin (needed for WSL operations)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Not running as Administrator - some operations may fail"
}

# Check WSL
Write-Step "Checking WSL installation..."
try {
    $wslVersion = wsl --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "WSL not properly installed"
    }
    Write-Success "WSL is installed"
    
    # Ensure WSL2 is default
    Write-Step "Ensuring WSL2 is default version..."
    wsl --set-default-version 2 2>&1 | Out-Null
    Write-Success "WSL2 set as default"
}
catch {
    Write-ErrorMsg "WSL is not installed or not working"
    Write-Host ""
    Write-Host "Install WSL with: " -NoNewline
    Write-Host "wsl --install" -ForegroundColor Yellow
    exit 1
}

# Check Docker Desktop
if (-not $SkipDockerCheck) {
    Write-Step "Checking Docker Desktop..."
    $dockerProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
    if ($dockerProcess) {
        Write-Success "Docker Desktop is running"
    }
    else {
        Write-Warning "Docker Desktop doesn't appear to be running"
        Write-Host "       Please start Docker Desktop before continuing" -ForegroundColor Yellow
        $continue = Read-Host "       Continue anyway? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            exit 1
        }
    }
}

# Check Judge0 source exists
Write-Step "Checking Judge0 source directory..."
if (-not (Test-Path $Judge0WindowsPath)) {
    Write-ErrorMsg "Judge0 source not found at: $Judge0WindowsPath"
    exit 1
}
if (-not (Test-Path "$Judge0WindowsPath\docker-compose.yml")) {
    Write-ErrorMsg "docker-compose.yml not found - is this a valid Judge0 directory?"
    exit 1
}
Write-Success "Judge0 source found"
#endregion

#region Check Existing Instance
Write-Header "Checking for Existing Instance"

$existingDistros = wsl --list --quiet 2>&1 | Where-Object { $_ -and $_ -notmatch "^\s*$" }
$instanceExists = $existingDistros -contains $InstanceName

if ($instanceExists) {
    if ($Force) {
        Write-Warning "Instance '$InstanceName' exists - removing (--Force specified)"
        Write-Step "Terminating instance..."
        wsl --terminate $InstanceName 2>&1 | Out-Null
        Write-Step "Unregistering instance..."
        wsl --unregister $InstanceName 2>&1 | Out-Null
        Write-Success "Existing instance removed"
    }
    else {
        Write-ErrorMsg "Instance '$InstanceName' already exists!"
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host "  1. Use -Force to remove and recreate"
        Write-Host "  2. Use -InstanceName to specify a different name"
        Write-Host "  3. Manually remove: wsl --unregister $InstanceName"
        exit 1
    }
}
else {
    Write-Success "No existing instance named '$InstanceName'"
}
#endregion

#region Download Ubuntu Rootfs
Write-Header "Downloading Ubuntu 22.04 Base (Minimal)"

if (Test-Path $TempDownloadPath) {
    Write-Info "Using cached download: $TempDownloadPath"
    Write-SubStep "Delete this file to force re-download"
}
else {
    Write-Step "Downloading Ubuntu 22.04 minimal base rootfs..."
    Write-SubStep "Source: cdimage.ubuntu.com (official Canonical)"
    Write-SubStep "This is a minimal ~30MB base system"
    
    try {
        $ProgressPreference = 'SilentlyContinue'  # Speed up download
        Invoke-WebRequest -Uri $UbuntuBaseUrl -OutFile $TempDownloadPath -UseBasicParsing
        $ProgressPreference = 'Continue'
        Write-Success "Download complete"
    }
    catch {
        Write-ErrorMsg "Download failed: $_"
        Write-Host ""
        Write-Host "If the URL has changed, check:" -ForegroundColor Yellow
        Write-Host "  https://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/" -ForegroundColor White
        exit 1
    }
}

$fileSize = (Get-Item $TempDownloadPath).Length / 1MB
Write-SubStep "File size: $([math]::Round($fileSize, 1)) MB"
#endregion

#region Create WSL Instance
Write-Header "Creating WSL Instance"

# Create install directory
Write-Step "Creating install directory..."
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}
Write-Success "Directory ready: $InstallPath"

# Import the distribution
Write-Step "Importing Ubuntu as '$InstanceName'..."
Write-SubStep "This may take a minute..."
try {
    wsl --import $InstanceName $InstallPath $TempDownloadPath --version 2
    if ($LASTEXITCODE -ne 0) {
        throw "WSL import failed"
    }
    Write-Success "Instance created successfully"
}
catch {
    Write-ErrorMsg "Failed to create WSL instance: $_"
    exit 1
}
#endregion

#region Configure Instance
Write-Header "Configuring WSL Instance"

# Create setup script to run inside WSL
$setupScript = @'
#!/bin/bash
set -e

echo "=== Configuring Judge0 WSL Instance ==="

# Update package lists
echo "[1/6] Updating package lists..."
apt-get update -qq

# Install essential packages
echo "[2/6] Installing essential packages..."
apt-get install -y -qq \
    curl \
    git \
    jq \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo

# Create judge0 user
echo "[3/6] Creating judge0 user..."
if ! id "judge0" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo judge0
    echo "judge0 ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/judge0
    chmod 440 /etc/sudoers.d/judge0
fi

# Configure WSL settings
echo "[4/6] Configuring WSL settings..."
cat > /etc/wsl.conf << 'WSLCONF'
[automount]
enabled = true
root = /mnt/
options = "metadata,umask=22,fmask=11"

[network]
generateResolvConf = true

[interop]
enabled = true
appendWindowsPath = true

[user]
default = judge0

[boot]
systemd = false
WSLCONF

# Create convenience symlink
echo "[5/6] Creating convenience symlink..."
JUDGE0_WSL_PATH="/mnt/c/myStuff/_tooling/Judge0"
if [ -d "$JUDGE0_WSL_PATH" ]; then
    ln -sf "$JUDGE0_WSL_PATH" /home/judge0/judge0
    chown -h judge0:judge0 /home/judge0/judge0
    echo "  Symlink created: ~/judge0 -> $JUDGE0_WSL_PATH"
fi

# Create shell profile additions with hardcoded paths (more reliable)
echo "[6/6] Setting up shell environment..."
cat >> /home/judge0/.bashrc << 'BASHRC'

# =============================================================================
# Judge0 Environment
# =============================================================================
export JUDGE0_DIR="/mnt/c/myStuff/_tooling/Judge0"

# Aliases with hardcoded paths (don't rely on variable expansion)
alias j0='cd /mnt/c/myStuff/_tooling/Judge0'
alias j0-up='cd /mnt/c/myStuff/_tooling/Judge0 && docker-compose up -d'
alias j0-down='cd /mnt/c/myStuff/_tooling/Judge0 && docker-compose down'
alias j0-logs='cd /mnt/c/myStuff/_tooling/Judge0 && docker-compose logs -f'
alias j0-ps='cd /mnt/c/myStuff/_tooling/Judge0 && docker-compose ps'
alias j0-restart='cd /mnt/c/myStuff/_tooling/Judge0 && docker-compose restart'

# Custom prompt
PS1='\[\033[01;32m\][judge0-wsl]\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
BASHRC

chown judge0:judge0 /home/judge0/.bashrc

echo ""
echo "=== Base configuration complete ==="
'@

Write-Step "Running initial configuration..."

# Convert Windows line endings (CRLF) to Unix (LF)
$setupScriptUnix = $setupScript -replace "`r`n", "`n"

# Write to Windows temp with Unix line endings (no BOM)
$tempScriptPath = "$env:TEMP\judge0-setup.sh"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($tempScriptPath, $setupScriptUnix, $utf8NoBom)

# Build the WSL path manually: C:\Users\steve\AppData\Local\Temp -> /mnt/c/Users/steve/AppData/Local/Temp
$driveLetter = $tempScriptPath.Substring(0, 1).ToLower()
$pathWithoutDrive = $tempScriptPath.Substring(2) -replace '\\', '/'
$wslScriptPath = "/mnt/$driveLetter$pathWithoutDrive"

Write-SubStep "Script path: $wslScriptPath"

# Execute the script
wsl -d $InstanceName -- bash "$wslScriptPath"

$exitCode = $LASTEXITCODE

# Cleanup
Remove-Item $tempScriptPath -Force -ErrorAction SilentlyContinue

if ($exitCode -ne 0) {
    Write-ErrorMsg "Configuration failed (exit code: $exitCode)"
    exit 1
}

Write-Success "Base configuration complete"

# Restart to apply wsl.conf
Write-Step "Restarting instance to apply settings..."
wsl --terminate $InstanceName 2>&1 | Out-Null
Start-Sleep -Seconds 2
Write-Success "Instance restarted"
#endregion

#region Verify Setup
Write-Header "Verifying Setup"

# Convert Windows path to WSL path for the script
$judge0WslPath = "/mnt/" + ($Judge0WindowsPath -replace '\\', '/' -replace ':', '').ToLower()

Write-Step "Judge0 path in WSL: $judge0WslPath"

# Test that the path is accessible
Write-Step "Verifying Judge0 source is accessible from WSL..."
$testAccess = wsl -d $InstanceName -- test -f "$judge0WslPath/docker-compose.yml" '&&' echo "OK" 2>&1
if ($testAccess -match "OK") {
    Write-Success "Judge0 source is accessible"
}
else {
    Write-Warning "Could not verify Judge0 source access"
}

# Check if Docker is available
Write-Step "Checking Docker availability..."
$dockerCheck = wsl -d $InstanceName -- docker --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "Docker is available: $dockerCheck"
}
else {
    Write-Warning "Docker not available - enable WSL Integration in Docker Desktop"
}
#endregion

#region Apply cgroups v2 Fix
Write-Header "Applying WSL2/Docker cgroups v2 Compatibility Fix"

Write-Step "Patching judge0.conf for cgroups v2 compatibility..."
Write-SubStep "WSL2/Docker Desktop uses cgroups v2, but isolate requires v1"
Write-SubStep "Disabling cgroups by enabling per-process limits"

$judge0ConfPath = "$Judge0WindowsPath\judge0.conf"
$confContent = Get-Content $judge0ConfPath -Raw

# Check if already patched
if ($confContent -match "ENABLE_PER_PROCESS_AND_THREAD_TIME_LIMIT=true") {
    Write-Info "judge0.conf already configured for cgroups v2"
}
else {
    # Patch ENABLE_PER_PROCESS_AND_THREAD_TIME_LIMIT
    $confContent = $confContent -replace `
        '(?m)^(# If true then CPU_TIME_LIMIT will be used as per process and thread\.\r?\n# Default: false.*\r?\n)ENABLE_PER_PROCESS_AND_THREAD_TIME_LIMIT=\s*$', `
        '$1# NOTE: Set to true to disable cgroups (required for WSL2/Docker Desktop cgroups v2)
ENABLE_PER_PROCESS_AND_THREAD_TIME_LIMIT=true'

    # Patch ENABLE_PER_PROCESS_AND_THREAD_MEMORY_LIMIT
    $confContent = $confContent -replace `
        '(?m)^(# If true then MEMORY_LIMIT will be used as per process and thread\.\r?\n# Default: false.*\r?\n)ENABLE_PER_PROCESS_AND_THREAD_MEMORY_LIMIT=\s*$', `
        '$1# NOTE: Set to true to disable cgroups (required for WSL2/Docker Desktop cgroups v2)
ENABLE_PER_PROCESS_AND_THREAD_MEMORY_LIMIT=true'

    Set-Content -Path $judge0ConfPath -Value $confContent -NoNewline
    Write-Success "judge0.conf patched for cgroups v2 compatibility"
}
#endregion

#region Summary
Write-Header "Setup Complete!"

Write-Host ""
Write-Success "WSL instance '$InstanceName' is ready!"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  NEXT STEP - Enable Docker Integration:" -ForegroundColor Yellow
Write-Host ""
Write-Host "    1. Open Docker Desktop" -ForegroundColor White
Write-Host "    2. Settings → Resources → WSL Integration" -ForegroundColor White
Write-Host "    3. Enable toggle for '$InstanceName'" -ForegroundColor White
Write-Host "    4. Click 'Apply & Restart'" -ForegroundColor White
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Quick Start (after Docker integration):" -ForegroundColor Cyan
Write-Host ""
Write-Host "    wsl -d $InstanceName" -ForegroundColor White
Write-Host "    j0-up" -ForegroundColor White
Write-Host ""
Write-Host "  Or directly from PowerShell:" -ForegroundColor Cyan
Write-Host ""
Write-Host "    wsl -d $InstanceName -- bash -c 'cd /mnt/c/myStuff/_tooling/Judge0 && docker-compose up -d'" -ForegroundColor White
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Available Aliases (inside WSL):" -ForegroundColor Cyan
Write-Host ""
Write-Host "    j0          - Navigate to Judge0 directory" -ForegroundColor Gray
Write-Host "    j0-up       - Start Judge0 services" -ForegroundColor Gray
Write-Host "    j0-down     - Stop Judge0 services" -ForegroundColor Gray
Write-Host "    j0-logs     - View logs (follow mode)" -ForegroundColor Gray
Write-Host "    j0-ps       - Show container status" -ForegroundColor Gray
Write-Host "    j0-restart  - Restart all services" -ForegroundColor Gray
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Management:" -ForegroundColor Cyan
Write-Host ""
Write-Host "    wsl --list --verbose              # List WSL instances" -ForegroundColor Gray
Write-Host "    wsl --unregister $InstanceName    # Remove this instance" -ForegroundColor Gray
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Access Judge0 (after starting):" -ForegroundColor Cyan
Write-Host ""
Write-Host "    API:  http://localhost:2358" -ForegroundColor White
Write-Host "    Docs: http://localhost:2358/docs" -ForegroundColor White
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

# Offer to enter the instance
$enterInstance = Read-Host "Enter the new WSL instance now? (Y/n)"
if ($enterInstance -ne 'n' -and $enterInstance -ne 'N') {
    Write-Host ""
    Write-Host "Entering $InstanceName..." -ForegroundColor Cyan
    Write-Host "(Type 'exit' to return to PowerShell)" -ForegroundColor Gray
    Write-Host ""
    wsl -d $InstanceName
}
#endregion
