# TcpDebugger アーキテクチャガイド

## 概要

TcpDebuggerは、TCP/UDP通信のテスト・デバッグを行うためのPowerShellベースの試験装置です。
このドキュメントでは、アプリケーションのアーキテクチャ設計、レイヤー構造、および開発ガイドラインを説明します。

## アーキテクチャ原則

### 1. レイヤードアーキテクチャ

本アプリケーションは以下の4層構造を採用しています：

```
┌─────────────────────────────────────┐
│   Presentation Layer (UI)           │  ← ユーザーインターフェース
├─────────────────────────────────────┤
│   Application Layer (Use Cases)     │  ← ビジネスロジックの調整
├─────────────────────────────────────┤
│   Domain Layer (Business Logic)     │  ← コアビジネスロジック
├─────────────────────────────────────┤
│   Infrastructure Layer (Adapters)   │  ← 外部システム連携
└─────────────────────────────────────┘
```

### 2. 依存性注入 (DI: Dependency Injection)

すべての主要なサービスは`ServiceContainer`を通じて管理され、依存関係は明示的に注入されます。

**推奨**: グローバル変数への直接アクセスを避け、常にServiceContainerまたはパラメータ経由で依存関係を取得してください。

```powershell
# ❌ 悪い例: グローバル変数への直接アクセス
function Start-Connection {
    $service = $Global:ConnectionService
    # ...
}

# ✅ 良い例: DIコンテナ経由でサービスを取得
function Start-Connection {
    param(
        [string]$ConnectionId,
        [ServiceContainer]$Container = $Global:ServiceContainer
    )
    
    $service = $Container.Resolve('ConnectionService')
    # ...
}
```

### 3. エラーハンドリング戦略

カスタム例外クラスを使用して、レイヤーごとに適切なエラーハンドリングを行います。

#### 例外クラスの種類

| 例外クラス | 用途 | 発生レイヤー |
|-----------|------|-------------|
| `ApplicationException` | ビジネスロジックエラー、検証エラー | Application Layer |
| `DomainException` | ドメインルール違反、状態遷移エラー | Domain Layer |
| `InfrastructureException` | 外部システム連携エラー、I/Oエラー | Infrastructure Layer |
| `ConnectionException` | TCP/UDP接続エラー | Infrastructure Layer |
| `ValidationException` | 入力値検証エラー | Application Layer |
| `ConfigurationException` | 設定ファイルエラー | Application Layer |

#### 例外の使用例

```powershell
# 接続が見つからない場合
if (-not $connection) {
    throw [ApplicationException]::new(
        "Connection not found: $ConnectionId",
        "CONNECTION_NOT_FOUND",
        @{ ConnectionId = $ConnectionId }
    )
}

# TCP接続エラー
try {
    $tcpClient.Connect($RemoteIP, $RemotePort)
}
catch {
    throw [ConnectionException]::new(
        "Failed to connect to ${RemoteIP}:${RemotePort}",
        $ConnectionId,
        "TCP_CONNECT_FAILED"
    )
}

# 設定ファイルエラー
if (-not (Test-Path $configPath)) {
    throw [ConfigurationException]::new(
        "Configuration file not found",
        $configPath
    )
}
```

## レイヤー詳細

### Presentation Layer (プレゼンテーション層)

**場所**: `Presentation/`

**責務**:
- ユーザーインターフェースの表示
- ユーザー入力の受付
- Application Layerへのリクエスト送信

**主要コンポーネント**:
- `MainForm.ps1`: メインウィンドウ定義
- `ViewBuilder.ps1`: UIコンポーネントビルダー

**ルール**:
- UIコードはビジネスロジックを含まない
- Application Layerの関数を呼び出すのみ
- Domain Layerに直接アクセスしない

### Application Layer (アプリケーション層)

**場所**: `Core/Application/`

**責務**:
- ユースケースの実装
- ビジネスロジックの調整（オーケストレーション）
- トランザクション管理

**主要コンポーネント**:
- `InstanceManager.ps1`: インスタンス管理のユースケース
- `ConnectionManager.ps1`: 接続管理のユースケース
- `NetworkAnalyzer.ps1`: ネットワーク診断のユースケース

**ルール**:
- Domain Layerのサービスを組み合わせてユースケースを実現
- Infrastructure Layerに直接依存しない（Domain経由でアクセス）
- UIに関する知識を持たない

