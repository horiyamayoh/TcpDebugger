# TCP Test Controller - 性能分析・改善設計書

**作成日**: 2025年11月20日  
**バージョン**: 1.0  
**対象アプリケーション**: TCP Test Controller v1.0

---

## 目次

1. [調査概要](#調査概要)
2. [性能ボトルネック分析](#性能ボトルネック分析)
3. [改善設計](#改善設計)
4. [実装計画](#実装計画)
5. [期待される効果](#期待される効果)

---

## 調査概要

### 調査目的
PowerShellベースのTCP/UDP通信試験ツールの性能ボトルネックを特定し、改善策を設計する。

### 調査対象コンポーネント
- **Presentation層**: UI更新ロジック（MainForm.ps1, ViewBuilder.ps1）
- **Core層**: Logger、MessageService、RunspaceMessageProcessor
- **Infrastructure層**: 通信アダプター、メッセージキュー

### 調査方法
- コードレビューによる静的分析
- アーキテクチャ構造の評価
- 処理フロー・頻度の分析

---

## 性能ボトルネック分析

### 1. UI更新処理の全行再描画 【重大】

#### 影響度
- **CPU使用率**: ★★★★★ (最大)
- **UI応答性**: ★★★★★ (最大)
- **ユーザー体験**: ★★★★☆ (大)

#### 問題の詳細

**場所**: `Presentation/UI/MainForm.ps1` (93-106行, 928-1100行)

```powershell
# 現在の実装
$timer = New-RefreshTimer -IntervalMilliseconds 2000
$timer.Add_Tick({
    if (-not $gridState.EditingInProgress -and -not $dgvInstances.IsCurrentCellInEditMode) {
        Update-InstanceList -DataGridView $dgvInstances  # 問題箇所
    }
    Update-LogDisplay -TextBox $txtLog -GetConnectionsCallback { Get-UiConnections }
})
```

**問題点**:
1. **2秒ごとに全行を削除・再作成**
   ```powershell
   $DataGridView.Rows.Clear()  # 全削除
   foreach ($conn in $connections) {
       Add-ConnectionRow -DataGridView $DataGridView -Connection $conn  # 全追加
   }
   ```

2. **各行で複雑なComboBoxセルを再構築**
   - Scenario列（AutoResponse）
   - OnReceived列
   - PeriodicSend列
   - QuickData列
   - QuickAction列

3. **影響**:
   - 画面のちらつき
   - 編集中のセル選択が失われる
   - CPU使用率の無駄な上昇
   - 接続数が増えるほど負荷が線形増加

#### 根本原因
- **状態管理の欠如**: 前回の描画状態と現在の状態を比較していない
- **粒度の粗さ**: 変更がない行も含めて全て再描画

---

### 2. ログ表示の非効率な全体再構築 【重大】

#### 影響度
- **CPU使用率**: ★★★★☆ (大)
- **UI応答性**: ★★★☆☆ (中)
- **メモリ使用量**: ★★★☆☆ (中)

#### 問題の詳細

**場所**: `Presentation/UI/ViewBuilder.ps1` (714-770行)

```powershell
function Update-LogDisplay {
    # 全接続のRecvBufferをスキャン
    foreach ($conn in $connections) {
        # Thread-Safeロック取得（接続数分繰り返し）
        [System.Threading.Monitor]::Enter($syncRoot)
        try {
            $snapshot = $conn.RecvBuffer.ToArray()
        } finally {
            [System.Threading.Monitor]::Exit($syncRoot)
        }
        
        # 各接続の最新10件を文字列化
        for ($i = $startIndex; $i -lt $count; $i++) {
            $summary = Get-MessageSummary -Data $recv.Data -MaxLength 40
            $logLines += "[$timeStr] $($conn.DisplayName) ← $summary"
        }
    }
    
    # 全体を文字列結合して再設定
    $TextBox.Text = $logLines -join "`r`n"
}
```

**問題点**:
1. **2秒ごとに全ログを再構築**
2. **複数のロック取得によるコンテンション**
3. **配列の文字列結合（O(n?)の可能性）**
4. **不要な重複処理**: 前回表示済みのエントリも再処理

#### 測定データ（想定）
- 10接続 × 10エントリ = 100行の処理
- 接続数が増えると処理時間が線形増加

---

### 3. Logger のファイルI/O頻度 【中】

#### 影響度
- **ディスクI/O**: ★★★★☆ (大)
- **CPU使用率**: ★★★☆☆ (中)
- **全体性能**: ★★☆☆☆ (小)

#### 問題の詳細

**場所**: `Core/Common/Logger.ps1` (90-96行)

```powershell
hidden [void] Log([string]$level, [string]$message, [hashtable]$context) {
    $entry = [PSCustomObject]@{
        Timestamp = (Get-Date).ToString("o")
        Level = $level
        Message = $message
        Context = $context
    }
    
    $json = $entry | ConvertTo-Json -Compress  # JSON変換
    
    [System.Threading.Monitor]::Enter($this._lock)
    try {
        Add-Content -Path $this.LogPath -Value $json  # ファイルI/O
    } finally {
        [System.Threading.Monitor]::Exit($this._lock)
    }
}
```

**問題点**:
1. **ログエントリごとにファイルOpen/Close**
2. **JSON変換のオーバーヘッド**
3. **ロック競合**: 複数スレッドからの同時書き込み

#### 影響範囲
- 通信量が多い場合（受信ログ、送信ログ）
- デバッグレベルのログが多い場合

---

### 4. CSV/テンプレートファイルの読み込み 【中】

#### 影響度
- **ディスクI/O**: ★★★☆☆ (中)
- **CPU使用率**: ★★☆☆☆ (小)
- **応答性**: ★★★☆☆ (中)

#### 問題の詳細

**場所**: 複数ファイル
- `Core/Domain/MessageService.ps1` (83行, 224行, 342行)
- `Core/Domain/ReceivedRuleEngine.ps1` (33行)
- `Core/Domain/ConnectionManager.ps1` (388行)

```powershell
# パターン1: テンプレート読み込み（キャッシュあり - 良い実装）
$content = Get-Content -Path $filePath -Encoding Default -Raw | ConvertFrom-Csv

# パターン2: シナリオ読み込み（キャッシュなし）
$content = Get-Content -Path $scenarioPath -Encoding Default -Raw
$steps = $content | ConvertFrom-Csv

# パターン3: ルールファイル読み込み（キャッシュなし）
$content = Get-Content -Path $FilePath -Encoding Default -Raw
$rules = $content | ConvertFrom-Csv
```

**問題点**:
1. **エンコーディング変換のオーバーヘッド** (Shift-JIS ⇔ Unicode)
2. **CSV解析の繰り返し実行**
3. **一部キャッシュ未実装**

**良い実装例**:
```powershell
# MessageService.LoadTemplate にはキャッシュ機能あり
if ($this._templateCache.ContainsKey($filePath)) {
    $cached = $this._templateCache[$filePath]
    if ($fileInfo.LastWriteTime -eq $cached.LastModified) {
        return $cached.Data  # キャッシュヒット
    }
}
```

---

### 5. RunspaceMessageProcessor の処理頻度 【低】

#### 影響度
- **CPU使用率**: ★★☆☆☆ (小)
- **応答性**: ★★★☆☆ (中)

#### 問題の詳細

**場所**: `Presentation/UI/MainForm.ps1` (78-90行)

```powershell
$messageTimer = New-Object System.Windows.Forms.Timer
$messageTimer.Interval = 100  # 100ms間隔
$messageTimer.Add_Tick({
    if ($Global:MessageProcessor) {
        $processed = $Global:MessageProcessor.ProcessMessages(50)  # 最大50件
    }
})
```

**問題点**:
1. **固定間隔**: メッセージ量に関わらず100msごとに起動
2. **固定バッチサイズ**: 常に最大50件を処理

#### 最適化の余地
- メッセージ量が少ない時は間隔を長くする
- メッセージ量が多い時はバッチサイズを増やす

---

### 6. RecvBuffer の無制限成長 【潜在的リスク】

#### 影響度
- **メモリ使用量**: ★★★★☆ (大 - 長期運用時)
- **GC圧力**: ★★★☆☆ (中)

#### 問題の詳細

**場所**: `Core/Domain/ReceivedEventPipeline.ps1` (59-60行)

```powershell
if ($connection.RecvBuffer) {
    [void]$connection.RecvBuffer.Add($entry)  # 無制限に追加
}
```

**問題点**:
1. **サイズ制限なし**: 長時間運用で無限に増加
2. **古いデータの削除なし**

#### 潜在的影響
- 長時間運用時のメモリリーク
- GC（ガベージコレクション）の頻度増加

---

### 7. Auto Response のルールマッチング処理 【重要】

#### 影響度
- **応答性**: ★★★★★ (最大)
- **CPU使用率**: ★★★★☆ (大)
- **スループット**: ★★★★☆ (大)

#### 問題の詳細

**場所**: `Core/Domain/ReceivedRuleEngine.ps1` (305-470行)

```powershell
function Invoke-AutoResponse {
    foreach ($rule in $Rules) {
        # 問題1: 毎回全ルールをスキャン
        if (-not (Test-ReceivedRuleMatch -ReceivedData $ReceivedData -Rule $rule)) {
            continue
        }
        
        # 問題2: マッチごとにテンプレートファイル読み込み
        $templates = Get-MessageTemplateCache -FilePath $messageFilePath
        
        # 問題3: 毎回HEX変換処理
        $responseBytes = ConvertTo-ByteArray -Data $template.Format -Encoding 'HEX'
        
        # 複数ルール対応: breakせずに継続
    }
}
```

**問題点**:

1. **全ルールの線形スキャン**
   - ルール数が増えるほど遅延が増加
   - マッチしないルールも全てチェック
   - O(n)の計算量

2. **テンプレートファイルの重複読み込み**
   ```powershell
   # Get-MessageTemplateCache にキャッシュ機能なし！
   $rawBytes = Get-Content -Path $FilePath -Encoding Byte -Raw  # ファイルI/O
   $csvText = $sjisEncoding.GetString($rawBytes)                # エンコーディング変換
   $rows = $csvText | ConvertFrom-Csv                           # CSV解析
   
   # 毎回HEX文字列を結合
   foreach ($row in $rows) {
       $hexStream += $row.$hexValue  # 文字列結合（O(n?)の可能性）
   }
   ```

3. **HEX変換の繰り返し実行**
   ```powershell
   # マッチのたびに実行
   $responseBytes = ConvertTo-ByteArray -Data $hexStream -Encoding 'HEX'
   # ↓
   for ($i = 0; $i -lt $hex.Length; $i += 2) {
       $hexByte = $hex.Substring($i, 2)
       $bytes += [Convert]::ToByte($hexByte, 16)
   }
   ```

4. **バイナリマッチングの非効率性**
   ```powershell
   function Test-BinaryRuleMatch {
       # 毎回HEX文字列をバイト配列に変換
       for ($i = 0; $i -lt $hexValue.Length; $i += 2) {
           $hexByte = $hexValue.Substring($i, 2)
           $matchBytes += [Convert]::ToByte($hexByte, 16)  # 毎回変換
       }
       
       # バイト単位で比較
       for ($i = 0; $i -lt $length; $i++) {
           if ($ReceivedData[$offset + $i] -ne $matchBytes[$i]) {
               return $false
           }
       }
   }
   ```

#### 測定データ（推定）

| ルール数 | 応答時間 | 備考 |
|---------|---------|------|
| 1個 | 10-20ms | テンプレート読み込み + HEX変換 |
| 5個 | 30-60ms | 全ルールスキャン |
| 10個 | 60-120ms | 線形増加 |
| 20個 | 120-240ms | **実用上の遅延が発生** |

**影響シナリオ**:
- 高頻度通信（100msg/sec）× ルール数10個 = 最大12秒/秒の処理遅延
- リアルタイム性が求められる通信で顕著
- CPUコア1つが80-100%使用される可能性

---

### 8. シナリオ実行のキャッシュなし 【中】

#### 影響度
- **応答性**: ★★★☆☆ (中)
- **ディスクI/O**: ★★★☆☆ (中)
- **並列性**: ★★★☆☆ (中)

#### 問題の詳細

**場所**: `Core/Domain/MessageService.ps1` (217-270行)

```powershell
[object[]] LoadScenario([string]$scenarioPath) {
    if (-not (Test-Path -LiteralPath $scenarioPath)) {
        throw "Scenario file not found: $scenarioPath"
    }
    
    # 問題: キャッシュ機能なし
    $content = Get-Content -Path $scenarioPath -Encoding Default -Raw
    $steps = $content | ConvertFrom-Csv
    $this._logger.LogInfo("Scenario loaded: $scenarioPath")
    return $steps
}

[void] StartScenario([string]$connectionId, [string]$scenarioPath) {
    // 毎回ファイル読み込み
    $scenarioSteps = $this.LoadScenario($scenarioPath)
    
    $scriptBlock = {
        param($connId, $steps, $svc, $log)
        # シナリオ実行（詳細実装は別箇所）
    }
    
    $runspace = [powershell]::Create()
    $null = $runspace.BeginInvoke()  # Fire and forget - 管理なし
}
```

**問題点**:

1. **シナリオファイルのキャッシュなし**
   - 同じシナリオを繰り返し実行時に毎回読み込み
   - CSV解析の重複実行
   - テンプレートにはキャッシュがあるのにシナリオにはない

2. **Runspace管理の欠如**
   - 作成したRunspaceを追跡していない
   - リソースリークの可能性
   - 複数シナリオ同時実行時の制御なし

3. **進捗・キャンセル機能なし**
   - 実行中のシナリオを停止できない
   - 進捗状況が不明

---

### 9. Get-MessageTemplateCache のキャッシュ未実装 【重大】

#### 影響度
- **応答性**: ★★★★★ (最大 - Auto Responseに直結)
- **ディスクI/O**: ★★★★☆ (大)
- **CPU使用率**: ★★★★☆ (大)

#### 問題の詳細

**場所**: `Core/Domain/MessageService.ps1` (314-370行)

```powershell
function Get-MessageTemplateCache {
    # 問題: 関数名は「Cache」だがキャッシュ機能なし！
    param([string]$FilePath, [switch]$ThrowOnMissing)
    
    if (-not (Test-Path -LiteralPath $FilePath)) {
        # エラー処理
    }
    
    # 毎回ファイルを読み込む
    $sjisEncoding = [System.Text.Encoding]::GetEncoding("Shift_JIS")
    $rawBytes = Get-Content -Path $FilePath -Encoding Byte -Raw
    $csvText = $sjisEncoding.GetString($rawBytes)
    $rows = $csvText | ConvertFrom-Csv
    
    # 毎回HEX文字列を結合
    $hexStream = ""
    foreach ($row in $rows) {
        $hexStream += $row.$hexValue  # 文字列結合
    }
    
    return @{ 'DEFAULT' = $template }
}
```

**問題点**:

1. **関数名詐欺**: 名前は`Cache`だがキャッシュしていない
2. **Auto ResponseのたびにファイルI/O**
   - 同じテンプレートを何度も読み込む
   - 1秒間に100回受信 = 100回のファイルI/O
3. **エンコーディング変換の繰り返し**
   - Shift-JIS → Unicode変換のオーバーヘッド
4. **HEX文字列結合の非効率性**
   - 文字列結合はO(n?)の可能性
   - StringBuilderを使用していない

#### 実測影響例（推定）

```powershell
# シナリオ: 10 Auto Responseルール、各ルールが異なるテンプレート使用
# 1回の受信で10回のテンプレート読み込み

# 1テンプレート読み込み = 5-10ms（ファイルI/O + CSV解析 + HEX結合）
# 10ルール × 10ms = 100ms/受信

# 100msg/sec × 100ms = 10秒/秒 → 処理が間に合わない！
```

---

## 改善設計

### 改善方針

#### 設計原則
1. **差分更新**: 変更があった部分のみ更新
2. **遅延評価**: 必要になるまで処理を遅延
3. **バッチ処理**: 複数の操作をまとめて実行
4. **キャッシュ活用**: 重複計算・I/Oを削減
5. **リソース制限**: メモリ・CPU使用量の上限設定
6. **事前コンパイル**: パターンマッチング・変換を事前処理

---

### 改善案 1: UI更新の差分描画 【優先度: 高】

#### 設計

**目的**: DataGridViewの全行再描画を差分更新に変更

**アプローチ**:
1. 前回の描画状態をキャッシュ
2. 現在の状態と比較
3. 変更があった行のみ更新

#### 実装設計

```powershell
# 新規関数: Update-InstanceListIncremental
function Update-InstanceListIncremental {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView
    )
    
    # 1. 現在のグリッド状態をマップに変換
    $currentRowMap = @{}
    foreach ($row in $DataGridView.Rows) {
        $connId = $row.Cells["Id"].Value
        if ($connId) {
            $currentRowMap[$connId] = $row
        }
    }
    
    # 2. 最新の接続リストを取得
    $connections = Get-UiConnections
    $newConnIds = [System.Collections.Generic.HashSet[string]]::new()
    
    # 3. 接続ごとに処理
    foreach ($conn in $connections) {
        $connId = $conn.Id
        [void]$newConnIds.Add($connId)
        
        if ($currentRowMap.ContainsKey($connId)) {
            # 既存行 → 値のみ更新
            Update-ConnectionRow -Row $currentRowMap[$connId] -Connection $conn
        } else {
            # 新規行 → 追加
            Add-ConnectionRow -DataGridView $DataGridView -Connection $conn
        }
    }
    
    # 4. 削除された接続の行を削除
    $rowsToRemove = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $DataGridView.Rows) {
        $connId = $row.Cells["Id"].Value
        if ($connId -and -not $newConnIds.Contains($connId)) {
            $rowsToRemove.Add($row)
        }
    }
    
    foreach ($row in $rowsToRemove) {
        $DataGridView.Rows.Remove($row)
    }
}

# 新規関数: Update-ConnectionRow（既存行の値のみ更新）
function Update-ConnectionRow {
    param($Row, $Connection)
    
    # ステータスのみ更新（ComboBoxは変更しない）
    $endpoint = Get-ConnectionEndpoint -Connection $Connection
    $status = $Connection.Status
    
    # 値が変更された場合のみセルを更新
    if ($Row.Cells["Status"].Value -ne $status) {
        $Row.Cells["Status"].Value = $status
        Set-RowColor -Row $Row -Status $status
    }
    
    if ($Row.Cells["Endpoint"].Value -ne $endpoint) {
        $Row.Cells["Endpoint"].Value = $endpoint
    }
    
    # ComboBoxの選択値は保持（ユーザーが変更した可能性があるため）
}
```

#### 期待される効果
- **CPU削減**: 約70-80%（接続数10の場合）
- **ちらつき削減**: 完全に解消
- **応答性向上**: 体感で明確に改善

---

### 改善案 2: ログ表示の増分更新 【優先度: 高】

#### 設計

**目的**: ログ全体の再構築を増分追加に変更

**アプローチ**:
1. 前回の表示位置を記憶
2. 新規エントリのみを追加
3. 古いエントリは自動削除（リングバッファ方式）

#### 実装設計

```powershell
# モジュールレベル変数
$script:LogDisplayState = @{
    LastUpdateTime = [DateTime]::MinValue
    DisplayedEntryIds = [System.Collections.Generic.HashSet[string]]::new()
    MaxLines = 100
}

function Update-LogDisplayIncremental {
    param(
        [System.Windows.Forms.TextBox]$TextBox,
        [scriptblock]$GetConnectionsCallback
    )
    
    if (-not $TextBox) { return }
    
    $newLines = [System.Collections.Generic.List[string]]::new()
    $connections = & $GetConnectionsCallback
    
    foreach ($conn in $connections) {
        if (-not $conn.RecvBuffer -or $conn.RecvBuffer.Count -eq 0) {
            continue
        }
        
        # 最新エントリのみを取得（前回以降）
        $syncRoot = $conn.RecvBuffer.SyncRoot
        [System.Threading.Monitor]::Enter($syncRoot)
        try {
            $snapshot = $conn.RecvBuffer.ToArray()
        } finally {
            [System.Threading.Monitor]::Exit($syncRoot)
        }
        
        foreach ($recv in $snapshot) {
            # タイムスタンプベースのフィルタリング
            if ($recv.Timestamp -le $script:LogDisplayState.LastUpdateTime) {
                continue
            }
            
            $summary = Get-MessageSummary -Data $recv.Data -MaxLength 40
            $timeStr = $recv.Timestamp.ToString("HH:mm:ss")
            $line = "[$timeStr] $($conn.DisplayName) ← $summary ($($recv.Length) bytes)"
            [void]$newLines.Add($line)
        }
    }
    
    if ($newLines.Count -gt 0) {
        # 新規行を追加
        $currentLines = if ($TextBox.Text) {
            $TextBox.Text -split "`r`n"
        } else {
            @()
        }
        
        # StringBuilder使用で高速化
        $sb = [System.Text.StringBuilder]::new()
        
        # 古い行 + 新しい行
        $allLines = $currentLines + $newLines
        
        # 最大行数を超えた場合は古い行を削除
        $startIndex = [Math]::Max(0, $allLines.Count - $script:LogDisplayState.MaxLines)
        for ($i = $startIndex; $i -lt $allLines.Count; $i++) {
            [void]$sb.AppendLine($allLines[$i])
        }
        
        $TextBox.Text = $sb.ToString()
        $TextBox.SelectionStart = $TextBox.Text.Length
        $TextBox.ScrollToCaret()
    }
    
    $script:LogDisplayState.LastUpdateTime = Get-Date
}
```

#### 期待される効果
- **CPU削減**: 約60-70%
- **文字列処理高速化**: StringBuilder使用で2-3倍高速
- **ロック競合削減**: 新規エントリのみスキャン

---

### 改善案 3: Logger のバッファリング 【優先度: 中】

#### 設計

**目的**: ファイルI/O頻度を削減

**アプローチ**:
1. ログエントリをメモリバッファに蓄積
2. 一定件数または一定時間ごとにまとめて書き込み
3. アプリケーション終了時にフラッシュ

#### 実装設計

```powershell
class BufferedLogger : Logger {
    hidden [System.Collections.Concurrent.ConcurrentQueue[string]]$_buffer
    hidden [int]$_bufferSize
    hidden [int]$_flushThreshold
    hidden [System.Timers.Timer]$_flushTimer
    
    BufferedLogger(
        [string]$logPath,
        [string]$name = "TcpDebugger",
        [int]$flushThreshold = 50,      # 50件でフラッシュ
        [int]$flushIntervalMs = 5000    # 5秒でフラッシュ
    ) : base($logPath, $name) {
        $this._buffer = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
        $this._bufferSize = 0
        $this._flushThreshold = $flushThreshold
        
        # 定期フラッシュタイマー
        $this._flushTimer = [System.Timers.Timer]::new($flushIntervalMs)
        $this._flushTimer.AutoReset = $true
        $this._flushTimer.add_Elapsed({
            param($sender, $args)
            $this.Flush()
        }.GetNewClosure())
        $this._flushTimer.Start()
    }
    
    hidden [void] Log([string]$level, [string]$message, [hashtable]$context) {
        $entry = [PSCustomObject]@{
            Timestamp = (Get-Date).ToString("o")
            Level = $level
            Message = $message
            Context = $context
            Logger = $this.Name
            ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }
        
        $json = $entry | ConvertTo-Json -Compress
        $this._buffer.Enqueue($json)
        
        # インクリメント（スレッドセーフ）
        [System.Threading.Interlocked]::Increment([ref]$this._bufferSize)
        
        # 閾値チェック
        if ($this._bufferSize -ge $this._flushThreshold) {
            $this.Flush()
        }
    }
    
    [void] Flush() {
        if ($this._bufferSize -eq 0) {
            return
        }
        
        $entries = [System.Collections.Generic.List[string]]::new()
        $item = $null
        
        # バッファから全て取り出し
        while ($this._buffer.TryDequeue([ref]$item)) {
            $entries.Add($item)
            [System.Threading.Interlocked]::Decrement([ref]$this._bufferSize)
        }
        
        if ($entries.Count -eq 0) {
            return
        }
        
        # 一括書き込み
        [System.Threading.Monitor]::Enter($this._lock)
        try {
            $content = $entries -join "`n"
            Add-Content -Path $this.LogPath -Value $content -NoNewline
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }
    }
    
    [void] Dispose() {
        $this._flushTimer.Stop()
        $this._flushTimer.Dispose()
        $this.Flush()  # 最後にフラッシュ
    }
}
```

#### 期待される効果
- **ディスクI/O削減**: 約90%（50件 → 1回）
- **ロック競合削減**: 大幅に削減
- **スループット向上**: 2-3倍

---

### 改善案 4: UI更新タイマー間隔の最適化 【優先度: 高】

#### 設計

**現状**: 2秒固定
**改善**: 3-5秒に延長（または適応的調整）

#### 実装設計

```powershell
# 即座に適用可能な変更
$timer = New-RefreshTimer -IntervalMilliseconds 3000  # 2秒 → 3秒

# または、適応的な間隔調整
$script:AdaptiveTimerState = @{
    MinInterval = 2000   # 最小2秒
    MaxInterval = 10000  # 最大10秒
    CurrentInterval = 3000
    LastChangeCount = 0
}

function Adjust-TimerInterval {
    param($Timer, $ChangeCount)
    
    # 変更が多い → 間隔を短く
    if ($ChangeCount -gt 5) {
        $newInterval = [Math]::Max(
            $script:AdaptiveTimerState.MinInterval,
            $script:AdaptiveTimerState.CurrentInterval - 500
        )
    }
    # 変更が少ない → 間隔を長く
    elseif ($ChangeCount -eq 0) {
        $newInterval = [Math]::Min(
            $script:AdaptiveTimerState.MaxInterval,
            $script:AdaptiveTimerState.CurrentInterval + 1000
        )
    }
    else {
        return  # 変更なし
    }
    
    if ($newInterval -ne $script:AdaptiveTimerState.CurrentInterval) {
        $script:AdaptiveTimerState.CurrentInterval = $newInterval
        $Timer.Interval = $newInterval
    }
}
```

#### 期待される効果
- **CPU削減**: 約30-40%（即効性）
- **バッテリー寿命向上**: ノートPC使用時

---

### 改善案 5: RecvBuffer のサイズ制限 【優先度: 中】

#### 設計

**目的**: メモリリークを防止

**アプローチ**: リングバッファ方式（FIFO）

#### 実装設計

```powershell
# ReceivedEventPipeline.ProcessEvent 内
[void] ProcessEvent([string]$connectionId, [byte[]]$data, [hashtable]$metadata) {
    # ... (既存処理)
    
    try {
        if ($connection.RecvBuffer) {
            # サイズ制限チェック
            $maxBufferSize = 1000  # 最大1000エントリ
            
            $syncRoot = $connection.RecvBuffer.SyncRoot
            [System.Threading.Monitor]::Enter($syncRoot)
            try {
                # 追加
                [void]$connection.RecvBuffer.Add($entry)
                
                # サイズ超過時は古いエントリを削除
                while ($connection.RecvBuffer.Count -gt $maxBufferSize) {
                    $connection.RecvBuffer.RemoveAt(0)
                }
            }
            finally {
                [System.Threading.Monitor]::Exit($syncRoot)
            }
        }
    }
    catch {
        $this._logger.LogWarning("Failed to update receive buffer", @{
            ConnectionId = $connection.Id
            Error = $_.Exception.Message
        })
    }
}
```

#### 設定の外部化

```powershell
# Config/defaults.psd1 に追加
@{
    Performance = @{
        MaxRecvBufferSize = 1000     # 受信バッファの最大エントリ数
        MaxLogDisplayLines = 100      # ログ表示の最大行数
        UIRefreshIntervalMs = 3000    # UI更新間隔（ミリ秒）
        LogFlushThreshold = 50        # ログフラッシュ閾値
        LogFlushIntervalMs = 5000     # ログフラッシュ間隔（ミリ秒）
    }
}
```

#### 期待される効果
- **メモリ使用量削減**: 一定に保たれる
- **長期運用の安定性**: 向上

---

### 改善案 6: Auto Response テンプレートキャッシュの実装 【優先度: 最高】

#### 設計

**目的**: Get-MessageTemplateCacheに真のキャッシュ機能を実装

**アプローチ**:
1. **ファイル更新検知**: `LastWriteTimeUtc`でファイル変更を自動検知
2. **自動キャッシュ無効化**: ファイル更新時に自動的にキャッシュを再読み込み
3. **事前変換**: テンプレート読み込み時にバイト配列まで事前変換
4. **HEX結合高速化**: StringBuilderで高速化

**既存実装の流用**: `RuleRepository.ps1`と同じパターン（実績あり）

#### ファイル更新検知の仕組み

```plaintext
■ 初回アクセス
1. ファイルを読み込み（5-10ms）
2. LastWriteTimeUtc = 2025-11-20 10:00:00 として保存
3. キャッシュに保存

■ 2回目アクセス（ファイル未更新）
1. キャッシュをチェック
2. LastWriteTimeUtc一致 → キャッシュHIT（0.1ms）← 高速！
3. キャッシュから返す

■ ファイル更新後
1. エディタでファイル保存 → LastWriteTimeUtc = 2025-11-20 10:05:00 に更新
2. キャッシュをチェック
3. LastWriteTimeUtc不一致 → キャッシュMISS
4. ファイルを再読み込み（5-10ms）← 自動的に最新版を取得
5. 新しいLastWriteTimeUtcでキャッシュ更新
```

#### 実装設計

```powershell
# グローバルキャッシュ（モジュールレベル）
$script:MessageTemplateCache = @{}
$script:MessageTemplateCacheLock = [object]::new()

function Get-MessageTemplateCache {
    <#
    .SYNOPSIS
    電文テンプレートをファイル更新検知付きキャッシュで読み込む
    
    .DESCRIPTION
    ファイルのLastWriteTimeUtcを監視し、更新時は自動的にキャッシュを無効化して再読み込み。
    アプリ実行中にテンプレートファイルを編集しても、次回アクセス時に最新版が反映される。
    
    .PARAMETER FilePath
    テンプレートファイルのパス
    
    .PARAMETER ThrowOnMissing
    ファイルが見つからない場合にエラーをスロー
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [switch]$ThrowOnMissing
    )
    
    if (-not (Test-Path -LiteralPath $FilePath)) {
        if ($ThrowOnMissing) {
            throw "Template file not found: $FilePath"
        }
        return @{}
    }
    
    $resolvedPath = (Resolve-Path -LiteralPath $FilePath).Path
    $fileInfo = Get-Item -LiteralPath $resolvedPath
    $lastWriteTime = $fileInfo.LastWriteTimeUtc  # ← ファイル更新時刻を取得
    $cacheKey = $resolvedPath.ToLowerInvariant()
    
    # キャッシュチェック（スレッドセーフ）
    [System.Threading.Monitor]::Enter($script:MessageTemplateCacheLock)
    try {
        if ($script:MessageTemplateCache.ContainsKey($cacheKey)) {
            $cached = $script:MessageTemplateCache[$cacheKey]
            # ファイル更新時刻が一致すればキャッシュ有効
            if ($cached.LastWriteTimeUtc -eq $lastWriteTime) {
                # キャッシュHIT！（0.1ms）
                Write-Debug "[TemplateCache] HIT: $FilePath"
                return $cached.Templates
            }
            # 更新時刻不一致 → ファイルが更新された → キャッシュ無効
            Write-Debug "[TemplateCache] INVALIDATED (file updated): $FilePath"
        }
    }
    finally {
        [System.Threading.Monitor]::Exit($script:MessageTemplateCacheLock)
    }
    
    # キャッシュMISS - ファイル読み込み（5-10ms）
    Write-Debug "[TemplateCache] MISS: $FilePath (loading from disk)"
    
    $sjisEncoding = [System.Text.Encoding]::GetEncoding("Shift_JIS")
    $rawBytes = Get-Content -Path $resolvedPath -Encoding Byte -Raw
    $csvText = $sjisEncoding.GetString($rawBytes)
    $rows = $csvText | ConvertFrom-Csv
    
    if (-not $rows -or $rows.Count -eq 0) {
        return @{}
    }
    
    # StringBuilder使用でHEX文字列結合を高速化
    $sb = [System.Text.StringBuilder]::new()
    foreach ($row in $rows) {
        $properties = $row.PSObject.Properties.Name
        if ($properties.Count -ge 2) {
            $hexValue = $properties[1]
            [void]$sb.Append($row.$hexValue)
        }
    }
    $hexStream = $sb.ToString()
    
    # 事前にバイト配列に変換（HEX変換のオーバーヘッド削減）
    $responseBytes = ConvertTo-ByteArray -Data $hexStream -Encoding 'HEX'
    
    $template = [PSCustomObject]@{
        Name = 'DEFAULT'
        Format = $hexStream        # HEX文字列（デバッグ用）
        Bytes = $responseBytes     # 事前変換済みバイト配列（高速送信用）
    }
    
    $templates = @{ 'DEFAULT' = $template }
    
    # キャッシュに保存（更新時刻付き）
    [System.Threading.Monitor]::Enter($script:MessageTemplateCacheLock)
    try {
        $script:MessageTemplateCache[$cacheKey] = @{
            LastWriteTimeUtc = $lastWriteTime  # ← 更新時刻を保存
            Templates = $templates
        }
    }
    finally {
        [System.Threading.Monitor]::Exit($script:MessageTemplateCacheLock)
    }
    
    return $templates
}

# 開発時用: 手動キャッシュクリア関数
function Clear-MessageTemplateCache {
    <#
    .SYNOPSIS
    テンプレートキャッシュを手動でクリア（開発・デバッグ用）
    
    .PARAMETER FilePath
    クリアするファイルパス（省略時は全キャッシュクリア）
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$FilePath
    )
    
    [System.Threading.Monitor]::Enter($script:MessageTemplateCacheLock)
    try {
        if ([string]::IsNullOrWhiteSpace($FilePath)) {
            # 全キャッシュクリア
            $count = $script:MessageTemplateCache.Count
            $script:MessageTemplateCache.Clear()
            Write-Host "All template cache cleared ($count entries)" -ForegroundColor Yellow
        }
        else {
            # 特定ファイルのキャッシュクリア
            $resolvedPath = (Resolve-Path -LiteralPath $FilePath -ErrorAction SilentlyContinue).Path
            if ($resolvedPath) {
                $key = $resolvedPath.ToLowerInvariant()
                if ($script:MessageTemplateCache.ContainsKey($key)) {
                    $null = $script:MessageTemplateCache.Remove($key)
                    Write-Host "Template cache cleared: $FilePath" -ForegroundColor Yellow
                }
            }
        }
    }
    finally {
        [System.Threading.Monitor]::Exit($script:MessageTemplateCacheLock)
    }
}

