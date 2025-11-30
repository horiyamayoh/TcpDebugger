# MainForm.ps1
# WinForms main window definition

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-UiConnectionService {
    # ServiceContainer経由でサービスを取得（推奨）
    if ($Global:ServiceContainer) {
        try {
            return $Global:ServiceContainer.Resolve('ConnectionService')
        }
        catch {
            # ServiceContainerが初期化されていない場合はフォールバック
        }
    }
    
    # 後方互換性のためのフォールバック
    if ($Global:ConnectionService) {
        return $Global:ConnectionService
    }
    if (Get-Command Get-ConnectionService -ErrorAction SilentlyContinue) {
        return Get-ConnectionService
    }
    throw "ConnectionService is not available."
}

function Get-UiProfileService {
    # ServiceContainer経由でサービスを取得（推奨）
    if ($Global:ServiceContainer) {
        try {
            return $Global:ServiceContainer.Resolve('ProfileService')
        }
        catch {
            # ServiceContainerが初期化されていない場合はフォールバック
        }
    }
    
    # 後方互換性のためのフォールバック
    if ($Global:ProfileService) {
        return $Global:ProfileService
    }
    return $null
}

function Get-UiMessageProcessor {
    # ServiceContainer経由でサービスを取得（推奨）
    if ($Global:ServiceContainer) {
        try {
            return $Global:ServiceContainer.Resolve('MessageProcessor')
        }
        catch {
            # ServiceContainerが初期化されていない場合はフォールバック
        }
    }
    
    # 後方互換性のためのフォールバック
    if ($Global:MessageProcessor) {
        return $Global:MessageProcessor
    }
    return $null
}

function Get-UiLogger {
    # ServiceContainer経由でサービスを取得（推奨）
    if ($Global:ServiceContainer) {
        try {
            return $Global:ServiceContainer.Resolve('Logger')
        }
        catch {
            # ServiceContainerが初期化されていない場合はフォールバック
        }
    }
    
    # 後方互換性のためのフォールバック
    if ($Global:Logger) {
        return $Global:Logger
    }
    return $null
}

function Get-UiConnection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConnectionId
    )
    if ([string]::IsNullOrWhiteSpace($ConnectionId)) {
        return $null
    }
    $service = Get-UiConnectionService
    return $service.GetConnection($ConnectionId)
}

function Get-UiConnections {
    $service = Get-UiConnectionService
    return $service.GetAllConnections()
}

function Show-MainForm {
    <#
    .SYNOPSIS
    Show the main WinForms UI.
    #>

    # Create main form using ViewBuilder
    $form = New-MainFormWindow -Title "Socket Debugger Simple v1.0" -Width 1700 -Height 800
    $script:CurrentMainForm = $form

    # ツールバーパネルを作成（統一カラーパレット使用）
    $toolbarPanel = New-Object System.Windows.Forms.Panel
    $toolbarPanel.Location = New-Object System.Drawing.Point(0, 0)
    $toolbarPanel.Size = New-Object System.Drawing.Size(1700, 50)
    $toolbarPanel.BackColor = [System.Drawing.Color]::FromArgb(241, 245, 249)  # slate-100
    $toolbarPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $toolbarPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor 
                           [System.Windows.Forms.AnchorStyles]::Left -bor 
                           [System.Windows.Forms.AnchorStyles]::Right
    $form.Controls.Add($toolbarPanel)

    # Toolbar buttons using ViewBuilder
    $btnConnect = New-ToolbarButton -Text "▶ Connect" -X 12 -Y 10 -Width 115 -ToolTip "すべての接続を開始します"
    $toolbarPanel.Controls.Add($btnConnect)

    $btnDisconnect = New-ToolbarButton -Text "⏹ Disconnect" -X 135 -Y 10 -Width 115 -ToolTip "すべての接続を切断します"
    $toolbarPanel.Controls.Add($btnDisconnect)

    # Global profile combo box (アプリケーションプロファイル用)
    $lblGlobalProfile = New-Object System.Windows.Forms.Label
    $lblGlobalProfile.Text = "App Profile:"
    $lblGlobalProfile.Location = New-Object System.Drawing.Point(268, 15)
    $lblGlobalProfile.Size = New-Object System.Drawing.Size(80, 20)
    $lblGlobalProfile.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $lblGlobalProfile.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblGlobalProfile.ForeColor = [System.Drawing.Color]::FromArgb(71, 85, 105)  # slate-500
    $toolbarPanel.Controls.Add($lblGlobalProfile)

    $script:cmbGlobalProfile = New-StyledComboBox -X 355 -Y 11 -Width 200 -ToolTip "アプリケーション全体に適用するプロファイルを選択"
    $toolbarPanel.Controls.Add($script:cmbGlobalProfile)

    # ステータスラベルを追加
    $script:StatusLabel = New-StatusLabel -X 570 -Y 15 -Width 600 -InitialText "Ready"
    $script:StatusLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor 
                        [System.Windows.Forms.AnchorStyles]::Left -bor 
                        [System.Windows.Forms.AnchorStyles]::Right
    $toolbarPanel.Controls.Add($script:StatusLabel)

    # DataGridView (connection list) using ViewBuilder
    # 画面いっぱいに表示（ツールバー分を考慮）
    $dgvInstances = New-ConnectionDataGridView -X 10 -Y 60 -Width 1660 -Height 690
    $form.Controls.Add($dgvInstances)
    
    # アプリケーションプロファイルコンボボックスの初期化
    function Initialize-ProfileComboBoxes {
        $script:cmbGlobalProfile.Items.Clear()
        $script:cmbGlobalProfile.Items.Add("(None)") | Out-Null

        $profileService = Get-UiProfileService
        if ($profileService) {
            $profiles = $profileService.GetAvailableApplicationProfiles() | Sort-Object
            foreach ($profileName in $profiles) {
                if (-not [string]::IsNullOrWhiteSpace($profileName)) {
                    $script:cmbGlobalProfile.Items.Add($profileName) | Out-Null
                }
            }
        }

        if ($script:cmbGlobalProfile.Items.Count -gt 0) {
            $script:cmbGlobalProfile.SelectedIndex = 0
        }
    }
    
    # アプリケーションプロファイル選択イベント
    $script:cmbGlobalProfile.Add_SelectedIndexChanged({
        $selectedProfile = $script:cmbGlobalProfile.SelectedItem
        if (-not $selectedProfile) {
            return
        }

        if ($selectedProfile -eq "(None)") {
            # 全てのプロファイルをクリア
            Write-Console "[UI] Clearing all profiles (None selected)" -ForegroundColor Cyan
            Clear-AllProfiles -DataGridView $dgvInstances
            return
        }

        Write-Console "[UI] Applying application profile: $selectedProfile" -ForegroundColor Cyan
        Apply-ApplicationProfile -DataGridView $dgvInstances -ProfileName $selectedProfile
    })

    # State holders
    $script:suppressScenarioEvent = $false
    $script:suppressOnReceiveScriptEvent = $false
    $script:suppressOnTimerSendEvent = $false
    $script:suppressProfileEvent = $false
    $script:isGlobalProfileLocked = $false
    $script:comboSelectedIndexChangedHandler = $null
    $script:isUpdatingGrid = $false
    $script:gridState = @{
        EditingInProgress = $false
        PendingComboDropDown = $null
    }
    $script:dgvInstances = $dgvInstances

    # Register event handlers
    Register-GridEvents -DataGridView $dgvInstances -GridState $script:gridState
    Register-ButtonEvents -DataGridView $dgvInstances -BtnConnect $btnConnect -BtnDisconnect $btnDisconnect

    # メッセージ処理タイマー (100ms間隔でRunspaceからのメッセージを処理)
    $messageTimer = New-Object System.Windows.Forms.Timer
    $messageTimer.Interval = 100
    $messageTimer.Add_Tick({
        try {
            $processor = Get-UiMessageProcessor
            if ($processor) {
                $processed = $processor.ProcessMessages(50)
                
                # 状態変更があった場合は即座に UI を更新
                if ($processor.CheckAndResetStatusChanged()) {
                    if (-not $script:gridState.EditingInProgress -and -not $script:dgvInstances.IsCurrentCellInEditMode) {
                        Update-InstanceList -DataGridView $script:dgvInstances
                        
                        # ステータス表示を更新
                        if ($script:StatusLabel) {
                            $connections = Get-UiConnections
                            $connectedCount = ($connections | Where-Object { $_.Status -eq 'CONNECTED' }).Count
                            $totalCount = $connections.Count
                            $script:StatusLabel.Text = "接続状態: $connectedCount / $totalCount Connected | 最終更新: $(Get-Date -Format 'HH:mm:ss')"
                        }
                    }
                }
            }
        }
        catch {
            # エラーは通常のロガーに任せる
        }
    })
    $messageTimer.Start()

    # Form closing cleanup
    $form.Add_FormClosing({
        $messageTimer.Stop()
        
        # Loggerバッファをフラッシュ
        $logger = Get-UiLogger
        if ($logger) {
            try {
                $logger.Flush()
            }
            catch {
                # ignore errors
            }
        }
        
        foreach ($conn in Get-UiConnections) {
            try {
                Stop-Connection -ConnectionId $conn.Id -Force
            } catch {
                # ignore errors
            }
        }
    })

    $form.Add_FormClosed({
        param($sender, $eventArgs)
        if ($script:CurrentMainForm -eq $sender) {
            $script:CurrentMainForm = $null
        }
    })

    # プロファイルコンボボックスを初期化
    try {
        Initialize-ProfileComboBoxes
    }
    catch {
        Write-Console "[Warning] Failed to initialize profile combo boxes: $_" -ForegroundColor Yellow
    }

    # Initial load (after profiles are available)
    Update-InstanceList -DataGridView $dgvInstances

    # Show form
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()

    if ($script:CurrentMainForm -eq $form) {
        $script:CurrentMainForm = $null
    }
}

