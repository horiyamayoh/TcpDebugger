# TcpDebugger アーキテクチャ改善設計書

## エグゼクティブサマリー

現在のTcpDebuggerコードベースは機能的には動作しているものの、以下の根本的な設計課題を抱えています：

1. **受信イベント処理の不完全な統合** - 受信データのイベント処理パイプラインが分断され、一部の機能が動作していない
2. **責務の曖昧さ** - モジュール間の責務境界が不明確で、重複したロジックが散在
3. **スレッド安全性の不備** - 共有状態の同期が不十分で、競合状態のリスクが高い
4. **テスタビリティの欠如** - 密結合な設計により単体テストが困難
5. **拡張性の限界** - 新しい通信プロトコルや機能の追加が困難

本設計書では、これらの課題を解決し、保守性・拡張性・信頼性を大幅に向上させる包括的なリファクタリング計画を提示します。

---

## 1. 現状分析：特定された問題点

### 1.1 受信イベント処理パイプラインの分断

**問題の本質:**
- `TcpClient.ps1`, `TcpServer.ps1`, `UdpCommunication.ps1` の受信ループ内で `Invoke-ConnectionAutoResponse` を直接呼び出しているが、呼び出し位置が不適切（受信データ取得前に実行）
- `ReceivedEventHandler.ps1` の `Invoke-ReceivedEvent` が統合処理を提供しているにも関わらず、通信モジュールから呼ばれていない
- AutoResponse と OnReceived の処理が別々のタイミングで実行されるべきだが、現状では AutoResponse しか動作していない

**具体的な問題箇所:**

`TcpClient.ps1` (L54-55):
```powershell
# 送信処理の後、受信処理の前に呼ばれている（バグ）
Invoke-ConnectionAutoResponse -ConnectionId $connId -ReceivedData $receivedData

# 受信処理（非ブロッキング）
if ($stream.DataAvailable) {
    $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
    # ... $receivedData がここで初めて定義される
}
```

**影響範囲:**
- OnReceived プロファイル機能が完全に不動作
- AutoResponse も未定義変数を参照してエラーになる可能性
- 統合形式（Unified）ルールの恩恵を受けられない

### 1.2 責務の曖昧さと重複コード

**問題の本質:**
各モジュールの責務が不明確で、同じような処理が複数箇所に散在しています。

**具体例:**

1. **ルール読み込みロジックの重複**
   - `AutoResponse.ps1`: `Read-AutoResponseRules`
   - `OnReceivedHandler.ps1`: `Read-OnReceivedRules`
   - `ReceivedRuleEngine.ps1`: `Read-ReceivedRules`（共通実装）
   
   → 3つのモジュールで同じような処理が定義されているが、実際には `ReceivedRuleEngine` だけを使うべき

2. **キャッシュ管理の分散**
   - 各モジュールが独自のキャッシュロジックを実装
   - キャッシュの無効化タイミングが統一されていない

3. **変数スコープの管理**
   - `Connection.Variables` が様々な目的で使われている（設定値、実行時状態、キャッシュ等）
   - どの変数がどのモジュールで使われるか追跡困難

### 1.3 スレッド安全性の問題

**問題の本質:**
マルチスレッド環境での共有状態管理に複数の問題があります。

**具体的な問題:**

1. **ConnectionContext の部分的な同期化**
   ```powershell
   # 同期化されている
   $this.Variables = [System.Collections.Hashtable]::Synchronized(@{})
   $this.SendQueue = [System.Collections.ArrayList]::Synchronized(...)
   
   # 同期化されていない
   $this.Status = "CONNECTED"  # 複数スレッドから書き込まれる
   $this.ErrorMessage = $_.Exception.Message
   ```

2. **グローバル変数へのアクセス**
   - `$Global:Connections` は同期化されているが、個々の Connection オブジェクトの操作は同期化されていない
   - UI スレッドと通信スレッドが同じオブジェクトを同時に読み書き

3. **タイマーイベントのスレッド安全性**
   - `Register-ObjectEvent` のイベントハンドラが別スレッドで実行される
   - `$Global:Connections` へのアクセスが保護されていない

### 1.4 モジュール設計の構造的欠陥

**問題の本質:**
レイヤー化アーキテクチャの原則が守られておらず、依存関係が循環しています。

**依存関係の問題:**