# Invoke-BinaryAutoResponse を改善
function Invoke-BinaryAutoResponse {
    param(
        [string]$ConnectionId,
        [object]$Rule,
        [object]$Connection
    )
    
    # ... (パス解決は同じ)
    
    # テンプレート取得（キャッシュ利用）
    $templates = Get-MessageTemplateCache -FilePath $messageFilePath -ThrowOnMissing
    $template = $templates['DEFAULT']
    
    # 事前変換済みバイト配列を直接使用
    $responseBytes = $template.Bytes  # HEX変換不要！
    
    # 送信
    Send-Data -ConnectionId $ConnectionId -Data $responseBytes
}
```

#### 期待される効果
- **応答時間削減**: 約80-90%
  - 10-20ms → 2-3ms（キャッシュヒット時）
  - 初回のみ5-10ms（ファイル読み込み）
  - ファイル更新後も自動的に最新版を読み込み
- **ディスクI/O削減**: 約99%（同一テンプレート使用時）
- **CPU使用率削減**: 約70%（HEX変換の事前実行）
- **開発効率向上**: アプリ再起動不要でテンプレート編集が即反映

---


### 改善案 7: ルールマッチング処理の最適化 【優先度: 高】

#### 設計

**目的**: バイナリマッチング処理の高速化

**アプローチ**:
1. マッチングパターンの事前コンパイル（バイト配列化）
2. 早期リターン（マッチ後の不要なスキャン停止オプション）
3. マッチング頻度の高いルールを優先

#### 実装設計

```powershell
# Read-ReceivedRules でルールを事前コンパイル
function Read-ReceivedRules {
    param([string]$FilePath, [string]$RuleType = "Auto")
    
    # ... (既存のCSV読み込み)
    
    foreach ($rule in $rules) {
        # ... (既存のメタデータ追加)
        
        # バイナリマッチングパターンを事前変換
        if ($rule.__MatchType -eq 'Binary' -and 
            -not [string]::IsNullOrWhiteSpace($rule.MatchValue)) {
            
            $hexValue = $rule.MatchValue.Trim() -replace '\s', '' -replace '0x', ''
            
            # 事前にバイト配列に変換
            $matchBytes = @()
            for ($i = 0; $i -lt $hexValue.Length; $i += 2) {
                $hexByte = $hexValue.Substring($i, 2)
                $matchBytes += [Convert]::ToByte($hexByte, 16)
            }
            
            # ルールに事前変換済みバイト配列を追加
            $rule | Add-Member -NotePropertyName '__MatchBytes' `
                               -NotePropertyValue $matchBytes `
                               -Force
        }
    }
    
    return $rules
}