function Register-GridEvents {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView,
        [hashtable]$GridState
    )

    $DataGridView.Add_CellBeginEdit({
        $GridState.EditingInProgress = $true
    })

    $DataGridView.Add_CellEndEdit({
        $GridState.EditingInProgress = $false
    })

    $DataGridView.Add_Leave({
        $GridState.EditingInProgress = $false
    })

    $DataGridView.Add_CurrentCellDirtyStateChanged({
        if ($DataGridView.IsCurrentCellDirty -and $DataGridView.CurrentCell -and
            $DataGridView.CurrentCell.OwningColumn -and
            $DataGridView.CurrentCell.OwningColumn.Name -in @("Scenario", "OnReceiveScript", "OnTimerSend", "Profile")) {
            $DataGridView.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
        }
    })

    $DataGridView.Add_CellValueChanged({
        param($sender, $args)
        if ($args.ColumnIndex -lt 0 -or $args.RowIndex -lt 0) {
            return
        }
        $column = $sender.Columns[$args.ColumnIndex]
        
        if ($column.Name -eq "Scenario") {
            Handle-ScenarioChanged -Sender $sender -Args $args
        }
        elseif ($column.Name -eq "OnTimerSend") {
            Handle-OnTimerSendChanged -Sender $sender -Args $args
        }
        elseif ($column.Name -eq "OnReceiveScript") {
            Handle-OnReceiveScriptChanged -Sender $sender -Args $args
        }
        elseif ($column.Name -eq "Profile") {
            Handle-ProfileChanged -Sender $sender -Args $args
        }
    })

    # CellContentClick removed in favor of CellClick for better button responsiveness
    # $DataGridView.Add_CellContentClick({ ... })

    $DataGridView.Add_CellClick({
        param($sender, $e)
        Handle-CellClick -Sender $sender -EventArgs $e -GridState $GridState
    })

    $DataGridView.Add_EditingControlShowing({
        param($sender, $eventArgs)
        Handle-EditingControlShowing -Sender $sender -EventArgs $eventArgs -GridState $GridState
    })

    $DataGridView.Add_DataError({
        param($sender, $eventArgs)

        if ($eventArgs) {
            $eventArgs.ThrowException = $false
            $eventArgs.Cancel = $true
        }

        $context = if ($eventArgs) { $eventArgs.Context } else { "Unknown" }
        Write-Verbose ("[UI] DataGridView error suppressed: {0}" -f $context)
    })
}

function Register-ButtonEvents {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView,
        [System.Windows.Forms.Button]$BtnConnect,
        [System.Windows.Forms.Button]$BtnDisconnect
    )

    $BtnConnect.Add_Click({
        # 上部ボタンは常に全インスタンスを一括接続
        $connections = Get-UiConnections
        
        # 接続が必要なインスタンスのみをフィルタ（DISCONNECTED または ERROR のみ対象）
        $connectableConnections = $connections | Where-Object { 
            $_.Status -eq 'DISCONNECTED' -or $_.Status -eq 'ERROR' 
        }
        
        # 全て接続済みなら何もしない
        if (-not $connectableConnections -or $connectableConnections.Count -eq 0) {
            return
        }
        
        $successCount = 0
        $failCount = 0
        
        foreach ($conn in $connectableConnections) {
            try {
                Start-Connection -ConnectionId $conn.Id
                $successCount++
                Write-Console "[UI] Connection started: $($conn.DisplayName)" -ForegroundColor Green
            } catch {
                $failCount++
                Write-Console "[UI] Failed to start connection $($conn.DisplayName): $_" -ForegroundColor Red
            }
        }
        
        Update-InstanceList -DataGridView $DataGridView
    })

    $BtnDisconnect.Add_Click({
        # 上部ボタンは常に全インスタンスを一括切断
        $connections = Get-UiConnections
        
        # 切断が必要なインスタンスのみをフィルタ（DISCONNECTED と ERROR 以外）
        $disconnectableConnections = $connections | Where-Object { 
            $_.Status -ne 'DISCONNECTED' -and $_.Status -ne 'ERROR' 
        }
        
        # 全て切断済みなら何もしない
        if (-not $disconnectableConnections -or $disconnectableConnections.Count -eq 0) {
            return
        }
        
        $successCount = 0
        $failCount = 0
        
        foreach ($conn in $disconnectableConnections) {
            try {
                Stop-Connection -ConnectionId $conn.Id
                $successCount++
                Write-Console "[UI] Connection stopped: $($conn.DisplayName)" -ForegroundColor Yellow
            } catch {
                $failCount++
                Write-Console "[UI] Failed to stop connection $($conn.DisplayName): $_" -ForegroundColor Red
            }
        }
        
        Update-InstanceList -DataGridView $DataGridView
    })
}

function Handle-ScenarioChanged {
    param(
        $Sender,
        $Args
    )

    if ($script:suppressScenarioEvent) {
        return
    }
    if ($Args.ColumnIndex -lt 0 -or $Args.RowIndex -lt 0) {
        return
    }
    $column = $Sender.Columns[$Args.ColumnIndex]
    if ($column.Name -ne "Scenario") {
        return
    }

    $row = $Sender.Rows[$Args.RowIndex]
    if (-not $row.Cells.Contains("Id")) {
        return
    }

    $connId = $row.Cells["Id"].Value
    if (-not $connId) {
        return
    }

    $cell = $row.Cells["Scenario"]
    $tagData = $cell.Tag
    $mapping = $null
    $currentProfileKey = ""

    if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("Mapping") -and $tagData.ContainsKey("ProfileKey")) {
        $mapping = $tagData["Mapping"]
        $currentProfileKey = $tagData["ProfileKey"]
    }

    $selectedKey = if ($cell.Value) { [string]$cell.Value } else { "" }
    $entry = $null
    if ($mapping -and $mapping.ContainsKey($selectedKey)) {
        $entry = $mapping[$selectedKey]
    }

    if ($entry -and $entry.Type -eq "Scenario") {
        Execute-Scenario -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentProfileKey -Sender $Sender
        return
    }

    Apply-OnReceiveReplyProfile -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentProfileKey -Sender $Sender
}