### Domain Layer (ドメイン層)

**場所**: `Core/Domain/`

**責務**:
- コアビジネスロジック
- ドメインモデルの定義
- ビジネスルールの実装

**主要コンポーネント**:
- `ConnectionService.ps1`: 接続エンティティ管理
- `ConnectionModels.ps1`: 接続ドメインモデル
- `MessageService.ps1`: メッセージ送受信ロジック
- `ProfileService.ps1`: プロファイル管理
- `ReceivedEventPipeline.ps1`: 受信イベント処理パイプライン
- `RuleProcessor.ps1`: ルール処理エンジン

**ルール**:
- フレームワークや外部ライブラリに依存しない
- ビジネスロジックのみに集中
- Infrastructure Layerを抽象化されたインターフェース経由で使用

### Infrastructure Layer (インフラストラクチャ層)

**場所**: `Core/Infrastructure/`

**責務**:
- 外部システムとの連携
- データ永続化
- ネットワーク通信の実装

**主要コンポーネント**:
- `Adapters/TcpClientAdapter.ps1`: TCPクライアント通信
- `Adapters/TcpServerAdapter.ps1`: TCPサーバー通信
- `Adapters/UdpAdapter.ps1`: UDP通信
- `Repositories/InstanceRepository.ps1`: インスタンス設定の永続化
- `Repositories/ProfileRepository.ps1`: プロファイル設定の永続化
- `ServiceContainer.ps1`: DIコンテナ

**ルール**:
- 技術的な詳細はこのレイヤーに隠蔽
- Domain Layerに依存してもよい
- Presentation Layerに依存しない

## 共通コンポーネント

### Common Layer (共通層)

**場所**: `Core/Common/`

**責務**:
- 全レイヤーで共通に使用されるユーティリティ
- ロギング、エラーハンドリングなどの横断的関心事

**主要コンポーネント**:
- `ConsoleOutput.ps1`: コンソール出力機能
- `Logger.ps1`: ロギング機能
- `ErrorHandler.ps1`: エラーハンドリング
- `Exceptions.ps1`: カスタム例外クラス
- `ThreadSafeCollections.ps1`: スレッドセーフコレクション

## サービス登録

`TcpDebugger.ps1`でServiceContainerにサービスを登録します：

```powershell
# シングルトン登録 (アプリケーション全体で1つのインスタンス)
$script:ServiceContainer.RegisterSingleton('ConnectionService', {
    param($c)
    $logger = $c.Resolve('Logger')
    [ConnectionService]::new($logger, $Global:Connections)
})

# トランジェント登録 (呼び出しごとに新しいインスタンス)
$script:ServiceContainer.RegisterTransient('TcpClientAdapter', {
    param($c)
    $connectionService = $c.Resolve('ConnectionService')
    $pipeline = $c.Resolve('ReceivedEventPipeline')
    $logger = $c.Resolve('Logger')
    $messageQueue = $c.Resolve('RunspaceMessageQueue')
    [TcpClientAdapter]::new($connectionService, $pipeline, $logger, $messageQueue)
})
```

## データフロー

### 接続開始のフロー例

```
User Action (MainForm.ps1)
    ↓
Start-Connection (ConnectionManager.ps1) ← Application Layer
    ↓
ConnectionService.GetConnection() ← Domain Layer
    ↓
TcpClientAdapter.Start() ← Infrastructure Layer
    ↓
Runspace で TCP接続処理
    ↓
RunspaceMessageQueue にメッセージ送信
    ↓
MessageProcessor でメッセージ処理
    ↓
ReceivedEventPipeline でイベント処理
    ↓
UI更新 (MainForm.ps1)
```

### メッセージ送信のフロー例

```
User Input (MainForm.ps1)
    ↓
Send-Data (ConnectionManager.ps1) ← Application Layer
    ↓
MessageService.PrepareMessage() ← Domain Layer
    ↓
Connection.SendQueue に追加
    ↓
Adapter の送信ループで処理 ← Infrastructure Layer
```

## テスト戦略

### 単体テスト

各レイヤーのコンポーネントは独立してテスト可能です。

**テストの配置**: `Tests/Unit/<Layer>/<Component>.Tests.ps1`

