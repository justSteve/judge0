# Code Review: Logging and Error Handling

## Executive Summary

**Status:** ⚠️ **NEEDS IMPROVEMENT**

Both features have basic error handling but **lack adequate logging infrastructure** for production use. Issues found:

### Critical Issues (Must Fix)
1. ❌ **No persistent logging** - Everything goes to console only
2. ❌ **No structured logs** - Can't parse or analyze
3. ❌ **No retry logic** - Transient failures cause complete failure
4. ❌ **Silent failures** - Some errors swallowed without visibility

### Important Issues (Should Fix)
5. ⚠️ **No timestamps** - Can't correlate events
6. ⚠️ **No log rotation** - Will fill disk in production
7. ⚠️ **Insufficient context** - Error messages lack detail
8. ⚠️ **No cleanup on failure** - Partial updates left in bad state

---

## Feature 1: Infrastructure Scripts

### Current State

#### Logging Assessment

| Aspect | Status | Issue |
|--------|--------|-------|
| Log Files | ❌ None | Only console output, lost on session end |
| Timestamps | ❌ None | Can't determine when events occurred |
| Structured Logs | ❌ None | Can't parse or analyze logs |
| Log Levels | ⚠️ Basic | Custom functions, not standard |
| Log Rotation | ❌ None | N/A - no files |
| Session Tracking | ❌ None | Can't identify specific runs |
| Historical Review | ❌ Impossible | No persistent storage |

**Example Issue:**
```powershell
Write-Info "Checking for updates..."  # Where does this go when run from Task Scheduler?
```

#### Error Handling Assessment

| Aspect | Status | Issue |
|--------|--------|-------|
| Exception Catching | ✅ Good | Try/catch blocks present |
| Error Context | ⚠️ Limited | Lacks detailed context |
| Retry Logic | ❌ None | Single failure = script fails |
| Rollback | ❌ None | Failed update leaves system in unknown state |
| Error Suppression | ❌ Present | `2>&1 | Out-Null` hides git errors |
| Exit Codes | ✅ Good | Proper exit codes (0/1) |
| Cleanup | ❌ None | No cleanup on failure |

**Example Issues:**

```powershell
# Line 103: Error output suppressed
git fetch $Remote $Branch 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to fetch from remote"  # WHY did it fail? No context!
    exit 1
}

# Line 179: Warning but continues - should this be fatal?
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to stop services (may not be running)"
    # Continues anyway - what if containers are in bad state?
}

# Line 230: Silent exception
catch {
    Write-Warning "API not responding yet"
    # What exception? Network error? Timeout? Parse error?
}
```

### Critical Scenarios Not Handled

1. **Network interruption during git pull**
   - Partial update leaves repo in broken state
   - No rollback mechanism
   - No retry

2. **Docker pull fails midway**
   - Some images updated, some not
   - Inconsistent state
   - No recovery

3. **Service fails to start after update**
   - Updated code but service down
   - No automatic rollback
   - Manual intervention required

4. **Scheduled task runs while update in progress**
   - Race condition
   - No locking mechanism
   - Could corrupt state

---

## Feature 2: Python Client Library

### Current State

#### Logging Assessment

| Aspect | Status | Issue |
|--------|--------|-------|
| Python logging | ❌ None | No logging module used |
| Debug output | ❌ None | Can't troubleshoot issues |
| Request logging | ❌ None | Can't see what was sent |
| Response logging | ❌ None | Can't see what was received |
| Performance metrics | ❌ None | Can't measure timing |
| Error context | ⚠️ Limited | Exception messages basic |

**Example Issue:**
```python
# client.py - No logging anywhere
def submit_code(self, source_code, language_id=71, ...):
    # No log of what's being submitted
    # No log of API response
    # No performance tracking
    ...
```

#### Error Handling Assessment

| Aspect | Status | Issue |
|--------|--------|-------|
| Custom Exceptions | ✅ Good | Proper exception hierarchy |
| Exception Wrapping | ✅ Good | Wraps requests exceptions |
| Retry Logic | ❌ None | Single failure = exception |
| Exponential Backoff | ❌ None | N/A |
| Bare Except | ❌ Present | Line 230: catches everything |
| Error Context | ⚠️ Limited | Lacks request/response details |
| Validation | ⚠️ Weak | Minimal response validation |

**Example Issues:**