function Execute-Scenario {
    param(
        [string]$ConnectionId,
        $Entry,
        $Cell,
        [string]$CurrentKey,
        $Sender
    )

    $scenarioPath = $Entry.Path
    if (-not $scenarioPath -or -not (Test-Path -LiteralPath $scenarioPath)) {
        [System.Windows.Forms.MessageBox]::Show("Scenario file not found: $($Entry.Name)", "Warning") | Out-Null
    } else {
        try {
            Start-Scenario -ConnectionId $ConnectionId -ScenarioPath $scenarioPath
            [System.Windows.Forms.MessageBox]::Show("Scenario started: $($Entry.Name)", "Success") | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to start scenario: $_", "Error") | Out-Null
        }
    }

    if ($CurrentKey -ne $Cell.Value) {
        $script:suppressScenarioEvent = $true
        try {
            $Cell.Value = $CurrentKey
        } finally {
            $script:suppressScenarioEvent = $false
        }
        $Sender.InvalidateCell($Cell)
    }
}

function Apply-OnReceiveReplyProfile {
    param(
        [string]$ConnectionId,
        $Entry,
        $Cell,
        [string]$CurrentKey,
        $Sender
    )

    $profileName = $null
    $profilePath = $null
    if ($Entry -and $Entry.Type -eq "Profile") {
        $profileName = $Entry.Name
        $profilePath = $Entry.Path
    }

    try {
        Set-ConnectionOnReceiveReplyProfile -ConnectionId $ConnectionId -ProfileName $profileName -ProfilePath $profilePath | Out-Null
        $tagData = $Cell.Tag
        if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("ProfileKey")) {
            $tagData["ProfileKey"] = $Cell.Value
        }
    } catch {
        if ($CurrentKey -ne $Cell.Value) {
            $script:suppressScenarioEvent = $true
            try {
                $Cell.Value = $CurrentKey
            } finally {
                $script:suppressScenarioEvent = $false
            }
            $Sender.InvalidateCell($Cell)
        }
        [System.Windows.Forms.MessageBox]::Show("Failed to apply On Receive: Reply profile: $_", "Error") | Out-Null
    }
}

function Handle-OnTimerSendChanged {
    param(
        $Sender,
        $Args
    )

    if ($script:suppressOnTimerSendEvent) {
        return
    }
    if ($Args.ColumnIndex -lt 0 -or $Args.RowIndex -lt 0) {
        return
    }
    $column = $Sender.Columns[$Args.ColumnIndex]
    if ($column.Name -ne "OnTimerSend") {
        return
    }

    $row = $Sender.Rows[$Args.RowIndex]
    if (-not $row.Cells.Contains("Id")) {
        return
    }

    $connId = $row.Cells["Id"].Value
    if (-not $connId) {
        return
    }

    $cell = $row.Cells["OnTimerSend"]
    $tagData = $cell.Tag
    $mapping = $null
    $currentTimerSendKey = ""

    if ($tagData -is [System.Collections.IDictionary]) {
        if ($tagData.ContainsKey("Mapping")) {
            $mapping = $tagData["Mapping"]
        }
        if ($tagData.ContainsKey("OnTimerSendProfileKey")) {
            $currentTimerSendKey = $tagData["OnTimerSendProfileKey"]
        }
    }

    $selectedKey = if ($cell.Value) { [string]$cell.Value } else { "" }
    
    $entry = $null
    if ($mapping -and $mapping.ContainsKey($selectedKey)) {
        $entry = $mapping[$selectedKey]
    }

    Apply-OnTimerSendProfile -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentTimerSendKey -Sender $Sender
}

function Apply-OnTimerSendProfile {
    param(
        [string]$ConnectionId,
        $Entry,
        $Cell,
        [string]$CurrentKey,
        $Sender
    )

    $profileName = $null
    $profilePath = $null
    if ($Entry -and $Entry.Type -eq "Profile") {
        $profileName = $Entry.Name
        $profilePath = $Entry.Path
    }

    try {
        $connection = Get-ManagedConnection -ConnectionId $ConnectionId
        if (-not $connection) {
            throw "Connection not found: $ConnectionId"
        }

        # 新しいプロファイルを設定（Set-ConnectionOnTimerSendProfileが状態チェックを行う）
        # インスタンスパスを取得
        $instancePath = $null
        if ($connection.Variables.ContainsKey('InstancePath')) {
            $instancePath = $connection.Variables['InstancePath']
        }

        if ($profilePath -and (Test-Path -LiteralPath $profilePath)) {
            # Set-ConnectionOnTimerSendProfileを使用（接続状態をチェックし、CONNECTEDの場合のみタイマーを開始）
            Set-ConnectionOnTimerSendProfile -ConnectionId $ConnectionId -ProfilePath $profilePath -InstancePath $instancePath
            Write-Console "[OnTimerSend] Applied profile: $profileName" -ForegroundColor Green
        }
        else {
            # プロファイルをクリア
            Set-ConnectionOnTimerSendProfile -ConnectionId $ConnectionId -ProfilePath $null -InstancePath $instancePath
            Write-Console "[OnTimerSend] Cleared profile" -ForegroundColor Yellow
        }

        # Tagを更新
        $tagData = $Cell.Tag
        if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("OnTimerSendProfileKey")) {
            $tagData["OnTimerSendProfileKey"] = $Cell.Value
        }
    }
    catch {
        # エラー時は元の値に戻す
        if ($CurrentKey -ne $Cell.Value) {
            $script:suppressOnTimerSendEvent = $true
            try {
                $Cell.Value = $CurrentKey
            } finally {
                $script:suppressOnTimerSendEvent = $false
            }
            $Sender.InvalidateCell($Cell)
        }
        [System.Windows.Forms.MessageBox]::Show("Failed to apply On Timer: Send profile: $_", "Error") | Out-Null
    }
}

function Handle-OnReceiveScriptChanged {
    param(
        $Sender,
        $Args
    )

    if ($script:suppressOnReceiveScriptEvent) {
        return
    }
    if ($Args.ColumnIndex -lt 0 -or $Args.RowIndex -lt 0) {
        return
    }
    $column = $Sender.Columns[$Args.ColumnIndex]
    if ($column.Name -ne "OnReceiveScript") {
        return
    }

    $row = $Sender.Rows[$Args.RowIndex]
    if (-not $row.Cells.Contains("Id")) {
        return
    }

    $connId = $row.Cells["Id"].Value
    if (-not $connId) {
        return
    }

    $cell = $row.Cells["OnReceiveScript"]
    $tagData = $cell.Tag
    $mapping = $null
    $currentProfileKey = ""

    if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("Mapping") -and $tagData.ContainsKey("OnReceiveScriptProfileKey")) {
        $mapping = $tagData["Mapping"]
        $currentProfileKey = $tagData["OnReceiveScriptProfileKey"]
    }

    $selectedKey = if ($cell.Value) { [string]$cell.Value } else { "" }
    $entry = $null
    if ($mapping -and $mapping.ContainsKey($selectedKey)) {
        $entry = $mapping[$selectedKey]
    }

    Apply-OnReceiveScriptProfile -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentProfileKey -Sender $Sender
}

