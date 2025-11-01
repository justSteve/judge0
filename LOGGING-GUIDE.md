# Judge0 Logging Guide

## Overview

This guide covers logging configuration and best practices for both the infrastructure scripts and Python client library.

---

## PowerShell Scripts Logging

### Quick Start

```powershell
# Import logging module
Import-Module .\scripts\LoggingModule.psm1

# Initialize logging
Initialize-Logging -BaseDir "logs" -LogName "judge0-update"

# Write logs
Write-Log "Starting update process" -Level INFO -Console
Write-Log "Update completed successfully" -Level SUCCESS -Console

# Close logging session
Close-Logging
```

### Configuration

#### Log Directory

```powershell
# Default: .\logs relative to script
Initialize-Logging

# Custom directory
Initialize-Logging -BaseDir "C:\Logs\Judge0"

# Relative to working directory
Initialize-Logging -BaseDir ".\mylogs"
```

#### Log Rotation

```powershell
# Keep last 30 log files (default)
Initialize-Logging

# Keep more/fewer files
Initialize-Logging -MaxLogFiles 90  # Keep 3 months
Initialize-Logging -MaxLogFiles 7   # Keep 1 week
```

#### Log Levels

```powershell
Write-Log "Informational message" -Level INFO
Write-Log "Warning message" -Level WARN
Write-Log "Error message" -Level ERROR
Write-Log "Success message" -Level SUCCESS
Write-Log "Debug details" -Level DEBUG
```

### Advanced Usage

#### Structured Logging

```powershell
Write-Log "Git fetch completed" -Level INFO -Data @{
    remote = "origin"
    branch = "master"
    duration_ms = 1234
    commits_fetched = 3
}
```

Output:
```
[2025-11-01 12:34:56.789] [a1b2c3d4] [INFO] Git fetch completed | remote=origin, branch=master, duration_ms=1234, commits_fetched=3
```

#### Exception Logging

```powershell
try {
    # Some operation
    throw "Something went wrong"
}
catch {
    Write-LogException -Exception $_ -Message "Operation failed"
}
```

#### Timed Operations

```powershell
$startTime = Start-LogOperation -Name "Docker pull"

try {
    docker-compose pull
    Complete-LogOperation -Name "Docker pull" -StartTime $startTime -Success $true
}
catch {
    Complete-LogOperation -Name "Docker pull" -StartTime $startTime -Success $false
    throw
}
```

### Log File Format

```
================================================
Log Session Started
================================================
Time: 2025-11-01 12:34:56
RunId: a1b2c3d4
User: azureuser
Computer: uJudge0
Script: C:\judge0\scripts\Check-And-Update.ps1
PowerShell: 7.4.0
================================================

[2025-11-01 12:34:56.123] [a1b2c3d4] [INFO] Logging initialized: C:\judge0\logs\judge0-update-20251101-123456.log
[2025-11-01 12:34:56.456] [a1b2c3d4] [INFO] Checking requirements...
[2025-11-01 12:34:56.789] [a1b2c3d4] [SUCCESS] All requirements met
...

================================================
Log Session Ended
================================================
Time: 2025-11-01 12:35:45
Duration: 49.2s
Log Size: 12.5 KB
RunId: a1b2c3d4
================================================
```

### Integration with Scheduled Tasks

```powershell
# In your script
Import-Module .\scripts\LoggingModule.psm1
Initialize-Logging -LogName "scheduled-update"

try {
    Write-Log "Scheduled task started" -Level INFO -Console

    # Your logic here

    Write-Log "Scheduled task completed" -Level SUCCESS -Console
}
catch {
    Write-LogException -Exception $_ -Message "Scheduled task failed"
    exit 1
}
finally {
    Close-Logging
}
```

---

## Python Client Logging

### Quick Start

```python
import logging
from judge0_client import Judge0Client, Judge0Config

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[
        logging.FileHandler('judge0-client.log'),
        logging.StreamHandler()
    ]
)

# Use client (automatically logs)
client = Judge0Client()
result = client.execute('print("Hello")')
```

### Configuration Levels

#### Development (Verbose)

```python
import logging

logging.basicConfig(
    level=logging.DEBUG,  # Show everything
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[logging.StreamHandler()]
)
```

#### Production (Important Only)

```python
import logging

logging.basicConfig(
    level=logging.INFO,  # Hide DEBUG messages
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler('/var/log/judge0-client.log'),
        logging.StreamHandler()  # Also to console
    ]
)
```

#### Minimal (Errors Only)

```python
import logging

logging.basicConfig(
    level=logging.ERROR,  # Only errors
    handlers=[logging.FileHandler('/var/log/judge0-errors.log')]
)
```