```
TcpClient.ps1
  ↓ 呼び出し
AutoResponse.ps1
  ↓ 呼び出し
ReceivedRuleEngine.ps1
  ↓ 呼び出し
MessageHandler.ps1
  ↓ 呼び出し
ConnectionManager.ps1 (Send-Data)
  ↓ アクセス
$Global:Connections
  ↑ 更新
TcpClient.ps1 ← 循環依存
```

**理想的な構造:**
```
Presentation Layer (UI)
   ↓
Application Layer (ScenarioEngine, InstanceManager)
   ↓
Domain Layer (ConnectionManager, MessageHandler)
   ↓
Infrastructure Layer (TcpClient, TcpServer, UDP)
```

### 1.5 エラーハンドリングとログの不統一

**問題の本質:**
エラー処理方針が統一されておらず、障害発生時の追跡が困難です。

**具体例:**

1. **エラーハンドリングの不統一**
   ```powershell
   # パターン1: try-catch で握りつぶす
   try { ... } catch { Write-Warning $_ }
   
   # パターン2: try-catch でエラーを投げる
   try { ... } catch { throw }
   
   # パターン3: エラーチェックなし
   $result = Do-Something
   # $result が $null でもそのまま使う
   ```

2. **ログレベルの不統一**
   - `Write-Host`, `Write-Warning`, `Write-Error` が混在
   - 重要度の基準が不明確
   - ログの構造化がなされていない

### 1.6 テスタビリティの欠如

**問題の本質:**
単体テストを書くことが極めて困難な設計になっています。

**具体的な障壁:**

1. **グローバル状態への強い依存**
   - すべての関数が `$Global:Connections` に直接アクセス
   - 依存性注入の仕組みがない

2. **副作用の多い関数**
   - ほとんどの関数が I/O 操作を含む
   - モック化が困難

3. **密結合な設計**
   - 関数間の依存が強く、一つの関数だけをテストできない

---

## 2. 改善アーキテクチャ設計

### 2.1 アーキテクチャ原則

以下の設計原則に基づいて改善を行います：

1. **単一責任原則 (SRP)**: 各モジュール・クラスは一つの責務のみを持つ
2. **開放閉鎖原則 (OCP)**: 拡張に開いて、修正に閉じた設計
3. **依存性逆転原則 (DIP)**: 抽象に依存し、具象に依存しない
4. **関心の分離 (SoC)**: ビジネスロジック、データアクセス、UI を明確に分離
5. **イミュータビリティ**: 可能な限り不変オブジェクトを使用
6. **明示的な依存関係**: グローバル変数を避け、依存を明示的に注入

### 2.2 レイヤーアーキテクチャの再設計

```
┌─────────────────────────────────────────────────┐
│  Presentation Layer (UI)                        │
│  - MainForm.ps1                                 │
│  - ViewModels (新規)                            │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│  Application Layer                              │
│  - ScenarioOrchestrator (新規)                  │
│  - InstanceCoordinator (新規)                   │
│  - ProfileManager (新規)                        │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│  Domain Layer                                   │
│  - ConnectionService (改善版 ConnectionManager) │
│  - MessageProcessor (改善版 MessageHandler)     │
│  - ReceivedEventPipeline (新規)                 │
│  - RuleRepository (新規)                        │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│  Infrastructure Layer                           │
│  - TcpClientAdapter (改善版 TcpClient)          │
│  - TcpServerAdapter (改善版 TcpServer)          │
│  - UdpAdapter (改善版 UdpCommunication)         │
│  - FileRepository (新規)                        │
│  - Logger (新規)                                │
└─────────────────────────────────────────────────┘
```

### 2.3 受信イベント処理パイプラインの再設計

**新しい処理フロー:**

```
受信データ発生
    ↓
[通信アダプター層]
    ↓ ReceivedEvent を発火
[ReceivedEventPipeline] ← 新設された統合ポイント
    ↓
    ├─→ [フィルター処理] (将来の拡張点)
    ├─→ [ロギング]
    ↓
[ReceivedRuleProcessor] ← ルールマッチング
    ↓
    ├─→ [AutoResponse 処理]
    │      ├─ テンプレート展開
    │      └─ 送信キューへ追加
    │
    └─→ [OnReceived 処理]
           ├─ スクリプト実行
           └─ 変数更新
```

**実装方針:**

1. **イベント駆動アーキテクチャの導入**
   ```powershell
   # 通信アダプターはイベントを発火するだけ
   class ReceivedEventArgs {
       [string]$ConnectionId
       [byte[]]$Data
       [datetime]$Timestamp
       [object]$RemoteEndPoint
   }
   
   # パイプラインがイベントを受け取って処理
   class ReceivedEventPipeline {
       [void] ProcessEvent([ReceivedEventArgs]$event) {
           $this.Logger.LogReceive($event)
           $this.RuleProcessor.Process($event)
       }
   }
   ```