function Apply-OnReceiveScriptProfile {
    param(
        [string]$ConnectionId,
        $Entry,
        $Cell,
        [string]$CurrentKey,
        $Sender
    )

    $profileName = $null
    $profilePath = $null
    if ($Entry -and $Entry.Type -eq "Profile") {
        $profileName = $Entry.Name
        $profilePath = $Entry.Path
    }

    try {
        Set-ConnectionOnReceiveScriptProfile -ConnectionId $ConnectionId -ProfileName $profileName -ProfilePath $profilePath | Out-Null
        $tagData = $Cell.Tag
        if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("OnReceiveScriptProfileKey")) {
            $tagData["OnReceiveScriptProfileKey"] = $Cell.Value
        }
    } catch {
        if ($CurrentKey -ne $Cell.Value) {
            $script:suppressOnReceiveScriptEvent = $true
            try {
                $Cell.Value = $CurrentKey
            } finally {
                $script:suppressOnReceiveScriptEvent = $false
            }
            $Sender.InvalidateCell($Cell)
        }
        [System.Windows.Forms.MessageBox]::Show("Failed to apply OnReceiveScript profile: $_", "Error") | Out-Null
    }
}

function Handle-ProfileChanged {
    param(
        $Sender,
        $Args
    )

    if ($script:suppressProfileEvent) {
        return
    }
    if ($Args.ColumnIndex -lt 0 -or $Args.RowIndex -lt 0) {
        return
    }

    $column = $Sender.Columns[$Args.ColumnIndex]
    if ($column.Name -ne "Profile") {
        return
    }

    $row = $Sender.Rows[$Args.RowIndex]
    if (-not $row.Cells.Contains("Id")) {
        return
    }

    $profileValue = [string]$row.Cells["Profile"].Value
    Apply-ProfileToConnectionRow -DataGridView $Sender -Row $row -ProfileName $profileValue
}

function Apply-ProfileToConnectionRow {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.DataGridView]$DataGridView,
        [Parameter(Mandatory=$true)][System.Windows.Forms.DataGridViewRow]$Row,
        [string]$ProfileName
    )

    $connId = $Row.Cells["Id"].Value
    if (-not $connId) {
        return
    }

    $connection = $null
    try {
        $connection = Get-UiConnection -ConnectionId $connId
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Connection not found: $connId", "Error") | Out-Null
        return
    }

    $profileService = Get-UiProfileService
    if (-not $profileService) {
        return
    }

    # インスタンス名とパスを取得
    $instanceName = ""
    if ($connection.Variables -and $connection.Variables.ContainsKey('InstanceName')) {
        $instanceName = $connection.Variables['InstanceName']
    }

    $instancePath = Get-InstancePathFromConnection -Connection $connection

    if ([string]::IsNullOrWhiteSpace($instanceName) -or [string]::IsNullOrWhiteSpace($instancePath)) {
        return
    }

    try {
        # ProfileNameが空の場合(NONEを選択した場合)は、すべてのプロファイルをクリア
        if ([string]::IsNullOrWhiteSpace($ProfileName)) {
            # OnReceiveReplyプロファイルをクリア
            Set-ConnectionOnReceiveReplyProfile -ConnectionId $connId -ProfileName $null -ProfilePath $null | Out-Null
            
            # OnReceiveScriptプロファイルをクリア
            Set-ConnectionOnReceiveScriptProfile -ConnectionId $connId -ProfileName $null -ProfilePath $null | Out-Null
            
            # OnTimerSendプロファイルをクリア
            Set-ConnectionOnTimerSendProfile -ConnectionId $connId -ProfilePath $null -InstancePath $instancePath | Out-Null
            
            # InstanceProfile変数もクリア
            $connection.Variables.Remove('InstanceProfile')
        }
        else {
            # ProfileNameが指定されている場合は、プロファイルを適用
            $profileService.ApplyInstanceProfile($connId, $instanceName, $ProfileName, $instancePath)
        }

        $script:suppressProfileEvent = $true
        $script:suppressScenarioEvent = $true
        $script:suppressOnReceiveScriptEvent = $true
        $script:suppressOnTimerSendEvent = $true
        
        Update-InstanceList -DataGridView $DataGridView -PreserveComboStates:$false
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to apply profile '$ProfileName': $_", "Error") | Out-Null
    }
    finally {
        $script:suppressScenarioEvent = $false
        $script:suppressOnReceiveScriptEvent = $false
        $script:suppressOnTimerSendEvent = $false
        $script:suppressProfileEvent = $false
    }
}

function Get-InstancePathFromConnection {
    param(
        $Connection
    )

    if (-not $Connection) {
        return $null
    }

    if ($Connection.Variables -and $Connection.Variables.ContainsKey('InstancePath')) {
        return $Connection.Variables['InstancePath']
    }

    if ($Connection.InstanceName) {
        return Join-Path (Join-Path $script:RootPath "Instances") $Connection.InstanceName
    }

    return $null
}

function Apply-ApplicationProfile {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView,
        [string]$ProfileName
    )

    $profileService = Get-UiProfileService
    if (-not $profileService -or [string]::IsNullOrWhiteSpace($ProfileName)) {
        return
    }

    try {
        # アプリケーションプロファイルを適用（全インスタンスに一斉適用）
        $profileService.ApplyApplicationProfile($ProfileName)
        
        # UIを更新
        $script:suppressProfileEvent = $true
        $script:suppressScenarioEvent = $true
        $script:suppressOnReceiveScriptEvent = $true
        $script:suppressOnTimerSendEvent = $true
        try {
            Update-InstanceList -DataGridView $DataGridView -PreserveComboStates:$false
        }
        finally {
            $script:suppressScenarioEvent = $false
            $script:suppressOnReceiveScriptEvent = $false
            $script:suppressOnTimerSendEvent = $false
            $script:suppressProfileEvent = $false
        }
    }
    catch {
        Write-Warning "[UI] Failed to apply application profile: $_"
    }
}

function Clear-AllProfiles {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView
    )

    try {
        Write-Verbose "[Clear-AllProfiles] Starting to clear all profiles"
        
        # ConnectionServiceを使用して全接続を取得
        $connections = Get-UiConnections
        $clearedCount = 0
        
        foreach ($conn in $connections) {
            try {
                $connId = $conn.Id
                $instancePath = if ($conn.Variables.ContainsKey('InstancePath')) { $conn.Variables['InstancePath'] } else { "" }
                
                Write-Verbose "[Clear-AllProfiles] Clearing profiles for: $connId"
                
                # OnReceiveReplyプロファイルをクリア
                Set-ConnectionOnReceiveReplyProfile -ConnectionId $connId -ProfileName $null -ProfilePath $null | Out-Null
                
                # OnReceiveScriptプロファイルをクリア
                Set-ConnectionOnReceiveScriptProfile -ConnectionId $connId -ProfileName $null -ProfilePath $null | Out-Null
                
                # OnTimerSendプロファイルをクリア（InstancePathが必要）
                if ($instancePath) {
                    Set-ConnectionOnTimerSendProfile -ConnectionId $connId -ProfilePath $null -InstancePath $instancePath | Out-Null
                }
                
                # InstanceProfile変数もクリア
                $conn.Variables.Remove('InstanceProfile')
                $clearedCount++
            }
            catch {
                Write-Warning "[UI] Failed to clear profiles for ${connId}: $_"
            }
        }
        
    Write-Console "[Clear-AllProfiles] Cleared profiles for $clearedCount connection(s)" -ForegroundColor Green
        
        # UIを更新
        $script:suppressProfileEvent = $true
        $script:suppressScenarioEvent = $true
        $script:suppressOnReceiveScriptEvent = $true
        $script:suppressOnTimerSendEvent = $true
        try {
            Update-InstanceList -DataGridView $DataGridView -PreserveComboStates:$false
        }
        finally {
            $script:suppressScenarioEvent = $false
            $script:suppressOnReceiveScriptEvent = $false
            $script:suppressOnTimerSendEvent = $false
            $script:suppressProfileEvent = $false
        }
    }
    catch {
        Write-Warning "[UI] Failed to clear all profiles: $_"
    }
}

