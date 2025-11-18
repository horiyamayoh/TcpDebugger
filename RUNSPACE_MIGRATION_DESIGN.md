# Runspace Migration Design Document

## 1. 概要

### 1.1 目的
PowerShellのスレッド実装をRunspaceベースに移行し、アプリケーションの安定性を向上させる。

### 1.2 背景
現在の実装では以下の問題が発生している：
- PowerShellクラスインスタンスをスレッド間で共有することによるランタイムの不安定性
- ScriptBlockのクロージャによるメモリ破壊
- 接続オブジェクトへの直接アクセスによる競合状態
- 5秒程度でアプリケーションがクラッシュする

### 1.3 解決方針
- **Runspace**: 各接続に独立したPowerShell実行環境を提供
- **メッセージキュー**: スレッド間通信を非同期メッセージパッシングで実現
- **UIスレッドでの状態管理**: すべての状態変更をUIスレッドで一元管理

## 2. アーキテクチャ設計

### 2.1 システム構成図

```
┌─────────────────────────────────────────────────────────────────┐
│ UIスレッド (WinForms)                                            │
│                                                                  │
│  ┌────────────┐    ┌──────────────────┐    ┌────────────────┐  │
│  │ MainForm   │───→│ ConnectionManager│───→│ MessageQueue   │  │
│  │ (Timer)    │    │                  │    │ Processor      │  │
│  └────────────┘    └──────────────────┘    └────────────────┘  │
│         ↓                   ↓                       ↓           │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ ConnectionService (接続オブジェクト管理)               │    │
│  │  - GetConnection()                                     │    │
│  │  - GetAllConnections() ← スナップショット返却          │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                            ↓ Start/Stop
┌─────────────────────────────────────────────────────────────────┐
│ Adapter Layer                                                    │
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │ TcpClientAdapter │  │ TcpServerAdapter │  │ UdpAdapter   │  │
│  │  - Start()       │  │  - Start()       │  │  - Start()   │  │
│  │  - Stop()        │  │  - Stop()        │  │  - Stop()    │  │
│  └──────────────────┘  └──────────────────┘  └──────────────┘  │
│         ↓                       ↓                     ↓         │
│  PowerShell.Create() + Runspace                                 │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Runspace Pool (独立したPowerShell実行環境)                      │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │ Runspace #1 │  │ Runspace #2 │  │ Runspace #3 │  ...       │
│  │ (接続A)     │  │ (接続B)     │  │ (接続C)     │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
│         ↓                 ↓                 ↓                   │
│  TCP/UDP通信処理                                                │
└─────────────────────────────────────────────────────────────────┘
                            ↓ メッセージ送信
┌─────────────────────────────────────────────────────────────────┐
│ RunspaceMessageQueue (ConcurrentQueue)                           │
│                                                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐  │
│  │ StatusUpdate    │  │ DataReceived    │  │ ErrorOccurred  │  │
│  │ ActivityMarker  │  │ SocketUpdate    │  │ ...            │  │
│  └─────────────────┘  └─────────────────┘  └────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 データフロー

#### 接続開始フロー
```
1. UI: Connectボタン押下
2. ConnectionManager: Start-Connection
3. Adapter: Start(connectionId)
   ├─ Runspace作成
   ├─ 必要な変数を設定
   ├─ ScriptBlock準備
   └─ PowerShell.BeginInvoke()
4. Runspace: TCP/UDP接続処理
   └─ メッセージキューに状態を送信
5. UIスレッド: タイマーがメッセージをポーリング
   └─ 接続オブジェクトの状態を更新
```

#### データ受信フロー
```
1. Runspace: データ受信
2. メッセージキューに追加
   ├─ Type: DataReceived
   ├─ ConnectionId
   ├─ Data (byte[])
   └─ Metadata
3. UIスレッド: メッセージ処理
   └─ ReceivedEventPipeline.ProcessEvent()
```

## 3. 主要コンポーネント設計

### 3.1 メッセージ型定義

**ファイル**: `Core/Domain/RunspaceMessages.ps1`

```powershell
# メッセージタイプ列挙型
enum MessageType {
    StatusUpdate      # 接続状態の変更
    DataReceived      # データ受信
    ErrorOccurred     # エラー発生
    ActivityMarker    # 最終アクティビティ時刻更新
    SocketUpdate      # ソケット状態更新
    LogMessage        # ログメッセージ
}

# メッセージ基底クラス
class RunspaceMessage {
    [MessageType]$Type
    [string]$ConnectionId
    [datetime]$Timestamp
    [hashtable]$Data
    