**例**:
- `Tests/Unit/Core/Domain/ConnectionService.Tests.ps1`
- `Tests/Unit/Core/Common/Logger.Tests.ps1`

### モック

DIコンテナを使用することで、依存関係を簡単にモックできます：

```powershell
# テスト用のモックロガー
$mockLogger = [Logger]::new("TestDrive:\test.log", "Test", 10, 5, $false)

# テスト用のサービス
$service = [ConnectionService]::new($mockLogger, @{})
```

## ベストプラクティス

### 1. 依存関係は常に注入する

```powershell
# ❌ 悪い例
function ProcessData {
    $service = $Global:ConnectionService
    $logger = $Global:Logger
}

# ✅ 良い例
function ProcessData {
    param(
        [ConnectionService]$ConnectionService,
        [Logger]$Logger
    )
}
```

### 2. レイヤー境界を尊重する

```powershell
# ❌ 悪い例: UIがInfrastructureに直接アクセス
$btnConnect.Add_Click({
    $adapter = [TcpClientAdapter]::new(...)
    $adapter.Start($connectionId)
})

# ✅ 良い例: Application Layer経由
$btnConnect.Add_Click({
    Start-Connection -ConnectionId $connectionId
})
```

### 3. 適切な例外を使用する

```powershell
# ❌ 悪い例
throw "Connection not found"

# ✅ 良い例
throw [ApplicationException]::new(
    "Connection not found: $ConnectionId",
    "CONNECTION_NOT_FOUND",
    @{ ConnectionId = $ConnectionId }
)
```

### 4. ログを適切に記録する

```powershell
# 情報ログ
$logger.LogInfo("Connection started", @{
    ConnectionId = $connectionId
    RemoteEndpoint = "${remoteIP}:${remotePort}"
})

# エラーログ
$logger.LogError("Connection failed", $exception, @{
    ConnectionId = $connectionId
})
```

## 改善履歴

### 2025年11月実施

1. **$Global:Connectionsへの直接アクセス削除**
   - すべてのConnectionService経由のアクセスに変更
   - データアクセス層の一貫性を確保

2. **ConnectionManagerのレイヤー移動**
   - `Core/Domain/` → `Core/Application/`
   - Application Layerの責務を明確化

3. **グローバル変数の削減**
   - ServiceContainerを中心としたDIパターンに統一
   - UIヘルパー関数経由のアクセスパターンを導入

4. **カスタム例外クラスの導入**
   - `Exceptions.ps1`を作成
   - レイヤーごとに適切な例外クラスを定義

5. **MainFormViewModelの削除**
   - 未使用のコードを削除
   - コードベースの簡素化

6. **単体テストの追加**
   - `ConnectionService.Tests.ps1`を作成
   - テストカバレッジの向上

7. **命名規則の統一**
   - Auto Response → On Receive: Reply
   - On Received → On Receive: Script
   - Periodic Send → On Timer: Send
   - Quick Data → Manual: Send
   - Quick Action → Manual: Script
   
8. **GUIの改善**
   - モダンなカラースキーム適用
   - レスポンシブ対応（Anchor設定）
   - ツールチップ追加
   - ステータス表示機能追加

## 今後の改善計画

### Phase 2: アーキテクチャ整理

- [x] レイヤー境界の厳格化（一部完了）
- [x] UIからDomain Layerへの直接アクセスを排除（ヘルパー関数経由に移行）
- [x] Repositoryパターンの完全実装（InstanceRepository, ProfileRepository, RuleRepository）

### Phase 3: 品質向上

- [ ] テストカバレッジ80%以上を目標
- [ ] パフォーマンスプロファイリングと最適化
- [x] ドキュメント整備（ARCHITECTURE.md, GUI_IMPROVEMENTS.md, ReceivedRuleFormat.md等）
- [ ] CI/CDパイプラインの構築

## まとめ

本アーキテクチャガイドに従うことで、以下のメリットが得られます：

- **保守性**: レイヤー分離により変更の影響範囲が限定される
- **テスタビリティ**: DIにより各コンポーネントを独立してテスト可能
- **拡張性**: 新機能の追加が容易
- **可読性**: 責務が明確で理解しやすいコード

質問や提案がある場合は、プロジェクトのIssueまたはPull Requestでお知らせください。
