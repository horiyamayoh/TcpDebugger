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

    # CSV読み込み
    $rules = Import-Csv -Path $FilePath -Encoding UTF8

    Write-Host "[AutoResponse] Loaded $($rules.Count) rules from $FilePath" -ForegroundColor Green

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

        Write-Host "[AutoResponse] Rule matched: $($rule.TriggerPattern)" -ForegroundColor Cyan

        if ($rule.Delay -and [int]$rule.Delay -gt 0) {
            Start-Sleep -Milliseconds ([int]$rule.Delay)
        }

        $responseTemplate = if ($rule.ResponseTemplate) { $rule.ResponseTemplate } else { "" }
        $response = Expand-MessageVariables -Template $responseTemplate -Variables $conn.Variables

        $responseEncoding = if ($rule.Encoding) { $rule.Encoding } else { $defaultEncoding }

        try {
            $responseBytes = ConvertTo-ByteArray -Data $response -Encoding $responseEncoding
        } catch {
            Write-Warning "[AutoResponse] Failed to encode auto-response message: $_"
            continue
        }

        try {
            Send-Data -ConnectionId $ConnectionId -Data $responseBytes
            Write-Host "[AutoResponse] Auto-responded: $response" -ForegroundColor Blue
        } catch {
            Write-Warning "[AutoResponse] Failed to send auto-response: $_"
        }

        break
    }
}

# Export-ModuleMember -Function @(
#     'Read-AutoResponseRules',
#     'Test-AutoResponseMatch',
#     'Invoke-AutoResponse'
# )
