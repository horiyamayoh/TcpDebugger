# TCP Test Controller

TCP/UDP通信のテスト・デバッグを行うための試験装置です。設定ファイルベースでシナリオ実行が可能で、視覚的に接続状態を確認できるGUIを備えています。

## 重要な注意
本アプリは Windows 上の Powershell で実行するためテキストエンコーディングは UTF8 ではなく Shift-JIS を利用してください。

## アーキテクチャ概要

本アプリケーションは、クリーンアーキテクチャの原則に基づいて設計されています。

### レイヤー構成
- **Core層**: ビジネスロジックとドメインモデルを含む中核部分
  - `Common/`: Logger、ErrorHandler、ThreadSafeCollectionsなどの共通ユーティリティ
  - `Domain/`: ConnectionService、MessageService、ReceivedEventPipelineなどのドメインロジック
  - `Application/`: InstanceManager、NetworkAnalyzerなどのアプリケーションサービス
  - `Infrastructure/`: TcpClientAdapter、TcpServerAdapter、UdpAdapterなどのインフラストラクチャ実装
    - `Adapters/`: 通信プロトコルの実装
    - `Repositories/`: データアクセス層（RuleRepository、InstanceRepository）
- **Presentation層**: UI/MainForm.ps1によるWinFormsベースのユーザーインターフェース
- **ServiceContainer**: 依存性注入（DI）コンテナによる疎結合な設計

### 主要コンポーネント
- `ConnectionService`: 接続の作成、管理、状態監視を統括
- `MessageService`: テンプレート展開、変数処理、シナリオ実行を統合
- `ReceivedEventPipeline`: 受信データの処理パイプライン（AutoResponse、OnReceived、Unifiedルール対応）
- `RuleProcessor`: ルールマッチングとアクション実行
- 通信アダプター（TcpClient/Server、UDP）: プロトコル固有の実装を分離

## 特徴

- **複数接続の同時管理**: TCP/UDPの複数接続を同時に扱い、一元管理
- **シナリオ実行**: CSV形式のシナリオファイルで送受信シーケンスを定義
- **変数機能**: 受信データを変数として保存し、次回送信に動的に埋め込み
- **自動応答**: 受信パターンに応じた自動返信機能
- **データバンク**: よく使う電文をテンプレートとして管理し、ワンクリック送信
- **ネットワーク診断**: Ping/ポート疎通確認など、接続トラブルシューティング機能
- **GUIインターフェース**: WinFormsベースのシンプルで使いやすいUI

## 必要環境

- **OS**: Windows 10/11
- **PowerShell**: 5.1以降（Windows標準搭載）
- **.NET Framework**: Windows標準搭載
- **追加インストール**: 不要

## インストール

1. リポジトリをクローンまたはZIPでダウンロード
2. 任意のフォルダに展開
3. `TcpDebugger.ps1`を実行

```powershell
# 実行ポリシーを一時的に変更する場合
powershell.exe -ExecutionPolicy Bypass -File ".\TcpDebugger.ps1"

# または、現在のセッションで実行ポリシーを変更
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\TcpDebugger.ps1
```

## ディレクトリ構成

```
TcpDebugger/
├── TcpDebugger.ps1              # メインスクリプト（起動ファイル）
├── README.md                    # 本ファイル
├── DESIGN.md                    # 設計書
├── ARCHITECTURE_REFACTORING.md  # アーキテクチャリファレンス
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
│   │   ├── ReceivedRuleEngine.ps1       # ルールエンジン（AutoResponse/OnReceived）
│   │   ├── RuleProcessor.ps1            # ルール実行
│   │   ├── OnReceivedLibrary.ps1        # OnReceivedプロファイル管理
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
├── Config/                      # 設定ファイル
│   └── defaults.psd1
├── Instances/                   # 通信インスタンスフォルダ群
│   └── Example/                     # サンプルインスタンス
│       ├── instance.psd1            # インスタンス設定
│       ├── scenarios/               # シナリオファイル
│       │   ├── auto/                    # Auto Response用ルール
│       │   ├── onreceived/              # OnReceived用ルール＆スクリプト
│       │   └── periodic/                # Periodic Send用設定
│       └── templates/               # 電文テンプレート
│           ├── databank.csv
│           └── messages.csv
├── Docs/                        # ドキュメント
├── Tests/                       # テストコード
│   └── Unit/
└── Logs/                        # ログファイル出力先
```