    RunspaceMessage([MessageType]$type, [string]$connId, [hashtable]$data) {
        $this.Type = $type
        $this.ConnectionId = $connId
        $this.Timestamp = Get-Date
        $this.Data = if ($data) { $data } else { @{} }
    }
}

# ヘルパー関数
function New-StatusUpdateMessage {
    param([string]$ConnectionId, [string]$Status)
    return [RunspaceMessage]::new([MessageType]::StatusUpdate, $ConnectionId, @{ Status = $Status })
}

function New-DataReceivedMessage {
    param([string]$ConnectionId, [byte[]]$Data, [hashtable]$Metadata)
    return [RunspaceMessage]::new([MessageType]::DataReceived, $ConnectionId, @{ 
        Data = $Data
        Metadata = $Metadata
    })
}

function New-ErrorMessage {
    param([string]$ConnectionId, [string]$Message, [Exception]$Exception)
    return [RunspaceMessage]::new([MessageType]::ErrorOccurred, $ConnectionId, @{ 
        Message = $Message
        Exception = $Exception
    })
}

function New-ActivityMessage {
    param([string]$ConnectionId)
    return [RunspaceMessage]::new([MessageType]::ActivityMarker, $ConnectionId, @{})
}

function New-LogMessage {
    param([string]$ConnectionId, [string]$Level, [string]$Message, [hashtable]$Context)
    return [RunspaceMessage]::new([MessageType]::LogMessage, $ConnectionId, @{
        Level = $Level
        Message = $Message
        Context = $Context
    })
}
```

### 3.2 メッセージキュー

**ファイル**: `Core/Infrastructure/RunspaceMessageQueue.ps1`

```powershell
class RunspaceMessageQueue {
    hidden [System.Collections.Concurrent.ConcurrentQueue[RunspaceMessage]]$_queue
    hidden [Logger]$_logger
    
    RunspaceMessageQueue([Logger]$logger) {
        $this._queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
        $this._logger = $logger
    }
    
    [void] Enqueue([RunspaceMessage]$message) {
        if (-not $message) {
            throw "Message cannot be null"
        }
        $this._queue.Enqueue($message)
    }
    
    [bool] TryDequeue([ref]$message) {
        return $this._queue.TryDequeue($message)
    }
    
    [int] GetCount() {
        return $this._queue.Count
    }
    
    [void] Clear() {
        $temp = $null
        while ($this._queue.TryDequeue([ref]$temp)) {
            # キューをクリア
        }
    }
}
```

### 3.3 メッセージプロセッサ

**ファイル**: `Core/Infrastructure/RunspaceMessageProcessor.ps1`

```powershell
class RunspaceMessageProcessor {
    hidden [RunspaceMessageQueue]$_queue
    hidden [ConnectionService]$_connectionService
    hidden [ReceivedEventPipeline]$_pipeline
    hidden [Logger]$_logger
    
    RunspaceMessageProcessor(
        [RunspaceMessageQueue]$queue,
        [ConnectionService]$connectionService,
        [ReceivedEventPipeline]$pipeline,
        [Logger]$logger
    ) {
        $this._queue = $queue
        $this._connectionService = $connectionService
        $this._pipeline = $pipeline
        $this._logger = $logger
    }
    
    [int] ProcessMessages([int]$maxCount) {
        $processed = 0
        
        while ($processed -lt $maxCount) {
            $message = $null
            if (-not $this._queue.TryDequeue([ref]$message)) {
                break
            }
            
            try {
                $this.ProcessMessage($message)
                $processed++
            }
            catch {
                $this._logger.LogError("Failed to process message", $_.Exception, @{
                    MessageType = $message.Type
                    ConnectionId = $message.ConnectionId
                })
            }
        }
        
        return $processed
    }
    