```python
# Line 78: No token validation - what if empty string?
token = response.json().get("token")
if not token:
    raise SubmissionError("No token in response")
# Should also check: is it a valid UUID? Non-empty? Right format?

# Line 148: No context on what went wrong
result = self.get_submission(token)
# If this fails, we don't know which poll attempt failed

# Line 158: Unhelpful timeout message
raise TimeoutError(f"Submission did not complete within {max_wait} seconds")
# Should include: token, last known status, number of polls attempted

# Line 230: SILENT FAILURE - Very bad!
except:
    return False
# What exception occurred? Network error? Parse error? Should be logged!

# Line 84-85: Loses original exception
except requests.RequestException as e:
    raise SubmissionError(f"Network error: {str(e)}")
# Should use "raise from" to preserve stack trace
```

### Critical Scenarios Not Handled

1. **API returns 500 error**
   - No retry
   - Immediate failure
   - User has to retry manually

2. **Submission stuck in queue indefinitely**
   - Polls until timeout
   - No way to cancel
   - Wastes resources

3. **Network connection drops mid-poll**
   - Exception raised
   - Lost context of what was happening
   - No automatic retry

4. **Malformed JSON response**
   - Exception raised
   - No details about what was wrong
   - Can't debug

---

## Recommended Improvements

### Priority 1: Add Logging (CRITICAL)

#### PowerShell Script

```powershell
# Add at start of script
$LogDir = Join-Path $Judge0Dir "logs"
$LogFile = Join-Path $LogDir "update-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$RunId = [guid]::NewGuid().ToString().Substring(0,8)

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

# Enhanced logging function
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')]
        [string]$Level = 'INFO',
        [switch]$Console
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$RunId] [$Level] $Message"

    # Always write to file
    Add-Content -Path $LogFile -Value $logMessage

    # Optionally write to console
    if ($Console -or $Level -eq 'ERROR') {
        $color = switch ($Level) {
            'INFO' { 'Cyan' }
            'WARN' { 'Yellow' }
            'ERROR' { 'Red' }
            'SUCCESS' { 'Green' }
        }
        Write-Host $logMessage -ForegroundColor $color
    }
}

# Example usage
Write-Log "Starting update check" -Level INFO -Console
Write-Log "Git fetch from $Remote/$Branch" -Level INFO
```

#### Python Client

```python
import logging
from typing import Optional

class Judge0Client:
    def __init__(self, config: Optional[Judge0Config] = None, logger: Optional[logging.Logger] = None):
        self.config = config or Judge0Config.from_env()
        self.logger = logger or logging.getLogger(__name__)

    def submit_code(self, source_code: str, language_id: int = 71, **kwargs) -> str:
        self.logger.info(
            "Submitting code",
            extra={
                "language_id": language_id,
                "code_length": len(source_code),
                "has_stdin": bool(kwargs.get("stdin")),
            }
        )

        try:
            response = requests.post(url, json=payload, headers=headers, timeout=self.config.timeout)

            self.logger.debug(
                "Submission response",
                extra={
                    "status_code": response.status_code,
                    "response_time_ms": response.elapsed.total_seconds() * 1000,
                }
            )

            if response.status_code == 201:
                token = response.json().get("token")
                self.logger.info(f"Submission successful", extra={"token": token})
                return token
            else:
                self.logger.error(
                    "Submission failed",
                    extra={
                        "status_code": response.status_code,
                        "response": response.text[:500],
                    }
                )
                raise SubmissionError(f"Submission failed: {response.status_code}")

        except requests.RequestException as e:
            self.logger.exception("Network error during submission")
            raise SubmissionError(f"Network error: {str(e)}") from e
```

### Priority 2: Add Retry Logic (CRITICAL)

#### PowerShell Script

```powershell
function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 5,
        [string]$Operation = "operation"
    )

    $attempt = 1
    while ($attempt -le $MaxAttempts) {
        try {
            Write-Log "Attempting $Operation (attempt $attempt/$MaxAttempts)" -Level INFO
            & $ScriptBlock
            Write-Log "$Operation succeeded" -Level SUCCESS
            return $true
        }
        catch {
            Write-Log "$Operation failed (attempt $attempt/$MaxAttempts): $_" -Level WARN

            if ($attempt -lt $MaxAttempts) {
                Write-Log "Retrying in $DelaySeconds seconds..." -Level INFO
                Start-Sleep -Seconds $DelaySeconds
                $attempt++
            }
            else {
                Write-Log "$Operation failed after $MaxAttempts attempts" -Level ERROR
                throw
            }
        }
    }
}

# Usage
Invoke-WithRetry -ScriptBlock {
    git fetch $Remote $Branch
    if ($LASTEXITCODE -ne 0) { throw "Git fetch failed" }
} -Operation "Git fetch" -MaxAttempts 3
```

