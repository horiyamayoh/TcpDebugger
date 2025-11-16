# ReceivedRuleEngine.ps1
# 受信時のルール処理エンジン（AutoResponse/OnReceived共通）

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
    受信ルールを読み込み（AutoResponse/OnReceived共通）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [string]$RuleType = "Auto"  # "Auto", "AutoResponse", "OnReceived"
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "[ReceivedRule] Rule file not found: $FilePath"
        return @()
    }

    # Shift-JISでCSV読み込み
    $sjisEncoding = [System.Text.Encoding]::GetEncoding("Shift_JIS")
    $rules = Import-Csv -Path $FilePath -Encoding $sjisEncoding

    if ($rules.Count -eq 0) {
        return @()
    }

    # ルールタイプを判定
    $detectedType = $null
    $firstRule = $rules[0]
    $properties = $firstRule.PSObject.Properties.Name

    # ResponseMessageFileとScriptFileの両方がある場合は統合形式
    $hasResponseFile = $properties -contains 'ResponseMessageFile'
    $hasScriptFile = $properties -contains 'ScriptFile'
    
    if ($hasResponseFile -and $hasScriptFile) {
        $detectedType = 'Unified'
    }
    # ResponseMessageFileのみがあればAutoResponse
    elseif ($hasResponseFile) {
        $detectedType = 'AutoResponse'
    }
    # ScriptFileのみがあればOnReceived
    elseif ($hasScriptFile) {
        $detectedType = 'OnReceived'
    }
    # TriggerPatternがあれば旧形式AutoResponse
    elseif ($properties -contains 'TriggerPattern') {
        $detectedType = 'AutoResponse_Legacy'
    }
    else {
        Write-Warning "[ReceivedRule] Unknown rule format"
        return @()
    }

    # 各ルールにメタデータを追加
    foreach ($rule in $rules) {
        $rule | Add-Member -NotePropertyName '__RuleType' -NotePropertyValue $detectedType -Force
        
        # 統合形式の場合、各ルールの実際のアクションタイプを判定
        if ($detectedType -eq 'Unified') {
            $hasResponse = -not [string]::IsNullOrWhiteSpace($rule.ResponseMessageFile)
            $hasScript = -not [string]::IsNullOrWhiteSpace($rule.ScriptFile)
            
            if ($hasResponse -and $hasScript) {
                # 両方指定されている場合
                $rule | Add-Member -NotePropertyName '__ActionType' -NotePropertyValue 'Both' -Force
            } elseif ($hasResponse) {
                $rule | Add-Member -NotePropertyName '__ActionType' -NotePropertyValue 'AutoResponse' -Force
            } elseif ($hasScript) {
                $rule | Add-Member -NotePropertyName '__ActionType' -NotePropertyValue 'OnReceived' -Force
            } else {
                $rule | Add-Member -NotePropertyName '__ActionType' -NotePropertyValue 'None' -Force
            }
        } else {
            # 非統合形式の場合
            if ($detectedType -eq 'AutoResponse' -or $detectedType -eq 'AutoResponse_Legacy') {
                $rule | Add-Member -NotePropertyName '__ActionType' -NotePropertyValue 'AutoResponse' -Force
            } elseif ($detectedType -eq 'OnReceived') {
                $rule | Add-Member -NotePropertyName '__ActionType' -NotePropertyValue 'OnReceived' -Force
            }
        }
        
        # バイナリマッチング形式かテキストマッチング形式かを判定
        if ($detectedType -eq 'AutoResponse_Legacy') {
            $rule | Add-Member -NotePropertyName '__MatchType' -NotePropertyValue 'Text' -Force
        } else {
            $rule | Add-Member -NotePropertyName '__MatchType' -NotePropertyValue 'Binary' -Force
        }
    }

    Write-Host "[ReceivedRule] Loaded $($rules.Count) rules (Type: $detectedType) from $FilePath" -ForegroundColor Green

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

    # テキストマッチング（旧形式AutoResponse）
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

    # 16進数文字列をバイト配列に変換
    $matchBytes = @()
    for ($i = 0; $i -lt $hexValue.Length; $i += 2) {
        $hexByte = $hexValue.Substring($i, 2)
        $matchBytes += [Convert]::ToByte($hexByte, 16)
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
    テキストパターンマッチング（旧形式AutoResponse用）
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

function Test-OnReceivedMatch {
    <#
    .SYNOPSIS
    受信データがOnReceivedルールにマッチするかチェック
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

function Invoke-AutoResponse {
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

    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        return
    }

    $conn = $Global:Connections[$ConnectionId]

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
        Write-Host "[AutoResponse] Rule matched ($matchedCount): $ruleName" -ForegroundColor Cyan

        # 遅延処理
        if ($rule.Delay -and [int]$rule.Delay -gt 0) {
            Start-Sleep -Milliseconds ([int]$rule.Delay)
        }

        # アクションタイプに応じて処理
        $actionType = if ($rule.PSObject.Properties.Name -contains '__ActionType') {
            $rule.__ActionType
        } else {
            'AutoResponse'
        }

        switch ($actionType) {
            'AutoResponse' {
                # AutoResponse処理のみ
                Invoke-BinaryAutoResponse -ConnectionId $ConnectionId -Rule $rule -Connection $conn
            }
            'OnReceived' {
                # OnReceivedスクリプト実行のみ
                Invoke-OnReceivedScript -ConnectionId $ConnectionId -ReceivedData $ReceivedData -Rule $rule -Connection $conn
            }
            'Both' {
                # 両方実行（AutoResponse → OnReceived の順）
                Invoke-BinaryAutoResponse -ConnectionId $ConnectionId -Rule $rule -Connection $conn
                Invoke-OnReceivedScript -ConnectionId $ConnectionId -ReceivedData $ReceivedData -Rule $rule -Connection $conn
            }
            'None' {
                Write-Warning "[AutoResponse] Rule has no action defined: $ruleName"
            }
            default {
                # 旧形式の場合
                if ($rule.__RuleType -eq 'AutoResponse_Legacy') {
                    Invoke-TextAutoResponse -ConnectionId $ConnectionId -Rule $rule -Connection $conn -DefaultEncoding $defaultEncoding
                } else {
                    Invoke-BinaryAutoResponse -ConnectionId $ConnectionId -Rule $rule -Connection $conn
                }
            }
        }

        # 複数ルール対応: breakせずに継続
    }

    if ($matchedCount -gt 0) {
        Write-Host "[AutoResponse] Total $matchedCount rule(s) processed" -ForegroundColor Green
    }
}