2. **責務の明確な分離**
   - 通信層: データの送受信のみ
   - パイプライン層: イベントのルーティング
   - ルール処理層: ビジネスロジックの実行

### 2.4 接続状態管理の改善

**現状の問題:**
```powershell
class ConnectionContext {
    [string]$Status  # スレッドセーフでない
    # ... 多数のミュータブルなプロパティ
}
```

**改善案:**

```powershell
# 1. 不変な接続設定と可変な実行時状態を分離
class ConnectionConfiguration {
    # 読み取り専用の設定値
    [ValidateNotNullOrEmpty()][string]$Id
    [ValidateNotNullOrEmpty()][string]$DisplayName
    [ValidateSet("TCP", "UDP")][string]$Protocol
    [ValidateSet("Client", "Server")][string]$Mode
    # ... その他の設定
    
    # すべてコンストラクタで初期化され、以後変更不可
}

class ConnectionRuntimeState {
    # スレッドセーフなプロパティのみ
    hidden [object]$_statusLock = [object]::new()
    hidden [string]$_status = "IDLE"
    
    [string] GetStatus() {
        [System.Threading.Monitor]::Enter($this._statusLock)
        try { return $this._status }
        finally { [System.Threading.Monitor]::Exit($this._statusLock) }
    }
    
    [void] SetStatus([string]$value) {
        [System.Threading.Monitor]::Enter($this._statusLock)
        try { $this._status = $value }
        finally { [System.Threading.Monitor]::Exit($this._statusLock) }
    }
}

class ManagedConnection {
    [ConnectionConfiguration]$Config
    [ConnectionRuntimeState]$State
    [ICommunicationAdapter]$Adapter
    [VariableScope]$Variables  # 専用のスコープクラス
}
```

### 2.5 モジュールの再編成

**新しいモジュール構成:**

```
Core/
├── Domain/
│   ├── ConnectionService.ps1      # 接続ライフサイクル管理
│   ├── MessageProcessor.ps1       # メッセージ処理の中核
│   ├── ReceivedEventPipeline.ps1  # 受信イベント統合処理
│   ├── RuleProcessor.ps1          # ルールマッチング・実行
│   └── VariableScope.ps1          # スレッドセーフな変数管理
│
├── Application/
│   ├── ScenarioOrchestrator.ps1   # シナリオ実行の統括
│   ├── ProfileManager.ps1         # プロファイル管理
│   └── InstanceCoordinator.ps1    # インスタンス統括管理
│
└── Infrastructure/
    ├── Adapters/
    │   ├── TcpClientAdapter.ps1
    │   ├── TcpServerAdapter.ps1
    │   └── UdpAdapter.ps1
    ├── Repositories/
    │   ├── RuleRepository.ps1      # ルールファイル読み込み
    │   ├── TemplateRepository.ps1  # テンプレート管理
    │   └── ScenarioRepository.ps1  # シナリオファイル管理
    └── Common/
        ├── Logger.ps1              # 構造化ログ
        ├── ErrorHandler.ps1        # エラー処理統一
        └── ThreadSafeCollections.ps1

Presentation/
└── UI/
    ├── MainForm.ps1
    ├── ConnectionViewModel.ps1     # データバインディング用
    └── UIUpdateService.ps1         # UI更新の統一インターフェース
```

### 2.6 依存性注入コンテナの導入

**目的:**
- グローバル変数への依存を排除
- テスタビリティの向上
- モジュール間の疎結合化

**実装例:**

