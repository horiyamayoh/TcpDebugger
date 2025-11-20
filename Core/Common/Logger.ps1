# Core/Common/Logger.ps1
# Thread-safe JSON logger with buffering

class Logger {
    [string]$Name
    [string]$LogPath
    hidden [bool]$_enabled
    hidden [object]$_lock
    hidden [System.Collections.Generic.List[string]]$_buffer
    hidden [int]$_bufferSize
    hidden [datetime]$_lastFlush
    hidden [int]$_flushIntervalSeconds

    Logger(
        [string]$logPath,
        [string]$name = "TcpDebugger",
        [int]$bufferSize = 50,
        [int]$flushIntervalSeconds = 5,
        [bool]$enabled = $true
    ) {
        $this._enabled = $enabled
        $this.Name = $name
        $this.LogPath = $logPath
        
        if (-not $enabled) {
            # ログ無効時はダミー初期化
            $this._lock = [object]::new()
            $this._buffer = $null
            $this._bufferSize = 0
            $this._flushIntervalSeconds = 0
            $this._lastFlush = [datetime]::MinValue
            return
        }
        
        if ([string]::IsNullOrWhiteSpace($logPath)) {
            throw "Log path cannot be empty."
        }

        $directory = [System.IO.Path]::GetDirectoryName($logPath)
        if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
            [System.IO.Directory]::CreateDirectory($directory) | Out-Null
        }

        $this._lock = [object]::new()
        $this.LogPath = $logPath
        $this.Name = if ($name) { $name } else { "TcpDebugger" }
        $this._buffer = [System.Collections.Generic.List[string]]::new()
        $this._bufferSize = $bufferSize
        $this._flushIntervalSeconds = $flushIntervalSeconds
        $this._lastFlush = Get-Date
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
        if (-not $this._enabled) { return }
        
        if (-not $context) { $context = @{} }
        $context['ConnectionId'] = $connectionId
        $context['Length'] = if ($data) { $data.Length } else { 0 }
        
        # HEX変換を高速化（StringBuilder使用）
        if ($data -and $data.Length -gt 0) {
            $previewLength = [Math]::Min(32, $data.Length)
            $sb = [System.Text.StringBuilder]::new($previewLength * 3)
            
            for ($i = 0; $i -lt $previewLength; $i++) {
                if ($i -gt 0) {
                    [void]$sb.Append(' ')
                }
                [void]$sb.Append($data[$i].ToString("X2"))
            }
            
            $context['Preview'] = $sb.ToString()
        }
        
        $this.Log("RECEIVE", "Received data", $context)
    }

    hidden [void] Log(
        [string]$level,
        [string]$message,
        [hashtable]$context
    ) {
        if (-not $this._enabled) { return }
        
        if ([string]::IsNullOrWhiteSpace($level)) {
            $level = "INFO"
        }

        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = ""
        }

        $entry = [PSCustomObject]@{
            Timestamp = (Get-Date).ToString("o")
            Level = $level
            Message = $message
            Context = $context
            Logger = $this.Name
            ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }

        $json = $entry | ConvertTo-Json -Compress

        [System.Threading.Monitor]::Enter($this._lock)
        try {
            # バッファに追加
            $this._buffer.Add($json)
            
            # フラッシュ条件チェック
            $shouldFlush = $false
            
            # 条件1: バッファサイズ超過
            if ($this._buffer.Count -ge $this._bufferSize) {
                $shouldFlush = $true
            }
            
            # 条件2: 時間経過
            $elapsed = (Get-Date) - $this._lastFlush
            if ($elapsed.TotalSeconds -ge $this._flushIntervalSeconds) {
                $shouldFlush = $true
            }
            
            # 条件3: エラーレベルは即座にフラッシュ
            if ($level -eq "ERROR") {
                $shouldFlush = $true
            }
            
            if ($shouldFlush) {
                $this.FlushBuffer()
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }
    }
    
    hidden [void] FlushBuffer() {
        # ロック済み前提で呼び出される
        if (-not $this._enabled -or $this._buffer.Count -eq 0) {
            return
        }
        
        try {
            # バッファ内容を一括書き込み
            $content = $this._buffer -join "`n"
            Add-Content -Path $this.LogPath -Value $content -NoNewline
            Add-Content -Path $this.LogPath -Value "`n"
            
            $this._buffer.Clear()
            $this._lastFlush = Get-Date
        }
        catch {
            # フラッシュ失敗時はバッファをクリアして続行
            Write-Warning "Failed to flush log buffer: $_"
            $this._buffer.Clear()
        }
    }
    
    # 明示的フラッシュ（アプリ終了時など）
    [void] Flush() {
        [System.Threading.Monitor]::Enter($this._lock)
        try {
            $this.FlushBuffer()
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }
    }
}

function New-FileLogger {
    <#
    .SYNOPSIS
    ファイルロガーを作成
    
    .PARAMETER Path
    ログファイルのパス
    
    .PARAMETER Name
    ロガー名
    
    .PARAMETER BufferSize
    バッファサイズ（デフォルト: 50）
    
    .PARAMETER FlushIntervalSeconds
    フラッシュ間隔（秒）（デフォルト: 5）
    
    .PARAMETER Enabled
    ログ出力を有効にするか（デフォルト: $true）
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$Name = "TcpDebugger",
        
        [Parameter(Mandatory = $false)]
        [int]$BufferSize = 50,
        
        [Parameter(Mandatory = $false)]
        [int]$FlushIntervalSeconds = 5,
        
        [Parameter(Mandatory = $false)]
        [bool]$Enabled = $true
    )

    return [Logger]::new($Path, $Name, $BufferSize, $FlushIntervalSeconds, $Enabled)
}
