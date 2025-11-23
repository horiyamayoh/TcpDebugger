# Runspace Migration Task List

## プロジェクト概要
- **目的**: PowerShellスレッドからRunspaceベースへの移行によるアプリケーション安定化
- **開始日**: 2025-11-19
- **予定工数**: 12-17時間
- **現在のステータス**: Phase 0 完了、Phase 1 準備中

---

## Phase 0: 準備・設計 ? 完了

### Task 0.1: 設計書作成 ?
- **担当**: Agent
- **期限**: 2025-11-19
- **状態**: 完了
- **成果物**: `RUNSPACE_MIGRATION_DESIGN.md`
- **詳細**: アーキテクチャ、コンポーネント設計、データフロー、移行手順を文書化

### Task 0.2: タスクリスト作成 ?
- **担当**: Agent
- **期限**: 2025-11-19
- **状態**: 完了
- **成果物**: `RUNSPACE_MIGRATION_TASKS.md` (本ファイル)
- **詳細**: 全フェーズのタスク定義、進捗管理フレームワーク構築

---

## Phase 1: 基盤実装 (2-3時間)

### Task 1.1: メッセージ型定義の実装 ?
- **担当**: Agent
- **予定工数**: 30分
- **状態**: 未着手
- **ファイル**: `Core/Domain/RunspaceMessages.ps1` (新規作成)
- **内容**:
  - [ ] `MessageType` enum定義
  - [ ] `RunspaceMessage` クラス実装
  - [ ] ヘルパー関数実装
    - [ ] `New-StatusUpdateMessage`
    - [ ] `New-DataReceivedMessage`
    - [ ] `New-ErrorMessage`
    - [ ] `New-ActivityMessage`
    - [ ] `New-LogMessage`
- **依存関係**: なし
- **検証方法**: メッセージ作成とプロパティ確認

### Task 1.2: メッセージキューの実装 ?
- **担当**: Agent
- **予定工数**: 30分
- **状態**: 未着手
- **ファイル**: `Core/Infrastructure/RunspaceMessageQueue.ps1` (新規作成)
- **内容**:
  - [ ] `RunspaceMessageQueue` クラス実装
  - [ ] `Enqueue()` メソッド
  - [ ] `TryDequeue()` メソッド
  - [ ] `GetCount()` メソッド
  - [ ] `Clear()` メソッド
- **依存関係**: Task 1.1
- **検証方法**: Enqueue/Dequeue動作確認

### Task 1.3: メッセージプロセッサの実装 ?
- **担当**: Agent
- **予定工数**: 1時間
- **状態**: 未着手
- **ファイル**: `Core/Infrastructure/RunspaceMessageProcessor.ps1` (新規作成)
- **内容**:
  - [ ] `RunspaceMessageProcessor` クラス実装
  - [ ] `ProcessMessages([int]$maxCount)` メソッド
  - [ ] `ProcessMessage([RunspaceMessage])` メソッド
  - [ ] 各メッセージタイプの処理ロジック
    - [ ] StatusUpdate
    - [ ] DataReceived
    - [ ] ErrorOccurred
    - [ ] ActivityMarker
    - [ ] SocketUpdate
    - [ ] LogMessage
- **依存関係**: Task 1.2
- **検証方法**: 各メッセージタイプの処理確認

### Task 1.4: ServiceContainerへの登録 ?
- **担当**: Agent
- **予定工数**: 30分
- **状態**: 未着手
- **ファイル**: `TcpDebugger.ps1` (変更)
- **内容**:
  - [ ] `RunspaceMessageQueue` のシングルトン登録
  - [ ] `MessageProcessor` のシングルトン登録
  - [ ] グローバル変数 `$Global:MessageProcessor` の設定
- **依存関係**: Task 1.3
- **検証方法**: DIコンテナからの解決確認

---

## Phase 2: TcpClientAdapter移行 (3-4時間)

### Task 2.1: TcpClientAdapter (Runspace版) 実装 ?
- **担当**: Agent
- **予定工数**: 2時間
- **状態**: 未着手
- **ファイル**: `Core/Infrastructure/Adapters/TcpClientAdapter.ps1` (大幅変更)
- **内容**:
  - [ ] コンストラクタに `MessageQueue` パラメータ追加
  - [ ] `Start()` メソッドのRunspace実装
    - [ ] `System.Threading.Thread` の削除
    - [ ] `[PowerShell]::Create()` の使用
    - [ ] Runspaceの初期化
    - [ ] ScriptBlockの準備
    - [ ] 変数の設定 (`ConnectionId`, `RemoteIP`, `MessageQueue` など)
    - [ ] `BeginInvoke()` の呼び出し
    - [ ] Runspace/PowerShell/AsyncHandleの保存
  - [ ] `Stop()` メソッドの更新
    - [ ] `PowerShell.Stop()` の呼び出し
    - [ ] `EndInvoke()` の呼び出し
    - [ ] Runspace/PowerShellのDispose
  - [ ] ScriptBlock内の実装
    - [ ] 接続処理
    - [ ] 送受信ループ
    - [ ] メッセージキューへの送信
    - [ ] エラーハンドリング
    - [ ] クリーンアップ処理
