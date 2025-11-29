# Core/Infrastructure/RunspaceMessageQueue.ps1
# スレッドセーフなメッセージキュー実装

<#
.SYNOPSIS
Runspace間通信用のスレッドセーフなメッセージキュー

.DESCRIPTION
ConcurrentQueueを使用してRunspaceからUIスレッドへメッセージを安全に転送する。
このクラスはRunspaceMessages.ps1で定義されたメッセージオブジェクトを扱う。
#>
class RunspaceMessageQueue {
    hidden [System.Collections.Concurrent.ConcurrentQueue[object]]$_queue
    hidden [Logger]$_logger
    hidden [int]$_totalEnqueued
    hidden [int]$_totalDequeued
    
    <#
    .SYNOPSIS
    コンストラクタ
    
    .PARAMETER logger
    ロガーインスタンス
    #>
    RunspaceMessageQueue([Logger]$logger) {
        if (-not $logger) {
            throw "Logger is required for RunspaceMessageQueue"
        }
        
        $this._queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
        $this._logger = $logger
        $this._totalEnqueued = 0
        $this._totalDequeued = 0
        
        $this._logger.LogInfo("RunspaceMessageQueue initialized", @{})
    }
    
    <#
    .SYNOPSIS
    メッセージをキューに追加
    
    .PARAMETER message
    RunspaceMessageオブジェクト
    
    .DESCRIPTION
    スレッドセーフにメッセージをキューに追加する。
    nullメッセージは拒否される。
    #>
    [void] Enqueue([object]$message) {
        if (-not $message) {
            throw "Message cannot be null"
        }
        
        # メッセージがRunspaceMessageクラスのインスタンスか確認
        if ($message.GetType().Name -ne 'RunspaceMessage') {
            $this._logger.LogWarning("Non-RunspaceMessage object enqueued", @{
                Type = $message.GetType().FullName
            })
        }
        
        $this._queue.Enqueue($message)
        $this._totalEnqueued++
        
        # デバッグログ (必要に応じてコメントアウト)
        # $this._logger.LogInfo("Message enqueued", @{
        #     Type = $message.Type
        #     ConnectionId = $message.ConnectionId
        #     QueueCount = $this._queue.Count
        # })
    }
    
    <#
    .SYNOPSIS
    キューからメッセージを取得
    
    .PARAMETER message
    取得したメッセージを格納する参照変数
    
    .RETURNS
    取得成功時はtrue、キューが空の場合はfalse
    
    .DESCRIPTION
    スレッドセーフにキューからメッセージを取得する。
    キューが空の場合はfalseを返し、messageにはnullが設定される。
    
    .EXAMPLE
    $msg = $null
    if ($queue.TryDequeue([ref]$msg)) {
    Write-Console "Got message: $($msg.Type)"
    }
    #>
    [bool] TryDequeue([ref]$message) {
        $result = $this._queue.TryDequeue($message)
        
        if ($result) {
            $this._totalDequeued++
            
            # デバッグログ (必要に応じてコメントアウト)
            # if ($message.Value) {
            #     $this._logger.LogInfo("Message dequeued", @{
            #         Type = $message.Value.Type
            #         ConnectionId = $message.Value.ConnectionId
            #         QueueCount = $this._queue.Count
            #     })
            # }
        }
        
        return $result
    }
    
    <#
    .SYNOPSIS
    キューの現在のメッセージ数を取得
    
    .RETURNS
    キュー内のメッセージ数
    #>
    [int] GetCount() {
        return $this._queue.Count
    }
    
    <#
    .SYNOPSIS
    統計情報を取得
    
    .RETURNS
    統計情報のハッシュテーブル
    #>
    [hashtable] GetStatistics() {
        return @{
            CurrentCount = $this._queue.Count
            TotalEnqueued = $this._totalEnqueued
            TotalDequeued = $this._totalDequeued
            PendingMessages = $this._totalEnqueued - $this._totalDequeued
        }
    }
    
    <#
    .SYNOPSIS
    キューをクリア
    
    .DESCRIPTION
    キュー内のすべてのメッセージを削除する。
    緊急時やシャットダウン時に使用。
    #>
    [void] Clear() {
        $clearedCount = 0
        $temp = $null
        
        while ($this._queue.TryDequeue([ref]$temp)) {
            $clearedCount++
        }
        
        if ($clearedCount -gt 0) {
            $this._logger.LogWarning("Message queue cleared", @{
                ClearedCount = $clearedCount
            })
        }
    }
    
    <#
    .SYNOPSIS
    キューの状態をログ出力
    
    .DESCRIPTION
    デバッグ用にキューの統計情報をログに出力
    #>
    [void] LogStatistics() {
        $stats = $this.GetStatistics()
        $this._logger.LogInfo("Message queue statistics", $stats)
    }
    
    <#
    .SYNOPSIS
    キューが空かどうかを確認
    
    .RETURNS
    空の場合true、メッセージがある場合false
    #>
    [bool] IsEmpty() {
        return $this._queue.IsEmpty
    }
}