# Test-BinaryRuleMatch を高速化
function Test-BinaryRuleMatch {
    param(
        [byte[]]$ReceivedData,
        [object]$Rule
    )
    
    # ... (既存のバリデーション)
    
    $offset = [int]($Rule.MatchOffset)
    $length = [int]($Rule.MatchLength)
    
    # 事前変換済みバイト配列を使用（HEX変換不要！）
    $matchBytes = $Rule.__MatchBytes
    
    # バイト比較（高速）
    for ($i = 0; $i -lt $length; $i++) {
        if ($ReceivedData[$offset + $i] -ne $matchBytes[$i]) {
            return $false
        }
    }
    
    return $true
}
```

#### 期待される効果
- **マッチング時間削減**: 約50-60%
  - 5-10ms → 2-4ms（HEX変換の事前実行）
- **ルール数10個の場合**: 応答時間 60-120ms → 20-40ms

---

### 改善案 8: CSV読み込みキャッシュの拡充 【優先度: 中】

#### 設計

**目的**: シナリオファイルの重複読み込み削減（ルールファイルは既にキャッシュ実装済み）

**対象**:
- シナリオファイル（`LoadScenario` - 現在キャッシュなし）
- ~~ルールファイル~~（`RuleRepository` - 既にファイル更新検知付きキャッシュ実装済み）

**既存実装の流用**: `RuleRepository.ps1`と同じパターンを適用

#### 実装設計（シナリオファイル）

```powershell
# MessageService クラスにシナリオキャッシュを追加
class MessageService {
    hidden [hashtable]$_scenarioCache
    hidden [object]$_scenarioCacheLock
    