## アーキテクチャと設計

### コア設計原則
本アプリケーションはクリーンアーキテクチャの原則に基づいて設計されており、以下の特徴を持ちます：

1. **レイヤー分離**: Core（ビジネスロジック）、Infrastructure（外部接続）、Presentation（UI）の明確な分離
2. **依存性注入**: ServiceContainerによるDIパターンで、テスタビリティと保守性を確保
3. **イベント駆動**: ReceivedEventPipelineによる一元化された受信処理パイプライン
4. **リポジトリパターン**: データアクセス層を抽象化し、キャッシュ管理を統一

### アーキテクチャの詳細
詳細な設計思想、アーキテクチャパターン、コンポーネント間の関係については、以下のドキュメントを参照してください：

- **DESIGN.md**: 機能要件、設計方針、データフォーマット、システム構成の詳細

## 使用方法

### 1. インスタンスの作成

`Instances/` フォルダ配下に新しいフォルダを作成し、`instance.psd1` ファイルを配置します。

**例: Instances/MyServer/instance.psd1**

```powershell
@{
    Id = "my-server"
    DisplayName = "My TCP Server"
    Description = "テスト用TCPサーバー"
    
    Connection = @{
        Protocol = "TCP"           # TCP/UDP
        Mode = "Server"           # Client/Server/Sender/Receiver
        LocalIP = "127.0.0.1"
        LocalPort = 9000
        RemoteIP = ""
        RemotePort = 0
    }
    
    AutoStart = $false
    AutoScenario = ""
    
    Tags = @("Test", "TCP")
    Group = "TestServers"
    
    DefaultEncoding = "UTF-8"
}
```

### 2. アプリケーションの起動

```powershell
.\TcpDebugger.ps1
```

GUIが起動し、`Instances/` 配下のインスタンスが自動的に読み込まれます。

### 3. 接続の開始

1. インスタンス一覧から接続したいインスタンスを選択
2. **Connect**ボタンをクリック
3. ステータス列が「CONNECTED」になれば接続成功

### 4. データ送信

`Instances/Example/scenarios/loop_test.csv` にはネストしたループを含むテストシナリオが用意されており、手動実行で動作を確認できます。

- **LOOP**: 指定ブロックを繰り返し実行します。`Parameter1` に `BEGIN` または `END` を指定し、`Parameter2` で回数 (`COUNT=3` など)、`Parameter3` で任意のラベル (`LABEL=outer` など) を指定します。ラベルを付けることでネストしたループも管理できます。
  ```csv
  1,LOOP,BEGIN,COUNT=2,LABEL=outer,Outer loop start
  2,LOOP,BEGIN,COUNT=3,LABEL=inner,Inner loop start
  3,SEND,Inner iteration ${TIMESTAMP},UTF-8,,Example payload
  4,LOOP,END,LABEL=inner,,Close inner loop
  5,LOOP,END,LABEL=outer,,Close outer loop
  ```
  既存の後方互換形式 (`LOOP,1,,COUNT=3` など) もサポートされますが、ネストには対応しません。

現在のバージョンでは、シナリオ機能を使用してデータを送信します。

**シナリオファイルの例: scenarios/simple_send.csv**

```csv
Step,Action,Parameter1,Parameter2,Parameter3,Description
1,SEND,Hello World!,UTF-8,,テキスト送信
2,WAIT_RECV,TIMEOUT=5000,,,応答待機
3,SAVE_RECV,VAR_NAME=response,,,受信データを保存
4,SEND,Echo: ${response},UTF-8,,受信データをエコーバック
```

### 5. シナリオの実行

PowerShellコンソールから以下のコマンドでシナリオを実行できます：

```powershell
# インスタンスのパスを指定
$scenarioPath = "C:\path\to\TcpDebugger\Instances\Example\scenarios\echo_test.csv"
$connectionId = "example-server"

# シナリオ実行
Start-Scenario -ConnectionId $connectionId -ScenarioPath $scenarioPath
```

### 6. 自動応答プロファイルの切り替え

- 各インスタンスフォルダの `scenarios/auto/` 配下に、受信トリガーと応答内容を定義したCSVファイルを配置します。
- 一覧画面の **Auto Response** 列からプロファイルを選択すると、選択中の接続に即座に適用されます。
- プロファイルを「(None)」に戻すと自動応答を無効化できます。

