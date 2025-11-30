# TCP/IP 試験装置 設計書

## 1. 概要

### 1.1 目的
TCP/UDP通信のテスト・デバッグを行うための試験装置を提供する。
設定ファイルベースでシナリオ実行が可能で、視覚的に接続状態を確認できるGUIを備える。

### 1.2 実行環境
- **OS**: Windows 10/11
- **実行環境**: PowerShell 5.1以降（追加インストール不要）
- **GUI**: Windows Forms (WinForms)。WPFはPoCレベルのオプションとし、安定版はWinFormsで提供。
- **前提条件**: .NET Framework（Windows標準搭載）

### 1.3 設計方針
- **送信第一主義 (Send-First Architecture)**: 本ツールは送信動作を最重要視し、ワンショット送信やデータ切替を最小アクションで行えるUI／APIを提供する。受信データは確認用の最小限表示に留める。
- **試験指向 (Test-Oriented)**: 再現性の高い試験シナリオとデータバンク方式での電文管理を実現し、現場作業者が即座に試験パターンを切り替えられることを重視する。
- **スケーラブル管理 (Scalable Instance Management)**: 10?20以上の通信インスタンスを論理グループ・タグで整理し、一貫した命名と一括制御を提供する。
- **1フォルダ=1インスタンス原則**: すべての通信インスタンスはフォルダ単位で管理し、設定・シナリオ・ログを完全に独立させる。
- **診断支援 (Diagnostic Support)**: ネットワーク疎通確認、ポート開放チェック、ルーティング確認を提供し、試験立ち上げ時の戸惑いを減らす。

### 1.4 競合ベンチマーク（Udome Socket Debugger）
> 公開情報および現場利用実態に基づく一般的な機能比較。詳細仕様が不明な箇所は推定を含む。

| 観点 | Udome Socket Debugger (推定) | 本設計の優位性 |
| --- | --- | --- |
| 接続数 | 単一 or 少数ソケットの手動切替 | 10?20以上を論理グループで同時運用、バルク操作可能 |
| 送信操作 | テキスト/HEX入力→ボタン送信 | データバンク方式でテンプレート即差し替え、ワンクリック送信 |
| シナリオ | スクリプト/マクロ限定 | CSVシナリオ＋PowerShell拡張、並列・条件・ループを簡潔記述 |
| 受信表示 | 詳細ログ／バイナリ表示 | シンプルな確認表示、Send-Firstに最適化 |
| 診断支援 | なし | Ping/Port/Routeチェック、推奨アクション提示 |
| UI/UX | 汎用デバッガUI | クイック送信、論理ビュー、シングルアクションで試験指向 |

本設計は既製品が得意とする手動デバッグ要素をカバーしつつ、試験治具として重要な「大量インスタンス管理」「送信テンプレートの即時切替」「性能/診断サポート」を追加することで、ユーザビリティと機能性の双方で上回ることを目標とする。

### 1.5 上位互換となる具体的機能
1. **データバンク＋ワンクリック送信**: よく使う電文をカテゴリ別に登録し、ドロップダウン選択またはボタン1クリックでワンショット送信。
2. **論理ビュー管理**: インスタンスを「用途×タグ」で整理し、20接続規模でも迷わず制御。グループ一括送信や再接続もワンクリック。
3. **シナリオ拡張性**: CSV形式のシナリオ記述、PowerShellスクリプト連携、並列・条件・ループを簡潔に記述できる仕組み。
4. **セットアップ診断**: Ping/Port/Route自動点検し、推奨対処を日本語で提示。初回接続時の迷いを解消。
5. **受信データ活用**: シナリオ内で受信データを変数として保持し、次回送信時に埋め込み可能。動的な電文生成を実現。
6. **1フォルダ=1インスタンス**: すべての設定・シナリオ・ログがフォルダ単位で完全独立。コピーだけで環境複製可能。

---

## 2. 機能要件

### 2.1 通信機能
- **TCP通信**: クライアント/サーバー両モード対応
- **UDP通信**: 送信/受信対応
- **複数接続**: 異なるIP:Portの組み合わせで複数インスタンスを同時起動
- **接続管理**: 接続/切断の制御、再接続機能

### 2.2 電文送受信機能（インスタンス単位で独立制御）
各通信インスタンスは独自のデータバンク・送信設定・受信処理を保持し、他インスタンスとは完全に分離された状態で動作する。
- **データバンク管理**: インスタンスフォルダ内のCSVで定義した名前付き電文セットを読み込み、カテゴリやタグで整理。
- **ワンクリック送信**: ドロップダウン選択またはボタン1回で、**選択中のインスタンス**へ即時送信できるSend-First UI。
- **多彩な送信方式**: テキスト、HEX、ファイル送信、テンプレート展開、変数埋め込み。すべてインスタンスごとに独立した変数スコープで処理。
- **自動送信**: シナリオまたはバッチ操作での連続送信。複数インスタンスへの一括送信も可能だが、各インスタンスは独立したタイミング・状態で実行。
- **受信表示（最小限）**: 受信結果はインスタンスごとにサマリとステータスのみを表示。
- **受信データ活用**: 受信データを変数として保持し、次回送信データに埋め込み可能。動的な電文生成を実現。
- **エンコーディング**: ASCII, UTF-8, Shift-JIS, バイナリ(HEX文字列)対応。インスタンスごとに設定可能。

### 2.3 シナリオ機能（インスタンス単位で独立実行）
各インスタンスは独自のシナリオファイルを持ち、他インスタンスのシナリオ実行状態に影響されることなく動作する。
- **シナリオファイル**: インスタンスフォルダ内のCSV形式でシナリオ定義
- **待機制御**: 時間待機、受信待機。待機状態は各インスタンスで独立管理。
- **条件分岐**: 受信データに基づく処理分岐。判定条件・変数はインスタンススコープ内で評価。
- **ループ処理**: 繰り返し実行。ループカウンタはインスタンスごとに独立。
- **変数機能**: 受信データを変数として保持し、次回送信時に動的に埋め込み。変数スコープはインスタンス内に閉じ、他インスタンスと共有しない。
- **スクリプト連携**: カスタムPowerShellロジックを呼び出し、複雑な振る舞いも簡潔に記述。スクリプトには現在のインスタンスコンテキストが渡される。
- **グループ送信**: 複数インスタンスへ一括送信指示が可能だが、実際の送信は各インスタンスが独立して実行。

### 2.4 拡張機能（インスタンス単位で独立設定）
- **自動応答**: 特定パターン受信時の自動返信。応答ルールはインスタンスごとに定義し、独立動作。
- **動的更新**: テンプレートベースの電文生成（変数置換）。変数・シーケンス番号はインスタンススコープで管理。
- **カスタムスクリプト**: PowerShellスクリプトによる拡張処理。インスタンスコンテキストを引数として受け取る。
- **プラグイン機能**: 外部PSスクリプトの読み込み。インスタンスごとに異なるプラグインセットを適用可能。

