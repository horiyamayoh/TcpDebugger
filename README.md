# TCP Test Controller

TCP/UDP通信のテスト・デバッグを行うための試験装置です。設定ファイルベースでシナリオ実行が可能で、視覚的に接続状態を確認できるGUIを備えています。

## 重要な注意
本アプリは Windows 上の Powershell で実行するためテキストエンコーディングは UTF8 ではなく Shift-JIS を利用してください。

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
├── DESIGN.md                    # 設計書
├── README.md                    # 本ファイル
├── Modules/                     # 機能モジュール群
│   ├── ConnectionManager.ps1        # 接続管理
│   ├── TcpClient.ps1               # TCPクライアント
│   ├── TcpServer.ps1               # TCPサーバー
│   ├── UdpCommunication.ps1        # UDP通信
│   ├── ScenarioEngine.ps1          # シナリオ実行
│   ├── MessageHandler.ps1          # メッセージ処理
│   ├── AutoResponse.ps1            # 自動応答
│   ├── QuickSender.ps1             # クイック送信
│   ├── InstanceManager.ps1         # インスタンス管理
│   └── NetworkAnalyzer.ps1         # ネットワーク診断
├── Config/                      # 共通設定
│   └── defaults.psd1                # デフォルト設定
├── Instances/                   # 通信インスタンスフォルダ群
│   └── Example/                     # サンプルインスタンス
│       ├── instance.psd1            # インスタンス設定
│       ├── scenarios/               # シナリオファイル
│       │   └── echo_test.csv
│       └── templates/               # 電文テンプレート
│           ├── databank.csv
│           └── messages.csv
├── Scripts/                     # カスタムスクリプト（拡張用）
└── UI/                          # UI定義
    └── MainForm.ps1                # メインフォーム
```

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

## 今後の拡張予定

- [ ] GUIからのシナリオ実行・停止
- [ ] GUIからのクイック送信（データバンク連携）
- [ ] 受信ログの詳細表示
- [ ] ログのエクスポート機能
- [ ] 複数インスタンスへの一括送信
- [ ] プロトコル解析プラグイン
- [ ] 性能測定機能

## ライセンス

本ソフトウェアは教育・試験目的で提供されています。

## バージョン

- **v1.0.0** (2025-11-15): 初版リリース
  - 基本的なTCP/UDP通信機能
  - シナリオ実行エンジン
  - 変数機能・自動応答
  - WinFormsベースGUI
  - ネットワーク診断機能

## お問い合わせ

不具合や機能要望は、GitHubのIssuesでご報告ください。
