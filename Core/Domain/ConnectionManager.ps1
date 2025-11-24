# ConnectionManager.ps1
# �ڑ��Ǘ����W���[�� - �����ڑ��̈ꌳ�Ǘ�

# デバッグ出力ヘルパー
function Write-DebugLog {
    param(
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    if ($script:EnableDebugOutput) {
        Write-Host $Message -ForegroundColor $ForegroundColor
    }
}

function Get-ConnectionService {
    if ($Global:ConnectionService) {
        return $Global:ConnectionService
    }
    throw "ConnectionService is not initialized. Please run TcpDebugger.ps1 to bootstrap services."
}

function Get-ManagedConnection {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )

    $service = Get-ConnectionService
    $conn = $service.GetConnection($ConnectionId)
    if (-not $conn) {
        throw "Connection not found: $ConnectionId"
    }
    return $conn
}

function New-ConnectionManager {
    <#
    .SYNOPSIS
    �ڑ��}�l�[�W���[��������
    #>
    
    Write-DebugLog "[ConnectionManager] Initializing..." "Cyan"
    
    $service = Get-ConnectionService
    foreach ($conn in @($service.GetAllConnections())) {
        try {
            Stop-Connection -ConnectionId $conn.Id -Force
        } catch {
            Write-Warning "Failed to stop connection $($conn.Id): $_"
        }
    }
    $service.ClearConnections()
    
    Write-DebugLog "[ConnectionManager] Initialized" "Green"
}

function Add-Connection {
    <#
    .SYNOPSIS
    �V�����ڑ���ǉ�
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )
    
    $service = Get-ConnectionService
    $conn = $service.AddConnection($Config)
    if (-not $conn) {
        throw "Failed to add connection."
    }
    
    Write-DebugLog "[ConnectionManager] Added connection: $($conn.DisplayName) [$($conn.Id)]" "Green"
    
    return $conn
}

function Remove-Connection {
    <#
    .SYNOPSIS
    �ڑ����폜
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )
    
    $service = Get-ConnectionService
    Stop-Connection -ConnectionId $ConnectionId -Force
    $service.RemoveConnection($ConnectionId)
    
    Write-DebugLog "[ConnectionManager] Removed connection: $ConnectionId" "Yellow"
}

