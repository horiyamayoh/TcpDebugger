# AutoResponse.ps1
# �����������W���[��
#
# [DEPRECATED] ���̃��W���[���́AReceivedEventPipeline�ɂ��苝�ރ��W�b�N���ύX����Ă��܂��B
# �V�����R�[�h�ł́AReceivedEventPipeline���g�p���Ă��������B
# ���̊֐����͌�������݊����̂��߂ɂ̂ݎc����Ă��܂��B

function Read-AutoResponseRules {
    <#
    .SYNOPSIS
    自動応答ルールを読み込み
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    # 共通エンジンを使用
    return Read-ReceivedRules -FilePath $FilePath -RuleType "AutoResponse"
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

    # 共通エンジンを使用
    return Test-ReceivedRuleMatch -ReceivedData $ReceivedData -Rule $Rule -DefaultEncoding $Encoding
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

    try {
        $repository = Get-RuleRepository
        return $repository.GetRules($profilePath)
    } catch {
        Write-Warning "[AutoResponse] Failed to load rules: $_"
        return @()
    }
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

    $conn = Get-ManagedConnection -ConnectionId $ConnectionId

    if ([string]::IsNullOrWhiteSpace($ProfileName) -or -not $ProfilePath) {
        $conn.Variables.Remove('AutoResponseProfile')
        $conn.Variables.Remove('AutoResponseProfilePath')
        Write-Host "[AutoResponse] Cleared auto-response profile for $($conn.DisplayName)" -ForegroundColor Yellow
        return @()
    }

    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        throw "Auto-response profile not found: $ProfilePath"
    }

    $resolved = (Resolve-Path -LiteralPath $ProfilePath).Path
    $conn.Variables['AutoResponseProfile'] = $ProfileName
    $conn.Variables['AutoResponseProfilePath'] = $resolved

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

    $conn = Get-ManagedConnection -ConnectionId $ConnectionId
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

    $conn = Get-ManagedConnection -ConnectionId $ConnectionId

    $defaultEncoding = "UTF-8"
    if ($conn.Variables.ContainsKey('DefaultEncoding') -and $conn.Variables['DefaultEncoding']) {
        $defaultEncoding = $conn.Variables['DefaultEncoding']
    }

    $matchedCount = 0

    foreach ($rule in $Rules) {
        $matchEncoding = if ($rule.Encoding) { $rule.Encoding } else { $defaultEncoding }

        if (-not (Test-AutoResponseMatch -ReceivedData $ReceivedData -Rule $rule -Encoding $matchEncoding)) {
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

# Export-ModuleMember -Function @(
#     'Read-AutoResponseRules',
#     'Test-AutoResponseMatch',
#     'Invoke-AutoResponse'
# )