    hidden [void] ProcessMessage([RunspaceMessage]$message) {
        $conn = $this._connectionService.GetConnection($message.ConnectionId)
        
        switch ($message.Type) {
            'StatusUpdate' {
                if ($conn) {
                    $conn.UpdateStatus($message.Data['Status'])
                }
            }
            'DataReceived' {
                $this._pipeline.ProcessEvent(
                    $message.ConnectionId,
                    $message.Data['Data'],
                    $message.Data['Metadata']
                )
            }
            'ErrorOccurred' {
                if ($conn) {
                    $conn.SetError(
                        $message.Data['Message'],
                        $message.Data['Exception']
                    )
                }
            }
            'ActivityMarker' {
                if ($conn) {
                    $conn.MarkActivity()
                }
            }
            'SocketUpdate' {
                if ($conn) {
                    $socket = $message.Data['Socket']
                    if ($socket) {
                        $conn.SetSocket($socket)
                    } else {
                        $conn.ClearSocket()
                    }
                }
            }
            'LogMessage' {
                $level = $message.Data['Level']
                $msg = $message.Data['Message']
                $context = $message.Data['Context']
                
                switch ($level) {
                    'Info' { $this._logger.LogInfo($msg, $context) }
                    'Warning' { $this._logger.LogWarning($msg, $context) }
                    'Error' { $this._logger.LogError($msg, $null, $context) }
                }
            }
        }
    }
}
```

### 3.4 TcpClientAdapter (Runspace版)

**ファイル**: `Core/Infrastructure/Adapters/TcpClientAdapter.ps1`

設計の要点：
- `System.Threading.Thread`を廃止
- `PowerShell.Create()`でRunspaceベースの実行環境を作成
- ScriptBlock内では接続オブジェクトに直接アクセスせず、メッセージキュー経由で通信
- Runspace、PowerShellオブジェクト、AsyncHandleを`$connection.Variables`に保存

主要メソッド：
- `Start([string]$connectionId)`: Runspaceを作成して接続処理を開始
- `Stop([string]$connectionId)`: Runspaceを停止してクリーンアップ

### 3.5 接続オブジェクトの変更

**ファイル**: `Core/Domain/ConnectionModels.ps1`

追加プロパティ：
- Runspace関連のオブジェクトは`Variables`に格納
  - `_Runspace`: Runspaceオブジェクト
  - `_PowerShell`: PowerShellオブジェクト
  - `_AsyncHandle`: 非同期実行ハンドル

## 4. Runspace内のScriptBlock設計

### 4.1 基本構造

```powershell
$scriptBlock = {
    param(
        [string]$ConnectionId,
        [string]$RemoteIP,
        [int]$RemotePort,
        [object]$MessageQueue,
        [object]$Logger,
        [System.Threading.CancellationToken]$CancellationToken
    )
    
    # ヘルパー関数をロード
    . $using:HelperFunctionsPath
    
    try {
        # 状態更新: CONNECTING
        $msg = New-StatusUpdateMessage -ConnectionId $ConnectionId -Status 'CONNECTING'
        $MessageQueue.Enqueue($msg)
        
        # TCP接続
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect($RemoteIP, $RemotePort)
        
        # 状態更新: CONNECTED
        $msg = New-StatusUpdateMessage -ConnectionId $ConnectionId -Status 'CONNECTED'
        $MessageQueue.Enqueue($msg)
        
        $stream = $client.GetStream()
        $buffer = New-Object byte[] 8192
        
        # 送受信ループ
        while ($client.Connected -and -not $CancellationToken.IsCancellationRequested) {
            # 送信処理（SendQueueからの取得はメッセージ経由で実装）
            
            # 受信処理
            if ($stream.DataAvailable) {
                $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
                if ($bytesRead -gt 0) {
                    $data = $buffer[0..($bytesRead - 1)]
                    $msg = New-DataReceivedMessage -ConnectionId $ConnectionId -Data $data -Metadata @{
                        RemoteEndpoint = "$RemoteIP:$RemotePort"
                    }
                    $MessageQueue.Enqueue($msg)
                    
                    # アクティビティマーカー
                    $actMsg = New-ActivityMessage -ConnectionId $ConnectionId
                    $MessageQueue.Enqueue($actMsg)
                }
            }
            
            Start-Sleep -Milliseconds 10
        }
    }
    catch {
        $msg = New-ErrorMessage -ConnectionId $ConnectionId -Message $_.Exception.Message -Exception $_.Exception
        $MessageQueue.Enqueue($msg)
    }
    finally {
        # クリーンアップ
        if ($stream) { $stream.Close(); $stream.Dispose() }
        if ($client) { $client.Close(); $client.Dispose() }
        
        # 状態更新: DISCONNECTED
        $msg = New-StatusUpdateMessage -ConnectionId $ConnectionId -Status 'DISCONNECTED'
        $MessageQueue.Enqueue($msg)
    }
}
```

### 4.2 送信処理の実装

SendQueueから直接取得する代わりに：

**オプション1**: ConcurrentQueueを使う
```powershell
# 接続オブジェクトにConcurrentQueueを追加
$connection.Variables['SendQueue'] = New-Object 'System.Collections.Concurrent.ConcurrentQueue[byte[]]'

