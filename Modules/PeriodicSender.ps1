# PeriodicSender.ps1
# [DEPRECATED] このモジュールは非推奨です。MessageServiceを直接使用してください。
# 定周期送信モジュール

function Read-PeriodicSendRules {
    <#
    .SYNOPSIS
    定周期送信ルールCSVを読み込み
    .DESCRIPTION
    CSV形式:
    - RuleName: ルール名（省略可）
    - MessageFile: 送信する電文テンプレートファイル（templates/内の相対パス）
    - IntervalMs: 送信周期（ミリ秒、10進数）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$InstancePath
    )
    
    if (-not (Test-Path -LiteralPath $FilePath)) {
        Write-Warning "[PeriodicSender] Rule file not found: $FilePath"
        return @()
    }
    
    try {
        # Shift-JIS で読み込み
        $encoding = [System.Text.Encoding]::GetEncoding("Shift_JIS")
        $rules = Import-Csv -Path $FilePath -Encoding $encoding
        
        $validRules = @()
        foreach ($rule in $rules) {
            # 必須フィールドチェック
            if ([string]::IsNullOrWhiteSpace($rule.MessageFile)) {
                Write-Warning "[PeriodicSender] Skipping rule with empty MessageFile"
                continue
            }
            
            if ([string]::IsNullOrWhiteSpace($rule.IntervalMs)) {
                Write-Warning "[PeriodicSender] Skipping rule '$($rule.RuleName)' with empty IntervalMs"
                continue
            }
            
            # IntervalMs を数値に変換
            $intervalMs = 0
            if (-not [int]::TryParse($rule.IntervalMs, [ref]$intervalMs) -or $intervalMs -le 0) {
                Write-Warning "[PeriodicSender] Invalid IntervalMs for rule '$($rule.RuleName)': $($rule.IntervalMs)"
                continue
            }
            
            # MessageFile の絶対パスを解決
            $templatesPath = Join-Path $InstancePath "templates"
            $messageFilePath = Join-Path $templatesPath $rule.MessageFile
            
            if (-not (Test-Path -LiteralPath $messageFilePath)) {
                Write-Warning "[PeriodicSender] MessageFile not found: $messageFilePath"
                continue
            }
            
            $validRules += [PSCustomObject]@{
                RuleName = if ($rule.RuleName) { $rule.RuleName } else { "Rule-$($validRules.Count + 1)" }
                MessageFile = $messageFilePath
                IntervalMs = $intervalMs
            }
        }
        
        Write-Host "[PeriodicSender] Loaded $($validRules.Count) periodic send rules from $FilePath" -ForegroundColor Green
        return $validRules
        
    } catch {
        Write-Error "[PeriodicSender] Failed to read periodic send rules: $_"
        return @()
    }
}

function Start-PeriodicSend {
    <#
    .SYNOPSIS
    指定された接続で定周期送信を開始
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,
        
        [Parameter(Mandatory=$true)]
        [string]$RuleFilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$InstancePath
    )
    
    try {
        $connection = Get-ManagedConnection -ConnectionId $ConnectionId
    } catch {
        Write-Warning "[PeriodicSender] Connection not found: $ConnectionId"
        return
    }
    
    # 既存のタイマーを停止
    Stop-PeriodicSend -ConnectionId $ConnectionId
    
    # ルールを読み込み
    $rules = Read-PeriodicSendRules -FilePath $RuleFilePath -InstancePath $InstancePath
    
    if ($rules.Count -eq 0) {
        Write-Host "[PeriodicSender] No valid periodic send rules found" -ForegroundColor Yellow
        return
    }
    
    # 接続にタイマーリストを格納
    if (-not $connection.PeriodicTimers) {
        $connection.PeriodicTimers = New-Object System.Collections.Generic.List[object]
    }
    
    # 各ルールに対してタイマーを作成
    foreach ($rule in $rules) {
        $timer = New-Object System.Timers.Timer
        $timer.Interval = $rule.IntervalMs
        $timer.AutoReset = $true
        
        # タイマーイベント設定
        $timerEvent = Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
            param($sender, $eventArgs)
            
            $connId = $Event.MessageData.ConnectionId
            $messageFile = $Event.MessageData.MessageFile
            $ruleName = $Event.MessageData.RuleName
            
            $service = Get-ConnectionService
            $conn = $service.GetConnection($connId)
            if (-not $conn) {
                return
            }
            
            # 接続が切断されている場合はスキップ
            if ($conn.Status -ne "CONNECTED") {
                return
            }
            
            try {
                $templates = Get-MessageTemplateCache -FilePath $messageFile -ThrowOnMissing
                if (-not $templates -or -not $templates.ContainsKey('DEFAULT')) {
                    Write-Warning "[PeriodicSender] DEFAULT template not found in: $messageFile"
                    return
                }

                $template = $templates['DEFAULT']
                if (-not $template -or -not $template.Format) {
                    Write-Warning "[PeriodicSender] Template format is empty: $messageFile"
                    return
                }

                $byteArray = ConvertTo-ByteArray -Data $template.Format -Encoding 'HEX'
                Send-Data -ConnectionId $connId -Data $byteArray
                
                Write-Host "[PeriodicSender] [$($conn.DisplayName)] Sent periodic message '$ruleName': $($byteArray.Length) bytes" -ForegroundColor Cyan
                
            } catch {
                Write-Warning "[PeriodicSender] Failed to send periodic message '$ruleName': $_"
            }
        } -MessageData @{
            ConnectionId = $ConnectionId
            MessageFile = $rule.MessageFile
            RuleName = $rule.RuleName
        }
        
        # タイマー開始
        $timer.Start()
        
        # タイマー情報を保存
        $connection.PeriodicTimers.Add(@{
            Timer = $timer
            Event = $timerEvent
            RuleName = $rule.RuleName
            IntervalMs = $rule.IntervalMs
        })
        
        Write-Host "[PeriodicSender] Started periodic send '$($rule.RuleName)' every $($rule.IntervalMs)ms" -ForegroundColor Green
    }
    
    Write-Host "[PeriodicSender] Started $($rules.Count) periodic send timers for connection '$($connection.DisplayName)'" -ForegroundColor Green
}

