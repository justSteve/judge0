# Feature 1: Judge0 Infrastructure Management

## Overview

Automated management scripts for Judge0 deployments on Azure Windows VMs and Linux servers.

## Status

✅ **COMPLETE** - Ready for deployment

## Problem Statement

Managing Judge0 deployments requires:
- Checking for updates from GitHub
- Safely pulling and applying updates
- Restarting Docker services
- Health monitoring
- Preventing downtime

Manual management is error-prone and time-consuming.

## Solution

Automated PowerShell and Bash scripts that:
1. Check GitHub remote for updates
2. Show changelog before applying
3. Safely pull updates (with local change detection)
4. Restart Docker services
5. Validate health after restart
6. Support scheduling for automated updates

## Components

### PowerShell Scripts (Windows/Azure)

**Location:** `scripts/`

1. **Check-And-Update.ps1**
   - Main update automation script
   - Fetches from GitHub remote
   - Compares commits and shows changelog
   - Pulls updates safely
   - Restarts services
   - Health validation
   - Supports: `-Force`, `-DryRun`

2. **Restart-Judge0.ps1**
   - Quick service restart
   - Dev/prod mode support
   - No update checking

3. **Get-Judge0Status.ps1**
   - Comprehensive status check
   - Git sync status
   - Docker container status
   - API health check
   - Disk space monitoring

### Bash Scripts (Linux)

**Location:** `scripts/`

1. **check-and-update.sh** - Same functionality as PowerShell version
2. **restart.sh** - Service restart script
3. **status.sh** - Status checker

### Documentation

- `scripts/README-PowerShell.md` - Complete PowerShell guide
- `scripts/README.md` - Bash scripts guide

## Features

### ✅ Update Management
- Automatic Git fetch and comparison
- Changelog display
- Safe update with local change detection
- Rollback capability

### ✅ Service Management
- Docker compose integration
- Graceful restart
- Health validation
- Dev/prod mode support

### ✅ Monitoring
- Git repository sync status
- Container health
- API availability
- Disk space monitoring

### ✅ Automation
- Task Scheduler integration (Windows)
- Cron support (Linux)
- Logging support
- Email notifications (extensible)

## Usage

### Manual Update Check

```powershell
# Check for updates (dry run)
.\scripts\Check-And-Update.ps1 -DryRun

# Apply updates if available
.\scripts\Check-And-Update.ps1

# Force update
.\scripts\Check-And-Update.ps1 -Force
```

### Quick Restart

```powershell
.\scripts\Restart-Judge0.ps1
```

### Status Check

```powershell
.\scripts\Get-Judge0Status.ps1
```

### Automated Updates (Task Scheduler)

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File C:\judge0\scripts\Check-And-Update.ps1"

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Hours 1)

Register-ScheduledTask -TaskName "Judge0-AutoUpdate" `
    -Action $action -Trigger $trigger
```

## Installation

### Prerequisites
- Git
- Docker
- Docker Compose
- PowerShell 5.1+ (Windows) or Bash (Linux)

### Setup

1. **Clone/pull Judge0 repository**
2. **Make scripts executable** (Linux):
   ```bash
   chmod +x scripts/*.sh
   ```
3. **Set execution policy** (Windows):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
4. **Test status script**:
   ```powershell
   .\scripts\Get-Judge0Status.ps1
   ```

## Configuration

### Environment Variables (Optional)

```powershell
$env:JUDGE0_DIR = "C:\path\to\judge0"
$env:REMOTE = "origin"
$env:BRANCH = "master"
$env:COMPOSE_FILE = "docker-compose.yml"
```

### Script Parameters

All scripts support parameters for customization:
- Remote repository
- Branch selection
- Compose file selection
- Timeout values

## Benefits

1. **Reliability** - Automated updates reduce human error
2. **Safety** - Local change detection prevents data loss
3. **Visibility** - Clear changelog before applying updates
4. **Flexibility** - Dry-run mode, force updates, scheduling
5. **Monitoring** - Health checks ensure services are running
6. **Cross-Platform** - Windows and Linux support

## Testing

### Test Scenarios

1. ✅ Update check with no updates available
2. ✅ Update check with updates available
3. ✅ Dry-run mode (no changes applied)
4. ✅ Force update when already up-to-date
5. ✅ Local changes detection
6. ✅ Service restart
7. ✅ Health check validation
8. ✅ Scheduled task execution

## Deployment Checklist

- [ ] Clone scripts to production server
- [ ] Test manual update check
- [ ] Test service restart
- [ ] Configure scheduled task/cron
- [ ] Set up logging directory
- [ ] Test scheduled execution
- [ ] Monitor logs for issues

## Future Enhancements

### Planned
- Email notifications on update
- Slack/Teams webhook integration
- Metrics collection
- Update rollback automation
- Multi-instance management

### Proposed
- Web dashboard
- Automatic backup before update
- Blue-green deployment support
- Kubernetes operator

## Support

**Documentation:**
- [PowerShell README](scripts/README-PowerShell.md)
- [Bash README](scripts/README.md)

**Common Issues:**
- Execution policy errors → Set RemoteSigned
- Local changes detected → Commit or stash changes
- API not responding → Wait 30s after restart
- Docker errors → Check Docker service status

## Metrics

**Code:**
- 3 PowerShell scripts (~700 lines)
- 3 Bash scripts (~500 lines)
- 2 README files

**Testing:**
- Manual testing on Azure Windows VM
- Error handling validated
- Edge cases covered

## Sign-Off

**Feature:** Infrastructure Management Scripts
**Status:** ✅ Complete
**Ready for:** Production deployment
**Dependencies:** Git, Docker, Docker Compose
**Platforms:** Windows (PowerShell), Linux (Bash)
**Documentation:** Complete
**Testing:** Manual validation complete

---

**Submitted by:** Claude Code
**Date:** 2025-11-01
**Version:** 1.0
