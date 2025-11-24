# MainForm.ps1
# WinForms main window definition

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-UiConnectionService {
    if ($Global:ConnectionService) {
        return $Global:ConnectionService
    }
    if (Get-Command Get-ConnectionService -ErrorAction SilentlyContinue) {
        return Get-ConnectionService
    }
    throw "ConnectionService is not available."
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
    $form = New-MainFormWindow -Title "TCP Test Controller v1.0" -Width 1200 -Height 750
    $script:CurrentMainForm = $form

    # Toolbar buttons using ViewBuilder
    $btnConnect = New-ToolbarButton -Text "Connect" -X 10 -Y 10
    $form.Controls.Add($btnConnect)

    $btnDisconnect = New-ToolbarButton -Text "Disconnect" -X 120 -Y 10
    $form.Controls.Add($btnDisconnect)

    # Global profile combo box (アプリケーションプロファイル用)
    $lblGlobalProfile = New-Object System.Windows.Forms.Label
    $lblGlobalProfile.Text = "App Profile:"
    $lblGlobalProfile.Location = New-Object System.Drawing.Point(230, 13)
    $lblGlobalProfile.Size = New-Object System.Drawing.Size(80, 20)
    $lblGlobalProfile.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $form.Controls.Add($lblGlobalProfile)

    $script:cmbGlobalProfile = New-Object System.Windows.Forms.ComboBox
    $script:cmbGlobalProfile.Location = New-Object System.Drawing.Point(315, 10)
    $script:cmbGlobalProfile.Size = New-Object System.Drawing.Size(180, 25)
    $script:cmbGlobalProfile.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $form.Controls.Add($script:cmbGlobalProfile)

    # DataGridView (connection list) using ViewBuilder
    $dgvInstances = New-ConnectionDataGridView -X 10 -Y 50 -Width 1160 -Height 200
    $form.Controls.Add($dgvInstances)

    # Log area using ViewBuilder
    $lblLog = New-LabelControl -Text "Connection Log:" -X 10 -Y 290 -Width 200 -Height 20
    $form.Controls.Add($lblLog)

    $txtLog = New-LogTextBox -X 10 -Y 315 -Width 1165 -Height 385
    $form.Controls.Add($txtLog)
    
    # アプリケーションプロファイルコンボボックスの初期化
    function Initialize-ProfileComboBoxes {
        $script:cmbGlobalProfile.Items.Clear()
        $script:cmbGlobalProfile.Items.Add("(None)") | Out-Null

        if ($Global:ProfileService) {
            $profiles = $Global:ProfileService.GetAvailableApplicationProfiles() | Sort-Object
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
            Write-Host "[UI] Clearing all profiles (None selected)" -ForegroundColor Cyan
            Clear-AllProfiles -DataGridView $dgvInstances
            return
        }

        Write-Host "[UI] Applying application profile: $selectedProfile" -ForegroundColor Cyan
        Apply-ApplicationProfile -DataGridView $dgvInstances -ProfileName $selectedProfile
    })

    # State holders
    $script:suppressScenarioEvent = $false
    $script:suppressOnReceivedEvent = $false
    $script:suppressPeriodicSendEvent = $false
    $script:suppressProfileEvent = $false
    $script:isGlobalProfileLocked = $false
    $script:lastSelectedConnectionId = $null
    $script:comboSelectedIndexChangedHandler = $null
    $gridState = @{
        EditingInProgress = $false
        PendingComboDropDown = $null
    }

    # Register event handlers
    Register-GridEvents -DataGridView $dgvInstances -GridState $gridState
    Register-ButtonEvents -DataGridView $dgvInstances -BtnConnect $btnConnect -BtnDisconnect $btnDisconnect

    # メッセージ処理タイマー (100ms間隔でRunspaceからのメッセージを処理)
    $messageTimer = New-Object System.Windows.Forms.Timer
    $messageTimer.Interval = 100
    $messageTimer.Add_Tick({
        try {
            if ($Global:MessageProcessor) {
                $processed = $Global:MessageProcessor.ProcessMessages(50)
            }
        }
        catch {
            # エラーは通常のロガーに任せる
        }
    })
    $messageTimer.Start()

    # Timer for periodic refresh (3秒間隔で性能最適化)
    $timer = New-RefreshTimer -IntervalMilliseconds 3000
    $timer.Add_Tick({
        try {
            if (-not $gridState.EditingInProgress -and -not $dgvInstances.IsCurrentCellInEditMode) {
                Update-InstanceList -DataGridView $dgvInstances
            }
            Update-LogDisplay -TextBox $txtLog -GetConnectionsCallback { Get-UiConnections }
        }
        catch {
            # ?^?C?}?[????G???[??????????A???O??L?^
            Write-Verbose "[UI Timer] Error during refresh: $_"
        }
    })
    $timer.Start()

    # Form closing cleanup
    $form.Add_FormClosing({
        $messageTimer.Stop()
        $timer.Stop()
        
        # Loggerバッファをフラッシュ
        if ($Global:Logger) {
            try {
                $Global:Logger.Flush()
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
        Write-Host "[Warning] Failed to initialize profile combo boxes: $_" -ForegroundColor Yellow
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
            $DataGridView.CurrentCell.OwningColumn.Name -in @("Scenario", "OnReceived", "PeriodicSend", "Profile")) {
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
        elseif ($column.Name -eq "PeriodicSend") {
            Handle-PeriodicSendChanged -Sender $sender -Args $args
        }
        elseif ($column.Name -eq "OnReceived") {
            Handle-OnReceivedChanged -Sender $sender -Args $args
        }
        elseif ($column.Name -eq "Profile") {
            Handle-ProfileChanged -Sender $sender -Args $args
        }
    })

    $DataGridView.Add_CellContentClick({
        param($sender, $args)
        Handle-CellContentClick -Sender $sender -Args $args
    })

    $DataGridView.Add_CellClick({
        param($sender, $args)
        Handle-ComboBoxClick -Sender $sender -Args $args -GridState $GridState
    })

    # Track selection to preserve it across grid updates
    $DataGridView.Add_SelectionChanged({
        if ($DataGridView.SelectedRows.Count -gt 0 -and $DataGridView.Columns.Contains("Id")) {
            $connId = $DataGridView.SelectedRows[0].Cells["Id"].Value
            if ($connId) {
                $script:lastSelectedConnectionId = $connId
            }
        }
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
        $connection = Get-SelectedConnection -DataGridView $DataGridView
        if (-not $connection) {
            [System.Windows.Forms.MessageBox]::Show("Please select a connection first.", "No Selection") | Out-Null
            return
        }
        try {
            Start-Connection -ConnectionId $connection.Id
            # MessageBox??UI???X???b?h???u???b?N?????A??????????
            # [System.Windows.Forms.MessageBox]::Show("Connection started: $($connection.DisplayName)", "Success") | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to start connection: $_", "Error") | Out-Null
        }
        Update-InstanceList -DataGridView $DataGridView
    })

    $BtnDisconnect.Add_Click({
        $connection = Get-SelectedConnection -DataGridView $DataGridView
        if (-not $connection) {
            return
        }
        try {
            Stop-Connection -ConnectionId $connection.Id
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to stop connection: $_", "Error") | Out-Null
        }
        Update-InstanceList -DataGridView $DataGridView
    })
}

function Get-SelectedConnection {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView
    )

    $connId = $null
    
    # Try getting selection from SelectedRows first
    if ($DataGridView.SelectedRows.Count -gt 0 -and $DataGridView.Columns.Contains("Id")) {
        $connId = $DataGridView.SelectedRows[0].Cells["Id"].Value
    }
    
    # Fallback: Try CurrentRow if no selection
    if (-not $connId -and $DataGridView.CurrentRow -and $DataGridView.Columns.Contains("Id")) {
        $connId = $DataGridView.CurrentRow.Cells["Id"].Value
    }
    
    # Fallback: Use last selected connection ID (preserved across grid updates)
    if (-not $connId -and $script:lastSelectedConnectionId) {
        $connId = $script:lastSelectedConnectionId
    }
    
    if (-not $connId) {
        return $null
    }
    
    try {
        return Get-UiConnection -ConnectionId $connId
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Connection not found: $connId", "Error") | Out-Null
        return $null
    }
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

    Apply-AutoResponseProfile -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentProfileKey -Sender $Sender
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

function Apply-AutoResponseProfile {
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
        Set-ConnectionAutoResponseProfile -ConnectionId $ConnectionId -ProfileName $profileName -ProfilePath $profilePath | Out-Null
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
        [System.Windows.Forms.MessageBox]::Show("Failed to apply auto-response profile: $_", "Error") | Out-Null
    }
}