function Set-ProfileColumnsReadOnly {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView,
        [bool]$IsLocked
    )

    if (-not $DataGridView) {
        return
    }

    foreach ($columnName in @("Profile", "Scenario", "OnReceiveScript", "OnTimerSend")) {
        if ($DataGridView.Columns.Contains($columnName)) {
            $DataGridView.Columns[$columnName].ReadOnly = $IsLocked
        }
    }
}

function Handle-CellContentClick {
    param(
        $Sender,
        $evt
    )

    if ($evt.RowIndex -lt 0 -or $evt.ColumnIndex -lt 0) {
        return
    }
    $column = $Sender.Columns[$evt.ColumnIndex]
    if (-not $column) {
        return
    }

    # ボタン列のみを処理
    if ($column -isnot [System.Windows.Forms.DataGridViewButtonColumn]) {
        return
    }

    $row = $Sender.Rows[$evt.RowIndex]
    
    # Check if Id column exists
    if (-not $Sender.Columns.Contains("Id")) {
        return
    }

    $cellId = $row.Cells["Id"]
    if (-not $cellId) {
        return
    }

    $connId = $cellId.Value
    if (-not $connId) {
        return
    }

    $connection = $null
    try {
        $connection = Get-ManagedConnection -ConnectionId $connId
    } catch {
        # connection might have been removed
    }

    switch ($column.Name) {
        "QuickSend" {
            Handle-QuickSendClick -Row $row -ConnectionId $connId -Connection $connection
        }
        "ActionSend" {
            Handle-ActionSendClick -Row $row -ConnectionId $connId -Connection $connection
        }
        "BtnConnect" {
            Write-Console "[UI] Row Connect button clicked for: $connId" -ForegroundColor Cyan
            Handle-RowConnectClick -ConnectionId $connId
            # 上部ボタンと同じように、即座にUI更新
            Update-InstanceList -DataGridView $Sender
        }
        "BtnDisconnect" {
            Write-Console "[UI] Row Disconnect button clicked for: $connId" -ForegroundColor Cyan
            Handle-RowDisconnectClick -ConnectionId $connId
            # 上部ボタンと同じように、即座にUI更新
            Update-InstanceList -DataGridView $Sender
        }
    }
}

function Send-ManualData {
    <#
    .SYNOPSIS
    Sends a template file to a connection.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,
        
        [Parameter(Mandatory=$true)]
        [string]$TemplateFilePath
    )
    
    if (-not (Test-Path -LiteralPath $TemplateFilePath)) {
        throw "Template file not found: $TemplateFilePath"
    }
    
    # Read template file and convert to byte array
    $templates = Get-MessageTemplateCache -FilePath $TemplateFilePath -ThrowOnMissing
    
    if (-not $templates.ContainsKey('DEFAULT')) {
        throw "DEFAULT template not found in $TemplateFilePath"
    }
    
    $template = $templates['DEFAULT']
    
    # Use pre-converted bytes if available, otherwise convert from HEX
    $byteArray = if ($template.Bytes) {
        $template.Bytes
    } else {
        ConvertTo-ByteArray -Data $template.Format -Encoding 'HEX'
    }
    
    # Send data
    Send-Data -ConnectionId $ConnectionId -Data $byteArray
}

function Handle-QuickSendClick {
    param(
        $Row,
        [string]$ConnectionId,
        $Connection
    )

    $comboCell = $Row.Cells["ManualSend"]
    if (-not $comboCell) { return }

    $selectedKey = if ($comboCell.Value) { [string]$comboCell.Value } else { "" }
    if ([string]::IsNullOrWhiteSpace($selectedKey)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a template to send.", "Warning") | Out-Null
        return
    }

    $tagData = $comboCell.Tag
    $templateMapping = $null
    if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("Mapping")) {
        $templateMapping = $tagData["Mapping"]
    }

    if (-not $templateMapping -or -not $templateMapping.ContainsKey($selectedKey)) {
        [System.Windows.Forms.MessageBox]::Show("Selected template is not available.", "Warning") | Out-Null
        return
    }

    $templateEntry = $templateMapping[$selectedKey]
    $templatePath = $templateEntry.FilePath

    if (-not $templatePath -or -not (Test-Path -LiteralPath $templatePath)) {
        [System.Windows.Forms.MessageBox]::Show("Template file not found: $templatePath", "Warning") | Out-Null
        return
    }

    try {
        Send-ManualData -ConnectionId $ConnectionId -TemplateFilePath $templatePath
        $targetName = if ($Connection) { $Connection.DisplayName } else { $ConnectionId }
        $templateName = $templateEntry.FileName
        Write-Console "[Manual:Send] Sent template '$templateName' to $targetName" -ForegroundColor Cyan
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to send data: $_", "Error") | Out-Null
    }
}

function Handle-ActionSendClick {
    param(
        $Row,
        [string]$ConnectionId,
        $Connection
    )

    $actionCell = $Row.Cells["ManualScript"]
    if (-not $actionCell) { return }

    $selectedKey = if ($actionCell.Value) { [string]$actionCell.Value } else { "" }
    if ([string]::IsNullOrWhiteSpace($selectedKey)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a script to run.", "Warning") | Out-Null
        return
    }

    $tagData = $actionCell.Tag
    $actionMapping = $null
    if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("Mapping")) {
        $actionMapping = $tagData["Mapping"]
    }

    if (-not $actionMapping -or -not $actionMapping.ContainsKey($selectedKey)) {
        [System.Windows.Forms.MessageBox]::Show("Selected script is not available.", "Warning") | Out-Null
        return
    }

    $actionEntry = $actionMapping[$selectedKey]
    
    if ($actionEntry.Type -eq "Script") {
        $scriptPath = $actionEntry.FilePath
        if (-not $scriptPath -or -not (Test-Path -LiteralPath $scriptPath)) {
            [System.Windows.Forms.MessageBox]::Show("Script file not found: $scriptPath", "Warning") | Out-Null
            return
        }

        # インスタンスパスを取得
        $instancePath = $null
        if ($Connection -and $Connection.Variables -and $Connection.Variables.ContainsKey('InstancePath')) {
            $instancePath = $Connection.Variables['InstancePath']
        }

        # Contextを作成（Manual Scriptは受信データがないので最小限）
        $context = [PSCustomObject]@{
            ConnectionId = $ConnectionId
            InstancePath = $instancePath
        }

        try {
            Write-Console "[Manual:Script] Executing script: $($actionEntry.FileName)" -ForegroundColor Cyan
            
            # スクリプトを実行
            & $scriptPath -Context $context
            
            Write-Console "[Manual:Script] Script completed: $($actionEntry.FileName)" -ForegroundColor Green
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to execute script: $_", "Error") | Out-Null
            Write-Console "[Manual:Script] Script failed: $_" -ForegroundColor Red
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Selected action is not supported.", "Warning") | Out-Null
    }
}

function Handle-RowConnectClick {
    <#
    .SYNOPSIS
    Handles the Connect button click for a specific row.
    #>
    param(
        [string]$ConnectionId
    )

    if ([string]::IsNullOrWhiteSpace($ConnectionId)) {
        return $false
    }

    # 接続状態を確認し、既に接続済みなら何もしない
    $conn = Get-UiConnection -ConnectionId $ConnectionId
    if ($conn -and $conn.Status -ne 'DISCONNECTED' -and $conn.Status -ne 'ERROR') {
        Write-Console "[UI] Connection already active: $ConnectionId (Status: $($conn.Status))" -ForegroundColor Gray
        return $false
    }

    try {
        Start-Connection -ConnectionId $ConnectionId
        Write-Console "[UI] Connection started: $ConnectionId" -ForegroundColor Green
        return $true
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to start connection: $_", "Error") | Out-Null
        return $false
    }
}

