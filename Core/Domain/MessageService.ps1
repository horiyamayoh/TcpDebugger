# MessageService.ps1
# メッセージテンプレート処理とシナリオ実行を統合管理

class MessageService {
    hidden [Logger]$_logger
    hidden [ConnectionService]$_connectionService
    hidden [hashtable]$_templateCache
    hidden [hashtable]$_scenarioCache
    hidden [object]$_scenarioCacheLock
    hidden [hashtable]$_customVariableHandlers

    MessageService([Logger]$logger, [ConnectionService]$connectionService) {
        $this._logger = $logger
        $this._connectionService = $connectionService
        $this._templateCache = @{}
        $this._scenarioCache = @{}
        $this._scenarioCacheLock = [object]::new()
        $this._customVariableHandlers = @{}
    }

    # カスタム変数ハンドラーの登録
    [void] RegisterCustomVariableHandler([string]$name, [scriptblock]$handler) {
        $key = $name.ToLowerInvariant()
        $this._customVariableHandlers[$key] = $handler
        $this._logger.LogInfo("Custom variable handler registered: $name")
    }

    # カスタム変数ハンドラーの削除
    [void] UnregisterCustomVariableHandler([string]$name) {
        $key = $name.ToLowerInvariant()
        if ($this._customVariableHandlers.ContainsKey($key)) {
            $this._customVariableHandlers.Remove($key)
            $this._logger.LogInfo("Custom variable handler unregistered: $name")
        }
    }

    # カスタム変数ハンドラーの実行
    [object] InvokeCustomVariableHandler([string]$identifier, [hashtable]$variables) {
        if ([string]::IsNullOrWhiteSpace($identifier)) {
            return $null
        }

        $handlerName = $identifier
        $argument = $null
        $separatorIndex = $identifier.IndexOf(':')
        if ($separatorIndex -ge 0) {
            $handlerName = $identifier.Substring(0, $separatorIndex)
            $argument = $identifier.Substring($separatorIndex + 1)
        }

        $key = $handlerName.ToLowerInvariant()
        if (-not $this._customVariableHandlers.ContainsKey($key)) {
            return $null
        }

        $context = [PSCustomObject]@{
            Name      = $handlerName
            Argument  = $argument
            RawValue  = $identifier
            Variables = $variables
        }

        try {
            return & $this._customVariableHandlers[$key] $context
        } catch {
            $this._logger.LogWarning("Custom variable handler '$handlerName' failed: $_")
            return $null
        }
    }

    # テンプレートのロード（キャッシュ付き）
    [object] LoadTemplate([string]$filePath) {
        if ($this._templateCache.ContainsKey($filePath)) {
            $cached = $this._templateCache[$filePath]
            $fileInfo = Get-Item -LiteralPath $filePath -ErrorAction SilentlyContinue
            if ($fileInfo -and $fileInfo.LastWriteTime -eq $cached.LastModified) {
                return $cached.Data
            }
        }

        if (-not (Test-Path -LiteralPath $filePath)) {
            throw "Template file not found: $filePath"
        }

        $fileInfo = Get-Item -LiteralPath $filePath
        # UTF-8でCSV読み込み
        $content = Get-Content -Path $filePath -Encoding UTF8 -Raw | ConvertFrom-Csv

        $this._templateCache[$filePath] = @{
            Data = $content
            LastModified = $fileInfo.LastWriteTime
        }

        $this._logger.LogInfo("Template loaded and cached: $filePath")
        return $content
    }

    # テンプレートキャッシュのクリア
    [void] ClearTemplateCache() {
        $this._templateCache.Clear()
        $this._logger.LogInfo("Template cache cleared")
    }

    # 変数の展開
    [string] ExpandVariables([string]$text, [hashtable]$variables) {
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $text
        }

        $result = $text
        $pattern = '\$\{([^}]+)\}'
        $matches = [regex]::Matches($result, $pattern)

