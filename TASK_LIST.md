# TcpDebugger リファクタリング作業タスク一覧

**最終更新:** 2025-01-16

このドキュメントは、ARCHITECTURE_REFACTORING.mdで提案されたリファクタリング計画の具体的な作業タスクを、進捗管理可能な形式で整理したものです。

---

## タスク管理の凡例

- ? **完了** - 実装・テスト完了
- ? **進行中** - 作業中
- ?? **保留中** - 他タスクの完了待ち
- ? **未着手** - まだ開始していない
- ?? **ブロック** - 問題により進行不可

---

## ? Phase 1: 緊急対応（Critical Path）

### ? Epic 1.1: 通信モジュールのアーキテクチャ移行

**目的:** $Global:Connectionsへの直接アクセスを排除し、新アーキテクチャに完全移行

#### Task 1.1.1: TcpClient のアダプター化 ?

**優先度:** P0 (最優先)  
**工数見積:** 8-12時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Core/Infrastructure/Adapters/TcpClientAdapter.ps1` を新規作成
2. [ ] `Modules/TcpClient.ps1` のロジックをクラス化して移植
3. [ ] コンストラクタで ConnectionService と ReceivedEventPipeline を注入
4. [ ] ServiceContainer への登録を追加
5. [ ] 既存の Start-TcpClient 関数を新アダプターのラッパーに変更

**実装例:**
```powershell
# Core/Infrastructure/Adapters/TcpClientAdapter.ps1
class TcpClientAdapter {
    hidden [ConnectionService]$_connectionService
    hidden [ReceivedEventPipeline]$_pipeline
    hidden [Logger]$_logger
    
    TcpClientAdapter(
        [ConnectionService]$connectionService,
        [ReceivedEventPipeline]$pipeline,
        [Logger]$logger
    ) {
        $this._connectionService = $connectionService
        $this._pipeline = $pipeline
        $this._logger = $logger
    }
    
    [void] Start([string]$connectionId) {
        $conn = $this._connectionService.GetConnection($connectionId)
        # ... 接続処理 ...
        
        # 受信時
        $this._pipeline.ProcessEvent($connectionId, $receivedData, $metadata)
    }
}
```

**完了基準:**
- [ ] TcpClientAdapter クラスが正常に動作
- [ ] $Global:Connections への参照がゼロ
- [ ] 既存のシナリオテストが全て通過

**依存関係:** なし

---

#### Task 1.1.2: TcpServer のアダプター化 ?

**優先度:** P0 (最優先)  
**工数見積:** 8-12時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Core/Infrastructure/Adapters/TcpServerAdapter.ps1` を新規作成
2. [ ] `Modules/TcpServer.ps1` のロジックをクラス化して移植
3. [ ] Task 1.1.1 と同様のパターンで実装
4. [ ] ServiceContainer への登録を追加
5. [ ] 既存の Start-TcpServer 関数を新アダプターのラッパーに変更

**完了基準:**
- [ ] TcpServerAdapter クラスが正常に動作
- [ ] $Global:Connections への参照がゼロ
- [ ] 既存のシナリオテストが全て通過

**依存関係:** Task 1.1.1 (パターン確立後に着手推奨)

---

#### Task 1.1.3: UDP のアダプター化 ?