#### Auto Response列でのシナリオ実行

- Auto Responseのドロップダウンには、実行用シナリオも `? ファイル名` 形式で表示されます。
- シナリオ行を選択すると即座に `Start-Scenario` が呼び出され、セルの選択状態は直前のプロファイルに戻ります（設定が変わることはありません）。
- UI側で DataGridView のエラーが出ないようにバリデーションを強化しているため、安全にシナリオをトリガーできます。失敗した場合は従来通りメッセージボックスで通知されます。

#### 複数機能の同時利用

- **Auto Response**、**On Received**、**Periodic Send** の各列は完全に独立しています。任意の組み合わせでプロファイルを選択しても、ほかの列の設定が上書きされることはありません。
- Auto Responseで自動応答を設定しつつ、On Receivedでスクリプトをトリガーし、さらに Periodic Send で定周期電文を流すことができます。
- これらの設定は接続ごとに保持され、GUIを更新しても維持されます。適用に失敗した場合のみ警告ダイアログが表示され、元の設定へ自動的にロールバックされます。

**例: Instances/Example/scenarios/auto/normal.csv**

```csv
TriggerPattern,ResponseTemplate,Encoding,Delay,MatchType
PING,PONG,UTF-8,0,Exact
REQUEST,OK ${TIMESTAMP},UTF-8,100,Contains
```

**例: Instances/Example/scenarios/auto/error.csv**

```csv
TriggerPattern,ResponseTemplate,Encoding,Delay,MatchType
PING,ERROR_TIMEOUT,UTF-8,3000,Exact
REQUEST,ERROR 500,UTF-8,0,Contains
```

### 7. プロファイル列とグローバルロック

- DataGridView に **Profile** 列が追加され、`Config/column_profiles/*.csv` で定義した列プロファイル（Auto Response / On Received / Periodic をまとめたプリセット）を一括で適用できます。
- プロファイルを選択すると同一行の Auto Response / On Received / Periodic 設定が即座に更新され、接続変数としても記録されます。
- 画面左上にある **Profile** コンボ（Connect/Disconnect ボタンの横）でグローバルプロファイルを選ぶと、すべての行に同じプロファイルが適用され、対象列は読み取り専用になります。`(None)` を選び直すとロックが解除され、行ごとの編集に戻れます。
- 列プロファイルの追加入力テンプレートは `Config/column_profiles/default.csv` を参照してください。Auto/OnReceived/Periodic の列に対象シナリオ名を記述するだけで、新しいプリセットをGUIから選択できます。

## シナリオアクション

### 送信アクション

- **SEND**: テキストデータ送信（変数展開対応）
  ```csv
  1,SEND,Hello ${TIMESTAMP},UTF-8,,現在時刻を含む挨拶
  ```

- **SEND_HEX**: HEXデータ送信
  ```csv
  1,SEND_HEX,48656C6C6F,,,「Hello」をHEXで送信
  ```

- **SEND_FILE**: ファイル内容送信
  ```csv
  1,SEND_FILE,C:\data\test.bin,,,バイナリファイル送信
  ```

### 受信アクション

- **WAIT_RECV**: 受信待機
  ```csv
  1,WAIT_RECV,TIMEOUT=5000,PATTERN=OK,,「OK」を含むデータを待機
  ```

- **SAVE_RECV**: 受信データを変数に保存
  ```csv
  1,SAVE_RECV,VAR_NAME=mydata,,,受信データをmydata変数に保存
  ```

### 制御アクション

- **SLEEP**: 待機
  ```csv
  1,SLEEP,1000,,,1秒待機
  ```

- **SET_VAR**: 変数設定
  ```csv
  1,SET_VAR,counter,10,,counter変数に10を設定
  ```

- **TIMER_START / START_TIMER / TIMER_SEND**: タイマで定周期送信（非同期）
  ```csv
  1,TIMER_START,HEARTBEAT ${TIMESTAMP},INTERVAL=2000,NAME=hb,,2秒ごとにハートビート送信
  2,WAIT_RECV,TIMEOUT=5000,,,受信を待ちながらタイマ送信を継続
  3,TIMER_STOP,NAME=hb,,,登録済みタイマを停止
  ```
  - `Parameter1`: 送信メッセージ（変数展開可）
  - `Parameter2/3`: `INTERVAL=<ミリ秒>`、`DELAY=<初回遅延>`、`ENCODING=<文字コード>`、`NAME=<識別子>`、`COUNT=<送信回数>` などを指定可能

