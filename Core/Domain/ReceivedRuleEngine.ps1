# ReceivedRuleEngine.ps1
# 受信時のルール処理エンジン（OnReceiveReply/OnReceiveScript共通）

# デバッグ出力ヘルパー
function Write-DebugLog {
    param(
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    if ($script:EnableDebugOutput) {
        Write-Host $Message -ForegroundColor $ForegroundColor
    }
}

# Helper accessor for the shared rule repository
function Get-RuleRepository {
    if ($Global:RuleRepository) {
        return $Global:RuleRepository
    }
    throw "RuleRepository is not initialized."
}

function Read-ReceivedRules {
    <#
    .SYNOPSIS
    受信ルールを読み込み（OnReceiveReply/OnReceiveScript共通）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [string]$RuleType = "Auto"  # "Auto", "OnReceiveReply", "OnReceiveScript"
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "[ReceivedRule] Rule file not found: $FilePath"
        return @()
    }

    # UTF-8でCSV読み込み
    $content = Get-Content -Path $FilePath -Encoding UTF8 -Raw
    $rules = $content | ConvertFrom-Csv

    if ($rules.Count -eq 0) {
        return @()
    }

    # ルールタイプを判定（シンプル版：Unified形式は廃止）
    $detectedType = $null
    $firstRule = $rules[0]
    $properties = $firstRule.PSObject.Properties.Name

    # ResponseMessageFileカラムがあればOnReceiveReply
    if ($properties -contains 'ResponseMessageFile') {
        $detectedType = 'OnReceiveReply'
    }
    # ScriptFileカラムがあればOnReceiveScript
    elseif ($properties -contains 'ScriptFile') {
        $detectedType = 'OnReceiveScript'
    }
    # TriggerPatternがあれば旧形式OnReceiveReply
    elseif ($properties -contains 'TriggerPattern') {
        $detectedType = 'OnReceiveReply_Legacy'
    }
    else {
        Write-Warning "[ReceivedRule] Unknown rule format"
        return @()
    }

    # 各ルールにメタデータを追加
    foreach ($rule in $rules) {
        $rule | Add-Member -NotePropertyName '__RuleType' -NotePropertyValue $detectedType -Force
        
        # ExecutionTiming の判定（OnReceiveScriptルールのみ有効）
        $executionTiming = 'After'  # デフォルト
        if ($properties -contains 'ExecutionTiming' -and -not [string]::IsNullOrWhiteSpace($rule.ExecutionTiming)) {
            $timing = $rule.ExecutionTiming.Trim()
            if ($timing -eq 'Before' -or $timing -eq 'After') {
                $executionTiming = $timing
            }
        }
        $rule | Add-Member -NotePropertyName '__ExecutionTiming' -NotePropertyValue $executionTiming -Force
        
        # アクションタイプを設定（Unified形式は廃止）
        if ($detectedType -eq 'OnReceiveReply' -or $detectedType -eq 'OnReceiveReply_Legacy') {
            $rule | Add-Member -NotePropertyName '__ActionType' -NotePropertyValue 'OnReceiveReply' -Force
        } elseif ($detectedType -eq 'OnReceiveScript') {
            $rule | Add-Member -NotePropertyName '__ActionType' -NotePropertyValue 'OnReceiveScript' -Force
        }
        
        # バイナリマッチング形式かテキストマッチング形式かを判定
        if ($detectedType -eq 'OnReceiveReply_Legacy') {
            $rule | Add-Member -NotePropertyName '__MatchType' -NotePropertyValue 'Text' -Force
        } else {
            $rule | Add-Member -NotePropertyName '__MatchType' -NotePropertyValue 'Binary' -Force
            
            # バイナリマッチングパターンを事前変換（性能最適化）
            if (-not [string]::IsNullOrWhiteSpace($rule.MatchValue)) {
                $hexValue = $rule.MatchValue.Trim() -replace '\s', '' -replace '0x', ''
                
                # 事前にバイト配列に変換（最適化版）
                try {
                    # 配列サイズを事前確定（+= は遅いので使わない）
                    $byteCount = $hexValue.Length / 2
                    $matchBytes = [byte[]]::new($byteCount)
                    $byteIndex = 0
                    
                    for ($i = 0; $i -lt $hexValue.Length; $i += 2) {
                        $hexByte = $hexValue.Substring($i, 2)
                        $matchBytes[$byteIndex++] = [Convert]::ToByte($hexByte, 16)
                    }
                    
                    # ルールに事前変換済みバイト配列を追加
                    $rule | Add-Member -NotePropertyName '__MatchBytes' `
                                       -NotePropertyValue $matchBytes `
                                       -Force
                }
                catch {
                    Write-Warning "[ReceivedRule] Failed to pre-compile match pattern for rule: $_"
                    $rule | Add-Member -NotePropertyName '__MatchBytes' -NotePropertyValue $null -Force
                }
            }
        }
    }

    Write-DebugLog "[ReceivedRule] Loaded $($rules.Count) rules (Type: $detectedType) from $FilePath" "Green"

    return $rules
}