**優先度:** P0 (最優先)  
**工数見積:** 8-12時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Core/Infrastructure/Adapters/UdpAdapter.ps1` を新規作成
2. [ ] `Modules/UdpCommunication.ps1` のロジックをクラス化して移植
3. [ ] Task 1.1.1 と同様のパターンで実装
4. [ ] ServiceContainer への登録を追加
5. [ ] 既存の Start-UdpCommunication 関数を新アダプターのラッパーに変更

**完了基準:**
- [ ] UdpAdapter クラスが正常に動作
- [ ] $Global:Connections への参照がゼロ
- [ ] 既存のシナリオテストが全て通過

**依存関係:** Task 1.1.1 (パターン確立後に着手推奨)

---

#### Task 1.1.4: ServiceContainer への通信アダプター登録 ?

**優先度:** P0 (最優先)  
**工数見積:** 2-4時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] TcpDebugger.ps1 の ServiceContainer 初期化部分を更新
2. [ ] 各アダプターを Transient または Singleton で登録
3. [ ] ファクトリ関数での依存性注入を実装

**実装例:**
```powershell
# TcpDebugger.ps1
$container.RegisterTransient('TcpClientAdapter', {
    param($c)
    $connectionService = $c.Resolve('ConnectionService')
    $pipeline = $c.Resolve('ReceivedEventPipeline')
    $logger = $c.Resolve('Logger')
    [TcpClientAdapter]::new($connectionService, $pipeline, $logger)
})
```

**完了基準:**
- [ ] すべての通信アダプターが ServiceContainer から取得可能
- [ ] 依存性が正しく注入されている

**依存関係:** Task 1.1.1, 1.1.2, 1.1.3

---

### ? Epic 1.2: 旧モジュールの非推奨化とラッパー化

**目的:** 新旧の二重アーキテクチャを解消し、段階的な移行を促進

#### Task 1.2.1: ReceivedEventHandler のラッパー化 ?

**優先度:** P1 (高)  
**工数見積:** 4-6時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Modules/ReceivedEventHandler.ps1` の `Invoke-ReceivedEvent` を ReceivedEventPipeline のラッパーに変更
2. [ ] 非推奨警告メッセージを追加
3. [ ] ドキュメントコメントに移行ガイドを記載

**実装例:**
```powershell
function Invoke-ReceivedEvent {
    [Obsolete("This function is deprecated. Use ReceivedEventPipeline directly via ServiceContainer.")]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,
        [Parameter(Mandatory=$true)]
        [byte[]]$ReceivedData
    )
    
    Write-Warning "[DEPRECATED] Invoke-ReceivedEvent is deprecated. Migrate to ReceivedEventPipeline."
    
    if ($Global:ReceivedEventPipeline) {
        $Global:ReceivedEventPipeline.ProcessEvent($ConnectionId, $ReceivedData, @{})
    } else {
        throw "ReceivedEventPipeline not initialized. Please update TcpDebugger.ps1."
    }
}
```

**完了基準:**
- [ ] 関数が ReceivedEventPipeline への薄いラッパーになっている
- [ ] 非推奨警告が表示される
- [ ] 既存の呼び出し元が動作する

**依存関係:** なし

---

#### Task 1.2.2: AutoResponse のラッパー化 ?

**優先度:** P1 (高)  
**工数見積:** 4-6時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Modules/AutoResponse.ps1` の各関数を RuleProcessor のラッパーに変更
2. [ ] 非推奨警告メッセージを追加
3. [ ] Read-AutoResponseRules を RuleRepository のラッパーに変更

**実装例:**
```powershell
function Invoke-ConnectionAutoResponse {
    [Obsolete("Use RuleProcessor via ReceivedEventPipeline instead.")]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,
        [Parameter(Mandatory=$true)]
        [byte[]]$ReceivedData
    )
    
    Write-Warning "[DEPRECATED] Invoke-ConnectionAutoResponse is deprecated. Use RuleProcessor."
    
    # RuleRepository 経由でルール取得
    $repository = Get-RuleRepository
    $conn = Get-ManagedConnection -ConnectionId $ConnectionId
    # ... 以下、RuleProcessor 呼び出しにリダイレクト
}
```

**完了基準:**
- [ ] 関数が RuleProcessor への薄いラッパーになっている
- [ ] 非推奨警告が表示される
- [ ] 既存の呼び出し元が動作する

**依存関係:** なし

---

#### Task 1.2.3: OnReceivedHandler のラッパー化 ?

**優先度:** P1 (高)  
**工数見積:** 4-6時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Modules/OnReceivedHandler.ps1` の各関数を RuleProcessor のラッパーに変更
2. [ ] 非推奨警告メッセージを追加
3. [ ] Read-OnReceivedRules を RuleRepository のラッパーに変更

**完了基準:**
- [ ] 関数が RuleProcessor への薄いラッパーになっている
- [ ] 非推奨警告が表示される
- [ ] 既存の呼び出し元が動作する

**依存関係:** なし

---

### ? Epic 1.3: MessageProcessor の実装

**目的:** テンプレート処理の統合と重複コードの削減

#### Task 1.3.1: MessageProcessor クラスの実装 ?