### 2.5 GUI機能
- **接続一覧**: アクティブな接続の一覧表示。各インスタンスの状態を個別に表示。
- **ステータス表示（色分け）**: 各接続の状態をリアルタイムに色分け表示（緑=接続中、赤=切断、黄=エラー、グレー=未接続）。WinFormsの`DataGridView`または`ListView`で各行・カードの背景色を動的に変更し、視覚的に状態を把握可能。インスタンス単位で独立。
- **ログビューア**: 送受信履歴の表示。選択したインスタンスのログをフィルタ表示可能。
- **設定パネル**: 接続設定、シナリオ選択。選択中のインスタンスに対して操作。
- **スケーラブル設計**: 多数の接続にも対応可能なUI。
- **クイックアクションバー**: 送信テンプレートをドロップダウンまたはボタンで即実行。対象インスタンスを選択して送信。
- **論理ビュー／物理ビュー切替**: グループ、タグ、プロトコル別の整理された一覧で多数インスタンスを管理。
- **診断パネル**: 接続テスト、推奨設定を提示。

### 2.6 診断支援機能（インスタンス単位で独立診断）
- **ネットワーク疎通確認**: IP到達性、ポート開放状況、ルーティング情報を可視化。選択したインスタンスの接続先を診断。
- **環境チェックリスト**: よくある構成ミスを自動検出し、是正案を提示。インスタンスごとの設定を検証。
- **接続ドリルダウン**: 各インスタンスの状態遷移、最終エラー原因を時系列で確認。
- **セットアップガイド**: 初回起動時に順を追ったウィザードで試験環境を整備。
- **ネットワークアナライザ**: IP到達性、ポート開放状況、ルーティング情報を可視化。選択したインスタンスの接続先を診断。
- **環境チェックリスト**: よくある構成ミスを自動検出し、是正案を提示。インスタンスごとの設定を検証。
- **接続ドリルダウン**: 各インスタンスの状態遷移、最終エラー原因を時系列で確認。
- **セットアップガイド**: 初回起動時に順を追ったウィザードで試験環境を整備。

---

## 3. システム構成

### 3.1 ディレクトリ構成

#### 3.1.1 通信インスタンスの概念
本アプリにおいて、**1フォルダ = 1通信インスタンス = 1ソケット接続(IP:Port) = 1外部装置・アプリ模擬**という対応関係を基本設計とする。各インスタンスは以下の要素を独立して保持し、他のインスタンスと完全に分離された状態で動作する:

- **接続設定**: TCP/UDP、クライアント/サーバーモード、バインドIP:Port、接続先IP:Port
- **シナリオ実行**: 送受信シーケンス、待機・分岐・ループ制御、変数スコープ
- **電文テンプレート**: データバンク、自動応答ルール、QuickSendスロット割当
- **性能計測**: スループット/レイテンシ測定、バースト送信設定
- **実行履歴**: 送受信ログ、診断結果、計測レポート

この設計により、1台のPC上で複数の外部装置を同時に模擬でき、装置Aは定期的なステータス送信、装置Bは要求応答型、装置Cは高負荷ストリームといった異なる振る舞いを並行実行できる。

#### 3.1.2 フォルダ構成
`Instances/` 配下に任意のフォルダ名で通信インスタンスを配置する。フォルダ名は識別しやすい名称（装置名・用途など）を自由に設定でき、アプリはフォルダの存在を検知して自動認識する。フォルダを追加すれば新たなインスタンスが追加され、削除すれば即座に一覧から除外される（FileSystemWatcherで監視）。
```
TcpDebugger/
├── TcpDebugger.ps1              # メインスクリプト（GUIエントリーポイント）
├── DESIGN.md                    # 本設計書
├── README.md                    # 使用方法
├── Core/                        # コア層（ビジネスロジック）
│   ├── Common/                      # 共通ユーティリティ
│   │   ├── Logger.ps1                   # ログ出力
│   │   ├── ErrorHandler.ps1             # エラーハンドリング
│   │   └── ThreadSafeCollections.ps1    # スレッドセーフコレクション
│   ├── Domain/                      # ドメインロジック
│   │   ├── ConnectionModels.ps1         # 接続モデル定義
│   │   ├── ConnectionService.ps1        # 接続管理サービス
│   │   ├── ConnectionManager.ps1        # 接続制御・ライフサイクル管理
│   │   ├── MessageService.ps1           # メッセージ処理（テンプレート、変数展開）
│   │   ├── ReceivedEventPipeline.ps1    # 受信イベント処理パイプライン
│   │   ├── ReceivedRuleEngine.ps1       # ルールエンジン（OnReceiveReply/OnReceiveScript）
│   │   ├── RuleProcessor.ps1            # ルール実行
│   │   ├── OnReceiveScriptLibrary.ps1   # OnReceiveScriptプロファイル管理
│   │   ├── VariableScope.ps1            # 変数スコープ管理
│   │   ├── ProfileModels.ps1            # プロファイルモデル定義
│   │   ├── ProfileService.ps1           # プロファイル管理サービス
│   │   └── RunspaceMessages.ps1         # Runspace間メッセージ定義
│   ├── Application/                 # アプリケーションサービス
│   │   ├── InstanceManager.ps1          # インスタンス管理
│   │   └── NetworkAnalyzer.ps1          # ネットワーク診断
│   └── Infrastructure/              # インフラストラクチャ層
│       ├── ServiceContainer.ps1         # DIコンテナ
│       ├── RunspaceMessageQueue.ps1     # Runspaceメッセージキュー
│       ├── RunspaceMessageProcessor.ps1 # メッセージプロセッサ
│       ├── Adapters/                    # 通信アダプター
│       │   ├── TcpClientAdapter.ps1     # TCPクライアント通信
│       │   ├── TcpServerAdapter.ps1     # TCPサーバー通信
│       │   └── UdpAdapter.ps1           # UDP通信
│       └── Repositories/                # データアクセス
│           ├── RuleRepository.ps1       # ルールリポジトリ
│           ├── InstanceRepository.ps1   # インスタンス設定リポジトリ
│           └── ProfileRepository.ps1    # プロファイルリポジトリ
├── Presentation/                # プレゼンテーション層
│   └── UI/
│       ├── MainForm.ps1                 # メインフォーム（WinForms UI）
│       ├── ViewBuilder.ps1              # UI構築ヘルパー
│       └── MainFormViewModel.ps1        # ViewModelロジック
├── Config/                      # 共通設定・デフォルトテンプレート
│   └── defaults.psd1                # 既定値スナップショット
├── Instances/                   # 通信インスタンスフォルダ群（増減で動的認識）
│   ├── WebServer-Sim/               # 任意のフォルダ名（装置識別名）
│   │   ├── instance.psd1            # インスタンス設定（ID、表示名、接続パラメータ）
│   │   ├── scenarios/               # このインスタンス専用シナリオ
│   │   │   ├── startup.csv
│   │   │   └── on_receive_reply.csv
│   │   ├── templates/               # このインスタンス専用電文テンプレート
│   │   │   └── messages.csv
│   │   ├── logs/                    # 送受信ログ（自動生成）
│   │   └── reports/                 # 性能計測レポート（自動生成）
│   ├── PLC-Controller/              # 別のインスタンス例
│   │   ├── instance.psd1
│   │   ├── scenarios/
│   │   │   └── periodic_poll.csv
│   │   └── templates/
│   │       └── plc_commands.csv
│   └── LoadTest-Client01/           # 負荷試験用インスタンス例
│       ├── instance.psd1
│       └── scenarios/
│           └── burst_send.csv
├── Docs/                        # ドキュメント
│   └── ReceivedRuleFormat.md        # 受信ルール共通フォーマット仕様
├── Tests/                       # テストコード
│   └── Unit/
│       └── Core/
│           ├── Common/
│           │   └── Logger.Tests.ps1
│           └── Domain/
│               └── VariableScope.Tests.ps1
└── Logs/                        # ログファイル出力先
```