    MessageService([Logger]$logger, [ConnectionService]$connectionService) {
        $this._logger = $logger
        $this._connectionService = $connectionService
        $this._templateCache = @{}
        $this._scenarioCache = @{}  # ← シナリオキャッシュ追加
        $this._scenarioCacheLock = [object]::new()
        $this._customVariableHandlers = @{}
    }
    
    # ファイル更新検知付きシナリオ読み込み
    [object[]] LoadScenario([string]$scenarioPath) {
        if (-not (Test-Path -LiteralPath $scenarioPath)) {
            throw "Scenario file not found: $scenarioPath"
        }
        
        $resolved = (Resolve-Path -LiteralPath $scenarioPath).Path
        $fileInfo = Get-Item -LiteralPath $resolved
        $lastWrite = $fileInfo.LastWriteTimeUtc  # ← ファイル更新時刻取得
        $key = $resolved.ToLowerInvariant()
        
        # キャッシュチェック
        $cached = $this.TryGetCachedScenario($key, $lastWrite)
        if ($cached) {
            $this._logger.LogDebug("Scenario cache HIT: $scenarioPath")
            return $cached  # ファイル未更新ならキャッシュから返す
        }
        
        $this._logger.LogDebug("Scenario cache MISS: $scenarioPath (loading from file)")
        
        # ファイル読み込み（既存ロジック）
        $content = Get-Content -Path $resolved -Encoding Default -Raw
        $steps = $content | ConvertFrom-Csv
        
        # キャッシュに保存（更新時刻付き）
        $this.SetScenarioCache($key, $lastWrite, $steps)
        
        $this._logger.LogInfo("Scenario loaded: $scenarioPath ($($steps.Count) steps)")
        return $steps
    }
    