function Start-Connection {
    <#
    .SYNOPSIS
    �ڑ����J�n
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )
    
    $conn = Get-ManagedConnection -ConnectionId $ConnectionId
    
    if ($conn.Status -eq "CONNECTED" -or $conn.Status -eq "CONNECTING") {
        Write-Warning "[ConnectionManager] Connection already active: $($conn.DisplayName)"
        return
    }
    
    $conn.UpdateStatus("CONNECTING")
    $conn.ClearError()
    
    # ���̃L�����Z���g�[�N�����N���[���A�b�v
    if ($conn.CancellationSource) {
        try {
            $conn.CancellationSource.Dispose()
        } catch {
            Write-Verbose "[ConnectionManager] Failed to dispose old CancellationSource: $_"
        }
        $conn.CancellationSource = $null
    }
    if ($conn.State.CancellationSource) {
        $conn.State.CancellationSource = $null
    }
    
    Write-DebugLog "[ConnectionManager] Starting connection: $($conn.DisplayName)" "Cyan"
    
    try {
        # ServiceContainer���K�v
        if (-not $Global:ServiceContainer) {
            throw "ServiceContainer is not initialized. Please run TcpDebugger.ps1 first."
        }
        
        # �V�����A�_�v�^�[�A�[�L�e�N�`�����g�p
        # �d�v: �A�_�v�^�[�C���X�^���X��GC�΍����Ƀ��l�N�V�����ɕۑ�
        switch ($conn.Protocol) {
            "TCP" {
                if ($conn.Mode -eq "Client") {
                    $adapter = $Global:ServiceContainer.Resolve('TcpClientAdapter')
                    # �A�_�v�^�[�𕛑�����ăX���b�h�����̎Q�Ƃ��ێ�
                    if (-not $conn.Variables) {
                        $conn.Variables = @{}
                    }
                    $conn.Variables['_Adapter'] = $adapter
                    $adapter.Start($ConnectionId)
                } elseif ($conn.Mode -eq "Server") {
                    $adapter = $Global:ServiceContainer.Resolve('TcpServerAdapter')
                    if (-not $conn.Variables) {
                        $conn.Variables = @{}
                    }
                    $conn.Variables['_Adapter'] = $adapter
                    $adapter.Start($ConnectionId)
                }
            }
            "UDP" {
                $adapter = $Global:ServiceContainer.Resolve('UdpAdapter')
                if (-not $conn.Variables) {
                    $conn.Variables = @{}
                }
                $conn.Variables['_Adapter'] = $adapter
                $adapter.Start($ConnectionId)
            }
            default {
                throw "Unsupported protocol: $($conn.Protocol)"
            }
        }
        
        $conn.UpdateStatus("CONNECTED")
        $conn.MarkActivity()
        
        $periodicProfilePath = $null
        if ($conn.Variables.ContainsKey('PeriodicSendProfilePath')) {
            $periodicProfilePath = $conn.Variables['PeriodicSendProfilePath']
        }
        
        if ($periodicProfilePath -and (Test-Path -LiteralPath $periodicProfilePath)) {
            try {
                # 既存のPeriodicSendタイマーが起動していないか確認
                $hasActiveTimers = $conn.PeriodicTimers -and $conn.PeriodicTimers.Count -gt 0
                
                if (-not $hasActiveTimers) {
                    $instancePath = if ($conn.Variables -and $conn.Variables.ContainsKey('InstancePath')) {
                        $conn.Variables['InstancePath']
                    } else {
                        $null
                    }
                    
                    if ($instancePath) {
                        Start-PeriodicSend -ConnectionId $ConnectionId -RuleFilePath $periodicProfilePath -InstancePath $instancePath
                        Write-DebugLog "[ConnectionManager] Started periodic send on connection" "Green"
                    }
                } else {
                    Write-DebugLog "[ConnectionManager] Periodic send already active, skipping startup" "Yellow"
                }
            } catch {
                Write-Warning "[ConnectionManager] Failed to start periodic send: $_"
            }
        }
        
        Write-DebugLog "[ConnectionManager] Connection established: $($conn.DisplayName)" "Green"
        
    } catch {
        $conn.SetError($_.Exception.Message, $_.Exception)
        Write-Error "[ConnectionManager] Failed to start connection $($conn.DisplayName): $_"
    }
}

function Stop-Connection {
    <#
    .SYNOPSIS
    �ڑ����~
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,
        
        [switch]$Force
    )
    
    $conn = Get-ManagedConnection -ConnectionId $ConnectionId
    
    Write-DebugLog "[ConnectionManager] Stopping connection: $($conn.DisplayName)" "Yellow"
    
    try {
        try {
            Stop-PeriodicSend -ConnectionId $ConnectionId
        } catch {
            Write-Verbose "[ConnectionManager] Failed to stop periodic send: $_"
        }
        
        if ($conn.ScenarioTimers -and $conn.ScenarioTimers.Count -gt 0) {
            foreach ($timerState in @($conn.ScenarioTimers.Values)) {
                try {
                    if ($timerState -and $timerState.Timer) {
                        [void]$timerState.Timer.Change([System.Threading.Timeout]::Infinite, [System.Threading.Timeout]::Infinite)
                        $timerState.Timer.Dispose()
                    }
                } catch {
                    Write-Verbose "[ConnectionManager] Failed to dispose timer '$($timerState.Id)': $_"
                }
                
                try {
                    if ($timerState -and $timerState.CancellationSource) {
                        $timerState.CancellationSource.Cancel()
                        $timerState.CancellationSource.Dispose()
                    }
                } catch {
                    Write-Verbose "[ConnectionManager] Failed to cancel timer '$($timerState.Id)': $_"
                }
            }
            $conn.ScenarioTimers.Clear()
        }
        
        # CancellationSource���L�����Z���������ď�����
        if ($conn.CancellationSource) {
            try {
                $conn.CancellationSource.Cancel()
                Start-Sleep -Milliseconds 50  # �L�����Z�����`�������܂Ői�҂�
                $conn.CancellationSource.Dispose()
            } catch {
                Write-Verbose "[ConnectionManager] Failed to cancel/dispose CancellationSource: $_"
            }
            $conn.CancellationSource = $null
        }
        
        if ($conn.State.CancellationSource) {
            $conn.State.CancellationSource = $null
        }
        
        if ($conn.Socket) {
            try {
                if ($conn.Socket -is [System.Net.Sockets.TcpClient]) {
                    $conn.Socket.Close()
                } elseif ($conn.Socket -is [System.Net.Sockets.TcpListener]) {
                    $conn.Socket.Stop()
                } elseif ($conn.Socket -is [System.Net.Sockets.UdpClient]) {
                    $conn.Socket.Close()
                }
                $conn.Socket.Dispose()
            }
            catch {
                Write-Verbose "[ConnectionManager] Failed to close/dispose socket: $_"
            }
            finally {
                $conn.ClearSocket()
            }
        }
        
        if ($conn.Thread -and $conn.Thread.IsAlive) {
            if (-not $Force) {
                $conn.Thread.Join(5000)
            }
            if ($conn.Thread.IsAlive) {
                Write-Warning "Thread still alive, forcing abort"
                $conn.Thread.Abort()
            }
        }
        
        # �A�_�v�^�[�Q�Ƃ���������
        if ($conn.Variables -and $conn.Variables.ContainsKey('_Adapter')) {
            $conn.Variables.Remove('_Adapter')
        }
        
        $conn.UpdateStatus("DISCONNECTED")
        $conn.Thread = $null
        
        Write-DebugLog "[ConnectionManager] Connection stopped: $($conn.DisplayName)" "Green"
        
    } catch {
        Write-Error "[ConnectionManager] Error stopping connection: $_"
    }
}