function Handle-RowDisconnectClick {
    <#
    .SYNOPSIS
    Handles the Disconnect button click for a specific row.
    #>
    param(
        [string]$ConnectionId
    )

    if ([string]::IsNullOrWhiteSpace($ConnectionId)) {
        return $false
    }

    # 接続状態を確認し、既に切断済みなら何もしない
    $conn = Get-UiConnection -ConnectionId $ConnectionId
    if ($conn -and ($conn.Status -eq 'DISCONNECTED' -or $conn.Status -eq 'ERROR')) {
        Write-Console "[UI] Connection already disconnected: $ConnectionId (Status: $($conn.Status))" -ForegroundColor Gray
        return $false
    }

    try {
        Stop-Connection -ConnectionId $ConnectionId
        Write-Console "[UI] Connection stopped: $ConnectionId" -ForegroundColor Yellow
        return $true
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to stop connection: $_", "Error") | Out-Null
        return $false
    }
}

function Handle-CellClick {
    param(
        $Sender,
        $EventArgs,
        [hashtable]$GridState
    )

    # グリッド更新中はクリックを無視
    if ($script:isUpdatingGrid) {
        return
    }

    if ($EventArgs.RowIndex -lt 0 -or $EventArgs.ColumnIndex -lt 0) {
        return
    }

    $row = $Sender.Rows[$EventArgs.RowIndex]
    $cell = $row.Cells[$EventArgs.ColumnIndex]
    $column = $cell.OwningColumn

    if (-not $column) {
        return
    }

    # Handle Button Clicks (Delegate to Handle-CellContentClick logic)
    # We use CellClick instead of CellContentClick to ensure clicks on the button padding are also caught.
    if ($column -is [System.Windows.Forms.DataGridViewButtonColumn]) {
        try {
            Handle-CellContentClick -Sender $Sender -evt $EventArgs
        } catch {
            Write-Console "[ERROR] Exception in Handle-CellContentClick: $_" -ForegroundColor Red
        }
        return
    }

    # コンボボックス列のみを処理
    if ($column -isnot [System.Windows.Forms.DataGridViewComboBoxColumn]) {
        return
    }

    $GridState.PendingComboDropDown = $column.Name
    if ($Sender.CurrentCell -ne $cell) {
        $Sender.CurrentCell = $cell
    }

    if (-not $Sender.IsCurrentCellInEditMode -and $cell -and $cell.OwningRow) {
        try {
            [void]$Sender.BeginEdit($true)
        } catch {
            # グリッド更新中のタイミングエラーを無視
            Write-Verbose "[UI] BeginEdit failed - timing issue"
            return
        }
    }

    $combo = $Sender.EditingControl
    if ($combo -is [System.Windows.Forms.ComboBox]) {
        $combo.DroppedDown = $true
        $GridState.PendingComboDropDown = $null
    }
}

function Handle-EditingControlShowing {
    param(
        $Sender,
        $EventArgs,
        [hashtable]$GridState
    )

    $control = $EventArgs.Control
    if ($control -isnot [System.Windows.Forms.ComboBox]) {
        return
    }

    # ドロップダウン表示処理
    if ($GridState.PendingComboDropDown) {
        $currentCell = $Sender.CurrentCell
        if (-not $currentCell -or -not $currentCell.OwningColumn) {
            $GridState.PendingComboDropDown = $null
            return
        }

        if ($currentCell.OwningColumn.Name -eq $GridState.PendingComboDropDown) {
            $control.DroppedDown = $true
        }

        $GridState.PendingComboDropDown = $null
    }

    # コンボボックス選択変更の即座反映（OnTimerSendやScenario用）
    $currentCell = $Sender.CurrentCell
    if ($currentCell -and $currentCell.OwningColumn) {
        $columnName = $currentCell.OwningColumn.Name
        
        # 以前のイベントハンドラーを削除（重複登録防止）
        $control.remove_SelectedIndexChanged($script:comboSelectedIndexChangedHandler)
        
        # 新しいイベントハンドラーを作成
        $script:comboSelectedIndexChangedHandler = {
            param($comboSender, $comboArgs)
            
            # コンボボックスから親のDataGridViewを取得
            $comboBox = $comboSender -as [System.Windows.Forms.ComboBox]
            if (-not $comboBox) {
                return
            }
            
            # 親コントロールを辿ってDataGridViewを取得
            $grid = $comboBox.Parent
            while ($grid -and $grid -isnot [System.Windows.Forms.DataGridView]) {
                $grid = $grid.Parent
            }
            
            if (-not $grid) {
                return
            }
            
            $cell = $grid.CurrentCell
            
            if ($cell -and $comboBox.SelectedItem) {
                $selectedValue = $comboBox.SelectedItem.Key
                $entry = $comboBox.SelectedItem
                $columnName = $cell.OwningColumn.Name
                $rowIndex = $cell.RowIndex
                
                # 行からConnectionIdを取得
                $row = $grid.Rows[$rowIndex]
                
                # 列の存在確認（安全な方法）
                $idCell = $null
                try {
                    $idCell = $row.Cells["Id"]
                }
                catch {
                    return
                }
                
                if (-not $idCell) {
                    return
                }
                
                $connId = $idCell.Value
                if (-not $connId) {
                    return
                }
                
                # セルの値を更新
                $cell.Value = $selectedValue
                
                # 編集を終了
                $grid.EndEdit()
                
                # カラムごとの処理を実行
                if ($columnName -eq "Profile") {
                    try {
                        Apply-ProfileToConnectionRow -DataGridView $grid -Row $row -ProfileName $selectedValue
                    }
                    catch {
                        Write-Warning "Error in Apply-ProfileToConnectionRow: $_"
                    }
                }
                elseif ($columnName -eq "OnTimerSend") {
                    $tagData = $cell.Tag
                    $currentTimerSendKey = ""
                    if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("OnTimerSendProfileKey")) {
                        $currentTimerSendKey = $tagData["OnTimerSendProfileKey"]
                    }
                    
                    try {
                        Apply-OnTimerSendProfile -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentTimerSendKey -Sender $grid
                    }
                    catch {
                        Write-Warning "Error in Apply-OnTimerSendProfile: $_"
                    }
                }
                elseif ($columnName -eq "Scenario") {
                    $tagData = $cell.Tag
                    $currentProfileKey = ""
                    if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("ProfileKey")) {
                        $currentProfileKey = $tagData["ProfileKey"]
                    }
                    
                    try {
                        if ($entry -and $entry.Type -eq "Scenario") {
                            Execute-Scenario -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentProfileKey -Sender $grid
                        } else {
                            Apply-OnReceiveReplyProfile -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentProfileKey -Sender $grid
                        }
                    }
                    catch {
                        Write-Warning "Error in Scenario handling: $_"
                    }
                }
                elseif ($columnName -eq "OnReceiveScript") {
                    $tagData = $cell.Tag
                    $currentOnReceiveScriptKey = ""
                    if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("OnReceiveScriptProfileKey")) {
                        $currentOnReceiveScriptKey = $tagData["OnReceiveScriptProfileKey"]
                    }
                    
                    try {
                        Apply-OnReceiveScriptProfile -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentOnReceiveScriptKey -Sender $grid
                    }
                    catch {
                        Write-Warning "Error in Apply-OnReceiveScriptProfile: $_"
                    }
                }
            }
        }
        
        # イベントハンドラー登録
        $control.add_SelectedIndexChanged($script:comboSelectedIndexChangedHandler)
    }
}