function Test-ReceivedRuleMatch {
    <#
    .SYNOPSIS
    受信データがルールにマッチするかチェック（共通）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$ReceivedData,

        [Parameter(Mandatory=$true)]
        [object]$Rule,

        [Parameter(Mandatory=$false)]
        [string]$DefaultEncoding = "UTF-8"
    )

    if (-not $Rule -or -not $ReceivedData) {
        return $false
    }

    # バイナリマッチング
    if ($Rule.__MatchType -eq 'Binary') {
        return Test-BinaryRuleMatch -ReceivedData $ReceivedData -Rule $Rule
    }

    # テキストマッチング（旧形式OnReceiveReply）
    return Test-TextRuleMatch -ReceivedData $ReceivedData -Rule $Rule -DefaultEncoding $DefaultEncoding
}

function Test-BinaryRuleMatch {
    <#
    .SYNOPSIS
    バイナリパターンマッチング
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$ReceivedData,

        [Parameter(Mandatory=$true)]
        [object]$Rule
    )

    # マッチング条件が指定されていない場合は常にマッチ
    if (-not ($Rule.PSObject.Properties.Name -contains 'MatchOffset') -or
        [string]::IsNullOrWhiteSpace($Rule.MatchOffset)) {
        return $true
    }

    # 必須パラメータチェック
    if ([string]::IsNullOrWhiteSpace($Rule.MatchLength) -or
        [string]::IsNullOrWhiteSpace($Rule.MatchValue)) {
        Write-Warning "[ReceivedRule] MatchLength or MatchValue is missing"
        return $false
    }

    # パラメータ解析
    try {
        $offset = [int]($Rule.MatchOffset)
        $length = [int]($Rule.MatchLength)
        $hexValue = $Rule.MatchValue.Trim() -replace '\s', '' -replace '0x', ''
    } catch {
        Write-Warning "[ReceivedRule] Failed to parse match parameters: $_"
        return $false
    }

    # バリデーション
    if ($offset -lt 0 -or $length -le 0) {
        return $false
    }

    if ($offset + $length -gt $ReceivedData.Length) {
        return $false
    }

    if ($hexValue -notmatch '^[0-9A-Fa-f]+$') {
        Write-Warning "[ReceivedRule] MatchValue contains invalid hex characters: $hexValue"
        return $false
    }

    if ($hexValue.Length % 2 -ne 0) {
        Write-Warning "[ReceivedRule] MatchValue has odd length: $hexValue"
        return $false
    }

    $expectedBytes = $hexValue.Length / 2
    if ($expectedBytes -ne $length) {
        Write-Warning "[ReceivedRule] MatchValue length mismatch"
        return $false
    }

    # 事前変換済みバイト配列を使用（HEX変換不要！）
    $matchBytes = $null
    if ($Rule.PSObject.Properties['__MatchBytes'] -and $Rule.__MatchBytes) {
        $matchBytes = $Rule.__MatchBytes
    }
    else {
        # フォールバック: 事前変換がない場合は実行時変換（最適化版）
        $byteCount = $hexValue.Length / 2
        $matchBytes = [byte[]]::new($byteCount)
        $byteIndex = 0
        
        for ($i = 0; $i -lt $hexValue.Length; $i += 2) {
            $hexByte = $hexValue.Substring($i, 2)
            $matchBytes[$byteIndex++] = [Convert]::ToByte($hexByte, 16)
        }
    }

    # 比較
    for ($i = 0; $i -lt $length; $i++) {
        if ($ReceivedData[$offset + $i] -ne $matchBytes[$i]) {
            return $false
        }
    }

    return $true
}

