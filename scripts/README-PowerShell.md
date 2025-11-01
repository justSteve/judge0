# Judge0 Management Scripts (PowerShell)

PowerShell scripts for managing Judge0 on Azure Windows VMs.

## Scripts Overview

### 1. `Check-And-Update.ps1` - Main Update Script
Checks GitHub for updates and automatically updates & restarts Judge0 if changes are found.

**Usage:**
```powershell
# Check for updates and apply if found
.\Check-And-Update.ps1

# Force update even if no changes detected
.\Check-And-Update.ps1 -Force

# Check what updates are available without applying
.\Check-And-Update.ps1 -DryRun

# Check different remote or branch
.\Check-And-Update.ps1 -Remote upstream -Branch extra
```

**Features:**
- Fetches latest changes from GitHub remote
- Compares local vs remote commits
- Shows changelog of what changed
- Checks for local modifications (prevents accidental overwrites)
- Pulls updates
- Restarts Docker containers
- Validates service health

**Parameters:**
- `-Force` - Force update even if no changes
- `-DryRun` - Check for updates without applying
- `-Remote` - Git remote to check (default: origin)
- `-Branch` - Git branch to check (default: master)
- `-ComposeFile` - Docker compose file (default: docker-compose.yml)

### 2. `Restart-Judge0.ps1` - Simple Restart
Quickly restart Judge0 services without checking for updates.

**Usage:**
```powershell
# Restart production instance
.\Restart-Judge0.ps1

# Restart development instance
.\Restart-Judge0.ps1 -Dev
```

### 3. `Get-Judge0Status.ps1` - Status Check
Check the current status of Judge0 services.

**Usage:**
```powershell
# Check local instance
.\Get-Judge0Status.ps1

# Check remote instance
.\Get-Judge0Status.ps1 -ApiUrl "http://your-vm-ip:2358"
```

**Shows:**
- Git repository status (branch, commits, sync status)
- Docker container status
- API health check
- Version information
- Disk space usage

## Setup on Azure Windows VM

### First Time Setup

1. **Connect via Azure Cloud Shell or RDP**
   ```powershell
   # If using Cloud Shell, you'll be in PowerShell by default
   ```

2. **Navigate to Judge0 directory:**
   ```powershell
   cd C:\path\to\judge0
   ```

3. **Check execution policy:**
   ```powershell
   Get-ExecutionPolicy

   # If it's Restricted, allow scripts to run:
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

4. **Test the status script:**
   ```powershell
   .\scripts\Get-Judge0Status.ps1
   ```

### Automated Updates with Task Scheduler

To automatically check for updates every hour:

1. **Create a scheduled task:**
   ```powershell
   # Create the task
   $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
       -Argument "-ExecutionPolicy Bypass -File C:\path\to\judge0\scripts\Check-And-Update.ps1" `
       -WorkingDirectory "C:\path\to\judge0\scripts"

   $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)

   $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

   Register-ScheduledTask -TaskName "Judge0-AutoUpdate" `
       -Action $action `
       -Trigger $trigger `
       -Principal $principal `
       -Description "Automatically check for Judge0 updates every hour"
   ```

2. **Or use Task Scheduler GUI:**
   - Open Task Scheduler (`taskschd.msc`)
   - Create Basic Task
   - Name: "Judge0 Auto Update"
   - Trigger: Daily, repeat every 1 hour
   - Action: Start a program
   - Program: `PowerShell.exe`
   - Arguments: `-ExecutionPolicy Bypass -File C:\path\to\judge0\scripts\Check-And-Update.ps1`
   - Start in: `C:\path\to\judge0\scripts`

3. **View task logs:**
   ```powershell
   Get-ScheduledTask -TaskName "Judge0-AutoUpdate" | Get-ScheduledTaskInfo
   ```

### Alternative: Simple Cron-like Scheduling

Create a simple loop script that runs forever:

```powershell
# Save as Run-Judge0-Monitor.ps1
while ($true) {
    Write-Host "$(Get-Date) - Checking for updates..."
    & "C:\path\to\judge0\scripts\Check-And-Update.ps1"

    # Wait 1 hour
    Start-Sleep -Seconds 3600
}
```