function Get-ConnectionsByGroup {
    <#
    .SYNOPSIS
    �O���[�v���Őڑ��𒊏o
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$GroupName
    )
    
    $service = Get-ConnectionService
    return $service.GetConnectionsByGroup($GroupName)
}

function Get-ConnectionsByTag {
    <#
    .SYNOPSIS
    �^�O�Őڑ��𒊏o
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Tag
    )
    
    $service = Get-ConnectionService
    return $service.GetConnectionsByTag($Tag)
}

function Get-AllConnections {
    <#
    .SYNOPSIS
    �S�ڑ����擾
    #>
    $service = Get-ConnectionService
    return $service.GetAllConnections()
}

function Send-Data {
    <#
    .SYNOPSIS
    �f�[�^���M
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,
        
        [Parameter(Mandatory=$true)]
        [byte[]]$Data
    )
    
    $conn = Get-ManagedConnection -ConnectionId $ConnectionId
    
    if ($conn.Status -ne "CONNECTED") {
        throw "Connection not connected: $($conn.DisplayName)"
    }
    
    [void]$conn.SendQueue.Add($Data)
    Write-Verbose "[ConnectionManager] Data queued for $($conn.DisplayName): $($Data.Length) bytes"
}

# =====================================================================
# Periodic Send Functions (定周期送信)
# =====================================================================

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
        Write-Warning "[PeriodicSend] Rule file not found: $FilePath"
        return @()
    }

    try {
        # UTF-8で読み込み
        $content = Get-Content -Path $FilePath -Encoding UTF8 -Raw
        $rules = $content | ConvertFrom-Csv

        $validRules = @()
        foreach ($rule in $rules) {
            # 必須フィールドチェック
            if ([string]::IsNullOrWhiteSpace($rule.MessageFile)) {
                Write-Warning "[PeriodicSend] Skipping rule with empty MessageFile"
                continue
            }

            if ([string]::IsNullOrWhiteSpace($rule.IntervalMs)) {
                Write-Warning "[PeriodicSend] Skipping rule '$($rule.RuleName)' with empty IntervalMs"
                continue
            }

            # IntervalMs を数値に変換
            $intervalMs = 0
            if (-not [int]::TryParse($rule.IntervalMs, [ref]$intervalMs) -or $intervalMs -le 0) {
                Write-Warning "[PeriodicSend] Invalid IntervalMs for rule '$($rule.RuleName)': $($rule.IntervalMs)"
                continue
            }

            # MessageFile の絶対パスを解決
            $templatesPath = Join-Path $InstancePath "templates"
            $messageFilePath = Join-Path $templatesPath $rule.MessageFile

            if (-not (Test-Path -LiteralPath $messageFilePath)) {
                Write-Warning "[PeriodicSend] MessageFile not found: $messageFilePath"
                continue
            }

            $validRules += [PSCustomObject]@{
                RuleName = if ($rule.RuleName) { $rule.RuleName } else { "Rule-$($validRules.Count + 1)" }
                MessageFile = $messageFilePath
                IntervalMs = $intervalMs
            }
        }

        Write-DebugLog "[PeriodicSend] Loaded $($validRules.Count) periodic send rules from $FilePath" "Green"
        return $validRules

    } catch {
        Write-Error "[PeriodicSend] Failed to read periodic send rules: $_"
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

    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        Write-Warning "[PeriodicSend] Connection not found: $ConnectionId"
        return
    }

    $connection = $Global:Connections[$ConnectionId]

    # 既存のタイマーを停止
    Stop-PeriodicSend -ConnectionId $ConnectionId

    # ルールを読み込み
    $rules = Read-PeriodicSendRules -FilePath $RuleFilePath -InstancePath $InstancePath
    
    if ($rules.Count -eq 0) {
        Write-DebugLog "[PeriodicSend] No valid periodic send rules found" "Yellow"
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

        # 関数のスクリプトブロックを取得（イベントスコープで使用可能にする）
        $getTemplateFunc = ${function:Get-MessageTemplateCache}
        $convertBytesFunc = ${function:ConvertTo-ByteArray}
        $sendDataFunc = ${function:Send-Data}

        # タイマーイベント設定
        $timerEvent = Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
            param($sender, $eventArgs)

            $connId = $Event.MessageData.ConnectionId
            $messageFile = $Event.MessageData.MessageFile
            $ruleName = $Event.MessageData.RuleName
            $getTemplate = $Event.MessageData.GetTemplateFunc
            $convertBytes = $Event.MessageData.ConvertBytesFunc
            $sendData = $Event.MessageData.SendDataFunc

            if (-not $Global:Connections.ContainsKey($connId)) {
                return
            }

            $conn = $Global:Connections[$connId]

            # 接続が切断されている場合はスキップ
            if ($conn.Status -ne "CONNECTED") {
                return
            }

            try {
                # スクリプトブロックとして関数を呼び出し
                $templates = & $getTemplate -FilePath $messageFile -ThrowOnMissing
                if (-not $templates -or -not $templates.ContainsKey('DEFAULT')) {
                    Write-Warning "[PeriodicSend] DEFAULT template not found in: $messageFile"
                    return
                }

                $template = $templates['DEFAULT']
                if (-not $template -or -not $template.Format) {
                    Write-Warning "[PeriodicSend] Template format is empty: $messageFile"
                    return
                }

                $bytes = & $convertBytes -Data $template.Format -Encoding 'HEX'
                & $sendData -ConnectionId $connId -Data $bytes
            } catch {
                Write-Warning "[PeriodicSend] Failed to send periodic message for rule '$ruleName': $_"
            }
        } -MessageData @{
            ConnectionId = $ConnectionId
            MessageFile = $rule.MessageFile
            RuleName = $rule.RuleName
            GetTemplateFunc = $getTemplateFunc
            ConvertBytesFunc = $convertBytesFunc
            SendDataFunc = $sendDataFunc
        }

        # タイマーを保存
        $timerState = [PSCustomObject]@{
            Timer = $timer
            Event = $timerEvent
            RuleName = $rule.RuleName
        }
        [void]$connection.PeriodicTimers.Add($timerState)

        # タイマー開始
        $timer.Start()
        Write-DebugLog "[PeriodicSend] Started periodic timer for rule '$($rule.RuleName)' (Interval: $($rule.IntervalMs)ms)" "Green"
    }
}