function Test-TextRuleMatch {
    <#
    .SYNOPSIS
    テキストパターンマッチング（旧形式OnReceiveReply用）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$ReceivedData,

        [Parameter(Mandatory=$true)]
        [object]$Rule,

        [Parameter(Mandatory=$false)]
        [string]$DefaultEncoding = "UTF-8"
    )

    $pattern = $Rule.TriggerPattern
    if ([string]::IsNullOrWhiteSpace($pattern)) {
        return $false
    }

    $effectiveEncoding = if ($Rule.Encoding) { $Rule.Encoding } else { $DefaultEncoding }

    try {
        $receivedText = ConvertFrom-ByteArray -Data $ReceivedData -Encoding $effectiveEncoding
    } catch {
        Write-Warning "[ReceivedRule] Failed to decode received data: $_"
        return $false
    }

    if ($null -eq $receivedText) {
        $receivedText = ""
    }

    $matchType = if ($Rule.MatchType) { $Rule.MatchType } else { "Exact" }
    $normalizedMatch = $matchType.ToUpperInvariant()

    switch ($normalizedMatch) {
        "REGEX" {
            try {
                return [System.Text.RegularExpressions.Regex]::IsMatch($receivedText, $pattern)
            } catch {
                Write-Warning "[ReceivedRule] Invalid regex pattern: $_"
                return $false
            }
        }
        "CONTAINS" {
            return $receivedText.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        }
        "STARTSWITH" {
            return $receivedText.StartsWith($pattern, [System.StringComparison]::OrdinalIgnoreCase)
        }
        "ENDSWITH" {
            return $receivedText.EndsWith($pattern, [System.StringComparison]::OrdinalIgnoreCase)
        }
        default {
            return $receivedText.Equals($pattern, [System.StringComparison]::OrdinalIgnoreCase)
        }
    }
}

function Test-OnReceiveScriptMatch {
    <#
    .SYNOPSIS
    受信データがOnReceiveScriptルールにマッチするかチェック
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$ReceivedData,

        [Parameter(Mandatory=$true)]
        [object]$Rule
    )

    # 共通エンジンを使用
    return Test-ReceivedRuleMatch -ReceivedData $ReceivedData -Rule $Rule -DefaultEncoding "UTF-8"
}

function Invoke-OnReceiveReply {
    <#
    .SYNOPSIS
    受信データに対して自動応答を実行
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,

        [Parameter(Mandatory=$true)]
        [byte[]]$ReceivedData,

        [Parameter(Mandatory=$true)]
        [array]$Rules
    )

    $service = Get-ConnectionService
    $conn = $service.GetConnection($ConnectionId)
    
    if (-not $conn) {
        return
    }

    $defaultEncoding = "UTF-8"
    if ($conn.Variables.ContainsKey('DefaultEncoding') -and $conn.Variables['DefaultEncoding']) {
        $defaultEncoding = $conn.Variables['DefaultEncoding']
    }

    $matchedCount = 0

    foreach ($rule in $Rules) {
        $matchEncoding = if ($rule.Encoding) { $rule.Encoding } else { $defaultEncoding }

        if (-not (Test-ReceivedRuleMatch -ReceivedData $ReceivedData -Rule $rule -DefaultEncoding $matchEncoding)) {
            continue
        }

        $matchedCount++

        # マッチした場合の処理
        $ruleName = if ($rule.RuleName) { $rule.RuleName } else { "Unknown" }
        Write-DebugLog "[OnReceiveReply] Rule matched ($matchedCount): $ruleName" "Cyan"

        # 遅延処理
        if ($rule.Delay -and [int]$rule.Delay -gt 0) {
            Start-Sleep -Milliseconds ([int]$rule.Delay)
        }

        # アクションタイプに応じて処理
        $actionType = if ($rule.PSObject.Properties.Name -contains '__ActionType') {
            $rule.__ActionType
        } else {
            'OnReceiveReply'
        }

        # アクションタイプに応じて処理（Unified形式は廃止）
        if ($actionType -eq 'OnReceiveReply') {
            # OnReceiveReply処理
            if ($rule.__RuleType -eq 'OnReceiveReply_Legacy') {
                Invoke-TextOnReceiveReply -ConnectionId $ConnectionId -Rule $rule -Connection $conn -DefaultEncoding $defaultEncoding
            } else {
                Invoke-BinaryOnReceiveReply -ConnectionId $ConnectionId -Rule $rule -Connection $conn
            }
        }
        # OnReceiveScriptは別の関数で処理されるのでここでは何もしない

        # 複数ルール対応: breakせずに継続
    }

    if ($matchedCount -gt 0) {
        Write-DebugLog "[OnReceiveReply] Total $matchedCount rule(s) processed" "Green"
    }
}

