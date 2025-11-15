# ReceivedRuleEngine.ps1
# 受信時のルール処理エンジン（AutoResponse/OnReceived共通）

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