```powershell
# ServiceContainer.ps1
class ServiceContainer {
    hidden [hashtable]$_services = @{}
    hidden [hashtable]$_singletons = @{}
    
    [void] RegisterSingleton([string]$name, [scriptblock]$factory) {
        $this._services[$name] = @{
            Type = 'Singleton'
            Factory = $factory
        }
    }
    
    [void] RegisterTransient([string]$name, [scriptblock]$factory) {
        $this._services[$name] = @{
            Type = 'Transient'
            Factory = $factory
        }
    }
    
    [object] Resolve([string]$name) {
        $service = $this._services[$name]
        if (-not $service) {
            throw "Service not registered: $name"
        }
        
        if ($service.Type -eq 'Singleton') {
            if (-not $this._singletons.ContainsKey($name)) {
                $this._singletons[$name] = & $service.Factory $this
            }
            return $this._singletons[$name]
        }
        
        return & $service.Factory $this
    }
}

# アプリケーション起動時の登録
$container = [ServiceContainer]::new()

$container.RegisterSingleton('Logger', {
    param($c)
    [Logger]::new("TcpDebugger.log")
})

$container.RegisterSingleton('ConnectionService', {
    param($c)
    $logger = $c.Resolve('Logger')
    [ConnectionService]::new($logger)
})

$container.RegisterSingleton('ReceivedEventPipeline', {
    param($c)
    $logger = $c.Resolve('Logger')
    $ruleProcessor = $c.Resolve('RuleProcessor')
    [ReceivedEventPipeline]::new($logger, $ruleProcessor)
})

# 使用例
$connectionService = $container.Resolve('ConnectionService')
$connectionService.StartConnection($connectionId)
```

---

## 3. 段階的な移行計画

### フェーズ0: 準備（リスクなし）

**目的:** 既存機能を壊さずに、新しいアーキテクチャの基盤を構築

**作業内容:**

1. **新モジュールの作成**
   - `Core/Common/Logger.ps1` - 構造化ログ
   - `Core/Common/ErrorHandler.ps1` - エラーハンドリング統一
   - `Core/Domain/VariableScope.ps1` - スレッドセーフな変数管理
   - `Core/Infrastructure/ServiceContainer.ps1` - DI コンテナ

2. **ユニットテスト環境の構築**
   - `Tests/` フォルダ作成
   - Pester テストフレームワーク導入
   - 基本的なテストケース作成

3. **ドキュメント整備**
   - モジュール責務マトリクス作成
   - API リファレンス生成

**完了基準:**
- 既存コードに一切変更なし
- 新モジュールが単独でテスト可能
- CI/CD パイプライン構築

### フェーズ1: 受信イベントパイプラインの修正（高優先度）

**目的:** 現在動作していない受信イベント処理を修正

**作業内容:**

1. **即座の修正（バグフィックス）**
   
   `TcpClient.ps1` の修正:
   ```powershell
   # 修正前（バグ）
   Invoke-ConnectionAutoResponse -ConnectionId $connId -ReceivedData $receivedData
   if ($stream.DataAvailable) {
       $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
       if ($bytesRead -gt 0) {
           $receivedData = $buffer[0..($bytesRead-1)]
           # ...
       }
   }
   
   # 修正後
   if ($stream.DataAvailable) {
       $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
       if ($bytesRead -gt 0) {
           $receivedData = $buffer[0..($bytesRead-1)]
           
           # 受信バッファに追加
           [void]$conn.RecvBuffer.Add(...)
           
           # 統合イベント処理を呼び出し
           Invoke-ReceivedEvent -ConnectionId $connId -ReceivedData $receivedData
           
           $conn.LastActivity = Get-Date
       }
   }
   ```
   
   同様の修正を `TcpServer.ps1`, `UdpCommunication.ps1` にも適用

2. **ReceivedEventPipeline の強化**
   ```powershell
   # ReceivedEventPipeline.ps1 (新規作成)
   class ReceivedEventPipeline {
       [Logger]$Logger
       [RuleProcessor]$RuleProcessor
       
       [void] ProcessReceivedData([string]$connectionId, [byte[]]$data) {
           # ログ記録
           $this.Logger.LogReceive($connectionId, $data)
           
           # 接続取得
           $conn = $this.GetConnection($connectionId)
           if (-not $conn) { return }
           
           # ルール処理（AutoResponse + OnReceived 統合）
           $this.RuleProcessor.ProcessRules($conn, $data)
       }
   }
   ```

**完了基準:**
- OnReceived プロファイルが正しく動作
- AutoResponse が受信後に正しく実行される
- 統合形式（Unified）ルールが完全動作

**リスク評価:** 低
- 既存の動いている部分への影響最小
- バグ修正が主体

### フェーズ2: 接続管理の改善（中優先度）

**目的:** スレッドセーフな接続管理とライフサイクル制御

**作業内容:**