function Handle-PeriodicSendChanged {
    param(
        $Sender,
        $Args
    )

    if ($script:suppressPeriodicSendEvent) {
        return
    }
    if ($Args.ColumnIndex -lt 0 -or $Args.RowIndex -lt 0) {
        return
    }
    $column = $Sender.Columns[$Args.ColumnIndex]
    if ($column.Name -ne "PeriodicSend") {
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

    $cell = $row.Cells["PeriodicSend"]
    $tagData = $cell.Tag
    $mapping = $null
    $currentPeriodicSendKey = ""

    if ($tagData -is [System.Collections.IDictionary]) {
        if ($tagData.ContainsKey("Mapping")) {
            $mapping = $tagData["Mapping"]
        }
        if ($tagData.ContainsKey("PeriodicSendProfileKey")) {
            $currentPeriodicSendKey = $tagData["PeriodicSendProfileKey"]
        }
    }

    $selectedKey = if ($cell.Value) { [string]$cell.Value } else { "" }
    
    $entry = $null
    if ($mapping -and $mapping.ContainsKey($selectedKey)) {
        $entry = $mapping[$selectedKey]
    }

    Apply-PeriodicSendProfile -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentPeriodicSendKey -Sender $Sender
}

function Apply-PeriodicSendProfile {
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

        # 新しいプロファイルを設定（Set-ConnectionPeriodicSendProfileが状態チェックを行う）
        # インスタンスパスを取得
        $instancePath = $null
        if ($connection.Variables.ContainsKey('InstancePath')) {
            $instancePath = $connection.Variables['InstancePath']
        }

        if ($profilePath -and (Test-Path -LiteralPath $profilePath)) {
            # Set-ConnectionPeriodicSendProfileを使用（接続状態をチェックし、CONNECTEDの場合のみタイマーを開始）
            Set-ConnectionPeriodicSendProfile -ConnectionId $ConnectionId -ProfilePath $profilePath -InstancePath $instancePath
            Write-Host "[PeriodicSend] Applied profile: $profileName" -ForegroundColor Green
        }
        else {
            # プロファイルをクリア
            Set-ConnectionPeriodicSendProfile -ConnectionId $ConnectionId -ProfilePath $null -InstancePath $instancePath
            Write-Host "[PeriodicSend] Cleared profile" -ForegroundColor Yellow
        }

        # Tagを更新
        $tagData = $Cell.Tag
        if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("PeriodicSendProfileKey")) {
            $tagData["PeriodicSendProfileKey"] = $Cell.Value
        }
    }
    catch {
        # エラー時は元の値に戻す
        if ($CurrentKey -ne $Cell.Value) {
            $script:suppressPeriodicSendEvent = $true
            try {
                $Cell.Value = $CurrentKey
            } finally {
                $script:suppressPeriodicSendEvent = $false
            }
            $Sender.InvalidateCell($Cell)
        }
        [System.Windows.Forms.MessageBox]::Show("Failed to apply periodic send profile: $_", "Error") | Out-Null
    }
}