function Update-InstanceList {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView,
        [switch]$PreserveComboStates = $true
    )

    if (-not $DataGridView) {
        return
    }

    # 更新中は新しい更新をスキップ（フリーズ防止）
    if ($script:isUpdatingGrid) {
        return
    }

    try {
        $script:isUpdatingGrid = $true
        
        # 編集モードを終了してから更新を行う（描画バグ防止）
        if ($DataGridView.IsCurrentCellInEditMode) {
            try {
                $DataGridView.EndEdit()
            } catch {
                # 編集終了に失敗しても続行
            }
        }
        
        # 現在のセル選択をクリア
        try {
            $DataGridView.CurrentCell = $null
        } catch {
            # 失敗しても続行
        }
        
        $state = Save-GridState -DataGridView $DataGridView
        
        # Suspend layout to prevent flickering during update
        $DataGridView.SuspendLayout()
        
        try {
            $DataGridView.Rows.Clear()

            $connections = Get-UiConnections
            if ($connections -and $connections.Count -gt 0) {
                foreach ($conn in $connections | Sort-Object DisplayName) {
                    try {
                        Add-ConnectionRow -DataGridView $DataGridView -Connection $conn
                    }
                    catch {
                        Write-Verbose "[UI] Failed to add row for connection: $_"
                    }
                }

                Restore-GridState -DataGridView $DataGridView -State $state -PreserveComboStates:$PreserveComboStates
            }
        } finally {
            $DataGridView.ResumeLayout()
        }
    }
    catch {
        Write-Verbose "[UI] Update-InstanceList failed: $_"
    }
    finally {
        $script:isUpdatingGrid = $false
    }
}

function Save-GridState {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView
    )

    # 現在のセル位置を保存
    $currentCellRowIndex = $null
    $currentCellColumnIndex = $null
    $currentConnectionId = $null
    
    if ($DataGridView.CurrentCell) {
        $currentCellRowIndex = $DataGridView.CurrentCell.RowIndex
        $currentCellColumnIndex = $DataGridView.CurrentCell.ColumnIndex
        
        # 行のConnection IDを取得
        if ($currentCellRowIndex -ge 0 -and $DataGridView.Columns.Contains("Id")) {
            $currentConnectionId = $DataGridView.Rows[$currentCellRowIndex].Cells["Id"].Value
        }
    }

    $firstDisplayedIndex = $null
    try {
        if ($DataGridView.RowCount -gt 0 -and $DataGridView.FirstDisplayedScrollingRowIndex -ge 0) {
            $firstDisplayedIndex = $DataGridView.FirstDisplayedScrollingRowIndex
        }
    } catch {
        $firstDisplayedIndex = $null
    }

    if (-not $currentConnectionId -and $DataGridView.Columns.Contains("Id") -and $DataGridView.RowCount -gt 0) {
        $fallbackIndex = 0
        if ($firstDisplayedIndex -ne $null) {
            $fallbackIndex = [Math]::Min([Math]::Max(0, $firstDisplayedIndex), $DataGridView.RowCount - 1)
        }

        try {
            $currentConnectionId = $DataGridView.Rows[$fallbackIndex].Cells["Id"].Value
            $currentCellColumnIndex = 0
        } catch {
            # ignore fallback errors
        }
    }

    # ComboBoxの選択状態を保存
    $comboStates = @{}
    foreach ($row in $DataGridView.Rows) {
        if ($row.Cells["Id"].Value) {
            $connId = $row.Cells["Id"].Value
            $comboStates[$connId] = @{}
            
            # 各ComboBox列の選択値を保存
            foreach ($colName in @('Profile', 'Scenario', 'OnReceiveScript', 'OnTimerSend', 'ManualSend', 'ManualScript')) {
                if ($DataGridView.Columns.Contains($colName)) {
                    $comboStates[$connId][$colName] = $row.Cells[$colName].Value
                }
            }
        }
    }

    return @{
        CurrentConnectionId = $currentConnectionId
        CurrentCellColumnIndex = $currentCellColumnIndex
        FirstDisplayedIndex = $firstDisplayedIndex
        ComboStates = $comboStates
    }
}

function Restore-GridState {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView,
        [hashtable]$State,
        [switch]$PreserveComboStates
    )

    $restoredCurrentCell = $false

    # Restore current cell position
    if ($State.CurrentConnectionId -and $State.CurrentCellColumnIndex -ne $null) {
        foreach ($row in $DataGridView.Rows) {
            if ($row.Cells["Id"].Value -eq $State.CurrentConnectionId) {
                try {
                    $colIndex = [Math]::Min($State.CurrentCellColumnIndex, $DataGridView.Columns.Count - 1)
                    $DataGridView.CurrentCell = $row.Cells[$colIndex]
                    $restoredCurrentCell = $true
                } catch {
                    # セルが編集不可の場合などエラーを無視
                }
                break
            }
        }
    }

    if (-not $restoredCurrentCell -and $DataGridView.RowCount -gt 0 -and $DataGridView.Columns.Count -gt 0) {
        $fallbackIndex = 0
        if ($State.FirstDisplayedIndex -ne $null) {
            $fallbackIndex = [Math]::Min([Math]::Max(0, $State.FirstDisplayedIndex), $DataGridView.RowCount - 1)
        }

        try {
            $DataGridView.CurrentCell = $DataGridView.Rows[$fallbackIndex].Cells[0]
        } catch {
            # ignore fallback errors
        }
    }

    # Restore ComboBox states only if requested
    if ($PreserveComboStates -and $State.ComboStates) {
        foreach ($row in $DataGridView.Rows) {
            $connId = $row.Cells["Id"].Value
            if ($connId -and $State.ComboStates.ContainsKey($connId)) {
                $savedState = $State.ComboStates[$connId]
                foreach ($colName in $savedState.Keys) {
                    if ($DataGridView.Columns.Contains($colName)) {
                        $row.Cells[$colName].Value = $savedState[$colName]
                    }
                }
            }
        }
    }

    # Restore scroll position
    if ($State.FirstDisplayedIndex -ne $null -and $DataGridView.RowCount -gt 0) {
        $targetIndex = [Math]::Min([Math]::Max(0, $State.FirstDisplayedIndex), $DataGridView.RowCount - 1)
        try {
            $DataGridView.FirstDisplayedScrollingRowIndex = $targetIndex
        } catch {
            # ignore scroll errors
        }
    }
}

function Add-ConnectionRow {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView,
        $Connection
    )

    try {
        $localEndpoint = Get-ConnectionLocalEndpoint -Connection $Connection
        $remoteEndpoint = Get-ConnectionRemoteEndpoint -Connection $Connection
        
        # ?X???b?h?Z?[?t??X?e?[?^?X??????
        $status = $Connection.Status
        # 表示用に短縮（CONNECTINGは表示しない）
        $displayStatus = switch ($status) {
            "DISCONNECTED" { "DISCONNECT" }
            "CONNECTING" { "DISCONNECT" }
            default { $status }
        }
        $displayName = $Connection.DisplayName
        $protocol = $Connection.Protocol
        $mode = $Connection.Mode
        $connId = $Connection.Id
        
        Write-Verbose "[Add-ConnectionRow] Adding row: $displayName, Status: $status"

        $rowIndex = $DataGridView.Rows.Add(
            $displayName,
            "$protocol $mode",
            $localEndpoint,
            $remoteEndpoint,
            $displayStatus,
            $null,
            $null,
            $null,
            $null,
            $null,
            $null,
            $null,
            $null,
            $null,
            $null,
            $connId
        )

        $row = $DataGridView.Rows[$rowIndex]

        try {
            $script:suppressScenarioEvent = $true
            $script:suppressOnReceiveScriptEvent = $true
            $script:suppressOnTimerSendEvent = $true

            $instancePath = if ($Connection.Variables.ContainsKey('InstancePath')) { $Connection.Variables['InstancePath'] } else { $null }

            Configure-ProfileColumn -Row $row -Connection $Connection
            Configure-ScenarioColumn -Row $row -Connection $Connection -InstancePath $instancePath
            Configure-OnReceiveScriptColumn -Row $row -Connection $Connection -InstancePath $instancePath
            Configure-OnTimerSendColumn -Row $row -Connection $Connection -InstancePath $instancePath
            Configure-ManualSendColumn -Row $row -InstancePath $instancePath
            Configure-ManualScriptColumn -Row $row -InstancePath $instancePath

        } catch {
            $row.Cells["Scenario"].Value = ""
        } finally {
            $script:suppressScenarioEvent = $false
            $script:suppressOnReceiveScriptEvent = $false
            $script:suppressOnTimerSendEvent = $false
        }

        Set-RowColor -Row $row -Status $status
    } catch {
        Write-Verbose "[UI] Failed to add connection row: $_"
    }
}

