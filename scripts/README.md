# Judge0 Management Scripts

Scripts for managing your Judge0 instance.

## Deployment Options

| Platform | Guide | Scripts |
|----------|-------|---------|
| **WSL2 (Windows)** | [README-WSL.md](wsl/README-WSL.md) | `wsl/setup-wsl.sh`, `wsl/Bootstrap-Judge0-WSL.ps1` |
| **Azure VM (Linux)** | See below | `check-and-update.sh`, `restart.sh`, `status.sh` |
| **Azure VM (Windows)** | [README-PowerShell.md](README-PowerShell.md) | PowerShell scripts |

## Scripts Overview

### 1. `check-and-update.sh` - Main Update Script
Checks GitHub for updates and automatically updates & restarts Judge0 if changes are found.

**Usage:**
```bash
# Check for updates and apply if found
./check-and-update.sh

# Force update even if no changes detected
./check-and-update.sh --force

# Check what updates are available without applying
./check-and-update.sh --dry-run
```

**Features:**
- Fetches latest changes from GitHub remote
- Compares local vs remote commits
- Shows changelog of what changed
- Checks for local modifications (prevents accidental overwrites)
- Pulls updates
- Restarts Docker containers
- Validates service health

**Environment Variables:**
```bash
JUDGE0_DIR=/path/to/judge0      # Default: script parent directory
BRANCH=master                    # Default: master
REMOTE=origin                    # Default: origin
COMPOSE_FILE=docker-compose.yml  # Default: docker-compose.yml
```

### 2. `restart.sh` - Simple Restart
Quickly restart Judge0 services without checking for updates.

**Usage:**
```bash
# Restart production instance
./restart.sh

# Restart development instance
./restart.sh dev
```

### 3. `status.sh` - Status Check
Check the current status of Judge0 services.

**Usage:**
```bash
./status.sh
```

**Shows:**
- Git repository status (branch, commit)
- Docker container status
- API health check
- Version information

## Setup on Azure VM

### First Time Setup

1. **SSH into your Azure VM:**
   ```bash
   ssh your-username@your-vm-ip
   ```

2. **Navigate to Judge0 directory:**
   ```bash
   cd /path/to/judge0
   ```

3. **Make scripts executable:**
   ```bash
   chmod +x scripts/*.sh
   ```

4. **Test the status script:**
   ```bash
   ./scripts/status.sh
   ```

### Automated Updates with Cron

To automatically check for updates every hour:

1. **Open crontab:**
   ```bash
   crontab -e
   ```

2. **Add this line:**
   ```bash
   # Check for Judge0 updates every hour
   0 * * * * /path/to/judge0/scripts/check-and-update.sh >> /var/log/judge0-update.log 2>&1
   ```

3. **For daily updates at 2 AM:**
   ```bash
   # Check for Judge0 updates daily at 2 AM
   0 2 * * * /path/to/judge0/scripts/check-and-update.sh >> /var/log/judge0-update.log 2>&1
   ```

4. **View update logs:**
   ```bash
   tail -f /var/log/judge0-update.log
   ```

## Common Workflows

### Manual Update Check
```bash
# Check if updates are available
./scripts/check-and-update.sh --dry-run

# Apply updates if available
./scripts/check-and-update.sh
```

### Quick Restart
```bash
# Just restart services
./scripts/restart.sh
```

### Health Check
```bash
# Check everything is running
./scripts/status.sh
```

### Force Update and Restart
```bash
# Force pull latest and restart (even if no changes)
./scripts/check-and-update.sh --force
```

## Troubleshooting

### Script says "local changes detected"
You have uncommitted changes in your Judge0 directory. Either commit them or stash:
```bash
git status
git stash  # Temporarily save changes
# or
git add . && git commit -m "Local changes"
```

### Services won't start
Check Docker logs:
```bash
cd /path/to/judge0
docker-compose logs
```

### API not responding
Wait a few seconds after restart, then check:
```bash
curl http://localhost:2358/about
```

### Permission denied
Make sure scripts are executable:
```bash
chmod +x scripts/*.sh
```

## Configuration

### Using Different Remote/Branch
```bash
# Check updates from different remote
REMOTE=upstream ./scripts/check-and-update.sh

# Check different branch
BRANCH=extra ./scripts/check-and-update.sh
```

### Using Development Compose File
```bash
COMPOSE_FILE=docker-compose.dev.yml ./scripts/check-and-update.sh
```

## Integration with Judge0 DSPy Lessons

After updating Judge0, you can test it with the DSPy lessons:

1. **Update the API endpoint in the lesson:**
   Edit `01_hello_dspy_j0.py` and set:
   ```python
   JUDGE0_API = "http://your-azure-vm-ip:2358"
   ```

2. **Remove authentication (for local instance):**
   The scripts already have commented sections for local instance - just uncomment them.

3. **Test the connection:**
   ```bash
   python 01_hello_dspy_j0.py
   ```

## Notes

- All scripts use `set -e` to exit on errors
- Color-coded output for easy reading
- Safe defaults (won't overwrite local changes)
- Validates prerequisites before running
- Logs all actions for troubleshooting

## License

These scripts are part of the Judge0 project. See main LICENSE file.
