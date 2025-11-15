# AutoResponse.ps1
# 自動応答処理モジュール

function Read-AutoResponseRules {
    <#
    .SYNOPSIS
    自動応答ルールを読み込み
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "AutoResponse file not found: $FilePath"
        return @()
    }

    # Shift-JISでCSV読み込み
    $sjisEncoding = [System.Text.Encoding]::GetEncoding("Shift_JIS")
    $rules = Import-Csv -Path $FilePath -Encoding $sjisEncoding

    # 新形式（バイナリマッチング）か旧形式（テキストマッチング）かを判定
    $isNewFormat = $false
    if ($rules.Count -gt 0) {
        $firstRule = $rules[0]
        # 新形式の必須フィールド: MatchOffset, MatchLength, MatchValue, ResponseMessageFile
        if ($firstRule.PSObject.Properties.Name -contains 'MatchOffset' -and
            $firstRule.PSObject.Properties.Name -contains 'MatchLength' -and
            $firstRule.PSObject.Properties.Name -contains 'MatchValue' -and
            $firstRule.PSObject.Properties.Name -contains 'ResponseMessageFile') {
            $isNewFormat = $true
        }
    }

    # ルールにフォーマット情報を追加
    foreach ($rule in $rules) {
        $rule | Add-Member -NotePropertyName '__Format' -NotePropertyValue $(if ($isNewFormat) { 'Binary' } else { 'Text' }) -Force
    }

    $formatType = if ($isNewFormat) { "Binary" } else { "Text" }
    Write-Host "[AutoResponse] Loaded $($rules.Count) rules (Format: $formatType) from $FilePath" -ForegroundColor Green

    return $rules
}

function Test-AutoResponseMatch {
    <#
    .SYNOPSIS
    受信データが自動応答ルールにマッチするかチェック
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$ReceivedData,

        [Parameter(Mandatory=$true)]
        [object]$Rule,

        [Parameter(Mandatory=$false)]
        [string]$Encoding = "UTF-8"
    )

    if (-not $Rule -or -not $ReceivedData) {
        return $false
    }

    # 新形式（バイナリマッチング）の場合
    if ($Rule.__Format -eq 'Binary') {
        return Test-BinaryPatternMatch -ReceivedData $ReceivedData -Rule $Rule
    }

    # 旧形式（テキストマッチング）の場合
    $pattern = $Rule.TriggerPattern
    if ([string]::IsNullOrWhiteSpace($pattern)) {
        return $false
    }

    $effectiveEncoding = if ($Rule.Encoding) { $Rule.Encoding } elseif ($Encoding) { $Encoding } else { "UTF-8" }

    try {
        $receivedText = ConvertFrom-ByteArray -Data $ReceivedData -Encoding $effectiveEncoding
    } catch {
        Write-Warning "[AutoResponse] Failed to decode received data with encoding '$effectiveEncoding': $_"
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
                Write-Warning "[AutoResponse] Invalid regex pattern '$pattern': $_"
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

function Test-BinaryPatternMatch {
    <#
    .SYNOPSIS
    バイナリデータのパターンマッチング（新形式）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$ReceivedData,

        [Parameter(Mandatory=$true)]
        [object]$Rule
    )

    # 必須パラメータチェック
    if ([string]::IsNullOrWhiteSpace($Rule.MatchOffset) -or
        [string]::IsNullOrWhiteSpace($Rule.MatchLength) -or
        [string]::IsNullOrWhiteSpace($Rule.MatchValue)) {
        Write-Warning "[AutoResponse] Binary rule missing required fields: MatchOffset, MatchLength, or MatchValue"
        return $false
    }

    # パラメータ解析
    try {
        $offset = [int]($Rule.MatchOffset)
        $length = [int]($Rule.MatchLength)
        $hexValue = $Rule.MatchValue.Trim() -replace '\s', '' -replace '0x', ''
    } catch {
        Write-Warning "[AutoResponse] Failed to parse binary match parameters: $_"
        return $false
    }

    # オフセットと長さのバリデーション
    if ($offset -lt 0 -or $length -le 0) {
        Write-Warning "[AutoResponse] Invalid offset ($offset) or length ($length)"
        return $false
    }

    if ($offset + $length -gt $ReceivedData.Length) {
        # 受信データが短すぎる
        return $false
    }

    # 16進数値のバリデーション
    if ($hexValue -notmatch '^[0-9A-Fa-f]+$') {
        Write-Warning "[AutoResponse] MatchValue contains invalid hex characters: $hexValue"
        return $false
    }

    if ($hexValue.Length % 2 -ne 0) {
        Write-Warning "[AutoResponse] MatchValue has odd length: $hexValue"
        return $false
    }

    # 長さチェック
    $expectedBytes = $hexValue.Length / 2
    if ($expectedBytes -ne $length) {
        Write-Warning "[AutoResponse] MatchValue length ($expectedBytes bytes) doesn't match MatchLength ($length)"
        return $false
    }

    # 16進数文字列をバイト配列に変換
    $expectedBytes = @()
    for ($i = 0; $i -lt $hexValue.Length; $i += 2) {
        $hexByte = $hexValue.Substring($i, 2)
        $expectedBytes += [Convert]::ToByte($hexByte, 16)
    }

    # 受信データの該当部分と比較
    for ($i = 0; $i -lt $length; $i++) {
        if ($ReceivedData[$offset + $i] -ne $expectedBytes[$i]) {
            return $false
        }
    }

    return $true
}