- **TIMER_STOP / STOP_TIMER**: タイマ停止（`Parameter1=ALL` で全停止）
  ```csv
  1,TIMER_STOP,ALL,,,登録済みタイマを全停止
  ```


- **CALL_SCRIPT**: カスタムスクリプト実行
  ```csv
  1,CALL_SCRIPT,Scripts\custom.ps1,,,外部スクリプト実行
  ```

- **DISCONNECT**: 切断
  ```csv
  1,DISCONNECT,,,,接続を切断
  ```

- **RECONNECT**: 再接続
  ```csv
  1,RECONNECT,,,,切断して再接続
  ```

## 変数展開

メッセージ内で以下の変数が使用できます：

- `${変数名}`: ユーザー定義変数（SAVE_RECVで保存したデータなど）
- `${TIMESTAMP}`: 現在時刻（yyyyMMddHHmmss形式）
- `${DATETIME:format}`: 書式指定日時
- `${RANDOM:min-max}`: ランダム値（例: `${RANDOM:1-100}`）
- `${SEQ:name}`: シーケンス番号（自動インクリメント）
- `${CALC:expression}`: 計算式評価

**例:**
```csv
1,SEND,TIME=${TIMESTAMP}|SEQ=${SEQ:main}|RAND=${RANDOM:1-100},UTF-8,,
```

## データバンク

`templates/databank.csv` でよく使う電文をテンプレート化できます。

```csv
DataID,Category,Description,Type,Content
HELLO,Basic,挨拶,TEXT,Hello!
PING,Health,疎通確認,TEXT,PING
STATUS,Status,ステータス要求,TEMPLATE,STATUS|TIME=${TIMESTAMP}
```

将来のバージョンでGUIからワンクリック送信機能を実装予定です。

## ネットワーク診断

PowerShellコンソールから診断機能を実行できます：

```powershell
# 接続IDを指定して診断実行
Invoke-ComprehensiveDiagnostics -ConnectionId "example-server"
```

実行結果：
- Ping疎通確認
- ポート開放状況
- ルーティング情報
- 推奨アクション

## トラブルシューティング

### 接続できない

1. ネットワーク診断を実行して問題箇所を特定
2. ファイアウォール設定を確認
3. 対象装置が起動しているか確認
4. IPアドレス、ポート番号が正しいか確認

### シナリオが実行されない

1. CSVファイルの形式が正しいか確認
2. ファイルパスが正しいか確認
3. エラーメッセージをコンソールで確認

### GUIが起動しない

1. PowerShell 5.1以降がインストールされているか確認
2. 実行ポリシーを確認: `Get-ExecutionPolicy`
3. モジュールファイルが正しく配置されているか確認

### Ctrl + C で終了したい

- PowerShellコンソールで `TcpDebugger.ps1` を実行している場合、`Ctrl + C` を押すとGUIに終了要求が送られ、自動的にフォームが閉じます。
- GUIが応答しない場合は、ウィンドウ右上の×ボタンで終了するか、別コンソールから `Stop-Process -Name powershell` などでプロセスを終了してください。

## 今後の拡張予定

- [ ] GUIからのシナリオ実行・停止（進行中）
- [ ] 受信ログの詳細表示機能の強化
- [ ] ログのエクスポート機能
- [ ] 複数インスタンスへの一括送信機能
- [ ] プロトコル解析プラグイン
- [ ] 性能測定機能の追加

## ライセンス

本ソフトウェアは教育・試験目的で提供されています。

## バージョン履歴

- **v1.1.0** (2025-11-24): アーキテクチャリファクタリング完了
  - クリーンアーキテクチャへの完全移行
  - 依存性注入（ServiceContainer）の導入
  - 受信イベントパイプラインの統合（ReceivedEventPipeline）
  - メッセージ処理の統一（MessageService）
  - レガシーコードの削除とコードベースの整理
  - プロファイル管理機能の強化（ProfileService/ProfileRepository）
  
- **v1.0.0** (2025-11-15): 初版リリース
  - 基本的なTCP/UDP通信機能
  - シナリオ実行エンジン
  - 変数機能・自動応答
  - WinFormsベースGUI
  - ネットワーク診断機能

## お問い合わせ

不具合や機能要望は、GitHubのIssuesでご報告ください。