function Get-ConnectionLocalEndpoint {
    param($Connection)
    
    if ($Connection.LocalIP -and $Connection.LocalPort) {
        return "$($Connection.LocalIP):$($Connection.LocalPort)"
    }
    return "-"
}

function Get-ConnectionRemoteEndpoint {
    param($Connection)
    
    if ($Connection.RemoteIP -and $Connection.RemotePort) {
        return "$($Connection.RemoteIP):$($Connection.RemotePort)"
    }
    return "-"
}

function Configure-ScenarioColumn {
    param(
        $Row,
        $Connection,
        [string]$InstancePath
    )

    $items = New-Object System.Collections.ArrayList
    $mapping = @{
    }
    $availableScenarios = @()

    $noneEntry = [PSCustomObject]@{
        Display = "(None)"
        Key     = ""
        Type    = "Profile"
        Name    = $null
        Path    = $null
    }
    [void]$items.Add($noneEntry)
    $mapping[$noneEntry.Key] = $noneEntry

    $currentProfile = ""
    $currentPath = $null
    if ($Connection.Variables.ContainsKey('OnReceiveReplyProfile')) {
        $currentProfile = $Connection.Variables['OnReceiveReplyProfile']
    }
    if ($Connection.Variables.ContainsKey('OnReceiveReplyProfilePath')) {
        $currentPath = $Connection.Variables['OnReceiveReplyProfilePath']
    }

    # Add profiles
    $profiles = @()
    if ($InstancePath) {
        try {
            $profiles = Get-InstanceOnReceiveReplyProfiles -InstancePath $InstancePath
        } catch {
            $profiles = @()
        }
    }

    foreach ($profile in $profiles) {
        if ([string]::IsNullOrWhiteSpace($profile.Name)) {
            continue
        }

        $key = "profile::$($profile.Name)"
        $entry = [PSCustomObject]@{
            Display = $profile.DisplayName
            Key     = $key
            Type    = "Profile"
            Name    = $profile.Name
            Path    = $profile.FilePath
        }

        [void]$items.Add($entry)
        $mapping[$key] = $entry
    }

    # Add scenarios
    if ($InstancePath) {
        try {
            $scenarioFiles = Get-InstanceScenarios -InstancePath $InstancePath
        } catch {
            $scenarioFiles = @()
        }

        if ($scenarioFiles -and $scenarioFiles.Count -gt 0) {
            $scenarioRoot = Join-Path $InstancePath "scenarios"
            foreach ($scenario in $scenarioFiles) {
                $scenarioKey = "scenario::$scenario"
                $scenarioPath = Join-Path $scenarioRoot $scenario
                $entry = [PSCustomObject]@{
                    Display = "? $scenario"
                    Key     = $scenarioKey
                    Type    = "Scenario"
                    Name    = $scenario
                    Path    = $scenarioPath
                }
                [void]$items.Add($entry)
                $mapping[$scenarioKey] = $entry
                $availableScenarios += $entry
            }
        }
    }

    $currentKey = ""
    if ($currentProfile) {
        $currentKey = "profile::$currentProfile"
        if (-not $mapping.ContainsKey($currentKey)) {
            $displayName = if ($currentPath) { "$currentProfile (missing)" } else { $currentProfile }
            $entry = [PSCustomObject]@{
                Display = $displayName
                Key     = $currentKey
                Type    = "Profile"
                Name    = $currentProfile
                Path    = $currentPath
            }
            [void]$items.Add($entry)
            $mapping[$currentKey] = $entry
        }
    }

    $scenarioCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
    $scenarioCell.DisplayMember = "Display"
    $scenarioCell.ValueMember = "Key"
    foreach ($item in $items) {
        [void]$scenarioCell.Items.Add($item)
    }
    $scenarioCell.Value = $currentKey
    $scenarioCell.Tag = @{
        Mapping    = $mapping
        ProfileKey = $currentKey
        AvailableScenarios = $availableScenarios
    }
    $Row.Cells["Scenario"] = $scenarioCell
}

function Configure-ManualSendColumn {
    param(
        $Row,
        [string]$InstancePath
    )

    $templateEntries = @()
    if ($InstancePath) {
        try {
            $catalog = Get-ManualSendCatalog -InstancePath $InstancePath
            if ($catalog) {
                $templateEntries = if ($catalog.Entries) { $catalog.Entries } else { @() }
            }
        } catch {
            $templateEntries = @()
        }
    }

    $manualSendCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
    $manualSendCell.DisplayMember = "Display"
    $manualSendCell.ValueMember = "Key"
    $manualSendCell.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

    $dataSource = New-Object System.Collections.ArrayList
    $templateMapping = @{}
    
    $dataPlaceholder = [PSCustomObject]@{
        Display  = "(Select)"
        Key      = ""
        FileName = ""
        FilePath = $null
    }
    [void]$dataSource.Add($dataPlaceholder)
    $templateMapping[""] = $dataPlaceholder

    if ($templateEntries -and $templateEntries.Count -gt 0) {
        foreach ($item in $templateEntries) {
            if (-not $item.FileName) { continue }

            $entry = [PSCustomObject]@{
                Display  = $item.Display
                Key      = $item.FileName
                FileName = $item.FileName
                FilePath = $item.FilePath
            }
            [void]$dataSource.Add($entry)
            $templateMapping[$item.FileName] = $entry
        }
    }

    foreach ($item in $dataSource) {
        [void]$manualSendCell.Items.Add($item)
    }
    $manualSendCell.Value = ""
    $manualSendCell.Tag = @{
        Mapping = $templateMapping
    }
    $Row.Cells["ManualSend"] = $manualSendCell
}

function Configure-ManualScriptColumn {
    param(
        $Row,
        [string]$InstancePath
    )

    $scriptEntries = @()
    if ($InstancePath) {
        try {
            $catalog = Get-ManualScriptCatalog -InstancePath $InstancePath
            if ($catalog) {
                $scriptEntries = if ($catalog.Entries) { $catalog.Entries } else { @() }
            }
        } catch {
            $scriptEntries = @()
        }
    }

    $manualScriptCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
    $manualScriptCell.DisplayMember = "Display"
    $manualScriptCell.ValueMember = "Key"
    $manualScriptCell.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

    $actionSource = New-Object System.Collections.ArrayList
    $actionMapping = @{}
    
    $actionPlaceholder = [PSCustomObject]@{
        Display  = "(Select)"
        Key      = ""
        Type     = ""
        FileName = ""
        FilePath = $null
    }
    [void]$actionSource.Add($actionPlaceholder)
    $actionMapping[""] = $actionPlaceholder

    if ($scriptEntries -and $scriptEntries.Count -gt 0) {
        foreach ($item in $scriptEntries) {
            if (-not $item.FileName) { continue }

            $entry = [PSCustomObject]@{
                Display  = $item.Display
                Key      = $item.FileName
                Type     = "Script"
                FileName = $item.FileName
                FilePath = $item.FilePath
            }
            [void]$actionSource.Add($entry)
            $actionMapping[$item.FileName] = $entry
        }
    }

    foreach ($item in $actionSource) {
        [void]$manualScriptCell.Items.Add($item)
    }
    $manualScriptCell.Value = ""
    $manualScriptCell.Tag = @{
        Mapping = $actionMapping
    }
    $Row.Cells["ManualScript"] = $manualScriptCell
}