function Get-ConnectionAutoResponseRules {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Connection
    )

    if (-not $Connection -or -not $Connection.Variables.ContainsKey('AutoResponseProfilePath')) {
        return @()
    }

    $profilePath = $Connection.Variables['AutoResponseProfilePath']
    if (-not $profilePath) {
        return @()
    }

    if (-not (Test-Path -LiteralPath $profilePath)) {
        Write-Warning "[AutoResponse] Profile path not found: $profilePath"
        $Connection.Variables['AutoResponseRulesCache'] = $null
        return @()
    }

    $resolved = (Resolve-Path -LiteralPath $profilePath).Path
    $fileInfo = Get-Item -LiteralPath $resolved
    $lastWrite = $fileInfo.LastWriteTimeUtc

    $cache = $null
    if ($Connection.Variables.ContainsKey('AutoResponseRulesCache')) {
        $cache = $Connection.Variables['AutoResponseRulesCache']
        if ($cache -and $cache.LastWriteTimeUtc -eq $lastWrite) {
            return $cache.Rules
        }
    }

    try {
        $rules = Read-AutoResponseRules -FilePath $resolved
    } catch {
        Write-Warning "[AutoResponse] Failed to load rules: $_"
        $Connection.Variables['AutoResponseRulesCache'] = $null
        return @()
    }

    $Connection.Variables['AutoResponseRulesCache'] = @{
        LastWriteTimeUtc = $lastWrite
        Rules            = $rules
    }

    return $rules
}

function Set-ConnectionAutoResponseProfile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,

        [Parameter(Mandatory=$false)]
        [string]$ProfileName,

        [Parameter(Mandatory=$false)]
        [string]$ProfilePath
    )

    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        throw "Connection not found: $ConnectionId"
    }

    $conn = $Global:Connections[$ConnectionId]

    if ([string]::IsNullOrWhiteSpace($ProfileName) -or -not $ProfilePath) {
        $conn.Variables.Remove('AutoResponseProfile')
        $conn.Variables.Remove('AutoResponseProfilePath')
        $conn.Variables.Remove('AutoResponseRulesCache')
        Write-Host "[AutoResponse] Cleared auto-response profile for $($conn.DisplayName)" -ForegroundColor Yellow
        return @()
    }

    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        throw "Auto-response profile not found: $ProfilePath"
    }

    $resolved = (Resolve-Path -LiteralPath $ProfilePath).Path
    $conn.Variables['AutoResponseProfile'] = $ProfileName
    $conn.Variables['AutoResponseProfilePath'] = $resolved
    $conn.Variables.Remove('AutoResponseRulesCache')

    Write-Host "[AutoResponse] Profile '$ProfileName' applied to $($conn.DisplayName)" -ForegroundColor Green

    return Get-ConnectionAutoResponseRules -Connection $conn
}

function Invoke-ConnectionAutoResponse {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,

        [Parameter(Mandatory=$true)]
        [byte[]]$ReceivedData
    )

    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        return
    }

    $conn = $Global:Connections[$ConnectionId]
    if (-not $conn.Variables.ContainsKey('AutoResponseProfilePath')) {
        return
    }

    try {
        $rules = Get-ConnectionAutoResponseRules -Connection $conn
    } catch {
        Write-Warning "[AutoResponse] Unable to load auto-response rules: $_"
        return
    }

    if (-not $rules -or $rules.Count -eq 0) {
        return
    }

    Invoke-AutoResponse -ConnectionId $ConnectionId -ReceivedData $ReceivedData -Rules $rules
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

    foreach ($rule in $Rules) {
        $matchEncoding = if ($rule.Encoding) { $rule.Encoding } else { $defaultEncoding }

        if (-not (Test-AutoResponseMatch -ReceivedData $ReceivedData -Rule $rule -Encoding $matchEncoding)) {
            continue
        }

        # マッチした場合の処理
        $ruleName = if ($rule.RuleName) { $rule.RuleName } else { "Unknown" }
        Write-Host "[AutoResponse] Rule matched: $ruleName" -ForegroundColor Cyan

        # 遅延処理
        if ($rule.Delay -and [int]$rule.Delay -gt 0) {
            Start-Sleep -Milliseconds ([int]$rule.Delay)
        }

        # 新形式（バイナリマッチング）の場合
        if ($rule.__Format -eq 'Binary') {
            Invoke-BinaryAutoResponse -ConnectionId $ConnectionId -Rule $rule -Connection $conn
        } else {
            # 旧形式（テキストマッチング）の場合
            Invoke-TextAutoResponse -ConnectionId $ConnectionId -Rule $rule -Connection $conn -DefaultEncoding $defaultEncoding
        }

        break
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

# Export-ModuleMember -Function @(
#     'Read-AutoResponseRules',
#     'Test-AutoResponseMatch',
#     'Invoke-AutoResponse'
# )