function Stop-PeriodicSend {
    <#
    .SYNOPSIS
    指定された接続の定周期送信を停止
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )
    
    try {
        $connection = Get-ManagedConnection -ConnectionId $ConnectionId
    } catch {
        return
    }
    
    if (-not $connection.PeriodicTimers -or $connection.PeriodicTimers.Count -eq 0) {
        return
    }
    
    foreach ($timerInfo in $connection.PeriodicTimers) {
        try {
            # タイマー停止
            if ($timerInfo.Timer) {
                $timerInfo.Timer.Stop()
                $timerInfo.Timer.Dispose()
            }
            
            # イベント登録解除
            if ($timerInfo.Event) {
                Unregister-Event -SourceIdentifier $timerInfo.Event.Name -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Warning "[PeriodicSender] Failed to stop timer: $_"
        }
    }
    
    $count = $connection.PeriodicTimers.Count
    $connection.PeriodicTimers.Clear()
    
    Write-Host "[PeriodicSender] Stopped $count periodic send timers for connection '$($connection.DisplayName)'" -ForegroundColor Yellow
}

function Set-ConnectionPeriodicSendProfile {
    <#
    .SYNOPSIS
    接続に定周期送信プロファイルを設定
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,
        
        [Parameter(Mandatory=$false)]
        [string]$ProfilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$InstancePath
    )
    
    try {
        $connection = Get-ManagedConnection -ConnectionId $ConnectionId
    } catch {
        Write-Warning "[PeriodicSender] Connection not found: $ConnectionId"
        return
    }
    
    # 既存のタイマーを停止
    Stop-PeriodicSend -ConnectionId $ConnectionId
    
    # プロファイル情報をクリアまたは設定
    if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
        $connection.Variables.Remove('PeriodicSendProfile')
        $connection.Variables.Remove('PeriodicSendProfilePath')
        Write-Host "[PeriodicSender] Cleared periodic send profile for $($connection.DisplayName)" -ForegroundColor Yellow
        return
    }
    
    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        throw "Periodic send profile not found: $ProfilePath"
    }
    
    # プロファイル名を抽出（ファイル名からベース名を取得）
    $profileName = [System.IO.Path]::GetFileNameWithoutExtension($ProfilePath)
    $resolved = (Resolve-Path -LiteralPath $ProfilePath).Path
    
    # Variables に保存
    $connection.Variables['PeriodicSendProfile'] = $profileName
    $connection.Variables['PeriodicSendProfilePath'] = $resolved
    
    Write-Host "[PeriodicSender] Profile '$profileName' set for $($connection.DisplayName)" -ForegroundColor Green
    
    # プロファイルが指定されている場合は開始
    if ($connection.Status -eq "CONNECTED") {
        Start-PeriodicSend -ConnectionId $ConnectionId -RuleFilePath $resolved -InstancePath $InstancePath
    }
}

function Get-ConnectionPeriodicSendProfile {
    <#
    .SYNOPSIS
    接続の定周期送信プロファイルを取得
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )
    
    try {
        $connection = Get-ManagedConnection -ConnectionId $ConnectionId
    } catch {
        return $null
    }

    return $connection.PeriodicSendProfile
}