function Stop-PeriodicSend {
    <#
    .SYNOPSIS
    定周期送信を停止
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )

    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        return
    }

    $connection = $Global:Connections[$ConnectionId]

    if (-not $connection.PeriodicTimers -or $connection.PeriodicTimers.Count -eq 0) {
        return
    }

    
    Write-DebugLog "[PeriodicSend] Stopping periodic timers for connection: $($connection.DisplayName)" "Yellow"
    
    foreach ($timerState in @($connection.PeriodicTimers)) {
        # タイマーを停止・破棄
        try {
            if ($timerState.Timer) {
                $timerState.Timer.Stop()
                $timerState.Timer.Dispose()
            }
        } catch {
            Write-Verbose "[PeriodicSend] Failed to dispose timer: $_"
        }

        # イベントをアンレジスター
        try {
            if ($timerState.Event) {
                $eventName = $timerState.Event.Name
                $eventId = $timerState.Event.Id
                
                Unregister-Event -SourceIdentifier $eventName -Force -ErrorAction SilentlyContinue
                
                $job = Get-Job -Id $eventId -ErrorAction SilentlyContinue
                if ($job) {
                    Stop-Job -Id $eventId -ErrorAction SilentlyContinue
                    Remove-Job -Id $eventId -Force -ErrorAction SilentlyContinue
                }
            }
        } catch {
            Write-Verbose "[PeriodicSend] Failed to unregister event: $_"
        }
    }

    $connection.PeriodicTimers.Clear()
    Write-DebugLog "[PeriodicSend] All periodic timers stopped" "Green"
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

    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        throw "Connection not found: $ConnectionId"
    }

    $conn = $Global:Connections[$ConnectionId]

    # 現在のプロファイルパスを取得
    $currentProfilePath = $null
    if ($conn.Variables.ContainsKey('PeriodicSendProfilePath')) {
        $currentProfilePath = $conn.Variables['PeriodicSendProfilePath']
    }

    # プロファイルをクリアする場合
    if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
        if ($currentProfilePath) {
            # 既存のPeriodicSendを停止
            Stop-PeriodicSend -ConnectionId $ConnectionId
            $conn.Variables.Remove('PeriodicSendProfile')
            $conn.Variables.Remove('PeriodicSendProfilePath')
            Write-DebugLog "[PeriodicSend] Cleared periodic send profile for $($conn.DisplayName)" "Yellow"
        }
        return
    }

    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        throw "Periodic send profile not found: $ProfilePath"
    }

    $resolved = (Resolve-Path -LiteralPath $ProfilePath).Path
    $profileName = [System.IO.Path]::GetFileNameWithoutExtension($ProfilePath)
    
    # 同じプロファイルが既に設定されている場合はスキップ
    if ($currentProfilePath -eq $resolved) {
        Write-DebugLog "[PeriodicSend] Profile '$profileName' is already active, skipping" "Cyan"
        return
    }

    # 既存のPeriodicSendを停止（異なるプロファイルに切り替える場合）
    if ($currentProfilePath) {
        Stop-PeriodicSend -ConnectionId $ConnectionId
    }

    $conn.Variables['PeriodicSendProfile'] = $profileName
    $conn.Variables['PeriodicSendProfilePath'] = $resolved

    
    Write-DebugLog "[PeriodicSend] Profile '$profileName' applied to $($conn.DisplayName)" "Green"    # 接続が既にアクティブな場合は即座に開始
    if ($conn.Status -eq "CONNECTED") {
        Start-PeriodicSend -ConnectionId $ConnectionId -RuleFilePath $resolved -InstancePath $InstancePath
    }
}