#### 3.1.3 インスタンス検出・管理ルール
- **最小構成**: `Instances/<任意フォルダ名>/instance.psd1` が存在すればインスタンスとして認識。
- **インスタンスID**: `instance.psd1` 内の `Id` プロパティで一意識別（未指定時はフォルダ名から自動生成）。
- **表示名**: `DisplayName` プロパティでUI表示用の名称を設定可能（未指定時はフォルダ名を使用）。
- **フォルダ監視**: FileSystemWatcherで `Instances/` 配下の追加・削除・リネームを検知し、UIへリアルタイム反映。
- **設定の優先順位**: 
  1. インスタンスフォルダ内の設定ファイル（`scenarios/`, `templates/`）
  2. `Config/defaults.psd1` のシステムデフォルト
- **独立性保証**: 各インスタンスは独自のスレッド・変数スコープ・状態管理を持ち、他インスタンスの動作に影響を与えない。
- **ログ・レポート**: 各インスタンスフォルダ内に自動保存され、フォルダごとコピーすることで環境移行・バックアップが可能。

### 3.2 クリーンアーキテクチャによる設計

本アプリケーションは、v1.1.0でクリーンアーキテクチャに完全移行しました。

#### 3.2.1 レイヤー構成
- **Core層**: ビジネスロジックとドメインモデル
  - `Common/`: Logger、ErrorHandler、ThreadSafeCollections
  - `Domain/`: ConnectionService、MessageService、ReceivedEventPipeline
  - `Application/`: InstanceManager、NetworkAnalyzer
  - `Infrastructure/`: Adapters（通信プロトコル）、Repositories（データアクセス）、ServiceContainer（DI）

- **Presentation層**: UI/MainForm.ps1によるWinFormsベースのユーザーインターフェース

#### 3.2.2 主要コンポーネント
- **ConnectionService**: 接続の作成、管理、状態監視を統括
- **MessageService**: テンプレート展開、変数処理、シナリオ実行を統合
- **ReceivedEventPipeline**: 受信データの処理パイプライン（On Receive: Reply、On Receive: Script、Unifiedルール対応）
- **RuleProcessor**: ルールマッチングとアクション実行
- **通信アダプター**（TcpClient/Server、UDP）: プロトコル固有の実装を分離
- **ProfileService**: On Receive: Reply、On Receive: Script、On Timer: Sendの各プロファイルを統合管理

### 3.3 ロジカルアーキテクチャ
```
┌─────────────────────────────────────────────┐
│ Presentation Layer                          │
│  - WinForms UI (MainForm, ViewBuilder)      │
│  - ViewModel (MainFormViewModel)            │
└─────────────────────────────────────────────┘
          │ (Data binding / Service calls)
┌─────────────────────────────────────────────┐
│ Core / Application Layer                    │
│  - InstanceManager (インスタンス管理)         │
│  - NetworkAnalyzer (ネットワーク診断)         │
└─────────────────────────────────────────────┘
          │ (Domain services)
┌─────────────────────────────────────────────┐
│ Core / Domain Layer                         │
│  - ConnectionService (接続管理)              │
│  - MessageService (メッセージ処理)            │
│  - ReceivedEventPipeline (受信処理)          │
│  - ProfileService (プロファイル管理)          │
└─────────────────────────────────────────────┘
          │ (Adapters / Repositories)
┌─────────────────────────────────────────────┐
│ Core / Infrastructure Layer                 │
│  - TcpClientAdapter / TcpServerAdapter / UdpAdapter │
│  - RuleRepository / ProfileRepository       │
│  - ServiceContainer (DI)                    │
└─────────────────────────────────────────────┘
```

- **責務分離**: UIはデータバインディングとユーザー操作の受付のみ。ビジネスロジックはDomain層、外部I/OはInfrastructure層に集約。
- **依存性注入**: ServiceContainerによるDIパターンで、テスタビリティと保守性を確保。
- **イベント駆動**: ReceivedEventPipelineによる統一された受信処理フロー。
- **イベント駆動**: Orchestration層はPowerShellイベントでUIへ状態を通知。Service層はイベント発火のみを行い、UIスレッドに直接触れない。
- **拡張性**: 新しいプロトコルや解析機能はService層のモジュール追加で実現し、UI/Orchestrationは最小改修で済む。

### 3.4 スレッド構成
- **UI Thread**: WinFormsのメッセージループ。ユーザー操作と表示更新を担当。
- **Connection Runspaces**: 接続ごとに専用のRunspaceを確保し、非同期受信と送信処理を実行。各インスタンスは独立したリソースのみ操作。
- **RunspaceMessageProcessor**: 通信スレッドとUIスレッド間のメッセージングを管理。
- **Shared Data Structures**: スレッドセーフなコレクション（ThreadSafeHashtable等）で接続状態を共有。UI更新は`Control.Invoke`を介して実行。

**設計原則**: 各通信インスタンスは専用Runspaceで動作し、独自のバッファ・変数・状態のみを操作。グローバル状態へのアクセスは最小化し、ServiceContainerを通じた依存性注入で疎結合を実現。

### 3.5 受信イベントパイプライン

v1.1.0で受信データ処理が統合的なパイプラインとして再設計されました：

- **ReceivedEventPipeline**: すべての受信データを統一的に処理するパイプライン。
- **RuleProcessor**: ルールマッチングとアクション実行を担当。
- **ProfileService**: On Receive: Reply、On Receive: Script、On Timer: Sendの各プロファイルを管理。
- **統合ルールフォーマット**: OnReceiveReply、OnReceiveScript、Unified形式をサポート（詳細は`Docs/ReceivedRuleFormat.md`参照）。

通信アダプター（TcpClientAdapter、TcpServerAdapter、UdpAdapter）の受信ループから`ReceivedEventPipeline`が呼び出され、設定されたプロファイルに基づいて自動応答やスクリプト実行が行われます。

