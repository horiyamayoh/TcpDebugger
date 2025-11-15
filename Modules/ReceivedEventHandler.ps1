# ReceivedEventHandler.ps1
# 受信イベント統合ハンドラ（AutoResponse + OnReceived）

function Invoke-ReceivedEvent {
    <#
    .SYNOPSIS
    受信イベント処理（AutoResponseとOnReceivedを統合実行）
    #>
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

    # 統合ルールファイルの存在確認
    $hasUnifiedRules = $false
    if ($conn.Variables.ContainsKey('AutoResponseProfilePath')) {
        $autoPath = $conn.Variables['AutoResponseProfilePath']
        if ($autoPath -and (Test-Path -LiteralPath $autoPath)) {
            # ルールタイプを確認
            try {
                $testRules = Read-ReceivedRules -FilePath $autoPath
                if ($testRules.Count -gt 0 -and $testRules[0].__RuleType -eq 'Unified') {
                    $hasUnifiedRules = $true
                }
            } catch {
                # エラーは無視（後続処理でハンドリング）
            }
        }
    }

    if ($hasUnifiedRules) {
        # 統合形式の場合: AutoResponseプロファイルのみで全処理
        Invoke-ConnectionAutoResponse -ConnectionId $ConnectionId -ReceivedData $ReceivedData
    } else {
        # 個別形式の場合: AutoResponseとOnReceivedを別々に実行
        
        # 1. AutoResponse処理
        if ($conn.Variables.ContainsKey('AutoResponseProfilePath') -and 
            $conn.Variables['AutoResponseProfilePath']) {
            Invoke-ConnectionAutoResponse -ConnectionId $ConnectionId -ReceivedData $ReceivedData
        }

        # 2. OnReceived処理
        if ($conn.Variables.ContainsKey('OnReceivedProfilePath') -and 
            $conn.Variables['OnReceivedProfilePath']) {
            Invoke-ConnectionOnReceived -ConnectionId $ConnectionId -ReceivedData $ReceivedData
        }
    }
}

function Set-ConnectionReceivedProfiles {
    <#
    .SYNOPSIS
    接続に対してAutoResponseとOnReceivedのプロファイルを設定
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,

        [Parameter(Mandatory=$false)]
        [string]$AutoResponseProfileName,

        [Parameter(Mandatory=$false)]
        [string]$AutoResponseProfilePath,

        [Parameter(Mandatory=$false)]
        [string]$OnReceivedProfileName,

        [Parameter(Mandatory=$false)]
        [string]$OnReceivedProfilePath
    )

    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        throw "Connection not found: $ConnectionId"
    }

    $conn = $Global:Connections[$ConnectionId]

    # AutoResponseプロファイル設定
    if (-not [string]::IsNullOrWhiteSpace($AutoResponseProfilePath)) {
        if (Test-Path -LiteralPath $AutoResponseProfilePath) {
            $resolved = (Resolve-Path -LiteralPath $AutoResponseProfilePath).Path
            $conn.Variables['AutoResponseProfile'] = $AutoResponseProfileName
            $conn.Variables['AutoResponseProfilePath'] = $resolved
            $conn.Variables.Remove('AutoResponseRulesCache')
            Write-Host "[ReceivedEvent] AutoResponse profile '$AutoResponseProfileName' set" -ForegroundColor Green
        } else {
            Write-Warning "[ReceivedEvent] AutoResponse profile not found: $AutoResponseProfilePath"
        }
    } elseif ([string]::IsNullOrWhiteSpace($AutoResponseProfileName)) {
        # クリア
        $conn.Variables.Remove('AutoResponseProfile')
        $conn.Variables.Remove('AutoResponseProfilePath')
        $conn.Variables.Remove('AutoResponseRulesCache')
        Write-Host "[ReceivedEvent] AutoResponse profile cleared" -ForegroundColor Yellow
    }

    # OnReceivedプロファイル設定
    if (-not [string]::IsNullOrWhiteSpace($OnReceivedProfilePath)) {
        if (Test-Path -LiteralPath $OnReceivedProfilePath) {
            $resolved = (Resolve-Path -LiteralPath $OnReceivedProfilePath).Path
            $conn.Variables['OnReceivedProfile'] = $OnReceivedProfileName
            $conn.Variables['OnReceivedProfilePath'] = $resolved
            $conn.Variables.Remove('OnReceivedRulesCache')
            Write-Host "[ReceivedEvent] OnReceived profile '$OnReceivedProfileName' set" -ForegroundColor Green
        } else {
            Write-Warning "[ReceivedEvent] OnReceived profile not found: $OnReceivedProfilePath"
        }
    } elseif ([string]::IsNullOrWhiteSpace($OnReceivedProfileName)) {
        # クリア
        $conn.Variables.Remove('OnReceivedProfile')
        $conn.Variables.Remove('OnReceivedProfilePath')
        $conn.Variables.Remove('OnReceivedRulesCache')
        Write-Host "[ReceivedEvent] OnReceived profile cleared" -ForegroundColor Yellow
    }
}

function Get-ConnectionReceivedProfiles {
    <#
    .SYNOPSIS
    接続の受信イベントプロファイル情報を取得
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )

    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        return $null
    }

    $conn = $Global:Connections[$ConnectionId]

    return [PSCustomObject]@{
        AutoResponseProfile = if ($conn.Variables.ContainsKey('AutoResponseProfile')) { 
            $conn.Variables['AutoResponseProfile'] 
        } else { 
            $null 
        }
        AutoResponseProfilePath = if ($conn.Variables.ContainsKey('AutoResponseProfilePath')) { 
            $conn.Variables['AutoResponseProfilePath'] 
        } else { 
            $null 
        }
        OnReceivedProfile = if ($conn.Variables.ContainsKey('OnReceivedProfile')) { 
            $conn.Variables['OnReceivedProfile'] 
        } else { 
            $null 
        }
        OnReceivedProfilePath = if ($conn.Variables.ContainsKey('OnReceivedProfilePath')) { 
            $conn.Variables['OnReceivedProfilePath'] 
        } else { 
            $null 
        }
    }
}