function Invoke-BinaryOnReceiveReply {
    <#
    .SYNOPSIS
    バイナリマッチングルールに基づく自動応答（電文ファイル参照）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,

        [Parameter(Mandatory=$true)]
        [object]$Rule,

        [Parameter(Mandatory=$true)]
        [object]$Connection
    )

    if ([string]::IsNullOrWhiteSpace($Rule.ResponseMessageFile)) {
        Write-Warning "[OnReceiveReply] ResponseMessageFile is not specified in the rule"
        return
    }

    # 電文ファイルのパスを解決
    $messageFilePath = $Rule.ResponseMessageFile

    # 相対パスの場合、インスタンスのtemplatesフォルダからの相対パスとして解釈
    if (-not [System.IO.Path]::IsPathRooted($messageFilePath)) {
        if ($Connection.Variables.ContainsKey('InstancePath')) {
            $instancePath = $Connection.Variables['InstancePath']
            $messageFilePath = Join-Path $instancePath "templates\$messageFilePath"
        }
    }

    if (-not (Test-Path -LiteralPath $messageFilePath)) {
        Write-Warning "[OnReceiveReply] Response message file not found: $messageFilePath"
        return
    }

    # 電文ファイルを読み込む
    try {
        Write-DebugLog "[OnReceiveReply] Loading template: $messageFilePath" "Yellow"
        $templates = Get-MessageTemplateCache -FilePath $messageFilePath -ThrowOnMissing
        Write-DebugLog "[OnReceiveReply] Template loaded successfully" "Yellow"
    } catch {
        Write-Warning "[OnReceiveReply] Failed to load response message file: $_"
        Write-Warning "[OnReceiveReply] Stack trace: $($_.ScriptStackTrace)"
        return
    }

    if (-not $templates -or $templates.Count -eq 0) {
        Write-Warning "[OnReceiveReply] No templates found in $messageFilePath"
        return
    }

    # DEFAULTテンプレートを取得（新形式の電文定義は常にDEFAULT名で格納される）
    if (-not $templates.ContainsKey('DEFAULT')) {
        Write-Warning "[OnReceiveReply] DEFAULT template not found in $messageFilePath"
        return
    }

    $template = $templates['DEFAULT']

    # 事前変換済みバイト配列を使用（HEX変換不要！）
    try {
        # テンプレートに事前変換済みのバイト配列がある場合はそれを使用
        if ($template.PSObject.Properties['Bytes'] -and $template.Bytes) {
            $responseBytes = $template.Bytes
        }
        else {
            # フォールバック: 旧形式のテンプレートの場合はHEX変換
            $responseBytes = ConvertTo-ByteArray -Data $template.Format -Encoding 'HEX'
        }
    } catch {
        Write-Warning "[OnReceiveReply] Failed to convert hex stream to bytes: $_"
        return
    }

    # 送信
    try {
        Send-Data -ConnectionId $ConnectionId -Data $responseBytes
        $hexPreview = $template.Format
        if ($hexPreview.Length -gt 40) {
            $hexPreview = $hexPreview.Substring(0, 40) + "..."
        }
        Write-DebugLog "[OnReceiveReply] Sent message from $($Rule.ResponseMessageFile) (${hexPreview})" "Blue"
    } catch {
        Write-Warning "[OnReceiveReply] Failed to send receive reply: $_"
    }
}