### Structured Logging (JSON)

```python
import logging
import json

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_obj = {
            'timestamp': self.formatTime(record),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
        }

        if hasattr(record, 'extra'):
            log_obj.update(record.extra)

        return json.dumps(log_obj)

handler = logging.FileHandler('judge0-client.json')
handler.setFormatter(JSONFormatter())

logger = logging.getLogger('judge0_client')
logger.addHandler(handler)
logger.setLevel(logging.DEBUG)
```

### Advanced Configuration

#### Separate Log Files by Level

```python
import logging

# Create logger
logger = logging.getLogger('judge0_client')
logger.setLevel(logging.DEBUG)

# Handler for all logs
all_handler = logging.FileHandler('judge0-all.log')
all_handler.setLevel(logging.DEBUG)

# Handler for errors only
error_handler = logging.FileHandler('judge0-errors.log')
error_handler.setLevel(logging.ERROR)

# Add formatters
formatter = logging.Formatter(
    '%(asctime)s [%(levelname)s] %(name)s: %(message)s'
)
all_handler.setFormatter(formatter)
error_handler.setFormatter(formatter)

# Add handlers
logger.addHandler(all_handler)
logger.addHandler(error_handler)
```

#### Rotating File Handler

```python
import logging
from logging.handlers import RotatingFileHandler

handler = RotatingFileHandler(
    'judge0-client.log',
    maxBytes=10*1024*1024,  # 10 MB
    backupCount=5            # Keep 5 old files
)

handler.setFormatter(
    logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
)

logger = logging.getLogger('judge0_client')
logger.addHandler(handler)
logger.setLevel(logging.INFO)
```

#### Time-Based Rotation

```python
import logging
from logging.handlers import TimedRotatingFileHandler

handler = TimedRotatingFileHandler(
    'judge0-client.log',
    when='midnight',     # Rotate at midnight
    interval=1,          # Every day
    backupCount=30       # Keep 30 days
)

handler.setFormatter(
    logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
)

logger = logging.getLogger('judge0_client')
logger.addHandler(handler)
logger.setLevel(logging.INFO)
```

### Using Enhanced Client (v2)

The enhanced client (`client_v2.py`) includes automatic logging:

```python
from judge0_client.client_v2 import Judge0Client
import logging

# Configure logging once
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[
        logging.FileHandler('judge0.log'),
        logging.StreamHandler()
    ]
)

# Client automatically logs all operations
client = Judge0Client()

# Detailed logs for:
# - Submissions
# - Polling
# - Retries
# - Errors
# - Performance metrics

result = client.execute('print("test")')
```

### Log Output Examples

#### Successful Execution

```
2025-11-01 12:34:56,123 [INFO] judge0_client.client_v2: Initialized Judge0Client | api_url=http://localhost:2358, timeout=30, max_wait=60
2025-11-01 12:34:56,234 [INFO] judge0_client.client_v2: Submitting code | language_id=71, code_length=17, has_stdin=False, has_expected_output=False
2025-11-01 12:34:56,456 [DEBUG] judge0_client.client_v2: Submission response received | status_code=201, response_time_ms=221.5
2025-11-01 12:34:56,457 [INFO] judge0_client.client_v2: Submission successful | token=abc123-def456, response_time_ms=221.5
2025-11-01 12:34:56,458 [INFO] judge0_client.client_v2: Waiting for submission completion | token=abc123-def456, max_wait=60, poll_interval=0.5
2025-11-01 12:34:56,678 [DEBUG] judge0_client.client_v2: Poll 1: status=Processing (id=2), waited=0.0s
2025-11-01 12:34:57,189 [DEBUG] judge0_client.client_v2: Poll 2: status=Accepted (id=3), waited=0.5s
2025-11-01 12:34:57,190 [INFO] judge0_client.client_v2: Submission completed | token=abc123-def456, final_status=Accepted, polls=2, total_time_sec=0.73
2025-11-01 12:34:57,191 [INFO] judge0_client.client_v2: Execute operation completed | total_time_sec=0.96, token=abc123-def456
```

#### Failed Execution with Retry

```
2025-11-01 12:35:10,123 [INFO] judge0_client.client_v2: Submitting code | language_id=71, code_length=25, has_stdin=False, has_expected_output=False
2025-11-01 12:35:10,234 [ERROR] judge0_client.client_v2: Connection error during submission: Connection refused
2025-11-01 12:35:10,235 [WARNING] judge0_client.client_v2: submit_code: Failed (attempt 1/3): Network error: Connection refused. Retrying in 1.0s...
2025-11-01 12:35:11,456 [DEBUG] judge0_client.client_v2: submit_code: Attempt 2/3
2025-11-01 12:35:11,567 [DEBUG] judge0_client.client_v2: Submission response received | status_code=201, response_time_ms=110.2
2025-11-01 12:35:11,568 [INFO] judge0_client.client_v2: submit_code: Succeeded on attempt 2
2025-11-01 12:35:11,569 [INFO] judge0_client.client_v2: Submission successful | token=xyz789, response_time_ms=110.2
```