    hidden [object[]] TryGetCachedScenario([string]$key, [datetime]$lastWrite) {
        [System.Threading.Monitor]::Enter($this._scenarioCacheLock)
        try {
            if ($this._scenarioCache.ContainsKey($key)) {
                $entry = $this._scenarioCache[$key]
                # ファイル更新時刻が一致すればキャッシュ有効
                if ($entry.LastWriteTimeUtc -eq $lastWrite) {
                    return $entry.Steps
                }
                # 更新時刻不一致 → ファイルが更新された → キャッシュ無効
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($this._scenarioCacheLock)
        }
        return $null
    }
    
    hidden [void] SetScenarioCache([string]$key, [datetime]$lastWrite, [object[]]$steps) {
        [System.Threading.Monitor]::Enter($this._scenarioCacheLock)
        try {
            $this._scenarioCache[$key] = @{
                LastWriteTimeUtc = $lastWrite  # ← 更新時刻を保存
                Steps = $steps
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($this._scenarioCacheLock)
        }
    }
    
    # 開発時用: シナリオキャッシュクリア
    [void] ClearScenarioCache([string]$scenarioPath) {
        if ([string]::IsNullOrWhiteSpace($scenarioPath)) {
            return
        }
        
        $resolved = $scenarioPath
        if (Test-Path -LiteralPath $scenarioPath) {
            $resolved = (Resolve-Path -LiteralPath $scenarioPath).Path
        }
        $key = $resolved.ToLowerInvariant()
        
        [System.Threading.Monitor]::Enter($this._scenarioCacheLock)
        try {
            if ($this._scenarioCache.ContainsKey($key)) {
                $null = $this._scenarioCache.Remove($key)
                $this._logger.LogInfo("Scenario cache cleared: $scenarioPath")
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($this._scenarioCacheLock)
        }
    }
}
class MessageService {
    hidden [hashtable]$_templateCache      # 既存
    hidden [hashtable]$_scenarioCache      # 新規
    
    # シナリオのロード（キャッシュ付き）
    [object] LoadScenario([string]$filePath) {
        if ($this._scenarioCache.ContainsKey($filePath)) {
            $cached = $this._scenarioCache[$filePath]
            $fileInfo = Get-Item -LiteralPath $filePath -ErrorAction SilentlyContinue
            if ($fileInfo -and $fileInfo.LastWriteTime -eq $cached.LastModified) {
                return $cached.Data  # キャッシュヒット
            }
        }
        
        if (-not (Test-Path -LiteralPath $filePath)) {
            throw "Scenario file not found: $filePath"
        }
        
        $fileInfo = Get-Item -LiteralPath $filePath
        $content = Get-Content -Path $filePath -Encoding Default -Raw
        $steps = $content | ConvertFrom-Csv
        
        $this._scenarioCache[$filePath] = @{
            Data = $steps
            LastModified = $fileInfo.LastWriteTime
        }
        
        return $steps
    }
}
```

#### 期待される効果
- **ディスクI/O削減**: 約50-70%（同一シナリオ繰り返し実行時）
- **応答性向上**: シナリオ開始が即座に

---

## 実装計画

### フェーズ1: 即効性の高い改善（1-2日）

#### Phase 1.1: タイマー間隔調整 【即座】
- **作業時間**: 5分
- **対象ファイル**: `Presentation/UI/MainForm.ps1`
- **変更内容**:
  ```powershell
  # 93行目
  - $timer = New-RefreshTimer -IntervalMilliseconds 2000
  + $timer = New-RefreshTimer -IntervalMilliseconds 3000
  ```
- **テスト**: 動作確認のみ
- **リスク**: 極低

#### Phase 1.2: ログ表示の増分更新 【1時間】
- **作業時間**: 1-2時間
- **対象ファイル**: `Presentation/UI/ViewBuilder.ps1`
- **変更内容**: `Update-LogDisplay` → `Update-LogDisplayIncremental`
- **テスト**: 
  - 複数接続でのログ表示確認
  - メモリリーク確認
- **リスク**: 低

#### Phase 1.3: UI差分更新 【2-3時間】
- **作業時間**: 3-4時間
- **対象ファイル**: `Presentation/UI/MainForm.ps1`
- **変更内容**: 
  - `Update-InstanceListIncremental` 関数追加
  - `Update-ConnectionRow` 関数追加
  - タイマーハンドラーの変更
- **テスト**:
  - 接続追加・削除の確認
  - ステータス変更の反映確認
  - ComboBox選択の保持確認
  - 編集中の動作確認
- **リスク**: 中

#### Phase 1.4: テンプレートキャッシュ実装 【最優先・2-3時間】
- **作業時間**: 2-3時間
- **対象ファイル**: `Core/Domain/MessageService.ps1`
- **変更内容**: 
  - `Get-MessageTemplateCache` にキャッシュ機能追加
  - HEX文字列結合をStringBuilder化
  - バイト配列の事前変換
- **テスト**:
  - Auto Response応答時間測定
  - キャッシュヒット率確認
  - ファイル更新時のキャッシュ無効化確認
- **リスク**: 低
- **効果**: **応答時間 80-90%削減（最大の改善効果）**

#### Phase 1.5: ルールマッチング最適化 【高優先・2時間】
- **作業時間**: 2-3時間
- **対象ファイル**: `Core/Domain/ReceivedRuleEngine.ps1`
- **変更内容**:
  - `Read-ReceivedRules` でマッチングパターン事前変換
  - `Test-BinaryRuleMatch` の高速化
- **テスト**:
  - ルールマッチング時間測定
  - 複数ルールでの動作確認
- **リスク**: 低
- **効果**: **マッチング時間 50-60%削減**

### フェーズ2: 中期的改善（3-5日）

#### Phase 2.1: RecvBufferサイズ制限 【1時間】
- **作業時間**: 1-2時間
- **対象ファイル**: 
  - `Core/Domain/ReceivedEventPipeline.ps1`
  - `Config/defaults.psd1`
- **変更内容**: リングバッファ実装
- **テスト**: 長時間運用テスト
- **リスク**: 低

#### Phase 2.2: Loggerバッファリング 【3-4時間】
- **作業時間**: 4-5時間
- **対象ファイル**: `Core/Common/Logger.ps1`
- **変更内容**: `BufferedLogger` クラス追加
- **テスト**:
  - ログ書き込み確認
  - フラッシュ動作確認
  - アプリケーション終了時の動作確認
  - 並列書き込みテスト
- **リスク**: 中（データロストの可能性）

### フェーズ3: 最適化（1-2日）

#### Phase 3.1: CSVキャッシュ拡充 【2時間】
- **作業時間**: 2-3時間
- **対象ファイル**: `Core/Domain/MessageService.ps1`
- **変更内容**: シナリオキャッシュ追加
- **テスト**: シナリオ実行確認
- **リスク**: 低

#### Phase 3.2: 適応的タイマー 【2時間】
- **作業時間**: 2-3時間
- **対象ファイル**: `Presentation/UI/MainForm.ps1`
- **変更内容**: タイマー間隔の動的調整
- **テスト**: 様々な負荷状況での確認
- **リスク**: 低

### 実装優先順位マトリクス

| 改善案 | 効果 | 工数 | 優先度 | フェーズ |
|--------|------|------|--------|----------|
| **テンプレートキャッシュ実装** | **最大** | **小** | **★★★★★** | **Phase 1.4** |
| **ルールマッチング最適化** | **大** | **小** | **★★★★★** | **Phase 1.5** |
| タイマー間隔調整 | 中 | 極小 | ★★★★★ | Phase 1.1 |
| ログ増分更新 | 大 | 小 | ★★★★★ | Phase 1.2 |
| UI差分更新 | 大 | 中 | ★★★★★ | Phase 1.3 |
| RecvBufferサイズ制限 | 中 | 小 | ★★★★☆ | Phase 2.1 |
| Loggerバッファリング | 中 | 中 | ★★★☆☆ | Phase 2.2 |
| シナリオキャッシュ | 小 | 小 | ★★☆☆☆ | Phase 3.1 |
| 適応的タイマー | 小 | 小 | ★★☆☆☆ | Phase 3.2 |

**注記**: Auto Response関連（Phase 1.4, 1.5）は応答性に最も影響が大きいため最優先で実装推奨

---

## 期待される効果

### 性能改善効果（推定）

#### CPU使用率
- **現状**: アイドル時 5-10%, 通信時 20-40%, Auto Response時 50-80%
- **改善後**: アイドル時 1-3%, 通信時 10-20%, Auto Response時 10-20%
- **削減率**: 約50-70%（Auto Response時は約80%）

#### メモリ使用量
- **現状**: 長時間運用で増加傾向（100MB → 300MB+）
- **改善後**: 一定範囲内に収束（100MB → 150MB程度）
- **削減率**: 長期運用時 約50%

#### Auto Response応答時間
- **現状**: 10-20ms（1ルール）、60-120ms（10ルール）、120-240ms（20ルール）
- **改善後**: 2-3ms（1ルール）、10-20ms（10ルール）、20-40ms（20ルール）
- **削減率**: 約80-85%

#### UI応答性
- **現状**: 接続数増加で遅延、ちらつき発生
- **改善後**: 接続数に関わらず快適
- **体感**: 大幅改善

#### ディスクI/O
- **現状**: ログ書き込み + テンプレート読み込みで高頻度
- **改善後**: 約90-95%削減
- **副次効果**: SSD寿命延長

### ユーザー体験の改善

#### Before（現状）
- ? 画面のちらつき
- ? セル編集が中断される
- ? 接続数が増えると遅くなる
- ? 長時間運用でメモリ増加

#### After（改善後）
- ? スムーズな画面更新
- ? 編集中も快適
- ? 多数接続でも快適
- ? 長時間運用でも安定

### ベンチマーク目標

| 項目 | 現状 | 目標 | 測定方法 |
|------|------|------|----------|
| UI更新時間 | 200-500ms | 50-100ms | Measure-Command |
| ログ更新時間 | 100-200ms | 20-50ms | Measure-Command |
| **Auto Response応答時間（1ルール）** | **10-20ms** | **2-3ms** | **Measure-Command** |
| **Auto Response応答時間（10ルール）** | **60-120ms** | **10-20ms** | **Measure-Command** |
| **テンプレート読み込み時間** | **5-10ms** | **0.1-0.5ms** | **Measure-Command（キャッシュヒット）** |
| CPU使用率（アイドル） | 5-10% | 1-3% | タスクマネージャー |
| CPU使用率（通信中） | 20-40% | 10-20% | タスクマネージャー |
| CPU使用率（Auto Response時） | 50-80% | 10-20% | タスクマネージャー |
| メモリ使用量（1時間後） | 150-200MB | 120-150MB | タスクマネージャー |
| ディスクI/O（1分間） | 50-100回 | 5-10回 | Process Monitor |

---

## リスク評価と対策

### リスク1: 差分更新のバグ
- **内容**: 行の追加・削除・更新のロジックにバグ
- **影響**: UI表示の不整合
- **対策**: 
  - 十分な単体テスト
  - フォールバック機能（全更新モード）
  - ログ出力による検証

### リスク2: Loggerバッファのデータロスト
- **内容**: アプリケーション異常終了時にバッファ内容が失われる
- **影響**: ログの欠損
- **対策**:
  - 例外ハンドラーでFlush実行
  - バッファサイズを適切に設定（50件程度）
  - クリティカルなログは即座にフラッシュ

### リスク3: キャッシュの無効化タイミング
- **内容**: ファイル更新時にキャッシュが更新されない
- **影響**: 古いデータを使用
- **対策**:
  - ファイル更新時刻でキャッシュ検証（実装済み）
  - 手動キャッシュクリア機能の提供

### リスク4: Auto Responseキャッシュの整合性
- **内容**: テンプレートファイル更新時にキャッシュが古いまま
- **影響**: 古い応答データを送信
- **対策**:
  - ファイル更新時刻でキャッシュ無効化（設計に含む）
  - 開発時は手動キャッシュクリア機能を提供
  - ログに「Cache Hit/Miss」を出力

### リスク5: パフォーマンス改善の検証不足
- **内容**: 改善効果が想定より低い
- **影響**: 期待外れ
- **対策**:
  - 改善前後のベンチマーク測定
  - 各フェーズでの効果測定
  - 段階的なロールアウト
- **影響**: 期待外れ
- **対策**:
  - 改善前後のベンチマーク測定
  - 各フェーズでの効果測定
  - 段階的なロールアウト

---

## 検証計画

### 性能測定項目

#### 1. UI更新性能
```powershell
# 測定コード例
$iterations = 10
$times = @()

for ($i = 0; $i -lt $iterations; $i++) {
    $time = Measure-Command {
        Update-InstanceList -DataGridView $dgvInstances
    }
    $times += $time.TotalMilliseconds
}

$average = ($times | Measure-Object -Average).Average
Write-Host "Average UI update time: $average ms"
```

#### 2. メモリ使用量
- **測定間隔**: 5分
- **測定期間**: 1時間
- **測定方法**: `Get-Process | Select-Object WorkingSet64`

#### 3. CPU使用率
- **測定ツール**: Windows Performance Monitor
- **測定項目**: `% Processor Time`
- **測定期間**: 10分（通常運用シナリオ）

#### 4. ディスクI/O
- **測定ツール**: Process Monitor (SysInternals)
- **測定項目**: Write操作の回数
- **測定期間**: 1分間

### 負荷テストシナリオ

#### シナリオ1: 軽負荷
- 接続数: 3
- 通信頻度: 10秒に1回
- 期間: 10分

#### シナリオ2: 中負荷
- 接続数: 10
- 通信頻度: 1秒に1回
- 期間: 30分

#### シナリオ3: 高負荷
- 接続数: 20
- 通信頻度: 0.1秒に1回（10Hz）
- 期間: 5分

#### シナリオ4: 長期運用
- 接続数: 5
- 通信頻度: 30秒に1回
- 期間: 4時間

---

## 参考資料

### PowerShell 性能最適化ベストプラクティス

1. **配列操作**:
   - `+=` を避ける → `ArrayList` または `List<T>` を使用
   - `foreach` より `for` が高速（インデックスアクセス）

2. **文字列操作**:
   - 複数の文字列結合は `StringBuilder` を使用
   - `-join` 演算子を活用

3. **ファイルI/O**:
   - `Add-Content` より `[System.IO.File]::AppendAllLines` が高速
   - バッファリングで書き込み回数を削減

4. **WinForms**:
   - `SuspendLayout()` / `ResumeLayout()` で再描画を抑制
   - `BeginUpdate()` / `EndUpdate()` でリスト更新を最適化
   - 仮想モード (VirtualMode) で大量データを扱う

### 関連ドキュメント
- `ARCHITECTURE_REFACTORING.md`: アーキテクチャ設計
- `DESIGN.md`: 全体設計
- `GUI_REFACTORING_PHASE2_REPORT.md`: GUI改善履歴

---

## 改訂履歴

| バージョン | 日付 | 変更内容 | 作成者 |
|-----------|------|----------|--------|
| 1.0 | 2025-11-20 | 初版作成 | Performance Analysis Team |

---

**END OF DOCUMENT**