1. **ConnectionService の導入**
   ```powershell
   class ConnectionService {
       hidden [hashtable]$_connections
       hidden [Logger]$_logger
       hidden [object]$_lock = [object]::new()
       
       ConnectionService([Logger]$logger) {
           $this._connections = [System.Collections.Hashtable]::Synchronized(@{})
           $this._logger = $logger
       }
       
       [ManagedConnection] GetConnection([string]$id) {
           return $this._connections[$id]
       }
       
       [void] AddConnection([ConnectionConfiguration]$config) {
           [System.Threading.Monitor]::Enter($this._lock)
           try {
               if ($this._connections.ContainsKey($config.Id)) {
                   throw "Connection already exists: $($config.Id)"
               }
               
               $conn = [ManagedConnection]::new($config)
               $this._connections[$config.Id] = $conn
               $this._logger.LogInfo("Connection added: $($config.Id)")
           }
           finally {
               [System.Threading.Monitor]::Exit($this._lock)
           }
       }
       
       [void] StartConnection([string]$id) {
           $conn = $this.GetConnection($id)
           if (-not $conn) {
               throw "Connection not found: $id"
           }
           
           $conn.Adapter.Start()
           $conn.State.SetStatus("CONNECTED")
           $this._logger.LogInfo("Connection started: $id")
       }
   }
   ```

2. **段階的な移行**
   - 新規接続は `ConnectionService` を使用
   - 既存コードは `$Global:Connections` を経由して `ConnectionService` にアクセス
   - 徐々に直接アクセスを置き換え

**完了基準:**
- すべての接続操作が ConnectionService 経由
- スレッド安全性の問題がゼロ
- 既存機能の動作確認

### フェーズ3: メッセージ処理の統合（中優先度）

**目的:** 重複したメッセージ処理ロジックの統合

**作業内容:**

1. **MessageProcessor の統合**
   ```powershell
   class MessageProcessor {
       [TemplateRepository]$TemplateRepo
       [Logger]$Logger
       
       [byte[]] ProcessTemplate([string]$templatePath, [hashtable]$variables) {
           # テンプレート読み込み（キャッシュ付き）
           $template = $this.TemplateRepo.GetTemplate($templatePath)
           
           # 変数展開
           $expanded = $this.ExpandVariables($template, $variables)
           
           # バイト配列に変換
           return $this.ConvertToBytes($expanded, $template.Encoding)
       }
   }
   ```

2. **ルール処理の統合**
   - `AutoResponse.ps1`, `OnReceivedHandler.ps1` のロジックを `RuleProcessor` に集約
   - キャッシュ管理を `RuleRepository` に一元化

**完了基準:**
- 重複コードが完全に排除
- キャッシュヒット率の可視化
- パフォーマンステスト完了

### フェーズ4: UI層の改善（低優先度）

**目的:** MVVM パターンの適用とデータバインディングの改善

**作業内容:**

1. **ViewModel の導入**
   ```powershell
   class ConnectionViewModel {
       [string]$Id
       [string]$DisplayName
       [string]$Status
       [ObservableCollection]$AvailableProfiles
       [string]$SelectedProfile
       
       # INotifyPropertyChanged 相当の実装
   }
   ```

2. **UI更新の非同期化**
   - UI スレッドと通信スレッドの完全分離
   - `Invoke` を使った安全な UI 更新

**完了基準:**
- UI がフリーズしない
- 接続状態がリアルタイムに反映
- 応答性の向上

---

## 4. 実装ガイドライン

### 4.1 コーディング規約

**PowerShell クラス設計:**

```powershell
# 良い例
class GoodExample {
    # プライベートフィールドは hidden + アンダースコア
    hidden [Logger]$_logger
    
    # パブリックプロパティは読み取り専用
    [string]$Id
    
    # コンストラクタで依存性注入
    GoodExample([Logger]$logger, [string]$id) {
        $this._logger = $logger
        $this.Id = $id
    }
    
    # メソッドは動詞-名詞形式
    [void] ProcessData([byte[]]$data) {
        try {
            # 処理
        }
        catch {
            $this._logger.LogError("ProcessData failed", $_)
            throw
        }
    }
}

# 悪い例
class BadExample {
    $Logger  # 型指定なし
    [string]$Id  # ミュータブル
    
    BadExample() {
        $this.Logger = Get-GlobalLogger  # グローバル依存
    }
    
    [void] DoStuff($data) {  # 型指定なし、曖昧な名前
        # エラーハンドリングなし
    }
}
```

**関数設計:**

