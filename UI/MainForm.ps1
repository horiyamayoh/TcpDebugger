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

function New-UiMainForm {
    param(
        [string]$Title,
        [System.Drawing.Size]$Size,
        [System.Drawing.Font]$Font
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = $Size
    $form.StartPosition = "CenterScreen"
    $form.Font = $Font

    return $form
}

function New-UiInstanceGrid {
    param(
        [System.Drawing.Point]$Location,
        [System.Drawing.Size]$Size
    )
    $dgvInstances = New-Object System.Windows.Forms.DataGridView
    $dgvInstances.Location = $Location
    $dgvInstances.Size = $Size
    $dgvInstances.AllowUserToAddRows = $false
    $dgvInstances.AllowUserToDeleteRows = $false
    $dgvInstances.AllowUserToResizeRows = $false
    $dgvInstances.RowHeadersVisible = $false
    $dgvInstances.ReadOnly = $false
    $dgvInstances.SelectionMode = "FullRowSelect"
    $dgvInstances.MultiSelect = $false
    $dgvInstances.AutoSizeColumnsMode = "Fill"
    $dgvInstances.AutoGenerateColumns = $false
    $dgvInstances.EditMode = [System.Windows.Forms.DataGridViewEditMode]::EditOnEnter

    Add-InstanceGridColumns -DataGridView $dgvInstances

    return $dgvInstances
}

function Add-InstanceGridColumns {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.DataGridView]$DataGridView
    )

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "Name"
    $colName.Name = "Name"
    $colName.ReadOnly = $true
    $colName.FillWeight = 150
    $DataGridView.Columns.Add($colName) | Out-Null

    $colProtocol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colProtocol.HeaderText = "Protocol"
    $colProtocol.Name = "Protocol"
    $colProtocol.ReadOnly = $true
    $colProtocol.FillWeight = 110
    $DataGridView.Columns.Add($colProtocol) | Out-Null

    $colEndpoint = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colEndpoint.HeaderText = "Endpoint"
    $colEndpoint.Name = "Endpoint"
    $colEndpoint.ReadOnly = $true
    $colEndpoint.FillWeight = 160
    $DataGridView.Columns.Add($colEndpoint) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Status"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $colStatus.FillWeight = 100
    $DataGridView.Columns.Add($colStatus) | Out-Null

    $colAutoResponse = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colAutoResponse.HeaderText = "Auto Response"
    $colAutoResponse.Name = "Scenario"
    $colAutoResponse.DisplayMember = "Display"
    $colAutoResponse.ValueMember = "Key"
    $colAutoResponse.ValueType = [string]
    $colAutoResponse.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colAutoResponse.FillWeight = 140
    $DataGridView.Columns.Add($colAutoResponse) | Out-Null

    $colOnReceived = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colOnReceived.HeaderText = "On Received"
    $colOnReceived.Name = "OnReceived"
    $colOnReceived.DisplayMember = "Display"
    $colOnReceived.ValueMember = "Key"
    $colOnReceived.ValueType = [string]
    $colOnReceived.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colOnReceived.FillWeight = 140
    $DataGridView.Columns.Add($colOnReceived) | Out-Null

    $colPeriodicSend = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colPeriodicSend.HeaderText = "Periodic Send"
    $colPeriodicSend.Name = "PeriodicSend"
    $colPeriodicSend.DisplayMember = "Display"
    $colPeriodicSend.ValueMember = "Key"
    $colPeriodicSend.ValueType = [string]
    $colPeriodicSend.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colPeriodicSend.FillWeight = 140
    $DataGridView.Columns.Add($colPeriodicSend) | Out-Null

    $colQuickData = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colQuickData.HeaderText = "Quick Data"
    $colQuickData.Name = "QuickData"
    $colQuickData.DisplayMember = "Display"
    $colQuickData.ValueMember = "Key"
    $colQuickData.ValueType = [string]
    $colQuickData.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colQuickData.FillWeight = 170
    $DataGridView.Columns.Add($colQuickData) | Out-Null

    $colQuickSend = New-Object System.Windows.Forms.DataGridViewButtonColumn
    $colQuickSend.HeaderText = "Send"
    $colQuickSend.Name = "QuickSend"
    $colQuickSend.Text = "Send"
    $colQuickSend.UseColumnTextForButtonValue = $true
    $colQuickSend.FillWeight = 70
    $DataGridView.Columns.Add($colQuickSend) | Out-Null

    $colQuickAction = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colQuickAction.HeaderText = "Quick Action"
    $colQuickAction.Name = "QuickAction"
    $colQuickAction.DisplayMember = "Display"
    $colQuickAction.ValueMember = "Key"
    $colQuickAction.ValueType = [string]
    $colQuickAction.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colQuickAction.FillWeight = 170
    $DataGridView.Columns.Add($colQuickAction) | Out-Null

    $colActionSend = New-Object System.Windows.Forms.DataGridViewButtonColumn
    $colActionSend.HeaderText = "Run"
    $colActionSend.Name = "ActionSend"
    $colActionSend.Text = "Run"
    $colActionSend.UseColumnTextForButtonValue = $true
    $colActionSend.FillWeight = 70
    $DataGridView.Columns.Add($colActionSend) | Out-Null

    $colId = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colId.HeaderText = "Id"
    $colId.Name = "Id"
    $colId.ReadOnly = $true
    $colId.Visible = $false
    $DataGridView.Columns.Add($colId) | Out-Null
}

