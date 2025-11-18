# Core/Infrastructure/RunspaceMessageProcessor.ps1
# メッセージキューからメッセージを取り出してUIスレッドで処理

<#
.SYNOPSIS
Runspaceメッセージプロセッサ

.DESCRIPTION
RunspaceMessageQueueからメッセージを取り出し、適切な処理を実行する。
すべての処理はUIスレッドで実行されるため、接続オブジェクトへの
直接アクセスが安全に行える。
#>
class RunspaceMessageProcessor {
    hidden [RunspaceMessageQueue]$_queue
    hidden [ConnectionService]$_connectionService
    hidden [ReceivedEventPipeline]$_pipeline
    hidden [Logger]$_logger
    hidden [int]$_totalProcessed
    hidden [hashtable]$_processingStats
    
    <#
    .SYNOPSIS
    コンストラクタ
    
    .PARAMETER queue
    メッセージキュー
    
    .PARAMETER connectionService
    接続サービス
    
    .PARAMETER pipeline
    受信イベントパイプライン
    
    .PARAMETER logger
    ロガー
    #>
    RunspaceMessageProcessor(
        [RunspaceMessageQueue]$queue,
        [ConnectionService]$connectionService,
        [ReceivedEventPipeline]$pipeline,
        [Logger]$logger
    ) {
        if (-not $queue) {
            throw "RunspaceMessageQueue is required"
        }
        if (-not $connectionService) {
            throw "ConnectionService is required"
        }
        if (-not $pipeline) {
            throw "ReceivedEventPipeline is required"
        }
        if (-not $logger) {
            throw "Logger is required"
        }
        
        $this._queue = $queue
        $this._connectionService = $connectionService
        $this._pipeline = $pipeline
        $this._logger = $logger
        $this._totalProcessed = 0
        $this._processingStats = @{
            StatusUpdate = 0
            DataReceived = 0
            ErrorOccurred = 0
            ActivityMarker = 0
            SocketUpdate = 0
            LogMessage = 0
            SendRequest = 0
            Unknown = 0
        }
        
        $this._logger.LogInfo("RunspaceMessageProcessor initialized", @{})
    }
    
    <#
    .SYNOPSIS
    メッセージを処理する
    
    .PARAMETER maxCount
    1回の呼び出しで処理する最大メッセージ数
    
    .RETURNS
    実際に処理したメッセージ数
    
    .DESCRIPTION
    キューからメッセージを取り出して処理する。
    maxCount個のメッセージを処理するか、キューが空になるまで処理を続ける。
    
    .EXAMPLE
    $processed = $processor.ProcessMessages(50)
    #>
    [int] ProcessMessages([int]$maxCount) {
        if ($maxCount -le 0) {
            return 0
        }
        
        $processed = 0
        
        while ($processed -lt $maxCount) {
            $message = $null
            
            if (-not $this._queue.TryDequeue([ref]$message)) {
                # キューが空
                break
            }
            
            try {
                $this.ProcessMessage($message)
                $processed++
                $this._totalProcessed++
            }
            catch {
                $this._logger.LogError("Failed to process message", $_.Exception, @{
                    MessageType = if ($message) { $message.Type } else { 'null' }
                    ConnectionId = if ($message) { $message.ConnectionId } else { 'null' }
                    ErrorMessage = $_.Exception.Message
                })
            }
        }
        
        return $processed
    }
    
    <#
    .SYNOPSIS
    単一メッセージを処理
    
    .PARAMETER message
    処理するメッセージ
    
    .DESCRIPTION
    メッセージタイプに応じて適切な処理を実行する。
    #>
    hidden [void] ProcessMessage([object]$message) {
        if (-not $message) {
            $this._logger.LogWarning("Null message received", @{})
            return
        }
        
        # 接続オブジェクトを取得
        $conn = $this._connectionService.GetConnection($message.ConnectionId)
        
        # メッセージタイプに応じて処理を分岐
        switch ($message.Type) {
            'StatusUpdate' {
                $this.ProcessStatusUpdate($conn, $message)
                $this._processingStats['StatusUpdate']++
            }
            'DataReceived' {
                $this.ProcessDataReceived($conn, $message)
                $this._processingStats['DataReceived']++
            }
            'ErrorOccurred' {
                $this.ProcessError($conn, $message)
                $this._processingStats['ErrorOccurred']++
            }
            'ActivityMarker' {
                $this.ProcessActivityMarker($conn, $message)
                $this._processingStats['ActivityMarker']++
            }
            'SocketUpdate' {
                $this.ProcessSocketUpdate($conn, $message)
                $this._processingStats['SocketUpdate']++
            }
            'LogMessage' {
                $this.ProcessLogMessage($message)
                $this._processingStats['LogMessage']++
            }
            'SendRequest' {
                $this.ProcessSendRequest($conn, $message)
                $this._processingStats['SendRequest']++
            }
            default {
                $this._logger.LogWarning("Unknown message type", @{
                    MessageType = $message.Type
                    ConnectionId = $message.ConnectionId
                })
                $this._processingStats['Unknown']++
            }
        }
    }
    
