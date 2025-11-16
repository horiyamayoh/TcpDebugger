# Core/Infrastructure/Repositories/RuleRepository.ps1

class RuleRepository {
    hidden [hashtable]$_cache
    hidden [object]$_lock
    hidden [Logger]$_logger

    RuleRepository([Logger]$logger) {
        if (-not $logger) {
            throw "Logger instance is required for RuleRepository."
        }
        $this._logger = $logger
        $this._cache = @{}
        $this._lock = [object]::new()
    }

    [object[]] GetRules([string]$filePath) {
        if ([string]::IsNullOrWhiteSpace($filePath)) {
            return @()
        }

        if (-not (Test-Path -LiteralPath $filePath)) {
            $this._logger.LogWarning("Rule file not found", @{ Path = $filePath })
            return @()
        }

        $resolved = (Resolve-Path -LiteralPath $filePath).Path
        $fileInfo = Get-Item -LiteralPath $resolved
        $lastWrite = $fileInfo.LastWriteTimeUtc
        $key = $resolved.ToLowerInvariant()

        $cached = $this.TryGetCached($key, $lastWrite)
        if ($cached) {
            return $cached
        }

        try {
            $rules = Read-ReceivedRules -FilePath $resolved
        }
        catch {
            $this._logger.LogWarning("Failed to load rules", @{
                Path = $resolved
                Error = $_.Exception.Message
            })
            return @()
        }

        $this.SetCache($key, $lastWrite, $rules)
        return $rules
    }

    [void] ClearCache([string]$filePath) {
        if ([string]::IsNullOrWhiteSpace($filePath)) {
            return
        }

        $resolved = $filePath
        if (Test-Path -LiteralPath $filePath) {
            $resolved = (Resolve-Path -LiteralPath $filePath).Path
        }
        $key = $resolved.ToLowerInvariant()

        [System.Threading.Monitor]::Enter($this._lock)
        try {
            if ($this._cache.ContainsKey($key)) {
                $null = $this._cache.Remove($key)
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }
    }

    hidden [object[]] TryGetCached([string]$key, [datetime]$lastWrite) {
        [System.Threading.Monitor]::Enter($this._lock)
        try {
            if ($this._cache.ContainsKey($key)) {
                $entry = $this._cache[$key]
                if ($entry.LastWriteTimeUtc -eq $lastWrite) {
                    return $entry.Rules
                }
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }

        return $null
    }

    hidden [void] SetCache([string]$key, [datetime]$lastWrite, [object[]]$rules) {
        [System.Threading.Monitor]::Enter($this._lock)
        try {
            $this._cache[$key] = @{
                LastWriteTimeUtc = $lastWrite
                Rules            = $rules
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }
    }
}
