# Judge0 WSL2 Setup Guide

Run Judge0 on a dedicated, minimal WSL2 instance with your local editable source.

## Quick Start (Recommended)

### One Command Setup

```powershell
# From PowerShell - creates dedicated 'judge0-wsl' instance
cd C:\myStuff\_tooling\Judge0\scripts\wsl
.\Create-Judge0-WSL.ps1
```

This will:
1. Download Ubuntu 22.04 minimal (~500MB)
2. Create a dedicated WSL instance named `judge0-wsl`
3. Configure it with Docker integration
4. Mount your local Judge0 source from `C:\myStuff\_tooling\Judge0`

### After Setup

```powershell
# Enter the Judge0 WSL instance
wsl -d judge0-wsl

# Start Judge0 (uses aliases configured automatically)
j0-up

# Or use the full startup script with options
./scripts/wsl/start-judge0.sh --pull --logs
```

### Access Judge0

- **API**: http://localhost:2358
- **Docs**: http://localhost:2358/docs

---

## Why a Dedicated Instance?

| Benefit | Description |
|---------|-------------|
| **Isolation** | Judge0 containers don't affect your main WSL |
| **Minimal** | Clean Ubuntu with only what's needed |
| **Reproducible** | Easy to destroy and recreate |
| **Editable Source** | Your Windows repo is mounted, edit from VS Code |

---

## Prerequisites

### 1. WSL2 Enabled

```powershell
# In PowerShell (Administrator)
wsl --install
wsl --set-default-version 2
```

### 2. Docker Desktop

1. **Download**: [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
2. **Install** with default options
3. **Enable WSL2 backend**: Settings → General → "Use the WSL 2 based engine"

**Important**: After creating the WSL instance, enable Docker integration:
- Settings → Resources → WSL Integration → Enable for `judge0-wsl`

---

## Available Commands (Inside WSL)

Once inside `judge0-wsl`, these aliases are available:

| Alias | Command | Description |
|-------|---------|-------------|
| `j0` | `cd $JUDGE0_DIR` | Navigate to Judge0 directory |
| `j0-up` | `docker-compose up -d` | Start all services |
| `j0-down` | `docker-compose down` | Stop all services |
| `j0-logs` | `docker-compose logs -f` | Follow logs |
| `j0-ps` | `docker-compose ps` | Show container status |
| `j0-restart` | `docker-compose restart` | Restart all services |

---

## Startup Script Options

The `start-judge0.sh` script provides additional control:

```bash
# Basic start
./scripts/wsl/start-judge0.sh

# Pull latest images first
./scripts/wsl/start-judge0.sh --pull

# Fresh start (removes volumes/data)
./scripts/wsl/start-judge0.sh --fresh

# Start and follow logs
./scripts/wsl/start-judge0.sh --logs

# Just check status
./scripts/wsl/start-judge0.sh --check

# Combine options
./scripts/wsl/start-judge0.sh --pull --logs
```

---

## Running from PowerShell (Without Entering WSL)

```powershell
# Start Judge0
wsl -d judge0-wsl -- bash -c 'cd /mnt/c/myStuff/_tooling/Judge0 && docker-compose up -d'

# Stop Judge0
wsl -d judge0-wsl -- bash -c 'cd /mnt/c/myStuff/_tooling/Judge0 && docker-compose down'

# View status
wsl -d judge0-wsl -- bash -c 'cd /mnt/c/myStuff/_tooling/Judge0 && docker-compose ps'

# View logs
wsl -d judge0-wsl -- bash -c 'cd /mnt/c/myStuff/_tooling/Judge0 && docker-compose logs --tail=50'
```

---

## Instance Management

### List WSL Instances

```powershell
wsl --list --verbose
```

### Enter the Instance

```powershell
wsl -d judge0-wsl
```

### Stop the Instance

```powershell
wsl --terminate judge0-wsl
```

### Remove the Instance

```powershell
# This removes the instance completely
wsl --unregister judge0-wsl

# Also remove the installation directory
Remove-Item -Recurse C:\WSL\judge0-wsl
```

### Recreate the Instance

```powershell
# Remove and recreate with --Force
.\Create-Judge0-WSL.ps1 -Force
```

---

## Editing Judge0 Source

Your Judge0 source at `C:\myStuff\_tooling\Judge0` is mounted in WSL at:
```
/mnt/c/myStuff/_tooling/Judge0
```

**Edit from Windows**: Use VS Code, any Windows editor - changes are immediately visible in WSL.

**Edit from WSL**: Changes are immediately visible in Windows.

After editing, restart services:
```bash
j0-restart
```

---

## Configuration

### Change API Port

Edit `docker-compose.yml` on Windows:

```yaml
services:
  server:
    ports:
      - "8080:2358"  # Change from 2358 to 8080
```

Then restart:
```bash
j0-restart
```

### Scale Workers

```bash
cd /mnt/c/myStuff/_tooling/Judge0
docker-compose up -d --scale worker=3
```

---

## Troubleshooting

### "Internal Error" on Submissions / cgroups errors

**Symptoms**: Submissions return status 13 "Internal Error" with messages like:
- `No such file or directory @ rb_sysopen - /box/script.py`
- `Failed to create control group /sys/fs/cgroup/memory/box-N/`

**Cause**: WSL2/Docker Desktop uses cgroups v2, but Judge0's isolate sandbox requires cgroups v1.

**Fix**: The setup script automatically patches `judge0.conf`, but if you see this issue:

```bash
# Edit judge0.conf and set both to true:
ENABLE_PER_PROCESS_AND_THREAD_TIME_LIMIT=true
ENABLE_PER_PROCESS_AND_THREAD_MEMORY_LIMIT=true
```

Then restart:
```bash
j0-down && j0-up
```

This disables cgroups-based resource limiting, falling back to per-process limits which work on cgroups v2.

### Docker not found in WSL

**Cause**: Docker Desktop WSL Integration not enabled for this instance.

**Fix**:
1. Open Docker Desktop
2. Settings → Resources → WSL Integration
3. Enable for `judge0-wsl`
4. Apply & Restart

### Slow file access

**Cause**: Cross-filesystem access (Windows ↔ WSL) has overhead.

**Mitigation**: This is normal for mounted Windows paths. For best performance with large file operations, consider copying files to the WSL filesystem.

### Permission errors

```bash
# Inside WSL, if you see permission errors:
sudo chown -R judge0:judge0 /mnt/c/myStuff/_tooling/Judge0
```

### API not responding

```bash
# Check container status
j0-ps

# Check logs for errors
j0-logs

# Restart everything
j0-down && j0-up
```

### Instance won't start

```powershell
# Check WSL status
wsl --list --verbose

# Try restarting WSL entirely
wsl --shutdown
wsl -d judge0-wsl
```

---

## Test Submission

```bash
curl -X POST "http://localhost:2358/submissions?wait=true" \
  -H "Content-Type: application/json" \
  -d '{"source_code": "print(1+1)", "language_id": 71}'
```

Expected output includes:
```json
{
  "stdout": "2\n",
  "status": { "id": 3, "description": "Accepted" }
}
```