        foreach ($match in $matches) {
            $varName = $match.Groups[1].Value
            $value = $null

            # カスタムハンドラーを試行
            $customValue = $this.InvokeCustomVariableHandler($varName, $variables)
            if ($null -ne $customValue) {
                $value = $customValue
            }
            # 通常の変数を試行
            elseif ($variables.ContainsKey($varName)) {
                $value = $variables[$varName]
            }
            # 組み込み変数
            else {
                $value = $this.ResolveBuiltInVariable($varName)
            }

            if ($null -ne $value) {
                $result = $result.Replace($match.Value, $value.ToString())
            }
        }

        return $result
    }

    # 組み込み変数の解決
    [object] ResolveBuiltInVariable([string]$name) {
        $result = switch ($name.ToLowerInvariant()) {
            'timestamp' { (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') }
            'timestamp_ms' { (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') }
            'unixtime' { [int]((Get-Date).ToUniversalTime() - (Get-Date '1970-01-01')).TotalSeconds }
            'guid' { [guid]::NewGuid().ToString() }
            'newline' { "`r`n" }
            'crlf' { "`r`n" }
            'lf' { "`n" }
            'tab' { "`t" }
            default { $null }
        }
        return $result
    }

    # メッセージをバイト配列に変換
    [byte[]] ConvertMessageToBytes([string]$message, [string]$encoding) {
        if ([string]::IsNullOrWhiteSpace($message)) {
            return @()
        }

        $enc = switch ($encoding.ToLowerInvariant()) {
            'utf8' { [System.Text.Encoding]::UTF8 }
            'sjis' { [System.Text.Encoding]::GetEncoding('Shift_JIS') }
            'ascii' { [System.Text.Encoding]::ASCII }
            default { [System.Text.Encoding]::UTF8 }
        }

        return $enc.GetBytes($message)
    }

    # HEX文字列をバイト配列に変換
    [byte[]] ConvertHexToBytes([string]$hexString) {
        $hex = $hexString -replace '\s+', ''
        if ($hex.Length % 2 -ne 0) {
            throw "Invalid hex string length: $($hex.Length)"
        }

        # 事前にサイズ確定した配列を作成（高速）
        $byteCount = $hex.Length / 2
        $bytes = [byte[]]::new($byteCount)
        $byteIndex = 0
        
        # ループ内の除算を排除（高速化）
        for ($i = 0; $i -lt $hex.Length; $i += 2) {
            $bytes[$byteIndex++] = [Convert]::ToByte($hex.Substring($i, 2), 16)
        }

        return $bytes
    }

    # テンプレートからメッセージを生成
    [byte[]] ProcessTemplate([string]$templatePath, [hashtable]$variables, [string]$connectionId) {
        $template = $this.LoadTemplate($templatePath)
        $conn = $this._connectionService.GetConnection($connectionId)
        if (-not $conn) {
            throw "Connection not found: $connectionId"
        }

        # 接続の変数とマージ
        $mergedVars = @{}
        foreach ($key in $conn.Variables.Keys) {
            $mergedVars[$key] = $conn.Variables[$key]
        }
        foreach ($key in $variables.Keys) {
            $mergedVars[$key] = $variables[$key]
        }

        # テンプレート処理（最初の行のみを使用）
        if ($template -and $template.Count -gt 0) {
            $row = $template[0]
            $message = $row.Message
            if ($row.PSObject.Properties['Encoding']) {
                $encoding = $row.Encoding
            } else {
                $encoding = 'utf8'
            }

            $expanded = $this.ExpandVariables($message, $mergedVars)
            return $this.ConvertMessageToBytes($expanded, $encoding)
        }

        return @()
    }

    # シナリオファイルの読み込み（ファイル更新検知付きキャッシュ）
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

        # UTF-8でCSV読み込み
        $content = Get-Content -Path $resolved -Encoding UTF8 -Raw
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
            # 全シナリオキャッシュクリア
            [System.Threading.Monitor]::Enter($this._scenarioCacheLock)
            try {
                $count = $this._scenarioCache.Count
                $this._scenarioCache.Clear()
                $this._logger.LogInfo("All scenario cache cleared ($count entries)")
            }
            finally {
                [System.Threading.Monitor]::Exit($this._scenarioCacheLock)
            }
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

    # シナリオの実行（非同期）
    [void] StartScenario([string]$connectionId, [string]$scenarioPath) {
        $conn = $this._connectionService.GetConnection($connectionId)
        if (-not $conn) {
            throw "Connection not found: $connectionId"
        }

        $scenarioSteps = $this.LoadScenario($scenarioPath)
        $logger = $this._logger
        $messageService = $this

        $scriptBlock = {
            param($connId, $steps, $svc, $log)

            try {
                for ($i = 0; $i -lt $steps.Count; $i++) {
                    $step = $steps[$i]
                    $log.LogInfo("Scenario step $($i+1)/$($steps.Count): $($step.Action)")

                    # ここでシナリオステップを実行
                    # （詳細実装は後続で追加）
                }
            } catch {
                $log.LogError("Scenario execution failed", $_)
            }
        }

        $runspace = [powershell]::Create()
        $runspace.AddScript($scriptBlock).AddArgument($connectionId).AddArgument($scenarioSteps).AddArgument($messageService).AddArgument($logger) | Out-Null
        $null = $runspace.BeginInvoke()

        $this._logger.LogInfo("Scenario started: $scenarioPath for connection: $connectionId")
    }

    # テンプレートからメッセージを送信
    [void] SendTemplate([string]$connectionId, [string]$templatePath, [hashtable]$variables) {
        $bytes = $this.ProcessTemplate($templatePath, $variables, $connectionId)
        $conn = $this._connectionService.GetConnection($connectionId)
        if (-not $conn) {
            throw "Connection not found: $connectionId"
        }

        if ($conn.Stream -and $conn.Stream.CanWrite) {
            $conn.Stream.Write($bytes, 0, $bytes.Length)
            $conn.Stream.Flush()
            $this._logger.LogInfo("Template sent: $templatePath to $connectionId ($($bytes.Length) bytes)")
        } else {
            throw "Connection stream is not writable: $connectionId"
        }
    }

    # バイトデータを送信
    [void] SendBytes([string]$connectionId, [byte[]]$data) {
        $conn = $this._connectionService.GetConnection($connectionId)
        if (-not $conn) {
            throw "Connection not found: $connectionId"
        }

        if ($conn.Stream -and $conn.Stream.CanWrite) {
            $conn.Stream.Write($data, 0, $data.Length)
            $conn.Stream.Flush()
            $this._logger.LogInfo("Bytes sent to $connectionId ($($data.Length) bytes)")
        } else {
            throw "Connection stream is not writable: $connectionId"
        }
    }

    # HEX文字列を送信
    [void] SendHex([string]$connectionId, [string]$hexString) {
        $bytes = $this.ConvertHexToBytes($hexString)
        $this.SendBytes($connectionId, $bytes)
    }

    # テキストメッセージを送信
    [void] SendText([string]$connectionId, [string]$text, [string]$encoding) {
        $bytes = $this.ConvertMessageToBytes($text, $encoding)
        $this.SendBytes($connectionId, $bytes)
    }
}

# =====================================================================
# グローバルヘルパー関数（旧互換性のため）
# =====================================================================

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
    
    # UTF-8でCSV読み込み
    $content = Get-Content -Path $resolvedPath -Encoding UTF8 -Raw
    $rows = $content | ConvertFrom-Csv
    
    if (-not $rows -or $rows.Count -eq 0) {
        return @{}
    }
    
    # StringBuilder使用でHEX文字列結合を高速化
    $sb = [System.Text.StringBuilder]::new()
    foreach ($row in $rows) {
        # Row1, Row2, ... の2列目のHEX値を結合（スペース削除）
        $properties = $row.PSObject.Properties.Name
        if ($properties.Count -ge 2) {
            $hexValue = $properties[1]
            $cleanHex = $row.$hexValue -replace '\s', ''  # スペース削除
            [void]$sb.Append($cleanHex)
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
            Write-DebugLog "All template cache cleared ($count entries)" "Yellow"
        }
        else {
            # 特定ファイルのキャッシュクリア
            $resolvedPath = (Resolve-Path -LiteralPath $FilePath -ErrorAction SilentlyContinue).Path
            if ($resolvedPath) {
                $key = $resolvedPath.ToLowerInvariant()
                if ($script:MessageTemplateCache.ContainsKey($key)) {
                    $null = $script:MessageTemplateCache.Remove($key)
                    Write-DebugLog "Template cache cleared: $FilePath" "Yellow"
                }
            }
        }
    }
    finally {
        [System.Threading.Monitor]::Exit($script:MessageTemplateCacheLock)
    }
}

function ConvertTo-ByteArray {
    <#
    .SYNOPSIS
    文字列またはHEX文字列をバイト配列に変換
    
    .PARAMETER Data
    変換するデータ
    
    .PARAMETER Encoding
    エンコーディング（HEX, UTF-8, Shift_JIS, ASCII）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Data,
        
        [Parameter(Mandatory=$false)]
        [string]$Encoding = "UTF-8"
    )
    
    if ([string]::IsNullOrWhiteSpace($Data)) {
        return @()
    }
    
    $normalizedEncoding = $Encoding.ToUpperInvariant() -replace '[_-]', ''
    
    if ($normalizedEncoding -eq 'HEX') {
        # HEX文字列をバイト配列に変換（最適化版）
        $hex = $Data -replace '\s+', ''
        if ($hex.Length % 2 -ne 0) {
            throw "Invalid hex string length: $($hex.Length)"
        }
        
        # 事前にサイズ確定した配列を作成（高速）
        $byteCount = $hex.Length / 2
        $bytes = [byte[]]::new($byteCount)
        $byteIndex = 0
        
        # ループ内の除算を排除（高速化）
        for ($i = 0; $i -lt $hex.Length; $i += 2) {
            $bytes[$byteIndex++] = [Convert]::ToByte($hex.Substring($i, 2), 16)
        }
        return $bytes
    }
    
    # テキストエンコーディング
    $enc = switch ($normalizedEncoding) {
        'UTF8' { [System.Text.Encoding]::UTF8 }
        'SHIFTJIS' { [System.Text.Encoding]::GetEncoding('Shift_JIS') }
        'SJIS' { [System.Text.Encoding]::GetEncoding('Shift_JIS') }
        'ASCII' { [System.Text.Encoding]::ASCII }
        default { [System.Text.Encoding]::UTF8 }
    }
    
    return $enc.GetBytes($Data)
}

function ConvertFrom-ByteArray {
    <#
    .SYNOPSIS
    バイト配列を文字列に変換
    
    .PARAMETER Data
    バイト配列
    
    .PARAMETER Encoding
    エンコーディング（UTF-8, Shift_JIS, ASCII）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Data,
        
        [Parameter(Mandatory=$false)]
        [string]$Encoding = "UTF-8"
    )
    
    if (-not $Data -or $Data.Length -eq 0) {
        return ""
    }
    
    $normalizedEncoding = $Encoding.ToUpperInvariant() -replace '[_-]', ''
    
    $enc = switch ($normalizedEncoding) {
        'UTF8' { [System.Text.Encoding]::UTF8 }
        'SHIFTJIS' { [System.Text.Encoding]::GetEncoding('Shift_JIS') }
        'SJIS' { [System.Text.Encoding]::GetEncoding('Shift_JIS') }
        'ASCII' { [System.Text.Encoding]::ASCII }
        default { [System.Text.Encoding]::UTF8 }
    }
    
    return $enc.GetString($Data)
}

function Expand-MessageVariables {
    <#
    .SYNOPSIS
    メッセージテンプレート内の変数を展開
    
    .PARAMETER Template
    変数を含むテンプレート文字列
    
    .PARAMETER Variables
    変数のハッシュテーブル
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Template,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$Variables = @{}
    )
    
    if ($Global:MessageService) {
        return $Global:MessageService.ExpandVariables($Template, $Variables)
    }
    
    # フォールバック: 簡易実装
    $result = $Template
    $pattern = '\$\{([^}]+)\}'
    $matches = [regex]::Matches($result, $pattern)
    
    foreach ($match in $matches) {
        $varName = $match.Groups[1].Value
        if ($Variables.ContainsKey($varName)) {
            $result = $result.Replace($match.Value, $Variables[$varName].ToString())
        }
    }
    
    return $result
}