```powershell
# 良い例
function Invoke-MessageProcessing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [byte[]]$Data,
        
        [Parameter(Mandatory=$false)]
        [MessageProcessor]$Processor = $script:DefaultProcessor
    )
    
    begin {
        $ErrorActionPreference = 'Stop'
        Write-Verbose "Processing message for connection: $ConnectionId"
    }
    
    process {
        try {
            $result = $Processor.Process($ConnectionId, $Data)
            return $result
        }
        catch {
            Write-Error "Message processing failed: $_"
            throw
        }
    }
}
```

### 4.2 エラーハンドリング戦略

**3層エラーハンドリング:**

```powershell
# Layer 1: Infrastructure (低レベルエラー)
class TcpClientAdapter {
    [void] Send([byte[]]$data) {
        try {
            $this._socket.Send($data)
        }
        catch [System.Net.Sockets.SocketException] {
            # ソケット固有のエラーをビジネス例外に変換
            throw [CommunicationException]::new(
                "Failed to send data",
                $_.Exception
            )
        }
    }
}

# Layer 2: Domain (ビジネスロジックエラー)
class ConnectionService {
    [void] StartConnection([string]$id) {
        $conn = $this.GetConnection($id)
        if (-not $conn) {
            # ビジネスルール違反
            throw [InvalidOperationException]::new(
                "Connection not found: $id"
            )
        }
        
        try {
            $conn.Adapter.Start()
        }
        catch [CommunicationException] {
            # インフラエラーをログして再スロー
            $this._logger.LogError("Connection start failed", $id, $_.Exception)
            throw
        }
    }
}

# Layer 3: Application/UI (ユーザー向けエラー)
function Start-ConnectionFromUI {
    param([string]$ConnectionId)
    
    try {
        $connectionService.StartConnection($ConnectionId)
        Show-SuccessMessage "Connection started successfully"
    }
    catch [InvalidOperationException] {
        Show-ErrorMessage "Connection does not exist. Please refresh the list."
    }
    catch [CommunicationException] {
        Show-ErrorMessage "Failed to establish connection. Check network settings."
    }
    catch {
        Show-ErrorMessage "An unexpected error occurred: $($_.Exception.Message)"
    }
}
```

### 4.3 ログ戦略

**構造化ログの実装:**

```powershell
class Logger {
    hidden [string]$_logPath
    hidden [object]$_lock = [object]::new()
    
    [void] LogInfo([string]$message, [hashtable]$context = @{}) {
        $this.Log("INFO", $message, $context)
    }
    
    [void] LogError([string]$message, [Exception]$exception, [hashtable]$context = @{}) {
        $context['Exception'] = $exception.ToString()
        $context['StackTrace'] = $exception.StackTrace
        $this.Log("ERROR", $message, $context)
    }
    
    hidden [void] Log([string]$level, [string]$message, [hashtable]$context) {
        $entry = [PSCustomObject]@{
            Timestamp = (Get-Date).ToString("o")
            Level = $level
            Message = $message
            Context = $context
            ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }
        
        [System.Threading.Monitor]::Enter($this._lock)
        try {
            $json = $entry | ConvertTo-Json -Compress
            Add-Content -Path $this._logPath -Value $json
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }
    }
}

# 使用例
$logger.LogInfo("Connection started", @{
    ConnectionId = "conn-001"
    Protocol = "TCP"
    RemoteEndpoint = "192.168.1.100:8080"
})
```

### 4.4 テスト戦略

**ユニットテストの例（Pester）:**

```powershell
# Tests/Unit/Core/Domain/MessageProcessor.Tests.ps1
Describe 'MessageProcessor' {
    BeforeAll {
        # モックの準備
        $mockLogger = [PSCustomObject]@{
            LogInfo = { param($msg) }
            LogError = { param($msg, $ex) }
        }
        
        $mockTemplateRepo = [PSCustomObject]@{
            GetTemplate = { 
                param($path)
                return [PSCustomObject]@{
                    Format = "Test {var}"
                    Encoding = "UTF-8"
                }
            }
        }
        
        $processor = [MessageProcessor]::new($mockTemplateRepo, $mockLogger)
    }
    
    Context 'ProcessTemplate' {
        It 'Should expand variables correctly' {
            $variables = @{ var = "Value" }
            $result = $processor.ProcessTemplate("test.csv", $variables)
            
            $result | Should -Not -BeNullOrEmpty
            $resultString = [System.Text.Encoding]::UTF8.GetString($result)
            $resultString | Should -Be "Test Value"
        }
        
        It 'Should throw on missing template' {
            $mockTemplateRepo.GetTemplate = { throw "Not found" }
            
            { $processor.ProcessTemplate("missing.csv", @{}) } | Should -Throw
        }
    }
}
```

