<#
.SYNOPSIS
    Logging module for Judge0 PowerShell scripts

.DESCRIPTION
    Provides structured logging with file output, rotation, and console display
#>

# Module variables
$script:LogDir = $null
$script:LogFile = $null
$script:RunId = $null
$script:SessionStart = $null

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initialize logging system

    .PARAMETER BaseDir
        Base directory for logs (default: .\logs)

    .PARAMETER LogName
        Name for log file (default: script name)

    .PARAMETER MaxLogFiles
        Maximum number of log files to keep (default: 30)
    #>
    param(
        [string]$BaseDir = "logs",
        [string]$LogName = $null,
        [int]$MaxLogFiles = 30
    )

    # Set module variables
    $script:SessionStart = Get-Date
    $script:RunId = [guid]::NewGuid().ToString().Substring(0, 8)

    # Determine log directory
    if (-not [System.IO.Path]::IsPathRooted($BaseDir)) {
        $script:LogDir = Join-Path $PWD $BaseDir
    } else {
        $script:LogDir = $BaseDir
    }

    # Create log directory if needed
    if (-not (Test-Path $script:LogDir)) {
        New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    }

    # Determine log file name
    if (-not $LogName) {
        $caller = (Get-PSCallStack)[1].ScriptName
        $LogName = [System.IO.Path]::GetFileNameWithoutExtension($caller)
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:LogFile = Join-Path $script:LogDir "${LogName}-${timestamp}.log"

    # Write header
    $header = @"
================================================
Log Session Started
================================================
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
RunId: $script:RunId
User: $env:USERNAME
Computer: $env:COMPUTERNAME
Script: $((Get-PSCallStack)[1].ScriptName)
PowerShell: $($PSVersionTable.PSVersion)
================================================
"@

    Add-Content -Path $script:LogFile -Value $header

    # Clean old logs
    Remove-OldLogs -MaxFiles $MaxLogFiles

    Write-Log "Logging initialized: $script:LogFile" -Level INFO -Console
}

function Write-Log {
    <#
    .SYNOPSIS
        Write a log message

    .PARAMETER Message
        The message to log

    .PARAMETER Level
        Log level (INFO, WARN, ERROR, SUCCESS, DEBUG)

    .PARAMETER Console
        Also write to console

    .PARAMETER Data
        Additional structured data to log
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO',

        [switch]$Console,

        [hashtable]$Data = @{}
    )

    # Ensure logging is initialized
    if (-not $script:LogFile) {
        Initialize-Logging
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $logMessage = "[$timestamp] [$script:RunId] [$Level] $Message"

    # Add structured data if provided
    if ($Data.Count -gt 0) {
        $dataStr = ($Data.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "
        $logMessage += " | $dataStr"
    }

    # Write to file
    try {
        Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction Stop
    }
    catch {
        # If logging fails, at least write to console
        Write-Host "[LOGGING ERROR] Failed to write to log file: $_" -ForegroundColor Red
    }

    # Write to console if requested or if ERROR
    if ($Console -or $Level -eq 'ERROR') {
        $color = switch ($Level) {
            'INFO' { 'Cyan' }
            'WARN' { 'Yellow' }
            'ERROR' { 'Red' }
            'SUCCESS' { 'Green' }
            'DEBUG' { 'Gray' }
        }

        Write-Host $logMessage -ForegroundColor $color
    }
}

function Write-LogException {
    <#
    .SYNOPSIS
        Log an exception with full details

    .PARAMETER Exception
        The exception object

    .PARAMETER Message
        Additional context message
    #>
    param(
        [Parameter(Mandatory)]
        $Exception,

        [string]$Message = "Exception occurred"
    )

    Write-Log "$Message`: $($Exception.Exception.Message)" -Level ERROR -Console

    # Log stack trace
    if ($Exception.ScriptStackTrace) {
        Write-Log "Stack trace: $($Exception.ScriptStackTrace)" -Level DEBUG
    }

    # Log inner exception
    if ($Exception.Exception.InnerException) {
        Write-Log "Inner exception: $($Exception.Exception.InnerException.Message)" -Level DEBUG
    }
}

function Start-LogOperation {
    <#
    .SYNOPSIS
        Start a timed operation

    .PARAMETER Name
        Operation name

    .OUTPUTS
        Returns operation start time
    #>
    param([string]$Name)

    Write-Log "Starting: $Name" -Level INFO
    return Get-Date
}

function Complete-LogOperation {
    <#
    .SYNOPSIS
        Complete a timed operation

    .PARAMETER Name
        Operation name

    .PARAMETER StartTime
        Operation start time from Start-LogOperation

    .PARAMETER Success
        Whether operation succeeded
    #>
    param(
        [string]$Name,
        [datetime]$StartTime,
        [bool]$Success = $true
    )

    $duration = (Get-Date) - $StartTime
    $level = if ($Success) { 'SUCCESS' } else { 'ERROR' }

    Write-Log "Completed: $Name" -Level $level -Data @{
        duration_ms = [int]$duration.TotalMilliseconds
        duration_sec = [math]::Round($duration.TotalSeconds, 2)
    }
}

function Remove-OldLogs {
    <#
    .SYNOPSIS
        Remove old log files

    .PARAMETER MaxFiles
        Maximum number of log files to keep
    #>
    param([int]$MaxFiles = 30)

    if (-not (Test-Path $script:LogDir)) {
        return
    }

    # Get all log files sorted by creation time
    $logFiles = Get-ChildItem -Path $script:LogDir -Filter "*.log" |
                Sort-Object CreationTime -Descending

    if ($logFiles.Count -le $MaxFiles) {
        return
    }

    # Remove excess files
    $toRemove = $logFiles | Select-Object -Skip $MaxFiles

    foreach ($file in $toRemove) {
        try {
            Remove-Item $file.FullName -Force
            Write-Log "Removed old log: $($file.Name)" -Level DEBUG
        }
        catch {
            Write-Log "Failed to remove old log $($file.Name): $_" -Level WARN
        }
    }

    Write-Log "Log cleanup: kept $MaxFiles files, removed $($toRemove.Count) files" -Level INFO
}

function Get-LogSummary {
    <#
    .SYNOPSIS
        Get summary of current logging session
    #>

    if (-not $script:SessionStart) {
        return $null
    }

    $duration = (Get-Date) - $script:SessionStart

    return @{
        RunId = $script:RunId
        SessionStart = $script:SessionStart
        Duration = $duration
        DurationSeconds = [math]::Round($duration.TotalSeconds, 2)
        LogFile = $script:LogFile
        LogSize = if (Test-Path $script:LogFile) {
            [math]::Round((Get-Item $script:LogFile).Length / 1KB, 2)
        } else { 0 }
    }
}

function Close-Logging {
    <#
    .SYNOPSIS
        Close logging session and write footer
    #>

    if (-not $script:LogFile) {
        return
    }

    $summary = Get-LogSummary
    $duration = $summary.DurationSeconds

    $footer = @"

================================================
Log Session Ended
================================================
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Duration: ${duration}s
Log Size: $($summary.LogSize) KB
RunId: $script:RunId
================================================
"@

    Add-Content -Path $script:LogFile -Value $footer

    Write-Log "Logging session closed" -Level INFO -Console
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-Logging',
    'Write-Log',
    'Write-LogException',
    'Start-LogOperation',
    'Complete-LogOperation',
    'Remove-OldLogs',
    'Get-LogSummary',
    'Close-Logging'
)