function New-UiToolbarButton {
    param(
        [string]$Text,
        [System.Drawing.Point]$Location
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Location = $Location
    $button.Size = New-Object System.Drawing.Size(100, 30)
    $button.Text = $Text

    return $button
}

function New-UiGroupFilter {
    param(
        [System.Drawing.Point]$Location,
        [System.Drawing.Size]$Size
    )

    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = $Location
    $comboBox.Size = $Size
    $comboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

    return $comboBox
}

function New-UiLabel {
    param(
        [string]$Text,
        [System.Drawing.Point]$Location,
        [System.Drawing.Size]$Size
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Location = $Location
    $label.Size = $Size
    $label.Text = $Text

    return $label
}

function New-UiLogTextBox {
    param(
        [System.Drawing.Point]$Location,
        [System.Drawing.Size]$Size,
        [System.Drawing.Font]$Font
    )

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = $Location
    $textBox.Size = $Size
    $textBox.Multiline = $true
    $textBox.ScrollBars = "Vertical"
    $textBox.ReadOnly = $true
    $textBox.Font = $Font

    return $textBox
}

function Show-MainForm {
    <#
    .SYNOPSIS
    Show the main WinForms UI.
    #>

    # Create main form
    $form = New-UiMainForm -Title "TCP Test Controller v1.0" -Size (New-Object System.Drawing.Size(1200, 700)) -Font (New-Object System.Drawing.Font("Segoe UI", 9))
    $script:CurrentMainForm = $form

    # DataGridView (connection list)
    $dgvInstances = New-UiInstanceGrid -Location (New-Object System.Drawing.Point(10, 50)) -Size (New-Object System.Drawing.Size(1160, 230))

    $form.Controls.Add($dgvInstances)

    # Toolbar buttons
    $btnRefresh = New-UiToolbarButton -Text "Refresh" -Location (New-Object System.Drawing.Point(10, 10))
    $form.Controls.Add($btnRefresh)

    $btnConnect = New-UiToolbarButton -Text "Connect" -Location (New-Object System.Drawing.Point(120, 10))
    $form.Controls.Add($btnConnect)

    $btnDisconnect = New-UiToolbarButton -Text "Disconnect" -Location (New-Object System.Drawing.Point(230, 10))
    $form.Controls.Add($btnDisconnect)

    $btnConnectAll = New-UiToolbarButton -Text "Connect All" -Location (New-Object System.Drawing.Point(340, 10))
    $form.Controls.Add($btnConnectAll)

    $btnDisconnectAll = New-UiToolbarButton -Text "Disconnect All" -Location (New-Object System.Drawing.Point(450, 10))
    $form.Controls.Add($btnDisconnectAll)

    $lblGroupFilter = New-UiLabel -Text "Group:" -Location (New-Object System.Drawing.Point(570, 15)) -Size (New-Object System.Drawing.Size(50, 20))
    $form.Controls.Add($lblGroupFilter)

    $cmbGroupFilter = New-UiGroupFilter -Location (New-Object System.Drawing.Point(620, 12)) -Size (New-Object System.Drawing.Size(180, 24))
    $form.Controls.Add($cmbGroupFilter)

    # Log area
    $lblLog = New-UiLabel -Text "Connection Log:" -Location (New-Object System.Drawing.Point(10, 290)) -Size (New-Object System.Drawing.Size(200, 20))
    $form.Controls.Add($lblLog)

    $txtLog = New-UiLogTextBox -Location (New-Object System.Drawing.Point(10, 315)) -Size (New-Object System.Drawing.Size(1165, 335)) -Font (New-Object System.Drawing.Font("Consolas", 9))
    $form.Controls.Add($txtLog)

    # State holders
    $script:suppressScenarioEvent = $false
    $gridEditingInProgress = $false
    $pendingComboDropDownColumn = $null
    $script:suppressOnReceivedEvent = $false
    $script:suppressPeriodicSendEvent = $false
    $script:currentGroupFilter = "(All)"

    $getSelectedConnection = {
        if ($dgvInstances.SelectedRows.Count -eq 0) {
            return $null
        }

        if (-not $dgvInstances.Columns.Contains("Id")) {
            return $null
        }

        $connId = $dgvInstances.SelectedRows[0].Cells["Id"].Value
        if (-not $connId) {
            return $null
        }

        try {
            return Get-UiConnection -ConnectionId $connId
        } catch {
            return $null
        }
    }

    # Events
    $dgvInstances.Add_CellBeginEdit({
        $gridEditingInProgress = $true
    })

    $dgvInstances.Add_CellEndEdit({
        $gridEditingInProgress = $false
    })

    $dgvInstances.Add_Leave({
        $gridEditingInProgress = $false
    })

    $btnRefresh.Add_Click({
        Update-InstanceList -DataGridView $dgvInstances -GroupFilterComboBox $cmbGroupFilter -GroupFilter $script:currentGroupFilter
    })

    $btnConnect.Add_Click({
        if ($dgvInstances.SelectedRows.Count -eq 0) {
            return
        }

        $connId = $dgvInstances.SelectedRows[0].Cells["Id"].Value
        if (-not $connId) {
            return
        }

        try {
            $conn = Get-UiConnection -ConnectionId $connId
        } catch {
            $conn = $null
        }

        if (-not $conn) {
            [System.Windows.Forms.MessageBox]::Show("Connection not found: $connId", "Error") | Out-Null
            return
        }

        try {
            Start-Connection -ConnectionId $conn.Id
            [System.Windows.Forms.MessageBox]::Show("Connection started: $($conn.DisplayName)", "Success") | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to start connection: $_", "Error") | Out-Null
        }

        Update-InstanceList -DataGridView $dgvInstances -GroupFilterComboBox $cmbGroupFilter -GroupFilter $script:currentGroupFilter
    })

    $btnDisconnect.Add_Click({
        if ($dgvInstances.SelectedRows.Count -eq 0) {
            return
        }

        $connId = $dgvInstances.SelectedRows[0].Cells["Id"].Value
        if (-not $connId) {
            return
        }

        try {
            $conn = Get-UiConnection -ConnectionId $connId
        } catch {
            $conn = $null
        }

        if (-not $conn) {
            [System.Windows.Forms.MessageBox]::Show("Connection not found: $connId", "Error") | Out-Null
            return
        }

        try {
            Stop-Connection -ConnectionId $conn.Id
            [System.Windows.Forms.MessageBox]::Show("Connection stopped: $($conn.DisplayName)", "Success") | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to stop connection: $_", "Error") | Out-Null
        }

        Update-InstanceList -DataGridView $dgvInstances -GroupFilterComboBox $cmbGroupFilter -GroupFilter $script:currentGroupFilter
    })

    $btnConnectAll.Add_Click({
        $connections = Get-UiConnections
        if (-not $connections) { return }

        $targetGroup = $script:currentGroupFilter
        if ($targetGroup -and $targetGroup -ne "(All)") {
            $connections = $connections | Where-Object { $_.Group -eq $targetGroup }
        }

        foreach ($conn in $connections) {
            try {
                Start-Connection -ConnectionId $conn.Id
            } catch {
                Write-Warning "[UI] Failed to start $($conn.DisplayName): $_"
            }
        }

        Update-InstanceList -DataGridView $dgvInstances -GroupFilterComboBox $cmbGroupFilter -GroupFilter $script:currentGroupFilter
    })

    $btnDisconnectAll.Add_Click({
        $connections = Get-UiConnections
        if (-not $connections) { return }

        $targetGroup = $script:currentGroupFilter
        if ($targetGroup -and $targetGroup -ne "(All)") {
            $connections = $connections | Where-Object { $_.Group -eq $targetGroup }
        }

        foreach ($conn in $connections) {
            try {
                Stop-Connection -ConnectionId $conn.Id
            } catch {
                Write-Warning "[UI] Failed to stop $($conn.DisplayName): $_"
            }
        }

        Update-InstanceList -DataGridView $dgvInstances -GroupFilterComboBox $cmbGroupFilter -GroupFilter $script:currentGroupFilter
    })

    $cmbGroupFilter.Add_SelectedIndexChanged({
        if ($cmbGroupFilter.SelectedItem) {
            $script:currentGroupFilter = [string]$cmbGroupFilter.SelectedItem
            Update-InstanceList -DataGridView $dgvInstances -GroupFilterComboBox $cmbGroupFilter -GroupFilter $script:currentGroupFilter
        }
    })

    $dgvInstances.Add_CurrentCellDirtyStateChanged({
        if ($dgvInstances.IsCurrentCellDirty -and $dgvInstances.CurrentCell -and
            $dgvInstances.CurrentCell.OwningColumn -and
            $dgvInstances.CurrentCell.OwningColumn.Name -eq "Scenario") {
            $dgvInstances.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
        }
    })

    $dgvInstances.Add_CellFormatting({
        param($sender, $eventArgs)

        if ($eventArgs.RowIndex -lt 0 -or $eventArgs.ColumnIndex -lt 0) { return }

        $column = $sender.Columns[$eventArgs.ColumnIndex]
        if (-not $column -or $column.Name -ne "Status") { return }

        $statusText = if ($eventArgs.Value) { [string]$eventArgs.Value } else { "" }
        $upperStatus = $statusText.ToUpperInvariant()

        switch ($upperStatus) {
            "CONNECTED" { $eventArgs.CellStyle.BackColor = [System.Drawing.Color]::FromArgb(198, 239, 206); $eventArgs.CellStyle.ForeColor = [System.Drawing.Color]::FromArgb(0, 97, 0) }
            "CONNECTING" { $eventArgs.CellStyle.BackColor = [System.Drawing.Color]::FromArgb(255, 235, 156); $eventArgs.CellStyle.ForeColor = [System.Drawing.Color]::FromArgb(156, 101, 0) }
            "DISCONNECTED" { $eventArgs.CellStyle.BackColor = [System.Drawing.Color]::FromArgb(237, 237, 237); $eventArgs.CellStyle.ForeColor = [System.Drawing.Color]::FromArgb(102, 102, 102) }
            "ERROR" { $eventArgs.CellStyle.BackColor = [System.Drawing.Color]::FromArgb(255, 199, 206); $eventArgs.CellStyle.ForeColor = [System.Drawing.Color]::FromArgb(156, 0, 6) }
            Default { $eventArgs.CellStyle.BackColor = [System.Drawing.Color]::White; $eventArgs.CellStyle.ForeColor = [System.Drawing.Color]::FromArgb(50, 49, 48) }
        }
    })

    $dgvInstances.Add_CellValueChanged({
        param($sender, $args)

        if ($script:suppressScenarioEvent) {
            return
        }

        if ($args.ColumnIndex -lt 0 -or $args.RowIndex -lt 0) {
            return
        }

        $column = $sender.Columns[$args.ColumnIndex]
        if ($column.Name -ne "Scenario") {
            return
        }

        $row = $sender.Rows[$args.RowIndex]
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
        } elseif ($tagData -is [System.Collections.IDictionary]) {
            $mapping = $tagData
        }

        if (-not $currentProfileKey) {
            $currentProfileKey = ""
        } else {
            $currentProfileKey = [string]$currentProfileKey
        }

        $selectedKey = if ($cell.Value) { [string]$cell.Value } else { "" }
        $entry = $null
        if ($mapping -and $mapping.ContainsKey($selectedKey)) {
            $entry = $mapping[$selectedKey]
        }

        if ($entry -and $entry.Type -eq "Scenario") {
            $scenarioPath = $entry.Path
            if (-not $scenarioPath -or -not (Test-Path -LiteralPath $scenarioPath)) {
                [System.Windows.Forms.MessageBox]::Show("Scenario file not found: $($entry.Name)", "Warning") | Out-Null
            } else {
                try {
                    Start-Scenario -ConnectionId $connId -ScenarioPath $scenarioPath
                    [System.Windows.Forms.MessageBox]::Show("Scenario started: $($entry.Name)", "Success") | Out-Null
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to start scenario: $_", "Error") | Out-Null
                }
            }

            if ($currentProfileKey -ne $selectedKey) {
                $script:suppressScenarioEvent = $true
                try {
                    $cell.Value = $currentProfileKey
                } finally {
                    $script:suppressScenarioEvent = $false
                }
                $sender.InvalidateCell($cell)

                if ($sender.IsCurrentCellInEditMode) {
                    try {
                        $sender.CancelEdit()
                        $sender.EndEdit()
                    } catch {
                        # ignore edit cancellation failures
                    }
                }
            }

            return
        }

        $profileName = $null
        $profilePath = $null
        if ($entry -and $entry.Type -eq "Profile") {
            $profileName = $entry.Name
            $profilePath = $entry.Path
        }

        try {
            Set-ConnectionAutoResponseProfile -ConnectionId $connId -ProfileName $profileName -ProfilePath $profilePath | Out-Null
            if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("ProfileKey")) {
                $tagData["ProfileKey"] = $selectedKey
            }
        } catch {
            if ($currentProfileKey -ne $selectedKey) {
                $script:suppressScenarioEvent = $true
                try {
                    $cell.Value = $currentProfileKey
                } finally {
                    $script:suppressScenarioEvent = $false
                }
                $sender.InvalidateCell($cell)
            }
            [System.Windows.Forms.MessageBox]::Show("Failed to apply auto-response profile: $_", "Error") | Out-Null
        }
    })

    $dgvInstances.Add_CellValueChanged({
        param($sender, $args)

        if ($script:suppressOnReceivedEvent) {
            return
        }

        if ($args.RowIndex -lt 0) {
            return
        }

        $column = $sender.Columns[$args.ColumnIndex]
        if (-not $column -or $column.Name -ne "OnReceived") {
            return
        }

        $row = $sender.Rows[$args.RowIndex]
        $cell = $row.Cells[$args.ColumnIndex]
        $connId = $row.Cells["Id"].Value

        if (-not $connId) {
            return
        }

        try {
            $conn = Get-UiConnection -ConnectionId $connId
        } catch {
            return
        }

        $tagData = $cell.Tag
        $mapping = $null
        $currentProfileKey = ""
        if ($tagData -is [System.Collections.IDictionary]) {
            if ($tagData.ContainsKey("Mapping")) {
                $mapping = $tagData["Mapping"]
            }
            if ($tagData.ContainsKey("OnReceivedProfileKey")) {
                $currentProfileKey = [string]$tagData["OnReceivedProfileKey"]
            }
        }

        $selectedKey = if ($cell.Value) { [string]$cell.Value } else { "" }
        if ($selectedKey -eq $currentProfileKey) {
            return
        }

        $entry = $null
        if ($mapping -and $mapping.ContainsKey($selectedKey)) {
            $entry = $mapping[$selectedKey]
        }

        $profileName = $null
        $profilePath = $null
        if ($entry -and $entry.Type -eq "Profile") {
            $profileName = $entry.Name
            $profilePath = $entry.Path
        }

        try {
            Set-ConnectionOnReceivedProfile -ConnectionId $connId -ProfileName $profileName -ProfilePath $profilePath | Out-Null
            if ($tagData -is [System.Collections.IDictionary]) {
                $tagData["OnReceivedProfileKey"] = $selectedKey
            }
        } catch {
            if ($currentProfileKey -ne $selectedKey) {
                $script:suppressOnReceivedEvent = $true
                try {
                    $cell.Value = $currentProfileKey
                } finally {
                    $script:suppressOnReceivedEvent = $false
                }
                $sender.InvalidateCell($cell)
            }
            [System.Windows.Forms.MessageBox]::Show("Failed to apply OnReceived profile: $_", "Error") | Out-Null
        }
    })

    # Periodic Send profile change handler
    $dgvInstances.Add_CellValueChanged({
        param($sender, $args)

        if ($script:suppressPeriodicSendEvent) {
            return
        }

        if ($args.RowIndex -lt 0) {
            return
        }

        $column = $sender.Columns[$args.ColumnIndex]
        if (-not $column -or $column.Name -ne "PeriodicSend") {
            return
        }

        $row = $sender.Rows[$args.RowIndex]
        $cell = $row.Cells[$args.ColumnIndex]
        $connId = $row.Cells["Id"].Value

        if (-not $connId) {
            return
        }

        try {
            $conn = Get-UiConnection -ConnectionId $connId
        } catch {
            return
        }

        $tagData = $cell.Tag
        $mapping = $null
        $currentProfileKey = ""
        if ($tagData -is [System.Collections.IDictionary]) {
            if ($tagData.ContainsKey("Mapping")) {
                $mapping = $tagData["Mapping"]
            }
            if ($tagData.ContainsKey("PeriodicSendProfileKey")) {
                $currentProfileKey = [string]$tagData["PeriodicSendProfileKey"]
            }
        }

        $selectedKey = if ($cell.Value) { [string]$cell.Value } else { "" }
        if ($selectedKey -eq $currentProfileKey) {
            return
        }

        $entry = $null
        if ($mapping -and $mapping.ContainsKey($selectedKey)) {
            $entry = $mapping[$selectedKey]
        }

        $profilePath = $null
        if ($entry -and $entry.Type -eq "Profile") {
            $profilePath = $entry.Path
        }

        try {
            $instancePath = $null
            if ($conn.Variables.ContainsKey('InstancePath')) {
                $instancePath = $conn.Variables['InstancePath']
            }

            if (-not $instancePath) {
                throw "Instance path is not available for this connection."
            }

            Set-ConnectionPeriodicSendProfile -ConnectionId $connId -ProfilePath $profilePath -InstancePath $instancePath | Out-Null
            if ($tagData -is [System.Collections.IDictionary]) {
                $tagData["PeriodicSendProfileKey"] = $selectedKey
            }
        } catch {
            if ($currentProfileKey -ne $selectedKey) {
                $script:suppressPeriodicSendEvent = $true
                try {
                    $cell.Value = $currentProfileKey
                } finally {
                    $script:suppressPeriodicSendEvent = $false
                }
                $sender.InvalidateCell($cell)
            }
            [System.Windows.Forms.MessageBox]::Show("Failed to apply Periodic Send profile: $_", "Error") | Out-Null
        }
    })

    $dgvInstances.Add_CellContentClick({
        param($sender, $args)

        if ($args.RowIndex -lt 0 -or $args.ColumnIndex -lt 0) {
            return
        }

        $column = $sender.Columns[$args.ColumnIndex]
        if (-not $column) {
            return
        }

        $row = $sender.Rows[$args.RowIndex]
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
            # connection might have been removed; leave $connection = $null for display fallback
        }

        switch ($column.Name) {
            "QuickSend" {
                $comboCell = $row.Cells["QuickData"]
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
                    Send-QuickData -ConnectionId $connId -DataID $selectedKey -DataBankPath $dataBankPath
                    $targetName = if ($connection) { $connection.DisplayName } else { $connId }
                    [System.Windows.Forms.MessageBox]::Show("Sent data item '$selectedKey' to $targetName.", "Success") | Out-Null
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to send data: $_", "Error") | Out-Null
                }
            }
            "ActionSend" {
                $actionCell = $row.Cells["QuickAction"]
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
                        Start-Scenario -ConnectionId $connId -ScenarioPath $scenarioPath
                        $actionName = if ($actionEntry.Name) { $actionEntry.Name } else { $selectedKey }
                        [System.Windows.Forms.MessageBox]::Show("Started scenario '$actionName'.", "Success") | Out-Null
                    } catch {
                        [System.Windows.Forms.MessageBox]::Show("Failed to start scenario: $_", "Error") | Out-Null
                    }
                } else {
                    [System.Windows.Forms.MessageBox]::Show("Selected action is not supported.", "Warning") | Out-Null
                }
            }
        }
    })

    $dgvInstances.Add_CellClick({
        param($sender, $args)

        if ($args.RowIndex -lt 0 -or $args.ColumnIndex -lt 0) {
            return
        }

        $row = $sender.Rows[$args.RowIndex]
        $cell = $row.Cells[$args.ColumnIndex]
        $column = $cell.OwningColumn

        if (-not $column -or ($column -isnot [System.Windows.Forms.DataGridViewComboBoxColumn])) {
            return
        }

        $pendingComboDropDownColumn = $column.Name
        if ($sender.CurrentCell -ne $cell) {
            $sender.CurrentCell = $cell
        }

        if (-not $sender.IsCurrentCellInEditMode) {
            [void]$sender.BeginEdit($true)
        }

        $combo = $sender.EditingControl
        if ($combo -is [System.Windows.Forms.ComboBox]) {
            $combo.DroppedDown = $true
            $pendingComboDropDownColumn = $null
        }
    })

    $dgvInstances.Add_EditingControlShowing({
        param($sender, $eventArgs)

        $control = $eventArgs.Control
        if ($control -isnot [System.Windows.Forms.ComboBox]) {
            return
        }

        if (-not $pendingComboDropDownColumn) {
            return
        }

        $currentCell = $sender.CurrentCell
        if (-not $currentCell -or -not $currentCell.OwningColumn) {
            $pendingComboDropDownColumn = $null
            return
        }

        if ($currentCell.OwningColumn.Name -eq $pendingComboDropDownColumn) {
            $control.DroppedDown = $true
        }

        $pendingComboDropDownColumn = $null
    })

    $dgvInstances.Add_DataError({
        param($sender, $eventArgs)

        if ($eventArgs) {
            $eventArgs.ThrowException = $false
            $eventArgs.Cancel = $true
        }

        $context = if ($eventArgs) { $eventArgs.Context } else { "Unknown" }
        Write-Verbose ("[UI] DataGridView error suppressed: {0}" -f $context)
    })

    # Timer for periodic refresh
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        if (-not $gridEditingInProgress -and -not $dgvInstances.IsCurrentCellInEditMode) {
            Update-InstanceList -DataGridView $dgvInstances -GroupFilterComboBox $cmbGroupFilter -GroupFilter $script:currentGroupFilter
        }
        Update-LogDisplay -TextBox $txtLog
    })
    $timer.Start()

    # Form closing cleanup
    $form.Add_FormClosing({
        $timer.Stop()

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

    # Initial load
    Update-InstanceList -DataGridView $dgvInstances -GroupFilterComboBox $cmbGroupFilter -GroupFilter $script:currentGroupFilter

    # Show form
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()

    if ($script:CurrentMainForm -eq $form) {
        $script:CurrentMainForm = $null
    }
}

function Update-InstanceList {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView,
        [System.Windows.Forms.ComboBox]$GroupFilterComboBox,
        [string]$GroupFilter
    )

    if (-not $DataGridView) {
        return
    }

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

    $DataGridView.Rows.Clear()

    $connections = Get-UiConnections
    if (-not $connections) { $connections = @() }

    $groupValues = @("(All)") + ($connections | Where-Object { $_.Group } | Select-Object -ExpandProperty Group -Unique | Sort-Object)
    if ($GroupFilterComboBox) {
        $previousSelection = if ($GroupFilterComboBox.SelectedItem) { [string]$GroupFilterComboBox.SelectedItem } else { "" }
        $GroupFilterComboBox.Items.Clear()
        foreach ($group in $groupValues) {
            [void]$GroupFilterComboBox.Items.Add($group)
        }

        $targetSelection = if ($GroupFilter) { $GroupFilter } elseif ($previousSelection) { $previousSelection } else { "(All)" }
        if (-not $GroupFilterComboBox.Items.Contains($targetSelection)) {
            $targetSelection = "(All)"
        }

        if ($GroupFilterComboBox.SelectedItem -ne $targetSelection) {
            $GroupFilterComboBox.SelectedItem = $targetSelection
        }
        $script:currentGroupFilter = $targetSelection
    }

    $targetGroup = if ($GroupFilter) { $GroupFilter } else { "" }
    if ($targetGroup -and $targetGroup -ne "(All)") {
        $connections = $connections | Where-Object { $_.Group -eq $targetGroup }
    }

    if (-not $connections -or $connections.Count -eq 0) {
        return
    }

    foreach ($conn in $connections | Sort-Object DisplayName) {
        $endpoint = ""
        if ($conn.Mode -eq "Client" -or $conn.Mode -eq "Sender") {
            $endpoint = "$($conn.RemoteIP):$($conn.RemotePort)"
        } else {
            $endpoint = "$($conn.LocalIP):$($conn.LocalPort)"
        }

        $rowIndex = $DataGridView.Rows.Add(
            $conn.DisplayName,
            "$($conn.Protocol) $($conn.Mode)",
            $endpoint,
            $conn.Status,
            $null,
            $null,
            $null,
            $null,
            $null,
            $conn.Id
        )

        $row = $DataGridView.Rows[$rowIndex]

        try {
            $script:suppressScenarioEvent = $true
            $script:suppressOnReceivedEvent = $true
            $script:suppressPeriodicSendEvent = $true

            $items = New-Object System.Collections.ArrayList
            $mapping = @{}
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
            if ($conn.Variables.ContainsKey('AutoResponseProfile')) {
                $currentProfile = $conn.Variables['AutoResponseProfile']
                Write-Verbose "[UI] Auto Response: $currentProfile"
            }
            if ($conn.Variables.ContainsKey('AutoResponseProfilePath')) {
                $currentPath = $conn.Variables['AutoResponseProfilePath']
            }

            $instancePath = $null
            if ($conn.Variables.ContainsKey('InstancePath')) {
                $instancePath = $conn.Variables['InstancePath']
            }

            $profiles = @()
            if ($instancePath) {
                try {
                    $profiles = Get-InstanceAutoResponseProfiles -InstancePath $instancePath
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

            if ($instancePath) {
                try {
                    $scenarioFiles = Get-InstanceScenarios -InstancePath $instancePath
                } catch {
                    $scenarioFiles = @()
                }

                if ($scenarioFiles -and $scenarioFiles.Count -gt 0) {
                    $scenarioRoot = Join-Path $instancePath "scenarios"
                    foreach ($scenario in $scenarioFiles) {
                        $scenarioKey = "scenario::$scenario"
                        $scenarioPath = Join-Path $scenarioRoot $scenario
                        $entry = [PSCustomObject]@{
                            Display = "笆ｶ $scenario"
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

            $scenarioCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
            $scenarioCell.DisplayMember = "Display"
            $scenarioCell.ValueMember = "Key"
            foreach ($item in $items) {
                [void]$scenarioCell.Items.Add($item)
            }
            if ($currentKey) {
                Write-Host "[UI] Setting Auto Response: $currentKey for $($conn.DisplayName)" -ForegroundColor Magenta
            }
            $scenarioCell.Value = $currentKey
            $scenarioCell.Tag = @{
                Mapping    = $mapping
                ProfileKey = $currentKey
            }
            $row.Cells["Scenario"] = $scenarioCell

            # OnReceived列の設定
            $onReceivedItems = New-Object System.Collections.ArrayList
            $onReceivedMapping = @{}

            $onReceivedNone = [PSCustomObject]@{
                Display = "(None)"
                Key     = ""
                Type    = "Profile"
                Name    = $null
                Path    = $null
            }
            [void]$onReceivedItems.Add($onReceivedNone)
            $onReceivedMapping[$onReceivedNone.Key] = $onReceivedNone

            $currentOnReceivedProfile = ""
            $currentOnReceivedPath = $null
            if ($conn.Variables.ContainsKey('OnReceivedProfile')) {
                $currentOnReceivedProfile = $conn.Variables['OnReceivedProfile']
            }
            if ($conn.Variables.ContainsKey('OnReceivedProfilePath')) {
                $currentOnReceivedPath = $conn.Variables['OnReceivedProfilePath']
            }

            $onReceivedProfiles = @()
            if ($instancePath) {
                try {
                    $onReceivedProfiles = Get-InstanceOnReceivedProfiles -InstancePath $instancePath
                } catch {
                    $onReceivedProfiles = @()
                }
            }

            foreach ($profile in $onReceivedProfiles) {
                if ([string]::IsNullOrWhiteSpace($profile.Name)) {
                    continue
                }

                $key = "onreceived::$($profile.Name)"
                $entry = [PSCustomObject]@{
                    Display = $profile.DisplayName
                    Key     = $key
                    Type    = "Profile"
                    Name    = $profile.Name
                    Path    = $profile.FilePath
                }

                [void]$onReceivedItems.Add($entry)
                $onReceivedMapping[$key] = $entry
            }

            $currentOnReceivedKey = ""
            if ($currentOnReceivedProfile) {
                $currentOnReceivedKey = "onreceived::$currentOnReceivedProfile"
                if (-not $onReceivedMapping.ContainsKey($currentOnReceivedKey)) {
                    $displayName = if ($currentOnReceivedPath) { "$currentOnReceivedProfile (missing)" } else { $currentOnReceivedProfile }
                    $entry = [PSCustomObject]@{
                        Display = $displayName
                        Key     = $currentOnReceivedKey
                        Type    = "Profile"
                        Name    = $currentOnReceivedProfile
                        Path    = $currentOnReceivedPath
                    }
                    [void]$onReceivedItems.Add($entry)
                    $onReceivedMapping[$currentOnReceivedKey] = $entry
                }
            }

            $onReceivedCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
            $onReceivedCell.DisplayMember = "Display"
            $onReceivedCell.ValueMember = "Key"
            foreach ($item in $onReceivedItems) {
                [void]$onReceivedCell.Items.Add($item)
            }
            $onReceivedCell.Value = $currentOnReceivedKey
            $onReceivedCell.Tag = @{
                Mapping              = $onReceivedMapping
                OnReceivedProfileKey = $currentOnReceivedKey
            }
            $row.Cells["OnReceived"] = $onReceivedCell

            # Periodic Send profiles
            $currentPeriodicSendProfile = ""
            $currentPeriodicSendPath = $null
            if ($conn.Variables.ContainsKey('PeriodicSendProfile')) {
                $currentPeriodicSendProfile = $conn.Variables['PeriodicSendProfile']
            }
            if ($conn.Variables.ContainsKey('PeriodicSendProfilePath')) {
                $currentPeriodicSendPath = $conn.Variables['PeriodicSendProfilePath']
            }

            $periodicSendProfiles = @()
            if ($instancePath) {
                try {
                    $periodicSendProfiles = Get-InstancePeriodicSendProfiles -InstancePath $instancePath
                } catch {
                    $periodicSendProfiles = @()
                }
            }

            $periodicSendItems = New-Object System.Collections.ArrayList
            $periodicSendMapping = @{}
            
            $periodicSendPlaceholder = [PSCustomObject]@{
                Display = "(None)"
                Key     = ""
                Type    = "None"
                Name    = $null
                Path    = $null
            }
            [void]$periodicSendItems.Add($periodicSendPlaceholder)
            $periodicSendMapping[$periodicSendPlaceholder.Key] = $periodicSendPlaceholder

            foreach ($profile in $periodicSendProfiles) {
                $key = "periodic::$($profile.ProfileName)"
                $entry = [PSCustomObject]@{
                    Display = $profile.ProfileName
                    Key     = $key
                    Type    = "Profile"
                    Name    = $profile.ProfileName
                    Path    = $profile.FilePath
                }

                [void]$periodicSendItems.Add($entry)
                $periodicSendMapping[$key] = $entry
            }

            $currentPeriodicSendKey = ""
            if ($currentPeriodicSendProfile) {
                $currentPeriodicSendKey = "periodic::$currentPeriodicSendProfile"
                if (-not $periodicSendMapping.ContainsKey($currentPeriodicSendKey)) {
                    $displayName = if ($currentPeriodicSendPath) { "$currentPeriodicSendProfile (missing)" } else { $currentPeriodicSendProfile }
                    $entry = [PSCustomObject]@{
                        Display = $displayName
                        Key     = $currentPeriodicSendKey
                        Type    = "Profile"
                        Name    = $currentPeriodicSendProfile
                        Path    = $currentPeriodicSendPath
                    }
                    [void]$periodicSendItems.Add($entry)
                    $periodicSendMapping[$currentPeriodicSendKey] = $entry
                }
            }

            $periodicSendCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
            $periodicSendCell.DisplayMember = "Display"
            $periodicSendCell.ValueMember = "Key"
            foreach ($item in $periodicSendItems) {
                [void]$periodicSendCell.Items.Add($item)
            }
            $periodicSendCell.Value = $currentPeriodicSendKey
            $periodicSendCell.Tag = @{
                Mapping              = $periodicSendMapping
                PeriodicSendProfileKey = $currentPeriodicSendKey
            }
            $row.Cells["PeriodicSend"] = $periodicSendCell

            $dataBankEntries = @()
            $dataBankPath = $null
            if ($instancePath) {
                try {
                    $catalog = Get-QuickDataCatalog -InstancePath $instancePath
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
            $row.Cells["QuickData"] = $quickDataCell

            $quickActionCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
            $quickActionCell.DisplayMember = "Display"
            $quickActionCell.ValueMember = "Key"
            $quickActionCell.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

            $actionSource = New-Object System.Collections.ArrayList
            $actionMapping = @{}
            $actionPlaceholder = [PSCustomObject]@{
                Display = "(Select)"
                Key     = ""
                Type    = ""
                Path    = $null
                Name    = $null
            }
            [void]$actionSource.Add($actionPlaceholder)
            $actionMapping[$actionPlaceholder.Key] = $actionPlaceholder

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
            $quickActionCell.Value = ""
            $quickActionCell.Tag = @{
                Mapping = $actionMapping
            }
            $row.Cells["QuickAction"] = $quickActionCell
        } catch {
            $row.Cells["Scenario"].Value = ""
        } finally {
            $script:suppressScenarioEvent = $false
            $script:suppressOnReceivedEvent = $false
            $script:suppressPeriodicSendEvent = $false
        }

        switch ($conn.Status) {
            "CONNECTED" {
                $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGreen
            }
            "CONNECTING" {
                $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightYellow
            }
            "ERROR" {
                $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightCoral
            }
            "DISCONNECTED" {
                $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGray
            }
            default {
                $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::White
            }
        }
    }

    if ($selectedId) {
        foreach ($row in $DataGridView.Rows) {
            if ($row.Cells["Id"].Value -eq $selectedId) {
                $row.Selected = $true
                if ($row.Cells.Count -gt 0) {
                    $DataGridView.CurrentCell = $row.Cells[0]
                }
                break
            }
        }
    }

    if ($firstDisplayedIndex -ne $null -and $DataGridView.RowCount -gt 0) {
        $targetIndex = [Math]::Min([Math]::Max(0, $firstDisplayedIndex), $DataGridView.RowCount - 1)
        try {
            $DataGridView.FirstDisplayedScrollingRowIndex = $targetIndex
        } catch {
            # ignore scroll errors
        }
    }
}

function Update-LogDisplay {
    param(
        [System.Windows.Forms.TextBox]$TextBox
    )

    if (-not $TextBox) {
        return
    }

    $logLines = @()

    foreach ($conn in Get-UiConnections) {
        $snapshot = @()

        try {
            if ($conn.RecvBuffer -and $conn.RecvBuffer.Count -gt 0) {
                $syncRoot = $conn.RecvBuffer.SyncRoot
                [System.Threading.Monitor]::Enter($syncRoot)
                try {
                    $snapshot = $conn.RecvBuffer.ToArray()
                } finally {
                    [System.Threading.Monitor]::Exit($syncRoot)
                }
            }
        } catch {
            continue
        }

        if (-not $snapshot -or $snapshot.Length -eq 0) {
            continue
        }

        $count = $snapshot.Length
        $startIndex = [Math]::Max(0, $count - 10)
        for ($i = $startIndex; $i -lt $count; $i++) {
            $recv = $snapshot[$i]
            if (-not $recv) { continue }

            $summary = Get-MessageSummary -Data $recv.Data -MaxLength 40
            $timeStr = $recv.Timestamp.ToString("HH:mm:ss")
            $logLines += "[$timeStr] $($conn.DisplayName) 竍? $summary ($($recv.Length) bytes)"
        }
    }

    $logLines = $logLines | Select-Object -Last 100

    $TextBox.Text = $logLines -join "`r`n"
    $TextBox.SelectionStart = $TextBox.Text.Length
    $TextBox.ScrollToCaret()
}

# Export-ModuleMember -Function 'Show-MainForm'