---

## 5. マイグレーションチェックリスト

### フェーズ1（受信イベント修正）

- [ ] `TcpClient.ps1` の受信処理を修正
- [ ] `TcpServer.ps1` の受信処理を修正
- [ ] `UdpCommunication.ps1` の受信処理を修正
- [ ] `ReceivedEventPipeline.ps1` を作成
- [ ] 統合テストで OnReceived 動作確認
- [ ] 統合形式ルールの動作確認
- [ ] 既存シナリオの回帰テスト

### フェーズ2（接続管理改善）

- [ ] `ConnectionConfiguration` クラス作成
- [ ] `ConnectionRuntimeState` クラス作成
- [ ] `ManagedConnection` クラス作成
- [ ] `ConnectionService` クラス作成
- [ ] `ServiceContainer` 作成
- [ ] 既存コードの段階的移行
- [ ] スレッド安全性のテスト
- [ ] パフォーマンステスト

### フェーズ3（メッセージ処理統合）

- [ ] `MessageProcessor` クラス作成
- [ ] `RuleProcessor` クラス作成
- [ ] `TemplateRepository` クラス作成
- [ ] `RuleRepository` クラス作成
- [ ] キャッシュロジックの統合
- [ ] 重複コードの削除
- [ ] パフォーマンステスト

### フェーズ4（UI改善）

- [ ] `ConnectionViewModel` 作成
- [ ] `UIUpdateService` 作成
- [ ] データバインディング実装
- [ ] 非同期UI更新の実装
- [ ] 応答性テスト

---

## 6. リスク管理

### 高リスク項目

1. **マルチスレッド処理の変更**
   - **リスク:** デッドロック、競合状態の発生
   - **軽減策:** 
     - 段階的な移行
     - 徹底したスレッドセーフティテスト
     - ロック範囲の最小化

2. **既存機能の破壊**
   - **リスク:** リファクタリングにより動作中の機能が停止
   - **軽減策:**
     - 包括的な回帰テストスイート
     - フィーチャーフラグによる段階的有効化
     - ロールバック計画

### 中リスク項目

1. **パフォーマンス劣化**
   - **リスク:** 抽象化層の追加によるオーバーヘッド
   - **軽減策:**
     - パフォーマンスベンチマークの継続実施
     - プロファイリングツールの使用
     - ホットパスの最適化

2. **学習曲線**
   - **リスク:** 新しいアーキテクチャの理解に時間がかかる
   - **軽減策:**
     - 詳細なドキュメント作成
     - サンプルコードの提供
     - ペアプログラミング

---

## 7. 期待される効果

### 品質面

- **バグ削減:** 現在動作していない OnReceived 機能の修正
- **安定性向上:** スレッドセーフティの徹底による競合状態の排除
- **保守性向上:** 責務の明確化により、バグの特定・修正が容易に

### 開発効率面

- **テスタビリティ:** ユニットテストカバレッジ 0% → 80%以上
- **拡張性:** 新機能追加時の影響範囲が限定的
- **可読性:** コードの意図が明確で、新規参加者のオンボーディングが容易

### パフォーマンス面

- **スループット:** キャッシュ最適化により 10-20% 向上見込み
- **応答性:** UI スレッドの分離により体感速度向上
- **リソース効率:** 不要なオブジェクト生成の削減

---

## 8. 参考資料

### 設計パターン

- **Repository パターン:** データアクセスロジックの抽象化
- **Service パターン:** ビジネスロジックのカプセル化
- **Dependency Injection:** 疎結合な設計
- **Event-Driven Architecture:** 非同期処理の制御
- **MVVM パターン:** UI とビジネスロジックの分離

### PowerShell ベストプラクティス