function Invoke-BinaryAutoResponse {
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
        Write-Warning "[AutoResponse] ResponseMessageFile is not specified in the rule"
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
        Write-Warning "[AutoResponse] Response message file not found: $messageFilePath"
        return
    }

    # 電文ファイルを読み込む
    try {
        $templates = Get-MessageTemplateCache -FilePath $messageFilePath -ThrowOnMissing
    } catch {
        Write-Warning "[AutoResponse] Failed to load response message file: $_"
        return
    }

    if (-not $templates -or $templates.Count -eq 0) {
        Write-Warning "[AutoResponse] No templates found in $messageFilePath"
        return
    }

    # DEFAULTテンプレートを取得（新形式の電文定義は常にDEFAULT名で格納される）
    if (-not $templates.ContainsKey('DEFAULT')) {
        Write-Warning "[AutoResponse] DEFAULT template not found in $messageFilePath"
        return
    }

    $template = $templates['DEFAULT']

    # 16進数ストリームをバイト配列に変換
    try {
        $responseBytes = ConvertTo-ByteArray -Data $template.Format -Encoding 'HEX'
    } catch {
        Write-Warning "[AutoResponse] Failed to convert hex stream to bytes: $_"
        return
    }

    # 送信
    try {
        Send-Data -ConnectionId $ConnectionId -Data $responseBytes
        $hexPreview = $template.Format
        if ($hexPreview.Length -gt 40) {
            $hexPreview = $hexPreview.Substring(0, 40) + "..."
        }
        Write-Host "[AutoResponse] Sent message from $($Rule.ResponseMessageFile) (${hexPreview})" -ForegroundColor Blue
    } catch {
        Write-Warning "[AutoResponse] Failed to send auto-response: $_"
    }
}

function Invoke-TextAutoResponse {
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
        Write-Warning "[AutoResponse] Failed to encode auto-response message: $_"
        return
    }

    try {
        Send-Data -ConnectionId $ConnectionId -Data $responseBytes
        Write-Host "[AutoResponse] Auto-responded: $response" -ForegroundColor Blue
    } catch {
        Write-Warning "[AutoResponse] Failed to send auto-response: $_"
    }
}

function Invoke-OnReceivedScript {
    <#
    .SYNOPSIS
    OnReceivedスクリプトを実行
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
        Write-Warning "[OnReceived] ScriptFile is not specified"
        return
    }

    # スクリプトファイルのパスを解決
    $scriptPath = $Rule.ScriptFile

    # 相対パスの場合、インスタンスのscenarios/onreceivedフォルダからの相対パス
    if (-not [System.IO.Path]::IsPathRooted($scriptPath)) {
        if ($Connection.Variables.ContainsKey('InstancePath')) {
            $instancePath = $Connection.Variables['InstancePath']
            $scriptPath = Join-Path $instancePath "scenarios\onreceived\$scriptPath"
        }
    }

    if (-not (Test-Path -LiteralPath $scriptPath)) {
        Write-Warning "[OnReceived] Script file not found: $scriptPath"
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
        Write-Host "[OnReceived] Executing script: $($Rule.ScriptFile)" -ForegroundColor Blue

        # スクリプトを実行
        $scriptBlock = [scriptblock]::Create((Get-Content -LiteralPath $scriptPath -Raw -Encoding UTF8))

        # スクリプトに変数を渡して実行
        & $scriptBlock -Context $scriptContext

        Write-Host "[OnReceived] Script executed successfully" -ForegroundColor Green
    } catch {
        Write-Warning "[OnReceived] Script execution failed: $_"
        Write-Warning $_.ScriptStackTrace
    }
}



