# OnReceivedHandler.ps1
# ��M���A�N�V��������W���[��
#
# [DEPRECATED] ���̃��W���[���́AReceivedEventPipeline�ɂ��苝�ރ��W�b�N���ύX����Ă��܂��B
# �V�����R�[�h�ł́AReceivedEventPipeline���g�p���Ă��������B
# ���̊֐����͌�������݊����̂��߂ɂ̂ݎc����Ă��܂��B

function Read-OnReceivedRules {
    <#
    .SYNOPSIS
    OnReceived ルールを読み込み
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    # 共通エンジンを使用
    return Read-ReceivedRules -FilePath $FilePath -RuleType "OnReceived"
}

function Get-ConnectionOnReceivedRules {
    <#
    .SYNOPSIS
    コネクションのOnReceivedルールを取得（キャッシュ付き）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Connection
    )

    if (-not $Connection -or -not $Connection.Variables.ContainsKey('OnReceivedProfilePath')) {
        return @()
    }

    $profilePath = $Connection.Variables['OnReceivedProfilePath']
    if (-not $profilePath) {
        return @()
    }

    try {
        $repository = Get-RuleRepository
        return $repository.GetRules($profilePath)
    } catch {
        Write-Warning "[OnReceived] Failed to load rules: $_"
        return @()
    }
}

function Set-ConnectionOnReceivedProfile {
    <#
    .SYNOPSIS
    コネクションにOnReceivedプロファイルを設定
    #>
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
        $conn.Variables.Remove('OnReceivedProfile')
        $conn.Variables.Remove('OnReceivedProfilePath')
        Write-Host "[OnReceived] Cleared OnReceived profile for $($conn.DisplayName)" -ForegroundColor Yellow
        return @()
    }

    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        throw "OnReceived profile not found: $ProfilePath"
    }

    $resolved = (Resolve-Path -LiteralPath $ProfilePath).Path
    $conn.Variables['OnReceivedProfile'] = $ProfileName
    $conn.Variables['OnReceivedProfilePath'] = $resolved

    Write-Host "[OnReceived] Profile '$ProfileName' applied to $($conn.DisplayName)" -ForegroundColor Green

    return Get-ConnectionOnReceivedRules -Connection $conn
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

function Invoke-ConnectionOnReceived {
    <#
    .SYNOPSIS
    受信データに対してOnReceivedアクションを実行
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,

        [Parameter(Mandatory=$true)]
        [byte[]]$ReceivedData
    )

    $conn = Get-ManagedConnection -ConnectionId $ConnectionId
    if (-not $conn.Variables.ContainsKey('OnReceivedProfilePath')) {
        return
    }

    try {
        $rules = Get-ConnectionOnReceivedRules -Connection $conn
    } catch {
        Write-Warning "[OnReceived] Unable to load rules: $_"
        return
    }

    if (-not $rules -or $rules.Count -eq 0) {
        return
    }

    $matchedCount = 0

    foreach ($rule in $rules) {
        if (-not (Test-OnReceivedMatch -ReceivedData $ReceivedData -Rule $rule)) {
            continue
        }

        $matchedCount++

        $ruleName = if ($rule.RuleName) { $rule.RuleName } else { "Unknown" }
        Write-Host "[OnReceived] Rule matched ($matchedCount): $ruleName" -ForegroundColor Cyan

        # 遅延処理
        if ($rule.Delay -and [int]$rule.Delay -gt 0) {
            Start-Sleep -Milliseconds ([int]$rule.Delay)
        }

        Invoke-OnReceivedScript -ConnectionId $ConnectionId -ReceivedData $ReceivedData -Rule $rule -Connection $conn
        
        # 複数ルール対応: breakせずに継続
    }

    if ($matchedCount -gt 0) {
        Write-Host "[OnReceived] Total $matchedCount rule(s) processed" -ForegroundColor Green
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