- **依存関係**: Task 1.4
- **検証方法**: 単一TCP接続での送受信テスト

### Task 2.2: 接続オブジェクトの変更対応 ?
- **担当**: Agent
- **予定工数**: 30分
- **状態**: 未着手
- **ファイル**: `Core/Domain/ConnectionModels.ps1` (変更)
- **内容**:
  - [ ] `Variables` への Runspace関連オブジェクト保存の確認
    - `_Runspace`
    - `_PowerShell`
    - `_AsyncHandle`
  - [ ] 既存の `State.WorkerThread` との互換性確認
- **依存関係**: Task 2.1
- **検証方法**: オブジェクト保存・取得確認

### Task 2.3: UIメッセージタイマーの実装 ?
- **担当**: Agent
- **予定工数**: 30分
- **状態**: 未着手
- **ファイル**: `Presentation/UI/MainForm.ps1` (変更)
- **内容**:
  - [ ] メッセージ処理タイマーの追加 (100ms間隔)
  - [ ] `MessageProcessor.ProcessMessages()` の呼び出し
  - [ ] エラーハンドリング
  - [ ] フォームClose時のタイマー停止
- **依存関係**: Task 1.4
- **検証方法**: メッセージ処理ログの確認

### Task 2.4: TcpClientAdapter統合テスト ?
- **担当**: Agent
- **予定工数**: 1時間
- **状態**: 未着手
- **テストケース**:
  - [ ] TCP Client接続成功
  - [ ] データ受信
  - [ ] データ送信
  - [ ] 接続切断
  - [ ] エラー発生時の動作
  - [ ] 複数接続の同時動作
- **検証方法**: Exampleインスタンスでの実機テスト
- **成功基準**: 5分以上クラッシュせず動作

---

## Phase 3: 残りのAdapter移行 (2-3時間)

### Task 3.1: TcpServerAdapter (Runspace版) 実装 ?
- **担当**: Agent
- **予定工数**: 1.5時間
- **状態**: 未着手
- **ファイル**: `Core/Infrastructure/Adapters/TcpServerAdapter.ps1` (大幅変更)
- **内容**:
  - [ ] TcpClientAdapterと同様のRunspace実装
  - [ ] リスナー起動処理
  - [ ] クライアント接続待機ループ
  - [ ] シングル接続モードの維持
  - [ ] メッセージキュー統合
- **依存関係**: Task 2.4
- **検証方法**: TCP Server接続での送受信テスト

### Task 3.2: UdpAdapter (Runspace版) 実装 ?
- **担当**: Agent
- **予定工数**: 1時間
- **状態**: 未着手
- **ファイル**: `Core/Infrastructure/Adapters/UdpAdapter.ps1` (大幅変更)
- **内容**:
  - [ ] Runspace実装
  - [ ] UDP送受信処理
  - [ ] ブロードキャスト対応
  - [ ] メッセージキュー統合
- **依存関係**: Task 3.1
- **検証方法**: UDP送受信テスト

### Task 3.3: 全Adapter統合テスト ?
- **担当**: Agent
- **予定工数**: 30分
- **状態**: 未着手
- **テストケース**:
  - [ ] TCP Client動作確認
  - [ ] TCP Server動作確認
  - [ ] UDP動作確認
  - [ ] 複数種類のAdapterの同時動作
- **検証方法**: Exampleインスタンスでの実機テスト

---

## Phase 4: クリーンアップ・最適化 (1-2時間)

### Task 4.1: 古いスレッドコードの削除 ?
- **担当**: Agent
- **予定工数**: 30分
- **状態**: 未着手
- **対象ファイル**:
  - `ConnectionManager.ps1`
  - `ConnectionModels.ps1`
- **内容**:
  - [ ] `System.Threading.Thread` 関連コードの削除
  - [ ] `State.WorkerThread` の削除（不要な場合）
  - [ ] `CancellationTokenSource` の使い方見直し
  - [ ] 不要なロック機構の削除
- **依存関係**: Task 3.3
- **検証方法**: Grep検索で残存コード確認

### Task 4.2: ログメッセージの統一 ?
- **担当**: Agent
- **予定工数**: 30分
- **状態**: 未着手
- **内容**:
  - [ ] Runspace内のログをメッセージ経由に変更
  - [ ] Adapter内のログレベル確認
  - [ ] ログコンテキスト情報の統一