### 3.6 状態・設定管理
- **インスタンス設定**: 起動時に`instance.psd1`を読み込み、InstanceRepositoryで管理。
- **プロファイル管理**: ProfileServiceとProfileRepositoryにより、On Receive: Reply、On Receive: Script、On Timer: Sendの設定を一元管理。
- **Runtime State**: 接続状態、シナリオ実行状況はConnectionServiceとConnectionManagerで管理。
- **キャッシュ管理**: MessageServiceとRuleRepositoryが、テンプレートとルールのキャッシュを自動管理（ファイル更新検知付き）。
- **ログ**: 構造化ログ（Logger）で統一的にログ出力。

### 3.7 拡張性
- **プロトコル拡張**: 新しい通信アダプターを`Core/Infrastructure/Adapters/`に追加し、ServiceContainerに登録。
- **カスタム処理**: On Receive: ScriptプロファイルでPowerShellスクリプトを実行可能。スクリプトにはConnectionContextが渡される。
- **変数システム**: MessageServiceで組み込み変数（TIMESTAMP、RANDOM、SEQなど）をサポート。カスタム変数ハンドラーの追加も可能。
- **テスト**: Pesterによる単体テストをTests/Unit/に配置。CI/CDパイプラインでの自動テストに対応。

### 3.8 デプロイ・運用
- **ポータブル実行**: `TcpDebugger.ps1`と`Core/`、`Presentation/`配下を配置するだけで動作。PowerShell 5.1以上があれば追加インストール不要。
- **インスタンス管理**: `Instances/`配下にフォルダを追加するだけで新規インスタンス作成。フォルダのコピーで環境複製可能。
- **依存性注入**: ServiceContainerによるDIで、モジュール間の依存関係を管理。
- **エラーハンドリング**: ErrorHandlerクラスで統一的なエラー処理とロギング。

### 3.9 動的インスタンス管理

#### 3.9.1 インスタンスライフサイクル
```
検出 → 初期化 → 接続 → アクティブ → 切断 → 保持
  ↑                              ↓
  └────── 再接続 ─────────────────┘
```

#### 3.9.2 リソース管理
- **Runspaceプール**: 通信用Runspaceを効率的に管理。
- **スレッドセーフコレクション**: 並行アクセスに対応したデータ構造。
- **明示的管理**: フォルダの削除でインスタンス削除（自動削除なし）。

#### 3.9.3 バッチ操作
| 操作 | 説明 | 実装 |
|------|------|------|
| 一括接続 | 選択した接続を同時開始 | InstanceManagerで一括制御 |
| 一括送信 | 複数接続への同一データ送信 | MessageServiceで並列送信 |
| プロファイル切替 | グループ単位でのプロファイル変更 | ProfileServiceで一括適用 |

---

## 4. データフォーマット

### 4.1 インスタンス設定ファイル（instance.psd1）
各インスタンスフォルダ内に配置する設定ファイル。このファイルの存在によりアプリがインスタンスとして認識する。

**例: Instances/WebServer-Sim/instance.psd1**
```powershell
@{
    # インスタンス識別子（省略時はフォルダ名から自動生成）
    Id = "web-srv-01"
    
    # UI表示名（省略時はフォルダ名を使用）
    DisplayName = "Webサーバー模擬装置"
    
    # 説明・用途
    Description = "HTTP通信試験用のサーバー側模擬"
    
    # 接続設定
    Connection = @{
        Protocol = "TCP"           # TCP/UDP
        Mode = "Server"           # Client/Server/Sender/Receiver
        LocalIP = "0.0.0.0"
        LocalPort = 8080
        RemoteIP = ""             # Serverモードでは不要
        RemotePort = 0
    }
    
    # 起動設定
    AutoStart = $true            # アプリ起動時に自動接続
    AutoScenario = "startup.csv" # 接続後に自動実行するシナリオ
    
    # タグ・グループ（論理ビューでの分類）
    Tags = @("WebServer", "HTTP", "Test")
    Group = "WebServers"
    
    # エンコーディング設定
    DefaultEncoding = "UTF-8"
    
    # 性能測定設定
    Performance = @{
        EnableMetrics = $true
        SampleInterval = 1000    # ms
    }
}
```

**例: Instances/PLC-Controller/instance.psd1**
```powershell
@{
    Id = "plc-ctrl-01"
    DisplayName = "PLC制御装置"
    Description = "FA制御システム向けPLC模擬"
    
    Connection = @{
        Protocol = "TCP"
        Mode = "Client"
        LocalIP = "0.0.0.0"
        LocalPort = 0
        RemoteIP = "192.168.10.50"
        RemotePort = 502         # Modbus TCP
    }
    
    AutoStart = $false
    AutoScenario = "periodic_poll.csv"
    
    Tags = @("PLC", "Modbus", "FA")
    Group = "FactoryAutomation"
    
    DefaultEncoding = "ASCII"
}
```