**優先度:** P0 (最優先)  
**工数見積:** 12-16時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Core/Domain/MessageProcessor.ps1` を作成
2. [ ] ARCHITECTURE_REFACTORING.md 付録A.3 の仕様に従って実装
3. [ ] 変数展開ロジックの実装
4. [ ] エンコーディング変換の実装
5. [ ] ユニットテストの作成

**実装すべきメソッド:**
```powershell
class MessageProcessor {
    [byte[]] ProcessTemplate([string]$templatePath, [hashtable]$variables)
    hidden [string] ExpandVariables([string]$format, [hashtable]$variables)
    hidden [byte[]] ConvertToBytes([string]$data, [string]$encoding)
    [string] FormatMessage([byte[]]$data, [string]$encoding)
}
```

**完了基準:**
- [ ] MessageProcessor クラスが設計書通りに動作
- [ ] ユニットテストがすべて通過
- [ ] 既存のテンプレート処理と同等の機能を提供

**依存関係:** Task 1.3.2 (並行作業可能)

---

#### Task 1.3.2: TemplateRepository の実装 ?

**優先度:** P0 (最優先)  
**工数見積:** 8-12時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Core/Infrastructure/Repositories/TemplateRepository.ps1` を作成
2. [ ] RuleRepository と同様のキャッシュ機構を実装
3. [ ] CSV形式のテンプレート読み込み
4. [ ] ファイル変更検知とキャッシュ無効化

**実装すべきメソッド:**
```powershell
class TemplateRepository {
    [TemplateDefinition] GetTemplate([string]$filePath)
    [void] ClearCache([string]$filePath)
    hidden [TemplateDefinition] TryGetCached([string]$key, [datetime]$lastWrite)
    hidden [void] SetCache([string]$key, [datetime]$lastWrite, [TemplateDefinition]$template)
}

class TemplateDefinition {
    [string]$Format
    [string]$Encoding
    [hashtable]$Metadata
}
```

**完了基準:**
- [ ] TemplateRepository が RuleRepository と同様に動作
- [ ] キャッシュ機能が正しく動作
- [ ] ユニットテストがすべて通過

**依存関係:** なし

---

#### Task 1.3.3: MessageProcessor の ServiceContainer 登録 ?

**優先度:** P1 (高)  
**工数見積:** 2-4時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] TcpDebugger.ps1 の ServiceContainer 初期化部分を更新
2. [ ] MessageProcessor を Singleton で登録
3. [ ] TemplateRepository を Singleton で登録

**実装例:**
```powershell
$container.RegisterSingleton('TemplateRepository', {
    param($c)
    $logger = $c.Resolve('Logger')
    [TemplateRepository]::new($logger)
})

$container.RegisterSingleton('MessageProcessor', {
    param($c)
    $templateRepo = $c.Resolve('TemplateRepository')
    $logger = $c.Resolve('Logger')
    [MessageProcessor]::new($templateRepo, $logger)
})
```

**完了基準:**
- [ ] MessageProcessor が ServiceContainer から取得可能
- [ ] 依存性が正しく注入されている

**依存関係:** Task 1.3.1, 1.3.2

---

#### Task 1.3.4: 既存のテンプレート処理を MessageProcessor に移行 ?

**優先度:** P1 (高)  
**工数見積:** 8-12時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Modules/MessageHandler.ps1` のテンプレート処理を MessageProcessor 呼び出しに変更
2. [ ] `Modules/QuickSender.ps1` のテンプレート処理を MessageProcessor 呼び出しに変更
3. [ ] `Modules/ScenarioEngine.ps1` のテンプレート処理を MessageProcessor 呼び出しに変更
4. [ ] 各モジュールで重複していたロジックを削除

**完了基準:**
- [ ] すべてのテンプレート処理が MessageProcessor 経由になっている
- [ ] 重複コードが削除されている
- [ ] 既存のシナリオテストが全て通過

**依存関係:** Task 1.3.1, 1.3.2, 1.3.3

---

## ? Phase 2: 重要改善（Important but not Urgent）

### ? Epic 2.1: エラーハンドリングの統一

#### Task 2.1.1: ErrorHandler クラスの実装 ?

**優先度:** P2 (中)  
**工数見積:** 8-12時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Core/Common/ErrorHandler.ps1` を作成
2. [ ] カスタム例外クラスの定義
   - CommunicationException
   - InvalidOperationException
   - ConfigurationException
3. [ ] 3層エラーハンドリング戦略の実装
4. [ ] エラーログの構造化