# =====================================================================
# OnReceived Profile Functions (受信イベントプロファイル)
# =====================================================================

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

    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        throw "Connection not found: $ConnectionId"
    }

    $conn = $Global:Connections[$ConnectionId]

    if ([string]::IsNullOrWhiteSpace($ProfileName) -or -not $ProfilePath) {
        $conn.Variables.Remove('OnReceivedProfile')
        $conn.Variables.Remove('OnReceivedProfilePath')
        $conn.Variables.Remove('OnReceivedRulesCache')
        Write-Host "[OnReceived] Cleared OnReceived profile for $($conn.DisplayName)" -ForegroundColor Yellow
        return @()
    }

    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        throw "OnReceived profile not found: $ProfilePath"
    }

    $resolved = (Resolve-Path -LiteralPath $ProfilePath).Path
    $conn.Variables['OnReceivedProfile'] = $ProfileName
    $conn.Variables['OnReceivedProfilePath'] = $resolved
    $conn.Variables.Remove('OnReceivedRulesCache')

    Write-Host "[OnReceived] Profile '$ProfileName' applied to $($conn.DisplayName)" -ForegroundColor Green

    # RuleRepositoryを通じてルールをキャッシュ
    if ($Global:RuleRepository) {
        try {
            $rules = $Global:RuleRepository.GetRules($resolved)
            return $rules
        } catch {
            Write-Warning "[OnReceived] Failed to load rules: $_"
            return @()
        }
    }

    return @()
}

function Set-ConnectionAutoResponseProfile {
    <#
    .SYNOPSIS
    コネクションにAutoResponseプロファイルを設定
    #>
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

    # RuleRepositoryを通じてルールをキャッシュ
    if ($Global:RuleRepository) {
        try {
            $rules = $Global:RuleRepository.GetRules($resolved)
            return $rules
        } catch {
            Write-Warning "[AutoResponse] Failed to load rules: $_"
            return @()
        }
    }

    return @()
}