function Handle-OnReceivedChanged {
    param(
        $Sender,
        $Args
    )

    if ($script:suppressOnReceivedEvent) {
        return
    }
    if ($Args.ColumnIndex -lt 0 -or $Args.RowIndex -lt 0) {
        return
    }
    $column = $Sender.Columns[$Args.ColumnIndex]
    if ($column.Name -ne "OnReceived") {
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

    $cell = $row.Cells["OnReceived"]
    $tagData = $cell.Tag
    $mapping = $null
    $currentProfileKey = ""

    if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("Mapping") -and $tagData.ContainsKey("OnReceivedProfileKey")) {
        $mapping = $tagData["Mapping"]
        $currentProfileKey = $tagData["OnReceivedProfileKey"]
    }

    $selectedKey = if ($cell.Value) { [string]$cell.Value } else { "" }
    $entry = $null
    if ($mapping -and $mapping.ContainsKey($selectedKey)) {
        $entry = $mapping[$selectedKey]
    }

    Apply-OnReceivedProfile -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentProfileKey -Sender $Sender
}

function Apply-OnReceivedProfile {
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
        Set-ConnectionOnReceivedProfile -ConnectionId $ConnectionId -ProfileName $profileName -ProfilePath $profilePath | Out-Null
        $tagData = $Cell.Tag
        if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("OnReceivedProfileKey")) {
            $tagData["OnReceivedProfileKey"] = $Cell.Value
        }
    } catch {
        if ($CurrentKey -ne $Cell.Value) {
            $script:suppressOnReceivedEvent = $true
            try {
                $Cell.Value = $CurrentKey
            } finally {
                $script:suppressOnReceivedEvent = $false
            }
            $Sender.InvalidateCell($Cell)
        }
        [System.Windows.Forms.MessageBox]::Show("Failed to apply OnReceived profile: $_", "Error") | Out-Null
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

    if (-not $Global:ProfileService) {
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
            # AutoResponseプロファイルをクリア
            Set-ConnectionAutoResponseProfile -ConnectionId $connId -ProfileName $null -ProfilePath $null | Out-Null
            
            # OnReceivedプロファイルをクリア
            Set-ConnectionOnReceivedProfile -ConnectionId $connId -ProfileName $null -ProfilePath $null | Out-Null
            
            # PeriodicSendプロファイルをクリア
            Set-ConnectionPeriodicSendProfile -ConnectionId $connId -ProfilePath $null -InstancePath $instancePath | Out-Null
            
            # InstanceProfile変数もクリア
            $connection.Variables.Remove('InstanceProfile')
        }
        else {
            # ProfileNameが指定されている場合は、プロファイルを適用
            $Global:ProfileService.ApplyInstanceProfile($connId, $instanceName, $ProfileName, $instancePath)
        }

        $script:suppressProfileEvent = $true
        $script:suppressScenarioEvent = $true
        $script:suppressOnReceivedEvent = $true
        $script:suppressPeriodicSendEvent = $true
        
        Update-InstanceList -DataGridView $DataGridView -PreserveComboStates:$false
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to apply profile '$ProfileName': $_", "Error") | Out-Null
    }
    finally {
        $script:suppressScenarioEvent = $false
        $script:suppressOnReceivedEvent = $false
        $script:suppressPeriodicSendEvent = $false
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

    if (-not $Global:ProfileService -or [string]::IsNullOrWhiteSpace($ProfileName)) {
        return
    }

    try {
        # アプリケーションプロファイルを適用（全インスタンスに一斉適用）
        $Global:ProfileService.ApplyApplicationProfile($ProfileName)
        
        # UIを更新
        $script:suppressProfileEvent = $true
        $script:suppressScenarioEvent = $true
        $script:suppressOnReceivedEvent = $true
        $script:suppressPeriodicSendEvent = $true
        try {
            Update-InstanceList -DataGridView $DataGridView -PreserveComboStates:$false
        }
        finally {
            $script:suppressScenarioEvent = $false
            $script:suppressOnReceivedEvent = $false
            $script:suppressPeriodicSendEvent = $false
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
                
                # AutoResponseプロファイルをクリア
                Set-ConnectionAutoResponseProfile -ConnectionId $connId -ProfileName $null -ProfilePath $null | Out-Null
                
                # OnReceivedプロファイルをクリア
                Set-ConnectionOnReceivedProfile -ConnectionId $connId -ProfileName $null -ProfilePath $null | Out-Null
                
                # PeriodicSendプロファイルをクリア（InstancePathが必要）
                if ($instancePath) {
                    Set-ConnectionPeriodicSendProfile -ConnectionId $connId -ProfilePath $null -InstancePath $instancePath | Out-Null
                }
                
                # InstanceProfile変数もクリア
                $conn.Variables.Remove('InstanceProfile')
                $clearedCount++
            }
            catch {
                Write-Warning "[UI] Failed to clear profiles for ${connId}: $_"
            }
        }
        
        Write-Host "[Clear-AllProfiles] Cleared profiles for $clearedCount connection(s)" -ForegroundColor Green
        
        # UIを更新
        $script:suppressProfileEvent = $true
        $script:suppressScenarioEvent = $true
        $script:suppressOnReceivedEvent = $true
        $script:suppressPeriodicSendEvent = $true
        try {
            Update-InstanceList -DataGridView $DataGridView -PreserveComboStates:$false
        }
        finally {
            $script:suppressScenarioEvent = $false
            $script:suppressOnReceivedEvent = $false
            $script:suppressPeriodicSendEvent = $false
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

    foreach ($columnName in @("Profile", "Scenario", "OnReceived", "PeriodicSend")) {
        if ($DataGridView.Columns.Contains($columnName)) {
            $DataGridView.Columns[$columnName].ReadOnly = $IsLocked
        }
    }
}

function Handle-CellContentClick {
    param(
        $Sender,
        $Args
    )

    if ($Args.RowIndex -lt 0 -or $Args.ColumnIndex -lt 0) {
        return
    }
    $column = $Sender.Columns[$Args.ColumnIndex]
    if (-not $column) {
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
    }
}

function Handle-QuickSendClick {
    param(
        $Row,
        [string]$ConnectionId,
        $Connection
    )

    $comboCell = $Row.Cells["QuickData"]
    if (-not $comboCell) { return }

    $selectedKey = if ($comboCell.Value) { [string]$comboCell.Value } else { "" }
    if ([string]::IsNullOrWhiteSpace($selectedKey)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a data item to send.", "Warning") | Out-Null
        return
    }

    $tagData = $comboCell.Tag
    $dataBankPath = $null
    $dataBankCount = 0
    if ($tagData -is [System.Collections.IDictionary]) {
        if ($tagData.ContainsKey("DataBankPath")) {
            $dataBankPath = $tagData["DataBankPath"]
        }
        if ($tagData.ContainsKey("DataBankCount")) {
            $dataBankCount = [int]$tagData["DataBankCount"]
        }
    }

    if ($dataBankCount -le 0 -and [string]::IsNullOrWhiteSpace($dataBankPath)) {
        [System.Windows.Forms.MessageBox]::Show("No data bank entries available for this connection.", "Warning") | Out-Null
        return
    }

    if ($dataBankPath -and -not (Test-Path -LiteralPath $dataBankPath)) {
        [System.Windows.Forms.MessageBox]::Show("Data bank file not found: $dataBankPath", "Warning") | Out-Null
        return
    }

    try {
        Send-QuickData -ConnectionId $ConnectionId -DataID $selectedKey -DataBankPath $dataBankPath
        $targetName = if ($Connection) { $Connection.DisplayName } else { $ConnectionId }
        [System.Windows.Forms.MessageBox]::Show("Sent data item '$selectedKey' to $targetName.", "Success") | Out-Null
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

    $actionCell = $Row.Cells["QuickAction"]
    if (-not $actionCell) { return }

    $selectedKey = if ($actionCell.Value) { [string]$actionCell.Value } else { "" }
    if ([string]::IsNullOrWhiteSpace($selectedKey)) {
        [System.Windows.Forms.MessageBox]::Show("Please select an action to run.", "Warning") | Out-Null
        return
    }

    $tagData = $actionCell.Tag
    $actionMapping = $null
    if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("Mapping")) {
        $actionMapping = $tagData["Mapping"]
    }

    if (-not $actionMapping -or -not $actionMapping.ContainsKey($selectedKey)) {
        [System.Windows.Forms.MessageBox]::Show("Selected action is not available.", "Warning") | Out-Null
        return
    }

    $actionEntry = $actionMapping[$selectedKey]
    if ($actionEntry.Type -eq "Scenario") {
        $scenarioPath = $actionEntry.Path
        if (-not $scenarioPath -or -not (Test-Path -LiteralPath $scenarioPath)) {
            [System.Windows.Forms.MessageBox]::Show("Scenario file not found.", "Warning") | Out-Null
            return
        }

        try {
            Start-Scenario -ConnectionId $ConnectionId -ScenarioPath $scenarioPath
            $actionName = if ($actionEntry.Name) { $actionEntry.Name } else { $selectedKey }
            [System.Windows.Forms.MessageBox]::Show("Started scenario '$actionName'.", "Success") | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to start scenario: $_", "Error") | Out-Null
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Selected action is not supported.", "Warning") | Out-Null
    }
}

function Handle-ComboBoxClick {
    param(
        $Sender,
        $Args,
        [hashtable]$GridState
    )

    if ($Args.RowIndex -lt 0 -or $Args.ColumnIndex -lt 0) {
        return
    }

    $row = $Sender.Rows[$Args.RowIndex]
    $cell = $row.Cells[$Args.ColumnIndex]
    $column = $cell.OwningColumn

    if (-not $column -or ($column -isnot [System.Windows.Forms.DataGridViewComboBoxColumn])) {
        return
    }

    $GridState.PendingComboDropDown = $column.Name
    if ($Sender.CurrentCell -ne $cell) {
        $Sender.CurrentCell = $cell
    }

    if (-not $Sender.IsCurrentCellInEditMode) {
        [void]$Sender.BeginEdit($true)
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

    # コンボボックス選択変更の即座反映（PeriodicSendやScenario用）
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
                elseif ($columnName -eq "PeriodicSend") {
                    $tagData = $cell.Tag
                    $currentPeriodicSendKey = ""
                    if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("PeriodicSendProfileKey")) {
                        $currentPeriodicSendKey = $tagData["PeriodicSendProfileKey"]
                    }
                    
                    try {
                        Apply-PeriodicSendProfile -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentPeriodicSendKey -Sender $grid
                    }
                    catch {
                        Write-Warning "Error in Apply-PeriodicSendProfile: $_"
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
                            Apply-AutoResponseProfile -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentProfileKey -Sender $grid
                        }
                    }
                    catch {
                        Write-Warning "Error in Scenario handling: $_"
                    }
                }
                elseif ($columnName -eq "OnReceived") {
                    $tagData = $cell.Tag
                    $currentOnReceivedKey = ""
                    if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("OnReceivedProfileKey")) {
                        $currentOnReceivedKey = $tagData["OnReceivedProfileKey"]
                    }
                    
                    try {
                        Apply-OnReceivedProfile -ConnectionId $connId -Entry $entry -Cell $cell -CurrentKey $currentOnReceivedKey -Sender $grid
                    }
                    catch {
                        Write-Warning "Error in Apply-OnReceivedProfile: $_"
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

    try {
        $state = Save-GridState -DataGridView $DataGridView
        
        # Suspend layout to prevent flickering
        $DataGridView.SuspendLayout()
        
        try {
            $DataGridView.Rows.Clear()

            $connections = Get-UiConnections
            if (-not $connections -or $connections.Count -eq 0) {
                return
            }

            foreach ($conn in $connections | Sort-Object DisplayName) {
                try {
                    Add-ConnectionRow -DataGridView $DataGridView -Connection $conn
                }
                catch {
                    Write-Verbose "[UI] Failed to add row for connection: $_"
                }
            }

            Restore-GridState -DataGridView $DataGridView -State $state -PreserveComboStates:$PreserveComboStates
        } finally {
            $DataGridView.ResumeLayout()
        }
    }
    catch {
        Write-Verbose "[UI] Update-InstanceList failed: $_"
    }
}

function Save-GridState {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView
    )

    $selectedId = $null
    if ($DataGridView.SelectedRows.Count -gt 0 -and $DataGridView.Columns.Contains("Id")) {
        $selectedId = $DataGridView.SelectedRows[0].Cells["Id"].Value
    }

    $firstDisplayedIndex = $null
    try {
        if ($DataGridView.RowCount -gt 0 -and $DataGridView.FirstDisplayedScrollingRowIndex -ge 0) {
            $firstDisplayedIndex = $DataGridView.FirstDisplayedScrollingRowIndex
        }
    } catch {
        $firstDisplayedIndex = $null
    }

    # ComboBoxの選択状態を保存
    $comboStates = @{}
    foreach ($row in $DataGridView.Rows) {
        if ($row.Cells["Id"].Value) {
            $connId = $row.Cells["Id"].Value
            $comboStates[$connId] = @{}
            
            # 各ComboBox列の選択値を保存
            foreach ($colName in @('Profile', 'AutoResponse', 'OnReceived', 'PeriodicSend')) {
                if ($DataGridView.Columns.Contains($colName)) {
                    $comboStates[$connId][$colName] = $row.Cells[$colName].Value
                }
            }
        }
    }

    return @{
        SelectedId = $selectedId
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

    # Restore selection
    if ($State.SelectedId) {
        foreach ($row in $DataGridView.Rows) {
            if ($row.Cells["Id"].Value -eq $State.SelectedId) {
                $row.Selected = $true
                if ($row.Cells.Count -gt 0) {
                    $DataGridView.CurrentCell = $row.Cells[0]
                }
                break
            }
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
        $endpoint = Get-ConnectionEndpoint -Connection $Connection
        
        # ?X???b?h?Z?[?t??X?e?[?^?X??????
        $status = $Connection.Status
        $displayName = $Connection.DisplayName
        $protocol = $Connection.Protocol
        $mode = $Connection.Mode
        $connId = $Connection.Id

        $rowIndex = $DataGridView.Rows.Add(
            $displayName,
            "$protocol $mode",
            $endpoint,
            $status,
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
            $script:suppressOnReceivedEvent = $true
            $script:suppressPeriodicSendEvent = $true

            $instancePath = if ($Connection.Variables.ContainsKey('InstancePath')) { $Connection.Variables['InstancePath'] } else { $null }

            Configure-ProfileColumn -Row $row -Connection $Connection
            Configure-ScenarioColumn -Row $row -Connection $Connection -InstancePath $instancePath
            Configure-OnReceivedColumn -Row $row -Connection $Connection -InstancePath $instancePath
            Configure-PeriodicSendColumn -Row $row -Connection $Connection -InstancePath $instancePath
            Configure-QuickDataColumn -Row $row -InstancePath $instancePath
            Configure-QuickActionColumn -Row $row -InstancePath $instancePath

        } catch {
            $row.Cells["Scenario"].Value = ""
        } finally {
            $script:suppressScenarioEvent = $false
            $script:suppressOnReceivedEvent = $false
            $script:suppressPeriodicSendEvent = $false
        }

        Set-RowColor -Row $row -Status $status
    } catch {
        Write-Verbose "[UI] Failed to add connection row: $_"
    }
}

function Get-ConnectionEndpoint {
    param($Connection)

    if ($Connection.Mode -eq "Client" -or $Connection.Mode -eq "Sender") {
        return "$($Connection.RemoteIP):$($Connection.RemotePort)"
    } else {
        return "$($Connection.LocalIP):$($Connection.LocalPort)"
    }
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
    if ($Connection.Variables.ContainsKey('AutoResponseProfile')) {
        $currentProfile = $Connection.Variables['AutoResponseProfile']
    }
    if ($Connection.Variables.ContainsKey('AutoResponseProfilePath')) {
        $currentPath = $Connection.Variables['AutoResponseProfilePath']
    }

    # Add profiles
    $profiles = @()
    if ($InstancePath) {
        try {
            $profiles = Get-InstanceAutoResponseProfiles -InstancePath $InstancePath
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

function Configure-QuickDataColumn {
    param(
        $Row,
        [string]$InstancePath
    )

    $dataBankEntries = @()
    $dataBankPath = $null
    if ($InstancePath) {
        try {
            $catalog = Get-QuickDataCatalog -InstancePath $InstancePath
            if ($catalog) {
                $dataBankEntries = if ($catalog.Entries) { $catalog.Entries } else { @() }
                $dataBankPath = $catalog.Path
            }
        } catch {
            $dataBankEntries = @()
        }
    }

    $quickDataCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
    $quickDataCell.DisplayMember = "Display"
    $quickDataCell.ValueMember = "Key"
    $quickDataCell.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

    $dataSource = New-Object System.Collections.ArrayList
    $dataPlaceholder = [PSCustomObject]@{
        Display = "(Select)"
        Key     = ""
    }
    [void]$dataSource.Add($dataPlaceholder)

    if ($dataBankEntries -and $dataBankEntries.Count -gt 0) {
        foreach ($item in $dataBankEntries) {
            if (-not $item.DataID) { continue }

            $displayText = if ([string]::IsNullOrWhiteSpace($item.Description)) {
                $item.DataID
            } else {
                "{0} - {1}" -f $item.DataID, $item.Description
            }

            $entry = [PSCustomObject]@{
                Display = $displayText
                Key     = [string]$item.DataID
            }
            [void]$dataSource.Add($entry)
        }
    }

    foreach ($item in $dataSource) {
        [void]$quickDataCell.Items.Add($item)
    }
    $quickDataCell.Value = ""
    $quickDataCell.Tag = @{
        DataBankCount = $dataBankEntries.Count
        DataBankPath  = if ($dataBankPath -and (Test-Path -LiteralPath $dataBankPath)) { $dataBankPath } else { $null }
    }
    $Row.Cells["QuickData"] = $quickDataCell
}

function Configure-QuickActionColumn {
    param(
        $Row,
        [string]$InstancePath
    )

    $quickActionCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
    $quickActionCell.DisplayMember = "Display"
    $quickActionCell.ValueMember = "Key"
    $quickActionCell.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

    $actionSource = New-Object System.Collections.ArrayList
    $actionMapping = @{
    }
    $actionPlaceholder = [PSCustomObject]@{
        Display = "(Select)"
        Key     = ""
        Type    = ""
        Path    = $null
        Name    = $null
    }
    [void]$actionSource.Add($actionPlaceholder)
    $actionMapping[$actionPlaceholder.Key] = $actionPlaceholder

    # Get available scenarios from Scenario column
    $scenarioCell = $Row.Cells["Scenario"]
    $availableScenarios = @()
    if ($scenarioCell.Tag -is [System.Collections.IDictionary] -and $scenarioCell.Tag.ContainsKey("AvailableScenarios")) {
        $availableScenarios = $scenarioCell.Tag["AvailableScenarios"]
    }

    foreach ($scenarioEntry in $availableScenarios) {
        $actionEntry = [PSCustomObject]@{
            Display = $scenarioEntry.Display
            Key     = $scenarioEntry.Key
            Type    = $scenarioEntry.Type
            Path    = $scenarioEntry.Path
            Name    = $scenarioEntry.Name
        }
        [void]$actionSource.Add($actionEntry)
        $actionMapping[$actionEntry.Key] = $actionEntry
    }

    foreach ($item in $actionSource) {
        [void]$quickActionCell.Items.Add($item)
    }
    $Row.Cells["QuickAction"] = $quickActionCell
}