1,LOOP,BEGIN,COUNT=3,LABEL=main,${MSG_HELLO}と応答処理を3回繰り返す
2,SEND,${MSG_HELLO},,,HelloM
3,WAIT_RECV,TIMEOUT=5000,PATTERN=OK,,?@
4,SAVE_RECV,VAR_NAME=response,,,Mf[^???
5,SLEEP,1000,,,1b?@
6,SEND_HEX,48656C6C6F,,,HEXf[^M
7,SEND,${response},,,Mf[^??
8,CALL_SCRIPT,custom_check.ps1,,,JX^s
9,LOOP,END,LABEL=main,,ループ終端

- `LOOP`: LOOPブロック制御 (BEGIN/END, COUNT, LABEL 対応)
- `Name`: 接続識別名
- `Protocol`: TCP/UDP
- `Mode`: Client/Server/Sender/Receiver
- `LocalIP`, `LocalPort`: ローカルバインド設定
- `RemoteIP`, `RemotePort`: リモート接続先
- `AutoStart`: 起動時自動接続フラグ
- `ScenarioFile`: 関連付けるシナリオファイル

### 4.2 シナリオファイル（scenarios/*.csv）
インスタンスフォルダ内に配置。各インスタンス専用のシナリオを定義。
```csv
Step,Action,Parameter1,Parameter2,Parameter3,Description
1,SEND,${MSG_HELLO},,,Hello送信
2,WAIT_RECV,TIMEOUT=5000,PATTERN=OK,,応答待機
3,SAVE_RECV,VAR_NAME=response,,,受信データを変数に保存
4,SLEEP,1000,,,1秒待機
5,SEND_HEX,48656C6C6F,,,HEXデータ送信
6,SEND,${response},,,受信したデータを送り返す
7,CALL_SCRIPT,custom_check.ps1,,,カスタム処理実行
8,LOOP,1,7,,,ステップ1-7をループ
```

**アクション種類:**
- `SEND`: テキスト送信（変数展開可）
- `SEND_HEX`: HEX文字列送信
- `SEND_FILE`: ファイル内容送信
- `WAIT_RECV`: 受信待機（タイムアウト、パターンマッチ）
- `SAVE_RECV`: 受信データを変数に保存（次回送信で利用可能）
- `SLEEP`: 時間待機
- `CALL_SCRIPT`: 外部スクリプト実行
- `SET_VAR`: 変数設定
- `IF`: 条件分岐
- `LOOP`: ループ処理
- `DISCONNECT`: 切断
- `RECONNECT`: 再接続

### 4.3 電文テンプレート（templates/message_templates.csv）
インスタンスフォルダ内に配置。各インスタンス専用の電文テンプレートを定義。
```csv
TemplateName,MessageFormat,Encoding
MSG_HELLO,Hello from ${HOSTNAME} at ${TIMESTAMP},ASCII
MSG_STATUS,STATUS ${SEQ}\n,UTF-8
MSG_BINARY,${HEX:AABBCCDD}${VAR:sequence},HEX
MSG_ECHO,${response},UTF-8
```

**変数タイプ:**
- `${変数名}`: 通常変数（SAVE_RECVで保存した受信データ等）
- `${TIMESTAMP}`: タイムスタンプ（yyyyMMddHHmmss）
- `${DATETIME:format}`: 書式指定日時
- `${RANDOM:min-max}`: ランダム値
- `${SEQ:name}`: シーケンス番号（自動インクリメント）
- `${HEX:value}`: HEX変換
- `${CALC:expression}`: 計算式

### 4.4 自動応答ルール（scenarios/on_receive_reply.csv）
```csv
TriggerPattern,ResponseTemplate,Encoding,Delay,MatchType
^PING,PONG,ASCII,0,Regex
STATUS,OK ${TIMESTAMP},UTF-8,100,Exact
0x01020304,${MSG_ACK},HEX,0,Exact
```

**フィールド説明:**
- `TriggerPattern`: 受信データのマッチパターン
- `ResponseTemplate`: 応答テンプレート（変数使用可）
- `Encoding`: エンコーディング
- `Delay`: 応答遅延（ミリ秒）
- `MatchType`: Regex/Exact/Contains
### 4.5 送信データバンク（databank.csv）
インスタンスフォルダ内に配置。クイック送信用の電文テンプレート一覧を定義。
```csv
DataID,Category,Description,Type,Content
STATUS,Basic,ステータス確認,TEXT,"STATUS\n"
QUERY,Basic,データ要求,TEXT,"QUERY\n"
PING,Health,疎通確認,HEX,50494E470D0A
SEQ_STATUS,Sequence,シーケンス付与,TEMPLATE,SEQ=${SEQ:main}|TIME=${TIMESTAMP}
ECHO_BACK,Dynamic,受信データ返送,TEXT,${response}
```

**フィールド説明:**
- `DataID`: テンプレート識別子（UIボタン名、ドロップダウン表示名）
- `Category`: 用途（Basic/Health/Dynamicなど）
- `Description`: オペレータ向け説明
- `Type`: TEXT/HEX/FILE/TEMPLATE など
- `Content`: 実データまたはテンプレート（変数使用可）

### 4.6 診断ルール設定（diagnostics.psd1）
インスタンスフォルダ内に配置。インスタンス固有の診断ルールを定義可能。
```powershell
@{
   checks = @(
      @{type = "ping"; target = '${REMOTE_IP}'; thresholdMs = 100}
      @{type = "port"; target = '${REMOTE_IP}'; port = 8080}
      @{type = "route"; destination = '${REMOTE_IP}'}
   )
   recommendations = @(
      @{code = "PING_FAIL"; message = "対象装置の電源/ネットワーク状態を確認してください"}
      @{code = "PORT_CLOSED"; message = "ポート8080が閉じています。対象装置のサービス起動を確認してください"}
   )
}
```

**キー説明:**
- `checks`: 実行する診断ステップ（Ping/Port/Route等）
- `recommendations`: 判定コードに紐づくアドバイステンプレート
- 変数 `${REMOTE_IP}` などは接続設定から自動展開

---

## 5. GUI設計

### 5.1 デザインコンセプト
- **実用性重視**: WinFormsの標準コントロールを活用したシンプルで堅牢なUI
- **視認性重視**: 明るい背景に適度なコントラスト、重要情報は色・サイズで強調
- **効率的な操作**: ドロップダウン選択＋送信ボタンのシンプルなワンアクション送信
- **スケーラブル**: 多数の接続を階層的に管理、パネルサイズ調整可能
- **三分割レイアウト**: 左（インスタンス一覧）・中央（操作パネル）・右（ログ/診断）の構成

### 5.2 メインウィンドウ構成

#### パターンA: インスタンス一覧ベース（推奨）
```
┌─────────────────────────────────────────────────────────────────────────┐
│ Socket Debugger Simple               [Refresh][Connect All]  [─][□][×] │
├─────────────────────────────────────────────────────────────────────────┤
│ Instance List                                                           │
│┌───┬──────────────┬────────┬──────────┬──────────────┬──────┬────────┐ │
││ ● │ Name         │Protocol│ Endpoint │ Scenario     │Status│ Action ││ │
│├───┼──────────────┼────────┼──────────┼──────────────┼──────┼────────┤ │
││ ● │WebServer-Sim │TCP Svr │:8080     │[startup.csv▼]│ RUN  │[Stop]  ││ │
││ ● │PLC-Ctrl-01   │TCP Cli │192....:502│[poll.csv  ▼]│ IDLE │[Start] ││ │
││ ○ │LoadTest-01   │TCP Cli │192....:9000│[burst.csv ▼]│ ---- │[Conn]  ││ │
││ ● │WebServer-02  │TCP Svr │:8081     │[None      ▼]│ IDLE │[Start] ││ │
│└───┴──────────────┴────────┴──────────┴──────────────┴──────┴────────┘ │
│                                                                         │
│ Selected: WebServer-Sim                                    [Details▼]  │
├─────────────────────────────────────────────────────────────────────────┤
│ ○ Manual Send  ● Scenario Control  ○ Diagnostics                      │
├───────────────────────────┬─────────────────────────────────────────────┤
│ Scenario: startup.csv     │ Instance Log: WebServer-Sim                │
│ ? Step 3/12              │┌───────────────────────────────────────────┐│
│ Sending STATUS_OK         ││14:30:25 ▲ SEND STATUS_OK                ││
│ ???????????? 67%         ││14:30:26 ▼ RECV ACK (64 bytes)           ││
│                           ││14:30:27 ▲ SEND QUERY                    ││
│ [? Run] [? Pause]        ││                                          ││
│ [? Stop] [? Next Step]   ││                                          ││
│                           ││                                          ││
│ Variables:                ││                                          ││
│  response = "ACK"         │└───────────────────────────────────────────┘│
│  seq = 3                  │                                            │
│                           │ [Clear Log] [Export Log]                   │
└───────────────────────────┴─────────────────────────────────────────────┘
│ Ready | 3/4 connected | Selected: WebServer-Sim           v1.0.0      │
└─────────────────────────────────────────────────────────────────────────┘
```

**特徴:**
- **インスタンス一覧テーブル**: すべてのインスタンスを1画面で把握。状態（●=接続中、○=切断）、シナリオ、実行状態を一覧表示。
- **インラインシナリオ選択**: 各行にドロップダウンを配置し、シナリオを即座に切り替え可能。
- **行選択で詳細操作**: インスタンスを選択すると、下部に詳細操作パネル（Manual/Scenario/Diagnostics）が表示される。
- **シナリオ実行状態の可視性**: Status列でIDLE/RUN/ERRORを表示し、複数インスタンスの同時実行状況を把握しやすい。

#### パターンB: タブ切り替え方式（代替案）
```
┌─────────────────────────────────────────────────────────────────────────┐
│ Socket Debugger Simple                                     [─][□][×]   │
│┌──────────────┬──────────────┬──────────────┬──────────────┐           │
││WebServer-Sim │ PLC-Ctrl-01  │ LoadTest-01  │ WebServer-02 │ [+]       │
│└──────────────┴──────────────┴──────────────┴──────────────┘           │
├─────────────────────────────────────────────────────────────────────────┤
│ Instance: WebServer-Sim (●Connected)                      [Disconnect]  │
│ Protocol: TCP Server | Endpoint: 0.0.0.0:8080                          │
├───────────────────────────┬─────────────────────────────────────────────┤
│ ○ Manual  ● Scenario  ○ Diag│ Instance Log                            │
├───────────────────────────┤┌───────────────────────────────────────────┐│
│ Scenario: [startup.csv ▼] ││14:30:25 ▲ SEND STATUS_OK                ││
│                           ││14:30:26 ▼ RECV ACK (64 bytes)           ││
│ ? Step 3/12              ││14:30:27 ▲ SEND QUERY                    ││
│ Sending STATUS_OK         ││                                          ││
│ ???????????? 67%         │└───────────────────────────────────────────┘│
│                           │                                            │
│ [? Run] [? Pause]        │ Global Log (All Instances)                 │
│ [? Stop] [? Next Step]   │┌───────────────────────────────────────────┐│
│                           ││14:30:25 [WebServer-Sim] ▲ SEND STATUS   ││
│ Variables:                ││14:30:26 [PLC-Ctrl-01] ▼ RECV 0x0102     ││
│  response = "ACK"         ││14:30:27 [WebServer-Sim] ▼ RECV ACK      ││
│  seq = 3                  │└───────────────────────────────────────────┘│
└───────────────────────────┴─────────────────────────────────────────────┘
│ 3/4 connected | Active: 2 scenarios running                v1.0.0      │
└─────────────────────────────────────────────────────────────────────────┘
```

**特徴:**
- **タブ切り替え**: 各インスタンスを個別タブで表示。集中して1インスタンスを操作できる。
- **インスタンスごとのログ**: 選択中インスタンスのログを個別表示。
- **グローバルログ**: 全インスタンスのログを時系列で表示し、全体の動きを把握。

---

### 5.3 推奨デザイン: パターンA（インスタンス一覧ベース）

**採用理由:**
1. **状況把握が容易**: 複数インスタンスの状態・シナリオ実行状況を1画面で把握
2. **シナリオ切り替えが迅速**: 各行のドロップダウンで即座に切り替え、Start/Stopボタンで制御
3. **比較が簡単**: 同時実行中の複数シナリオを並べて確認可能
4. **スケーラブル**: 10?20インスタンスでもスクロールで対応可能

**実装詳細:**
- **DataGridView**: WinFormsのDataGridViewを使用し、各列を定義
  - 列1: 状態アイコン（●/○、CellPaintingイベントで描画）
  - 列2: Name（TextBoxColumn）
  - 列3: Protocol（TextBoxColumn）
  - 列4: Endpoint（TextBoxColumn）
  - 列5: Scenario（ComboBoxColumn、選択イベントでシナリオ切り替え）
  - 列6: Status（TextBoxColumn、色分け表示）
  - 列7: Action（ButtonColumn、Start/Stop/Conn）
- **行選択イベント**: SelectionChangedイベントで下部の詳細パネルを更新
- **インラインアクション**: ButtonColumnのClickイベントで接続/切断/シナリオ開始/停止を制御

### 5.3 UI要素詳細

#### インスタンス一覧テーブル（DataGridView）
- **状態列（●/○）**: CellPaintingイベントで色付き円を描画
  - 緑●: 接続中かつシナリオ実行中
  - 青●: 接続中でアイドル
  - グレー○: 切断中
  - 赤●: エラー状態
- **Name列**: インスタンス表示名（instance.psd1のDisplayName）
- **Protocol列**: TCP/UDP、Client/Server/Sender/Receiverを表示
- **Endpoint列**: リモートIPまたはローカルバインドポートを表示
- **Scenario列（ComboBoxColumn）**: 
  - インスタンスフォルダ内のscenarios/*.csvを自動列挙
  - [None]、[startup.csv]、[poll.csv]等をドロップダウン表示
  - 選択変更時にScenarioEngineへロード指示（即座に反映、自動開始はしない）
- **Status列**: IDLE / RUN / PAUSE / ERROR / ----（未接続）
  - 背景色で視覚的に区別（RUN=薄緑、ERROR=薄赤）
- **Action列（ButtonColumn）**: 
  - 未接続時: [Connect]
  - 接続中でシナリオ未実行: [Start]（シナリオ開始）
  - シナリオ実行中: [Stop]
  - エラー時: [Retry]

#### 詳細操作パネル（下部タブ）

**Manualタブ（手動送信）:**
- **Template選択**: ComboBoxでDataBank一覧を表示、カテゴリ別にグループ化
- **Preview**: 変数展開済みの送信データをTextBoxで表示・編集可能
- **Encoding選択**: ASCII/UTF-8/Shift-JIS/HEXをComboBoxで選択
- **送信ボタン**: 
  - [Send]: 選択中インスタンスへ送信
  - [Burst 10x]: 10回連続送信
  - [Send to Group]: 同じGroupに属する全インスタンスへ送信

**Scenarioタブ（シナリオ実行）:**
- **実行状態表示**: 
  - 現在のステップ番号/総ステップ数
  - 進捗率（ProgressBar）
  - 経過時間
  - 実行中のアクション内容（TextBox）
- **制御ボタン**: 
  - [? Run]: シナリオ開始
  - [? Pause]: 一時停止
  - [? Stop]: 停止
  - [? Next Step]: 1ステップ実行
- **Variables表示**: 現在の変数スコープをListViewで表示（読み取り専用）

**Diagnosticsタブ（診断）:**
- **診断実行**: [Run Check]ボタンで診断開始
- **結果表示**: ListViewでチェック項目とステータス（?OK/?NG）を表示
- **推奨アクション**: TextBoxで是正案を表示

#### インスタンスログパネル（右側）
- **ListView表示**: 選択中インスタンスの送受信履歴
  - 列1: 時刻
  - 列2: 方向（▲送信/▼受信）
  - 列3: データサマリ（最初の50文字）
  - 列4: サイズ（bytes）
- **背景色**: 送信行=薄青、受信行=薄緑、エラー行=薄赤
- **最大100件**: 古いものから自動削除
- **操作ボタン**: 
  - [Clear Log]: 現在のログをクリア
  - [Export Log]: ファイルに保存（SaveFileDialogで保存先指定）

#### グループ操作（ツールバー）
- **Group Filter**: ComboBoxで表示するグループを選択（All/WebServers/LoadTest等）
- **一括操作ボタン**: 
  - [Refresh]: インスタンス一覧を再読み込み
  - [Connect All]: フィルタ中の全インスタンスを接続
  - [Disconnect All]: フィルタ中の全インスタンスを切断
  - [Start All Scenarios]: フィルタ中の全インスタンスのシナリオを開始

### 5.4 WinForms実装方針
- **フォーム生成**: `UI/MainForm.ps1`で`System.Windows.Forms`を用い、`SplitContainer`でレイアウト。
- **データバインディング**: `BindingSource`＋`BindingList`を採用し、バックエンド`StateStore`とUIコントロールを同期。
- **非同期処理**: スレッドからの通知は`Control.Invoke/BeginInvoke`でUIスレッドへマーシャリング。
- **イベント駆動**: WinFormsイベントで各コントロールの操作を処理。
- **標準コントロール**: TreeView, ComboBox, TextBox, Button, ListView, ProgressBar等の標準コントロールを活用。
- **レイアウト**: `SplitContainer`や`TableLayoutPanel`で3分割レイアウトを実現。`Dock`プロパティで可変サイズ対応。

### 5.5 デザインシステム

#### カラーパレット
```
プライマリ:     #0078D4 (Microsoft Blue)
成功:           #107C10 (Success Green)
警告:           #FFB900 (Warning Yellow)
エラー:         #E81123 (Error Red)
背景:           #FFFFFF (White)
パネル背景:     #F3F3F3 (Light Gray)
ボーダー:       #E1E1E1 (Border Gray)
テキスト:       #323130 (Dark Gray)
```

#### タイポグラフィ
```
見出し:         Segoe UI Semibold 14pt
ボタン:         Segoe UI 10pt
本文:           Segoe UI 9pt
コード:         Consolas 9pt
```

#### 間隔・サイズ
```
基本単位:       8px グリッド
パディング:     8px / 16px
ボタン高さ:     28px
アイコンサイズ: 16×16px
```

### 5.6 アクセシビリティ
- **キーボードナビゲーション**: Tab順序を論理的に設定し、Enter/Spaceで操作可能。
- **ショートカット**: Ctrl+S（保存）、Ctrl+O（開く）、F5（リフレッシュ）等の一般ショートカットをサポート。
- **フォーカス表示**: キーボードフォーカス時に枠で明示

---

## 6. 処理フロー

### 6.1 起動フロー
```
1. TcpDebugger.ps1 実行
2. モジュール読み込み
3. WinFormsフォーム初期化（`System.Windows.Forms.Application.Run`）
4. Instances/ フォルダをスキャンし、instance.psd1 読み込み
5. AutoStart=trueの接続を自動開始
6. メインイベントループ開始
```

### 6.2 接続確立フロー（TCP Client）
```
1. ConnectionManagerが接続設定を取得し、ConnectionContextを生成
2. TcpClient スレッドを起動し、リモートホストへ接続試行
3. 接続成功
   → 状態更新イベントをUIへ発火
   → 受信ループ開始、受信データはMessageHandlerへ委譲
   → AutoStartシナリオがあればScenarioEngineを起動
4. 接続失敗
   → エラー情報をInstanceManagerへ通知
   → 再接続ポリシに従いリトライ or ユーザーへエラー提示
```

### 6.3 シナリオ実行フロー
```
1. ScenarioEngineがCSVを読み込み、Actionパイプラインを構築
2. 実行開始すると、各ステップをスレッド内で順次処理
3. SEND/SEND_HEX等はQuickSender APIを経由して対象接続へ送信
4. WAIT_RECVやIFは受信バッファ／変数ストアを参照して判定
5. SAVE_RECVで受信データを変数に保存し、次回送信で利用可能
6. CALL_SCRIPTやSET_VARで外部ロジックや状態更新を実施
7. 進捗はStepProgressイベントとしてUIとログへ通知
8. 完了・中断・エラーをScenarioResultとしてInstanceManagerに返却
```

### 6.4 自動応答フロー
```
1. Connection スレッドが受信データをMessageHandlerへ渡す
2. OnReceiveReplyモジュールがルールテーブルを走査
3. マッチした場合はテンプレート展開→Delay→送信
4. 応答結果を履歴へ記録し、必要に応じてScenarioEngineへトリガー返送
5. マッチしなかった場合はシナリオ待機へ委譲
```

### 6.5 ワンクリック送信フロー（Send-First）
```
1. ユーザーがドロップダウンでテンプレート選択し、送信ボタンをクリック
2. QuickSenderがDataBankからテンプレートと送信設定を取得
3. MessageHandlerで変数展開・エンコード・整形
4. 対象接続または論理グループの送信キューへ投入
5. Connection スレッドが送信完了を確認し、履歴ストアへ記録
```

### 6.6 インスタンス一括制御フロー
```
1. ユーザーが論理ビューでグループ/タグを選択
2. InstanceManagerが対象接続一覧を抽出
3. 要求（接続/切断/送信/シナリオ開始）を各接続のスレッドへディスパッチ
4. 各接続からの結果イベントを集約し、UIに集約状態（成功/失敗数）を表示
```

### 6.7 ネットワーク診断フロー
```
1. 診断パネルで「Run Check」ボタンをクリック
2. NetworkAnalyzer スレッドがPing/Port/Routeチェックを並列実行
3. 結果をスコアリングし、diagnostics.psd1の推奨アクションを適用
4. UIへ結果表示し、必要に応じて対処手順を提示
5. 対処後は「再診断」で同じチェックを再実行
```

---

## 7. 技術仕様

### 7.1 通信実装
- **TCP**: `System.Net.Sockets.TcpClient`, `TcpListener`
- **UDP**: `System.Net.Sockets.UdpClient`
- **非同期**: `BeginReceive`/`EndReceive` または `ReceiveAsync`
- **バッファサイズ**: 8192バイト（可変設定可）

### 7.2 スレッド管理
- **メインスレッド**: WinForms UIスレッド（Application.Run）
- **接続スレッド**: 各接続ごとにスレッド生成（System.Threading.Thread）
- **シナリオスレッド**: シナリオ実行用スレッド
- **同期**: `Hashtable.Synchronized()`でデータ共有
- **診断スレッド**: NetworkAnalyzerがバックグラウンドでPing/Portチェックを実行

**重要**: 各インスタンスは独立したリソースのみ操作するため、ロック機構は不要。

### 7.3 エラーハンドリング
- すべての通信処理にtry-catchブロック
- エラーログをGUIに表示
- 再接続ロジック（リトライ回数、間隔設定可）

### 7.4 データ永続化
- 設定ファイル: PSD1形式（PowerShellハッシュテーブル）
- ログ: ユーザーが明示的に「ログ保存」ボタンで出力
- DataBank: 各インスタンスフォルダ内のCSVファイルとして管理

### 7.5 QuickSender
- DataBankファイルをロードし、`BindingList`でUIにバインド
- テンプレートIDと送信データのマッピングを管理

### 7.6 InstanceManager
- 各接続をPSCustomObjectでラップし、Group/Tag属性を追加
- グループ抽出、一括操作APIを提供
- GUIへ`BindingSource`で状態配信

### 7.7 NetworkAnalyzer
- `Test-Connection`, `Test-NetConnection`, `Find-NetRoute`を組み合わせた診断
- 診断ルールをPSD1で記述し、推奨アクションをテンプレート生成

### 7.8 ログ管理
- **ログレベル**: INFO/WARN/ERRORを用意
- **ログ出力**: ユーザーが「ログエクスポート」ボタンで明示的に保存（ファイル名・保存先をユーザー指定）
- **自動保存なし**: 詳細トレースが必要な場合は外部ツールを使用

---



### 7.9 既知の技術的課題

- TcpClient.ps1 と UdpCommunication.ps1 では Invoke-ConnectionOnReceiveReply の呼び出し位置が受信処理より前にあり、receivedData 変数が未定義のまま実行される恐れがある (TcpServer.ps1 は正しい位置に配置済み)。

- 受信パイプラインは ReceivedEventHandler.ps1 を経由する設計だが、通信ループから Invoke-ReceivedEvent が呼ばれておらず、OnReceiveScript プロファイルのみを指定した場合は実行されない。

- UI/MainForm.ps1 の On Timer: Send 設定では未実装の Get-InstancePath を参照しており、実行時に例外が発生する。Connection.Variables[InstancePath] を再利用する方向で改修が必要。

- ScenarioEngine.ps1 の IF アクション (Invoke-IfAction) は警告を出すだけのスタブで、条件分岐を伴うシナリオをまだ実行できない。

- OnReceiveScript プロファイルを GUI から切り替えても実行フックが存在しないため、Unified ルール経由で Invoke-OnReceiveScript が呼ばれるケース以外では効果が出ない。



## 8. 拡張性

### 8.1 カスタムスクリプト
On Receive: ScriptプロファイルでPowerShellスクリプトを実行できます。スクリプトにはConnectionContextが渡され、受信データの加工や変数操作が可能です。

```powershell
# Instances/Example/scenarios/on_receive_script/log_login.ps1
param($Context)

# 受信データをログに記録
$receivedText = [System.Text.Encoding]::UTF8.GetString($Context.RecvBuffer)
Write-Host "Login received: $receivedText"

# 変数に保存
$Context.Variables['LastLogin'] = $receivedText
$Context.Variables['LoginTime'] = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
```

### 8.2 変数システム拡張
MessageServiceで組み込み変数をサポート。カスタム変数ハンドラーの追加も可能です。

```powershell
# 組み込み変数の例
${TIMESTAMP}      # 現在時刻
${RANDOM:1-100}   # ランダム値
${SEQ:name}       # シーケンス番号
${CALC:1+2}       # 計算式
```

---

## 9. セキュリティ考慮事項

### 9.1 実行環境
- PowerShell実行ポリシー: RemoteSigned推奨
- ネットワークアクセス権限が必要

> **用途**: 本ツールはTCP/IP通信試験用の治具であり、信頼されたネットワーク環境での使用を想定。厳格なセキュリティ要件が必要な環境では、適切なアクセス制御と監視を実施すること。

---

## 10. パフォーマンスとスケーラビリティ

### 10.1 最適化
- **テンプレートキャッシュ**: MessageServiceがファイル更新検知付きキャッシュで高速読み込み
- **ルールキャッシュ**: RuleRepositoryがルール定義をキャッシュし、繰り返しアクセスを高速化
- **非同期処理**: 通信処理はRunspaceで並列実行し、UIをブロックしない
- **スレッドセーフコレクション**: ロックフリーなデータ構造で並行性能を向上

### 10.2 スケーラビリティ
- **同時接続数**: 20～30接続程度を想定（ハードウェア性能に依存）
- **メモリ使用量**: 接続あたり数MB
- **CPU負荷**: 通常時 < 5%

---

## 11. テスト方針

### 11.1 単体テスト
- **Pesterフレームワーク**: PowerShell標準のテストフレームワークを使用
- **テスト対象**: Core層の主要コンポーネント（Logger、VariableScope、MessageService等）
- **テストファイル**: `Tests/Unit/`配下に配置
- **CI/CD**: 自動テストパイプラインで継続的に品質を保証

### 11.2 統合テスト
- ローカルループバック通信テスト
- 複数接続同時動作テスト
- シナリオ実行テスト（変数展開、ループ、条件分岐）
- プロファイル切替テスト（On Receive: Reply、On Receive: Script、On Timer: Send）

### 11.3 実環境テスト
- 実機器との接続テスト
- 長時間稼働テスト
- エラーリカバリテスト
- 10～20接続規模での負荷テスト

---

## 12. 配布と運用

### 12.1 配布形態
- **ポータブルパッケージ**: 単一ZIPファイルで完全な実行環境を配布
- **依存関係**: PowerShell 5.1以上（Windows標準）のみ
- **USB実行対応**: 任意のドライブから実行可能、レジストリ非依存

### 12.2 起動方法
```powershell
# 基本起動
.\TcpDebugger.ps1

# 実行ポリシー指定
powershell.exe -ExecutionPolicy Bypass -File ".\TcpDebugger.ps1"
```

### 12.3 バージョン管理
- v1.1.0でクリーンアーキテクチャへ完全移行
- 詳細なバージョン履歴はREADME.mdを参照

---

## 13. 参考資料

### 13.1 関連ドキュメント
- **README.md**: 使用方法、インストール手順、機能概要
- **Docs/ReceivedRuleFormat.md**: 受信ルール共通フォーマット仕様

### 13.2 技術参考
- [PowerShell Documentation](https://learn.microsoft.com/powershell/)
- [.NET Socket Programming](https://docs.microsoft.com/dotnet/api/system.net.sockets)
- [Windows Forms](https://learn.microsoft.com/dotnet/desktop/winforms/)

---

**文書履歴**
- Version 1.0 (2025-11-15): 初版作成
- Version 1.1 (2025-11-15): 要件整理と簡素化
  - 1フォルダ=1インスタンスに厳密統一
  - WinFormsで現実的なGUIに変更
  - スレッド構成を明確化
  - 受信データ活用機能（SAVE_RECV）を追加
- Version 1.2 (2025-11-24): クリーンアーキテクチャ移行に伴う更新
  - Core/Infrastructure/Presentation層への再構成
  - ServiceContainerによる依存性注入の導入
  - ReceivedEventPipelineによる受信処理の統合
  - ProfileServiceによるプロファイル管理の一元化
  - 古いモジュール名の更新と不要な記述の削除