Then run it as a background job or in a separate PowerShell window.

## Common Workflows

### Manual Update Check
```powershell
# Check if updates are available
.\scripts\Check-And-Update.ps1 -DryRun

# Apply updates if available
.\scripts\Check-And-Update.ps1
```

### Quick Restart
```powershell
# Just restart services
.\scripts\Restart-Judge0.ps1
```

### Health Check
```powershell
# Check everything is running
.\scripts\Get-Judge0Status.ps1
```

### Force Update and Restart
```powershell
# Force pull latest and restart (even if no changes)
.\scripts\Check-And-Update.ps1 -Force
```

### Remote Status Check
```powershell
# Check Judge0 running on another machine
.\scripts\Get-Judge0Status.ps1 -ApiUrl "http://10.0.0.5:2358"
```

## Troubleshooting

### Script says "execution of scripts is disabled"
Set the execution policy:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Script says "local changes detected"
You have uncommitted changes. Either commit them or stash:
```powershell
git status
git stash  # Temporarily save changes
# or
git add .
git commit -m "Local changes"
```

### Services won't start
Check Docker logs:
```powershell
cd C:\path\to\judge0
docker-compose logs
```

### API not responding
Wait a few seconds after restart, then check:
```powershell
Invoke-WebRequest -Uri "http://localhost:2358/about" -UseBasicParsing
```

### Azure Cloud Shell timeout issues
Use Task Scheduler or Windows Service to run updates automatically, or:
- Keep session alive by running status checks periodically
- Use RDP instead of Cloud Shell for long-running tasks
- Set up automated tasks that don't require active session

## Integration with Judge0 DSPy Lessons

After updating Judge0, test it with the DSPy lessons:

1. **Update the API endpoint in the lesson:**
   ```powershell
   # Edit 01_hello_dspy_j0.py and set:
   # For local instance:
   $apiUrl = "http://localhost:2358"
   # For Azure VM (from another machine):
   $apiUrl = "http://your-azure-vm-ip:2358"
   ```

2. **Update the lesson script to use local Judge0:**
   In `01_hello_dspy_j0.py`, uncomment the local instance URLs:
   ```python
   # For local Judge0 instance:
   url = "http://localhost:2358/submissions?wait=true"
   headers = {"content-type": "application/json"}
   ```

3. **Test the connection:**
   ```powershell
   python .dspy\lessons\basics\01_hello_dspy_j0.py
   ```

## Script Output Examples

### Successful Update:
```
==============================================================
Judge0 Update Checker (PowerShell)
Directory: C:\judge0
Remote: origin
Branch: master
==============================================================

[INFO] Checking requirements...
[SUCCESS] All requirements met

[INFO] Checking for updates from origin/master...
[INFO] Fetching from remote...
[INFO] Local commit:  abc123def
[INFO] Remote commit: xyz789uvw

[INFO] Changes found:

xyz789u Update language versions
abc456d Fix memory limit handling

==============================================================
[INFO] Starting update process...
==============================================================

[INFO] Pulling updates from origin/master...
[SUCCESS] Updates pulled successfully

[INFO] Restarting Judge0 services...
[INFO] Stopping services...
[INFO] Starting services...
[SUCCESS] Judge0 services restarted

[INFO] Checking service health...
[SUCCESS] API is responding
[INFO] Version: 1.13.0

==============================================================
[SUCCESS] Update complete!
==============================================================
```

### No Updates Available:
```
[INFO] Checking for updates from origin/master...
[INFO] Local commit:  abc123def
[INFO] Remote commit: abc123def

[SUCCESS] Already up to date!
[INFO] No action needed
```

## Notes

- All scripts use proper PowerShell error handling
- Color-coded output for easy reading
- Safe defaults (won't overwrite local changes)
- Validates prerequisites before running
- Works with Azure Cloud Shell and RDP sessions
- Compatible with PowerShell 5.1+ and PowerShell Core

## Links

- [Judge0 Documentation](https://ce.judge0.com)
- [Judge0 GitHub](https://github.com/judge0/judge0)
- [Docker for Windows](https://docs.docker.com/desktop/install/windows-install/)

## License

These scripts are part of the Judge0 project. See main LICENSE file.