- **依存関係**: Task 4.1
- **検証方法**: ログファイル確認

### Task 4.3: パフォーマンステスト ?
- **担当**: Agent
- **予定工数**: 30分
- **状態**: 未着手
- **テストケース**:
  - [ ] 長時間稼働テスト（1時間）
  - [ ] 高頻度接続・切断テスト（100回）
  - [ ] 大量データ送受信テスト（10MB+）
  - [ ] CPU/メモリ使用率の監視
- **検証方法**: Task Managerでのリソース監視
- **成功基準**: クラッシュなし、メモリリークなし

---

## Phase 5: ドキュメント・リリース (1時間)

### Task 5.1: 設計書の更新 ?
- **担当**: Agent
- **予定工数**: 20分
- **状態**: 未着手
- **ファイル**: `RUNSPACE_MIGRATION_DESIGN.md`
- **内容**:
  - [ ] 実装時の変更点の反映
  - [ ] 最終的なコード例の追加
  - [ ] トラブルシューティング情報の追加
- **依存関係**: Task 4.3
- **検証方法**: レビュー

### Task 5.2: README更新 ?
- **担当**: Agent
- **予定工数**: 20分
- **状態**: 未着手
- **ファイル**: `README.md`
- **内容**:
  - [ ] アーキテクチャセクションの更新
  - [ ] 動作環境の確認
  - [ ] トラブルシューティングの追加
- **依存関係**: Task 5.1
- **検証方法**: レビュー

### Task 5.3: 最終動作確認 ?
- **担当**: Agent + User
- **予定工数**: 20分
- **状態**: 未着手
- **内容**:
  - [ ] 全シナリオの動作確認
  - [ ] 既知の問題の文書化
  - [ ] リリースノートの作成
- **依存関係**: Task 5.2
- **検証方法**: ユーザー承認

---

## 進捗管理

### ステータス凡例
- ? **完了**: タスク終了、検証済み
- ? **進行中**: 現在実装・テスト中
- ? **未着手**: まだ開始していない
- ?? **ブロック**: 依存関係により停止中
- ? **失敗**: 実装失敗、再検討必要

### 全体進捗

| Phase | タスク数 | 完了 | 進行中 | 未着手 | 進捗率 |
|-------|---------|------|--------|--------|--------|
| Phase 0 | 2 | 2 | 0 | 0 | 100% |
| Phase 1 | 4 | 0 | 0 | 4 | 0% |
| Phase 2 | 4 | 0 | 0 | 4 | 0% |
| Phase 3 | 3 | 0 | 0 | 3 | 0% |
| Phase 4 | 3 | 0 | 0 | 3 | 0% |
| Phase 5 | 3 | 0 | 0 | 3 | 0% |
| **合計** | **19** | **2** | **0** | **17** | **11%** |

### マイルストーン

- **M1: 基盤完成** (Phase 1終了) - 目標: 2025-11-19 EOD
- **M2: 最初のAdapter移行** (Phase 2終了) - 目標: 2025-11-20 EOD
- **M3: 全Adapter移行** (Phase 3終了) - 目標: 2025-11-21 EOD
- **M4: リリース準備完了** (Phase 5終了) - 目標: 2025-11-22 EOD

---

## リスク管理

### 識別されたリスク

1. **Runspace作成のオーバーヘッド** (中)
   - 影響: パフォーマンス低下
   - 対策: 初期テストで許容範囲か確認、必要なら将来的にRunspace Pool導入
   - 責任者: Agent
   - ステータス: 監視中

2. **メッセージ処理の遅延** (中)
   - 影響: UI更新の遅れ
   - 対策: タイマー間隔とメッセージ処理数の調整
   - 責任者: Agent
   - ステータス: 監視中

3. **デバッグの複雑化** (低)
   - 影響: トラブルシューティングが困難
   - 対策: 詳細なログ出力、メッセージフロー図の作成
   - 責任者: Agent
   - ステータス: 対策済み（設計書に記載）

4. **既存機能の破壊** (高)
   - 影響: ReceivedEventPipeline、RuleEngine等が動作しなくなる
   - 対策: 段階的移行、各Phaseでの動作確認
   - 責任者: Agent + User
   - ステータス: 対策計画済み

---

## 変更履歴

| 日付 | バージョン | 変更内容 | 担当 |
|------|-----------|---------|------|
| 2025-11-19 | 1.0 | 初版作成 | Agent |

---

## 次のアクション

**次にやること**: Task 1.1 - メッセージ型定義の実装

**ユーザーへの確認事項**:
1. この設計とタスク分割で問題ないか？
2. 実装を開始してよいか？
3. Phase 1から順番に進めていく方針でよいか？

**準備完了**:
- ? 設計書作成完了
- ? タスクリスト作成完了
- ? ユーザー承認待ち