---

## Best Practices

### 1. Always Initialize Logging Early

```powershell
# PowerShell - First thing in script
Import-Module .\scripts\LoggingModule.psm1
Initialize-Logging
```

```python
# Python - At module level
import logging
logging.basicConfig(level=logging.INFO)
```

### 2. Use Appropriate Log Levels

| Level | Use For |
|-------|---------|
| DEBUG | Detailed diagnostic info (polling, retries) |
| INFO | General informational messages (operations starting/completing) |
| WARN | Recoverable problems (retry warnings) |
| ERROR | Errors that prevent operation (submission failures) |
| SUCCESS | Successful completion (PowerShell only) |

### 3. Include Context in Error Messages

```python
# Bad
logger.error("Submission failed")

# Good
logger.error(
    "Submission failed",
    extra={
        "status_code": 500,
        "token": "abc123",
        "language_id": 71,
    }
)
```

### 4. Log Performance Metrics

```python
start_time = time.time()
# ... operation ...
duration = time.time() - start_time

logger.info(
    "Operation completed",
    extra={"duration_sec": round(duration, 2)}
)
```

### 5. Don't Log Sensitive Data

```python
# Bad - logs API key
logger.debug(f"Headers: {headers}")

# Good - mask sensitive data
safe_headers = {k: v if k != 'X-RapidAPI-Key' else '***' for k, v in headers.items()}
logger.debug(f"Headers: {safe_headers}")
```

### 6. Close Logging Sessions Properly

```powershell
# PowerShell
try {
    # ... work ...
}
finally {
    Close-Logging
}
```

### 7. Monitor Log File Size

```python
# Use rotating handlers in production
from logging.handlers import RotatingFileHandler

handler = RotatingFileHandler(
    'app.log',
    maxBytes=10*1024*1024,  # 10MB
    backupCount=5
)
```

---

## Troubleshooting

### Logs Not Appearing

```powershell
# PowerShell - Check log file path
$logSummary = Get-LogSummary
$logSummary.LogFile
```

```python
# Python - Check logging configuration
import logging
print(logging.getLogger().handlers)
print(logging.getLogger().level)
```

### Too Much Debug Output

```python
# Reduce logging level
logging.getLogger('judge0_client').setLevel(logging.INFO)
```

### Logs Not Rotating

```python
# Verify rotation handler is added
import logging
logger = logging.getLogger('judge0_client')
print([type(h).__name__ for h in logger.handlers])
# Should show: ['RotatingFileHandler', ...]
```

---

## Examples

### Complete PowerShell Script

```powershell
Import-Module .\scripts\LoggingModule.psm1

try {
    Initialize-Logging -LogName "update" -MaxLogFiles 30

    Write-Log "Starting update process" -Level INFO -Console

    $startTime = Start-LogOperation -Name "Git fetch"
    git fetch origin master
    Complete-LogOperation -Name "Git fetch" -StartTime $startTime -Success ($LASTEXITCODE -eq 0)

    Write-Log "Update completed" -Level SUCCESS -Console
}
catch {
    Write-LogException -Exception $_ -Message "Update failed"
    exit 1
}
finally {
    Close-Logging
}
```

### Complete Python Application

```python
import logging
from logging.handlers import RotatingFileHandler
from judge0_client.client_v2 import Judge0Client

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# File handler with rotation
file_handler = RotatingFileHandler(
    'judge0-app.log',
    maxBytes=10*1024*1024,
    backupCount=5
)
file_handler.setFormatter(
    logging.Formatter('%(asctime)s [%(levelname)s] %(name)s: %(message)s')
)
logger.addHandler(file_handler)

# Console handler
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
console_handler.setFormatter(
    logging.Formatter('%(levelname)s: %(message)s')
)
logger.addHandler(console_handler)

# Use client
try:
    client = Judge0Client()

    result = client.execute('print("Hello, World!")')

    logging.info(f"Result: {result['stdout']}")

except Exception as e:
    logging.exception("Application failed")
    raise
```

---

## References

- [Python logging documentation](https://docs.python.org/3/library/logging.html)
- [PowerShell about_Logging](https://learn.microsoft.com/en-us/powershell/)
- [Judge0 API documentation](https://ce.judge0.com)

---

**Last Updated:** 2025-11-01