**実装例:**
```powershell
# カスタム例外
class CommunicationException : System.Exception {
    CommunicationException([string]$message) : base($message) {}
    CommunicationException([string]$message, [Exception]$inner) : base($message, $inner) {}
}

# ErrorHandler
class ErrorHandler {
    hidden [Logger]$_logger
    
    [void] HandleInfrastructureError([Exception]$ex, [hashtable]$context)
    [void] HandleDomainError([Exception]$ex, [hashtable]$context)
    [void] HandleApplicationError([Exception]$ex, [hashtable]$context)
}
```

**完了基準:**
- [ ] ErrorHandler クラスが正常に動作
- [ ] カスタム例外が定義されている
- [ ] ユニットテストがすべて通過

**依存関係:** なし

---

#### Task 2.1.2: 既存のエラー処理を ErrorHandler に移行 ?

**優先度:** P2 (中)  
**工数見積:** 12-16時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] 各通信アダプターのエラー処理を ErrorHandler 経由に変更
2. [ ] Domain層のエラー処理を ErrorHandler 経由に変更
3. [ ] Application層のエラー処理を ErrorHandler 経由に変更
4. [ ] 統一的なエラーハンドリングパターンを適用

**完了基準:**
- [ ] すべてのエラー処理が ErrorHandler 経由になっている
- [ ] エラーログが構造化されている
- [ ] try-catch のパターンが統一されている

**依存関係:** Task 2.1.1

---

### ? Epic 2.2: Repository の拡充

#### Task 2.2.1: ScenarioRepository の実装 ?

**優先度:** P2 (中)  
**工数見積:** 8-12時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Core/Infrastructure/Repositories/ScenarioRepository.ps1` を作成
2. [ ] シナリオCSVファイルの読み込み
3. [ ] キャッシュ機構の実装
4. [ ] ファイル変更検知

**実装すべきメソッド:**
```powershell
class ScenarioRepository {
    [ScenarioStep[]] GetScenario([string]$filePath)
    [void] ClearCache([string]$filePath)
}
```

**完了基準:**
- [ ] ScenarioRepository が正常に動作
- [ ] キャッシュ機能が正しく動作
- [ ] ユニットテストがすべて通過

**依存関係:** なし

---

#### Task 2.2.2: ConfigurationRepository の実装 ?

**優先度:** P3 (低)  
**工数見積:** 6-8時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Core/Infrastructure/Repositories/ConfigurationRepository.ps1` を作成
2. [ ] .psd1 形式の設定ファイル読み込み
3. [ ] 設定のバリデーション

**完了基準:**
- [ ] ConfigurationRepository が正常に動作
- [ ] 設定のバリデーションが機能する

**依存関係:** なし

---

### ? Epic 2.3: ユニットテストの拡充

#### Task 2.3.1: ConnectionService のテスト作成 ?

**優先度:** P2 (中)  
**工数見積:** 6-8時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Tests/Unit/Core/Domain/ConnectionService.Tests.ps1` を作成
2. [ ] 接続の追加・取得・削除のテスト
3. [ ] スレッド安全性のテスト
4. [ ] エラーケースのテスト

**完了基準:**
- [ ] コードカバレッジ 80% 以上
- [ ] すべてのテストが通過

**依存関係:** なし

---

#### Task 2.3.2: ReceivedEventPipeline のテスト作成 ?

**優先度:** P2 (中)  
**工数見積:** 6-8時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Tests/Unit/Core/Domain/ReceivedEventPipeline.Tests.ps1` を作成
2. [ ] イベント処理フローのテスト
3. [ ] RuleProcessor 連携のテスト
4. [ ] エラーケースのテスト

**完了基準:**
- [ ] コードカバレッジ 80% 以上
- [ ] すべてのテストが通過

**依存関係:** なし

---

#### Task 2.3.3: RuleProcessor のテスト作成 ?

**優先度:** P2 (中)  
**工数見積:** 8-12時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Tests/Unit/Core/Domain/RuleProcessor.Tests.ps1` を作成
2. [ ] ルールマッチングのテスト
3. [ ] AutoResponse / OnReceived 処理のテスト
4. [ ] Unified形式のテスト
5. [ ] エラーケースのテスト

**完了基準:**
- [ ] コードカバレッジ 80% 以上
- [ ] すべてのテストが通過

**依存関係:** なし

---

#### Task 2.3.4: MessageProcessor のテスト作成 ?

**優先度:** P2 (中)  
**工数見積:** 8-12時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Tests/Unit/Core/Domain/MessageProcessor.Tests.ps1` を作成
2. [ ] テンプレート展開のテスト
3. [ ] 変数置換のテスト
4. [ ] エンコーディング変換のテスト
5. [ ] エラーケースのテスト