# Runspace内で取得
$sendQueue = $connection.Variables['SendQueue']
$data = $null
if ($sendQueue.TryDequeue([ref]$data)) {
    $stream.Write($data, 0, $data.Length)
}
```

**オプション2**: メッセージ経由で送信リクエスト
```powershell
# UIスレッド: 送信リクエストメッセージをキューに追加
$msg = [RunspaceMessage]::new([MessageType]::SendRequest, $connId, @{ Data = $data })
$messageQueue.Enqueue($msg)
```

## 5. UIスレッドでのメッセージ処理

### 5.1 タイマー設定

**ファイル**: `Presentation/UI/MainForm.ps1`

```powershell
# メッセージ処理タイマー (100ms間隔)
$messageTimer = New-Object System.Windows.Forms.Timer
$messageTimer.Interval = 100
$messageTimer.Add_Tick({
    try {
        $processor = $Global:MessageProcessor
        $processed = $processor.ProcessMessages(50)  # 最大50メッセージ/回
        
        if ($processed -gt 0) {
            Write-Verbose "[MessageProcessor] Processed $processed messages"
        }
    }
    catch {
        Write-Verbose "[MessageProcessor] Error: $_"
    }
})
$messageTimer.Start()
```

### 5.2 既存のRefreshタイマーとの統合

- Refreshタイマー: 2000ms間隔でGrid更新
- メッセージタイマー: 100ms間隔でメッセージ処理
- 両者は独立して動作

## 6. ServiceContainerへの登録

**ファイル**: `TcpDebugger.ps1`

```powershell
# メッセージキューとプロセッサの登録
$script:ServiceContainer.RegisterSingleton('RunspaceMessageQueue', {
    param($c)
    $logger = $c.Resolve('Logger')
    [RunspaceMessageQueue]::new($logger)
})

$script:ServiceContainer.RegisterSingleton('MessageProcessor', {
    param($c)
    $queue = $c.Resolve('RunspaceMessageQueue')
    $connectionService = $c.Resolve('ConnectionService')
    $pipeline = $c.Resolve('ReceivedEventPipeline')
    $logger = $c.Resolve('Logger')
    [RunspaceMessageProcessor]::new($queue, $connectionService, $pipeline, $logger)
})

# アダプターの更新（MessageQueueを注入）
$script:ServiceContainer.RegisterTransient('TcpClientAdapter', {
    param($c)
    $connectionService = $c.Resolve('ConnectionService')
    $pipeline = $c.Resolve('ReceivedEventPipeline')
    $logger = $c.Resolve('Logger')
    $messageQueue = $c.Resolve('RunspaceMessageQueue')
    [TcpClientAdapter]::new($connectionService, $pipeline, $logger, $messageQueue)
})
```

## 7. テスト戦略

### 7.1 単体テスト
- メッセージキューの動作確認
- メッセージプロセッサの各メッセージタイプ処理
- Runspace作成と破棄

### 7.2 統合テスト
- TcpClientAdapterでの接続・切断
- データ送受信
- エラーハンドリング
- 複数接続の同時動作

### 7.3 負荷テスト
- 長時間稼働（1時間以上）
- 高頻度の接続・切断
- 大量データ送受信

## 8. 移行手順

1. **Phase 1**: 基盤実装 (2-3時間)
2. **Phase 2**: TcpClientAdapter移行 (3-4時間)
3. **Phase 3**: テスト・デバッグ (2-3時間)
4. **Phase 4**: TcpServerAdapter/UdpAdapter移行 (2-3時間)
5. **Phase 5**: 最終テスト・ドキュメント (1-2時間)

## 9. リスクと対策

### リスク1: Runspace作成のオーバーヘッド
- **対策**: Runspace Poolの使用を検討（将来的な改善）
- **現状**: 接続数が少ない想定のため許容範囲

### リスク2: メッセージ処理の遅延
- **対策**: タイマー間隔を調整可能に
- **対策**: 処理するメッセージ数の上限を設定

### リスク3: デバッグの複雑化
- **対策**: 詳細なログ出力
- **対策**: メッセージフロー図の作成

## 10. 今後の拡張性

- **Runspace Pool**: 複数接続の効率化
- **async/await**: .NET Task ベースへの移行（PowerShell 7+）
- **メッセージ優先度**: 重要なメッセージを優先処理
- **パフォーマンス監視**: メッセージ処理時間の計測

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-19  
**Status**: Draft
