# Core/Domain/ReceivedEventPipeline.ps1

class ReceivedEventPipeline {
    hidden [Logger]$_logger
    hidden [ConnectionService]$_connectionService
    hidden [RuleProcessor]$_ruleProcessor

    ReceivedEventPipeline(
        [Logger]$logger,
        [ConnectionService]$connectionService,
        [RuleProcessor]$ruleProcessor
    ) {
        if (-not $logger) {
            throw "Logger is required for ReceivedEventPipeline."
        }
        if (-not $connectionService) {
            throw "ConnectionService is required for ReceivedEventPipeline."
        }
        if (-not $ruleProcessor) {
            throw "RuleProcessor is required for ReceivedEventPipeline."
        }

        $this._logger = $logger
        $this._connectionService = $connectionService
        $this._ruleProcessor = $ruleProcessor
    }

    [void] ProcessEvent(
        [string]$connectionId,
        [byte[]]$data,
        [hashtable]$metadata
    ) {
        if ([string]::IsNullOrWhiteSpace($connectionId) -or -not $data -or $data.Length -eq 0) {
            return
        }

        $connection = $this._connectionService.GetConnection($connectionId)
        if (-not $connection) {
            $this._logger.LogWarning("Received data for unknown connection", @{
                ConnectionId = $connectionId
                Length       = if ($data) { $data.Length } else { 0 }
            })
            return
        }

        if (-not $metadata) {
            $metadata = @{}
        }

        $timestamp = Get-Date
        $entry = [PSCustomObject]@{
            Timestamp = $timestamp
            Data      = $data
            Length    = $data.Length
        }

        foreach ($key in $metadata.Keys) {
            $entry | Add-Member -NotePropertyName $key -NotePropertyValue $metadata[$key] -Force
        }

        try {
            if ($connection.RecvBuffer) {
                # RecvBufferサイズ制限（FIFO: 1000件を超えたら古いものを削除）
                if ($connection.RecvBuffer.Count -ge 1000) {
                    # 最も古いエントリを削除（先頭から100件削除して余裕を持たせる）
                    $removeCount = [Math]::Min(100, $connection.RecvBuffer.Count - 900)
                    for ($i = 0; $i -lt $removeCount; $i++) {
                        [void]$connection.RecvBuffer.RemoveAt(0)
                    }
                }
                
                [void]$connection.RecvBuffer.Add($entry)
            }
            if ($connection -is [ManagedConnection]) {
                $connection.MarkActivity()
            } else {
                $connection.LastActivity = $timestamp
            }
        }
        catch {
            $this._logger.LogWarning("Failed to update receive buffer", @{
                ConnectionId = $connection.Id
                Error        = $_.Exception.Message
            })
        }

        $logContext = @{
            Connection = $connection.DisplayName
            ConnectionId = $connection.Id
            Protocol   = $connection.Protocol
            RemoteIP   = $connection.RemoteIP
            RemotePort = $connection.RemotePort
        }

        foreach ($key in $metadata.Keys) {
            $logContext[$key] = $metadata[$key]
        }

        $this._logger.LogReceive($connection.Id, $data, $logContext)

        try {
            $this._ruleProcessor.ProcessRules($connection, $data)
        }
        catch {
            $this._logger.LogError("Rule processing pipeline failed", $_.Exception, @{
                ConnectionId = $connection.Id
            })
        }
    }
}