function Invoke-TextOnReceiveReply {
    <#
    .SYNOPSIS
    テキストマッチングルールに基づく自動応答（旧形式）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,

        [Parameter(Mandatory=$true)]
        [object]$Rule,

        [Parameter(Mandatory=$true)]
        [object]$Connection,

        [Parameter(Mandatory=$true)]
        [string]$DefaultEncoding
    )

    $responseTemplate = if ($rule.ResponseTemplate) { $rule.ResponseTemplate } else { "" }
    $response = Expand-MessageVariables -Template $responseTemplate -Variables $Connection.Variables

    $responseEncoding = if ($rule.Encoding) { $rule.Encoding } else { $DefaultEncoding }

    try {
        $responseBytes = ConvertTo-ByteArray -Data $response -Encoding $responseEncoding
    } catch {
        Write-Warning "[OnReceiveReply] Failed to encode receive reply message: $_"
        return
    }

    try {
        Send-Data -ConnectionId $ConnectionId -Data $responseBytes
        Write-Host "[OnReceiveReply] Receive reply sent: $response" -ForegroundColor Blue
    } catch {
        Write-Warning "[OnReceiveReply] Failed to send receive reply: $_"
    }
}

function Invoke-OnReceiveScript {
    <#
    .SYNOPSIS
    OnReceiveScriptスクリプトを実行
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,

        [Parameter(Mandatory=$true)]
        [byte[]]$ReceivedData,

        [Parameter(Mandatory=$true)]
        [object]$Rule,

        [Parameter(Mandatory=$true)]
        [object]$Connection
    )

    if ([string]::IsNullOrWhiteSpace($Rule.ScriptFile)) {
        Write-Warning "[OnReceiveScript] ScriptFile is not specified"
        return
    }

    # スクリプトファイルのパスを解決
    $scriptPath = $Rule.ScriptFile

    # 相対パスの場合、インスタンスのscenariosフォルダ配下を検索
    if (-not [System.IO.Path]::IsPathRooted($scriptPath)) {
        if ($Connection.Variables.ContainsKey('InstancePath')) {
            $instancePath = $Connection.Variables['InstancePath']
            $searchPaths = @(
                (Join-Path (Join-Path $instancePath "scenarios") "on_receive_script"),
                (Join-Path $instancePath "scenarios"),
                (Join-Path $instancePath "templates")
            )
            $resolved = $false
            foreach ($dir in $searchPaths) {
                $fullPath = Join-Path $dir $scriptPath
                if (Test-Path -LiteralPath $fullPath) {
                    $scriptPath = $fullPath
                    $resolved = $true
                    break
                }
            }
            if (-not $resolved) {
                # 従来の形式も試す（後方互換性）
                $scriptPath = Join-Path $instancePath "scenarios\$scriptPath"
            }
        }
    }

    if (-not (Test-Path -LiteralPath $scriptPath)) {
        Write-Warning "[OnReceiveScript] Script file not found: $scriptPath"
        return
    }

    # スクリプト実行用のコンテキストを準備
    $scriptContext = @{
        ReceivedData = $ReceivedData
        Connection = $Connection
        ConnectionId = $ConnectionId
        Rule = $Rule
        InstancePath = $Connection.Variables['InstancePath']
    }

    try {
        Write-Host "[OnReceiveScript] Executing script: $($Rule.ScriptFile)" -ForegroundColor Blue

        # スクリプトを実行
        $scriptBlock = [scriptblock]::Create((Get-Content -LiteralPath $scriptPath -Raw -Encoding UTF8))

        # スクリプトに変数を渡して実行
        & $scriptBlock -Context $scriptContext

        Write-Host "[OnReceiveScript] Script executed successfully" -ForegroundColor Green
    } catch {
        Write-Warning "[OnReceiveScript] Script execution failed: $_"
        Write-Warning $_.ScriptStackTrace
    }
}