- [PowerShell Practice and Style Guide](https://poshcode.gitbook.io/powershell-practice-and-style/)
- [The PowerShell Best Practices and Style Guide](https://github.com/PoshCode/PowerShellPracticeAndStyle)

### アーキテクチャ参考文献

- Clean Architecture (Robert C. Martin)
- Domain-Driven Design (Eric Evans)
- Patterns of Enterprise Application Architecture (Martin Fowler)

---

## 9. 次のステップ

1. **本設計書のレビュー**
   - 関係者による設計レビュー
   - フィードバックの反映

2. **プロトタイプ作成**
   - フェーズ1の一部を試験的に実装
   - 技術的な実現可能性の検証

3. **詳細スケジュールの策定**
   - 各フェーズの工数見積もり
   - リソース配分

4. **キックオフ**
   - チーム全体での方針共有
   - 役割分担の決定

---

## 付録A: 主要クラス仕様

### A.1 ConnectionService

```powershell
<#
.SYNOPSIS
接続のライフサイクルを管理するコアサービス

.DESCRIPTION
スレッドセーフな接続管理を提供し、接続の作成・開始・停止・削除を統括する。
すべての接続操作はこのサービスを経由して行われる。
#>
class ConnectionService {
    # プライベートフィールド
    hidden [hashtable]$_connections
    hidden [Logger]$_logger
    hidden [object]$_lock
    
    # コンストラクタ
    ConnectionService([Logger]$logger) {
        $this._connections = [System.Collections.Hashtable]::Synchronized(@{})
        $this._logger = $logger
        $this._lock = [object]::new()
    }
    
    # パブリックメソッド
    [ManagedConnection] GetConnection([string]$id) { }
    [void] AddConnection([ConnectionConfiguration]$config) { }
    [void] RemoveConnection([string]$id) { }
    [void] StartConnection([string]$id) { }
    [void] StopConnection([string]$id) { }
    [ManagedConnection[]] GetAllConnections() { }
    [ManagedConnection[]] GetConnectionsByGroup([string]$group) { }
    [ManagedConnection[]] GetConnectionsByTag([string]$tag) { }
}
```

### A.2 ReceivedEventPipeline

```powershell
<#
.SYNOPSIS
受信イベントの統合処理パイプライン

.DESCRIPTION
すべての受信データはこのパイプラインを通過し、ルール処理・ログ記録・
イベント発火が統一的に行われる。
#>
class ReceivedEventPipeline {
    hidden [Logger]$_logger
    hidden [RuleProcessor]$_ruleProcessor
    
    ReceivedEventPipeline([Logger]$logger, [RuleProcessor]$ruleProcessor) {
        $this._logger = $logger
        $this._ruleProcessor = $ruleProcessor
    }
    
    [void] ProcessReceivedData([string]$connectionId, [byte[]]$data) {
        # 受信ログ記録
        $this._logger.LogReceive($connectionId, $data)
        
        # ルール処理（AutoResponse + OnReceived）
        $this._ruleProcessor.ProcessRules($connectionId, $data)
    }
}
```

### A.3 MessageProcessor

```powershell
<#
.SYNOPSIS
メッセージ処理の中核クラス

.DESCRIPTION
テンプレート展開、変数置換、エンコーディング変換など、
メッセージ処理に関するすべての機能を提供する。
#>
class MessageProcessor {
    hidden [TemplateRepository]$_templateRepo
    hidden [Logger]$_logger
    
    MessageProcessor([TemplateRepository]$templateRepo, [Logger]$logger) {
        $this._templateRepo = $templateRepo
        $this._logger = $logger
    }
    
    [byte[]] ProcessTemplate(
        [string]$templatePath,
        [hashtable]$variables
    ) {
        # テンプレート取得（キャッシュ付き）
        $template = $this._templateRepo.GetTemplate($templatePath)
        
        # 変数展開
        $expanded = $this.ExpandVariables($template.Format, $variables)
        
        # バイト配列に変換
        return $this.ConvertToBytes($expanded, $template.Encoding)
    }
    
    hidden [string] ExpandVariables([string]$format, [hashtable]$variables) { }
    hidden [byte[]] ConvertToBytes([string]$data, [string]$encoding) { }
}
```

---

## 付録B: 用語集

| 用語 | 定義 |
|------|------|
| **Connection** | TCP/UDP の物理的な接続。1つのソケットに対応 |
| **Instance** | 1つの通信インスタンス。フォルダ単位で管理される |
| **Profile** | Auto Response / OnReceived / Periodic Send の設定セット |
| **Rule** | 受信データに対するマッチング条件とアクション定義 |
| **Template** | 電文の雛形。変数展開機能を持つ |
| **Scenario** | 一連の送受信アクションを定義したCSVファイル |
| **Pipeline** | データが通過する処理の流れ |
| **Adapter** | 特定の通信プロトコルの実装を抽象化するクラス |
| **Repository** | データの永続化・取得を担当するクラス |
| **Service** | ビジネスロジックを提供するクラス |

---

**文書バージョン:** 1.0  
**作成日:** 2025-01-16  
**最終更新:** 2025-01-16  
**ステータス:** Draft - レビュー待ち