**完了基準:**
- [ ] コードカバレッジ 80% 以上
- [ ] すべてのテストが通過

**依存関係:** Task 1.3.1 (MessageProcessor 実装後)

---

#### Task 2.3.5: 統合テストの作成 ?

**優先度:** P2 (中)  
**工数見積:** 12-16時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Tests/Integration/` フォルダを作成
2. [ ] 通信フローの統合テスト（TCP Client/Server, UDP）
3. [ ] シナリオ実行の統合テスト
4. [ ] 受信イベント処理の統合テスト

**完了基準:**
- [ ] 主要なユースケースが統合テストでカバーされている
- [ ] すべてのテストが通過

**依存関係:** Task 1.1.1, 1.1.2, 1.1.3

---

## ? Phase 3: 長期改善（Nice to have）

### ? Epic 3.1: UI層のMVVM化

#### Task 3.1.1: ConnectionViewModel の実装 ?

**優先度:** P3 (低)  
**工数見積:** 12-16時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Presentation/UI/ConnectionViewModel.ps1` を作成
2. [ ] INotifyPropertyChanged 相当の実装
3. [ ] データバインディング用プロパティの定義
4. [ ] コマンドハンドラーの実装

**完了基準:**
- [ ] ConnectionViewModel が正常に動作
- [ ] データバインディングが機能する

**依存関係:** なし

---

#### Task 3.1.2: UIUpdateService の実装 ?

**優先度:** P3 (低)  
**工数見積:** 8-12時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `Presentation/UI/UIUpdateService.ps1` を作成
2. [ ] UIスレッドでの安全な更新処理
3. [ ] Invoke パターンの統一化

**完了基準:**
- [ ] UI更新が非同期で安全に行われる
- [ ] UIがフリーズしない

**依存関係:** なし

---

#### Task 3.1.3: MainForm のリファクタリング ?

**優先度:** P3 (低)  
**工数見積:** 16-24時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] `UI/MainForm.ps1` をMVVMパターンに移行
2. [ ] ViewModel とのデータバインディング
3. [ ] イベントハンドラーの整理
4. [ ] UI更新ロジックの UIUpdateService への移行

**完了基準:**
- [ ] MainForm が MVVM パターンに従っている
- [ ] ビジネスロジックが ViewModel に移動している
- [ ] UI の応答性が向上している

**依存関係:** Task 3.1.1, 3.1.2

---

### ? Epic 3.2: インフラストラクチャの整備

#### Task 3.2.1: CI/CDパイプラインの構築 ?

**優先度:** P3 (低)  
**工数見積:** 8-12時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] GitHub Actions または Azure DevOps パイプラインの設定
2. [ ] 自動テスト実行の設定
3. [ ] コードカバレッジレポートの生成
4. [ ] 静的解析ツールの統合

**完了基準:**
- [ ] コミット時に自動テストが実行される
- [ ] カバレッジレポートが生成される
- [ ] 静的解析結果が表示される

**依存関係:** Task 2.3.x (テスト作成後)

---

#### Task 3.2.2: ドキュメント自動生成 ?

**優先度:** P3 (低)  
**工数見積:** 6-8時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] platyPS を使用した API リファレンス生成
2. [ ] モジュール責務マトリクスの作成
3. [ ] 移行ガイドの作成

**完了基準:**
- [ ] APIリファレンスが自動生成される
- [ ] ドキュメントが最新の状態に保たれる

**依存関係:** なし

---

### ? Epic 3.3: 旧モジュールの削除

#### Task 3.3.1: 非推奨モジュールの削除計画 ?

**優先度:** P3 (低)  
**工数見積:** 4-6時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] 削除対象モジュールのリストアップ
2. [ ] 依存関係の確認
3. [ ] 削除スケジュールの策定
4. [ ] ユーザーへの告知

**完了基準:**
- [ ] 削除計画が文書化されている
- [ ] 関係者に周知されている

**依存関係:** Task 1.2.x (ラッパー化完了後)

---

#### Task 3.3.2: 旧Modulesフォルダの段階的削除 ?

**優先度:** P3 (低)  
**工数見積:** 8-12時間  
**担当者:** _未割り当て_