#### Python Client

```python
import time
from functools import wraps

def retry_on_failure(max_attempts=3, delay=1.0, backoff=2.0, exceptions=(requests.RequestException,)):
    """Decorator for retrying failed operations"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            attempt = 1
            current_delay = delay

            while attempt <= max_attempts:
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    if attempt == max_attempts:
                        raise

                    logger.warning(
                        f"{func.__name__} failed (attempt {attempt}/{max_attempts}): {e}. "
                        f"Retrying in {current_delay:.1f}s..."
                    )

                    time.sleep(current_delay)
                    current_delay *= backoff
                    attempt += 1

        return wrapper
    return decorator

class Judge0Client:
    @retry_on_failure(max_attempts=3, delay=1.0)
    def submit_code(self, source_code: str, language_id: int = 71, **kwargs) -> str:
        # Implementation stays the same
        ...
```

### Priority 3: Improve Error Context (HIGH)

#### PowerShell Script

```powershell
function Update-Repository {
    try {
        $status = git status --porcelain
        if ($status) {
            $changedFiles = ($status | Measure-Object).Count
            Write-Log "Local changes detected: $changedFiles files modified" -Level ERROR -Console
            Write-Log "Files: $($status -join ', ')" -Level ERROR
            throw "Cannot update with local changes present"
        }

        $startTime = Get-Date
        git pull $Remote $Branch 2>&1 | Tee-Object -Variable gitOutput
        $duration = (Get-Date) - $startTime

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Git pull failed after $($duration.TotalSeconds)s" -Level ERROR
            Write-Log "Git output: $gitOutput" -Level ERROR
            throw "Git pull failed with exit code $LASTEXITCODE"
        }

        Write-Log "Git pull completed in $($duration.TotalSeconds)s" -Level SUCCESS -Console
    }
    catch {
        Write-Log "Update-Repository failed: $($_.Exception.Message)" -Level ERROR -Console
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level ERROR
        throw
    }
}
```

#### Python Client

```python
class SubmissionError(Judge0Error):
    """Raised when code submission fails"""
    def __init__(self, message: str, status_code: Optional[int] = None,
                 response_text: Optional[str] = None, token: Optional[str] = None):
        super().__init__(message)
        self.status_code = status_code
        self.response_text = response_text
        self.token = token

    def __str__(self):
        parts = [super().__str__()]
        if self.status_code:
            parts.append(f"Status: {self.status_code}")
        if self.token:
            parts.append(f"Token: {self.token}")
        if self.response_text:
            parts.append(f"Response: {self.response_text[:200]}")
        return " | ".join(parts)

def wait_for_completion(self, token: str, max_wait: Optional[int] = None,
                       poll_interval: float = 0.5) -> Dict[str, Any]:
    max_wait = max_wait or self.config.max_wait
    waited = 0.0
    polls = 0
    last_status = None

    while waited < max_wait:
        polls += 1
        result = self.get_submission(token)
        status_id = result.get("status", {}).get("id")
        status_desc = result.get("status", {}).get("description")
        last_status = status_desc

        self.logger.debug(
            f"Poll {polls}: status={status_desc} (id={status_id}), waited={waited:.1f}s"
        )

        if status_id not in [1, 2]:
            self.logger.info(f"Submission completed after {polls} polls ({waited:.1f}s)")
            return result

        time.sleep(poll_interval)
        waited += poll_interval

    raise TimeoutError(
        f"Submission {token} did not complete within {max_wait}s. "
        f"Last status: {last_status}. Polls: {polls}"
    )
```

### Priority 4: Add Health Checks & Validation (MEDIUM)

#### PowerShell Script