    <#
    .SYNOPSIS
    接続状態更新メッセージを処理
    #>
    hidden [void] ProcessStatusUpdate([object]$conn, [object]$message) {
        if ($conn) {
            $status = $message.Data['Status']
            $conn.UpdateStatus($status)
            
            $this._logger.LogInfo("Status updated", @{
                ConnectionId = $message.ConnectionId
                Status = $status
            })
        }
        else {
            $this._logger.LogWarning("Connection not found for status update", @{
                ConnectionId = $message.ConnectionId
            })
        }
    }
    
    <#
    .SYNOPSIS
    データ受信メッセージを処理
    #>
    hidden [void] ProcessDataReceived([object]$conn, [object]$message) {
        try {
            $data = $message.Data['Data']
            $metadata = $message.Data['Metadata']
            
            # ReceivedEventPipeline経由で処理
            $this._pipeline.ProcessEvent(
                $message.ConnectionId,
                $data,
                $metadata
            )
            
            # アクティビティをマーク（DataReceivedメッセージには既にActivityMarkerが
            # 送られている想定だが、念のためここでもマーク）
            if ($conn) {
                $conn.MarkActivity()
            }
        }
        catch {
            $this._logger.LogError("Failed to process received data", $_.Exception, @{
                ConnectionId = $message.ConnectionId
                DataLength = if ($message.Data['Data']) { $message.Data['Data'].Length } else { 0 }
            })
        }
    }
    
    <#
    .SYNOPSIS
    エラー発生メッセージを処理
    #>
    hidden [void] ProcessError([object]$conn, [object]$message) {
        if ($conn) {
            $errorMessage = $message.Data['Message']
            $exception = $message.Data['Exception']
            
            $conn.SetError($errorMessage, $exception)
            
            $this._logger.LogError("Connection error reported", $exception, @{
                ConnectionId = $message.ConnectionId
                ErrorMessage = $errorMessage
            })
        }
        else {
            $this._logger.LogWarning("Connection not found for error message", @{
                ConnectionId = $message.ConnectionId
                ErrorMessage = $message.Data['Message']
            })
        }
    }
    
    <#
    .SYNOPSIS
    アクティビティマーカーメッセージを処理
    #>
    hidden [void] ProcessActivityMarker([object]$conn, [object]$message) {
        if ($conn) {
            $conn.MarkActivity()
        }
    }
    
    <#
    .SYNOPSIS
    ソケット更新メッセージを処理
    #>
    hidden [void] ProcessSocketUpdate([object]$conn, [object]$message) {
        if ($conn) {
            $socket = $message.Data['Socket']
            
            if ($socket) {
                $conn.SetSocket($socket)
            }
            else {
                $conn.ClearSocket()
            }
        }
    }
    
    <#
    .SYNOPSIS
    ログメッセージを処理
    #>
    hidden [void] ProcessLogMessage([object]$message) {
        $level = $message.Data['Level']
        $logMessage = $message.Data['Message']
        $context = $message.Data['Context']
        
        if (-not $context) {
            $context = @{}
        }
        
        # ConnectionIdをコンテキストに追加
        $context['ConnectionId'] = $message.ConnectionId
        
        switch ($level) {
            'Info' {
                $this._logger.LogInfo($logMessage, $context)
            }
            'Warning' {
                $this._logger.LogWarning($logMessage, $context)
            }
            'Error' {
                $this._logger.LogError($logMessage, $null, $context)
            }
            default {
                $this._logger.LogInfo($logMessage, $context)
            }
        }
    }
    
    <#
    .SYNOPSIS
    送信リクエストメッセージを処理 (将来の拡張用)
    #>
    hidden [void] ProcessSendRequest([object]$conn, [object]$message) {
        # 現状では未実装（SendQueueに直接追加する方式を使用）
        $this._logger.LogWarning("SendRequest message not implemented", @{
            ConnectionId = $message.ConnectionId
        })
    }
    
    <#
    .SYNOPSIS
    統計情報を取得
    
    .RETURNS
    処理統計のハッシュテーブル
    #>
    [hashtable] GetStatistics() {
        return @{
            TotalProcessed = $this._totalProcessed
            ProcessingStats = $this._processingStats.Clone()
            QueueStats = $this._queue.GetStatistics()
        }
    }
    
    <#
    .SYNOPSIS
    統計情報をログ出力
    #>
    [void] LogStatistics() {
        $stats = $this.GetStatistics()
        $this._logger.LogInfo("Message processor statistics", $stats)
    }
}
