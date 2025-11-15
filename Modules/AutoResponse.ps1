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
    
    # バイト配列を文字列に変換
    $receivedText = ConvertFrom-ByteArray -Data $ReceivedData -Encoding $Encoding
    
    # マッチタイプによる判定
    switch ($Rule.MatchType) {
        "Regex" {
            return $receivedText -match $Rule.TriggerPattern
        }
        "Exact" {
            return $receivedText -eq $Rule.TriggerPattern
        }
        "Contains" {
            return $receivedText -like "*$($Rule.TriggerPattern)*"
        }
        default {
            # デフォルトはContains
            return $receivedText -like "*$($Rule.TriggerPattern)*"
        }
    }
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
