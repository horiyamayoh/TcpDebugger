. "$PSScriptRoot\ConnectionModels.ps1"

class ConnectionService {
    hidden [Logger]$_logger
    hidden [System.Collections.Hashtable]$_connections
    hidden [object]$_lock

    ConnectionService(
        [Logger]$logger,
        [System.Collections.Hashtable]$backingStore
    ) {
        if (-not $logger) {
            throw "Logger instance is required."
        }

        $this._logger = $logger
        if ($backingStore) {
            $this._connections = $backingStore
        } else {
            $this._connections = [System.Collections.Hashtable]::Synchronized(@{})
        }
        $this._lock = [object]::new()
    }

    [System.Collections.Hashtable] GetStore() {
        return $this._connections
    }

    [ManagedConnection] AddConnection([hashtable]$config) {
        if (-not $config) {
            throw "Connection configuration cannot be null."
        }

        $configuration = [ConnectionConfiguration]::new($config)

        [System.Threading.Monitor]::Enter($this._lock)
        try {
            if ($this._connections.ContainsKey($configuration.Id)) {
                $this._logger.LogWarning("Connection already exists", @{
                    ConnectionId = $configuration.Id
                })
                return $this._connections[$configuration.Id]
            }

            $connection = [ManagedConnection]::new($configuration, $null, $null)
            $this._connections[$configuration.Id] = $connection

            $this._logger.LogInfo("Connection added", @{
                ConnectionId = $configuration.Id
                DisplayName = $configuration.DisplayName
                Protocol = $configuration.Protocol
                Mode = $configuration.Mode
            })

            return $connection
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }
    }

    [void] RemoveConnection([string]$connectionId) {
        if ([string]::IsNullOrWhiteSpace($connectionId)) {
            return
        }

        [System.Threading.Monitor]::Enter($this._lock)
        try {
            if ($this._connections.ContainsKey($connectionId)) {
                $null = $this._connections.Remove($connectionId)
                $this._logger.LogInfo("Connection removed", @{
                    ConnectionId = $connectionId
                })
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }
    }

    [ManagedConnection] GetConnection([string]$connectionId) {
        if ([string]::IsNullOrWhiteSpace($connectionId)) {
            return $null
        }
        return $this._connections[$connectionId]
    }

    [ManagedConnection[]] GetAllConnections() {
        [System.Threading.Monitor]::Enter($this._lock)
        try {
            # Synchronized Hashtable???.Values????????S?????
            # ?R?s?[??????????S??z??????
            $result = @($this._connections.Values)
            return $result
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }
    }

    [ManagedConnection[]] GetConnectionsByGroup([string]$group) {
        if ([string]::IsNullOrWhiteSpace($group)) {
            return @()
        }

        # foreachで結果リストを構築（Where-Objectパイプラインより高速）
        $result = [System.Collections.Generic.List[ManagedConnection]]::new()
        foreach ($conn in $this._connections.Values) {
            if ($conn.Group -eq $group) {
                $result.Add($conn)
            }
        }
        return $result.ToArray()
    }

    [ManagedConnection[]] GetConnectionsByTag([string]$tag) {
        if ([string]::IsNullOrWhiteSpace($tag)) {
            return @()
        }

        # foreachで結果リストを構築（Where-Objectパイプラインより高速）
        $result = [System.Collections.Generic.List[ManagedConnection]]::new()
        foreach ($conn in $this._connections.Values) {
            if ($conn.Tags -contains $tag) {
                $result.Add($conn)
            }
        }
        return $result.ToArray()
    }

    [void] ClearConnections() {
        [System.Threading.Monitor]::Enter($this._lock)
        try {
            $this._connections.Clear()
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }
    }
}