**実装内容:**
1. [ ] 使用されていないモジュールから順次削除
2. [ ] 各削除後の動作確認
3. [ ] 最終的に Modules/ フォルダを Core/ に統合

**完了基準:**
- [ ] すべての旧モジュールが削除されている
- [ ] 新アーキテクチャのみが使用されている
- [ ] すべてのテストが通過している

**依存関係:** Task 3.3.1, および Phase 1, 2 のすべてのタスク

---

## ? 進捗トラッキング

### 全体進捗

| Phase | 総タスク数 | 完了 | 進行中 | 未着手 | 進捗率 |
|-------|-----------|------|--------|--------|--------|
| Phase 1 (緊急) | 13 | 0 | 0 | 13 | 0% |
| Phase 2 (重要) | 12 | 0 | 0 | 12 | 0% |
| Phase 3 (長期) | 7 | 0 | 0 | 7 | 0% |
| **合計** | **32** | **0** | **0** | **32** | **0%** |

### Epic別進捗

| Epic | 総タスク数 | 完了 | 進行中 | 未着手 | 進捗率 |
|------|-----------|------|--------|--------|--------|
| 1.1 通信モジュール移行 | 4 | 0 | 0 | 4 | 0% |
| 1.2 旧モジュール非推奨化 | 3 | 0 | 0 | 3 | 0% |
| 1.3 MessageProcessor実装 | 4 | 0 | 0 | 4 | 0% |
| 2.1 エラーハンドリング統一 | 2 | 0 | 0 | 2 | 0% |
| 2.2 Repository拡充 | 2 | 0 | 0 | 2 | 0% |
| 2.3 ユニットテスト拡充 | 5 | 0 | 0 | 5 | 0% |
| 3.1 UI層MVVM化 | 3 | 0 | 0 | 3 | 0% |
| 3.2 インフラ整備 | 2 | 0 | 0 | 2 | 0% |
| 3.3 旧モジュール削除 | 2 | 0 | 0 | 2 | 0% |

---

## ? 推奨される着手順序

### Week 1-2
1. Task 1.1.1: TcpClient のアダプター化
2. Task 1.3.1: MessageProcessor クラスの実装
3. Task 1.3.2: TemplateRepository の実装

### Week 3-4
4. Task 1.1.2: TcpServer のアダプター化
5. Task 1.1.3: UDP のアダプター化
6. Task 1.1.4: ServiceContainer への通信アダプター登録
7. Task 1.3.3: MessageProcessor の ServiceContainer 登録

### Week 5-6
8. Task 1.3.4: 既存のテンプレート処理を MessageProcessor に移行
9. Task 1.2.1, 1.2.2, 1.2.3: 旧モジュールのラッパー化
10. Task 2.1.1: ErrorHandler クラスの実装

### Week 7-8
11. Task 2.3.1-2.3.4: ユニットテストの拡充
12. Task 2.1.2: 既存のエラー処理を ErrorHandler に移行
13. Task 2.2.1: ScenarioRepository の実装

### Week 9 以降
14. Phase 3 のタスクに着手

---

## ? タスク管理のベストプラクティス

### タスクの開始時
- [ ] タスクの実装内容と完了基準を再確認
- [ ] 依存関係があるタスクが完了しているか確認
- [ ] ブランチを作成（例: `feature/task-1.1.1-tcpclient-adapter`）
- [ ] タスクステータスを「進行中?」に更新

### タスクの完了時
- [ ] 完了基準がすべて満たされているか確認
- [ ] ユニットテストを作成・実行
- [ ] コードレビューを依頼
- [ ] マージ後、タスクステータスを「完了?」に更新
- [ ] 進捗トラッキングテーブルを更新

### 週次レビュー
- [ ] 完了したタスクの振り返り
- [ ] ブロックされているタスクの確認
- [ ] 次週の計画立案
- [ ] 進捗率の更新

---

## ? 関連ドキュメント

- [ARCHITECTURE_REFACTORING.md](./ARCHITECTURE_REFACTORING.md) - リファクタリング設計書
- [REFACTORING_PROGRESS.md](./REFACTORING_PROGRESS.md) - 進捗レポート
- [DESIGN.md](./DESIGN.md) - 全体設計書
- [README.md](./README.md) - プロジェクト概要

---

**最終更新者:** GitHub Copilot  
**レビュー状態:** Draft - レビュー待ち
