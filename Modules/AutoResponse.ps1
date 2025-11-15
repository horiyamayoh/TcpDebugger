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
    
    Execute auto response




    if (-not $Rules -or $Rules.Count -eq 0) {
        return
    }

    $defaultEncoding = "UTF-8"
    if ($conn.Variables.ContainsKey('DefaultEncoding') -and $conn.Variables['DefaultEncoding']) {
        $defaultEncoding = $conn.Variables['DefaultEncoding']
    }

        if (Test-AutoResponseMatch -ReceivedData $ReceivedData -Rule $rule -Encoding $defaultEncoding) {



            $encoding = if ($rule.Encoding) { $rule.Encoding } else { $defaultEncoding }

            try {
                Send-Data -ConnectionId $ConnectionId -Data $responseBytes
                Write-Host "[AutoResponse] Auto-responded: $response" -ForegroundColor Blue
            } catch {
                Write-Warning "[AutoResponse] Failed to send auto-response: $_"
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
    
    foreach ($rule in $Rules) {
        # マッチング判定
        if (Test-AutoResponseMatch -ReceivedData $ReceivedData -Rule $rule) {
            Write-Host "[AutoResponse] Rule matched: $($rule.TriggerPattern)" -ForegroundColor Cyan
            
            # ディレイ
            if ($rule.Delay -and [int]$rule.Delay -gt 0) {
                Start-Sleep -Milliseconds ([int]$rule.Delay)
            }
            
            # 応答メッセージ生成
            $response = Expand-MessageVariables -Template $rule.ResponseTemplate -Variables $conn.Variables
            
            # エンコーディング
            $encoding = if ($rule.Encoding) { $rule.Encoding } else { "UTF-8" }
            $responseBytes = ConvertTo-ByteArray -Data $response -Encoding $encoding
            
            # 送信
            Send-Data -ConnectionId $ConnectionId -Data $responseBytes
            
            Write-Host "[AutoResponse] Auto-responded: $response" -ForegroundColor Blue
            
            # 最初にマッチしたルールのみ実行
            break
        }
    }
}

# Export-ModuleMember -Function @(
#     'Read-AutoResponseRules',
#     'Test-AutoResponseMatch',
#     'Invoke-AutoResponse'
# )
