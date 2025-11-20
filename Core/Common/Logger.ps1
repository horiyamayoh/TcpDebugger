# Core/Common/Logger.ps1
# Thread-safe JSON logger used across layers

class Logger {
    [string]$Name
    [string]$LogPath
    hidden [object]$_lock
    hidden [System.IO.StreamWriter]$_writer
    hidden static [System.Web.Script.Serialization.JavaScriptSerializer]$Serializer

    Logger(
        [string]$logPath,
        [string]$name = "TcpDebugger"
    ) {
        if ([string]::IsNullOrWhiteSpace($logPath)) {
            throw "Log path cannot be empty."
        }

        $directory = [System.IO.Path]::GetDirectoryName($logPath)
        if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
            [System.IO.Directory]::CreateDirectory($directory) | Out-Null
        }

        if (-not [Logger]::Serializer) {
            [Logger]::Serializer = [System.Web.Script.Serialization.JavaScriptSerializer]::new()
        }

        $this._lock = [object]::new()
        $this.LogPath = $logPath
        $this.Name = if ($name) { $name } else { "TcpDebugger" }
        $this._writer = [System.IO.StreamWriter]::new($logPath, $true, [System.Text.Encoding]::UTF8)
        $this._writer.AutoFlush = $true
    }

    [void] LogInfo([string]$message, [hashtable]$context = @{}) {
        $this.Log("INFO", $message, $context)
    }

    [void] LogWarning([string]$message, [hashtable]$context = @{}) {
        $this.Log("WARN", $message, $context)
    }

    [void] LogDebug([string]$message, [hashtable]$context = @{}) {
        $this.Log("DEBUG", $message, $context)
    }

    [void] LogError(
        [string]$message,
        [Exception]$exception,
        [hashtable]$context = @{}
    ) {
        if (-not $context) { $context = @{} }
        if ($exception) {
            $context['Exception'] = $exception.GetType().FullName
            $context['ExceptionMessage'] = $exception.Message
            $context['StackTrace'] = $exception.StackTrace
        }
        $this.Log("ERROR", $message, $context)
    }

    [void] LogReceive(
        [string]$connectionId,
        [byte[]]$data,
        [hashtable]$context = @{}
    ) {
        if (-not $context) { $context = @{} }
        $context['ConnectionId'] = $connectionId
        $context['Length'] = if ($data) { $data.Length } else { 0 }
        if ($data) {
            $previewLength = [Math]::Min(32, $data.Length)
            $context['Preview'] = ($data[0..($previewLength - 1)] | ForEach-Object { $_.ToString("X2") }) -join " "
        }
        $this.Log("RECEIVE", "Received data", $context)
    }

    hidden [void] Log(
        [string]$level,
        [string]$message,
        [hashtable]$context
    ) {
        if ([string]::IsNullOrWhiteSpace($level)) {
            $level = "INFO"
        }

        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = ""
        }

        $entry = @{
            Timestamp = (Get-Date).ToString("o")
            Level     = $level
            Message   = $message
            Context   = $context
            Logger    = $this.Name
            ThreadId  = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }

        $json = $this.SerializeEntry($entry)

        [System.Threading.Monitor]::Enter($this._lock)
        try {
            if (-not $this._writer) {
                $this._writer = [System.IO.StreamWriter]::new($this.LogPath, $true, [System.Text.Encoding]::UTF8)
                $this._writer.AutoFlush = $true
            }

            $this._writer.WriteLine($json)
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }
    }

    hidden [string] SerializeEntry([hashtable]$entry) {
        return [Logger]::Serializer.Serialize($entry)
    }
}

function New-FileLogger {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$Name = "TcpDebugger"
    )

    return [Logger]::new($Path, $Name)
}
