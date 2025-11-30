# TcpDebugger ユーザーマニュアル

## 目次

1. [はじめに](#1-はじめに)
2. [インストールと起動](#2-インストールと起動)
3. [基本的な使い方](#3-基本的な使い方)
4. [インスタンスの設定](#4-インスタンスの設定)
5. [電文テンプレートの作成](#5-電文テンプレートの作成)
6. [自動応答機能（On Receive: Reply）](#6-自動応答機能on-receive-reply)
7. [受信時スクリプト実行（On Receive: Script）](#7-受信時スクリプト実行on-receive-script)
8. [定周期送信（On Timer: Send）](#8-定周期送信on-timer-send)
9. [手動送信機能](#9-手動送信機能)
10. [OnReceiveScript ヘルパー関数リファレンス](#10-onreceivescript-ヘルパー関数リファレンス)
11. [実践的なサンプル](#11-実践的なサンプル)
12. [トラブルシューティング](#12-トラブルシューティング)

---

## 1. はじめに

### 1.1 TcpDebuggerとは

TcpDebuggerは、TCP/UDP通信のテスト・デバッグを行うためのPowerShellベースの試験ツールです。以下のような用途に最適です：

- 自作のTCP/IPプログラムの動作確認
- 通信プロトコルの試験・検証
- 外部装置の模擬（シミュレータ）
- 受信パターンに応じた自動応答
- 定周期での電文送信

### 1.2 主な機能

| 機能 | 説明 |
|------|------|
| **複数接続の同時管理** | TCP/UDPの複数接続を同時に管理 |
| **自動応答** | 受信パターンに応じて自動的に応答電文を送信 |
| **スクリプト実行** | 受信時にPowerShellスクリプトを実行 |
| **定周期送信** | 指定間隔で電文を自動送信 |
| **手動送信** | テンプレートからワンクリックで送信 |
| **変数展開** | タイムスタンプや連番を動的に埋め込み |

### 1.3 動作環境

- **OS**: Windows 10/11
- **PowerShell**: 5.1以降（Windows標準搭載）
- **追加インストール**: 不要

---

## 2. インストールと起動

### 2.1 インストール

1. リポジトリをクローンまたはZIPでダウンロード
2. 任意のフォルダに展開

```
TcpDebugger/
├── TcpDebugger.ps1      ← 起動ファイル
├── Core/                ← コアモジュール
├── Presentation/        ← UI
├── Instances/           ← 通信インスタンス定義
└── Docs/                ← ドキュメント
```

### 2.2 起動方法

```powershell
# PowerShellを管理者権限で開き、TcpDebuggerフォルダに移動

# 実行ポリシーを一時的に変更して起動
powershell.exe -ExecutionPolicy Bypass -File ".\TcpDebugger.ps1"

# または、現在のセッションで実行ポリシーを変更
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\TcpDebugger.ps1
```

### 2.3 GUIの概要

起動すると、メインウィンドウが表示されます：

```
┌────────────────────────────────────────────────────────────┐
│ [▶ Connect] [⏹ Disconnect]  Profile: [(None) ▼]           │
├────────────────────────────────────────────────────────────┤
│ Instance      │ Status    │ On Receive │ On Timer │ Send  │
│───────────────┼───────────┼────────────┼──────────┼───────│
│ Example TCP   │ CONNECTED │ normal ▼   │ hb ▼     │ 📤    │
│ Example2 TCP  │ DISCONN   │ (None) ▼   │ (None) ▼ │ 📤    │
└────────────────────────────────────────────────────────────┘
│ 接続状態: 1 / 2 Connected | 最終更新: 12:34:56            │
└────────────────────────────────────────────────────────────┘
```

---

## 3. 基本的な使い方

### 3.1 接続の開始

1. 一覧から接続したいインスタンスの行をクリック
2. **Connect** ボタンをクリック（または行内のConnectボタン）
3. ステータスが「CONNECTED」（緑）になれば成功

### 3.2 接続の終了

1. 切断したいインスタンスの行をクリック
2. **Disconnect** ボタンをクリック
3. ステータスが「DISCONNECTED」（グレー）に変わる

### 3.3 ステータスの色分け

| 色 | 状態 | 説明 |
|----|------|------|
| 🟢 緑 | CONNECTED | 接続済み・通信可能 |
| 🟡 黄 | CONNECTING | 接続中 |
| 🔴 赤 | ERROR | エラー発生 |
| ⚪ グレー | DISCONNECTED | 未接続 |

---

## 4. インスタンスの設定

### 4.1 インスタンスとは

「インスタンス」は1つの通信接続を表します。`Instances/` フォルダ配下にフォルダを作成するだけで、新しいインスタンスが追加されます。

```
Instances/
├── MyServer/           ← 新しいインスタンス
│   ├── instance.psd1   ← 設定ファイル（必須）
│   ├── scenarios/      ← シナリオ定義
│   └── templates/      ← 電文テンプレート
└── Example/            ← サンプルインスタンス
```

### 4.2 instance.psd1 の書き方

```powershell
@{
    # インスタンス識別子（一意であること）
    Id = "my-server-01"
    
    # UI表示名
    DisplayName = "My TCP Server"
    
    # 説明
    Description = "テスト用TCPサーバー"
    
    # 接続設定
    Connection = @{
        Protocol = "TCP"           # TCP または UDP
        Mode = "Server"            # Server / Client
        LocalIP = "0.0.0.0"        # バインドするIP（0.0.0.0で全IF）
        LocalPort = 8080           # 待ち受けポート
        RemoteIP = ""              # Clientモード時の接続先IP
        RemotePort = 0             # Clientモード時の接続先ポート
    }
    
    # 起動時設定
    AutoStart = $false             # アプリ起動時に自動接続
    
    # グループ・タグ（オプション）
    Group = "TestServers"
    Tags = @("TCP", "Test")
    
    # デフォルトエンコーディング
    DefaultEncoding = "UTF-8"
}
```

### 4.3 モードの種類

| モード | Protocol | 説明 |
|--------|----------|------|
| Server | TCP | 指定ポートで接続を待ち受け |
| Client | TCP | 指定のリモートホストに接続 |
| Sender | UDP | UDPパケット送信 |
| Receiver | UDP | UDPパケット受信 |

---

## 5. 電文テンプレートの作成

### 5.1 テンプレートファイル形式

電文テンプレートは `templates/` フォルダにCSV形式で配置します。

**例: templates/response.csv**
```csv
要素名,データ
ヘッダ,0001
データ長,0008
ペイロード,48656C6C6F21
```

- **要素名**: 説明用（実際の送信には影響なし）
- **データ**: 16進数文字列（スペース区切り可）

### 5.2 データ形式

```csv
要素名,データ
# 連続した16進数
例1,0102030405

# スペース区切り（読みやすさ向上）
例2,01 02 03 04 05

# ASCIIテキストをHEXで表現
Hello,48 65 6C 6C 6F
```

### 5.3 変数展開

テンプレート内で以下の変数が使用できます：

| 変数 | 説明 | 例 |
|------|------|-----|
| `${TIMESTAMP}` | 現在時刻 | 20251130123456 |
| `${DATETIME:format}` | 書式指定日時 | ${DATETIME:HHmmss} |
| `${RANDOM:min-max}` | ランダム値 | ${RANDOM:1-100} |
| `${SEQ:name}` | シーケンス番号 | ${SEQ:main} |

---

## 6. 自動応答機能（On Receive: Reply）

### 6.1 概要

受信電文のパターンに応じて、自動的に応答電文を送信する機能です。

### 6.2 ルールファイルの配置

```
Instances/MyServer/
└── scenarios/
    └── on_receive_reply/
        ├── normal.csv      ← 通常応答ルール
        └── error.csv       ← エラー応答ルール
```

### 6.3 ルールファイルの書き方

**例: scenarios/on_receive_reply/normal.csv**
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ResponseMessageFile,Delay
ログイン応答,0,2,0001,login_response.csv,0
データ要求応答,0,2,0010,data_response.csv,100
ハートビート,0,2,00FF,heartbeat_ack.csv,0
```

| 列名 | 必須 | 説明 |
|------|------|------|
| RuleName | 推奨 | ルール名（ログ出力用） |
| MatchOffset | ○ | マッチング開始位置（バイト） |
| MatchLength | ○ | マッチング長さ（バイト） |
| MatchValue | ○ | マッチさせる16進数値 |
| ResponseMessageFile | ○ | 応答電文ファイル（templates/からの相対パス） |
| Delay | - | 応答前の遅延（ミリ秒） |

### 6.4 マッチング例

受信データ: `00 01 12 34 56 78`

```csv
# オフセット0から2バイトが0001ならマッチ
MatchOffset=0, MatchLength=2, MatchValue=0001  → マッチ！

# オフセット2から2バイトが1234ならマッチ
MatchOffset=2, MatchLength=2, MatchValue=1234  → マッチ！
```

### 6.5 GUIでの設定

1. 接続一覧の **On Receive: Reply** 列のドロップダウンをクリック
2. 適用したいプロファイル（CSVファイル名）を選択
3. 即座に設定が反映される

---

## 7. 受信時スクリプト実行（On Receive: Script）

### 7.1 概要

受信電文に応じてPowerShellスクリプトを実行する機能です。単純な自動応答では対応できない複雑な処理が可能です。

### 7.2 ファイルの配置

```
Instances/MyServer/
└── scenarios/
    └── on_receive_script/
        ├── rules.csv           ← ルール定義
        ├── process_login.ps1   ← スクリプト
        └── copy_id.ps1         ← スクリプト
```

### 7.3 ルールファイルの書き方

**例: scenarios/on_receive_script/rules.csv**
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ScriptFile,Delay,ExecutionTiming
ログイン処理,0,2,0001,process_login.ps1,0,Before
ID転記,0,2,0010,copy_id.ps1,0,After
```

| 列名 | 必須 | 説明 |
|------|------|------|
| ScriptFile | ○ | 実行するスクリプトファイル |
| ExecutionTiming | - | `Before`=応答前 / `After`=応答後（デフォルト） |

### 7.4 スクリプトの書き方

スクリプトには `$Context` パラメータが渡されます：

```powershell
# scenarios/on_receive_script/my_script.ps1
param($Context)

# $Context に含まれる情報
# - $Context.ReceivedData   : 受信データ（byte[]）
# - $Context.ConnectionId   : 接続ID
# - $Context.Connection     : 接続オブジェクト
# - $Context.InstancePath   : インスタンスフォルダパス
# - $Context.Rule           : マッチしたルール情報
```

### 7.5 ExecutionTiming の使い分け

```
受信電文到着
    ↓
Before スクリプト実行 ← 応答前に変数を設定したい場合
    ↓
On Receive: Reply 送信
    ↓
After スクリプト実行  ← ログ記録など後処理
```

---

## 8. 定周期送信（On Timer: Send）

### 8.1 概要

指定した間隔で電文を自動送信する機能です。ハートビートやポーリングに使用します。

### 8.2 ファイルの配置

```
Instances/MyServer/
└── scenarios/
    └── on_timer_send/
        ├── heartbeat.csv    ← 定周期送信ルール
        └── polling.csv
```

### 8.3 ルールファイルの書き方

**例: scenarios/on_timer_send/heartbeat.csv**
```csv
RuleName,MessageFile,IntervalMs
ハートビート,heartbeat.csv,3000
ステータス確認,status_request.csv,5000
```

| 列名 | 必須 | 説明 |
|------|------|------|
| RuleName | 推奨 | ルール名 |
| MessageFile | ○ | 送信電文ファイル（templates/からの相対パス） |
| IntervalMs | ○ | 送信間隔（ミリ秒） |

### 8.4 GUIでの設定

1. 接続一覧の **On Timer: Send** 列のドロップダウンをクリック
2. 適用したいプロファイルを選択
3. 接続中であれば即座に定周期送信が開始

---

## 9. 手動送信機能

### 9.1 Manual: Send

テンプレートファイルを選択してワンクリックで送信します。

1. **Manual: Send** 列のドロップダウンからテンプレートを選択
2. 📤 ボタンをクリックして送信

### 9.2 Manual: Script

任意のPowerShellスクリプトを手動実行します。

1. **Manual: Script** 列のドロップダウンからスクリプトを選択
2. ▶ ボタンをクリックして実行

スクリプトは `scenarios/manual_scripts/` に配置します。

---

## 10. OnReceiveScript ヘルパー関数リファレンス

On Receive: Script で使用できるヘルパー関数の一覧です。

### 10.1 バイト操作

#### Get-ByteSlice
受信データから指定範囲を抽出します。

```powershell
# 構文
Get-ByteSlice -Data <byte[]> -Offset <int> -Length <int>

# 例: オフセット2から4バイトを取得
$id = Get-ByteSlice -Data $Context.ReceivedData -Offset 2 -Length 4
```

#### Set-ByteSlice
バイト配列の指定位置にデータを書き込みます。

```powershell
# 構文
Set-ByteSlice -Target <byte[]> -Offset <int> -Source <byte[]>

# 例: 応答電文のオフセット4にIDを書き込み
Set-ByteSlice -Target $response -Offset 4 -Source $id
```

#### ConvertTo-HexString
バイト配列を16進数文字列に変換します。

```powershell
# 構文
ConvertTo-HexString -Data <byte[]> [-Separator <string>]

# 例
$hex = ConvertTo-HexString -Data $bytes                    # "0102030A"
$hex = ConvertTo-HexString -Data $bytes -Separator " "     # "01 02 03 0A"
```

#### ConvertFrom-HexString
16進数文字列をバイト配列に変換します。

```powershell
# 構文
ConvertFrom-HexString -HexString <string>

# 例
$bytes = ConvertFrom-HexString -HexString "0102030A"
$bytes = ConvertFrom-HexString -HexString "01 02 03 0A"    # スペースは無視
```

### 10.2 メッセージ送受信

#### Read-MessageFile
電文テンプレートを読み込んでバイト配列を取得します。

```powershell
# 構文
Read-MessageFile -FilePath <string> [-InstancePath <string>]

# 例
$response = Read-MessageFile -FilePath "response.csv" -InstancePath $Context.InstancePath
```

#### Write-MessageFile
バイト配列を電文ファイルに書き込みます。

```powershell
# 構文
Write-MessageFile -Data <byte[]> -FilePath <string> [-InstancePath <string>]

# 例
Write-MessageFile -Data $modifiedData -FilePath "output.csv" -InstancePath $Context.InstancePath
```

#### Send-MessageFile
テンプレートファイルを読み込んで送信します。

```powershell
# 構文
Send-MessageFile -ConnectionId <string> -FilePath <string> [-InstancePath <string>]

# 例
Send-MessageFile -ConnectionId $Context.ConnectionId -FilePath "ack.csv" -InstancePath $Context.InstancePath
```

#### Send-MessageData
バイト配列を直接送信します。

```powershell
# 構文
Send-MessageData -ConnectionId <string> -Data <byte[]>

# 例
Send-MessageData -ConnectionId $Context.ConnectionId -Data $responseBytes
```

### 10.3 変数管理

#### Get-ConnectionVariable
接続ごとの変数を取得します。

```powershell
# 構文
Get-ConnectionVariable -Connection <object> -Name <string> [-Default <object>]

# 例
$counter = Get-ConnectionVariable -Connection $Context.Connection -Name "Counter" -Default 0
```

#### Set-ConnectionVariable
接続ごとの変数を設定します。

```powershell
# 構文
Set-ConnectionVariable -Connection <object> -Name <string> -Value <object>

# 例
Set-ConnectionVariable -Connection $Context.Connection -Name "Counter" -Value ($counter + 1)
```

### 10.4 ログ出力

#### Write-OnReceiveScriptLog
スクリプトからログを出力します。

```powershell
# 構文
Write-OnReceiveScriptLog <string>

# 例
Write-OnReceiveScriptLog "Received message ID: $messageId"
```

---

## 11. 実践的なサンプル

### 11.1 受信IDを応答に転記

受信電文のIDを応答電文にコピーするスクリプトです。

```powershell
# scenarios/on_receive_script/copy_id_reply.ps1
param($Context)

# 1. 受信データからID抽出（オフセット2から4バイト）
$receivedId = Get-ByteSlice -Data $Context.ReceivedData -Offset 2 -Length 4
Write-OnReceiveScriptLog "Received ID: $(ConvertTo-HexString $receivedId -Separator ' ')"

# 2. 応答テンプレートを読み込み
$response = Read-MessageFile -FilePath "ack_template.csv" -InstancePath $Context.InstancePath

# 3. 応答電文のオフセット2にIDを転記
Set-ByteSlice -Target $response -Offset 2 -Source $receivedId

# 4. 送信
Send-MessageData -ConnectionId $Context.ConnectionId -Data $response
```

### 11.2 シーケンス番号のカウント

接続ごとにシーケンス番号を管理し、応答に埋め込みます。

```powershell
# scenarios/on_receive_script/sequence_reply.ps1
param($Context)

# シーケンス番号をインクリメント
$seq = Get-ConnectionVariable -Connection $Context.Connection -Name "SeqNo" -Default 0
$seq++
Set-ConnectionVariable -Connection $Context.Connection -Name "SeqNo" -Value $seq

# 応答テンプレート読み込み
$response = Read-MessageFile -FilePath "response.csv" -InstancePath $Context.InstancePath

# シーケンス番号を2バイトのビッグエンディアンで埋め込み
$seqBytes = [BitConverter]::GetBytes([uint16]$seq)
[Array]::Reverse($seqBytes)  # ビッグエンディアンに変換
Set-ByteSlice -Target $response -Offset 6 -Source $seqBytes

Write-OnReceiveScriptLog "Reply with Seq=$seq"
Send-MessageData -ConnectionId $Context.ConnectionId -Data $response
```

### 11.3 受信内容に応じた分岐

受信電文の内容によって異なる応答を返します。

```powershell
# scenarios/on_receive_script/conditional_reply.ps1
param($Context)

# コマンド種別を取得（オフセット0から2バイト）
$cmdBytes = Get-ByteSlice -Data $Context.ReceivedData -Offset 0 -Length 2
$cmdHex = ConvertTo-HexString -Data $cmdBytes

switch ($cmdHex) {
    "0001" {
        Write-OnReceiveScriptLog "Login request received"
        Send-MessageFile -ConnectionId $Context.ConnectionId -FilePath "login_ack.csv" -InstancePath $Context.InstancePath
    }
    "0002" {
        Write-OnReceiveScriptLog "Logout request received"
        Send-MessageFile -ConnectionId $Context.ConnectionId -FilePath "logout_ack.csv" -InstancePath $Context.InstancePath
    }
    "0010" {
        Write-OnReceiveScriptLog "Data request received"
        # データ部分を抽出して処理
        $dataLength = $Context.ReceivedData.Length - 4
        if ($dataLength -gt 0) {
            $payload = Get-ByteSlice -Data $Context.ReceivedData -Offset 4 -Length $dataLength
            Write-OnReceiveScriptLog "Payload: $(ConvertTo-HexString $payload -Separator ' ')"
        }
        Send-MessageFile -ConnectionId $Context.ConnectionId -FilePath "data_ack.csv" -InstancePath $Context.InstancePath
    }
    default {
        Write-OnReceiveScriptLog "Unknown command: $cmdHex"
        Send-MessageFile -ConnectionId $Context.ConnectionId -FilePath "error.csv" -InstancePath $Context.InstancePath
    }
}
```

### 11.4 受信データの蓄積と集計

複数回の受信を集計するスクリプトです。

```powershell
# scenarios/on_receive_script/accumulate_data.ps1
param($Context)

# 受信カウントを取得・更新
$count = Get-ConnectionVariable -Connection $Context.Connection -Name "RecvCount" -Default 0
$count++
Set-ConnectionVariable -Connection $Context.Connection -Name "RecvCount" -Value $count

# 受信バイト数を累積
$totalBytes = Get-ConnectionVariable -Connection $Context.Connection -Name "TotalBytes" -Default 0
$totalBytes += $Context.ReceivedData.Length
Set-ConnectionVariable -Connection $Context.Connection -Name "TotalBytes" -Value $totalBytes

Write-OnReceiveScriptLog "Stats: Count=$count, TotalBytes=$totalBytes"

# 10回受信ごとにサマリーを出力
if ($count % 10 -eq 0) {
    Write-OnReceiveScriptLog "=== Summary: $count messages, $totalBytes bytes total ==="
}
```

---

## 12. トラブルシューティング

### 12.1 接続できない

| 症状 | 確認事項 |
|------|----------|
| ポートが使用中 | `netstat -an | findstr :8080` で確認 |
| ファイアウォール | Windows Defender ファイアウォールの設定確認 |
| IPアドレス誤り | instance.psd1 の LocalIP/RemoteIP を確認 |

### 12.2 自動応答が動作しない

1. **プロファイルが選択されているか確認**
   - On Receive: Reply 列が `(None)` になっていないか

2. **ルールファイルの形式を確認**
   - CSVのヘッダー行が正しいか
   - MatchValue が16進数文字列になっているか

3. **マッチング条件を確認**
   - MatchOffset, MatchLength が正しいか
   - 受信データをログで確認

### 12.3 スクリプトが実行されない

1. **スクリプトファイルのパスを確認**
   - `scenarios/on_receive_script/` 配下に配置されているか

2. **構文エラーを確認**
   - PowerShellコンソールでエラーメッセージを確認

3. **param($Context) を確認**
   - スクリプトの先頭に `param($Context)` があるか

### 12.4 定周期送信が動作しない

1. **接続状態を確認**
   - 接続が `CONNECTED` 状態か

2. **MessageFile のパスを確認**
   - templates/ フォルダにファイルが存在するか

3. **IntervalMs の値を確認**
   - 数値として正しく設定されているか

### 12.5 ログの確認

PowerShellコンソールに出力されるログを確認してください：

- `[OnReceive:Reply]` - 自動応答のログ
- `[OnReceive:Script]` - スクリプト実行のログ  
- `[OnTimerSend]` - 定周期送信のログ

---

## 付録

### A. ディレクトリ構成テンプレート

新しいインスタンスを作成する際のテンプレートです：

```
Instances/
└── NewInstance/
    ├── instance.psd1
    ├── profiles.csv                    # オプション
    ├── scenarios/
    │   ├── on_receive_reply/
    │   │   └── normal.csv
    │   ├── on_receive_script/
    │   │   ├── rules.csv
    │   │   └── my_script.ps1
    │   ├── on_timer_send/
    │   │   └── heartbeat.csv
    │   └── manual_scripts/
    │       └── test.ps1
    └── templates/
        ├── response.csv
        ├── heartbeat.csv
        └── error.csv
```

### B. CSVファイルのエンコーディング

すべてのCSVファイルは **UTF-8（BOMなし）** で保存してください。

### C. よく使うHEX値

| 文字 | HEX |
|------|-----|
| 0-9 | 30-39 |
| A-Z | 41-5A |
| a-z | 61-7A |
| スペース | 20 |
| CR | 0D |
| LF | 0A |
| NULL | 00 |

---

© 2025 TcpDebugger Project