```powershell
function Test-ServiceHealth {
    param([int]$MaxRetries = 6, [int]$RetryDelay = 5)

    Write-Log "Checking service health (max wait: $($MaxRetries * $RetryDelay)s)" -Level INFO

    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            # Check containers
            $containers = docker-compose -f $ComposeFile ps --quiet
            $runningCount = ($containers | Measure-Object).Count

            Write-Log "Found $runningCount running containers" -Level INFO

            if ($runningCount -eq 0) {
                throw "No containers running"
            }

            # Check API
            $response = Invoke-WebRequest -Uri "http://localhost:2358/about" `
                -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop

            if ($response.StatusCode -eq 200) {
                $version = ($response.Content | ConvertFrom-Json).version
                Write-Log "API healthy - version $version" -Level SUCCESS -Console
                return $true
            }
        }
        catch {
            Write-Log "Health check attempt $attempt failed: $_" -Level WARN

            if ($attempt -lt $MaxRetries) {
                Write-Log "Retrying in ${RetryDelay}s..." -Level INFO
                Start-Sleep -Seconds $RetryDelay
                $attempt++
            }
            else {
                Write-Log "Health check failed after $MaxRetries attempts" -Level ERROR
                return $false
            }
        }
    }
}
```

#### Python Client

```python
def health_check(self, include_details: bool = False) -> Union[bool, Dict[str, Any]]:
    """
    Check if Judge0 API is accessible.

    Args:
        include_details: If True, return detailed health info

    Returns:
        If include_details=False: True/False
        If include_details=True: Dict with health details
    """
    details = {
        "healthy": False,
        "api_url": self.config.api_url,
        "error": None,
        "version": None,
        "response_time_ms": None,
    }

    try:
        url = f"{self.config.api_url}/about"
        headers = self.config.get_headers()

        start_time = time.time()
        response = requests.get(url, headers=headers, timeout=5)
        response_time = (time.time() - start_time) * 1000

        details["response_time_ms"] = round(response_time, 2)

        if response.status_code == 200:
            data = response.json()
            details["healthy"] = True
            details["version"] = data.get("version")

            self.logger.info(
                f"Health check passed ({response_time:.0f}ms, version={data.get('version')})"
            )
        else:
            details["error"] = f"Status {response.status_code}"
            self.logger.warning(f"Health check failed: status {response.status_code}")

    except Exception as e:
        details["error"] = str(e)
        self.logger.warning(f"Health check failed: {e}")

    return details if include_details else details["healthy"]
```

---

## Proposed Changes

### Files to Create/Modify

1. **scripts/Check-And-Update-v2.ps1** - Enhanced with logging
2. **scripts/LoggingModule.psm1** - Reusable logging module
3. **.dspy/lib/judge0_client/logging_config.py** - Logging configuration
4. **.dspy/lib/judge0_client/retry.py** - Retry decorators
5. **.dspy/lib/judge0_client/client.py** - Updated with logging & retries
6. **LOGGING-GUIDE.md** - How to configure and use logging

### Configuration Files Needed

1. **logs/judge0-update.log** - Main log file
2. **logs/judge0-client.log** - Client library log
3. **.env** - Add logging configuration

---

## Testing Plan

### Test Scenarios

1. **Network interruption during update**
   - Disconnect network mid-pull
   - Verify retry logic works
   - Verify logs capture failure

2. **API unavailable**
   - Stop Judge0
   - Submit code
   - Verify retries and eventual failure
   - Verify error context in logs

3. **Log rotation**
   - Run script 50 times
   - Verify old logs don't accumulate forever
   - Verify rotation works correctly

4. **Concurrent execution**
   - Run update script twice simultaneously
   - Verify locking prevents conflicts
   - Verify logs from both runs

---

## Next Steps

1. ✅ Review complete - Issues identified
2. ⏳ Create enhanced versions with logging
3. ⏳ Add retry logic to both features
4. ⏳ Write logging configuration guide
5. ⏳ Test all failure scenarios
6. ⏳ Update documentation
7. ⏳ Deploy and monitor

---

## Conclusion

**Current State:** Basic functionality works, but **not production-ready** due to logging/error handling gaps.

**Recommendation:** Implement Priority 1 & 2 improvements **before production deployment**.

**Estimated Effort:**
- Logging infrastructure: 4-6 hours
- Retry logic: 2-3 hours
- Testing: 3-4 hours
- Documentation: 1-2 hours
- **Total: 10-15 hours**

**Risk if deployed as-is:**
- ❌ Can't troubleshoot production issues
- ❌ Silent failures in scheduled tasks
- ❌ Transient errors cause unnecessary failures
- ❌ No audit trail for compliance

**Benefits after improvements:**
- ✅ Full visibility into all operations
- ✅ Automatic recovery from transient failures
- ✅ Detailed error context for debugging
- ✅ Historical logs for analysis
- ✅ Production-grade reliability
